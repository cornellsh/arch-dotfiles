# Retrofit Discipline

> **Mode R only.** Loaded when producing a canonical architecture doc retroactively for a project already in flight — code exists, decisions are partly tribal, multiple stale docs may overlap. Not applicable to greenfield (Mode 0).

## The principle

**Documenting reality is pass one. Reform is pass two. Don't run them in the same paragraph.**

The most common failure mode in retrofit work: sneaking new decisions into "documentation." A team six months into a project asks the architect to "write up what we have." The architect, with the benefit of hindsight, fixes the things that look broken — and the resulting doc describes a system that's part-real and part-aspirational. Three months later somebody points out that section §X doesn't match what's deployed; trust collapses.

The senior move: **rigid two-pass discipline.** First document what *is*, exactly, including the embarrassing parts. Second propose reform, separately and clearly marked. Both passes can be the same author, the same week, even the same PR — but the prose stays separated. Readers can always tell which sentences describe reality and which describe a desired future.

## The two passes

### Pass 1 — Mirror reality

Pass 1 produces a doc that describes the system **as it ships today**, with full honesty:

- Decisions whose rationale is lost to time
- Components that are partial, broken, or load-bearing despite being marked "deprecated"
- Workarounds that everyone agrees are ugly but ship value
- Places where deployed reality contradicts the wiki, README, or runbook
- Naming collisions causing real problems
- The actual on-call rotation, escalation path, ownership map

Discipline of Pass 1:

1. **Verify against reality, not memory.** Read the code. Pull `kubectl get` output. Read dashboards. Read the on-call runbook. Don't write what you remember; write what's deployed.
2. **No editorializing.** "Service X uses 16-character base32 IDs" is fine. "Service X uses an unfortunate 16-character base32 ID scheme that should really be a ULID" is editorializing — the second clause is reform, not documentation.
3. **No omissions for embarrassment.** If service X has a known SQL injection that the team hasn't patched, the doc says so (in a security-marked section). Selective documentation is motivated reasoning.
4. **`IMPLICIT — owner: X` for unknown rationales.** Where you can describe what the system does but not why, mark explicitly.
5. **`DECIDED:` only for choices with surviving evidence.** If there's no RFC, ticket, or email — it isn't `DECIDED:`. It's `IMPLICIT:`.

### Pass 2 — Propose reform

Pass 2 produces a separate set of sections (or separate document) that proposes changes:

1. Each reform proposal is anchored to a specific Pass 1 section ("Pass 1 §3.4 documents X; we propose Y because Z").
2. Each proposal is marked `OPEN: reform proposed — switch criterion: ...` per `decision-discipline.md`.
3. Each proposal has an owner — the person who'll write the migration plan if the proposal advances to `DECIDED:`.
4. Each proposal has a delta-cost estimate (rough effort for migration).
5. Each proposal has a do-nothing alternative explicitly considered.

### The blur to avoid

Bad mixing:

> *"Service X uses an unfortunate base32 16-character ID scheme. We are migrating to ULIDs in Q3 to address this."*

Two problems:
- "Unfortunate" is editorializing in Pass 1 prose.
- "Migrating in Q3" presents a reform as if settled, without `OPEN:` discipline.

Good separated:

> **Pass 1 §3.4** *Service X uses base32 16-character IDs. The IDs are generated client-side and validated server-side against a regex `^[a-z2-7]{16}$`. The rationale for this scheme is undocumented and predates the current team. (`IMPLICIT — owner: backend lead by Q3`)*
>
> **Pass 2 §R3.4** *We propose migrating Service X's IDs to ULIDs. Reasons: (a) sortability for log correlation, (b) shorter than UUIDs at equivalent uniqueness, (c) eliminates client-side generation requirement. Migration cost: ~3 engineering weeks. (`OPEN: ULID migration — switch criterion: backend-lead approval + Q3 capacity`. Owner: backend lead.)*

Reader can tell, line by line, which is reality and which is proposal.

## Reverse-engineering decisions

A retrofit will discover decisions whose rationale is lost. Don't invent rationale — recover what you can; admit the rest.

### Recovery sources, in order of authority

1. **Surviving RFC/ADR/design doc** — if it exists, cite it.
2. **Original ticket / PR description** — if it exists, cite it.
3. **Original PR review comments** — sometimes rationale is in the review thread.
4. **Commit message** — sometimes the only surviving rationale.
5. **Author of the original change** — interview if reachable.
6. **Adjacent reviewers** — second-best to the author.
7. **Code archaeology** — what came before the change, what problem the change solved.

