# Illustration & art styles — prompt templates

Concrete templates and worked examples. All follow the universal formula from SKILL.md (Subject, Action, Location, Composition, Lighting, Style, Text), paired with recommended CLI flags.

Table of contents:

- [Illustrations, stickers & icon sets](#illustrations-stickers--icon-sets)
- [Children's book illustration](#childrens-book-illustration)
- [Painting media — watercolor, oil, ink, charcoal](#painting-media--watercolor-oil-ink-charcoal)
- [3D render styles — isometric, octane, claymation, low-poly](#3d-render-styles--isometric-octane-claymation-low-poly)
- [Pixel art](#pixel-art)
- [Comics, manga & storyboards](#comics-manga--storyboards)
- [Concept art & character turnaround sheets](#concept-art--character-turnaround-sheets)
- [Tattoo flash & stencil designs](#tattoo-flash--stencil-designs)
- [Seamless patterns & textile prints](#seamless-patterns--textile-prints)

---

## Illustrations, stickers & icon sets

**Why this matters:** Style consistency across icon sets is what makes them production-ready. Specify the exact style language.

**Example — kawaii sticker:**
```bash
imagegen "A kawaii-style sticker of a happy red panda wearing a tiny bamboo hat, munching on a bamboo leaf. Bold black outlines, cel-shaded coloring, vibrant warm colors. White background." \
  -a 1:1 -r 2K -b
```

**Example — icon set:**
```bash
imagegen 'A set of 9 minimalist line icons arranged in a 3x3 grid on a white background. Subjects: home, search, profile, settings, calendar, message, notification, heart, share. Style: 2px stroke weight, rounded line caps, 24x24 grid each, monochrome charcoal grey. Consistent visual weight and corner radius across all icons. Clean labeling below each icon in a small uppercase sans-serif.' \
  -a 1:1 -r 2K
```

**Example — flat illustration:**
```bash
imagegen 'A flat vector illustration of a person at a wooden desk with a laptop, plants, and a steaming mug of coffee. Style: friendly modern flat illustration, rounded corners, clean lines, no decorative fonts. Color palette: soft sage, warm peach, cream, charcoal accents. Suitable for an empty-state in a productivity app. White background.' \
  -a 4:3 -r 2K
```

---

## Children's book illustration

**Why this matters:** Children's books need (1) a visual style that reads instantly to ages 3–8, (2) a character who looks the *same* across 20+ pages. Pro handles both if you anchor with a reference and repeat traits.

**Style language:** `friendly storybook illustration`, `soft watercolor with pencil outlines`, `flat vector with rounded shapes`, `Eric Carle collage style`, `Quentin Blake loose pen and ink`, `Beatrix Potter delicate watercolor`, `Pixar-influenced 3D storybook`.

**Workflow:**
1. Generate a clean front-facing **character anchor** (full body, neutral pose, plain background).
2. Reuse that image as `-i` for every scene; **repeat the trait list verbatim** in every prompt.
3. Lock style language across prompts (don't switch from "watercolor" to "flat vector" mid-book).

**Example — character anchor:**
```bash
imagegen "Friendly storybook character illustration: a young girl named Pip with curly black hair tied in two pom-poms, freckles across her nose, big brown eyes, wearing a yellow raincoat, blue rubber boots, and holding a small red umbrella. Full body, front-facing, neutral happy expression. Soft watercolor and pencil outline style with warm pastel colors. Plain off-white background." \
  -a 1:1 -r 2K -o pip_anchor.png
```

**Example — scene reusing the anchor:**
```bash
imagegen "Storybook illustration in soft watercolor and pencil outline style. Pip — a young girl with curly black hair in two pom-poms, freckles, big brown eyes, yellow raincoat, blue rubber boots, holding a small red umbrella — is splashing in a puddle on a cobblestone village street. A friendly orange tabby cat watches from a doorway. Soft drizzle, warm pastel palette, gentle morning light. Match Pip's appearance exactly to the provided reference." \
  -i pip_anchor.png -a 4:3 -r 2K
```

**Tips:**
- Always re-state the full trait list — the reference alone drifts after a few generations.
- Use a 4:3 or 3:2 aspect for spreads, 1:1 for cover.
- For multi-page books, batch-generate (see `batch.md`) with the anchor image referenced in every entry.

---

## Painting media — watercolor, oil, ink, charcoal

**Why this matters:** AI defaults to clean digital. Painting media demand the *opposite* — physical artifacts (bleeds, granulation, brushstroke texture, paper grain). Without explicit physical descriptors, you get "watercolor-flavored digital art".

**Universal template:**
```
[Subject], rendered in [medium] on [substrate].
[Physical artifacts: bleeds / granulation / impasto / dry brush / drips].
[Pigment names]. [Mood / lighting].
[Optional: visible underdrawing / pencil outlines / paper grain showing through].
```

**Medium-specific vocabulary:**

| Medium | Physical descriptors | Pigments / palette |
|---|---|---|
| **Watercolor** | `wet-on-wet bleeds`, `granulation`, `paper grain visible`, `light pencil underdrawing showing through`, `soft edges fading into white paper`, `cauliflower bloom artifacts` | `cobalt blue`, `burnt sienna`, `viridian`, `cadmium red`, `payne's grey` |
| **Oil paint** | `thick impasto with palette knife marks`, `visible canvas weave`, `wet-into-wet blending`, `glazing layers`, `varnish sheen` | `titanium white`, `ivory black`, `cadmium yellow`, `ultramarine`, `alizarin crimson` |
| **Ink wash** | `controlled water dilutions from black to grey`, `bamboo brush strokes`, `dry-brush textures`, `rice paper grain`, `confident single-stroke gesture` | `sumi black ink`, `single-color tonal range` |
| **Charcoal** | `smudged graphite tones`, `eraser highlights`, `paper tooth visible`, `crisp dark blacks against grey midtones`, `loose hatching` | `monochrome black to white` |

**Example — watercolor portrait:**
```bash
imagegen "A loose watercolor portrait of an old fisherman with a weathered face and a pipe, painted on textured cold-press paper. Wet-on-wet bleeds in the background, granulation in the shadows of his coat, light pencil underdrawing visible through the wash. Pigments: burnt sienna, payne's grey, cobalt blue. Soft edges fading into white paper at the borders. Imperfect, gestural, expressive — not clean digital." \
  -a 4:5 -r 2K
```

**Example — oil paint impasto:**
```bash
imagegen "An oil painting of a stormy seascape in the style of late J.M.W. Turner. Thick impasto applied with a palette knife, visible canvas weave underneath, dramatic chiaroscuro between dark stormclouds and a sliver of golden light breaking through. Pigments: titanium white, ivory black, cadmium yellow, ultramarine. Layered glazes adding atmospheric depth." \
  -a 16:9 -r 4K
```

**Example — sumi-e ink wash:**
```bash
imagegen "A traditional sumi-e ink wash painting of a single bamboo stalk with three leaves, on cream rice paper. Confident single-stroke gestures, dry-brush texture on the leaves, controlled tonal range from deep black to pale grey wash. Generous negative space, a small red signature seal in the lower right. Minimalist, meditative." \
  -a 2:3 -r 2K
```

**Anti-pattern:** asking for "watercolor" without physical descriptors → you'll get clean Adobe Illustrator-style flat art with watercolor-tinted edges. Always describe what makes it *physical*.

---

## 3D render styles — isometric, octane, claymation, low-poly

**Why this matters:** "3D render" alone is meaningless. Each sub-style has distinct geometry rules, lighting conventions, and material languages. Naming the engine/aesthetic does most of the work.

**Common sub-styles:**

| Style | Defining traits |
|---|---|
| **Octane / photorealistic 3D** | Physically-accurate materials, soft global illumination, depth of field, subsurface scattering |
| **Isometric** | Top-down 30-degree angle, no perspective distortion, cube-grid alignment |
| **Claymation / Pixar-style** | Soft rounded forms, slight surface imperfections, subsurface scattering on skin, warm lighting |
| **Low-poly** | Visible triangular facets, flat colors per face, no smooth shading, limited palette |
| **Voxel** | Cube-based blocks (Minecraft / Crossy Road look), pixelated 3D |
| **Wireframe / blueprint** | Visible polygon edges, technical aesthetic, often on dark grid background |

**Templates:**

**Octane / photoreal:**
```bash
imagegen "Octane render of a single matte ceramic vase on a polished marble pedestal, soft global illumination from a large softbox above, subtle reflections in the marble, shallow depth of field. Hyperreal materials, 4K detail, neutral color grading." \
  -a 4:5 -r 4K
```

**Isometric scene:**
```bash
imagegen "Isometric 3D illustration of a tiny cozy coffee shop interior, top-down 30-degree angle, no perspective distortion. Visible: a wooden bar with espresso machine, two small tables with chairs, a hanging plant, warm pendant lights. Soft pastel palette (cream, terracotta, sage, dusty pink), soft ambient lighting with crisp shadows. Stylized 3D, smooth surfaces, miniature diorama feel." \
  -a 1:1 -r 2K
```

**Claymation:**
```bash
imagegen "Claymation-style 3D render of a smiling fox character, soft rounded forms with slight thumbprint imperfections in the clay, warm orange and white fur sculpted in plasticine, glossy black eyes. Studio lighting with soft warm key light, shallow depth of field. Aardman Studios aesthetic." \
  -a 4:5 -r 2K
```

**Low-poly:**
```bash
imagegen "Low-poly 3D render of a snowy mountain landscape with a small log cabin, visible triangular polygon facets across all surfaces, flat color fills per face with no smooth shading. Limited palette: cool whites, dusty blues, warm cabin glow. Simple sun lighting from upper-right with sharp polygon shadows. Stylized geometric, clean and minimal." \
  -a 16:9 -r 2K
```

**Voxel:**
```bash
imagegen "Voxel-art 3D scene of a small wizard's tower on a floating island, blocky cube-based geometry like Minecraft. Pastel daytime palette, soft ambient lighting. Cute, miniature, isometric 30-degree angle." \
  -a 1:1 -r 2K
```

---

## Pixel art

**Why this matters:** Pixel art has hard rules — bit depth dictates palette size and detail level; mixing styles produces unconvincing "AI pixel-tinted blur". Specify the bit era and a palette reference.

**Bit-depth conventions:**
- **8-bit (NES era):** 4-color palette per sprite, ~16×16 to 32×32 sprite resolution, iconic minimal detail
- **16-bit (SNES/Genesis era):** 16-color palette, ~32×32 to 64×64 sprites, more shading and detail
- **32-bit (PSX/Saturn era):** richer palettes, parallax-friendly, slight pre-rendered look
- **Modern indie pixel art:** unrestricted palette, dithering, sub-pixel anti-aliasing — Celeste / Stardew Valley / Hyper Light Drifter look

**Palette references:** `NES color palette`, `Game Boy 4-shade green palette`, `PICO-8 16-color palette`, `Commodore 64 palette`, `pastel modern indie palette`.

**Template:**
```
[Bit depth, e.g. "16-bit pixel art"] sprite of [subject in clear pose], [palette reference].
[Pose / facing direction]. [Background: solid color or transparent / black].
[Optional: dithering, anti-aliased, sub-pixel detail].
```

**Rules:**
- **Generate one angle at a time** — don't ask for "front + side + back in one image".
- **Solid background** (`black background` or `dark background`) makes sprites cleaner to extract.
- **One sprite per generation** — don't ask for a sprite sheet of 8 frames; do them as individual prompts.
- **Don't mix eras** — "8-bit with modern dithering" produces neither.

**Example — 8-bit NES:**
```bash
imagegen "8-bit NES-style pixel art sprite of a knight in red armor holding a sword, facing right in an action pose, 32x32 resolution feel, NES 4-color palette per sprite (red, dark red, beige, black). Solid black background." \
  -a 1:1 -r 1K
```

**Example — 16-bit SNES:**
```bash
imagegen "16-bit SNES-style pixel art sprite of a wizard with a long blue robe, pointed hat, and a glowing staff, facing the camera. Detailed shading, 16-color palette, slight outline. Solid dark background." \
  -a 1:1 -r 1K
```

**Example — modern indie scene:**
```bash
imagegen "Modern indie pixel art landscape of a forest clearing at dusk, parallax-style depth with foreground bushes, midground glowing fireflies, distant pine silhouettes against a pink-purple gradient sky. Subtle dithering, sub-pixel anti-aliasing. Hyper Light Drifter / Eastward palette aesthetic." \
  -a 16:9 -r 2K
```

---

## Comics, manga & storyboards

**Why this matters:** Pro can lay out a full comic page in one shot — but the prompt has to dictate **page-level** instead of asking for one panel. For consistency across pages, lock down character refs first.

**Two modes:**

1. **Full-page generation** — let Pro arrange panels itself based on the script.
2. **Single-panel generation** — generate each panel individually, then assemble in a layout tool (cleaner for production work).

### Mode 1 — full-page comic

**Template:**
```
[Western comic / manga / webtoon] page layout with [N panels] arranged [horizontal grid / vertical scroll / dynamic varying sizes].
Style: [black-and-white ink / colored / watercolor].
Panel 1: [scene + character action + dialogue/SFX].
Panel 2: [...]
...
[Style anchors: G-pen linework / screen tone / hatching / cel-shaded color].
```

**Aspect ratios:**
- **Manga page:** `2:3` (matches printed manga proportions)
- **Western comic page:** `2:3` or `3:4`
- **Webtoon vertical scroll:** `9:16` or `1:4`
- **Single cinematic panel:** `16:9` or `21:9`

**Example — manga page:**
```bash
imagegen 'A manga page layout in classic black-and-white ink style with G-pen linework, screen tone shading, and dynamic hatching. Six panels arranged with varying sizes for dramatic pacing.
Panel 1 (top, wide): a young girl in a school uniform standing on a windswept rooftop at sunset, hair blowing, looking off-frame.
Panel 2 (small, top-right): close-up of her eyes, determined expression.
Panel 3 (middle-left): she clenches her fist, with dramatic motion lines.
Panel 4 (middle-right): the city skyline far below, vertigo perspective looking down.
Panel 5 (bottom-left): she leaps off the edge, mid-air pose.
Panel 6 (bottom, wide, full bleed): explosive impact frame with "DON" SFX text in stylized katakana.
Authentic shounen manga aesthetic, varied screen tones, confident inking.' \
  -a 2:3 -r 4K
```

**Example — webtoon vertical:**
```bash
imagegen 'Webtoon-style vertical scroll comic page in clean digital color. Three sequential scenes stacked vertically:
Top: a girl with pink hair sitting alone in a school cafeteria, sad expression.
Middle: a boy approaches with a lunch tray, asking "is this seat taken?".
Bottom: she looks up with surprise, soft blush. Speech bubble "...no, go ahead".
Soft pastel digital coloring, clean linework, gentle gradients. Manhwa/webtoon aesthetic.' \
  -a 9:16 -r 2K
```

### Mode 2 — single-panel storyboard frames

For animation/film storyboarding, generate each frame individually with consistent character refs:

```bash
imagegen "Storyboard frame in rough graphite-pencil style with light blue underdrawing showing through. A detective in a trench coat enters a dimly-lit warehouse, low-angle shot, hard rim light from the doorway behind him. Frame 4 of 12. Black-and-white pencil sketch aesthetic, gestural and loose, not finished art." \
  -a 16:9 -r 2K
```

**Tips:**
- For multi-page consistency, generate the protagonist as a character anchor first (see Concept Art section), then `-i` it into every page prompt.
- Manga keywords that work: `G-pen linework`, `screen tone`, `cross-hatching`, `Mob Psycho aesthetic`, `Naoki Urasawa style`, `shounen / shoujo / seinen`.
- Western comic keywords: `inked panel`, `4-color process`, `Frank Miller chiaroscuro`, `Mike Mignola heavy black shadows`, `Moebius clean line`.

---

## Concept art & character turnaround sheets

**Why this matters:** Game/animation studios need a *model sheet* — a single image showing a character from front, side, back (and often 3/4 views) with consistent proportions and lighting. Pro produces clean turnarounds when prompted with explicit camera and lighting locks.

**Three-section template:**
```
Style: [3D render / cel-shaded anime / painted concept / pencil sketch].
Character: [detailed description — silhouette, build, hair, face, costume, props, color story].
Technical: character design sheet with [N views: front / 3/4 / side / back], orthographic camera, consistent lighting across all views, neutral T-pose or A-pose, plain [white / grey] background, character names labeled below each view.
```

**Example — game character turnaround:**
```bash
imagegen 'Stylized 3D character design sheet, four orthographic views (front, 3/4, side, back) of "Vex", a futuristic exosuit pilot. Build: athletic, mid-twenties, short cropped dark hair with an undercut, scar across left brow. Costume: matte black exosuit with glowing cyan accent lines along the seams, articulated plate armor on shoulders and forearms, utility belt with three pouches, magnetic boots. Neutral A-pose for all views. Orthographic camera (no perspective distortion), consistent flat lighting from front-left across all four views, plain light grey background. Each view labeled below: "FRONT", "3/4", "SIDE", "BACK". Cel-shaded with clean linework, color-flat fills with soft AO shadows. Production-quality character design sheet.' \
  -a 16:9 -r 4K
```

**Example — environment concept:**
```bash
imagegen 'Painted environment concept art for a fantasy game: an ancient elven library carved into the trunk of a colossal living tree, multi-level wooden walkways spiraling around the interior, glowing magical books floating between shelves, shafts of golden light filtering through canopy windows. Painted illustration aesthetic, brush-textured, atmospheric depth, warm green-gold palette. Production concept art quality, ArtStation-tier composition.' \
  -a 16:9 -r 4K
```

**Example — prop sheet:**
```bash
imagegen 'A prop design sheet showing 6 variations of a fantasy sword, arranged in a 2x3 grid on a parchment-colored background. Each sword has a unique blade shape, hilt design, and pommel: 1) classic longsword with cross-guard, 2) curved scimitar with jeweled hilt, 3) two-handed greatsword with leather-wrapped grip, 4) elven blade with intricate filigree, 5) blackened orcish blade with serrated edge, 6) ornamental ceremonial sword with gold inlay. Each labeled below in a small uppercase serif. Concept art ink-and-wash style with subtle color accents.' \
  -a 4:3 -r 2K
```

**Tips:**
- **Orthographic camera** is the critical instruction — without it, perspective distorts proportions across views.
- **A-pose or T-pose** keeps limbs visible. Don't ask for action poses on a turnaround.
- For animation refs, prompt: `expression sheet showing the same character with 6 expressions: neutral, happy, sad, angry, surprised, smirk`.

---

## Tattoo flash & stencil designs

**Why this matters:** Tattoo flash has style-specific rules (line weight, shading conventions, palette restrictions per style). A "tattoo design" prompt without these produces unusable digital art.

**Style menu and rules:**

| Style | Line weight | Shading | Color |
|---|---|---|---|
| **American traditional** | bold 3-5mm outlines | solid color fills, minimal shading | red, green, yellow, black, limited palette |
| **Neo-traditional** | medium 2-4mm | soft gradient shading | full color, rich saturated tones |
| **Japanese (irezumi)** | bold 3-5mm | flowing wave/cloud backgrounds, layered | red, black, indigo, with traditional motifs |
| **Blackwork** | varied 1-5mm | solid black fills, no shading or color | black only |
| **Fine-line / single-needle** | 0.5-1mm | minimal stipple shading | black or single muted color |
| **Realism** | varied | photorealistic gradient shading, no outlines | full color or black-and-grey |
| **Geometric / ornamental** | precise 1-2mm | dot-work, line patterns | usually black-only |

**Template (flash design):**
```
[Style] tattoo flash design of [subject].
[Line weight specification]. [Shading approach].
[Color palette or "black ink only"].
Solid white background, designed as printable flash.
```

**Template (stencil-ready output):**
```
[Subject] tattoo design as a clean stencil: black linework only, no shading, no fills, no color.
High contrast, white background, lines confident and continuous (no sketchy multi-strokes), [line weight].
Print-ready stencil format.
```

**Example — American traditional flash:**
```bash
imagegen "American traditional tattoo flash design of a roaring tiger head with a snake wrapped around its neck. Bold 4mm black outlines, solid color fills with minimal shading, classic limited palette of red, green, yellow, and black. Centered composition on a white background, designed as printable flash sheet." \
  -a 4:5 -r 2K -b
```

**Example — fine-line minimal:**
```bash
imagegen "Fine-line single-needle tattoo design of a small botanical sprig of rosemary. 0.5mm black linework, delicate stipple shading, no fills. White background, centered composition with generous negative space, designed for an inner forearm placement." \
  -a 1:1 -r 2K -b
```

**Example — stencil-ready output:**
```bash
imagegen "A coiled dragon tattoo design as a clean stencil: black linework only, no shading, no fills, no color. High contrast against pure white background. Lines confident and continuous, 2mm line weight throughout. Detailed scales and flowing whiskers. Print-ready stencil format." \
  -a 4:5 -r 2K -b
```

---

## Seamless patterns & textile prints

**Why this matters:** Generic "pattern" prompts produce single illustrations that don't tile. The magic words are `seamless repeating pattern tile`, `tileable`, `clean edges`. For textile/wallpaper, scale of motifs matters too.

**Template:**
```
A seamless repeating pattern tile of [motif description].
Tileable with clean edges that match on all four sides.
[Motif scale: small / medium-to-large / dense / airy].
[Color palette, fixed].
[Style: line-art botanical / Art Deco geometric / mid-century modern / William Morris / minimalist].
```

**Application notes:**
- **Wallpaper:** medium-to-large motifs, calmer contrast, readable from across a room
- **Textile / fabric:** smaller dense motifs, suitable for cutting and seams
- **Wrapping paper / packaging:** medium motifs, high contrast OK
- **Surface design / phone case:** dense, high-contrast, instant visual impact

**Example — botanical wallpaper:**
```bash
imagegen "A seamless repeating pattern tile of delicate line-art botanical illustrations: ferns, eucalyptus sprigs, and small wildflowers, arranged with airy spacing. Tileable with clean edges that match on all four sides. Medium-to-large motif scale suitable for wallpaper. Limited palette: charcoal black line work on a soft cream background, no fill colors. William Morris-meets-modern minimalism aesthetic." \
  -a 1:1 -r 4K
```

**Example — Art Deco textile:**
```bash
imagegen "A seamless tileable pattern of Art Deco geometric motifs: fans, sunburst rays, stepped chevrons, and stylized peacock feathers in a strict vertical-symmetric arrangement. Clean edges matching on all four sides. Dense motif scale suitable for textile printing. Palette: deep emerald green, gold, ivory, and black. Authentic 1920s Art Deco aesthetic." \
  -a 1:1 -r 4K
```

**Example — mid-century kitchen pattern:**
```bash
imagegen "A seamless repeating pattern tile of mid-century modern kitchen icons: stylized teacups, lemons, leaves, and abstract starbursts. Tileable with clean edges. Small-to-medium dense motif scale. Mustard yellow, sage green, off-white, and warm brown palette. Charley Harper / Vera Neumann aesthetic." \
  -a 1:1 -r 2K
```

**Tip:** verify tileability by visually checking whether the corners/edges match. If they don't, add: `the pattern at the left edge must mirror the right edge exactly, and top must mirror bottom`.
