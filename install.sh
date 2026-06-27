#!/usr/bin/env bash
# arch-dotfiles — cornell.sh
# Interactive, opinionated dotfiles installer. No args = TUI checklist.
# With args: `./install.sh all` or `./install.sh shell pi tmux`.

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

# ─── palette (cornell.sh) ───────────────────────────────────────────────────
A=$'\033[38;2;189;147;249m'   # accent  (purple)
P=$'\033[38;2;255;110;153m'   # pink
G=$'\033[38;2;143;217;127m'   # green
Y=$'\033[38;2;240;198;116m'   # amber
D=$'\033[38;2;118;118;118m'   # dim
B=$'\033[1m'; N=$'\033[0m'

say()  { printf '\n%s::%s %s%s%s\n' "$A" "$N" "$B" "$1" "$N"; }
sub()  { printf '   %s%s%s\n' "$D" "$1" "$N"; }
ok()   { printf '   %s✓%s %s\n' "$G" "$N" "$1"; }
warn() { printf '   %s!%s %s\n' "$Y" "$N" "$1"; }

# ─── components: key|label|description ──────────────────────────────────────
COMPONENTS=(
  "shell|Shell|zsh · bash · git · p10k + OMZ plugins"
  "config|Config|~/.config — niri · waybar · dms · ghostty"
  "systemd|Systemd|user services"
  "scripts|Scripts|~/scripts · ~/.local/bin (wt)"
  "vscode|VS Code|settings · keybinds · extensions"
  "opencode|OpenCode|config · plugins · themes · skills"
  "pi|Pi|config · extensions · themes · skills"
  "tmux|Tmux|.tmux.conf"
)
N_ITEMS=${#COMPONENTS[@]}
declare -a SEL; for ((i=0;i<N_ITEMS;i++)); do SEL[i]=1; done

key_of()  { echo "${COMPONENTS[$1]%%|*}"; }
label_of(){ local r="${COMPONENTS[$1]#*|}"; echo "${r%%|*}"; }
desc_of() { echo "${COMPONENTS[$1]##*|}"; }

# ─── TUI checklist ──────────────────────────────────────────────────────────
menu() {
  local cur=0 key rest
  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null || true' RETURN
  while true; do
    clear
    printf '\n  %s%sarch-dotfiles%s  %s· cornell.sh%s\n' "$A" "$B" "$N" "$D" "$N"
    printf '  %s↑/↓ move · space toggle · a all · n none · ↵ install · q quit%s\n\n' "$D" "$N"
    for ((i=0;i<N_ITEMS;i++)); do
      local box ptr lbl
      [ "${SEL[i]}" = 1 ] && box="${A}◉${N}" || box="${D}○${N}"
      [ "$i" = "$cur" ] && ptr="${P}▸${N}" || ptr=" "
      lbl=$(label_of "$i")
      printf '  %s %s  %s%-9s%s %s%s%s\n' "$ptr" "$box" "$B" "$lbl" "$N" "$D" "$(desc_of "$i")" "$N"
    done
    printf '\n'
    IFS= read -rsn1 key
    if [ "$key" = $'\033' ]; then IFS= read -rsn2 -t 0.01 rest || rest=""; key="$key$rest"; fi
    case "$key" in
      $'\033[A'|k) (( cur>0 )) && cur=$((cur-1)) ;;
      $'\033[B'|j) (( cur<N_ITEMS-1 )) && cur=$((cur+1)) ;;
      ' ') [ "${SEL[cur]}" = 1 ] && SEL[cur]=0 || SEL[cur]=1 ;;
      a|A) for ((i=0;i<N_ITEMS;i++)); do SEL[i]=1; done ;;
      n|N) for ((i=0;i<N_ITEMS;i++)); do SEL[i]=0; done ;;
      q|Q) tput cnorm 2>/dev/null || true; printf '\n'; exit 0 ;;
      '') break ;;
    esac
  done
  tput cnorm 2>/dev/null || true
}

# ─── component installers ───────────────────────────────────────────────────
install_shell() {
  say "Shell"
  cp .zshrc .bashrc .profile .gitconfig .p10k.zsh ~/ 2>/dev/null || true
  ok "configs"
  local C="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sub "installing oh-my-zsh"
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1 || true
  fi
  [ -d "$C/plugins/zsh-autosuggestions" ] || git clone -q https://github.com/zsh-users/zsh-autosuggestions "$C/plugins/zsh-autosuggestions" 2>/dev/null || true
  [ -d "$C/themes/powerlevel10k" ]        || git clone -q --depth=1 https://github.com/romkatv/powerlevel10k.git "$C/themes/powerlevel10k" 2>/dev/null || true
  ok "oh-my-zsh · zsh-autosuggestions · powerlevel10k"
}

