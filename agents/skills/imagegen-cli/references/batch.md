# Batch mode

For more than one distinct prompt — variations, asset sets, brand sheets — use batch mode. The CLI accepts a JSON array via `--config <file>` or `--config -` (stdin).

## Schema

Each entry requires `prompt`. All other fields are optional and override the default for that entry only. Field names match CLI flag long forms with hyphens (`aspect-ratio`, `remove-background`).

```jsonc
[
  {
    "prompt": "required string",                       // text prompt
    "count": 1,                                        // int, default 1
    "aspect-ratio": "1:1",                             // 1:1|2:3|3:2|3:4|4:3|4:5|5:4|9:16|16:9|21:9 (+ Flash-only 1:4|4:1|1:8|8:1)
    "resolution": "1K",                                // 1K|2K|4K (+ Flash-only 0.5K)
    "format": "png",                                   // png|jpg
    "image": ["./refs/logo.png", "https://..."],       // string[] of paths/URLs (up to 14)
    "output": "${HOME}/pictures/foo.png",              // dir or file path; ${VAR}/$VAR/~ expanded
    "remove-background": false,                        // bool
    "grounding": false,                                // bool — Google Search grounding (real-time web data)
    "thinking-level": "minimal",                       // minimal|low|medium|high — Flash only; omit for default
    "model": "gemini-3-pro-image"                      // gemini-3-pro-image | gemini-3.1-flash-image
  }
]
```

A per-entry `0.5K` resolution, banner aspect ratio, or `thinking-level` requires `"model": "gemini-3.1-flash-image"` on that entry; combined with the default Pro model it aborts the whole batch pre-flight with a clear error naming the offending job.

`schema.json` lives at the repo root (`/Users/andreassonnleitner/Workspaces/git-workspace/replicate/imagegen/schema.json`). The root is a JSON **array**, so an inline `$schema` key can't be used — wire the schema up in the editor's JSON schema settings (e.g. VS Code `json.schemas` matching `*.imagegen.json`) for autocompletion.

## Precedence

`defaults < config entry < CLI flags`

CLI flags **override** the config entry, so this is useful for "render the whole batch at 4K" without editing the file:

```bash
imagegen --config brand.json -r 4K           # everything at 4K
imagegen --config brand.json -m gemini-3.1-flash-image   # everything via Nano Banana 2 (Flash)
```

## Common patterns

### A) Inline / stdin batch — quick variations

For ad-hoc series without a saved file:

```bash
echo '[
  {"prompt":"a minimalist mountain logo, line art, black on white","aspect-ratio":"1:1"},
  {"prompt":"a vintage badge mountain logo with banner, forest green and cream","aspect-ratio":"1:1"},
  {"prompt":"a modern geometric mountain wordmark, sans-serif, monochrome","aspect-ratio":"1:1"}
]' | imagegen --config - -r 2K -b
```

### B) Brand asset set — same logo across mockups

```jsonc
// brand-aurora.json
[
  {
    "prompt": "Studio photograph of a frosted glass dropper bottle for 'Aurora Botanicals', label clearly visible, on a soft cream surface with eucalyptus sprigs. Soft natural lighting from the left. 50mm, f/2.8.",
    "image": ["./refs/aurora-logo.png"],
    "aspect-ratio": "4:5",
    "resolution": "2K"
  },
  {
    "prompt": "A flat-lay arrangement of Aurora Botanicals products: dropper bottle, cream jar, and lip balm, all on a warm oak surface with dried flowers and a linen cloth. Top-down view, editorial magazine style.",
    "image": ["./refs/aurora-logo.png"],
    "aspect-ratio": "1:1",
    "resolution": "2K"
  },
  {
    "prompt": "Lifestyle shot of a woman applying Aurora Botanicals cream in a sun-drenched bathroom mirror reflection, warm morning light, 35mm film aesthetic.",
    "image": ["./refs/aurora-logo.png"],
    "aspect-ratio": "9:16",
    "resolution": "2K"
  },
  {
    "prompt": "Pure logo presentation: the Aurora Botanicals wordmark centered on a soft sage green background with subtle paper texture. Press kit style.",
    "image": ["./refs/aurora-logo.png"],
    "aspect-ratio": "16:9",
    "resolution": "4K",
    "output": "outputs/aurora-press-hero.png"
  }
]
```

