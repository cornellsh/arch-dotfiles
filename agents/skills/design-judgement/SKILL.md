---
name: design-judgement
description: |
  Install procedural design judgement when building, reviewing, or refining
  any user-facing artifact whose form carries meaning: websites, landing
  pages, dashboards, marketing surfaces, product UI, brand documents,
  pitch decks, README hero sections. Use when the task involves visual
  or narrative composition where the wrong default would be to ship the
  first plausible output. Triggers include "redesign", "refresh", "make
  this look better", "build a landing page", "design the homepage",
  "improve the hero", "make this feel premium", "review this UI", or
  any work where craft, narrative, and the composite-as-signal matter.
  Reverse-engineered from how a senior design lead actually decides:
  classifying artifacts before applying principles, fighting the ease
  trap, evaluating in real context not isolation, walking the store,
  and resisting the default decay toward mediocrity.
license: MIT
compatibility: claude-code opencode
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
---

# Design Judgement

This skill is your stand-in for a senior design lead in the room. Without it,
you ship the first plausible output. With it, you classify the artifact, run
a procedure that matches its class, critique your own output before showing
it, and refuse the easy approval the default behavior wants you to give.

This is not a style guide. It is a decision procedure. Run the procedure.

---

## Worldview (read first; the procedure does not work without these)

Seven beliefs underwrite every check below. If you skip these, the checks
become performance and produce nothing.

### 1. Form is content
The way an artifact is built is itself a statement about who built it.
Surface choices broadcast the team's actual standards. Care visible in
small details (spacing, transitions, copy precision, alignment) is read
by users as evidence about the parts they cannot directly audit. Sloppy
margins say "we are sloppy" about everything else too. This is not
decoration; it is information transmission.

Implication for you: under-investing in form because "the function is
what matters" is the most common AI mistake in design work. The function
matters AND form is part of how function is communicated.

### 2. Users are inferential, not literal
Users do not list claims and rationally evaluate. They form impressions
from cues. "We are trustworthy" is an assertion. "$X billion processed,
N9 uptime" is evidence the user can derive trust from. Adjective stacks
("robust, secure, scalable, world-class") are weak because they are
competitor-replaceable. Concrete artifacts of competence are strong.

Implication: prefer evidence over claim. Prefer specific over general.
Prefer numbers over adjectives. Prefer demonstration over description.

### 3. The composite is the unit
Local quality does not add up. Coherence is its own dimension. A polished
section next to an unpolished one degrades both. An updated dining room
makes the unrenovated kitchen look worse. Per-element optimization
without composite review makes the whole worse, even if every change is
locally an improvement.

Implication: never approve a change without zooming out to see how it
sits among its neighbors. The unit of evaluation is the page, the flow,
the document — not the element.

### 4. Time is asymmetric
Some artifacts will exist unchanged for years (homepage, brand identity,
public docs). Some will exist for hours (PR description, draft copy).
The right time/quality budget for each is different. Treating everything
with the same urgency under-iterates on long-life work and over-iterates
on disposable work.

Implication: classify time-horizon before committing effort.

### 5. Default is decay
Without active counter-force, work drifts toward mediocrity, toward
incoherence (add-on tax), toward isolation-judgement, toward acceptance
of whatever was easy to produce. The default behavior of an AI agent —
ship first plausible output, optimize locally, approve own work — is
exactly the decay direction. Most of the work in this skill is the
counter-force.

Implication: any time something feels easy, suspect that you are inside
the decay direction. Resistance is the operation.

### 6. Different eyes catch different things
No single perspective is sufficient for review. The maker's eye is
biased by the making. Self-review by the same agent that produced the
work is the weakest possible critique — same model, same blind spots,
same training data. A structural perspective shift (different role,
different time, different frame) is required before approving.

Implication: every approval must come after a perspective-shift critique
pass, not after self-confirmation.

### 7. Names are tools
Internal vocabulary is cognitive infrastructure. A pattern with a name
("scrolly telling," "ease trap," "dining room only," "uniqueness audit")
can be discussed, refused, defended. An unnamed pattern is invisible.
This skill gives you names. Use them.