If 1-6 fail, the decision is `IMPLICIT`. Do not promote it to `DECIDED:` by inventing rationale.

### The `IMPLICIT` artifact

```
IMPLICIT — owner: <person who must write the rationale or admit the gap> by <milestone>.
Current behavior: <what the system actually does today, observed empirically>.
Recovery attempts: <list of sources checked; explicitly note "rationale not found">.
```

The named owner has 90 days (or to the milestone) to either:

- **Recover the rationale** (interview team members, deeper code archaeology, departed-engineer outreach)
- **Or formalize current behavior** as `DECIDED: <description> — rationale lost; affirmed by current team on <date>`

The second outcome is honest. Inventing rationale is not.

### What if the rationale was wrong?

Sometimes archaeology reveals: "the original author thought X would happen, X didn't happen, and the design now serves a different purpose." Documentation:

> *DECIDED: 16-char base32 IDs (current production behavior). Original rationale (per RFC-007, 2024): URL-safe IDs that fit comfortably in 80-column terminals. Current rationale (affirmed 2026-Q1): the IDs are now serving a secondary purpose — distinguishing pre-migration vs post-migration records. Migration to ULIDs deferred until pre-migration record retention period ends (2027-Q3).*

The doc captures both the *original* and the *current* rationale honestly. Future engineers know why the design exists today, not why it existed years ago.

## The no-stealth-rewrite rule

When documenting a retrofit, a tempting failure mode: rename, reshape, or "improve" things in the doc that aren't yet renamed in code. **Don't.**

If `tier` is a column in the database meaning three different things across the codebase, Pass 1 documents that:

> *§4.2 The `tier` column carries three distinct meanings depending on which module reads it: in `alerts/` it means escalation level; in `billing/` it means feature gate; in `infra/` it means deployment topology. The conflation is the cause of incident-2024-Q4-07.*

The doc *does not* invent new column names that don't exist in the database yet. The renaming is Pass 2:

> *§R4.2 We propose splitting `tier` into `escalation_tier`, `feature_tier`, and `deployment_tier` over the Q3 migration window. Migration plan: ... (`OPEN: rename — switch when migration window opens; owner: platform lead`).*

Stealth-rewriting (writing new names in Pass 1 without yet renaming in code) creates a doc that lies. Readers see the new names and assume they're real; they file bugs against the new names; they discover the names don't exist in the codebase; trust collapses.

The rule is unconditional. Even if the rename is "obvious," it doesn't go into Pass 1 until it's in the code.

## Legacy collisions

When Pass 1 surfaces a collision (label collision, ownership ambiguity, contradictory documentation), there are exactly three legitimate moves:

| Move | When | Cost |
|---|---|---|
| **Rename in both** | Achievable in next migration window AND breaks no SLA | Coordinated PR; documented changelog; some downtime |
| **Document + `OPEN: rename pending`** | Rename is desired but not yet achievable | Doc reflects reality; rename gets scheduled |
| **Document + accept** | Rename is too costly OR collision is benign once documented | Doc explicitly says "this collision is policy" |

Picking move 2 (`OPEN: rename pending`) and never advancing it to move 1 is the most common failure. The collision becomes permanent; the marker becomes furniture. Discipline: every `OPEN: rename pending` has a switch criterion ("when next migration window opens" + an owner).

## Tribal knowledge audit

Part of the retrofit is enumerating decisions that exist socially but not in writing.

### The audit

1. **Interview each engineer** for 30-60 minutes: "What does the team know that isn't written down?" Capture verbatim, then categorize.
2. **Cross-reference incident retrospectives** — incidents often surface tribal knowledge ("we always do X before Y; I didn't know that").
3. **Cross-reference onboarding gaps** — what did each new hire learn from someone else that wasn't in any doc?
4. **List every `IMPLICIT:` decision** discovered during recovery.

### Closing the list

Each item gets an owner who'll either:

- Write it down (becomes `DECIDED:` or doc prose)
- Or admit it's lost (`IMPLICIT — affirmed: <date>`)

Closing this list is the actual work of the retrofit. The canonical doc is the byproduct.

## Senior moves vs junior moves in retrofit

The patterns most commonly distinguishing senior retrofit work from junior:

