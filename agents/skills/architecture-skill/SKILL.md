---
name: architecture-skill
description: Use when drafting a canonical architecture/product document for a non-trivial software product — multi-tenant SaaS, B2B platform, infrastructure product, or regulated-industry app — covering edge, identity, multi-tenancy, data plane, caching, messaging, API design, operations, disaster recovery, compliance, billing, branding, and build sequencing in concrete, prescriptive depth. Also use when retrofitting a canonical doc onto a project already in flight.
---

# Architecture Skill — Senior Architect's Mental Library

## Overview

This skill gives an agent the **architectural mental library** to produce a buildable greenfield plan, or to retrofit a canonical doc onto a project already in flight, at the depth a senior architect would.

It is not a meta-skill about "how to write a doc." It is a library of concrete, prescriptive patterns for every layer of the stack — edge, identity, multi-tenancy, data plane, caching, messaging, APIs, operations, disaster recovery, compliance, billing, branding, sequencing — with named technology classes, trade-off tables, default recommendations, and anti-patterns.

The core stance: **every commitment in the plan is reversible-by-design where possible, falsifiable when not, and bounded by an explicit "what we don't do" boundary.** KISS and YAGNI moderate this; over-engineering for hypothetical futures is itself a failure.

## How to tell which mode you're in

Three yes/no questions:

1. Does production code already exist for this system?
2. Does anything ship to real users today?
3. Are there existing docs that overlap with what you're about to write?

**Any "yes" → Mode R (retrofit).** You are reverse-engineering and reforming. Your bias: document reality first, propose reform second. Most-common failure: smuggling new decisions into "documentation." Go to `references/retrofit-discipline.md` first.

**All three "no" → Mode 0 (greenfield).** You are synthesizing research into a buildable plan. Your bias: rejection — easier to keep things out than to take them out later. Most-common failure: aspirational completeness, premature commitments. Go straight to the layered references below.

## The fitness gate (run BEFORE writing any section)

> **"What concrete decision will a builder make differently because this section exists? If the answer is 'nothing they wouldn't already do,' the section is ceremony — cut it."**

Pre-write checks:
1. Does this section name an **ownership boundary**, a **deferred decision with a switch criterion**, a **collision/gotcha**, or a **measurable trade-off**? If none — cut or compress to glossary.
2. Is there at least one specific present-day or near-term build decision that depends on this being written down?
3. Could it be replaced by a glossary entry, a one-line `OPEN:` marker, or an `IMPLICIT — owner: X` placeholder?

Full discipline in `references/decision-discipline.md`.

## The layered reference library

The skill is structured as a layered library. Each reference is independently loadable; load the layer that matches the section you're writing.

