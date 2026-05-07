# Symptom Map

> Loaded as an index when you have a smell, anti-pattern, or specific concern in a draft and need to find the right reference and remedy.

## How to use

Match by symptom first. Look up the row; load the named reference; apply the remedy. Mode column: `0` = greenfield, `R` = retrofit, `0+R` = both.

## Layered symptom map

### Edge / routing layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Edge filter doing token validation cryptographically | 0+R | Move to backend; edge does shape-validation only | edge-and-routing |
| Body parsing at edge for routing decisions | 0+R | Route on headers/path/hostname; body parsing is service-side | edge-and-routing |
| Per-tenant edge config files | 0+R | Tenant routing via lookup table fed by control-API; one edge config | edge-and-routing |
| Auto-renew certs without alerting | 0+R | Alert at 30/7 days remaining; page at 48h | edge-and-routing |
| Internal services with `if not internal then 403` | 0+R | No public listener; rely on network policy as primary defense | edge-and-routing, operations-and-deployment |
| Rate-limit budgets in code | 0+R | Budgets in config; reload-able; per-tier from control plane | edge-and-routing |
| Anycast accelerator before measuring need | 0+R | Benchmark first; add when measured RTT > X | edge-and-routing |
| No geofencing | 0+R | Sanctioned-country IP block at edge | edge-and-routing, compliance-and-ownership |

### Identity / auth layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Identity service publicly exposed | 0+R | Internal only; mediated by API services | identity-and-auth, operations-and-deployment |
| Long-lived bearer tokens for bots | 0+R | API keys for bots; bearer for UI; same identity | identity-and-auth, api-design |
| Storing API keys plaintext | 0+R | Hash with bcrypt/argon2id; show key once at creation | identity-and-auth |
| MFA optional for tenant admins | 0+R | Mandatory for admin classes | identity-and-auth |
| Authorization decisions at identity | 0+R | Auth-N at identity; auth-Z at services | identity-and-auth |
| Session timeouts not enforced | 0+R | Idle + absolute timeout; revocation cache | identity-and-auth |
| Token format embeds tenant in `sub` | 0+R | `sub` is user; `tenant_id` is separate claim | identity-and-auth |
| Account-link manual merging automated | 0+R | Manual review; double-confirm; audit log | identity-and-auth |
| URL tenant_id not validated against token | 0+R | Always validate URL tenant matches token tenant | identity-and-auth |

### Multi-tenancy layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Single column called `tier` | 0+R | Split into `commercial_tier` + `deployment_tier`; document mapping | multi-tenancy, decision-discipline |
| 1000 tenants on one shared pod | 0+R | Cap shared pod at ~50-200; provision new pods | multi-tenancy |
| Shared tier with per-tenant downstream credentials | 0+R | Shared = platform-owned credentials; tenant-owned require dedicated tier | multi-tenancy |
| Manual tenant provisioning | 0+R | Tenant Operator + CRD from day 1 | multi-tenancy, operations-and-deployment |
| Per-tenant code branches | 0+R | Same binary; per-tenant config; refuse forks | multi-tenancy |
| Tenant data in cross-tenant tables without `tenant_id` filter | 0+R | RLS OR per-tenant schema OR per-tenant DB; defense in depth | multi-tenancy, data-plane |
| Shared encryption keys across tenants | 0+R | Per-tenant DEKs wrapped by per-tenant KEK | multi-tenancy, disaster-recovery |
| Tier downgrade dropping features silently | 0+R | Refuse downgrade until features explicitly disabled | multi-tenancy |
| Dedicated egress IPs in shared_pod tier | 0+R | Dedicated egress only at cluster+ tier | multi-tenancy |

### Data plane layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| `tenant_id` column missing on tenant-scoped table | 0+R | Schema-level enforcement; CI check; RLS or per-tenant schema/DB | data-plane |
| Sequential integer IDs in public APIs | 0+R | ULIDs (or UUIDv7) | data-plane, api-design |
| Auditing as triggers on every table | 0+R | Audit via outbox at the application level | data-plane, messaging-and-events |
| Storing money as float | 0+R | DECIMAL(18,8) or higher; never float | data-plane, api-design |
| Time-series in vanilla Postgres tables | 0+R | Timescale hypertables OR dedicated TS store | data-plane, caching-and-storage |
| Settings + feature flags conflated in same table | 0+R | Separate stores per class | data-plane |
| `deleted_at` set without preserving prior state | 0+R | Audit-events table records the delete | data-plane |