```bash
imagegen --config brand-aurora.json
```

### C) Hero variants — explore aspect ratios in one go

```jsonc
// hero-explore.json
[
  { "prompt": "A wide cinematic hero of a developer workspace at dusk — single illuminated monitor, oak desk, city bokeh through window, warm amber lamp light, cinematic teal shadows. Negative space on the left.", "aspect-ratio": "21:9", "resolution": "4K" },
  { "prompt": "A wide cinematic hero of a developer workspace at dusk — single illuminated monitor, oak desk, city bokeh through window, warm amber lamp light, cinematic teal shadows. Negative space on the left.", "aspect-ratio": "16:9", "resolution": "4K" },
  { "prompt": "A vertical hero of a developer workspace at dusk — single illuminated monitor, oak desk, warm amber lamp, soft city bokeh. Subject in lower third, negative space top.", "aspect-ratio": "9:16", "resolution": "2K" }
]
```

**Caution:** dir-mode filenames are `{timestamp}_{slug}_{N}` and the never-overwrite counter only protects explicit file `output` paths. Entries with identical prompt text (like the two above) that finish in the same second can silently overwrite each other — give such entries distinct per-entry `output` paths.

### D) Per-entry output paths — write to specific files

Use `output` per entry when you want named files instead of timestamped slugs. `${HOME}`, `$VAR`, and `~/` are expanded.

```jsonc
[
  { "prompt": "logo concept A", "output": "${HOME}/projects/aurora/concepts/logo_a.png" },
  { "prompt": "logo concept B", "output": "${HOME}/projects/aurora/concepts/logo_b.png" },
  { "prompt": "logo concept C", "output": "${HOME}/projects/aurora/concepts/logo_c.png" }
]
```

### E) Mixed models — Nano Banana Pro for text-heavy, Nano Banana 2 for drafts

```jsonc
[
  {
    "prompt": "Final brand wordmark for 'Helix' on a white background, minimalist sans-serif, ALL CAPS, perfectly legible.",
    "model": "gemini-3-pro-image",
    "resolution": "4K"
  },
  {
    "prompt": "Quick mood study: abstract dark blue gradient with subtle helix motif, no text.",
    "model": "gemini-3.1-flash-image",
    "resolution": "1K",
    "count": 4
  }
]
```

## Workflow tips

- **Build the JSON in the conversation, then pipe through stdin** for ad-hoc batches. No need to save a file the user didn't ask for.
- **Save a file** when the user is iterating on a brand/series and will rerun. Put it next to the project's assets, not in the imagegen repo.
- **Per-entry `count` adds up.** A batch with 3 entries each at `count: 2` produces 6 images and reports `Total: 6/6 images generated across 3 jobs`.
- **One failed entry doesn't kill the batch — but pre-flight errors do.** Generation-time failures print `[i/N] failed (reason)` and the run continues. However an invalid config schema, a missing local ref file, or a missing env var aborts the ENTIRE batch before anything generates. The process also exits 0 even when images fail, so parse the `success/total` summary, not the exit code. 429/5xx errors retry indefinitely at 1s intervals, so heavy rate limiting looks like a hang.
- **Reference image upload is deduplicated.** The same `./refs/logo.png` across 10 entries is uploaded at most once (content-hash key + existence check); each entry still independently re-hashes the file and presigns its own 1h URL.
- **Background removal works per-entry.** Set `"remove-background": true` only on entries that need it; it costs an extra Replicate call.

## Anti-patterns

- ❌ One giant prompt that asks for "5 different logo variations on one canvas" — Pro can do this but loses fidelity. Better: 5 batch entries.
- ❌ Putting `$schema` at the array root (it's an object key); instead, reference the schema in your editor's settings or skip it.
- ❌ Setting `count: 10` on every entry — that's 10 parallel Gemini calls per entry. Stick to `count: 1–4` per entry; if you need 20 of one prompt, fine, but expect rate limits.
