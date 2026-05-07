# Multi-Tenancy

> Loaded when designing tenant isolation: deployment-tier spectrum, commercial-vs-deployment tier separation, isolation models, migration between tiers, anti-patterns.

## What multi-tenancy decisions cover

The product hosts multiple counterparties (tenants) under one platform. The architectural decisions cover:

1. **Isolation level** — which resources are shared vs dedicated per tenant.
2. **Tier mapping** — pricing tier → infrastructure tier (with override path).
3. **Tenant lifecycle** — onboarding, scaling up/down between tiers, offboarding.
4. **Per-tenant secrets, networking, observability** — how counterparties' data and operations are kept separate.
5. **Migration** — moving a tenant from one tier to another.
6. **What the platform refuses to multi-tenant** — tenants that need physical isolation (own cluster, own region, own KMS root).

## The deployment-tier spectrum

A typical product needs all five tiers; ship them as a spectrum, not a binary.

```
SHARED                                                              DEDICATED
←─────────────────────────────────────────────────────────────────────────→
shared_pod        namespace        cluster        region        on_prem
```

| Tier | Topology | What's shared | What's dedicated | Ops cost |
|---|---|---|---|---|
| `shared_pod` | Multiple tenants share one backend pod | Engine, message broker, DB, everything | Branding + tenant_id-scoped data only | ~$0 incremental |
| `namespace` | Dedicated k8s namespace + dedicated backend pod per tenant | Cluster, DB cluster, observability stack | Pod, message broker per-tenant, scheduling isolation | $50-150/mo per tenant |
| `cluster` | Dedicated pod + dedicated DB cluster | k8s cluster | DB, Redis, message broker, egress IP | $300-700/mo |
| `region` | Dedicated cluster in a tenant-chosen region | Nothing | Cluster, region, optional own KMS root | $1.5-4k/mo |
| `on_prem` | Tenant runs the software on their infra | Nothing | Everything, including the operational responsibility | License fee only; tenant operates |

Numbers above are illustrative and depend heavily on cloud and product. Calibrate during Phase 1.

### What the lowest tier (`shared_pod`) actually allows

For free trials, self-serve onboarding, and low-spend tenants — the shared tier is essential to ship a low-friction signup flow. But it carries hard limits:

- **No dedicated counterparty credentials.** If a tenant brings their own credentials for a downstream service (vendor API key, FIX session, payment processor), they cannot share that credential across the shared pod's outbound calls. Shared tier MUST use platform-owned downstream credentials only.
- **No tenant-specific egress IP.** Some downstream services allowlist IPs; shared tier can't promise a stable IP per tenant.
- **No tenant-specific compliance posture.** If one tenant needs (e.g.) per-tenant audit log retention, all tenants in that pod get the same.
- **One bug cascades.** A tenant's bad input can affect others in the pod (memory pressure, queue backups, DB lock contention).

Cap: `shared_pod` typically supports ~50-200 tenants per pod. Beyond that, isolation degrades faster than cost benefits accrue.

### When to require `namespace` or higher

Hard requirements that force a tenant up the spectrum:

| Requirement | Minimum tier |
|---|---|
| Tenant brings their own credentials for an external service that allowlists by source IP | `cluster` (dedicated egress IP) |
| Tenant requires an SLA the shared tier can't meet | `namespace` |
| Tenant needs a custom subset of features (different from the shared product) | `namespace` |
| Tenant has compliance requirement requiring data isolation | `cluster` or `region` |
| Tenant requires data residency in a specific region | `region` |
| Tenant requires their own encryption keys (own KMS root) | `region` |
| Tenant runs in their own infra | `on_prem` |

## Commercial tier vs deployment tier — separate dimensions

Don't conflate. A `tier` column carrying both pricing and topology will collide.

```
DEFAULT MAPPING (override per tenant when needed):

commercial_tier  → deployment_tier (default)
trial            → shared_pod
self_serve       → shared_pod
branded          → namespace
dedicated        → cluster
enterprise       → region
on_prem_license  → on_prem
```

Document the mapping in a single place; it lives in the control-plane DB, not in code. Override per tenant with rationale logged in the audit table.

```sql
CREATE TABLE tenant_deployment_assignment (
    tenant_id        UUID PRIMARY KEY,
    commercial_tier  TEXT NOT NULL,
    deployment_tier  TEXT NOT NULL,
    cluster_id       TEXT,            -- which k8s cluster (for namespace+ tiers)
    region           TEXT,            -- AWS region (for region+ tiers)
    assigned_at      TIMESTAMPTZ NOT NULL,
    assignment_actor UUID NOT NULL,   -- who set this
    rationale        TEXT             -- if override from default mapping
);

CREATE TABLE tenant_deployment_history (
    tenant_id        UUID NOT NULL,
    changed_at       TIMESTAMPTZ NOT NULL,
    actor            UUID NOT NULL,
    old_commercial   TEXT,
    new_commercial   TEXT,
    old_deployment   TEXT,
    new_deployment   TEXT,
    rationale        TEXT,
    PRIMARY KEY (tenant_id, changed_at)
);
```