Implication: when you spot a failure mode, name it. When you make a
choice, articulate which principle it serves. Vague critique
("doesn't feel right") is not actionable; named critique is.

---

## How to use this skill

For any non-trivial design task, run the nine layers in order. You can
skip layers that are clearly N/A (e.g., trigger gate is moot if the user
explicitly said "redesign this"), but you must consciously skip them,
not silently bypass them.

For small tasks, a compressed pass is acceptable: classification (Layer 3)
+ search framing (Layer 4) + internal critique (Layer 6) + real-context
decision (Layer 7) is the irreducible minimum.

The decision rule about when this skill applies: if the artifact's form
carries identity, trust, or commercial signal — apply this. If the
artifact is purely instrumental and disposable — apply lighter judgement.
Use Layer 3's classification to decide.

---

## Layer 1 — Trigger gate

**Question to answer**: should design work happen at all?

The user, or your own first instinct, may be wrong about the trigger.
Before doing the work, classify what is actually being asked.

Three legitimate triggers:
- **Narrative drift**: the artifact tells a story that is no longer true.
  The product, the audience, the offering, or the company has moved
  past what the artifact says. This is the strongest trigger.
- **Functional failure**: the artifact actively fails at its job —
  broken layouts, dead links, content nobody can find, performance.
- **Coherence failure**: accumulated additions have eroded the original
  composition. The artifact is now incoherent even though no individual
  piece is wrong.

Two weak / illegitimate triggers (push back when you see these):
- **Time-since-last-launch**: "it's been three years, we should refresh."
  Time alone is not a trigger. Stripe ran their site six years.
- **Aesthetic fashion**: "everyone uses bento grids now." Fashion-chasing
  produces work that looks like everyone else and ages fast.

Anti-pattern to watch for in yourself: **the AI agreement reflex**. When
the user says "make it more modern," do not reach for current trends.
Ask what is actually wrong with the present artifact, in narrative or
functional terms. Often the right move is to subtract or restructure,
not redesign.

Decision before leaving this layer:
- Trigger named in narrative/functional/coherence terms? □
- If user-supplied trigger was vague ("modernize"), is the underlying
  cause now articulated? □
- Is subtraction or restructuring an option you've considered, instead
  of redesign? □

If the trigger doesn't survive this gate, surface that to the user
before proceeding. "I'd push back on this — the existing artifact
seems to still tell the right story. What specifically isn't working?"

---

## Layer 2 — Purpose frame

**Question to answer**: what is this artifact for?

Borrow the senior move: ask the question one level higher than the
brief. "What is the point of a website?" "What is the point of this
dashboard?" "What is the point of this onboarding flow?"

Answer in **manifesto** terms, not feature terms:
- Who is this for? Be specific. Multiple audiences? Rank them.
- What does it broadcast about who built it? (Form-is-content axiom.)
- What evidence does it carry that a competitor could not honestly
  put on theirs? (Uniqueness preview — full audit happens at Layer 4.)
- What does it choose NOT to care about? (Negative space is also
  signal. Things you omit say something.)

The output of this layer is a one-paragraph manifesto for the artifact.
Write it. Until you can write it, you don't have enough to start.

Anti-pattern: skipping straight to "what should this section look like?"
without answering what the artifact is for. The look is downstream of
the purpose.

Decision before leaving this layer:
- Manifesto written, in plain prose? □
- Audience ranked, not listed? □
- One thing competitors couldn't honestly say identified? □
- One thing intentionally omitted identified? □

---

## Layer 3 — Class calibration

**Question to answer**: what kind of artifact is this, and what time/
quality budget does that imply?

This is the most important classification you make. It controls every
later layer's bar. Misclassification is the root of most design
failures: identity work treated as feature work (under-iterated, ships
wrong), or feature work treated as identity work (over-iterated, never
ships).

Three primary classes:

**Identity / brand-defining**
Examples: homepage, primary marketing surface, brand assets, signature
animations, the artifact users will see first and remember.
- Lifespan: years.
- Time budget: long (weeks to months).
- Reversibility: low (changes are loud).
- Quality bar: clothing test must pass — "would I be comfortable
  wearing this for the next six years?"
- Uniqueness audit must pass: a competitor cannot honestly use this.
- Default to wait-for-right over ship-on-time.