### Caching / storage layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Cache as primary store | 0+R | Cache reads only; writes through to OLTP | caching-and-storage |
| L1 cache without bound | 0+R | Bounded LRU | caching-and-storage |
| Redis without eviction policy | 0+R | `maxmemory-policy allkeys-lru` | caching-and-storage |
| Reading from OLAP for transactional flows | 0+R | OLTP for transactional; OLAP for analytics | caching-and-storage |
| No retention policies | 0+R | Tier-based retention; documented policies | caching-and-storage, disaster-recovery |
| Cache TTL = 0 | 0+R | Pick a TTL; profile; tune | caching-and-storage |
| Cache stampede unhandled | 0+R | Single-flight or stale-while-revalidate | caching-and-storage |
| One Redis for cache + queue + session | 0+R | Separate at scale | caching-and-storage |
| Audit log in mutable storage | 0+R | Write-once tier (Object Lock) | caching-and-storage, disaster-recovery, compliance-and-ownership |

### Messaging / events layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Direct service-to-service HTTP without backoff | 0+R | Async via internal bus; circuit breakers | messaging-and-events |
| Writing to broker without outbox | 0+R | Outbox pattern | messaging-and-events |
| One Kafka topic for everything | 0+R | Topic per resource_kind | messaging-and-events |
| Global event ordering | 0+R | Per-aggregate ordering only | messaging-and-events |
| Webhook dispatcher inline with API | 0+R | Async via outbox; never inline | messaging-and-events |
| Webhook delivery without HMAC | 0+R | HMAC always; timestamp + nonce | messaging-and-events |
| Indefinite webhook retry | 0+R | 24-hour cap; explicit DLQ; counterparty alert | messaging-and-events |
| One Kafka consumer group for all tenants | 0+R | Per-tenant consumer groups | messaging-and-events |
| Consumer not idempotent | 0+R | Dedup on `event_id` OR idempotent business logic | messaging-and-events |
| Mixing commands and events on same bus | 0+R | Two buses (internal + external) | messaging-and-events |

### API design layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Public API mirrors internal model 1:1 | 0+R | Collapse internal richness at the boundary | api-design, decision-discipline |
| Sequential integer IDs in URLs | 0+R | ULIDs with type prefix (URN form) | api-design |
| No `intent_id` on POST endpoints | 0+R | Caller-supplied keys; 24h server retention | api-design |
| Float for monetary fields | 0+R | Decimal strings | api-design, data-plane |
| 200 response for failures | 0+R | Use HTTP status correctly | api-design |
| Generic 500 for all server errors | 0+R | Body code (`internal_error`, `temporarily_unavailable`) | api-design |
| Streaming endpoint with no reconnect contract | 0+R | Documented heartbeat + backoff + resumption | api-design |
| Offset pagination for unbounded resources | 0+R | Cursor pagination | api-design |
| OpenAPI spec drifts from code | 0+R | Spec generated from code; CI enforces parity | api-design |
| Versioning by header without rules | 0+R | URL versioning for breaking; additive otherwise | api-design |
| Internal taxonomy in error codes | 0+R | Stable taxonomy; map internal failures to external | api-design |
| HMAC without timestamp | 0+R | Always include timestamp; reject if > 5min old | api-design, messaging-and-events |
| Cross-account ops in one call | 0+R | One account per call; counterparty issues parallel | api-design |

### Operations / deployment layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Manual `kubectl apply` for prod | 0+R | GitOps; emergency only with audit | operations-and-deployment |
| Tenant Operator deferred until 10+ tenants | 0+R | Build the Operator early; Phase 1 | operations-and-deployment, multi-tenancy |
| Secrets in env vars in CRDs | 0+R | Vault references; CRD has refs only | operations-and-deployment |
| Logs without `tenant_id` label | 0+R | Label everything | operations-and-deployment |
| Metrics with high-cardinality labels (user_id, request_id) | 0+R | Use traces for high-cardinality | operations-and-deployment |
| Manual cert renewal | 0+R | ACME + cert-manager; alerts at countdown | operations-and-deployment, edge-and-routing |
| No drift audit | R | Quarterly drift check | operations-and-deployment, decision-discipline |
| Backoffice without audit | 0+R | Every Backoffice action audited | operations-and-deployment, compliance-and-ownership |
| Deploys at peak traffic | 0+R | Off-peak; tier-based rollout | operations-and-deployment |
| No canary | 0+R | Canary 5%; auto-promote on green | operations-and-deployment |

### Disaster recovery layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Backups never tested | 0+R | Weekly/monthly/quarterly drills | disaster-recovery |
| Same-region only backups | 0+R | Cross-region replication for cluster+ tier | disaster-recovery |
| Encrypted backups with single-region key | 0+R | Cross-region key replication | disaster-recovery |
| Audit log mutable | 0+R | App-level append-only + DB GRANT revocation + S3 Object Lock | disaster-recovery, data-plane |
| Schema migrations without rollback | 0+R | Backwards-compatible; multi-step | disaster-recovery, operations-and-deployment |
| RTO/RPO undocumented | 0+R | Document per-tier; in SLA | disaster-recovery, multi-tenancy |
| Failover untested | 0+R | Quarterly drills | disaster-recovery |
| Right-to-be-forgotten ambiguous on backups | 0+R | Document explicitly; consider crypto-shredding | disaster-recovery, compliance-and-ownership |
| KMS keys in same region as data | 0+R | Cross-region key replication | disaster-recovery |
| Long DNS TTL during failover | 0+R | Reduce TTL preemptively before maintenance | disaster-recovery |
| Backups not encrypted at rest | 0+R | KMS-encrypted always | disaster-recovery |

