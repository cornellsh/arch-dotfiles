# Decoupling, Loose Coupling & Service Layer — Reference

Loose coupling is the **meta-goal** that SOLID principles, design patterns, and architectural patterns all serve. This reference covers the concept, the practical toolkit, and the service layer pattern.

---

## Loose Coupling — the concept

### Definition (Wikipedia)
A **loosely coupled** system is one in which:
1. Components are **weakly associated** — changes in one have minimal impact on others.
2. Each component has **little or no knowledge** of the definitions of other separate components.

**Coupling = the degree of direct knowledge that one component has of another.**

Loose coupling ≈ **encapsulation** vs. non-encapsulation.

### Tight coupling vs loose coupling — the canonical example
```
// TIGHT: dependent class holds a pointer to a CONCRETE class
class Service {
    private MySQLDatabase db;     // can't substitute
    Service() { db = new MySQLDatabase(); }
}

// LOOSE: dependent class holds a pointer to an INTERFACE
class Service {
    private Database db;           // any implementation works
    Service(Database db) { this.db = db; }
}
```

This is **dependency inversion** in action.

### Why it matters
- Components can be **replaced** with alternative implementations.
- Components are **less constrained** to the same platform/language/OS/build environment.
- **Easier to test** in isolation.
- **Easier to scale** — replace/upgrade individual components without disrupting others.

### Trade-offs (be honest)
- If decoupled in **time**, transactional integrity is hard → need additional coordination.
- **Data replication** for availability creates consistency problems.
- Extra abstractions/indirection have a **performance cost**.
- Genuinely simple systems may not benefit (KISS).

---

## The Decoupling Toolkit (Bagus Cahyono's framing)

Four practical techniques to reduce coupling:

### 1. Abstraction
Use interfaces to define behaviors. Consumers depend on the interface, not the concrete class.

**Example:** `interface Repository { find(id) }` decouples business logic from data access.

### 2. Dependency Injection (DI)
Inject dependencies into a component instead of instantiating them internally.

**Example:** Pass a database connection into a service's constructor instead of `new`-ing it inside.

(See `references/solid.md#d---dependency-inversion-principle-dip` for the full DI breakdown.)

### 3. Event-Driven Architecture
Components communicate through events instead of direct calls.

**Example:** Publish/subscribe systems. Producer doesn't know who consumes; consumers can be added/removed without producer changes.

### 4. Message Queues
Asynchronous messaging between decoupled components.

**Example:** RabbitMQ, Kafka. Producer puts a message on the queue; consumer pulls when ready. Time-decoupled and process-decoupled.

---

## When decoupling is overkill (KISS check)

- **Small applications** — adds unnecessary complexity.
- **Performance-critical paths** — abstractions/messaging add latency.
- **Single-implementation, no foreseen change** — interface is ceremony.
- **One-off scripts or throwaway code**.

The decoupling investment pays off when:
- Multiple implementations exist or are likely.
- Components are written by different teams or in different languages.
- Components have independent change cycles.
- Components cross trust/network boundaries.
- Testability of isolated components matters.

---

## Eleven forms of loose coupling (from Josuttis, *SOA in Practice*)

For deeper / distributed-system contexts:
1. Physical connections via mediator (vs. direct).
2. Asynchronous communication style (vs. synchronous).
3. Simple common types only in data model.
4. Weak type system.
5. Data-centric, self-contained messages.
6. Distributed control of process logic.
7. Dynamic binding of service consumers/providers.
8. Platform independence.
9. Business-level compensation (vs. system-level transactions).
10. Deployment at different times.
11. Implicit upgrades in versioning.

**Warning:** Over-engineered ESBs and middleware can produce the *opposite* effect — undesired tight coupling and a central architectural hotspot.

---

## Service Layer Pattern (architectural)

### Definition
An **architectural pattern** that organizes services in a service inventory into **logical layers**. Services in the same layer share functionality.

### Two common layering strategies

**Three-layer (most common):**
- **Task** layer — orchestration, process-specific logic.
- **Entity** layer — business entities and their operations.
- **Utility** layer — cross-cutting concerns, infrastructure.

**Five-layer (Bieberstein et al.):**
- Enterprise / Process / Service / Component / Object.

### Two interpretations to know
1. **Strict SOA sense**: organizing services in a service inventory (the Wikipedia definition).
2. **Mainstream application architecture sense**: a layer of "service objects" / "application services" that sit between controllers/UI and the domain model. Encapsulates business operations and orchestrates between layers.

Both senses share the principle: **a logical layer that groups operations by purpose, decoupling consumers from implementation details.**

### When to use
- Enterprise systems with many services that mix concerns.
- Teams cannot find or reason about services because they're scattered.
- Changes ripple unpredictably across services.
- Need a clear seam between UI/transport and domain logic (typical web app).

### When NOT to use
- Small apps with few services — layering adds overhead.
- Single-purpose script or microservice with no internal layering need.

### Common companions
- **Repository pattern** for data access (entity-layer).
- **Domain-Driven Design (DDD)** application services.
- **Hexagonal / clean architecture** (layered patterns at scale).

---

## Decoupling vs the SOLID principles — how they connect

| SOLID principle | How it serves decoupling |
|-----------------|--------------------------|
| **SRP** | Each class has one reason to change → changes don't ripple to unrelated concerns. |
| **OCP** | Extensions don't require modifying existing code → consumers stay isolated from new variants. |
| **LSP** | Substitution works → consumers can depend on the abstraction, not concrete subtypes. |
| **ISP** | Smaller interfaces → consumers depend only on what they actually use. |
| **DIP** | Direct mechanism for loose coupling — depend on abstractions. |

> **GeeksforGeeks puts it explicitly:** "The SOLID principles help in enhancing loose coupling."

---

## Quick decision guide

| Situation | Move |
|-----------|------|
| Class instantiates its dependencies via `new ConcreteX()` | Apply **DI** (constructor injection) |
| Need to swap implementations for tests | Apply **DIP** + DI |
| Producer needs to notify N unknown consumers | Consider **Event-Driven** / pub-sub |
| Two components must scale independently | Consider **Message Queue** between them |
| Web app's controllers contain business logic | Extract a **service layer** between them |
| Distributed system needs transactional integrity AND loose coupling | Choose carefully — these conflict. Often: business-level compensation rather than 2PC. |

---

## Anti-patterns to watch for

- **Over-engineered ESB** — central hotspot disguised as decoupling middleware.
- **God service in the service layer** — defeats the purpose; split by concern.
- **Interface for one implementation, forever** — speculative abstraction. Wait until the second implementation appears (YAGNI).
- **Pretending DI without it** — calling `Locator.get(DatabaseService.class)` is hidden coupling, not DI.
