# Editing & continuity — prompt templates

Concrete templates and worked examples. All follow the universal formula from SKILL.md (Subject, Action, Location, Composition, Lighting, Style, Text), paired with recommended CLI flags.

Table of contents:

- [Image editing patterns](#image-editing-patterns)
- [Photo restoration & colorization](#photo-restoration--colorization)
- [Outfit / hairstyle / expression / age edits](#outfit--hairstyle--expression--age-edits)
- [Character consistency series](#character-consistency-series)

---

## Image editing patterns

Pass the source image as `-i`. Describe the change while explicitly preserving everything else.

| Pattern | Prompt shape |
|---|---|
| Add element | `Using the provided image, add [thing] [where]. Match the lighting and perspective of the photo.` |
| Remove element | `Remove [thing]. Keep everything else identical, including [shadows / reflections / lighting].` |
| Inpaint specific region | `Change only [the X] to [Y]. Keep [the rest of the scene, lighting, surrounding elements] unchanged.` |
| Replace background | `Replace the background with [new scene]. Keep the subject's pose, lighting, and edges intact.` |
| Style transfer | `Transform this photo into [style] style. Preserve the [composition / subjects], but render with [stylistic features].` |
| Color change | `Change the [object]'s color to [new color]. Keep texture, material, and lighting realistic.` |
| Outpaint | `Extend the scene [direction]. Continue the [environment / lighting / perspective] naturally.` |
| Compose two images | `Take [thing] from image 1 and [other] from image 2; combine into [scene description]. Adjust lighting and shadows so it looks naturally composited.` |

**Critical rule:** name what you want to *preserve* explicitly. Without that, the model often regenerates parts you wanted to keep.

---

## Photo restoration & colorization

**Why this matters:** Restoration needs *preservation* (don't reinvent the face) plus *era awareness* (1940s palette ≠ 1970s palette). Pro reads contextual cues — clothing, materials, location — to pick plausible colors.

**Restoration template:**
```
Restore this old photograph: [list specific damage — scratches / tears / fading / yellowing / dust / creases].
Repair damage and recover detail without altering the subject's face, clothing, or composition.
Preserve the original era and aesthetic; do not modernize.
```

**Colorization template:**
```
Colorize this black-and-white photograph from approximately [decade or year].
Apply era-appropriate, plausible colors based on visible context (clothing materials, location, lighting).
Skin tones natural, fabric colors typical for the period.
Preserve all original detail, composition, and grain — do not smooth or modernize.
```

**Examples:**
```bash
imagegen "Restore this old photograph: remove scratches, tears in the upper-right corner, dust spots, and yellowing. Recover faded detail in the shadows. Preserve the subject's face, clothing, pose, and the original sepia tone exactly. Do not modernize or smooth the grain." \
  -i grandma_1952.jpg -r 2K

imagegen "Colorize this black-and-white photograph from approximately 1968. Apply era-appropriate plausible colors: warm earthy palette, muted denim, period-correct skin tones. Use contextual cues (clothing fabric, indoor setting, light source) to pick realistic hues. Preserve all original detail, grain, and composition — do not smooth or modernize." \
  -i family_1968.jpg -r 2K

imagegen "Restore and colorize together: repair scratches and creases, recover detail in faded areas, then colorize with era-appropriate (~1945) palette. Keep faces, expressions, and composition exact. Preserve original photographic grain." \
  -i wedding_1945.jpg -r 2K
```

**Tips:**
- For severely damaged photos, restore first (one pass), then colorize (second pass on the restored output).
- Era cues that help the model: visible clothing style, hair style, vehicle, signage, building materials.
- Don't ask for "modern HD" — that defeats the point and the model will fabricate detail. Ask for restoration of *existing* detail.
- Watermark applies even to restored photos (SynthID).

---

## Outfit / hairstyle / expression / age edits

**Why this matters:** Identity-preserving edits are the single highest-failure category. The fix is **single variable at a time** + **explicit preservation list** + **separate generations for separate angles**.

**Universal edit template:**
```
Using the provided image, change only [the one thing].
Preserve exactly: face, facial features, expression, hair (unless changing), pose, body proportions, camera angle, lighting, and background.
[Specifics of the change].
```

**Outfit / clothing swap:**
```bash
imagegen "Using the provided image, change only the clothing. Replace the current outfit with a tailored navy wool blazer, white silk blouse, and high-waisted black trousers. Preserve exactly: face, facial features, expression, hair, pose, body proportions, camera angle, lighting, and background." \
  -i source.jpg -r 2K

# With a clothing reference:
imagegen "Take the dress from image 1 and put it on the woman in image 2. Preserve her face, hair, pose, body proportions, camera angle, lighting, and background exactly. Adjust only the dress to fit naturally on her body, including realistic fabric folds and shadows." \
  -i dress_ref.jpg -i person.jpg -r 2K
```

**Hairstyle change:**
```bash
imagegen "Using the provided image, change only the hairstyle. Give her a shoulder-length curtain bob with soft face-framing layers, same natural dark brown color. Preserve exactly: face, facial features, expression, skin, pose, clothing, camera angle, lighting, and background. Hair must look real with shadow-matched highlights and natural scalp visibility." \
  -i source.jpg -r 2K
```

**Expression change:**
```bash
imagegen "Using the provided image, change only the expression. Make her smile warmly with teeth showing, eyes softened with subtle squinting at the corners. Preserve exactly: facial features, identity, hair, pose, clothing, camera angle, lighting, and background. Skin tones, freckles, and any other identifying details must match exactly." \
  -i source.jpg -r 2K
```

**Age edit (younger or older):**
```bash
imagegen "Using the provided image, age the subject naturally to approximately 65 years old. Add age-appropriate fine wrinkles around the eyes and mouth, slight skin texture changes, salt-and-pepper to grey hair, slightly softer jawline. Preserve their fundamental identity (eye shape, nose, ear shape, expression, smile pattern), pose, clothing, camera angle, lighting, and background." \
  -i source.jpg -r 2K
```

**Lighting / time-of-day relight:**
```bash
imagegen "Using the provided image, change only the lighting and time of day. Re-light as if shot at golden hour with warm directional sunlight from the left, soft shadows on the right side of the face. Preserve exactly: face, expression, hair, clothing, pose, camera angle, and background composition. Adjust only how light falls on the subject and scene." \
  -i source.jpg -r 2K
```

**Background swap (people-safe):**
```bash
imagegen "Using the provided image, replace only the background with a sun-drenched Tuscan countryside (cypress trees, rolling hills, late afternoon golden light). Preserve the subject exactly: face, hair, pose, clothing, body, edges. Adjust the subject's lighting to match the new background's golden-hour direction subtly, but keep the subject's identity and core composition unchanged." \
  -i source.jpg -r 2K
```

**Critical rules:**
- **One variable at a time.** Don't combine "new outfit AND new hair AND smiling" in one prompt — drift compounds.
- **Generate angles separately.** Don't ask for "front, side, back" of an edited person in one image. Run three prompts.
- **Always include the preservation list.** Without it, faces drift across iterations.
- **For faces**, repeat distinguishing features verbatim (`freckles, hazel eyes, slight gap between front teeth`) — anchors identity.

---

## Character consistency series

**Why this matters:** Producing the same character across multiple poses/scenes is one of the harder use cases. Pro handles it well with explicit reference + naming.

**Workflow:**
1. Generate (or pick) a clean front-facing reference image of the character.
2. Pass it as `-i` to subsequent generations and explicitly reference it.

**Example — first generate the reference:**
```bash
imagegen 'A studio portrait of a young woman with shoulder-length auburn hair, freckles, hazel eyes, and a soft smile, wearing a deep green oversized sweater. Front-facing, neutral expression, soft three-point softbox lighting on a seamless white background. Photorealistic, 85mm portrait lens, shallow depth of field.' \
  -a 1:1 -r 2K -o character_ref.png
```

**Then reuse:**
```bash
imagegen 'Using the provided image as the character reference (auburn hair, freckles, green sweater), generate the same woman walking through an autumn forest at golden hour, looking back over her shoulder with a warm smile. 35mm lens, cinematic depth of field. Match her face, hair, and outfit exactly.' \
  -i character_ref.png -a 4:5 -r 2K -o forest_scene.png

imagegen 'Using the provided image as the character reference, generate the same woman sitting at a window seat in a sunlit cafe, holding a ceramic mug, reading a book. Soft natural light from the window. Match her face, hair, and outfit exactly. 50mm lens.' \
  -i character_ref.png -a 3:2 -r 2K -o cafe_scene.png
```

**Tips:**
- Always re-state the distinguishing features in each follow-up prompt — the reference image alone isn't enough; the description anchors the model.
- For 360-degree views, prompt incrementally: `... in profile looking right`, `... three-quarter view from the left`, `... back of head`.
- For brand mascots, set `-r 2K` and reuse the same first generation as the canonical reference.