### Compliance / ownership layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Promising counterparty-side compliance | 0+R | Layered model; explicit ownership | compliance-and-ownership, decision-discipline |
| No "explicitly-not" list | 0+R | Document explicit non-coverage | compliance-and-ownership, decision-discipline |
| Audit log without tamper-evidence | 0+R | Hash-chain + Object Lock | compliance-and-ownership, disaster-recovery |
| Geofencing in code, not config | 0+R | Config-driven with per-tenant overrides | compliance-and-ownership, edge-and-routing |
| Evidence storage without expiry tracking | 0+R | `expires_at` column; alert at countdown | compliance-and-ownership |
| Privacy regulation as legal-only concern | 0+R | Build the APIs (export, deletion); legal documents | compliance-and-ownership |
| Optional integration framework treated as mandatory | 0+R | Truly optional; can be disabled per tenant | compliance-and-ownership |
| Subpoena response without audit | 0+R | Audit every legal-process response | compliance-and-ownership |

### Billing / commerce layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| In-app billing for enterprise contracts | 0+R | Out-of-band for higher tiers | billing-and-commerce |
| Per-account fee without "created vs active" | 0+R | Carryover rule + 2-month streak | billing-and-commerce |
| Demo accounts billable | 0+R | Demo accounts always free | billing-and-commerce |
| Subscription status only in CRM | 0+R | Replicate to platform DB; CRM is source of truth | billing-and-commerce |
| Manual invoice in code | 0+R | Out-of-band invoice via accounting tool | billing-and-commerce |
| Revenue-share without daily reconciliation | 0+R | Daily worker; alert on drift | billing-and-commerce |
| Platform processing end-user payments | 0+R | Counterparty's PSP; platform doesn't touch | billing-and-commerce, compliance-and-ownership |
| One pricing model across products | 0+R | Per-product billing dimensions | billing-and-commerce |
| Tier features defined in code | 0+R | Feature entitlements in DB; loaded at runtime | billing-and-commerce, multi-tenancy |
| No graceful PAST_DUE | 0+R | Banner → grace → SUSPENDED → CANCELLED with notice | billing-and-commerce |

### Branding / customization layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Branding in code; deploy to change | 0+R | DB-driven; runtime theming or build pipeline | branding-and-customization |
| No branding review workflow | 0+R | 4-eyes review gate | branding-and-customization |
| Same review process for trial and enterprise | 0+R | Tier-driven; self-serve at low tiers | branding-and-customization |
| Manual binary signing | 0+R | Automated build + sign pipeline | branding-and-customization |
| No auto-update for desktop apps | 0+R | Updater endpoint per tenant; signed manifests | branding-and-customization |
| Custom-domain provisioning manual | 0+R | API-driven; automated ACME | branding-and-customization, edge-and-routing |
| Theme JSON cached aggressively | 0+R | TTL ≤ 5 min; or invalidate on update | branding-and-customization |

### Build sequencing layer

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Single architecture diagram | 0+R | All five zooms + MVP cut + cross-phase invariants | build-sequencing |
| 30-second view with 12 boxes | 0+R | Cut to 5 | build-sequencing |
| Z2 without status flags | 0+R | ✅ / 🚧 / 📋 / 🌌 on every box | build-sequencing |
| No Z3 trace | 0+R | Trace dominant request end-to-end | build-sequencing |
| Z4 omitted | 0+R | Draw the DAG; check sprint plan against it | build-sequencing |
| Z5 numbers without ±range | 0 | Apply bound discipline; "outside means..." | build-sequencing, decision-discipline |
| MVP cut absent | 0+R | Pre-answer with cuts + costs | build-sequencing |
| Cross-phase invariants not enumerated | 0 | List 5+ invariants explicitly | build-sequencing |
| Phase ordering without rationale | 0 | Write rationale + kill criteria | build-sequencing |
| Estimates without "outside" clause | 0 | Numbers must be falsifiable | build-sequencing, decision-discipline |

