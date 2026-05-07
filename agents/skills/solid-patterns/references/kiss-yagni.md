# KISS, YAGNI, and the Moderation Stance — Reference

This is the **counterweight** to the rest of the skill. SOLID and design patterns are tools to invest in flexibility — but unjustified flexibility is technical debt with extra steps.

**Core stance:** Every pattern recommendation, every interface extraction, every layer of indirection must pass a fitness check: *is the variation/change real, or speculative?* If speculative — **don't add it**.

---

## KISS — Keep It Simple, Stupid

### Origin
Coined by Kelly Johnson, lead engineer at Lockheed Skunk Works (designers of U-2, SR-71). The "stupid" doesn't insult the engineer — it refers to the **relationship between how things break and the sophistication available to repair them**.

The canonical illustration: jet aircraft must be repairable by an average mechanic in the field under combat conditions, with only basic tools.

### Plain meaning
**Simplicity should be a design goal.** Solutions should accommodate worst-case maintenance conditions, not optimal lab conditions.

### The KISS test (apply this to your designs)
> Could a stranger encountering this code at 3am, debugging an outage with limited context, understand and fix it?

If the answer requires the stranger to first understand a custom DI framework, three layers of decorators, and a state machine — KISS is being violated.

### Kindred ideas
- **Occam's Razor** — fewest assumptions.
- **Saint-Exupéry**: "Perfection is reached not when there is nothing left to add, but when there is nothing left to take away."
- **Einstein** (paraphrased): "Make everything as simple as possible, but not simpler."
- **Saint-Exupéry / Mies van der Rohe**: "Less is more."
- **Steve Jobs**: "Simplify, simplify, simplify."
- **Parkinson's Third Law**: "Expansion means complexity and complexity, decay; the more complex, the sooner dead."

### KISS-friendly companions
- **Unix philosophy** — small tools doing one thing well.
- **Rule of least power** — use the simplest mechanism that solves the problem.
- **DRY** (with care — see SRP for when DRY is wrong).
- **Worse is better** / "less is more."

### Famous "non-KISS" failure modes
- **Heath Robinson contraptions** / **Rube Goldberg machines** — humorously over-complex.
- Enterprise FizzBuzz — using 14 design patterns to print 1 to 100.

---

## YAGNI — You Aren't Gonna Need It

### Plain meaning
Don't build features, abstractions, or extension points until you have **concrete present-day evidence** that you need them.

### The YAGNI heuristic
> "We might need to support PostgreSQL someday."  
> → **No.** When that day comes, refactor. Until then, code for the actual requirement.

### What YAGNI rules out
- Speculative interfaces ("this might have multiple implementations someday").
- Configuration knobs no one has asked for.
- "Just in case" extension points.
- Generalizing the second instance prematurely (the **Rule of Three**: extract abstraction on the third occurrence, not the second).

### What YAGNI does NOT rule out
- Building things you actually need now.
- Quality work (tests, error handling, naming).
- Refactoring to reduce existing complexity.
- Following SOLID where the variation pressure is **already real**.

---

## The fitness gate (apply BEFORE recommending any principle/pattern)

Before suggesting Strategy, Decorator, an interface extraction, a service layer split, or any structural change, the agent must answer:

| Question | If "yes" → proceed | If "no" → reconsider |
|----------|--------------------|-----------------------|
| Is the variation/change pressure **already concrete and real** (not hypothetical)? | Apply | Don't add the structure |
| Will the abstraction make the code **easier to reason about** for a maintainer? | Apply | Don't add the structure |
| Is the cost of being wrong **low** (small refactor) AND benefit **high** (real flexibility)? | Apply | Don't add the structure |
| Is there **at least one specific concrete scenario** that needs the abstraction now? | Apply | Don't add the structure |

If two or more answers are "no" → **defer**. Add a comment explaining what would trigger revisiting it. Move on.

---

## The "second time" rule

A practical heuristic that captures both KISS and YAGNI:

| Occurrence | Action |
|------------|--------|
| **First time** you write something | Just write it. Solve the problem. |
| **Second time** you face a similar problem | Notice. Tolerate the duplication for now. |
| **Third time** | Now extract the abstraction. The shape is clear. |

Premature extraction (after one occurrence, or in anticipation) creates wrong abstractions that are worse than duplication.

---

## When KISS overrides everything else

KISS wins these arguments:
- Pattern X "would be cleaner" but the system has only 2 stable variants → **KISS**, use a conditional.
- Interface "for future flexibility" with one implementation → **KISS**, use the concrete class.
- "We should add a service layer" for an app with 3 endpoints → **KISS**, just call the domain methods directly.
- "We should use Singleton for this config" → **KISS** + DIP, just pass the config in.

When KISS is ALSO violated by the existing code (e.g., a 2000-line god class), the structural intervention earns its complexity cost. KISS does not mean "never refactor."

---

## Red flags that suggest you're violating KISS/YAGNI

- "We might need this someday."
- "This makes it more flexible."
- "This is more enterprise-grade."
- The pattern's name appears in code/comments/docs more than the *problem* it solves.
- You are introducing the third level of indirection in a row.
- A new team member needs >30 minutes to trace one user-visible feature through the code.
- The class diagram is bigger than the actual feature spec.
- You added a config knob "in case someone wants to change it."
- You wrote a base class because the subclass might have a sibling someday.

---

## The standing question

For every principle/pattern recommendation made by this skill, the answering agent must be ready to answer:

> **What would change in the user's code if I did NOT recommend this?**

If the honest answer is "almost nothing" → the recommendation is ceremony. **Skip it.**

If the honest answer is "they'd hit pain X next week / they're already feeling pain Y" → the recommendation is justified.