**Feature / user-blocking**
Examples: a new product capability users are waiting for, a fix for
something broken, a flow that unblocks usage.
- Lifespan: months to years, but with iteration.
- Time budget: short (the user is blocked).
- Reversibility: high (you can iterate after ship).
- Quality bar: MVQP — minimum viable QUALITY product. Ship fewer
  features rather than worse craft. Don't ship below the trust
  threshold; don't refuse to ship just for being above it.
- Default to ship at MVQP threshold and iterate.

**Commodity / conventional**
Examples: signup modal, password reset, contact form, settings panel,
404 page.
- Lifespan: long, but no one cares.
- Time budget: minimal beyond "execute the convention well."
- Reversibility: medium.
- Quality bar: conventional pattern, executed cleanly. Innovation is
  risk without reward — users have well-formed expectations.
- Default to use the well-known pattern.

**Cross-cutting flag — lean-back vs lean-forward**:
Independently of the class above, classify the user's mode:
- Lean-back (browsing, evaluating, deciding): tolerates visual content,
  not cognitive commitment. Tabs, accordions, "click to learn more"
  patterns gate too much. Show, don't make them work for it.
- Lean-forward (task, configuration, focused use): tolerates cognitive
  commitment, wants speed and density. Forms, tables, multi-step
  flows are appropriate.

AI default is lean-forward. Most marketing/identity surfaces are
lean-back. Mismatch is a common failure.

Decision before leaving this layer:
- Primary class named (identity / feature / commodity)? □
- Time budget set in concrete terms (hours / days / weeks)? □
- Quality bar named (clothing test / MVQP / convention)? □
- User mode named (lean-back / lean-forward)? □
- If hybrid (e.g., feature on a marketing surface), which class wins
  for the contested elements? □

---

## Layer 4 — Search framing

**Question to answer**: what are we searching across, and how will we
know when we've found it?

The mistake is to start exploring options without knowing what axis
you're exploring along. You end up with a heap of variations that
can't be compared because they vary on different dimensions.

Frame the search by stating:

**Discriminator questions**
What is the design choice that, once made, eliminates whole regions of
the space? Examples from the source material:
- "Flat or object with form?" (visual element character)
- "Vibrant or muted?" (color energy)
- "Show or tell?" (content delivery mode)
- "Single page or progressive disclosure?" (information architecture)

For your task, list 2–4 discriminators. These are the axes you'll
sweep across.

**Durability test**
For identity work, articulate the clothing test in concrete terms:
"if this still exists unchanged in N years, will it still feel right?"
For feature work: "if a hundred users hit this on first day, will at
least 95 of them succeed without a wrong impression?"
For commodity work: "would a user of any other modern product feel
that this is missing nothing?"

**Uniqueness audit (identity work only)**
Test every prominent element against the question: could any direct
competitor honestly put this exact element on their site, with no
changes? If yes, that element is not earning its prominence.

This is not vanity differentiation. It's an audit of whether the
artifact is doing the broadcasting work it should be. Generic feature
grids and adjective stacks fail this audit; concrete claims, specific
evidence, and brand-particular details pass it.

**Stop conditions**
What state of the artifact would make you stop searching? Write it
before exploring. Otherwise you'll search forever or stop at the first
plausible thing.

Decision before leaving this layer:
- Discriminators named (2–4)? □
- Durability test articulated? □
- For identity work: uniqueness audit framework ready? □
- Stop condition articulated? □

---

## Layer 5 — Parallel exploration

**Question to answer**: how do I generate a useful search across the
framing from Layer 4?

The default failure mode here is to make one thing and iterate on it
linearly ("now make it more blue, now make it bigger"). Linear
iteration starts in a random place and never sees the rest of the
space. A senior designer would generate a sweep.

Three exploration patterns, in increasing leverage:

**One-shot sample (weakest)**
Generate one variation. Critique. Modify. Repeat.
Use only when: extremely tight scope, small surface, and you have
high prior confidence about the right region.

**Variant batch**
Generate 5–9 variations along the discriminators from Layer 4. Lay
them out together. Compare against each other before approving any.
Use as the default for any non-trivial design choice.

