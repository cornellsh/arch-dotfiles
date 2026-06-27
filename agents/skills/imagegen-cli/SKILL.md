---
name: imagegen-cli
description: Generate images via Andreas's `imagegen` CLI (Google Gemini 3 Pro/Flash Image, with Replicate background removal). Use when the user asks to generate images, create logos, mock up UIs, produce product shots, batch-generate from a prompt list, remove backgrounds, or mentions imagegen, gemini-3-pro-image ("Nano Banana Pro"), gemini-3.1-flash-image ("Nano Banana 2"). Covers prompt engineering for the underlying Gemini 3 image models, CLI invocation, batch JSON config, reference images, and common pitfalls.
allowed-tools: Bash(imagegen:*)
---

# imagegen CLI

`imagegen` is a thin CLI client of the imagegen API server (`https://imagegen.s8r.dev`). It generates via Google Gemini 3 image models (the default), with OpenAI and Grok available via `--provider`, plus Replicate background removal — all run server-side. It's installed on PATH at `~/.local/bin/imagegen`, so call `imagegen` directly; do NOT probe with `command -v` / `which` first. Install/update: `curl -fsSL https://imagegen.s8r.dev/install.sh | IMAGEGEN_API_TOKEN=<token> bash` for the first install, then `imagegen update` to upgrade in place.

Two responsibilities live in this skill:
1. **Invoke the CLI correctly** — flags, env vars, batch mode, output paths.
2. **Write prompts that work for Gemini 3 image models** — these models reward narrative descriptions, photographic vocabulary, and explicit text.

## When to delegate vs. just run

- Single image, prompt is concrete → just run the command.
- User wants variations / a series / brand assets → use batch mode with a JSON config (atomic, lower overhead).
- User gives a vague brief ("make me a logo") → ask 2–3 clarifying questions (industry, style preference, must-include elements, background) before generating, since Gemini 3 Pro reasons through the prompt and benefits from specifics.

## CLI cheat sheet

```
imagegen <prompt> [options]
imagegen --config <file|-> [options]
```

