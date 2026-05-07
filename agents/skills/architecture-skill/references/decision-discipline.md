# Decision Discipline

> Loaded for the cross-cutting discipline that applies at every layer: ownership boundaries, falsifiable decisions, reversibility ranking, abstraction negative space, and tier-collision renaming.

## The fitness gate

> **"What concrete decision will a builder make differently because this section exists? If 'nothing they wouldn't already do,' the section is ceremony — cut it."**

Mode 0 phrasing: *"What concrete present-day or near-term build decision depends on this being written down vs. left tribal?"*

Mode R phrasing: *"Does this document a real decision, or am I making a new decision under cover of documentation?"*

Pre-write checks:
1. Does this section name an **ownership boundary**, a **deferred decision with switch criteria**, a **collision/gotcha**, or a **measurable trade-off**?
2. Is there at least one specific present-day or near-term build decision that depends on it?
3. Could it be replaced by a glossary entry, a one-line `OPEN:` marker, or `IMPLICIT — owner: X`?

## Ownership boundaries — the four-bucket model

**Ownership boundaries come before feature lists.** A feature list without owners is a wishlist.

Every capability lives in exactly one bucket:

| Bucket | Meaning | Implies |
|---|---|---|
| **Us-mandatory** | Platform-owned, non-negotiable, present in every deployment | Tested, documented, on the roadmap, in the SLA |
| **Counterparty-domain** | Belongs to whoever uses the platform — customer, tenant, partner, end user | We don't do it; we may or may not facilitate it |
| **Optional integration** | We provide rails; counterparty plugs in their own provider/policy/data | Configurable, documented, but inert by default |
| **Explicitly-not** | Anti-feature. We don't do it; we don't intend to; we don't facilitate it. | Out-of-scope marker that survives revisits |

The counterparty bucket needs a domain-specific name — *tenant*, *customer*, *partner*, *operator*, *publisher*, *seller*. Pick one and use it consistently.

### The four-pass procedure

**Pass 1 — List capabilities, no buckets.** Brainstorm everything the system might touch. ≥30 entries; <15 means more thinking needed.

**Pass 2 — Assign to buckets.** Three questions per capability:
- Are we contractually/regulatorily/operationally obligated in every deployment? → us-mandatory.
- Is the counterparty obligated by their license/role/jurisdiction/business model? → counterparty-domain.
- Is there value in providing rails the counterparty configures, but no value in performing ourselves? → optional integration.
- Do we deliberately reject this for cost/scope/regulatory/focus reasons? → explicitly-not.

If a capability fits multiple buckets, split it.

**Pass 3 — Mirror the negative space.** For every us-mandatory capability, write one sentence describing what we deliberately do NOT do alongside it. Each becomes a candidate for the doc's "explicitly does NOT cover" section.

**Pass 4 — Surface conflicts.** Read the bucket assignments to a stakeholder from each affected role (eng, sales, support, legal, ops). Conflicts surface immediately.

### Why explicitly-not is its own bucket

Without it, every revisit re-litigates the same rejected scope. With it, *"explicitly-not, see <reference>"* ends the discussion in 30 seconds. The bucket also surfaces *why* — when rationale changes, bucket assignment changes; otherwise it holds.

## Falsifiable decisions — three artifacts

A decision is falsifiable if you can write down, in advance, the conditions under which you would reverse it. Three artifact types:

### `DECIDED:` — decision made

```
DECIDED: <choice> — primary, with <fallback> as fallback if <switch criterion> by <milestone>.
Evidence: <RFC/ticket/meeting record>.
Owner: <person or team accountable>.
```

Example:

> *DECIDED: managed cloud Postgres for primary OLTP, with self-managed Postgres on the same engine as fallback. Switch to self-managed if (a) regulatory residency requires regions where managed isn't available, OR (b) cost of managed exceeds 3x equivalent self-managed at sustained load, OR (c) we land a customer whose security review rejects the managed service. Decide-by: Phase 2 start. Evidence: ADR-014. Owner: data-platform lead.*

The fallback + switch criterion are **mandatory**. A `DECIDED:` without them is just an assertion.

### `OPEN:` — decision deferred, with criteria

```
OPEN: <question> — decide by <milestone>. Default while open: <interim choice>.
Switch criterion: <condition that would settle it>.
Owner: <person responsible for resolving>.
```

Example:

> *OPEN: single-region vs multi-region active-active for the customer-data tier — decide by first paid customer in EU. Default: single-region (us-east). Switch: any customer signs whose contract requires EU residency, OR cumulative EU-bound traffic exceeds 20% of total. Owner: infra lead.*

All four fields (criterion, decide-by, default, owner) are mandatory. Otherwise it's a parking lot.

### `IMPLICIT — owner: X` (Mode R only)

