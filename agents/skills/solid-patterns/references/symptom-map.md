# Symptom → Remedy Map (Extended Lookup)

Use this when SKILL.md's quick table doesn't match exactly. Each entry: **what you see in code → what to consider → KISS check.**

Each remedy assumes the **fitness gate** has been passed (see `references/kiss-yagni.md`). If the variation isn't real, **skip the remedy and add a comment explaining why**.

---

## Conditional / branching code smells

### `if/elseif` chain on a type code or string
```js
if (type === "credit_card") { ... }
else if (type === "paypal") { ... }
else if (type === "crypto") { ... }
```
**Consider:** Strategy pattern (extract algorithms) or polymorphism (Replace Conditional with Polymorphism refactoring).
**Principle:** OCP — adding a new payment type currently requires editing this code.
**KISS check:** If only 2 stable types, conditional is fine. Strategy earns its complexity around 3+ variants OR when adding new variants is frequent.

### `switch (status)` repeated across many methods of the same class
```js
class Document {
  publish() { switch (this.status) { ... } }
  archive() { switch (this.status) { ... } }
  share()   { switch (this.status) { ... } }
}
```
**Consider:** State pattern.
**Principle:** OCP + SRP.
**KISS check:** If only 2-3 stable states with 1-2 methods each, plain conditionals are fine.

### Long method with deeply nested conditionals
**Consider:** First, refactoring (Extract Method, Replace Nested Conditional with Guard Clauses). Patterns may not be needed.
**KISS check:** Most of the time, a refactor — not a pattern — is the answer.

---

## Class-shape smells

### Class name with "And" or vague suffix (`UserManager`, `OrderHelper`, `DataProcessor`)
**Consider:** SRP split. Identify the actors driving change. Each actor → its own class.
**KISS check:** If the class is small and stable and has one actual user, leave it.

### Class is enormous and touches many subsystems
**Consider:** SRP split + possibly Service Layer if the responsibilities form architectural seams (UI ↔ business ↔ data).
**KISS check:** Splitting earns complexity if the class is genuinely painful (test churn, merge conflicts, hard to navigate).

### Subclass that throws "not supported" or no-ops inherited methods
**Consider:** ISP violation — the parent interface is too fat. Split into smaller interfaces.
**Principle:** ISP.
**Alternative:** Maybe the inheritance was wrong; consider composition.

### Subclass overrides parent method to return different type / different semantics
**Consider:** LSP violation. Either fix the hierarchy or replace inheritance with composition.
**Red flag:** Caller code with `if obj instanceof SubtypeX` is the symptom of an LSP violation that has propagated.

---

## Construction / wiring smells

### Class constructor / methods contain `new ConcreteX()` for dependencies
```js
class Service {
  constructor() {
    this.db = new MySQLClient(...);
    this.cache = new RedisClient(...);
  }
}
```
**Consider:** Dependency Injection (constructor injection) + DIP (depend on interfaces).
**Principle:** DIP.
**KISS check:** Stable, ubiquitous dependencies (`String`, `List`, value objects) don't need this. Apply for things you'd want to swap in tests or for alternatives.

### Conditional construction scattered through the code
```js
let transport;
if (config.mode === "truck") transport = new Truck();
else if (config.mode === "ship") transport = new Ship();
```
**Consider:** Factory Method (centralize construction).
**Principle:** SRP + OCP.
**KISS check:** If construction happens in one place and is unlikely to grow, leave it.

### "Just need one of these globally" temptation
**Consider:** Dependency Injection FIRST. Only consider Singleton if DI is genuinely impossible.
**Principle:** DIP.
**Singleton warning:** Singleton violates SRP, makes testing painful, hides dependencies. Refactoring.Guru's own page warns against it.

---

## Integration smells