| Junior move | Senior move |
|---|---|
| Document only the parts the team is proud of | Document the embarrassing parts too; selective documentation = motivated reasoning |
| Invent rationale for `IMPLICIT:` decisions | Use `IMPLICIT — owner: X`; let the owner recover or admit |
| Rename in the doc while writing it ("we'll fix this in code soon") | Pass 1 mirrors current code; renames are Pass 2 with switch criteria |
| Big-bang doc rewrite | Incremental, by section, with reality verification at each step |
| Treat the wiki as a source of truth | Verify against deployed reality; the wiki is a candidate, not authoritative |
| Skip negative-space sections because "the system does what it does" | Apply negative-space discipline; capture out-of-scope explicitly |
| Smuggle reform into "documentation" PRs | Pass 1 PR and Pass 2 PR are separate (or, if combined, prose is clearly separated) |
| Close the retrofit with v1 of the canonical doc | Establish the living-doc cadence (`operations-and-deployment.md`) so the doc stays accurate |

## Retrofit-specific anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Pass 1 includes editorial language ("unfortunately", "regrettably") | Pass 1 is supposed to be neutral observation | Strip editorial; move judgments to Pass 2 |
| Pass 2 reform proposals without owners | Reform is wishful, not actionable | Each proposal has named owner + switch criterion |
| `IMPLICIT:` markers without recovery attempts logged | Future readers can't tell what was tried | List sources checked; explicitly note "rationale not found" |
| Stealth-renaming in Pass 1 | Doc lies; readers can't reconcile with code | Renames live in Pass 2; Pass 1 uses current code names |
| Long-lived `OPEN: rename pending` markers | Marker becomes furniture; rename never happens | Each marker has switch criterion AND decide-by milestone |
| Tribal-knowledge audit produces list, no follow-through | Knowledge stays tribal | Each item has owner who writes or admits `IMPLICIT:` |
| Promoting `IMPLICIT:` to `DECIDED:` by inventing rationale | Future engineers defend wrong reasons | If evidence is gone, `DECIDED: <behavior> — rationale lost; affirmed <date>` |
| Treating canonical doc as done at v1 | Doc rots immediately | Establish monthly re-read + drift audits per `operations-and-deployment.md` |

## Sequencing a retrofit

Order of operations:

1. **Inventory existing artifacts.** What docs, runbooks, READMEs, wikis, ADRs already exist? List them.
2. **Pick the canonical home.** Decide where the new doc will live. Single file or directory; supersession plan.
3. **Run Pass 1 by section.** One module/area at a time. Verify each against deployed reality. Don't try the whole system in one PR.
4. **Run the tribal-knowledge audit in parallel.** Interview engineers as Pass 1 progresses.
5. **Identify the 3-5 highest-leverage reforms.** Don't write Pass 2 for everything; prioritize.
6. **Write Pass 2 for those reforms.** With owners, switch criteria, migration plans.
7. **Establish living-doc cadence.** Monthly re-read, drift audits, OPEN tracking.
8. **Supersede the old artifacts.** Move to archive; add redirect notices; update internal links.

Each step takes 1-3 weeks for a non-trivial system. Total retrofit: 1-2 quarters of part-time architect work. Compressing it shorter usually produces a doc that's wrong and isn't trusted.

## Worked example — internal corp tool, 18 months in

Setting: an internal corp tool grew across three teams over 18 months. No canonical doc. The wiki has six pages of partly-stale content. Three teams use the term `tier` to mean different things; an incident last quarter cost 4 hours of debugging because of the confusion.

Pass 1 product:

- §3 Component map (verified against `kubectl get` output for current cluster)
- §4 Data model (verified against current schema; documents the `tier` column carrying three meanings)
- §5 Decisions: 7 `DECIDED:` items with surviving RFCs/tickets, 12 `IMPLICIT:` items with named owners, 0 invented rationales
- §6 Known issues: SQL injection in service X (CVE pending), the `tier` collision, three more known-broken items
- §7 Glossary, including a "deprecated terms in the wild" subsection mapping old wiki terms to current code

Pass 2 product:

- §R4 Proposal: split `tier` into three columns (full plan, owner, switch criterion)
- §R5 Proposal: ULID migration for service X order IDs (full plan)
- §R6 Proposal: deprecate the bottom three wiki pages, supersede with this doc
- §R7 Resolution plan for known issues, prioritized

The doc is now honest. Pass 1 is the team's shared reality; Pass 2 is the team's shared backlog. They co-evolve over time, and the team can see at any moment what's real vs proposed.

A new engineer can join, read Pass 1, and understand what's deployed. They can read Pass 2 and understand what's planned. They cannot confuse the two.

## Cross-references

- `decision-discipline.md` — for `OPEN:`, `DECIDED:`, and `IMPLICIT:` artifacts
- `operations-and-deployment.md` — for living-doc cadence after retrofit
- All other layered references — used in Pass 1 to document each layer of current reality
