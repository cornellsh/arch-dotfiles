# Build Sequencing

> Loaded when designing the phasing rationale, cross-phase invariants, MVP cut, critical-path dependency DAG, complexity verification metrics, ±50% bounded estimates, zoom hierarchy.

## What this layer commits to

The sequencing layer answers:

1. **In what order should we build** the layers/components? Why this order?
2. **What stays constant** across phases? (Cross-phase invariants — what's built once and reused.)
3. **What's the MVP cut?** What can ship without?
4. **What blocks what?** (Critical-path DAG.)
5. **How big is this really?** (Complexity verification: number of services, LOC, team size, time, cost — all with ±50% bounds.)

This layer provides the **zoom hierarchy** that the rest of the architecture is presented through.

## The zoom hierarchy — five standard zooms + two side-views

A canonical doc presents the architecture at multiple zoom levels:

| Zoom | Reader question | Form | Length |
|---|---|---|---|
| **Z1 — 30-second view** | "What is this thing in 5 boxes?" | One small diagram + 1 paragraph | ≤200 words |
| **Z2 — Service map with build status** | "What components exist? Which are real today?" | Diagram with status flags + responsibility table | 1-2 pages |
| **Z3 — Single-request trace** | "What does a single end-user action touch end-to-end?" | Sequence diagram or numbered hop list + per-hop SLA | 1 page per critical path |
| **Z4 — Critical-path dependency DAG** | "What blocks what, in build order?" | Directed graph; layered top-down | 1 page |
| **Z5 — Complexity verification metrics** | "Is this buildable? How big is it really?" | Numeric table with ±bounds | 1 page |

Plus two recurring side-views:

| Side-view | Question | Form |
|---|---|---|
| **MVP cut** | "What can be cut to ship faster?" | Per-component table with "if cut, what's lost?" + "what blocks unblocking it later?" |
| **Cross-phase invariants** | "What stays constant across phases?" | List of components + contracts that survive unchanged |

Use all of them. One diagram is for a presentation, not a build doc.

### Z1 — 30-second view

Five boxes maximum. Each box is a noun a stakeholder would recognize without explanation. One paragraph beneath explains how they relate.

If you cannot reduce to 5 boxes, you don't yet have a clean mental model. Do the compression work; the reader shouldn't.

### Z2 — Service map with build status

Every deployable unit, every external dependency, every shared data store. Connected by actual dependencies. With status flags:

- ✅ Built / proven
- 🚧 Partially built
- 📋 Planned
- 🌌 Future / speculative

The status flags are what make Z2 load-bearing. Without them, Z2 is a wishlist.

Pair the diagram with a one-line responsibility table:

| Service | Layer | Used by | What it does |
|---|---|---|---|
| (one line per service) | | | |

### Z3 — Single-request trace

Pick the most-trafficked or most-critical end-user action. Trace from first network hop to last. Number every hop. Annotate per-hop with:

- Component name
- Typical SLA (latency or throughput)
- Failure mode

Multiple critical paths get multiple Z3 diagrams (synchronous user request, asynchronous background job, real-time event subscription, etc.).

### Z4 — Critical-path dependency DAG

Edges are "X must be done before Y can start." Group nodes into layers (foundation → identity → edge → app → data → polish) for readability.

This catches sequencing errors: the doc's Z4 may show service A depending on service B, but the sprint plan has A scheduled before B. The DAG makes the contradiction visible.

### Z5 — Complexity verification metrics

A numeric table:

| Metric | Value | Notes |
|---|---|---|
| Distinct services at v1 | ~N ±M | breakdown by category |
| External dependencies | ~K | one line per family |
| End-user clients | C | web / desktop / mobile / API |
| Backend repos | R | shared monorepo or separate |
| Critical-path hops for the dominant request | H | edge → service → data → external |
| Total LOC at v1 | ~L ±50% | rough estimate |
| Team size for v1 | T engineers ±2 | breakdown by specialty |
| Time to first production-grade release | M months ±50% | what "outside" means |
| Operational footprint | nodes / cost-per-month ±30% | |

Numbers are tripwires. If headcount says 4 and Z5 says "needs 8," surface the gap.

### MVP cut

Title verbatim: **"What can be cut for an MVP."**

For each candidate cut:

| Component / capability | If cut, what's lost? | If cut, what blocks unblocking it later? |
|---|---|---|
| Service X | Feature Y becomes manual | Database schema lock-in if we ship without it |
| Capability Z | Reduced SLA on path P | None — additive only |

Pre-answer "can we ship without this?" so scope debates have a starting point.

### Cross-phase invariants

Title verbatim: **"What stays constant across all phases."**

List components, contracts, and decisions built once and reused unchanged through later phases:

- Identity model (one user across all phases)
- API protocol family (Connect-RPC + REST; same shape across phases)
- Observability stack (metrics + tracing schema unchanged)
- Eventing contract (message format + retry semantics)
- UI foundation (component library, design system)
- Branding pipeline

If you can't name 5+ invariants, the phases are probably independent projects in disguise; the cost-saving thesis of sequential delivery doesn't hold.

## Phasing — sequential vs parallel

For non-trivial products, sequential delivery typically beats parallel. Reasons:

1. **Capital efficiency.** Each phase fundable from prior-phase revenue + modest extension. Avoids large up-front commitment.
2. **Risk isolation.** If phase 1 fails to find product-market fit, kill before phase 2 spend.
3. **Phase 2 leverages phase 1 platform.** Identity, multi-tenancy, edge, observability, branding — all built in phase 1, extended (not rebuilt) in phase 2.
4. **Real users + revenue + feedback inform later phases.** Build to known requirements, not abstract spec.

When parallel makes sense:

- Two products with truly disjoint architectures (rare).
- Time-to-market pressure where serial would lose the market window.
- Capital available specifically for parallel build (rare for non-funded teams).

The default is sequential. Justify parallel explicitly.

## Phasing rationale — what to write

Document the phasing thesis explicitly:

1. **What's phase 1?** The minimal product that earns revenue and validates demand.
2. **What's phase 2?** Extension that leverages phase 1 (typically: same identity, same UI, same ops; new business capability).
3. **What's phase 3?** Further extension (typically more ambitious; only fundable from phase 1+2 success).

Per phase:

- **Why this order?** What about phase 1 makes phase 2 easier?
- **What's the gating decision** between phases? When do we commit to phase 2?
- **What's the kill criterion?** When do we abandon a phase?

Example phrasing:

> *Phase 1 — earliest path to revenue; uses the simplest external integrations; no enterprise sales gates; ~6 months ±50%.*
>
> *Phase 2 — leverages phase 1 platform (~50% of phase 2 work already done by phase 1). Adds enterprise capability needed for high-tier customers. ~9 months ±50% from phase 1 GA.*
>
> *Phase 3 — depends on phase 1+2 customers + revenue informing the requirements. Capital-intensive; deferred until phase 1+2 validate demand.*

## Critical-path dependency DAG — concrete

Layered DAG; each node depends on nodes above:

```
Layer 0 — Foundation
├─ k8s cluster + EKS
├─ GitOps with Argo CD
├─ Observability LGTM stack
└─ Vault / secret manager

Layer 1 — Identity & Control
├─ identity-service        (depends on: k8s, Vault)
├─ control-API             (depends on: identity, k8s)
└─ Tenant Operator + CRD   (depends on: control-API, k8s)

Layer 2 — Edge
├─ Custom-Domain SaaS      (depends on: DNS provider account)
├─ Anycast TCP             (depends on: cloud account)
└─ Edge proxy + filter     (depends on: control-API for tenant lookup)

Layer 3 — Per-tenant data plane
├─ Per-tenant Postgres + Timescale
├─ Per-tenant Redis
├─ Per-tenant message broker
└─ Cross-tenant Kafka (shared)

Layer 4 — Application services
├─ engine                  (depends on: data plane, identity)
├─ customer-API              (depends on: engine, identity, edge)
├─ manager-API             (depends on: control-API, identity, edge)
├─ webapi                  (depends on: identity, edge)
└─ workers                 (depends on: data plane, broker)

Layer 5 — UI & branding
├─ UI codebase             (depends on: APIs)
├─ Branding pipeline       (depends on: control-API)
└─ Custom-domain workflow  (depends on: edge, control-API)

Layer 6 — Polish
├─ Tauri desktop builds
├─ Mobile apps
└─ Documentation site
```

Trying to start layer 4 work before layer 1 is done is a common failure. The DAG forces explicit conversation about it.

## Estimates with ±50% bounds

Every numeric claim in Z5 (and elsewhere) has a ±range and a stated meaning for "outside the range":

```
<metric>: <median> ±<percentage>. Outside this range means: <consequence>.
```

Defaults:

- ±50% for time/headcount estimates on greenfield work
- ±30% for performance numbers on systems with measurement
- ±100% for genuinely speculative numbers (mark as such)

Examples:

- *"Time to first paying customer: 6 months ±50%. Outside means the funding model breaks; revisit phasing."*
- *"Engine throughput target: 5,000 events/sec ±30%. Outside means architecture choice (in-memory queue vs streaming bus) needs re-evaluation, not just tuning."*
- *"Team size for phase 1: 4 engineers ±2. Outside means phase 1 cannot complete on the current schedule."*

The "outside" clause is what makes the bound load-bearing.

## Worked example — phasing for a B2B SaaS

Phasing thesis:

**Phase 1 — Self-serve B2B with standard integrations.**

- T0/T1 tier; shared_pod and namespace deployment tiers only
- Standard set of integrations (top 3 vendor adapters)
- Identity, edge, branding, observability, billing all built
- Out-of-band billing for higher tiers (manual sales cycle)
- Target: 6 months ±50%; first 10 paying customers; ~$100k ARR
- Kill criterion: no paying customer by month 9 → reset hypothesis

**Phase 2 — Enterprise-tier extension.**

- Adds T3/T4 tier; cluster and region deployment tiers
- Adds dedicated egress IPs; per-tenant DB; SLA-backed
- Adds branding pipeline customizations (per-counterparty desktop builds)
- Same identity, same UI, same APIs as phase 1 (just more capacity)
- Target: 9 months ±50% from phase 1 GA; first 5 enterprise customers; ~$1M ARR
- Kill criterion: < 2 enterprise customers signed within 9 months

**Phase 3 — Multi-region / advanced capability.**

- Adds region tier with full data residency
- Adds BYOK
- Adds advanced compliance integrations
- Target: 12-18 months from phase 2; informed by actual phase 1+2 customer requirements
- Kill criterion: no actual customer ask for these capabilities within phase 2

What stays constant across all three phases:

- Identity service — one user model, one auth flow across all phases
- API protocol (Connect-RPC + REST + WS)
- UI codebase
- Tenant Operator + CRD
- Observability stack (LGTM-class)
- Branding pipeline
- Eventing contract (outbox + Kafka + webhook)

Z5 — complexity verification:

| Metric | Phase 1 value | ±range |
|---|---|---|
| Distinct services | ~12 | ±2 |
| Backend repos | 3-4 | ±1 |
| Team size | 4 engineers | ±1 |
| Time to first customer | 6 months | ±50% |
| Time to GA | 9 months | ±30% |
| Total LOC at GA | ~80k | ±50% |
| Operational footprint | 10-15 nodes | ±30% |

MVP cut for phase 1:

| Component | If cut, what's lost? | What blocks unblocking later? |
|---|---|---|
| Per-counterparty desktop builds | Counterparties use web only | None — additive |
| Branding pipeline review (use fixed theme) | Counterparties on default brand | Branding DB schema can be added later |
| Custom-domain SaaS | Counterparties on `<short>.platform.com` only | Edge can add custom domain later |
| Self-serve branding via Manager UI | Counterparties email theirs in | Manual; doesn't block |
| Dedicated egress IPs | Tenants who need allowlisted external services blocked | Cluster-tier infra; phase 2 anyway |

Critical-path DAG (phase 1 only):

```
0 — k8s + GitOps + observability + Vault
1 — identity-service + control-API + Tenant Operator
2 — Custom-Domain SaaS + edge proxy
3 — Postgres + Redis + NATS + Kafka
4 — engine + customer-API + manager-API + webapi
5 — UI + Branding (basic)
6 — Documentation site
```

Anything later in this list cannot start before everything earlier is done (or stubbed in a way that doesn't constrain the design).

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Single architecture diagram | No entry point; no exit point | All five zooms + MVP cut + cross-phase invariants |
| 30-second view with 12 boxes | Same as Z2; not a 30-second view | Cut to 5; force the compression |
| Z2 without status flags | Wishlist | ✅ / 🚧 / 📋 / 🌌 on every box |
| No Z3 trace | Topology hides hidden hops; complexity surprises | Trace at least dominant request end-to-end |
| Z4 omitted | Sprint plan diverges from architecture dependencies silently | Draw the DAG; check sprint plan against it |
| Z5 numbers without ±range | Unfalsifiable estimates | Apply bound discipline; state "outside means..." |
| MVP cut absent | Every scope debate re-discovers the architecture | Pre-answer with cuts + costs |
| Cross-phase invariants asserted but not enumerated | Cost-saving claim un-falsifiable | List 5+ invariants explicitly |
| Phase ordering without rationale | Team second-guesses; phases get re-ordered ad hoc | Write the rationale and the kill criteria explicitly |
| Parallel phasing without justification | Capital and risk multiply unnecessarily | Default sequential; justify parallel |
| Phase plan with no kill criteria | Sunk cost drives continuation past viability | Each phase has a kill criterion in the doc |
| Estimates without "outside" clause | Numbers are decorative | Always state what crossing the bound means |
| Z5 metrics that don't include the team | "We can build this" when the team can't | Headcount metric is mandatory |

## Cross-references

- `decision-discipline.md` — for `OPEN:`/`DECIDED:` decisions and ±50% discipline at decision points
- `multi-tenancy.md` — for what's built once vs evolved per tier
- `operations-and-deployment.md` — for the dependency between Tenant Operator and other layers
- `data-plane.md` — for the layered storage build order
- `compliance-and-ownership.md` — for compliance milestones in phase plans (SOC 2 Type II, etc.)
