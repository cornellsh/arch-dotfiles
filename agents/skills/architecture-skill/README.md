# architecture-skill

An agent skill that gives the agent the **mental library to draft a buildable, in-depth canonical architecture/product document** for a non-trivial software product — covering edge, identity, multi-tenancy, data plane, caching, messaging, API design, operations, disaster recovery, compliance, billing, branding, and build sequencing in concrete, prescriptive depth.

Works with agentic coding tools that support the [agent skills](https://agentskills.io/specification) format: Claude Code, OpenCode, Copilot CLI, Gemini CLI, and others.

## What it's for

When a senior architect sits down to draft the canonical architecture doc for a non-trivial product — a multi-tenant B2B SaaS, an infrastructure platform, a regulated-industry app — they don't write a meta-essay about how to write the doc. They draft *concrete, prescriptive sections* answering specific questions:

- How does the edge layer route a request to the right tenant pod?
- What credential classes does the system support, and what are their lifetimes?
- What does the deployment-tier spectrum look like, and how does a tenant migrate up it?
- What's the cache hierarchy, and how does invalidation work?
- How does the outbox pattern transfer events from per-tenant DBs to the cross-tenant streaming bus?
- What are the URN identifiers, idempotency keys, exposure tiers, error codes, and reconnect protocols for the public API?
- What does the Tenant Operator do, and what does it not?
- What are the per-tier RPO/RTO targets, and how is the cross-region failover tested?
- Which compliance obligations live with us, with the counterparty, with optional integrations, and which we explicitly refuse?
- How does usage tracking feed out-of-band invoicing?
- How do per-counterparty desktop binaries get built and signed?
- What's the phasing rationale, the cross-phase invariants, the MVP cut, and the dependency DAG?

This skill provides the agent with a layered library of named patterns, concrete trade-off tables, default recommendations, schema sketches, and anti-pattern detectors so it can answer those questions at depth — without being bound to any specific product domain.

## Two entry modes

The skill supports both:

- **Mode 0 — Greenfield.** Drafting the canonical doc from research, competitive intel, and stakeholder input. Bias: rejection (easier to keep things out than to take them out later).
- **Mode R — Retrofit.** Reverse-engineering a canonical doc onto a project already in flight. Bias: document reality first (Pass 1), propose reform second (Pass 2). Most-common failure: smuggling new decisions into "documentation."

The discipline is the same; the workflow differs at specific decision points. Mode detection is a 3-question check at the top of `SKILL.md`.

## What's inside

```
architecture-skill/
├── SKILL.md                              # Navigator + fitness gate + mode detection + cross-cutting principles + self-check
├── references/
│   ├── decision-discipline.md            # Fitness gate, OPEN/DECIDED/IMPLICIT, switch criteria, reversibility, tier collisions, ownership boundaries
│   ├── edge-and-routing.md               # TLS, custom-domain SaaS, anycast, edge filters, tenant routing, rate limiting, WAF
│   ├── identity-and-auth.md              # Bearer + API key + signed-message + service-credentials; OAuth2 flows; MFA; multi-surface identity
│   ├── multi-tenancy.md                  # Five-tier deployment spectrum; commercial vs deployment tier separation; migration; what to refuse
│   ├── data-plane.md                     # Per-tenant services; OLTP/audit/cache layering; ULID PKs; tenancy isolation; time-series patterns
│   ├── caching-and-storage.md            # L1/L2/warm/cold tiers; invalidation patterns; sizing; cross-region replication
│   ├── messaging-and-events.md           # Internal vs external bus; outbox pattern; idempotency; webhook delivery; backpressure
│   ├── api-design.md                     # URN identifiers; intent_id idempotency; account-scoped endpoints; public-vs-internal collapse; decimal money; WS reconnect; OpenAPI deliverable; error taxonomy
│   ├── operations-and-deployment.md      # k8s + CRD + Operator; GitOps; per-tenant secrets; observability; exposure tiering; living-doc cadence
│   ├── disaster-recovery.md              # Per-tier RPO/RTO; PITR; cross-region; write-once audit; restore drills; key management; right-to-be-forgotten
│   ├── compliance-and-ownership.md       # Layered model (us / counterparty / optional / explicitly-not); audit infra; geofencing; evidence storage
│   ├── billing-and-commerce.md           # Out-of-band vs in-app; tier matrices; per-product dimensions; created vs active carryover
│   ├── branding-and-customization.md     # Custom-domain provisioning; theme pipeline; per-counterparty artifacts; code-signing; 4-eyes review
│   ├── build-sequencing.md               # Five-zoom hierarchy (30-sec → service → request → DAG → metrics); MVP cut; cross-phase invariants; ±50% bounded estimates
│   ├── retrofit-discipline.md            # Mode R only — two-pass principle, decision recovery, IMPLICIT artifact, no-stealth-rewrite, legacy collisions
│   └── symptom-map.md                    # 100+ symptom→remedy entries indexed by layer and mode; anti-pattern detectors
├── README.md                             # this file
├── LICENSE                               # MIT
└── .gitignore
```

`SKILL.md` is the navigator — it routes the agent to the right reference based on what's being designed. References are loaded lazily, one layer at a time, keeping active context small.

## Coverage

The skill covers fifteen architectural concerns at a level of depth comparable to a senior architect's complete canonical doc:

1. **Decision discipline** — how decisions are framed, gated, and tracked
2. **Edge and routing** — how traffic enters the system
3. **Identity and auth** — who's authenticated, how, with what scopes
4. **Multi-tenancy** — how tenants are isolated and tiered
5. **Data plane** — what services run per-tenant; schema patterns
6. **Caching and storage** — the four-tier hierarchy; invalidation
7. **Messaging and events** — internal vs external bus; outbox; webhooks
8. **API design** — public surface; identifiers; idempotency; error taxonomy
9. **Operations and deployment** — k8s + Operator; GitOps; observability
10. **Disaster recovery** — per-tier RPO/RTO; backups; failover; drills
11. **Compliance and ownership** — layered model; audit infrastructure
12. **Billing and commerce** — out-of-band vs in-app; tier matrices; revenue share
13. **Branding and customization** — custom domains; theme pipeline; review
14. **Build sequencing** — phasing rationale; zoom hierarchy; MVP cut; DAG
15. **Retrofit discipline** — Mode R two-pass principle and decision recovery

Each layer has a dedicated reference file with concrete trade-off tables, default recommendations, schema sketches, and anti-pattern detectors.

## What it doesn't cover

- **Code-level design** — class structure, design patterns, OOP refactoring. Use [solid-patterns-skill](https://github.com/cornellsh/solid-patterns-skill) instead.
- **Project management** — timelines, OKRs, staffing models, hiring plans, sprint structure.
- **Specific cloud-vendor selection** (AWS vs GCP vs Azure) or specific framework comparisons (React vs Vue, Postgres vs MySQL). The decision *framework* is in `decision-discipline.md`; the picks are situational.
- **Engineering management practices** — 1:1s, performance reviews, hiring loops.
- **Specific compliance regimes** (GDPR, HIPAA, SOC 2, etc.). The *layered ownership* pattern applies, but regime-specific content is for compliance counsel.
- **Threat modeling** as a discipline. The skill flags missing security review at the sequencing step but doesn't replace STRIDE/PASTA/etc.
- **Distributed-systems theory beyond passing references.**

## Installation

Open the agent you want to install it into and paste:

```
Install the architecture-skill from this repo into my skills directory for this agent. If you don't know where the skills directory is, check your own configuration or documentation first. After cloning, confirm the skill is discoverable and tell me whether I need to restart the session for it to load.
```

## When the agent activates it

**Mode 0 — Greenfield triggers:**

- "Draft a canonical architecture doc for a multi-tenant B2B SaaS we're starting."
- "I have research material — turn it into a buildable plan."
- "What does the deployment-tier spectrum look like for this product?"
- "How do I describe the multi-tenancy isolation for sales?"
- "Choose between vendor X and vendor Y for this layer."

**Mode R — Retrofit triggers:**

- "We're 6 months in, no canonical doc — draft one."
- "Our wiki has drifted from reality, help us reconcile."
- "We have three docs that contradict each other."
- "Document this codebase as if for a new hire."
- "I think we have a tier-label collision, walk me through it."

**Cross-mode triggers:**

- "Review this architecture plan."
- "What's missing from this design doc?"
- "How do we describe what we explicitly don't do?"

The skill stays out of the way for narrow questions (rename a method, fix a typo), single-feature design notes, throwaway prototypes, and pure technical writing tasks (changelogs, release notes).

## Design stance

> *Every commitment in the plan is reversible-by-design where possible, falsifiable when not, and bounded by an explicit "what we don't do" boundary. KISS and YAGNI moderate this; over-engineering for hypothetical futures is itself a failure.*

Two cross-cutting principles drive most of the skill:

1. **Ownership boundaries before features.** Every capability lives in a named bucket: us-mandatory, counterparty-domain, optional integration, or explicitly-not. Without this, feature placement is arbitrary.
2. **Falsifiable decisions, not preferences.** Every decision has a fallback, a switch criterion, a decide-by milestone, and a named owner. Otherwise the doc is a wishlist.

## Related skills

- **[solid-patterns-skill](https://github.com/cornellsh/solid-patterns-skill)** — for code-level design (classes, modules, design patterns). Use it after the architecture is settled and you're implementing.

## Sources

The skill synthesizes commonly-known architectural practice from public sources:

- C4 model for software architecture ([c4model.com](https://c4model.com))
- Architecture Decision Records (Michael Nygard)
- AWS Well-Architected Framework
- The Twelve-Factor App ([12factor.net](https://12factor.net))
- OAuth 2.0 (RFC 6749) and Authorization Server Metadata (RFC 8414)
- Idempotency in HTTP APIs (RFC 9110, §9.2.2)
- Postel's Law (RFC 1958, §3.9)
- Semantic Versioning ([semver.org](https://semver.org))
- Kubernetes Operator pattern ([kubernetes.io](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/))
- The Outbox Pattern (Chris Richardson, microservices.io)
- CAP, PACELC theorems

The skill also draws on patterns observed in canonical architecture documents the author has analyzed; none of those private documents are referenced by name, only the *patterns* they exemplify.

## Contributing

Issues and PRs welcome. When proposing a change:

1. Say what behavior the change actually produces. Not "improves clarity," but "the agent will now also recommend X."
2. Verify your change doesn't introduce domain-specific jargon (the skill must remain generally usable across products and domains).
3. If the change touches both `SKILL.md` and a reference file, update both.
4. **Pressure-test before publishing externally.** This skill v1 was written from synthesis without TDD pressure-testing. Before publishing significant changes (especially those affecting Mode R discipline), run pressure scenarios against a baseline subagent: write the scenario, run it without the skill loaded, document the failure verbatim, then run with the skill loaded and verify the agent now complies.

The skill follows the [agentskills.io specification](https://agentskills.io/specification). The YAML frontmatter must stay under 1,024 characters.

## License

MIT License — see [LICENSE](LICENSE).