install_config() {
  say "Config"
  mkdir -p ~/.config && cp -r config/* ~/.config/ 2>/dev/null || true
  ok "~/.config"
}

install_systemd() {
  say "Systemd"
  mkdir -p ~/.config/systemd/user
  cp -r systemd/user/* ~/.config/systemd/user/ 2>/dev/null || true
  systemctl --user daemon-reload 2>/dev/null || true
  ok "user services (daemon reloaded)"
}

install_scripts() {
  say "Scripts"
  mkdir -p ~/scripts ~/.local/bin
  cp -r scripts/* ~/scripts/ 2>/dev/null || true
  cp -r local-bin/* ~/.local/bin/ 2>/dev/null || true
  chmod +x ~/scripts/* ~/.local/bin/* 2>/dev/null || true
  ok "~/scripts · ~/.local/bin"
}

install_vscode() {
  say "VS Code"
  mkdir -p ~/.config/Code/User
  cp vscode/settings.json vscode/keybindings.json vscode/mcp.json ~/.config/Code/User/ 2>/dev/null || true
  cp -r vscode/snippets ~/.config/Code/User/ 2>/dev/null || true
  ok "settings · keybinds · snippets"
  if command -v code >/dev/null 2>&1; then
    sub "installing extensions"
    while IFS= read -r ext; do
      [ -z "$ext" ] || [[ "$ext" == *"{"* ]] && continue
      code --install-extension "$ext" --force >/dev/null 2>&1 || true
    done < vscode/extensions-list.txt
    ok "extensions"
  else
    warn "code CLI not found — skipped extensions"
  fi
}

install_skills() {
  mkdir -p ~/.agents/skills
  cp -r agents/skills/. ~/.agents/skills/ 2>/dev/null || true
  cp agents/.skill-lock.json ~/.agents/.skill-lock.json 2>/dev/null || true
  find ~/.agents/skills -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
  chmod +x ~/.agents/skills/telegram-tools/tg 2>/dev/null || true
  ok "skills → ~/.agents/skills"
}

install_opencode() {
  say "OpenCode"
  mkdir -p ~/.config/opencode/.ocx ~/.config/opencode/themes ~/.config/opencode/plugins
  cp opencode/opencode.json opencode/package.json ~/.config/opencode/
  cp opencode/dcp.jsonc opencode/ocx.jsonc opencode/.gitignore ~/.config/opencode/ 2>/dev/null || true
  cp -r opencode/themes/. ~/.config/opencode/themes/ 2>/dev/null || true
  cp -r opencode/plugins/. ~/.config/opencode/plugins/ 2>/dev/null || true
  cp opencode/.ocx/receipt.jsonc ~/.config/opencode/.ocx/ 2>/dev/null || true
  ok "config · plugins · themes"
  ( cd ~/.config/opencode && { command -v bun >/dev/null && bun install || npm install; } >/dev/null 2>&1 ) || true
  if ! command -v ocx >/dev/null 2>&1; then
    sub "installing ocx"
    { command -v bun >/dev/null && bun add -g ocx || npm install -g ocx; } >/dev/null 2>&1 || true
  fi
  ok "plugins resolved"
  install_skills
}

install_pi() {
  say "Pi"
  mkdir -p ~/.pi/agent/themes ~/.pi/agent/prompts ~/.pi/agent/extensions
  cp pi/settings.json pi/AGENTS.md ~/.pi/agent/   # no secrets: auth.json is never tracked
  cp -r pi/themes/. ~/.pi/agent/themes/ 2>/dev/null || true
  cp -r pi/prompts/. ~/.pi/agent/prompts/ 2>/dev/null || true
  cp -r pi/extensions/. ~/.pi/agent/extensions/ 2>/dev/null || true
  ok "config · extensions · themes · prompts"
  if command -v pi >/dev/null 2>&1; then
    pi install npm:pi-claude-oauth-adapter >/dev/null 2>&1 || true
    pi install npm:pi-web-access          >/dev/null 2>&1 || true
    ok "packages"
  else
    warn "pi not found — npm i -g @earendil-works/pi-coding-agent"
  fi
  install_skills
}

install_tmux() {
  say "Tmux"
  rm -f ~/.tmux.conf ~/.config/tmux/tmux.conf 2>/dev/null || true
  mkdir -p ~/.config/tmux
  cp .tmux.conf ~/.tmux.conf
  cp .tmux.conf ~/.config/tmux/tmux.conf
  ok ".tmux.conf"
  if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
    if [ -n "${TMUX:-}" ]; then
      warn "inside tmux — run: tmux kill-server && tmux"
    else
      tmux kill-server 2>/dev/null || true
      sub "killed stale tmux server"
    fi
  fi
}

# ─── selection from args (non-interactive) ──────────────────────────────────
if [ $# -gt 0 ]; then
  for ((i=0;i<N_ITEMS;i++)); do SEL[i]=0; done
  for arg in "$@"; do
    if [ "$arg" = all ]; then for ((i=0;i<N_ITEMS;i++)); do SEL[i]=1; done; continue; fi
    for ((i=0;i<N_ITEMS;i++)); do [ "$(key_of "$i")" = "$arg" ] && SEL[i]=1; done
  done
else
  menu
fi

# ─── run ────────────────────────────────────────────────────────────────────
any=0
for ((i=0;i<N_ITEMS;i++)); do
  [ "${SEL[i]}" = 1 ] || continue
  any=1
  "install_$(key_of "$i")"
done

if [ "$any" = 0 ]; then printf '\n%snothing selected.%s\n' "$D" "$N"; exit 0; fi

printf '\n%s::%s %sdone%s  %s· source ~/.zshrc · restart VS Code · run pi/opencode%s\n\n' \
  "$A" "$N" "$B" "$N" "$D" "$N"