### Wrapping every call to a 3rd-party / legacy API with massaging code
```js
const raw = legacyApi.fetch(opts);
const result = transformLegacyShape(raw);
const normalized = normalizeFields(result);
```
**Consider:** Adapter pattern. Wrap the legacy API once with the interface your code expects.
**Principle:** SRP (separates conversion from business logic) + OCP.
**KISS check:** If you call the API from one place, inline conversion is fine.

### Two layers of code that "almost" speak the same protocol
**Consider:** Adapter. Or: refactor one side to match the other if you control both.

### Migrating between two SDKs / API versions
**Consider:** Adapter at the seam. New code uses your interface; the adapter dispatches to old or new SDK based on flags.

---

## Composition / extension smells

### Combinatorial subclass explosion
```
EmailNotifier
SMSNotifier
EmailAndSMSNotifier
EmailAndSlackNotifier
EmailAndSMSAndSlackNotifier
...
```
**Consider:** Decorator pattern. Each channel is a wrapper; stack them at runtime.
**Principle:** OCP, composition over inheritance.
**KISS check:** If only 2-3 channels with no real combination need, simpler approaches work.

### Repeating the same "wrap with caching / logging / retry" pattern
**Consider:** Decorator. Each cross-cutting concern is its own wrapper.
**Real-world equivalents:** HTTP middleware, AOP interceptors, function decorators (Python).

### Need to add behavior to a `final` / sealed class
**Consider:** Decorator (composition wrapper).

---

## Architecture smells

### Controllers / route handlers contain business logic
**Consider:** Service Layer. Extract business operations into application services; controllers just translate HTTP ↔ service calls.
**KISS check:** For a 3-endpoint app, this may be overkill.

### Same business operation duplicated across multiple controllers / handlers
**Consider:** Service Layer. The shared operation belongs in a service.

### Components are scaling at very different rates / written by different teams
**Consider:** Decoupling toolkit — events, message queues, separate deployments.

### Distributed components need to coordinate atomic state changes
**Be cautious:** Loose coupling and transactional integrity conflict. Often: business-level compensation rather than 2PC.

---

## Test / maintainability smells

### Hard to write a unit test because the unit constructs its own dependencies
**Consider:** DI. Inject dependencies → mock them in tests.
**Principle:** DIP.

### Tests need real DBs, networks, filesystems
**Consider:** DI + abstraction over the IO layer.
**KISS check:** Some integration tests SHOULD hit real things. Don't fake everything.

### Touching one method requires re-testing many unrelated methods
**Consider:** SRP — likely the class has multiple actors mashed together.

---

## Anti-patterns: when the smell is the WRONG signal

### "Premature interface" — interface with one implementation that has existed for years
**Action:** Inline the interface back into the concrete class. The abstraction was speculative (YAGNI violation).

### "Pattern fever" — code where pattern names appear more than business names
**Action:** Question every pattern. Some may not be earning their complexity.

### "Bloated DI container config" — XML/code defining hundreds of bindings
**Action:** Reconsider whether all those abstractions are needed. Manual DI for the simple cases is often clearer.

### "Service object for everything" — one service class per controller method
**Action:** Service layer is a tool, not an obligation. Group by purpose, not by route.

### "DRY' d code that serves different actors"
**Action:** **Un-DRY it.** Duplication serving different stakeholders is correct (per SRP). The shared abstraction is the bug.

---

## How to use this map (for the agent)

1. **Spot the symptom** in the user's code or the proposed design.
2. **Apply the fitness gate** from `references/kiss-yagni.md`. If speculative → don't recommend.
3. **Recommend the remedy** with:
   - The specific pattern/principle name.
   - **Why** (which symptom you saw, what it predicts will go wrong).
   - **What to do** (the concrete code change).
   - **The KISS check** (when to NOT apply it).
4. **Cross-reference** to the deeper file (`references/solid.md`, `references/patterns.md`, etc.) if the user wants more.
5. **Be honest** if you're recommending the closest match but the fit isn't perfect — say so.