**Parameter sweep (strongest)**
Build or use a tool that lets you tune the actual underlying
parameters (color, density, motion speed, copy length, layout
weight) and explore continuously. The Stripe team built a wave-
tuning tool for exactly this. Use when: the decision space is high-
dimensional and judgement-based, and you'll be making related
decisions multiple times.

Practical implementation in code contexts:
- For colors/spacing/timing: parameterize via CSS variables; sweep
  via a small playground page.
- For copy: generate the same paragraph in 5 register variants
  (formal, plain, terse, warm, technical) and compare.
- For layouts: generate 3–4 alternatives in parallel, not in series.
- For animations: render 3 timing curves side by side, not one
  after the other.

**Critical** — the variations must enter real context as fast as
possible (Layer 7 will judge them there). Generating variants in
isolation defers the only judgement that matters.

Decision before leaving this layer:
- Exploration pattern chosen (sample / batch / sweep)? □
- For batch/sweep: the variants vary on the named discriminators,
  not on incidental features? □
- Path to put variations in real context identified? □

---

## Layer 6 — Internal critique

**Question to answer**: which variants do I actually believe in, and
why do I reject the rest?

Default failure: dump all variants on the user. "Here are seven
options, which do you prefer?" This outsources the entire judgement
task. The senior move is to come with an opinion, having already
filtered options you would not personally recommend.

Three operations in this layer, run in order:

### 6a. Down-select with articulated reasons
For each rejected variant, write one sentence stating the reason. Not
"didn't feel right" — name a specific failure: "the green is too
saturated for the surrounding palette," "the accordion gates a key
message behind a click in lean-back mode," "the headline is
adjective-stacked rather than evidenced," "the motion speed makes the
loading metric feel unstable."

If you cannot articulate why a variant is rejected, you do not
actually have a reason. Either generate one by inspecting more
carefully, or include the variant.

### 6b. Double-look detail inspection
First-pass scanning misses errors. AI output specifically fails in
the long tail of details: not the main shape, but the edges. Hands
that aren't quite hands. Shadows that don't match light direction.
Words that almost mean what they should. Animations whose easing
goes slightly wrong at the end.

For each surviving variant, do a second pass specifically looking for:
- Geometric correctness (alignments, anatomies, perspectives)
- Light/shadow consistency
- Copy precision (words that almost work but aren't quite right)
- Edge cases of the layout (very long content, empty content, one item)
- Multi-context legibility (small + large + dark + light + mobile +
  desktop, whatever applies)
- Adjacent-element interactions (text over background, hover state
  on disabled state, loaded state next to loading state)

### 6c. Deletion test on every animation, decoration, and detail
For every motion, every visual flourish, every non-content element,
ask: in one sentence, what message does this carry?

If you cannot answer in one sentence, delete the element.

If the answer is "it's nice / pretty / adds visual interest," that
is not a message. Either find a real message it carries, or delete.

This is the test that prevents "polish for polish's sake" — which is
not polish at all but visual noise that signals lack of intent.

Decision before leaving this layer:
- Each rejection has a one-sentence articulated reason? □
- Double-look pass completed on survivors? □
- Deletion test passed on every non-content element? □
- Final set is 1–3 variants you would actually recommend, not "all
  of them"? □

---

## Layer 7 — Real-context decision

**Question to answer**: with the artifact in place, in its actual
habitat, with its real neighbors and real content and real users in
mind, what's the call?

The isolation fallacy is the dominant failure mode here. Something
that looks great on a clean canvas, in a Figma frame, on its own,
will routinely look wrong once it's in the page with the typography,
the surrounding elements, the actual content lengths, the load
states, the adjacent sections. The design app is not the habitat.

Three operations:

### 7a. Get into context
- For web work: render in the actual page, with the actual surrounding
  components, with realistic content lengths, at the resolutions and
  device classes you care about.
- For copy: place it in the layout with everything else around it,
  not in a doc.
- For data viz / illustration: surround with the body content that
  will sit beside it.
- For animations: see the transitions into and out of adjacent
  sections, not the animation alone.

### 7b. Sit with it
- Walk away. Come back with fresh eyes.
- Imagine the user's mode (lean-back / lean-forward from Layer 3).
  Move through the artifact in that mode.
- If identity work: imagine the artifact unchanged in N years (the
  clothing test from Layer 4). Are you still comfortable?

### 7c. Decide, with the wait option on the table
The legitimate options are:
- **Ship it**: meets the bar from Layer 3 in real context.
- **Cut scope, ship the rest**: drop the parts not yet at bar; ship
  what's ready. (Stripe's "let's just only do three or one" option.)
