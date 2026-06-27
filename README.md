# arch-dotfiles

```bash
git clone https://github.com/cornellsh/arch-dotfiles.git
cd arch-dotfiles
./install.sh                 # interactive checklist
./install.sh all             # everything, no prompts
./install.sh shell pi tmux   # just these
```

## Components

| | Installs |
|---|---|
| **Shell** | `.zshrc` · `.bashrc` · `.profile` · `.gitconfig` · `.p10k.zsh`; oh-my-zsh, zsh-autosuggestions, powerlevel10k if missing |
| **Config** | everything in `config/` → `~/.config` (niri, waybar, DankMaterialShell, ghostty) |
| **Systemd** | user services from `systemd/user/` |
| **Scripts** | `~/scripts` · `~/.local/bin` (incl. `wt`, the worktree manager) |
| **VS Code** | settings, keybinds, snippets, extensions |
| **OpenCode** | config, pinned plugins, themes, skills |
| **Pi** | config, extensions, themes, prompts, packages, skills |
| **Tmux** | `.tmux.conf` (+ XDG mirror; restarts a stale server) |

## OpenCode — `~/.config/opencode`

`opencode.json` (model, permissions, plugins, MCP) plus pinned plugins and the
cornell.sh theme. `bun install` runs on setup; `ocx` is installed globally to
manage registry plugins.

- **Plugins** — `opencode-claude-auth` and a local `worktree` plugin. Its
  `worktree_create/delete` tools are disabled in favour of the `wt` CLI.
- **MCP servers** — `lightpanda`, `chrome-devtools`, `telegram` (sources
  `~/.zsh_secrets`; won't start if the path/secret is absent).
- **Permissions** — `telegram_send/forward/reply` and `git push` are gated to
  `ask`; everything else auto-approves.

**Worktrees** — `wt` (`local-bin/wt`): `wt new|fan|go|ls|rm|clean`. Worktrees at
`~/worktrees/<repo>/<branch>/`, repos scanned under `~/work`. Needs only `git`.

## Pi — `~/.pi/agent`

- **settings.json** — theme, model, compaction, pinned packages.
- **extensions/** — `plan-mode`, `subagent`, `todo`, `notify`, `git-checkpoint`,
  `permission-gate`, `protected-paths`, `custom-footer`, `hide-oauth-status`.
- **themes/** — `cornell.sh`.
- **prompts/** — `commit`, `explain`, `review`, `test`.
- **packages** — `pi-claude-oauth-adapter`, `pi-web-access`.

No MCP servers. The equivalents are skills in `~/.agents/skills` (shared with
OpenCode): `imagegen-cli`, `lightpanda`, `telegram-tools`.

**telegram-tools** — `tg` CLI (Telethon via `uv`): `tg me · chats · read ·
search · send · reply`. Credentials from the environment or `~/.zsh_secrets`.

## Requirements

`git` · `zsh` · `tmux` · `node`/`npm` (+ `bun` for OpenCode) · `uv`
(telegram-tools) · `code` CLI (VS Code extensions) · `lightpanda` at
`~/.local/bin` (optional).