### Decision discipline (cross-cutting)

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| "We will revisit later" with no criterion | 0+R | `OPEN:` with switch criterion + decide-by + interim default + owner | decision-discipline |
| Feature listed without owner | 0+R | Four-bucket ownership model first | decision-discipline |
| "Industry-standard" cited with no source | 0+R | Cite + mark reference vs dependency | decision-discipline |
| Decision as preference, not falsifiable | 0+R | "A unless (b) or (c) by milestone M" | decision-discipline |
| Capability listed without "we don't do X" mirror | 0+R | Negative-space subsection | decision-discipline, compliance-and-ownership |
| Runtime flag where compile-time would work | 0+R | Move into the type system | decision-discipline, api-design |
| "Build vs buy" without escape-cost | 0+R | Reversibility-first ranking | decision-discipline |
| Citation as if requirement | 0+R | Reference vs dependency mark | decision-discipline |
| Constraints without exception procedures | 0+R | Every constraint has "who grants exceptions" | decision-discipline |

### Retrofit-specific (Mode R only)

| Symptom | Mode | Remedy | Reference |
|---|---|---|---|
| Section says what *should* exist instead of what *does* | R | Pass 1 documents shipping; reform goes to Pass 2 | retrofit-discipline |
| Plan re-litigates a settled decision | R | Find original; mark `DECIDED:` with evidence | retrofit-discipline |
| Author invents rationale for choices with no evidence | R | Use `IMPLICIT — owner: X` | retrofit-discipline |
| Big-bang doc rewrite contradicting reality | R | Pass 1 mirrors; Pass 2 reforms | retrofit-discipline |
| Selective documentation of "good" parts | R | Force a "current state" column | retrofit-discipline |
| Stealth renaming in Pass 1 (new names not yet in code) | R | Doc rename comes after code rename, or both ship together | retrofit-discipline, decision-discipline |
| Tribal-knowledge audit produces list, no follow-through | R | Each item has owner who writes or admits `IMPLICIT:` | retrofit-discipline |
| New doc overlaps with stale ones | R | Explicit supersession clause; relocate superseded | retrofit-discipline, operations-and-deployment |

## Anti-pattern detectors

Patterns that look like architecture but aren't:

### Aspirational completeness

The doc lists every imaginable feature, integration, capability. There's no concept of cutting; every section reads as committed work.

**Detection:** count features in the doc; compare to team's actual quarterly capacity. If ratio exceeds ~3x, the doc is aspirational, not a build plan.

**Fix:** apply fitness gate to every section; cut to what drives a current-quarter builder decision; promote everything else to `OPEN:` markers with switch criteria.

### Pattern citation as commitment

The doc cites a competitor's architecture, an industry pattern, or a paper, and treats the citation as authoritative — without distinguishing reference from dependency.

**Detection:** count citations. For each, ask: are we studying or depending? If the doc doesn't say, the reader can't tell.

**Fix:** apply citation discipline (`decision-discipline.md`); annotate every citation.

### Stealth retrofit

A doc presented as documentation of an existing system actually proposes substantial changes, blended into descriptive prose.

**Detection:** sample 10 declarative sentences. Check whether each is currently true in the deployed system. If more than ~20% are aspirational, you have stealth retrofit.

**Fix:** apply two-pass discipline (`retrofit-discipline.md`).

### Decoration disguised as decisions

Many `OPEN:` markers but lacking switch criteria, owners, or decide-by milestones. Parking lots, not decisions.

**Detection:** sample 5 `OPEN:` markers. Can you predict (a) what would resolve it, (b) when, (c) who's responsible? If multiple "no" answers, the markers are decoration.

**Fix:** `OPEN:` discipline (`decision-discipline.md`); fill in or delete.

### Tier theater

Elaborate tier modeling but the tiers don't drive any actual differentiation in the system. All customers get the same thing; tiers are sales fiction.

**Detection:** for each tier, ask: what does the system do differently for this tier? If "same as next tier" or "case-by-case," the tier isn't a real tier.

**Fix:** collapse to the smallest set that drives real differentiation (`multi-tenancy.md`); remove the rest from the canonical doc (sales collateral).

### Negative-space avoidance

Many features and integrations listed; no "what we explicitly do NOT cover" section.

**Detection:** look for "out of scope" or "explicitly-not" or "what we don't do." If absent, negative-space discipline missed.

**Fix:** ownership-boundaries discipline; add the negative-space section.

### Glossary as decoration

Glossary section exists but is empty, has placeholder content, or contains only generic textbook definitions.

**Detection:** read 5 glossary entries. Are they doc-specific? Do they link to substantive sections? Use the team's actual vocabulary?

**Fix:** glossary discipline (`operations-and-deployment.md`); rewrite each entry doc-specifically.

### One-zoom architecture

The doc has exactly one architecture diagram. Readers either get the whole system at once or nothing.

**Detection:** count distinct architecture diagrams. If ≤1, the zoom hierarchy hasn't been applied.

**Fix:** add Z1, Z2, Z3 explicitly per `build-sequencing.md`.

## Cross-references

This map indexes every other reference. Load whichever the matched row points to.