```
IMPLICIT — owner: <person who must write the rationale or admit the gap> by <milestone>.
Current behavior: <what the system does today, observed empirically>.
Recovery attempts: <sources checked; explicitly note "rationale not found">.
```

The owner either resurrects the rationale or formalizes current behavior into `DECIDED: <description> — rationale lost; affirmed by current team on <date>`. Inventing rationale is forbidden.

## Switch criteria — how to write them

A switch criterion is the answer to a future question, written down today. It must be:

1. **Observable** — checkable without re-opening the debate.
2. **Time-bounded or event-bounded** — anchored to milestone, metric breach, or named external event.
3. **Specific enough to commit to** — if your future self could plausibly argue both sides, too soft.
4. **Concrete enough to be wrong** — if it can never fail, it isn't a switch.

| Bad | Better |
|---|---|
| "When it becomes necessary" | "When monthly active sessions exceed 100k" |
| "If we hit scaling issues" | "If p99 latency exceeds 800ms for 7 consecutive days" |
| "When the team decides to revisit" | "At the next quarterly architecture review, revisit if X has happened" |
| "Eventually" | "By end of Phase 1, milestone P1-3" |
| "If a customer asks" | "If 3+ paying customers ask, OR if first enterprise contract requires it" |

## Estimate bounds — ±50% with meaning

Every numeric estimate gets a ±range and a stated meaning for "outside the range":

```
<metric>: <median> ±<percentage>. Outside this range means: <consequence>.
```

Defaults: ±50% for time/headcount, ±30% for throughput/latency on existing measured systems, ±100% for genuinely speculative numbers (mark as such).

The "outside" clause is what makes the bound load-bearing. The moment reality crosses the threshold, the architect is obliged to revisit, not rationalize.

Examples:

- *"Time to first paying customer: 6 months ±50%. Outside means the funding model breaks; revisit phasing."*
- *"Engine throughput target: 5,000 events/sec ±30%. Outside means the architecture choice (in-memory queue vs streaming bus) needs re-evaluation, not just tuning."*

## Reversibility ranking — escape cost first

Rank options by **escape cost** (cost to migrate away once code depends on it) before by elegance, performance, or familiarity.

| Tier | Escape cost | Examples |
|---|---|---|
| **Trivially reversible** | Few hours; isolated to one module | Logging library, formatting tools, sorting algorithm |
| **Reversible with effort** | Days to a week; coordinated PR | Identifier scheme, internal API protocol, CI/CD platform |
| **Painful to reverse** | A quarter of work; multiple teams | Database choice (within OLTP family), authentication provider, message bus |
| **Migration-grade reversal** | Multi-quarter project; every consumer | Programming language for hot path, primary data model, hosting provider |
| **Effectively irreversible** | Re-platform; rewrite | Serialization format with on-disk persistence, public API contract with external consumers, regulatory licensing strategy |

When two options offer similar value but very different escape costs, the cheaper-to-escape option wins by default. Earn the right to pick more-locked-in options only when the value advantage funds the eventual migration cost.

KISS exception: if the more-locked-in option is *much* simpler today and the value advantage is real, the lock-in tax may be worth paying. Reversibility-first is a default, not a law.

## Abstraction negative space

For every abstraction (trait, interface, base class, protocol) spanning heterogeneous backends, write a "What this abstraction does NOT hide" section.

The list typically includes:

- **Authentication scheme** — different backends authenticate differently
- **Failure modes** — backends fail in different ways
- **Latency characteristics** — different speed/throughput profiles
- **Atomicity guarantees** — different transaction semantics
- **Idempotency model** — natural dedupe vs caller-supplied keys
- **Cost / billing model** — different per-op cost
- **Eventual vs strong consistency** — never paper over

Example:

> ### What `Storage` does NOT hide
> - **Durability latency.** Object-store backend is durable on PUT 200; local-disk backend is durable only after fsync. Callers expecting cross-backend durability must explicitly call `flush()`.
> - **Cross-region semantics.** Object-store cross-region replication is eventual; local backends have no concept of region. The `region` parameter is honored where supported and ignored elsewhere.
> - **Authorization.** Object-store uses cloud credentials; local backend uses filesystem permissions; test backend ignores authorization. Callers configure each via backend-specific config.
> - **Cost.** Object-store costs per GB-month and per request; local backends cost ~nothing per op but have hard capacity limits.

The negative-space section is an architectural commitment. It tells callers what they must *not* assume.

## Compile-time over runtime

When two operations have different semantics, express the difference at the type level, not as a runtime flag.

### Anti-pattern: runtime flag

```python
def submit_batch(items, atomicity="atomic"):  # or "best_effort" or "sequential"
    ...
```

Problems: caller and callee may disagree on string values; typo is silent bug; return shape varies invisibly.

### Pattern: separate methods per semantic