- **Wait**: hold the launch until brand-defining elements are right.
  Use sparingly. Justify explicitly. Identity work is the main case.
- **Push back**: the request itself is wrong; surface this to the
  user.

Default for an AI agent: choose ship-it too readily. Counter-force:
the wait and cut-scope options are real options, not failures. Use
them when warranted.

Decision before leaving this layer:
- Artifact evaluated in real context, not in isolation? □
- Sat with it for at least one perspective shift (different role,
  different time, different frame)? □
- Decision named explicitly (ship / cut scope / wait / push back)?
  □
- If wait or cut-scope, the cost of that decision named (delay,
  reduced scope) and accepted? □

---

## Layer 8 — Walk the store

**Question to answer**: now that this exists in the artifact, does the
whole composite still hold together?

This is the post-ship traversal. (For multi-stage work, run this
after each significant change, not just at the end.) The point is
that local optimization can degrade global coherence: you renovated
the dining room and now the kitchen looks worse than it did before.

Three operations:

### 8a. Traverse the user journey
Pick a user role (different from the one you designed for if
possible). Move through the artifact end to end as that user. Not
the happy path — find the dead ends. Things that look fine in
isolation but break when you arrive at them from a specific
direction.

### 8b. Cross seams
If your change touched one section of a larger artifact, walk the
adjacent sections. Are the typography, color, motion, copy
register, density consistent? Did you create a "renovated dining
room" effect?

### 8c. Mixed-discipline witness
Different roles see different things. If you have access to multiple
agents, perspectives, or tools — use them. Even running the same
review with different framing (engineer's eye, brand eye, content-
strategist eye, accessibility eye) catches things a single review
misses.

In code-adjacent design work specifically, run reviews from at least:
- A user-of-the-product perspective ("does this help me?")
- A maintainer-of-the-code perspective ("can this be sustained?")
- A first-time-visitor perspective ("what does this signal about the team?")

Decision before leaving this layer:
- End-to-end traversal completed in at least one user role? □
- Adjacent sections walked? □
- At least two distinct perspectives applied? □
- Dead ends or coherence failures found and either fixed or
  acknowledged? □

---

## Layer 9 — Drift resistance

**Question to answer**: how do I keep this from decaying after I leave?

This is the long-tail layer. It runs every time you (or anyone) makes
a future change to the artifact.

Three habits:

### 9a. Suspect ease
Whenever a change feels easy, fast, "good enough," check whether you
are inside the ease trap. Ask: "Don't be wooed by how easy that was
to achieve. Is this really great? Have I really hit the mark?" The
fact that AI produces output cheaply does not mean the output is good.
Decouple production cost from quality assessment.

### 9b. Cost-of-mediocre framing
The default question is "what does it cost to make this better?" The
reframe is "what does it cost to leave this as-is, and what
precedent does this set?" One "good enough" decision costs little.
A thousand of them is what makes companies mediocre.

When you feel the pull to ship something that's good-enough, ask:
"If I let this slide, what else am I going to let slide?"

### 9c. Sunk-cost callout
Don't ship because the team / you put a lot of effort in. The
artifact is only as good as what users experience. The team will
not be happy with a meh ship; they'll be happier with a delay or
a smaller scope. Effort already spent is not a reason to ship the
wrong thing.

Decision before leaving this layer:
- Have I noted at least one place where I almost accepted ease and
  pushed back? □
- For every "good enough" call, the precedent it sets is named? □
- No decisions justified by sunk cost alone? □

---

## Compressed loop (for small tasks)

Full nine layers is for non-trivial design work. For small tasks,
the irreducible minimum is:

1. **Class** (Layer 3): is this identity / feature / commodity?
   What time/quality budget?
2. **Frame** (Layer 4): what discriminator question? What's the stop
   condition?
