# Photography & realism — prompt templates

Concrete templates and worked examples. All follow the universal formula from SKILL.md (Subject, Action, Location, Composition, Lighting, Style, Text), paired with recommended CLI flags.

Table of contents:

- [Photorealistic / portraits](#photorealistic--portraits)
- [Product photography & mockups](#product-photography--mockups)
- [Food photography](#food-photography)
- [Architectural / interior visualization](#architectural--interior-visualization)
- [Fashion editorial & lookbook](#fashion-editorial--lookbook)

---

## Photorealistic / portraits

**Why this matters:** Photorealism breaks fastest from generic prompts. The fix is photographic vocabulary — lens, aperture, lighting setup, film stock.

**Template:**
```
A [shot type] of [subject with specific traits] [action] in [location].
[Lens + aperture]. [Lighting setup]. [Film stock or color grade].
[Mood].
```

**Example — close-up portrait:**
```bash
imagegen "A close-up portrait of an elderly Japanese ceramicist with sun-etched wrinkles and a warm smile inspecting a glazed tea bowl in his rustic workshop. 85mm portrait lens, shallow depth of field at f/1.8. Soft golden hour light through windows, gentle rim light on his shoulder. Shot on Kodak Portra 400, slight grain. Serene, masterful mood." \
  -a 4:5 -r 2K -m gemini-3-pro-image
```

**Example — environmental wide shot:**
```bash
imagegen "A wide shot of a lone hiker in a red shell jacket pausing on a granite outcrop overlooking a glacial valley at dawn. 24mm wide-angle lens. Cool blue ambient light with a single warm shaft of sunrise hitting the far peak. Cinematic color grading with muted teal shadows and orange highlights." \
  -a 21:9 -r 4K
```

**Vocabulary cheat sheet:**
- **Lens:** `85mm portrait`, `50mm`, `35mm`, `24mm wide-angle`, `100mm macro`, `200mm telephoto`
- **Aperture:** `shallow depth of field, f/1.8`, `deep focus, f/16`
- **Lighting:** `three-point softbox`, `chiaroscuro with harsh contrast`, `golden hour backlighting`, `overcast diffused light`, `single key light, deep shadows`, `rim light`, `volumetric lighting`
- **Film/grade:** `Kodak Portra 400`, `1980s color film with grain`, `cinematic teal and orange`, `desaturated documentary look`
- **Mood:** `serene, masterful`, `melancholy`, `vibrant, energetic`, `mysterious`

---

## Product photography & mockups

**Why this matters:** E-commerce shots need controlled lighting, clean surfaces, and sharp focus. Studio vocabulary > "professional photo".

**Template:**
```
[Shot type] of [product with materials and finish] on [surface].
[Lighting setup, often 3-point softbox]. [Camera angle]. [Focus detail].
[Style: ultra-realistic / e-commerce / editorial].
```

**Example — e-commerce product shot:**
```bash
imagegen "Studio-lit product photograph of a minimalist matte black ceramic coffee mug with a slim ergonomic handle on a polished concrete surface. Three-point softbox setup creating soft, diffused highlights and a subtle shadow under the mug. 45-degree elevated angle. Sharp focus on the rim and steam rising from coffee. Ultra-realistic e-commerce style. White seamless background." \
  -a 1:1 -r 2K -b
```

**Example — lifestyle product shot:**
```bash
imagegen "Lifestyle photograph of a navy blue tweed sneaker resting on a wet city street at night, neon signage reflecting in the puddle. Cinematic lighting, shallow depth of field at f/2.0, 50mm lens. Realistic textures of wet leather and tweed. Moody urban atmosphere." \
  -a 3:2 -r 4K
```

**Example — flat-lay:**
```bash
imagegen "Top-down flat-lay of artisan coffee tools arranged on a warm oak surface: a copper kettle, a glass V60 dripper, a porcelain cup, a wooden spoon, and scattered coffee beans. Soft natural window light from the left. Editorial magazine style. Square frame." \
  -a 1:1 -r 2K
```

**Background removal workflow:**
- Always request a clean background first (`white seamless background`).
- Pass `-b` to get a transparent PNG (`outputs/{stem}.nobg.png`).
- The original is kept too — useful for context shots.

---

## Food photography

**Why this matters:** Food shots are 40% food details, 40% photography terms, 20% styling/mood. Generic "delicious meal" prompts produce ad-stock blandness; specific texture verbs and surface choices produce craveable results.

**Template:**
```
[Shot type] of [dish, plated and garnished] on [surface and props].
[Lighting]. [Camera angle]. [Texture verbs: glistening / steaming / crispy / caramelized].
[Style: editorial / commercial menu / lifestyle].
```

**Key vocabulary:**
- **Angles:** `overhead flat-lay`, `45-degree hero angle`, `eye-level`, `close-up macro`
- **Lighting:** `natural window light, soft directional`, `dramatic side light, deep shadows`, `moody backlight with steam visible`
- **Textures:** `glistening`, `steaming`, `crispy`, `creamy`, `melting`, `caramelized`, `tender`, `flaky`, `dewdrops on greens`
- **Surfaces:** `warm rustic oak`, `polished concrete`, `dark slate`, `marble with veining`, `linen napkin and burlap`
- **Props:** `vintage silver fork`, `crumbs scattered`, `wine glass blurred in background`, `cast iron pan`

**Example — hero shot:**
```bash
imagegen "45-degree hero angle of a sliced ribeye steak on a hot cast iron pan, glistening with melted butter and garlic, charred crust, pink medium-rare interior, scattered rosemary and flaky sea salt. Dark slate surface, dramatic side light from the left creating deep shadows. Steam rising. Editorial commercial photography, sharp focus on the cut surface, bokeh background. Shot on 50mm at f/2.8." \
  -a 4:5 -r 2K
```

**Example — overhead flat-lay:**
```bash
imagegen "Overhead flat-lay of a brunch spread on a warm oak table: a plate of fluffy pancakes drizzled with maple syrup and topped with fresh blueberries, a glass of orange juice, a small bowl of yogurt with granola, and a steaming ceramic mug of coffee. Soft natural window light from the upper left, gentle shadows. Linen napkin, scattered crumbs. Editorial brunch magazine style." \
  -a 1:1 -r 2K
```

**Example — moody close-up:**
```bash
imagegen "Extreme close-up macro of melted dark chocolate being poured over a glossy chocolate cake, viscous flow caught mid-pour, highlights on the chocolate surface. Black slate background, single warm key light from the right. Indulgent, luxurious mood. 100mm macro lens at f/4." \
  -a 1:1 -r 4K
```

---

## Architectural / interior visualization

**Why this matters:** Nano Banana Pro understands spatial vocabulary (axonometric, eye-level, twilight) and preserves geometry on edits. Use it to iterate on materials and lighting without re-running a SketchUp/Revit render.

**Template:**
```
[Spatial view: eye-level / axonometric / aerial / floor plan] of a [room or building type] with [materials and finishes].
[Lighting condition and time of day]. [Lens: 16-24mm wide for interiors, 35-50mm for accents].
[Style: photorealistic 3D render / architectural rendering / matte painting].
```

**Vocabulary cheat sheet:**
- **Views:** `eye-level interior`, `axonometric / isometric`, `aerial / bird's eye`, `street-level exterior`, `worm's-eye low angle`
- **Time of day:** `bright midday`, `golden hour`, `twilight blue hour`, `night with interior lighting`, `overcast diffused`
- **Lighting:** `large window with soft natural daylight`, `recessed downlights`, `pendant lighting`, `linear LED strips`, `ambient cove lighting`
- **Materials:** `warm oak flooring`, `polished concrete`, `travertine`, `terrazzo`, `walnut paneling`, `brushed brass fixtures`, `bouclé upholstery`, `microcement walls`
- **Style anchors:** `Modern minimalist`, `Japandi`, `Mid-century modern`, `Industrial loft`, `Brutalist`, `Mediterranean`, `Scandinavian`, `Art Deco`, `Bauhaus`

**Example — interior render:**
```bash
imagegen "Photorealistic 3D interior render of a Japandi-style living room: warm white oak flooring, off-white plaster walls, a low-profile bouclé sofa in cream, a black walnut coffee table with a single ceramic vase, large floor-to-ceiling window with sheer linen curtains. Late afternoon natural daylight with long soft shadows. Eye-level wide shot, 24mm lens, vertical lines kept perfectly straight. Architectural visualization quality." \
  -a 16:9 -r 4K
```

**Example — exterior twilight:**
```bash
imagegen "Architectural exterior of a modern minimalist house at twilight blue hour: clean cantilevered concrete and glass volumes, warm interior lighting glowing through floor-to-ceiling windows, stone landscaping with a reflecting pool in the foreground. Deep blue sky with the last orange band on the horizon. Eye-level street view, 35mm lens. Photorealistic architectural render." \
  -a 16:9 -r 4K
```

**Example — material/lighting iteration with a reference:**
```bash
imagegen "Using the provided image as the room's geometry and camera angle, change only the materials: replace the oak flooring with polished concrete, the sofa with a charcoal grey leather chesterfield, and the walls with exposed red brick. Keep all furniture positions, window light, and perspective identical. Industrial loft aesthetic." \
  -i current_render.png -a 16:9 -r 2K
```

**Tips:**
- For interiors, use 16-24mm lens vocabulary — narrower lenses look cramped.
- Always say "vertical lines kept perfectly straight" for serious arch viz; otherwise the model can warp pillars and corners.
- Twilight blue hour (`5-15 minutes after sunset`) is the most flattering time for exteriors with interior lighting visible.
- For multi-angle consistency, generate the floor plan first as a `-i` reference, then prompt each angle separately.

---

## Fashion editorial & lookbook

**Why this matters:** Fashion needs pose direction, garment vocabulary, and editorial conventions. Generic "model wearing dress" reads as stock catalog. Pose language ("contrapposto, hand on hip, looking over shoulder") is what separates editorial from amateur.

**Template:**
```
[Genre: editorial / lookbook / runway / campaign] photograph of [model description: build, hair, expression] wearing [garment with fabric, fit, color].
[Pose direction: stance + hand position + gaze]. [Setting]. [Lighting]. [Lens / film stock].
[Mood / publication reference].
```

**Pose vocabulary:**
- **Stances:** `contrapposto`, `wide stance, weight on one hip`, `crossed legs leaning against wall`, `mid-stride walking toward camera`, `kneeling`, `seated on stool, legs crossed`
- **Hands:** `hand on hip`, `arms crossed`, `hand running through hair`, `hands in pockets`, `one hand adjusting collar`
- **Gaze:** `direct eye contact with camera`, `looking over shoulder`, `gazing off into distance`, `eyes downcast`, `head tilted, profile`
- **Expression:** `neutral high-fashion blank`, `subtle smirk`, `confident smile`, `pensive`, `defiant`

**Garment specificity:** name the *fabric* (silk, raw denim, navy tweed, cashmere, vinyl, oversized cotton poplin, biker leather), the *fit* (oversized, tailored, draped, cropped, bias-cut), and any *details* (raw hem, open back, exposed zipper, structured shoulders).

**Example — high-fashion editorial:**
```bash
imagegen "Editorial fashion photograph of a tall woman with sharp cheekbones, dark slicked-back hair, and a neutral high-fashion expression wearing an oversized navy wool blazer with structured shoulders, raw-hem black silk trousers, and pointed black leather boots. Contrapposto stance, hands in trouser pockets, head tilted slightly, gazing past the camera. Concrete brutalist gallery setting, single hard key light from the left creating deep shadow. Shot on medium format film, slight grain. Vogue Italia aesthetic." \
  -a 2:3 -r 4K
```

**Example — lookbook minimal:**
```bash
imagegen "Lookbook photograph of a model with shoulder-length blonde hair and a soft natural smile wearing a cream cashmere sweater, high-waisted vintage Levi's 501s, and white leather sneakers. Walking mid-stride toward the camera, hands in pockets, relaxed gaze. Seamless paper backdrop in warm beige. Soft natural daylight, 50mm lens at f/2.8. Aritzia / COS aesthetic, clean and approachable." \
  -a 4:5 -r 2K
```

**Example — campaign with text:**
```bash
imagegen 'Campaign image for a luxury perfume brand "Lumière". Black-and-white close-up portrait of a model with closed eyes and parted lips, soft chiaroscuro lighting from a single softbox above. Holding a glass perfume bottle to her cheek. The text "LUMIÈRE — pour la nuit" rendered in a thin elegant serif at the bottom of the frame. Shot on Kodak Tri-X, deep blacks, fine grain.' \
  -a 4:5 -r 4K
```