| Layer | Reference | What it covers |
|---|---|---|
| **Edge** | `edge-and-routing.md` | TLS, custom-domain SaaS, anycast TCP, DDoS/WAF, edge filters, request-level routing, rate limiting |
| **Identity** | `identity-and-auth.md` | Auth schemes (bearer, API key, signed-message, service-credentials), OAuth2 flows, MFA, session model, multi-surface identity, per-counterparty client_credentials |
| **Tenancy** | `multi-tenancy.md` | Deployment-tier spectrum (shared_pod → namespace → cluster → region → on_prem), commercial-tier vs deployment-tier, isolation models, migration between tiers, what NOT to do |
| **Data plane** | `data-plane.md` | Per-tenant services topology, OLTP/OLAP/audit/cache layering, schema patterns, primary-key strategies, tenancy-isolation-in-schema, hypertables for time-series |
| **Caching/storage** | `caching-and-storage.md` | L1 in-memory, L2 Redis, warm OLAP (ClickHouse-class), cold archive (Parquet on object store); invalidation patterns; what goes where; ID-key vs query-key |
| **Messaging** | `messaging-and-events.md` | Command vs event bus, internal broker (NATS-class) vs external streaming bus (Kafka-class), outbox pattern, idempotency contract, fan-out, retry semantics, webhook delivery |
| **API design** | `api-design.md` | URN identifiers (rebrandable prefix), ULID over UUID, idempotency via caller-supplied keys, account-scoped endpoints, public-vs-internal enum collapse, decimal money, WS reconnect protocol, OpenAPI 3 deliverable, error code taxonomy, two-auth pattern |
| **Operations** | `operations-and-deployment.md` | k8s + CRD + operator pattern, GitOps, per-tenant secret namespacing, observability stack (logs/metrics/traces/dashboards), per-tenant labels, exposure tiering (public/internal/counterparty-facing) |
| **DR/durability** | `disaster-recovery.md` | RPO/RTO targets per tier, PITR, cross-region replication strategies, write-once audit log, restore-test cadence, disaster scenarios with response procedures, key management, right-to-be-forgotten |
| **Compliance** | `compliance-and-ownership.md` | Layered compliance model (us / counterparty / optional / explicitly-not), audit log infrastructure, geofencing, data export for regulators, evidence storage, mode-specific compliance behavior |
| **Billing** | `billing-and-commerce.md` | Out-of-band vs in-app, usage tracking for invoice support, tier-based pricing matrices, per-product billing dimensions, "created" vs "active" carryover, what fields live in the platform DB |
| **Branding** | `branding-and-customization.md` | Custom-domain provisioning workflow, theme pipeline, per-counterparty artifacts, code-signing per counterparty, 4-eyes review for branding |
| **Sequencing** | `build-sequencing.md` | Phasing rationale, cross-phase invariants, MVP cut, critical-path dependency DAG, complexity verification metrics, ±50% bounded estimates, zoom hierarchy (30-second view, service map, request trace, DAG, metrics) |
| **Decisions** | `decision-discipline.md` | Fitness gate, `OPEN:`/`DECIDED:`/`IMPLICIT:` artifacts, switch criteria, reversibility ranking, ±50% bounds, ownership boundaries (4-bucket model), abstraction negative space, tier-collision renaming |
| **Retrofit** | `retrofit-discipline.md` | **Mode R only.** Two-pass principle (mirror reality first, propose reform second), decision recovery sources, the `IMPLICIT` artifact, no-stealth-rewrite rule, legacy collisions, tribal-knowledge audit |
| **Index** | `symptom-map.md` | 80+ symptom→remedy entries indexed by mode and layer; anti-pattern detectors |

## How to use this skill (greenfield workflow)

```
1. Read this SKILL.md (navigator).
2. Sketch a top-down plan: phasing rationale → 30-second view → service map.
3. For each layer of the stack, load the matching reference and write that section.
   - Default order: tenancy → identity → data plane → edge → API design →
     messaging → caching → ops → DR → compliance → billing → branding → sequencing
   - Some sections feed each other; iterate as needed.
4. Apply decision-discipline at every choice (DECIDED/OPEN/IMPLICIT, reversibility,
   bounds, ownership).
5. Apply the symptom map as a self-review checklist before declaring v1 done.
```

## How to use this skill (retrofit workflow)

```
1. Read this SKILL.md.
2. Read references/retrofit-discipline.md FIRST.
3. Pass 1: mirror reality, layer by layer. Use the same layered references but
   document what's deployed today (verified via kubectl/dashboards/code-read).
4. Tribal-knowledge audit in parallel.
5. Pass 2: reform proposals as separate sections, OPEN markers with switch criteria.
6. Establish living-doc cadence (in operations-and-deployment.md).
```

## Cross-cutting principles (apply at every layer)

These principles cut across every layer; the layer-specific references reinforce them.

1. **Ownership boundaries before features.** Every capability lives in one of four buckets: us-mandatory / counterparty-domain / optional integration / explicitly-not. (`decision-discipline.md`)
2. **Falsifiable decisions, not preferences.** Every decision has a fallback + switch criterion + decide-by milestone + named owner. (`decision-discipline.md`)
3. **Reversibility-first ranking.** Choose by escape cost before by elegance. (`decision-discipline.md`)
4. **Tier any concept that has multiple dimensions.** Don't conflate `tier` across pricing/infra/feature/role/support. (`multi-tenancy.md`, `decision-discipline.md`)
5. **Compile-time over runtime.** Move semantic differences into the type system; separate methods or types beat runtime flags. (`api-design.md`, `decision-discipline.md`)
6. **Public API smaller than internal model.** Collapse internal richness at the boundary. (`api-design.md`)
7. **Idempotency via caller-supplied keys.** Every state-changing endpoint accepts a caller-generated key with documented retention. (`api-design.md`, `messaging-and-events.md`)
8. **Per-tenant isolation as the default.** Shared infra is a cost optimization for the lowest tier; default for paying tenants is dedicated. (`multi-tenancy.md`, `data-plane.md`)
9. **Observability per-tenant labeled.** Every metric, log, and trace carries `tenant_id`. (`operations-and-deployment.md`)
10. **Disaster recovery is a tier-driven decision, not a uniform policy.** Different tiers get different RPO/RTO. (`disaster-recovery.md`, `multi-tenancy.md`)
11. **Negative space defines scope.** Every layer names what it explicitly does NOT do. (`compliance-and-ownership.md`, `decision-discipline.md`)
12. **One canonical doc per concern.** Supersede explicitly; archive superseded. (`operations-and-deployment.md`)