| Flag | Short | Default | Notes |
|---|---|---|---|
| `--count <n>` | `-n` | 1 | Concurrent generations |
| `--aspect-ratio <r>` | `-a` | `1:1` | `1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9` + Flash-only banners `1:4, 4:1, 1:8, 8:1` |
| `--resolution <r>` | `-r` | `1K` | `1K, 2K, 4K` + Flash-only `0.5K` |
| `--format <f>` | `-f` | `png` | `png, jpg` |
| `--image <p>` | `-i` | — | Reference image path or URL, repeatable (model limit 14; the CLI doesn't validate, >14 fails at the API) |
| `--output <p>` | `-o` | `outputs/` | Directory or `.png`/`.jpg` file path |
| `--model <m>` | `-m` | `gemini-3-pro-image` | or `gemini-3.1-flash-image` |
| `--remove-background` | `-b` | false | Sends result through Replicate `851-labs/background-remover` |
| `--grounding` | `-g` | false | Enables Google Search grounding (`tools: [{googleSearch:{}}]`) so factual prompts can reach the web |
| `--thinking-level <l>` | `-t` | — | `minimal, low, medium, high`. Flash only. Omitted = Flash default `minimal`. Crank to `high` for harder layouts at Flash prices |
| `--config <f\|->` | `-c` | — | JSON config, `-` reads stdin |
| `--provider <p>` | — | `gemini` | `gemini` (default), `openai`, `grok`. The flags above are Gemini's; other providers use `--size`, `--quality`, `--background`, `--moderation` (openai) / `--size`, `--negative`, `--safe-mode` (grok). |
| `--version` | `-v` | — | Print version. |

There is a real `--help`, and unknown flags give a clean error (no crash dump). Bareword commands: `imagegen version`, `imagegen help`, `imagegen update` (self-update from the server).

**Flash-only features** (`0.5K` resolution, banner ratios `1:4/4:1/1:8/8:1`, `--thinking-level`): pass `-m gemini-3.1-flash-image`. Using them on the Pro model is rejected by the server (the Pro image model rejects `thinking_level` outright). `0.5K` maps to the API's `512` tier.

**Config**: the only required env var is `IMAGEGEN_API_TOKEN` (the install script writes it into your shell rc). The server holds all provider keys (Google/OpenAI/Replicate) and S3 credentials — there are NO local Google/Replicate/S3 keys. Optional: `IMAGEGEN_API_URL` (default `https://imagegen.s8r.dev`). Local `-i` reference files are uploaded to the server automatically (content-addressed, sent once ever); no S3 keys needed. Assume the token is set; only diagnose it if a run fails with a missing-token error.

**Output paths:**
- Directory: `outputs/{TIMESTAMP}_{slug}_{N}.{ext}` — slug is sanitized prompt (50 chars max).
- File (`.png`/`.jpg`/`.jpeg`): exact path; `_N` suffix appended when `--count > 1`; existing files never overwritten (counter appended).
- Background-removed: `{stem}.nobg.png` alongside the original.

Generated images carry A1111-compatible metadata (prompt, model, settings) embedded server-side as a PNG `tEXt` chunk or JPEG `EXIF UserComment`.

## Pro vs. Flash — which model

Aliases: **Nano Banana Pro** = `gemini-3-pro-image` (default). **Nano Banana 2** = `gemini-3.1-flash-image`. Both GA since 2026-05-28; the older `-preview` IDs are shut down as of 2026-06-25 and the CLI no longer accepts them.

| Use Pro (`gemini-3-pro-image`, default) | Use Flash (`gemini-3.1-flash-image`) |
|---|---|
| Maximum **text/layout fidelity** (dense posters, UI labels, infographics) | Production volume work at ~half Pro's price |
| **Brand consistency** across multiple references (up to 6 object + 5 character refs) | Strong text rendering too — fine for simple text, localized text |
| Complex multi-element compositions, reasoning-heavy layouts | Drafts, iteration, style explorations |
| Image edits where logic must hold up | Single-subject shots, speed-sensitive comps |

Both models run a "thinking" pass by default (it cannot be disabled). Flash defaults to a minimal thinking level, which is why it's faster; Pro reasons more deeply through layout and text. Flash is no longer a drafts-only tier — Google positions it as the production default — but Pro remains the safer pick for the hardest text/layout work. Price per image: Pro $0.134 (1K/2K) / $0.24 (4K); Flash $0.045 (0.5K) / $0.067 (1K) / $0.101 (2K) / $0.151 (4K).

**Flash-only features the CLI now exposes** (pass `-m gemini-3.1-flash-image`): `0.5K` resolution (`-r 0.5K`), the banner ratios `1:4/4:1/1:8/8:1` (`-a 8:1` etc.), and `--thinking-level`/`-t` (`minimal`/`low`/`medium`/`high`; Flash defaults to `minimal`, `-t high` buys deeper layout reasoning at Flash prices). Using any of them on Pro is a hard error; Pro's thinking is always on and not configurable. `--grounding`/`-g` (Search grounding) works on both models. The one Flash capability NOT yet wired into the CLI: video-to-image input — API-level only.

## Aspect ratio + resolution decision rules

| Use case | Aspect | Resolution |
|---|---|---|
| Logo, app icon, square social | `1:1` | `2K` |
| Web hero, landscape banner, cinematic | `16:9` | `2K`–`4K` |
| Mobile screen mockup, story, vertical poster | `9:16` | `2K` |
| Social portrait (Instagram feed) | `4:5` | `2K` |
| Magazine/editorial portrait | `2:3` or `3:4` | `2K`–`4K` |
| Ultra-wide cinematic | `21:9` | `4K` |
| Print / billboard / detail-critical hero | matches medium | `4K` |
| Iteration / drafts | matches target | `1K` |
| Wide banner / strip (Flash only) | `4:1` or `8:1` | `1K`–`2K` |
| Thumbnail / tiny preview (Flash only) | matches target | `0.5K` |

**Default to 2K** for production work. 4K outputs are huge (~25MB PNG), slow, cost ~1.8× a 2K image, and the 4K tier is still preview-stage (1K/2K are GA) — only use 4K when the medium needs the detail. 1K is fine for selection rounds.

## Prompt engineering — the universal formula

Gemini 3 image models reward **narrative description** over keyword soup. Build prompts from these elements:

```
[Subject + adjectives] doing [Action] in [Location/Context].
[Composition / camera angle].
[Lighting / atmosphere].
[Style / medium].
[Specific text or constraint, in quotes].
```

Not every element on every prompt — but the more concrete you are, the closer the output lands.

### Universal rules

1. **Describe, don't list.** "A close-up portrait of an elderly Japanese ceramicist with sun-etched wrinkles and a warm smile inspecting a glazed tea bowl in his rustic workshop. Soft, golden hour light through windows. 85mm portrait lens with bokeh." beats "old man, ceramic, workshop, golden hour, 85mm, bokeh".
2. **Open with the operation verb.** Start the prompt with a strong verb naming what you want: Create / Edit / Compose / Restore. It tells the model the primary operation up front.
3. **Quote literal text, finalize copy first.** Always wrap on-image text in `"double quotes"`. For text-heavy images, write the exact final copy BEFORE prompting and embed it verbatim — don't ask the model to invent the words. Fonts can be described (`a flowing, elegant brush script font`) or named outright (`Century Gothic, bold`). Both models render text well; Pro is the safer pick for dense layouts.
4. **Use semantic negative prompts.** Phrase positively: "an empty, deserted street" — not "a street with no cars". Gemini 3 doesn't reliably parse "no X".
5. **Skip clichés.** Don't append `4k, masterpiece, trending on artstation, ultra-detailed`. They add noise. Specific photographic terms (`85mm`, `f/1.8`, `three-point softbox`, `golden hour backlighting`) work better.
6. **Photographic vocabulary for realism.** Camera/lens (`85mm portrait lens`, `wide-angle`, `macro`), aperture (`shallow depth of field, f/1.8`), lighting setup (`three-point softbox`, `chiaroscuro`, `golden hour backlighting`), film stock (`shot on Kodak Portra 400`, `1980s color film with grain`). Name materials, not just objects: `navy blue tweed sneaker`, not `sneaker`.
7. **No transparent backgrounds.** Gemini doesn't output alpha. Request `white background` or a solid color and use `--remove-background` if you need transparency.
8. **Localized text:** write the prompt in English and specify the target language for the rendered text (`the headline "..." rendered in German`). Verify rendered non-English text before shipping.
9. **Iterate.** First gen rarely lands. Adjust one variable at a time (lighting, then composition, then style).

### Hard rules (these override "iterate freely" — they are where every angry session came from)

1. **A user-provided reference is mandatory `-i` input.** If the user attaches an image, or points at an approved on-disk image/screenshot ("use this as ref", "match the reference", "like the section screenshot"), you MUST pass it as `-i` and make the generation an EDIT/MATCH of it. NEVER iterate on your own generated outputs while a user reference exists.
2. **Hold the prompt constant; change only the words the correction names.** Keep ONE canonical prompt string. On a correction, diff it: edit only the clause for the thing the user flagged, leave every other clause byte-for-byte. Do NOT retype the subject/lighting/style paragraphs from scratch. State the exact change before regenerating ("changing only the ground from valley to ridge; creature + sky clauses unchanged").
3. **Edit, don't redraw, when an instance already exists.** If the user wants a change to a specific existing image (or a revert to a known-good state), pass that image as `-i` with a "keep everything else identical" instruction. Do not regenerate from scratch, and do not stack blind edits off screenshots you cannot read. If you cannot judge the result from your own screenshot, STOP and pull ground-truth pixels or revert; do not keep guessing.
4. **A name is a label, not a theme to render.** When an asset has a codename (Ash, Thunderbolt, "capital"), do not invent literal thematic content from the word. Recreate the actual shape/symbol the user described; ask if unsure.
5. **Stop the reroll bleed.** After 2 rejected reroll rounds on the same asset, STOP generating and ask for a reference image or one concrete spec change, instead of opening a new aesthetic direction. Do not fire a large parallel batch (high `-n`, many concurrent jobs) on a concept the user has not validated: calibrate ONE, confirm, THEN batch.

(Provenance: distilled from real failure sessions f37266dc and 6caa6013.)

### Reference images (`-i`)

Formula when passing `-i`:

```
[Reference role assignments] + [Relationship instruction] + [New scenario]
```

Examples:
- `imagegen "Using image 1 as the character pose and image 2 as the art style, place this character in a sun-drenched minimalist living room." -i pose.jpg -i style.png`
- `imagegen "Take the dress from image 1 and the model from image 2; generate a full-body editorial fashion shot with outdoor lighting and shadows adjusted accordingly." -i dress.jpg -i model.jpg`

Up to 14 refs total (model limit; the CLI doesn't validate it). Within that, fidelity has per-type sub-limits: Pro holds high fidelity for up to **6 object refs + 5 character refs**; Flash for up to **10 object + 4 character**. Beyond those counts expect drift. Local files get uploaded to S3 (cached by content hash) and presigned for 1h. URLs are passed through directly.

### Image editing (single ref + edit instruction)

For edits, pass the source as `-i` and describe the change while preserving the rest:

- **Add element:** `imagegen "Using the provided image, add a small knitted wizard hat on the cat's head. Match the soft lighting of the photo." -i cat.jpg`
- **Remove element:** `imagegen "Remove the person in the background. Keep everything else identical, including reflections and shadows." -i scene.jpg`
- **Inpaint (semantic mask):** `imagegen "Change only the blue sofa to a vintage brown leather chesterfield. Keep the room, pillows, and lighting unchanged." -i room.jpg`
- **Style transfer:** `imagegen "Transform this photo into Van Gogh's Starry Night style. Preserve the building composition but render with swirling impasto brushstrokes and deep blues and bright yellows." -i city.jpg`

## Use-case templates

Detailed prompt templates live in references/, split by domain. **Read ONLY the file matching the request** — don't load the others:

| Request involves | Read |
|---|---|
| Photorealism, portraits, product shots, food, architecture/interiors, fashion | [references/photography.md](references/photography.md) |
| Logos, brand identity sheets, web heroes, covers/posters, YouTube thumbnails | [references/brand-marketing.md](references/brand-marketing.md) |
| UI mockups, infographics, diagrams | [references/ui-infographics.md](references/ui-infographics.md) |
| Illustrations, stickers/icons, children's books, painting media, 3D styles, pixel art, comics/manga, concept art, tattoo, patterns | [references/illustration-art.md](references/illustration-art.md) |
| Editing existing images, restoration/colorization, outfit/hair/expression/age edits, character consistency series | [references/editing-continuity.md](references/editing-continuity.md) |

## Batch mode

For >1 distinct prompt, use a JSON config. Each entry needs `prompt`; everything else is optional. Precedence: defaults < config entry < CLI args (CLI overrides apply to all jobs).

Quick form, piped from stdin:

```bash
echo '[{"prompt":"first idea","aspect-ratio":"16:9"},{"prompt":"second idea","count":3}]' | imagegen --config -
```

Detailed batch patterns and the schema reference live in [references/batch.md](references/batch.md).

## Common pitfalls

- **`IMAGEGEN_API_TOKEN is required`** → the token isn't in the current shell. The installer writes it to your shell rc, so `source ~/.zshrc` or open a new terminal. (No Google/Replicate/S3 keys exist locally anymore; the server holds them.)
- **`-i` with a local file** → just works; the CLI uploads it to the server with your token. No S3 keys needed.
- **Prompt requests transparency** → won't happen. Use white/solid bg + `-b`.
- **Asked for 5 images, got 4** → Gemini doesn't always honor exact counts in a single response. The CLI sidesteps this by sending `--count` parallel single-image requests, so each `-n` increment is reliable.
- **Text in non-English looks off** → multilingual rendering and in-image localization are supported (specify the target language explicitly), but verify rendered non-English text before shipping, especially CJK / Arabic / Hindi.
- **Output PNG is 25MB** → 4K outputs are huge. Use 2K unless you actually need 4K detail.
- **Background removal failed / slow** → `-b` runs Replicate server-side and can take a while on cold starts; it warns but keeps the original. It's a separate server call after generation.
- **"no image data in response"** → a model-side policy refusal. The CLI already disables all tunable safety categories, so there is no setting to loosen — rephrase the prompt.
- **Factual/current-events content is stale** → the model's knowledge cutoff is January 2025. Put the facts in the prompt, or pass `--grounding`/`-g` to let the model pull real-time data via Google Search. Without grounding, "use accurate, current details" does nothing.
- **Watermark concern** → all outputs carry a SynthID invisible watermark plus C2PA Content Credentials metadata. Non-removable.

## When the user asks for "a logo" / "a UI" / "a banner"

These benefit from clarifying questions before generating. Common follow-ups:
- Logo: industry, name to render, style (minimalist / mascot / vintage / 3D / lettermark), color preference, background.
- UI mockup: platform (iOS / Android / web), single screen or flow, light/dark theme, brand colors.
- Web hero: aspect (16:9 vs 21:9), product/service, mood (warm / clinical / dark / bright), text to overlay.
- Product shot: surface (wood / concrete / marble), lighting (studio / golden hour / dramatic), angle, with or without props.

If the user gives a one-line brief and you proceed without asking, pick reasonable defaults and flag the assumptions: "going with a 1:1 minimalist mark on a white bg at 2K — say if you want something else."
