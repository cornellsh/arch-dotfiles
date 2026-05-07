# Compliance and Ownership

> Loaded when designing the compliance posture: layered ownership model (us / counterparty / optional / explicitly-not), audit log infrastructure, geofencing, data export for regulators, evidence storage, mode-specific compliance behavior.

## What this layer commits to

The compliance layer answers:

1. **Who owns each compliance obligation?** (Layered model)
2. **What does the platform do mandatorily** in every deployment?
3. **What do counterparties do** (their license, their problem)?
4. **What integration framework do we offer** for counterparties who want unified compliance through us?
5. **What do we explicitly NOT do?**
6. **How do we prove compliance posture** to auditors and regulators?

The discipline is the same as `decision-discipline.md`'s ownership-boundary model, applied specifically to compliance. Most compliance failures come from unclear ownership — counterparty thought we did X, we thought they did, nobody did.

## The layered compliance model

Three layers with three different owners:

| Layer | Owner | Examples |
|---|---|---|
| **Platform protection** | Us, mandatory in every deployment | Geofencing, sanctions screening at edge, audit log infrastructure, data export tools, write-once tier |
| **Counterparty compliance** | Counterparty's license / regulatory obligation | Identity verification of end users, suspicious activity reporting, transaction monitoring, tax reporting, source-of-funds checks |
| **Optional integration framework** | We provide rails; counterparty configures | Identity-verification vendor integrations, sanctions list providers, regulatory reporting plugins |

A fourth implicit layer:

| Layer | Owner | Examples |
|---|---|---|
| **Explicitly-not** | Out of scope; we refuse | Acting as a regulated party for the counterparty's end users; making compliance recommendations; assuming the counterparty's regulatory liabilities |

## What WE do (platform-level, mandatory)

These are non-negotiable platform-level protections present in every deployment:

### Country geofencing

Block requests from sanctioned countries at the edge:

- Sanctioned-country IP block (refresh daily from a sanctions-list provider).
- Per-tenant additional country restrictions configurable in Manager UI.
- Implemented as edge filter (WASM/Lua) checking IP against tenant's allowed-country list before routing.

For products where end-user identity is non-account-bound (e.g., signed-message authentication without a registered account): also check against last-known IP geo on each request, since the credential itself doesn't carry country info.

### Sanctions screening

- Daily refresh of sanctions lists from regulator-published sources (multiple jurisdictions).
- IP-level: edge filter blocks at the network layer.
- Identity-level: at user signup or first action, screen the identity against the lists; block on match.
- For products where end users are identified by a non-account-bound credential (signed-message, federated assertion, hardware token): screen the credential identifier against the relevant sanctions databases.
- Block list cached at the edge (Redis); refresh hourly; deny-list pushes invalidate immediately.
- Audit log every block decision with reason.

### Audit log infrastructure

(Detailed in `data-plane.md` and `disaster-recovery.md`.)

- Append-only `audit_events` table with hash-chain tamper-evidence.
- Per-tenant scope; tenant can export their own audit log via Manager.
- Retention typically 7 years for financial; configurable per regulation.
- Subpoena response procedure: Backoffice + Legal; documented runbook.

### Data export for regulators

- Per-tenant export tool: tenant admin self-serves their data for their own regulator.
- Cross-tenant subpoena response: documented procedure with Backoffice + Legal.
- Court order response: legal-hold flag stops automatic deletion; preserves data even past normal retention.
- Every export is itself logged.

### Data residency

For products with regulatory residency requirements:

- EU-classified tenants' data physically resides in EU pods (`region` tier).
- Country-specific compliance modes per tenant where required.

This is `region` tier or higher; not feasible at lower tiers without compromising the multi-tenant model.

### Privacy / right-to-be-forgotten infrastructure

(Cross-references `disaster-recovery.md`.)

- API endpoint for tenant to request deletion of an end user's data.
- 30-day SLA on OLTP deletion; longer for backup propagation.
- Crypto-shredding option for immediate effective deletion.
- Audit log records the deletion request and execution.

## What COUNTERPARTIES do (their license, their problem)

The counterparty carries the regulatory weight for end users they bring to the platform:

- **Identity verification** — confirming an end user's identity (varies by jurisdiction and product class).
- **Transaction monitoring** — surveillance for suspicious patterns.
- **Suspicious activity reporting** — to financial-crimes regulators where applicable.
- **Travel rule** — for financial transfers above threshold (jurisdiction-dependent).
- **Tax reporting** — per-jurisdiction reports the counterparty must file.
- **Source-of-funds verification** — for high-value accounts / risk-tier accounts.
- **PEP screening** — politically-exposed-persons due diligence where required.
- **Account opening due diligence** — risk scoring; enhanced due diligence where required.

The counterparty integrates their own vendor (or builds in-house) for each of these. We don't make the determination; we don't perform the verification.