3. **Critique** (Layer 6): articulated reasons for rejections, double-
   look pass, deletion test.
4. **Real-context decide** (Layer 7): in habitat, sit with it, name
   the decision.

Even for trivial tasks, run the deletion test (6c) and the suspect-
ease check (9a). Those two are the minimum-viable counter-force.

---

## Vocabulary (use these names; they're tools)

- **Manifesto framing** — answering "what is this for?" before "what
  should it look like?" (Layer 2)
- **Clothing test** — "would I wear this shirt for the next six
  years?" The durability check for identity work. (Layer 4)
- **Uniqueness audit** — "could a direct competitor honestly put
  this exact element on their site?" (Layer 4)
- **Scrolly telling** — the failure mode of one-section-per-screen
  storytelling that asks the user for too much patience.
- **Lean-back vs lean-forward** — the user-mode classification that
  governs disclosure pattern choice. (Layer 3)
- **Add-on tax** — the accumulation drift where each rational addition
  degrades the composite narrative. (Layer 1)
- **Show, don't tell** — prefer evidence/demonstration over assertion.
  (Worldview 2 + Layer 4)
- **Progressive disclosure** — the gradient nothing → glimpse → modal
  → page → full doc. Pick the right depth per element. (Layer 3)
- **Isolation fallacy** — judging an element against a clean canvas
  instead of its real habitat. (Layer 7)
- **Double-look** — second-pass detail inspection specifically for
  long-tail errors AI produces. (Layer 6)
- **Deletion test** — "what message does this carry, in one
  sentence?" Failure mode → delete. (Layer 6)
- **Ease trap** — accepting cheap output because it was cheap.
  (Layer 9 + Worldview 5)
- **Mediocrity gravity** — the default decay direction; resistance is
  the operation. (Worldview 5 + Layer 9)
- **Dining room only** — the local-optimization trap where renovating
  one area makes adjacent areas look worse. (Layer 8)
- **Walking the store** — post-ship end-to-end traversal in user
  role, with mixed-discipline witnesses. (Layer 8)
- **MVQP** — minimum viable QUALITY product. The trust-floor minimum,
  not the feature-floor minimum. (Layer 3 + Layer 7)

---

## What this skill is fighting against (in you)

You will tend to:
- Accept your first plausible output (mediocrity gravity)
- Optimize literal claims rather than evidence (form-content axiom violation)
- Treat all artifacts with the same urgency (no time-asymmetry awareness)
- Judge in isolation against a blank canvas (isolation fallacy)
- Add when asked to improve (add-on tax)
- Approve your own output without a perspective-shift critique (different-eyes axiom violation)
- Miss long-tail errors because you scan once (no double-look)
- Iterate linearly, not in parallel (no parameter sweep)
- Skip details no one will see directly (form-content axiom violation)
- Treat motion as decoration to add (no intent test)
- Surface everything because all of it is "important" (no progressive disclosure)
- Apply lean-forward UX to lean-back contexts (no mode classification)
- Optimize one section without checking adjacent (no walking the store)
- Refuse to delete; only add (no deletion test)
- Apply lower standard to AI-produced output because it was cheap (ease trap)
- Outsource judgement to the user with "here are 7 options" (no down-select)
- Refuse to ship for fear of imperfection (perfection trap, MVQP violation)
- Ship for sake of shipping (mediocrity gravity)
- Be time-blind: no clothing test (no durability framing)
- Be brand-blind: no uniqueness audit (form-content axiom violation)

Each of these is corrected by a specific layer or check above. When you
catch yourself doing one, name it (Worldview 7) and run the relevant
check.

---

## Final pass before declaring done

Before saying the work is complete, ask in this exact order:

1. Have I run the layers that apply to this artifact's class?
2. Did I do a deletion test on every non-content element?
3. Did I judge in real context, or am I about to ship something I
   only saw in isolation?
4. If a senior designer walked into the room right now, would they
   say "ship it" or would they ask why I left some specific failure
   mode unaddressed? If I can name a likely failure mode they'd
   point at, I'm not done.
5. Am I shipping because it's actually right, or because it was
   easy? If easy, suspect.

Only after these five answer favorably is the work done.
