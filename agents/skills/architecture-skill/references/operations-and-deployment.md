# Operations and Deployment

> Loaded when designing how the platform is deployed, scaled, observed, and operated: k8s + CRD + operator pattern, GitOps, per-tenant secret namespacing, observability stack, exposure tiering, living-doc cadence.

## What this layer owns

The operations layer is the control plane: how new tenants get provisioned, how config changes propagate, how secrets are managed, how the system is observed, and how the doc itself stays accurate.

It contrasts with the per-tenant data plane (`data-plane.md`) — operations is about *how the platform runs*, not what end users see.

## The k8s + CRD + Operator pattern

For multi-tenant SaaS at scale, the dominant pattern is:

1. **Kubernetes** as the container orchestrator.
2. A **Custom Resource Definition (CRD)** named something like `Tenant` that captures the desired state of a tenant.
3. A **custom Operator** (k8s controller) that watches `Tenant` resources and reconciles cluster state.

```yaml
apiVersion: platform.example.com/v1
kind: Tenant
metadata:
  name: acme-corp
spec:
  commercial_tier: branded
  deployment_tier: namespace
  region: us-east-1
  branding:
    primary_color: "#1a73e8"
    logo_url: "https://cdn.platform.com/branding/acme-corp/logo.svg"
  surfaces:
    primary_product:
      enabled: true
      version: "v1.4.2"
  webhooks:
    - url: "https://acme.example.com/webhooks/platform"
      event_kinds: ["order.*", "account.*"]
```

The Operator reconciles by:

1. Reading the desired state from the CRD.
2. Comparing to actual state (namespaces, deployments, secret namespaces, DNS entries, webhooks).
3. Creating/updating/deleting resources to converge.
4. Emitting events for observability.
5. Reporting status back to the CR.

Status block:

```yaml
status:
  phase: ready                    # provisioning | ready | upgrading | failed | offboarding
  observed_generation: 4
  conditions:
    - type: NamespaceReady
      status: "True"
      reason: NamespaceCreated
      lastTransitionTime: "2026-01-01T12:00:00Z"
    - type: DBReady
      status: "True"
      reason: DBProvisioned
    - type: BrandingApplied
      status: "True"
      reason: ThemeShipped
```

### What the Operator manages

For each `Tenant` CR (depending on `deployment_tier`):

| Resource | shared_pod | namespace | cluster | region |
|---|---|---|---|---|
| k8s Namespace | shared | per-tenant | per-tenant | per-tenant in target region |
| Backend Deployments + Services | shared | per-tenant | per-tenant | per-tenant |
| Postgres StatefulSet (or managed DB) | shared | shared / schema | per-tenant | per-tenant |
| Redis | shared | shared / prefix | per-tenant | per-tenant |
| Message broker | shared | per-tenant or shared | per-tenant | per-tenant |
| NetworkPolicy | shared | per-tenant ingress/egress | per-tenant | per-tenant |
| Secret namespace | shared | per-tenant | per-tenant | per-tenant |
| DNS record | shared | per-tenant | per-tenant | per-tenant |
| TLS cert (for custom domain) | shared via SaaS CDN | per-tenant via SaaS CDN | same | same |
| Per-tenant egress IP | n/a | n/a | per-tenant SNAT | per-tenant SNAT |
| Webhook config | shared | per-tenant | per-tenant | per-tenant |