This is the bucket where most products misallocate ownership. The counterparty's regulator may demand things our infrastructure can't do alone (e.g., source-of-funds verification requires document collection plus human review). Don't promise it.

## OPTIONAL integration framework

For counterparties who want unified compliance through our platform (instead of running each vendor themselves), we offer optional integrations:

```
Manager UI: "Compliance integrations"
  - Pick identity-verification vendor (Vendor A, B, C)
  - Enter API credentials (stored in Vault per-tenant)
  - Configure verification levels (basic / enhanced / institutional)
  - Set country-specific requirements
  - Review verification status mirror
```

What we provide:

- Adapter plumbing (we call the vendor's API; pass results back).
- Status mirror in our DB (for convenience; counterparty's vendor is the source of truth).
- Audit log of compliance events.
- Webhook to counterparty on verification state changes.

What we explicitly DON'T provide:

- Determination of whether a verification result satisfies the counterparty's regulator.
- Liability for the verification accuracy (vendor is the counterparty's choice).
- Recommendations on which vendor to pick.

This is **opt-in**. We don't enforce that counterparties use our integrations; they can run their own vendor pipeline outside our system entirely.

## Mode-specific compliance behavior

Different deployment modes / surfaces have different compliance postures. Document explicitly.

Example matrix (generic):

| End-user mode | Platform action | KYC required by us? | KYC by counterparty? |
|---|---|---|---|
| **Non-account-bound credential** (signed-message etc.) | Geofence + sanctions screen on credential identifier | No (credential carries no identity by design) | Optional, counterparty's choice |
| **Counterparty-custodial** (counterparty holds funds, end user has account) | Same + custody compliance posture | Optional integration framework | Yes, mandatory if counterparty regulated |
| **Live/regulated transactions** (e.g., counterparty operates as a regulated entity) | Same + counterparty compliance evidence | No (we facilitate, don't perform) | Yes, regulator-mandated |
| **Sandbox / demo** | Geofence only | No | No |

The matrix communicates: same platform, different compliance requirements depending on the mode the end user is in.

## What we explicitly DON'T do

Document this section explicitly in the canonical doc:

- ❌ Verify end-user identity (counterparty's responsibility)
- ❌ Custody end-user funds (except where the architecture explicitly provides custody primitives)
- ❌ Surveillance / transaction monitoring of end-user activity (counterparty)
- ❌ Suspicious activity report filing (counterparty)
- ❌ Tax reporting to authorities (counterparty)
- ❌ Source-of-funds investigation (counterparty)
- ❌ Determine whether a counterparty's compliance posture satisfies their regulator (their and their counsel's call)
- ❌ Recommend specific compliance vendors

These are counterparty responsibility. We're a SaaS infrastructure provider; the explicit list keeps both sides honest.

## Compliance evidence storage

For our own protection, we store evidence of counterparties' compliance posture:

```sql
CREATE TABLE compliance_evidence (
    id              CHAR(26) PRIMARY KEY,
    tenant_id       UUID NOT NULL,
    evidence_kind   TEXT NOT NULL,                -- 'license_certificate', 'regulator_registration', 'kyc_vendor_contract', 'soc2_report', etc.
    document_url    TEXT NOT NULL,                -- S3 reference (encrypted)
    expires_at      DATE,
    submitted_by    UUID NOT NULL,
    submitted_at    TIMESTAMPTZ NOT NULL,
    verified_by     UUID,                          -- platform staff
    verified_at     TIMESTAMPTZ,
    verification_notes TEXT,
    INDEX (tenant_id, evidence_kind)
);
```

Backoffice operator reviews and verifies evidence at:

1. **Tenant onboarding** — license certificate, regulator registration, vendor contracts.
2. **Annual review** — refresh; check expirations.
3. **On request** — when a regulator asks us about a counterparty.

Helps demonstrate we acted in good faith if a counterparty later violates.

## Tier-driven compliance posture

Different tiers get different compliance expectations:

| Tier | Compliance offering |
|---|---|
| `shared_pod` (trial) | Platform-mandatory only; no counterparty-side evidence required at signup |
| `namespace` (self-serve, branded) | Platform-mandatory + evidence collection at onboarding |
| `cluster` (dedicated) | Above + audit-log retention to counterparty's spec + per-tenant region option |
| `region` (enterprise) | Above + BYOK + data residency + annual third-party audit |
| `on_prem` | Above + we ship + support + counterparty operates everything |

Document per-tier compliance offerings in the canonical doc; sales references it directly.

## Subpoena and legal-process response

Documented procedure:

```
1. Subpoena/court order received → Legal triages
2. Determine: is this for one tenant's data, cross-tenant, or platform-level?
3. Notify affected tenants (unless gag order forbids)
4. Backoffice operator pulls relevant data via export tool
5. Legal review of response before delivery
6. Delivery via secure channel (signed URL, attorney-eyes-only)
7. Audit log entry for the subpoena response
```

The audit log entry is itself important — if a regulator later asks "did you respond to subpoena X?", we have the record.

## GDPR / privacy regulation specifics

Without enumerating every regulation, the platform must:

1. **Lawful basis for processing** — documented per processing activity.
2. **Data subject rights** — access, rectification, deletion, portability — implemented as Manager UI features for counterparties to invoke on behalf of end users.
3. **Data Processing Agreement (DPA)** — template for counterparties; we sign as processor; they remain controller.
4. **Breach notification** — 72-hour response capability; on-call playbook.
5. **Records of processing** — what we process, why, retention; documented in the canonical doc and the privacy policy.

Each of these is a specific operational capability the platform must build, not a paragraph in a privacy policy.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Promising counterparty-side compliance ("we'll handle KYC") | Liability transfer; we can't deliver; legal exposure | Layered model; explicit ownership |
| No "explicitly-not" list | Same scope re-litigated every quarter | Document explicit non-coverage |
| Audit log without tamper-evidence | Fails compliance audit | Hash-chain + Object Lock |
| Geofencing in code, not config | Updates require deploys | Config-driven with per-tenant overrides |
| Evidence storage without expiry tracking | Stale licenses go unnoticed | `expires_at` column; alert at 30/60/90 days |
| Data residency assumed instead of enforced | Cross-region data leak | Region pinning enforced at infra level (cluster scheduling) |
| Privacy regulations as legal-team-only concern | Engineering-side capabilities missing (data export, deletion APIs) | Build the APIs; legal documents what they enforce |
| Optional integration framework treated as mandatory | Counterparties feel locked in | Truly optional; can be disabled per tenant |
| Compliance vendor recommendations to counterparties | We're not their counsel | Don't recommend; let them choose |
| Subpoena response without audit | Future "did you respond?" question can't be answered | Audit every legal-process response |
| Single-region for all data | Customer with EU residency requirement can't be onboarded | `region` tier enables multi-region; document tier-driven |
| Tenant lifecycle deletion without considering audit retention | Compliance gap; or legal-hold violation | Document: delete OLTP, retain audit logs, retain backups within window |

## Worked example — compliance posture for a B2B platform

Layered model (concrete):

**Us-mandatory:**
- Geofence at edge (sanctioned countries blocked)
- Sanctions screening (daily refresh; IP + identity + credential-identifier screen)
- Audit log (hash-chained, 7-year retention)
- Data export tool for tenant self-service to their regulator
- Subpoena response procedure
- Right-to-be-forgotten API
- Encryption at rest + in transit
- Platform-level SOC 2 / ISO 27001 controls

**Counterparty-domain:**
- Identity verification of their end users
- Transaction monitoring + suspicious activity detection
- Tax reporting (1099-equivalent per jurisdiction)
- Travel rule (where applicable)
- Source-of-funds for high-value accounts
- PEP screening
- Compliance vendor selection

**Optional integration:**
- Identity-verification vendor adapters (Vendor A, B, C)
- Sanctions list provider adapters
- Regulatory reporting plugins

**Explicitly-not:**
- We do not act as a regulated party for the counterparty's end users
- We do not make compliance determinations for the counterparty
- We do not recommend compliance vendors
- We do not assume the counterparty's regulatory liabilities

Tier-driven compliance:

- shared_pod: platform-mandatory only
- namespace: + evidence collection
- cluster: + audit retention to counterparty spec + per-tenant region
- region: + BYOK + data residency + annual audit
- on_prem: + customer operates

Mode-specific (for products with multiple end-user modes):

| Mode | Identity verification by us? | Identity verification by counterparty? |
|---|---|---|
| Non-account-bound credential | No | Optional |
| Counterparty-managed account | No | Yes if counterparty regulated |
| Live/regulated transaction | No | Yes regulator-mandated |
| Sandbox/demo | No | No |

Documented in the canonical doc explicitly so sales, legal, and engineering align.

`OPEN:` markers:
- `OPEN: SOC 2 Type II audit timing — Type I in Phase 1 first 6 months; Type II at end of Phase 1. Owner: compliance lead.`
- `OPEN: BYOK rollout — currently scoped to region tier; consider exposing at cluster tier if a customer requires it. Switch on first such ask. Owner: same.`

## Cross-references

- `decision-discipline.md` — for the four-bucket ownership model this layer applies
- `data-plane.md` — for audit-events table schema
- `disaster-recovery.md` — for audit retention and write-once tier
- `multi-tenancy.md` — for tier-driven compliance posture
- `operations-and-deployment.md` — for evidence storage in control-plane DB
- `edge-and-routing.md` — for geofencing implementation
