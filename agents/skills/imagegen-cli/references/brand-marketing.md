# Brand & marketing — prompt templates

Concrete templates and worked examples. All follow the universal formula from SKILL.md (Subject, Action, Location, Composition, Lighting, Style, Text), paired with recommended CLI flags.

Table of contents:

- [Logos & wordmarks](#logos--wordmarks)
- [Brand identity sheets (multi-image)](#brand-identity-sheets-multi-image)
- [Web heroes & landing banners](#web-heroes--landing-banners)
- [Movie / album / book covers & posters](#movie--album--book-covers--posters)
- [YouTube thumbnails](#youtube-thumbnails)

---

## Logos & wordmarks

**Why this matters:** Pro renders text reliably. Always quote the literal name. Specify industry — a tech logo and a bakery logo follow different conventions.

**Template:**
```
Design a [style] logo for "[BRAND NAME]", a [industry/description].
[Visual concept: mark/symbol/composition]. [Typography style: font + weight].
[Color palette]. [Background].
```

**Logo style menu:** `minimalist`, `vintage`, `tech / geometric`, `mascot`, `luxury / serif`, `lettermark`, `3D rendered`, `abstract`, `badge / emblem`, `hand-drawn`.

**Example — minimalist tech wordmark:**
```bash
imagegen 'Design a modern, minimalist wordmark logo for "Helix", a developer tools startup. Clean geometric sans-serif lettering with a subtle helix-spiral integrated into the "x". Pure black on a white background. Centered composition with generous negative space.' \
  -a 1:1 -r 2K -b
```

**Example — vintage emblem:**
```bash
imagegen 'A vintage emblem logo for "Northwood Coffee Roasters", a specialty coffee roaster. Circular badge composition with serif uppercase wordmark on a banner across the center, a stylized pine tree silhouette above, and "EST. 2018" below. Warm cream and dark forest green palette. Slightly distressed, hand-drawn feel. White background.' \
  -a 1:1 -r 2K
```

**Example — mascot:**
```bash
imagegen 'A friendly cartoon mascot logo for "Pixel Pals", a kids coding app. A round, smiling robot character holding a glowing green bracket icon, soft pastel colors (mint, peach, lavender), bold rounded sans-serif "Pixel Pals" wordmark below. Clean vector style. White background.' \
  -a 1:1 -r 2K
```

**Example — variations from one prompt:**
```bash
imagegen 'Design 6 distinct minimalist wordmark logos for "Lumen", a lighting design studio, using clean geometric letterforms. Each variation explores a different way to integrate a subtle light/glow motif into the typography. Black on white, arranged in a 2x3 grid with thin labels.' \
  -a 4:3 -r 2K
```

**Tips:**
- Always include a `background` instruction (logos usually want white or transparent → use `-b`).
- For multi-variation requests, ask for an explicit grid layout — Pro will arrange them.
- If text comes out wrong, retry with the brand name in `ALL CAPS` quoted; that often improves accuracy.

---

## Brand identity sheets (multi-image)

**Why this matters:** Pro can lay out a full identity board in a single shot — logo, color palette, typography, mockup. Use `9:16` or `1:1` and high resolution.

**Example:**
```bash
imagegen 'A brand identity sheet for "Aurora Botanicals", an organic skincare brand. Layout in a 9:16 vertical board: at the top, the primary wordmark "Aurora" in an elegant thin serif. Below it, a 5-swatch color palette (sage green, warm cream, dusty rose, deep forest, soft white) with hex labels. Middle section: typography pairing showing "Aurora" in serif and a body line "Pure botanicals from northern fields" in a clean sans-serif. Bottom: a product mockup of a frosted glass dropper bottle with the wordmark on the label. Soft natural lighting throughout. Editorial magazine layout, lots of negative space.' \
  -a 9:16 -r 4K
```

**For brand consistency across multiple separate assets**, batch-mode it (see [batch.md](batch.md)) and pass the same logo as `-i` to each entry.

---

## Web heroes & landing banners

**Why this matters:** Heroes need composition for text overlay. Ask for negative space on one side.

**Template:**
```
A [aspect: wide/cinematic] hero banner showing [scene] with significant negative space on the [left/right] for text overlay.
[Mood/atmosphere]. [Lighting]. [Style].
[Optional: text to render in the hero].
```

**Example — SaaS hero:**
```bash
imagegen 'A wide cinematic hero banner showing a sleek modern home office at dusk: a single illuminated monitor on a minimalist oak desk, soft warm lamplight, large window with city lights bokeh in the background. Significant negative space on the left third for text overlay. Calm, focused, premium mood. Cinematic color grading with deep blues and warm amber accents.' \
  -a 21:9 -r 4K
```

**Example — hero with embedded text:**
```bash
imagegen 'A wide hero banner for an outdoor brand. A lone hiker silhouetted against a vast snowy mountain ridge at sunrise, low-angle composition, hiker positioned in the right third. The text "GO FURTHER" rendered in a bold uppercase sans-serif font in white, positioned in the upper-left negative space, large but tasteful. Cool blues and warm orange sunrise.' \
  -a 16:9 -r 4K
```

**Example — abstract hero:**
```bash
imagegen 'A wide abstract hero banner: smooth flowing 3D liquid forms in a warm gradient (peach to dusty pink to cream), soft volumetric lighting, glossy ceramic-like material. Serene, premium feel. Significant negative space on the right for text. Octane render quality.' \
  -a 21:9 -r 2K
```

---

## Movie / album / book covers & posters

**Why this matters:** Pro lays out cover hierarchy (title, subtitle, artist/author) cleanly and renders text reliably. Genre conventions are doing real work — name them.

**Template:**
```
[Cover type] for "[TITLE]" by [Artist/Author/Studio], a [genre/category].
Hero imagery: [scene or subject + style].
Title typography: [font style + size + position].
[Tagline / cover lines, in quotes].
[Mood / publication style reference].
```

**Genre conventions:**
- **Horror movie poster:** dark palette, single ominous element, title in distressed serif, thin tagline at top
- **Indie film poster:** flat color or photographic, sans-serif title bottom third, festival laurels
- **Thriller poster:** silhouette / partial face, harsh contrast, title in bold uppercase
- **Indie rock album:** moody photograph, handwritten or vintage serif title, aged film grain
- **Pop album:** saturated color, sharp typography, geometric composition
- **Synthwave album:** neon gradient, retro-future grid, chrome typography
- **Literary novel:** minimalist illustration, classical serif, plenty of negative space
- **Thriller novel:** photographic hero, bold sans-serif title, blood-red accents

**Example — minimalist thriller poster:**
```bash
imagegen 'Minimalist thriller movie poster for "THE SILENT ECHO". The visual is an aerial shot of a single isolated cabin in a vast snowy forest, photographed at twilight. The title "THE SILENT ECHO" in a large distressed sans-serif font in white, positioned at the top, taking up the full width. Tagline "Some sounds carry forever" in a thin serif below. Director credit "A film by Mira Halle" small at the bottom. High contrast black and white, fine grain. Festival laurels in the lower left.' \
  -a 2:3 -r 4K
```

**Example — indie rock album cover:**
```bash
imagegen 'Indie rock album cover for "Northern Lights" by The Glasshouse. Hero image: a foggy pine forest at dawn with a single human silhouette walking away from camera. Title "Northern Lights" in a handwritten cursive script across the upper-third in white. Band name "The Glasshouse" in a small uppercase sans-serif at the bottom-right. Vintage Kodak Tri-X film grain, slight light leak. Square 1:1 framing.' \
  -a 1:1 -r 4K
```

**Example — synthwave album:**
```bash
imagegen 'Synthwave album cover for "Neon Drive" by Voltaire. A retro-future grid horizon stretching to vanishing point with a low pink and purple sun, palm tree silhouettes flanking the sides, a chrome 80s sports car driving toward the viewer. Title "NEON DRIVE" in chrome 3D extruded uppercase typography centered above the horizon. Artist "Voltaire" in a thin sans-serif below. Saturated hot pink, electric purple, and cyan palette.' \
  -a 1:1 -r 4K
```

**Example — book cover (literary):**
```bash
imagegen 'Literary novel cover for "The Last Garden" by Elena Mori. Minimalist composition: a single botanical illustration of a wilting tulip in muted sage and dusty pink watercolor, centered on a cream textured paper background. Title "The Last Garden" in a classical serif (Garamond style) below the tulip, author "Elena Mori" smaller below. Generous negative space. Penguin Modern Classics aesthetic.' \
  -a 2:3 -r 2K
```

---

## YouTube thumbnails

**Why this matters:** Thumbnails live or die by 3 things: face/object clarity, text legibility at small size, and contrast that survives the cluttered feed. Most "AI thumbnail" output fails because it's beautiful but unreadable at 320×180.

**SLCT framework** (Subject + Lighting + Camera + Text/details):

```
Subject: [primary subject in expressive pose / state, central position].
Lighting: [high-contrast lighting that separates subject from background].
Camera: [close-to-medium shot, subject occupying 40-60% of frame].
Text: ["1-3 word HOOK"] in [font weight, color], [position].
[Background: bold color block / blurred scene, supports subject contrast].
```

**Rules:**
- **Cap text at 1–3 words.** "INSANE GAINS", "I QUIT", "BEFORE / AFTER". Long titles become unreadable.
- **One subject hero.** Face + reaction OR product + outcome. Not both fighting for attention.
- **Central crop safety.** YouTube crops to square on some surfaces — keep critical content within the center 60%.
- **Contrast pairs:** yellow on dark navy, white on red, black on lime. Avoid mid-tone combinations.
- **Expression sells.** "Wide-eyed shocked", "deadpan annoyed", "smug grin pointing at thing". Generic smiles get scrolled past.

**Example — tech tutorial:**
```bash
imagegen 'YouTube thumbnail. Subject: a tech YouTuber with short dark hair, wide-eyed shocked expression, leaning toward the camera, hand gesturing to the right. Bright high-contrast lighting from the left, deep shadow on the right. Medium close-up shot, subject occupying 45% of the left side. To the right, a glowing laptop showing colorful code on screen with a red "CRASHED" warning. Bold yellow text "I BROKE IT" in a heavy sans-serif font, positioned in the upper-right, with a thin red outline. Solid dark navy background.' \
  -a 16:9 -r 2K
```

**Example — fitness before/after:**
```bash
imagegen 'YouTube thumbnail. Split-screen composition with a bold red diagonal slash divider. Left side: a man in a baggy t-shirt looking down, dim flat lighting, desaturated. Right side: same man flexing in good shape, bright high-contrast gym lighting, sharp focus. Bold white sans-serif text "30 DAYS" overlaid centered on the diagonal divider with a thin black outline. Realistic photographic style, high saturation on the right side.' \
  -a 16:9 -r 2K
```

**Example — explainer / documentary:**
```bash
imagegen 'YouTube thumbnail for a finance explainer. Subject: a 100-dollar bill being torn in half centered in the frame, dramatic lighting with hard shadow underneath. Bold uppercase text "WHY?" in massive yellow sans-serif font filling the right third of the frame. Solid black background with subtle red glow behind the bill. High-contrast, eye-catching, designed to read at small size.' \
  -a 16:9 -r 2K
```