## When NOT to invoke this skill

- Single-feature design notes, RFCs, or ADRs (use ADR templates directly).
- Throwaway prototypes, one-shot scripts, narrowly-scoped tools.
- "Explain this code" or "what does this function do" questions.
- Pure technical writing tasks (changelogs, release notes, API references — *consume* the API design from this skill but the writing is mechanical).
- Project management artifacts (timelines, OKRs, staffing).
- Code-level design (use [solid-patterns-skill](https://github.com/cornellsh/solid-patterns-skill) instead).

## Red flags during drafting

You're about to write something problematic if you catch yourself typing:

- "We will revisit this in the future." → Add `OPEN:` with switch criterion.
- "Industry-standard." → Cite + mark reference vs dependency.
- "We support multi-tenancy." → Which tier? Shared what, dedicated what?
- "The API is flexible." → Flexible for what concrete consumer?
- "Estimates are approximate." → ±range? What's "outside"?
- "We'll define ownership later." → Boundaries come BEFORE features.
- "Naming collision is fine, context disambiguates." → Rename now.
- "The system handles all backends uniformly." → What does it NOT hide?
- (Mode R) "Let's clean this up while we're documenting." → Stop. Pass 1 mirrors; Pass 2 reforms.
- (Mode R) "Nobody remembers why, so let me write what makes sense." → That's invention. Use `IMPLICIT — owner: X`.

When you catch any of these, **run the fitness gate again and load the matching reference.**

## Self-check before declaring v1 done

Run this as a final pass:

1. Does every layer have a section?
2. Does every section answer "what builder decision changes because this is written down?"
3. Does every deferred decision have an `OPEN:` marker with switch criterion + decide-by + interim default + owner?
4. Does every estimate have a ±range and a stated meaning for "outside"?
5. Are ownership boundaries named BEFORE feature lists?
6. Is every "industry-standard" claim cited and marked as reference vs dependency?
7. Does at least one section in each layer describe what the system does NOT do?
8. Does the architecture have ≥3 zoom levels including a 30-second view and an MVP-cut?
9. Is every multi-dimensional concept in its own column with documented mapping?
10. Does every abstraction state what it does NOT hide?
11. Does the public API collapse internal taxonomy where they differ?
12. Is the glossary front-loaded and grouped by reader background?
13. Does the doc state which other docs it supersedes?
14. (Mode R) Are sections clearly labeled as "what's shipping" vs "what we'd change"?
15. (Mode R) Does every recovered decision cite evidence or admit `IMPLICIT — owner: X`?

A "no" answer points to which reference file to load next.

## Cross-references

- For code-level design after architecture is settled: [solid-patterns-skill](https://github.com/cornellsh/solid-patterns-skill).

## Sources

This skill synthesizes commonly-known architectural practice. Domain-agnostic public references:

- **C4 model for software architecture** ([c4model.com](https://c4model.com)) — multi-zoom views.
- **Architecture Decision Records** (Michael Nygard) — falsifiable decisions, switch criteria.
- **AWS Well-Architected Framework** — pillar separation, reversibility, operational excellence.
- **The Twelve-Factor App** ([12factor.net](https://12factor.net)) — config separation, disposability, dev/prod parity.
- **OAuth 2.0** (RFC 6749) and **Authorization Server Metadata** (RFC 8414).
- **Idempotency in HTTP APIs** (RFC 9110, §9.2.2) — caller-supplied keys, retry safety.
- **Postel's Law** (RFC 1958, §3.9) — public API surface design.
- **Semantic Versioning** ([semver.org](https://semver.org)) — falsifiable change-classification.
- **Kubernetes Operator pattern** ([kubernetes.io](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)) — CRD-driven control planes.
- **The Outbox Pattern** (Chris Richardson, microservices.io) — transactional event publication.
- **CAP, PACELC** (Brewer; Abadi) — consistency vs availability trade-offs.

The skill also draws on patterns observed in canonical architecture documents the author has analyzed; none of those private documents are referenced by name, only the *patterns* they exemplify.
