# Product UI & infographics — prompt templates

Concrete templates and worked examples. All follow the universal formula from SKILL.md (Subject, Action, Location, Composition, Lighting, Style, Text), paired with recommended CLI flags.

Table of contents:

- [UI mockups (mobile screens)](#ui-mockups-mobile-screens)
- [Infographics & diagrams](#infographics--diagrams)

---

## UI mockups (mobile screens)

**Why this matters:** UI mockups need device chrome, native components, realistic content (no Lorem ipsum), and a consistent design language. Nano Banana Pro handles this far better than Nano Banana 2 because of text rendering and spatial logic.

**Template (single screen):**
```
A high-fidelity mockup of [device] showing the [screen name] of [app description].
Native [iOS / Android / web] design language. [Light/dark] theme.
[Brand colors]. [Typography].
Six to eight distinct UI elements: [list them: nav, header, list, card, tab bar, etc.].
Realistic, domain-specific content (no Lorem ipsum). Soft even lighting, professional presentation.
```

**Example — single iOS screen:**
```bash
imagegen 'A high-fidelity mockup of a modern iPhone 15 Pro showing the home screen of "Bloom", a habit-tracking app. Native iOS 17 design with SF Pro typography, light theme with a soft cream background and sage green accents. Top: a compact greeting "Good morning, Andreas" with a small streak counter showing "12-day streak". Middle: a 2x2 grid of habit cards (Meditate, Read, Walk, Hydrate), each with a circular progress ring and clean iconography. Bottom: a native iOS tab bar with Home, Stats, Garden, Profile. Realistic content, 8pt grid spacing, professional product-marketing render quality.' \
  -a 9:16 -r 2K
```

**Example — multi-screen flow:**
```bash
imagegen 'Four iPhone 15 Pro screens side-by-side showing the onboarding flow of "Ledger", a personal finance app. Dark theme with deep navy background and electric blue accents. SF Pro typography, edge-to-edge displays.
Screen 1: welcome screen with the wordmark "Ledger" centered and a single "Get started" button.
Screen 2: account connection screen listing 4 banks with logos and a primary CTA "Connect securely".
Screen 3: spending overview with a colorful donut chart, total "$2,418 this month", and a 3-row category list.
Screen 4: a single transaction detail screen with merchant logo, amount "-$42.18", category "Coffee", and a map snippet showing the location.
Realistic financial content. Subtle glow lighting, professional product-marketing presentation. Devices arranged on a soft gradient background.' \
  -a 16:9 -r 2K
```

**Tips:**
- Cap each screen at 6–8 elements. More than that and the model loses spatial coherence.
- Keep titles short (`under 30 chars`) so text rendering stays clean.
- Always specify the design system (`iOS 17 / SF Pro`, `Material You`, `shadcn-style`) so the model has a coherent reference.
- For dashboards, name the metrics ("MRR $48,200", "+18% MoM") rather than asking for "KPIs".

---

## Infographics & diagrams

**Why this matters:** Both models render legible infographic text, but Pro is the safer choice for dense text, factual layouts, and complex multi-element diagrams.

**Template:**
```
An infographic explaining [topic]. [Layout: vertical / 4-step horizontal / flow / hub-and-spoke].
Clean [vector / editorial] style. [Color palette].
Each [step / node] labeled with: [list the labels and what each shows].
```

**Example — process diagram:**
```bash
imagegen 'A clean vector infographic explaining how a Replicate prediction lifecycle works. Vertical 5-step layout with arrows between steps. Pastel palette: soft mint, peach, lavender, cream, charcoal text.
Step 1 — "Submit": a small icon of a paper plane and the label "POST /predictions".
Step 2 — "Queue": a clock icon and the label "status: starting".
Step 3 — "Boot": a gear icon and the label "model cold-start".
Step 4 — "Predict": a spinner icon and the label "status: processing".
Step 5 — "Output": a checkmark icon and the label "status: succeeded, output URL".
Title at top: "Replicate Prediction Lifecycle". Generous negative space.' \
  -a 9:16 -r 2K
```

**Tip (grounding):** the model's knowledge cutoff is January 2025, so by default it can't reach current facts. For factual diagrams (frameworks, APIs, architectures, current data), either supply the facts/labels/numbers in the prompt yourself, or pass `--grounding`/`-g` to enable Google Search grounding so the model can pull real-time web data. Grounding adds latency and cost, so prefer in-prompt facts when you already have them.