The Operator does NOT manage:
- Cross-tenant infrastructure (the cluster itself, shared OLAP, shared message bus).
- Per-tenant business logic (that's in the application code; Operator just deploys the binary).
- Counterparty data (that lives in the per-tenant DB).

## GitOps as the deployment model

All cluster state declared in Git; an agent (Argo CD, Flux) reconciles the cluster to match Git.

Repository layout:

```
platform-infra/
├─ clusters/
│   ├─ prod-us-east-1/
│   │   ├─ apps/
│   │   │   ├─ tenant-operator/
│   │   │   ├─ identity-api/
│   │   │   ├─ control-api/
│   │   │   └─ ...
│   │   └─ infrastructure/
│   │       ├─ ingress/
│   │       ├─ observability/
│   │       └─ ...
│   ├─ prod-eu-west-1/
│   └─ staging/
└─ shared/
    ├─ helm-charts/
    └─ kustomize-bases/
```

Discipline:

- No `kubectl apply` outside emergencies; every change is a git commit + PR + merge.
- Argo CD reconciles every 3-5 minutes (configurable per app).
- Drift between Git and cluster is alerted; manual changes are squashed.
- Rollback = git revert + Argo sync.
- Per-app sync windows for sensitive components (e.g., DB schema migrations apply only during maintenance windows).

## Per-tenant secret namespacing

Secret manager (Vault-class) with per-tenant namespaces:

```
secret/
├─ platform/                       # platform-owned secrets
│   ├─ identity/
│   ├─ database/
│   └─ ...
├─ tenants/
│   ├─ <tenant_id>/
│   │   ├─ downstream_credentials/    # tenant's vendor API keys
│   │   ├─ webhook_signing_secret/
│   │   ├─ tls_cert/                  # for custom domain
│   │   └─ ...
│   └─ ...
└─ shared/                         # cross-tenant infra secrets
    ├─ shared_db/
    └─ ...
```

Access policy:

- The tenant's pod has a service account; service account is bound to the tenant's secret namespace.
- Pod can read its own secrets only; not other tenants', not platform's.
- Platform staff access is logged via Backoffice with reason and dual-control for production secrets.

Rotation:

- Platform-owned secrets: 90-day rotation cycle; automated.
- Tenant-owned secrets: tenant initiates via Manager UI; old secret valid for 7-day overlap.

## Observability stack

The stack class (LGTM = Loki + Grafana + Tempo + Mimir, or equivalent ELK-class, or vendor SaaS):

- **Logs** — structured (JSON), shipped from every pod, indexed by tenant_id + service + level.
- **Metrics** — Prometheus-compatible scraping; long-term storage in Mimir/equivalent; per-tenant labels.
- **Traces** — OpenTelemetry; sampled (5-10% of requests; 100% of errors); shipped to Tempo/equivalent.
- **Dashboards** — Grafana; per-tenant folders for counterparty admin views; cross-tenant for platform staff.

### Per-tenant labeling

Every metric, log, trace carries `tenant_id` as a primary label. This is the difference between an observability stack that scales to multi-tenancy and one that doesn't.

```
http_requests_total{tenant_id="acme-corp", service="customer-api", method="POST", status="200"}
```

Standard labels:

- `tenant_id` — required on all tenant-scoped data
- `service` — service name
- `pod` — k8s pod name (cardinality concern at scale; rotate)
- `region` — cloud region
- `environment` — prod/staging/dev

Avoid high-cardinality labels like `user_id` or `request_id` in metrics (use traces for those).

### Standard SLO targets

For a typical B2B SaaS:

| Metric | Target | Window |
|---|---|---|
| Availability (read endpoints) | 99.9% | 30 days |
| Availability (write endpoints) | 99.5% | 30 days |
| p99 read latency | < 200ms | 5 minutes |
| p99 write latency | < 500ms | 5 minutes |
| Error rate (5xx) | < 0.1% | 5 minutes |

Per-tier SLOs are more aggressive (enterprise tier may demand 99.99% with named CSM); shared_pod tier is more lax. Document per-tier SLOs explicitly.

Alerting on SLO burn rate (multi-window multi-burn-rate alerts) — alert when burn rate exceeds 14.4x for 1h or 6x for 6h. This is more nuanced than single-threshold alerting and reduces noise.

## Service exposure model — three tiers

(Cross-references `api-design.md` and `edge-and-routing.md`; consolidated here for ops-side view.)

### Public

End users reach these directly through the edge.

| Service | URL | Audience |
|---|---|---|
| UI assets | `app.platform.com` and custom domains | End users |
| API gateway | `api.platform.com`, `live.api.platform.com` | Bots, mobile, web |
| Identity portal | `id.platform.com` | All users; profile, MFA, sessions |
| Marketing | `platform.com` and per-tenant custom domain root | Public |
| Status page | `status.platform.com` | Public |
| Public docs | `docs.platform.com` | Developers |

### Internal (cluster-internal only)

| Service | Access | Purpose |
|---|---|---|
| identity-api | mTLS-authed services within cluster | Token issuance, validation, account management. NEVER public. |
| control-api | Backoffice frontend + cluster-internal | Tenant lifecycle, billing, audit aggregator |
| Tenant Operator | k8s controller | Watches `Tenant` CRDs; reconciles |
| Vault / Secret manager | Cluster-internal mTLS | Secret store |
| Argo CD API | Internal staff VPN only | GitOps |
| Message broker | Cluster-internal | Per-tenant + shared |
| Engine pods (per-tenant) | Cluster-internal | Domain logic; only same-namespace services talk to them |
| Postgres / Redis / OLAP / archive | Cluster-internal | Data layer |

### Counterparty-facing

| Service | URL | Auth |
|---|---|---|
| customer-api / customer-api (Connect-RPC + WS) | `live.api.platform.com` (anycast) with tenant header | OAuth2 user token |
| manager-api | `manager-api.platform.com` shared host | OAuth2 staff token |
| webapi (REST) | `live-<tenant>.webapi.platform.com:8443` | OAuth2 client_credentials per-tenant |

Per-tenant subdomain for webapi gives the counterparty a stable hostname for their CRM/backend integration. Shared host for manager-api because it's accessed from a browser tied to a session.

## Living-doc cadence

The canonical doc rots without explicit cadence. Embed it in operations:

### Monthly architecture re-read

- Lead architect (or designee) reads the canonical doc top-to-bottom.
- Asks: does the description still match reality? Any `OPEN:` ready to close? Any `DECIDED:` under pressure?
- Output: a short writeup with PRs to update the doc.
- Cadence: monthly is enough; quarterly is too rare; weekly is too noisy.

### Quarterly drift audit

Compare doc claims against reality:

- Service map vs `kubectl get deployments`
- Glossary terms vs current team vocabulary
- Ownership boundaries vs incident-response ownership
- SLO targets vs observed metrics

Each discrepancy is either a doc bug (PR to update) or a behavior bug (file ticket).

### Onboarding loop

Every new hire reads the canonical doc as part of onboarding. After two weeks:

- What was confusing or contradictory?
- What did you learn from someone else that wasn't in the doc?
- What would you cut?

Their feedback drives the next monthly re-read. New hires are the cheapest reality check.

### Doc supersession workflow

When a new doc replaces older ones:

1. New doc has an explicit "Supersedes:" clause naming what it replaces.
2. Superseded docs get a redirect notice at the top: *"Superseded on YYYY-MM-DD by `<new-doc>`."*
3. Superseded docs moved to `archive/` directory; not deleted (history matters).
4. All internal links updated (search wiki, READMEs, runbooks).

Without explicit supersession, stale docs continue to be cited in onboarding and PR reviews.

## Deployment cadence and safety

Standard practices for safe deployment at multi-tenant scale:

| Practice | What |
|---|---|
| Canary | Deploy to 5% of pods first; observe for 15min; promote if SLOs hold |
| Tier-based rollout | shared_pod tier first (low blast radius); then namespace; then cluster; then region |
| Feature flags for risky features | New features behind a flag; ramp tenant-by-tenant |
| DB schema migrations | Backwards-compatible; multi-step (add column → backfill → use → remove old column over multiple releases) |
| Rollback plan per release | Documented; rehearsed quarterly |
| Maintenance windows for breaking ops | Communicated 7+ days in advance; tier-aware scheduling |

CI/CD pipeline:

```
PR opened → tests + lint + spec validation
PR merged → build → push image → update GitOps repo → Argo syncs to staging
Staging passes → manual promote to canary
Canary holds 15min → auto-promote to full prod
```

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Manual `kubectl apply` for prod changes | Drift; lost changes on next reconcile | GitOps; emergency only with audit |
| Tenant Operator deferred until 10+ tenants | Scaling falls off a cliff; manual provisioning becomes the bottleneck | Build the Operator early; Phase 1 |
| Secrets in environment variables in CRDs | Plaintext at rest in etcd | Vault references; CRD has refs only |
| Logs without `tenant_id` label | Per-tenant debugging requires grep across all logs | Label everything |
| Metrics with high-cardinality labels (`user_id`, `request_id`) | Cardinality explosion; metric backend OOMs | Use traces for high-cardinality; metrics for aggregates |
| One Argo CD app for everything | Sync errors block all changes | One app per service or per logical group |
| GitOps repo with prod credentials in cleartext | Repo compromise = total | Sealed secrets; SOPS; Vault refs only |
| Manual cert renewal | Renewal forgotten; outage at expiry | ACME + cert-manager; alerts at 7-day countdown |
| No drift audit | Doc and reality diverge silently | Quarterly drift check; treat each gap as a bug |
| Per-tenant Vault namespaces shared by accident | Tenant A reads Tenant B's secrets | Test the isolation; review service account bindings |
| Backoffice without audit | Platform staff actions unlogged | Every Backoffice action audited; reason field required |
| Deploys at peak traffic | Highest blast radius | Off-peak windows; tier-based rollout |
| No canary | Bug ships to 100% before detection | Canary 5%; auto-promote on green |

## Worked example — operations stack for a B2B SaaS

Cluster topology:

- **Production:** 3 regions (us-east-1, eu-west-1, ap-southeast-1); each has its own k8s cluster; 15-30 nodes per cluster mixing m5.xlarge for general workload and m5.4xlarge for OLAP nodes.
- **Staging:** 1 cluster, mirror of production us-east-1, smaller scale.
- **Dev:** local k3d / kind for engineers.

Control plane (per cluster):

- Tenant Operator (k8s controller, written in Go using kubebuilder)
- Argo CD for GitOps reconciliation
- Vault for secrets
- LGTM stack for observability
- cert-manager + external-dns for ingress automation

Per-tenant data plane (provisioned by Operator):

- Per-tenant k8s namespace
- Engine, customer-api, manager-api, webapi pods
- Per-tenant Postgres + Timescale (cluster+ tier) or shared Postgres + RLS (shared_pod)
- Per-tenant Redis (cluster+) or shared Redis with prefix (shared)
- Per-tenant NATS (namespace+) or shared NATS (shared_pod)
- Per-tenant NetworkPolicy: ingress from edge namespace only; egress to internal services + tenant's allowlisted external services

Shared infrastructure (per cluster):

- ClickHouse cluster, sharded
- Kafka cluster, 3 brokers
- S3 buckets (one shared bucket with per-tenant prefix; alternative: per-tenant bucket at cluster+ tier)

Observability:

- Logs to Loki, retained 30d hot, 1y cold
- Metrics to Mimir, retained 13 months
- Traces to Tempo, sampled 5%, retained 7d
- Grafana per-tenant folders for counterparty admin dashboards
- PagerDuty on SLO burn rate; per-team escalations

CI/CD:

- GitHub Actions for build/test
- ArgoCD for deployment
- Canary via Argo Rollouts
- Manual promote to prod from staging after 24h soak

`OPEN:` markers:

- `OPEN: multi-region active-active for OLTP — currently active-passive with 4h failover RPO. Switch to active-active if first enterprise contract requires <5min RPO. Owner: data-platform lead. Decide-by: first enterprise contract.`
- `OPEN: vendor SaaS observability vs self-hosted LGTM — currently self-hosted. Switch if monthly ops time on observability exceeds 1 FTE OR cost crosses $50k/mo. Owner: SRE lead.`

## Cross-references

- `multi-tenancy.md` — for the deployment-tier spectrum the Operator implements
- `data-plane.md` — for what the Operator provisions per-tenant
- `edge-and-routing.md` — for cert-manager + external-dns + DNS automation
- `disaster-recovery.md` — for the runbooks the on-call uses
- `compliance-and-ownership.md` — for audit-log infrastructure as us-mandatory
- `decision-discipline.md` — for living-doc cadence