## Per-tenant isolation primitives

For tiers `namespace` and above, the platform provides:

### Per-tenant Kubernetes namespace

- One namespace per tenant: `tenant-<tenant_id>` or `tenant-<short-name>`.
- Resources within: backend pods, in-namespace DB if dedicated, in-namespace message broker if dedicated.
- Network policy: allow ingress only from the edge namespace; allow egress only to the platform's internal services + the tenant-configured external whitelist.

### Per-tenant secret namespace

- Secret manager (Vault-class) with per-tenant namespace.
- Tenant secrets: their downstream credentials, their signing keys, their TLS certs, their tenant-specific config encryption keys.
- Access: only the tenant's pod can read its own secrets via service-account-bound auth; platform staff access is logged via Backoffice.

### Per-tenant Postgres + Redis (cluster+ tier)

- Dedicated DB cluster per tenant — separate compute, separate storage, separate backups, separate restore path.
- Same engine version across all tenants on a tier; upgrades are coordinated.

### Per-tenant message broker (namespace+ tier)

- Internal command/event bus per tenant — events stay local to the tenant's pod.
- Cross-tenant communication only via the shared external streaming bus (e.g., Kafka-class) at well-defined publish points.

### Per-tenant egress IP (cluster+ tier)

- NAT gateway or SNAT mapping; outbound traffic from the tenant's pod presents a stable per-tenant IP.
- Required for downstream services that allowlist by IP.
- Cost: ~$30-50/mo per static IP plus NAT data processing.

### Per-tenant observability labels

- Every metric, log, trace carries `tenant_id` as a primary label.
- Tenant-scoped dashboards: per-tenant Grafana folders or per-tenant Kibana namespaces.
- Counterparty admin can see their own tenant's observability via Manager UI; platform staff see across.

## Tenant lifecycle

### Onboarding flow

```
1. Sales / self-serve sign-up creates tenants row in control-plane DB
   tenant_id = ulid; commercial_tier = trial; deployment_tier = shared_pod (default)
2. Tenant Operator (k8s controller) sees the new tenant and:
   - For shared_pod: nothing to provision (already a shared pod exists)
   - For namespace+: create namespace, deploy pods, provision DB, create secret namespace
3. Branding pipeline runs (see branding-and-customization.md)
4. Tenant admin invited via email; sets up password + MFA
5. Tenant ready
```

The tenant operator is the central control plane piece — see `operations-and-deployment.md`.

### Tier upgrade migration

Moving from `shared_pod` → `namespace`:

```
1. Sales/Backoffice flips tenant_deployment_assignment.deployment_tier = 'namespace'
2. Tenant Operator detects change and:
   a. Provision new namespace + pod + DB cluster
   b. Schema migration: copy tenant's data from shared DB to dedicated DB
      Use either logical replication or a one-shot copy + cutover
   c. Engine reconciliation: new pod loads state from new DB; old shared pod stops serving for that tenant_id (block list)
   d. DNS / edge router config update: tenant's API requests now route to dedicated pod
   e. Old tenant_id-tagged data in shared pod marked archived (kept for retention period; no longer queryable through the live API)
3. ~5-15 minutes of customer-visible downtime during the cutover (announce in advance)
4. Tenant remains in new tier; commercial_tier may have changed too (sales-driven)
```

Automate this via the control-API. Manual migrations don't scale beyond ~10 tenants.

### Tier downgrade

Rare but possible: a tenant can move from `cluster` back to `shared_pod` if their usage drops or contract changes.

- Same flow in reverse, with extra care: copy tenant's data back into the shared DB; verify; cutover.
- Caveat: if the tenant had per-tenant features (custom SLA, custom endpoints) that aren't supported on the shared tier, the downgrade requires those features to be removed first. Don't auto-downgrade if it implies feature regression.

### Offboarding

```
1. Tenant requests offboarding; sales confirms
2. Tenant data exported to tenant-controlled location (S3, secure download link, etc.)
3. Tenant marked status = offboarding; live API responds 410 Gone
4. After grace period (e.g., 30 days), data deleted from active stores
5. Backups retained per regulatory requirement (typically 7 years for financial; varies)
6. Audit log entry: who, when, why; immutable
```

Document the offboarding flow in the canonical doc; counterparties ask about it during sales.

## What the platform should refuse

Some tenants are not multi-tenant candidates. Refuse early:

