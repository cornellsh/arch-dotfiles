# arch-dotfiles

My Arch Linux config. Run the installer, pick what you want.

```bash
git clone https://github.com/cornellsh/arch-dotfiles.git
cd arch-dotfiles
./install.sh
```

## How the installer works

`./install.sh` opens a checklist. Move with `↑/↓` (or `j/k`), toggle with
`space`, hit `enter` to run. `a` selects everything, `n` clears, `q` quits.

| Component   | What it does |
|-------------|--------------|
| Shell       | Drops in `.zshrc`, `.bashrc`, `.profile`, `.gitconfig`, `.p10k.zsh`. Installs Oh My Zsh, zsh-autosuggestions, and powerlevel10k if they're missing. |
| App Configs | Copies everything under `config/` into `~/.config/`. That's niri, waybar, DankMaterialShell, ghostty, etc. |
| Systemd     | User services from `systemd/user/`, e.g. `webcam.service`. |
| Scripts     | `~/scripts` and `~/.local/bin`. |
| VS Code     | `settings.json`, `keybindings.json`, `mcp.json`, snippets, plus every extension listed in `vscode/extensions-list.txt`. |
| OpenCode    | Config, pinned plugins, themes, skills. See below. |
| Tmux        | `.tmux.conf` (mirrored to `~/.config/tmux/tmux.conf`). Kills any running tmux server so the new config takes effect on next launch. |

## OpenCode

Run the OpenCode toggle and you get:

- `~/.config/opencode/opencode.json` (plugins and permissions)
- `~/.config/opencode/package.json` (pinned plugin versions; the script
  runs `bun install` or `npm install`)
- `~/.config/opencode/dcp.jsonc` (Dynamic Context Pruning settings)
- `~/.config/opencode/ocx.jsonc` and `~/.config/opencode/.ocx/receipt.jsonc`
  (so `ocx verify` works and `ocx update` can refresh registry plugins)
- `~/.config/opencode/plugins/` (OCX-managed plugin source like `worktree.ts`)
- `~/.config/opencode/themes/` (currently just `cornell.sh.json`)
- `~/.agents/skills/` (agent-browser, architecture-skill, design-judgement,
  humanizer, solid-patterns)

### Plugins

| Plugin | Source | Why |
|---|---|---|
| opencode-claude-auth | npm | Claude subscription auth |
| opencode-gemini-auth | npm | Google/Gemini auth |
| @tarquinen/opencode-dcp | npm | Drops obsolete tool outputs from context. Saves tokens on long sessions. |
| opencode-snip | npm | Pipes shell output through `snip` so the LLM doesn't see 5000 lines of `npm install` noise. |
| envsitter-guard | npm | Stops the agent from reading or editing `.env*` files. |
| opencode-agent-skills | npm | Picks up skills in `~/.agents/skills` and project-local dirs. |
| opencode-handoff | npm | `/handoff` to continue a session in a fresh one when context fills up. |
| kdco/worktree | OCX | `worktree_create` and `worktree_delete` tools. Spawns a new terminal in an isolated git worktree. |

### Things you need on the system

- `bun` (preferred) or `npm` for the npm plugins.
- `ocx` for the registry plugins. The installer runs `bun add -g ocx` if
  it's missing.
- `go` only if `snip` isn't already on your PATH; the installer will
  `go install` it.

## After install

- `source ~/.zshrc`
- Restart VS Code
- Enable user services if you want them, e.g.
  `systemctl --user enable --now webcam.service`
