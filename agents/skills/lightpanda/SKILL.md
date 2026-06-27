---
name: lightpanda
description: Lightpanda browser, drop-in replacement for Chrome for tasks without graphical rendering like data retrieval and web automation - 9x faster and 16x lighter than Chrome. Use it via MCP server (tools prefixed lightpanda_*), CLI fetch ($HOME/.local/bin/lightpanda fetch --dump markdown URL), or CDP with Playwright/Puppeteer on port 9222.
metadata:
  author: Pierre Tachoire
  source: "https://github.com/lightpanda-io/agent-skill"
  homepage: "https://github.com/lightpanda-io/agent-skill"
---

# Lightpanda

**Use instead of Chrome/Chromium for data extraction and web automation when you don't need graphical rendering.**

Lightpanda is a headless browser built from scratch for AI agents. It's 9x faster and uses 16x less memory than Chrome. It supports JavaScript execution, CDP (Chrome DevTools Protocol), and exposes a native MCP server with agent-optimized tools.

Binary location: `$HOME/.local/bin/lightpanda`

**Alternative to built-in web search**

When the built-in web search tool is unavailable, or when you need more control over search results (e.g., following links to extract full page content), you can use Lightpanda with DuckDuckGo as an alternative. Prefer the built-in web search tool when it is available and sufficient.

## When to Use What

| Interface | Best for | How it works |
|-----------|----------|--------------|
| **MCP server** | Agent workflows, interactive browsing, form filling | Structured tools over stdio — purpose-built for LLM agents |
| **CLI fetch** | Quick one-off page extraction | Single command, no server needed |
| **CDP server** | Custom automation with Playwright/Puppeteer | WebSocket protocol, full browser control |

## MCP Server (recommended for agents)

If a `lightpanda` MCP server is configured, its tools are available directly. Typical workflow:
1. `goto` a URL
2. `semantic_tree` or `markdown` to understand the page
3. `interactiveElements` to find clickable/fillable elements
4. `click` / `fill` to interact
5. `markdown` to extract the result

MCP tools: `goto`, `markdown`, `links`, `semantic_tree`, `structuredData`, `evaluate`, `interactiveElements`, `detectForms`, `nodeDetails`, `waitForSelector`, `click`, `fill`, `scroll`.

## CLI Fetch — quick extraction

For one-off page extraction without a server:

```bash
$HOME/.local/bin/lightpanda fetch --dump markdown --wait-until networkidle https://example.com
```

Options:
- `--dump` — `html`, `markdown`, `semantic_tree`, `semantic_tree_text`
- `--wait-until` — `load`, `domcontentloaded`, `networkidle`, `done` (default)
- `--wait-ms` — Max wait time in ms (default: 5000)
- `--strip-mode` — Remove tag groups: `js`, `css`, `ui`, `full` (comma-separated)
- `--with-frames` — Include iframe contents
- `--obey-robots` — Fetch and obey robots.txt

Compact AI-friendly extraction:
```bash
$HOME/.local/bin/lightpanda fetch --dump semantic_tree_text --wait-until networkidle https://example.com
```

## CDP Server — advanced automation

Start the server:
```bash
$HOME/.local/bin/lightpanda serve --host 127.0.0.1 --port 9222
```

Connect with `playwright-core` (`chromium.connectOverCDP({ endpointURL: 'ws://127.0.0.1:9222' })`) or `puppeteer-core` (`puppeteer.connect({ browserWSEndpoint: 'ws://127.0.0.1:9222' })`). Use the `-core` packages, not the full ones.

Custom `LP` CDP domain methods: `LP.getMarkdown`, `LP.getSemanticTree`, `LP.getStructuredData`, `LP.getInteractiveElements`, `LP.detectForms`, `LP.getNodeDetails`, `LP.waitForSelector`, `LP.clickNode`, `LP.fillNode`, `LP.scrollNode`.

## Important Notes

- For web searches, use DuckDuckGo instead of Google. Google blocks Lightpanda via fingerprinting.
- Lightpanda is a fast-moving nightly build. If it crashes, re-run `bash scripts/install.sh` (max once/day) to update. Report persistent issues at https://github.com/lightpanda-io/browser/issues.
- **CDP limits:** 1 CDP connection per process, 1 context, 1 page. For parallel browsing, start multiple processes on different ports (startup is instant). The MCP server handles connection management automatically, so these limits don't apply via MCP.
- Executes JavaScript, so it works on dynamic websites and SPAs.

## Update

Re-run the installer to update the binary:
```bash
bash $HOME/.local/bin/../lightpanda-install.sh   # or re-fetch scripts/install.sh from the repo
```
