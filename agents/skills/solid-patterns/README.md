# solid-patterns-skill

An agent skill for deciding when to apply SOLID, design patterns, and decoupling techniques during code design and review. It's also a skill for *not* applying them when the situation doesn't warrant it, which is most of the time.

Works with agentic coding tools that support the [agent skills](https://agentskills.io/specification) format: Claude Code, OpenCode, Copilot CLI, Gemini CLI, and others.

## Why this exists

Most design failures I've watched (and caused) didn't come from not knowing the patterns. They came from reaching for a pattern because it sounded clean, with no concrete present-day pressure to justify it. Strategy classes for two stable algorithms. Interfaces with one implementation, forever. Singleton because "we only need one." That kind of thing.

So this skill is built around a single question:

> What would change in the user's code if I did NOT recommend this?

If the honest answer is "almost nothing," the recommendation is ceremony. The skill teaches the agent to say so, out loud, instead of reciting the pattern catalog.

## What's in it

The skill gives the agent:

- A fitness gate that filters ceremonial recommendations before they get offered.
- A symptom-to-remedy table mapping concrete code smells to specific principles or patterns.
- A conceptual map showing how SOLID, the patterns, and the architectural pieces all serve the same goal: loose coupling.
- Two worked examples for every multi-finding review: one recommendation that passes the gate, one that fails it (with the right thing to say instead).
- Sequencing guidance for code reviews: security and correctness first, structural changes second, polish last. Don't bury a hardcoded credential under a Strategy lecture.

KISS and YAGNI sit on top of all of it as the moderation force. The skill prefers stdlib and language idioms over GoF boilerplate (a `dict[str, Callable]` is already a Strategy in Python, no `StrategyContext` class needed). It treats Singleton with the suspicion Refactoring.Guru's own page recommends.

## Coverage

The five SOLID principles (SRP, OCP, LSP, ISP, DIP), including DI mechanics and the constructor-injection pattern.

Six design patterns. Two behavioral (Strategy, State), two structural (Adapter, Decorator), two creational (Factory Method, and Singleton with explicit cautions).

Decoupling pieces: loose coupling, the four-technique decoupling toolkit (abstraction, DI, events, message queues), and the service layer pattern.

Moderation principles: KISS, YAGNI, the rule of three, and the standing question above.

## What it doesn't cover

The other 16 GoF patterns aren't in here: Builder, Abstract Factory, Prototype, Bridge, Composite, Facade, Flyweight, Proxy, Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, Template Method, Visitor. The skill knows they exist and will mention them when the problem clearly maps, but the depth lives elsewhere (the GoF book, Refactoring.Guru).

Also out of scope:

- Functional patterns (monads, lenses, transducers).
- Concurrency patterns (Actor, Producer/Consumer).
- Distributed systems beyond loose-coupling basics.
- DDD tactical patterns past a Service Layer mention.
- Refactoring catalog mechanics. Use [Refactoring.Guru](https://refactoring.guru/refactoring) for those.
- Architectural styles (Hexagonal, Clean, Onion) past passing references.

## Repository layout

```
solid-patterns-skill/
├── SKILL.md                  # Entry point. Load this first.
├── references/               # Lazy-loaded deep references
│   ├── solid.md              # Each SOLID principle in depth
│   ├── patterns.md           # The 6 GoF patterns covered
│   ├── decoupling.md         # Loose coupling, DI, service layer
│   ├── kiss-yagni.md         # The moderation stance
│   └── symptom-map.md        # Extended symptom-to-remedy lookup
├── LICENSE
└── README.md
```

`SKILL.md` is around 2,400 words. The reference files load only when the agent needs the depth for a specific recommendation, which keeps the active context small.

## Installation

Open the agent you want to install it into and paste the prompt below. The agent figures out where the skills directory lives on your platform and clones into the right place.

```
Install the solid-patterns skill from https://github.com/cornellsh/solid-patterns-skill into my skills directory for this agent. If you don't know where the skills directory is, check your own configuration or documentation first. After cloning, confirm the skill is discoverable and tell me whether I need to restart the session for it to load.
```

## When the agent activates it

- Designing a new class, module, interface, or service.
- Refactoring code that has grown awkward.
- Reviewing code for OOP design quality.
- Choosing between inheritance and composition.
- Deciding whether a specific pattern fits.
- Asking whether the code has the right abstractions, or too many.
- Any "is this design good?" / "should I use pattern X?" / "how do I clean this up?" question.

It stays out of the way for narrow questions (rename a method, fix a typo), throwaway scripts, prototyping, and anything that isn't really a design call.

## Design stance

Two quotes do most of the philosophical work:

> What would change in the user's code if I did NOT recommend this?

> It's impossible to make a completely closed program. What you can choose is what to close and what to leave open. — paraphrased from the Brains To Bytes OCP article

SOLID and patterns are flexibility investments, not universal laws. They cost real complexity. They earn it back only when the variation pressure they hedge against is real and present. KISS wins when it isn't.

## Sources

The skill is a synthesis of 19 sources covering SOLID, KISS, the design patterns above, loose coupling, and decoupling:

- DigitalOcean — *SOLID Design Principles Explained*
- Brains To Bytes — the full SOLID series (SRP, OCP, LSP, ISP, DI/DIP) by Juan Luis Orozco Villalobos
- Refactoring.Guru — pattern catalog and per-pattern deep dives (Strategy, State, Adapter, Factory Method, Decorator, Singleton)
- GeeksforGeeks — *SOLID Principles with Real Life Examples*
- Wikipedia — KISS principle, Loose coupling, Service layer pattern
- Reddit r/learnprogramming — community thread on SOLID
- Bagus Cahyono — *Decoupling* notes

The cross-reference index, conflict analysis, and synthesis themes from research are kept local and aren't published with the skill. They were the working material that produced it.

## Contributing

Issues and PRs welcome. When proposing a change:

1. Say what behavior the change actually produces. Not "improves clarity," but "the agent will now also flag X."
2. Run the change against a realistic code review scenario before opening the PR. There's an example one in the verification step from this repo's commit history if you want a starting point.
3. If the change touches both SKILL.md and a reference file, update both.

The skill follows the [agentskills.io specification](https://agentskills.io/specification). The YAML frontmatter has to stay under 1,024 characters, so resist the urge to expand the description.

## License

MIT License — see [LICENSE](LICENSE).