```python
def submit_batch_atomic(items) -> list[Id]:
    """All-or-nothing. Either every leg succeeds or the entire batch
    fails with a single error. Return type promises a complete list."""

def submit_batch_best_effort(items) -> list[Result[Id, Error]]:
    """Per-leg result. Caller inspects each. Return type forces handling
    of partial failure."""

def submit_batch_sequential(items) -> SequentialResult:
    """Fail-fast. Submit leg N+1 only if N succeeded. Return type carries
    the prefix of successful submissions plus the failing leg's error."""
```

Compile-time guarantees beat runtime contracts. The compiler enforces the invariant; the type signature documents it.

## Reference vs dependency

Every prior-art citation must be marked as one of two things:

| Kind | Meaning | Phrasing |
|---|---|---|
| **Reference** | We study this pattern. We build our own equivalent. | "We study X's design as inspiration. We implement our own version. We do not depend on X's code." |
| **Dependency** | We use this code/library/protocol directly. Their failures, breaking changes, and licensing affect us. | "We depend on library Y at version Z. Migration plan: <plan>. License: <terms>." |

Default if unstated: reader treats it as a dependency, and the team will later argue why something they thought was free actually costs maintenance.

## Tier modeling — splitting collided labels

Most "tier" collisions are dimensional confusion presented as a labeling problem. A single column called `tier` typically carries two or three independent dimensions — pricing, infrastructure isolation, feature access, support level, regulatory posture.

### Apply the 4-question test

1. Does the label drive different downstream code paths in different modules? → split.
2. Could two customers want the same value on dimension A but different on dimension B? → split.
3. Does the label appear in different contracts (sales, infra, compliance, support) with subtly different meanings? → split.
4. Has the label been renamed informally in conversation but not in code? → split.

### Naming dimensions

| Dimension | Typical name | Controls |
|---|---|---|
| Pricing | `commercial_tier`, `plan`, `package` | Sales contract, billing logic, monthly fee |
| Infrastructure | `deployment_tier`, `topology`, `isolation_level` | Pod shape, region, dedicated DB, egress IP |
| Feature gating | `feature_set`, `entitlements` | Which features the account can access |
| Support | `support_tier`, `sla_tier` | Response time, channels, named CSM |
| Account mode | `account_mode`, `routing_mode` | How requests flow internally |
| Role / RBAC | `role`, `permission_set` | What an individual user can do |
| Security | `security_tier`, `hardening_level` | MFA, audit retention, encryption |

### Documented mapping

Three patterns:

- **Default with override:** each commercial_tier maps to a default deployment_tier; override per customer with rationale logged.
- **Independent dimensions:** sold separately; both must be set; no default.
- **Constrained:** some combinations valid (e.g., `deployment_tier ≥ namespace WHEN commercial_tier IN (branded, dedicated, enterprise)`).

Constraint without a documented exception procedure is brittle. Every constraint has a "who grants exceptions, how" clause.

### Renaming under collision

When the collision is in flight (Mode R):
1. Inventory every place the offending label appears.
2. Name the dimensions; get sales/infra/support to agree on vocabulary in writing.
3. **Doc rename first, code rename second.** Update doc; add `OPEN: rename in code by milestone M` for each code location. Do NOT silently rename in code under cover of "we're just writing the doc."
4. Migration window — schedule code rename for a quarterly migration window with deprecation aliases.
5. Sunset old name on stated date.

## Living-doc cadence

The doc rots without explicit cadence:

1. **Monthly re-read** by lead architect: does description still match reality? Any `OPEN:` ready to close? Any `DECIDED:` under pressure? Any new doc that should supersede or be superseded?
2. **Quarterly drift audits**: component map vs `kubectl get`; metrics vs dashboards; glossary vs current vocabulary; ownership boundaries vs incident-response patterns.
3. **Onboarding loop**: every new hire reads the canonical doc; after 2 weeks, they answer what was confusing or contradictory.

`OPEN:` markers have parallel tracking issues; close in lockstep.

## Common rationalizations to refuse

| Excuse | Reality |
|---|---|
| "We can't predict the conditions yet" | If you genuinely can't, you don't have enough information to defer either; collect data first |
| "The criterion is obvious" | Then write it down; obvious to you ≠ obvious to next quarter's team |
| "We'll know when we see it" | The failure mode itself is "we won't know we're seeing it" |
| "Setting a number commits us" | That's the *purpose* |
| "Conditions might change" | Conditions changing IS the switch criterion; document that |
| "It's just a placeholder" | Placeholders without criteria become permanent fixtures |
| "We're just documenting, not making decisions" | Documentation IS a decision in Mode R; the question is which |

## Cross-references

- `multi-tenancy.md` — for tier-modeling applied to deployment topology
- `api-design.md` — for compile-time over runtime + abstraction negative space at the API edge
- `retrofit-discipline.md` — for `IMPLICIT:` artifact and stealth-rewrite avoidance
- `operations-and-deployment.md` — for living-doc cadence + doc supersession workflow