- **Tenants requiring a forked codebase.** Per-tenant code branches are an operational nightmare; offer `on_prem` instead.
- **Tenants requiring guaranteed-isolated bare metal.** Not impossible (Kubernetes node affinity + dedicated nodes), but requires a sales conversation.
- **Tenants requiring zero shared infrastructure.** Even the lowest dedicated tier shares the cluster control plane and DNS. If they need air-gapped, they need `on_prem`.
- **Tenants with conflicting jurisdictional requirements.** If two tenants' regulators have contradictory demands on the same physical infrastructure, refuse one or move to `region` for both.

Document the refusal in `explicitly-not` (per `decision-discipline.md`).

## Naming conventions

- `tenant_id` — UUID or ULID; primary key everywhere; never reused after deletion.
- `tenant_short_name` — DNS-safe slug (e.g., `acme-corp`); used in subdomains and cluster namespaces; must be unique; typically lowercase alphanumeric + hyphen, 3-30 chars.
- `tenant_display_name` — human-readable; shown in UIs and emails; not a primary key.

Keep the three separate. The display name changes when the company rebrands; the short name is sticky (DNS depends on it); the tenant_id is forever.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| One column called `tier` | Will silently collide between pricing and infra | Split into `commercial_tier` + `deployment_tier`; document mapping |
| 1000 tenants on one shared pod | Cache thrashing; one tenant's tick burst slows others | Cap shared pod at ~50-200; provision new pods after |
| Shared tier with per-tenant downstream credentials | Allowlist breaks; one tenant's outbound has wrong identity | Shared tier uses platform-owned credentials; tenant-owned credentials require dedicated tier |
| Mix of surface A and surface B in one pod | Different engines, different lifecycles, different isolation | Separate pods per surface |
| Manual provisioning of new tenants | Scales to ~10; falls over after | Automate via Tenant Operator + CRD from day 1 |
| Per-tenant code branches | Maintenance disaster; security drift | Same binary; per-tenant config; refuse if a tenant needs more |
| Tenant data in cross-tenant tables (no `tenant_id` filter) | Bug in `WHERE tenant_id = ?` = cross-tenant data leak | RLS (Postgres row-level security) OR per-tenant schema OR per-tenant DB; defense in depth |
| Shared encryption keys across tenants | One key compromise = all-tenant compromise | Per-tenant data encryption keys (DEK) wrapped by per-tenant KEK |
| Tier downgrade that drops features silently | Tenant complains; data loss | Refuse downgrade until features explicitly disabled |
| Dedicating egress IPs in shared_pod tier | Cost without benefit; tenant assumes isolation that isn't there | Dedicated egress only at `cluster` tier and above |
| Tenant_id in URL path but not validated against token | Cross-tenant access via crafted URL | Always validate URL tenant_id matches token's tenant claim |

## Worked example — five-tier topology for a B2B SaaS

Product: a multi-tenant data platform serving small SaaS startups (free trial), medium enterprises (custom branding, dedicated infra), and large enterprises (own region, own KMS).

Tier topology:

| Tier | Pricing model | Ops investment | Cap |
|---|---|---|---|
| `shared_pod` | Free trial 30 days; then $0 self-serve up to N events/mo | One pod per region; ~100 tenants | 100/pod |
| `namespace` | $500-2,500/mo | One namespace per tenant; shared cluster | Limited by cluster capacity |
| `cluster` | $5k+/mo | Per-tenant DB + Redis + egress IP | Per-cluster scheduler limits |
| `region` | $25k+/mo enterprise contract | Per-tenant cluster in tenant-chosen region | Per-region quota |
| `on_prem` | Annual license | Tenant operates; we ship + support | Sales-driven |

Concrete migration paths:

- `shared_pod` → `namespace`: scheduled, ~10 min downtime, automated; trigger on payment or feature request.
- `namespace` → `cluster`: scheduled, ~30 min downtime, automated; trigger on dedicated DB requirement.
- `cluster` → `region`: weeks of planning, automated migration with custom region steps; trigger on data-residency contract.
- `region` → `on_prem`: months of planning; we ship + train; trigger on a sovereignty/regulatory requirement.

Refused tenants:
- "We need a custom backend feature that none of our tenants get." → `on_prem` with a custom build, separate license.
- "We need 99.999% uptime." → `region` minimum; SLA negotiated; document failure-mode runbooks.
- "We need to share infra with our parent company's data." → out of scope for our product; refuse.

## Cross-references

- `data-plane.md` — for per-tenant DB / Redis / message broker provisioning
- `operations-and-deployment.md` — for the Tenant Operator pattern and CRD
- `edge-and-routing.md` — for tenant routing decisions at the edge
- `decision-discipline.md` — for `commercial_tier` vs `deployment_tier` rename pattern
- `compliance-and-ownership.md` — for tier-driven compliance posture
- `disaster-recovery.md` — for tier-driven RPO/RTO
- `billing-and-commerce.md` — for commercial_tier rate cards
