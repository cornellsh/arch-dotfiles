#!/bin/bash
# arch-dotfiles - Interactive Install Script
# Toggle which components to install

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Menu items: label|description|default
ITEMS=(
    "Shell configs|.zshrc, .bashrc, .profile, .gitconfig, .p10k.zsh + OMZ/plugins|1"
    "App configs|niri, waybar, DankMaterialShell|1"
    "Systemd|webcam service|1"
    "Scripts|~/scripts, ~/.local/bin|1"
    "VS Code|settings, keybindings, extensions|1"
    "OpenCode|config, plugins, themes, skills|1"
    "Tmux|.tmux.conf|1"
)

# Selection state (parallel array)
SELECTED=()
for item in "${ITEMS[@]}"; do
    SELECTED+=("${item##*|}")
done

CURSOR=0
N=${#ITEMS[@]}

draw_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         arch-dotfiles - Interactive Install      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}↑/↓${NC} or ${YELLOW}j/k${NC}: navigate   ${YELLOW}space${NC}: toggle   ${YELLOW}a${NC}: all   ${YELLOW}n${NC}: none   ${GREEN}enter${NC}: start   ${RED}q${NC}: quit"
    echo ""

    for i in "${!ITEMS[@]}"; do
        IFS='|' read -r label desc _ <<< "${ITEMS[$i]}"
        local mark
        if [ "${SELECTED[$i]}" = "1" ]; then
            mark="${GREEN}[✓]${NC}"
        else
            mark="${RED}[ ]${NC}"
        fi
        if [ "$i" = "$CURSOR" ]; then
            printf "  ${BLUE}▶${NC} ${mark} %-16s ${YELLOW}%s${NC}\n" "$label" "($desc)"
        else
            printf "    ${mark} %-16s %s\n" "$label" "($desc)"
        fi
    done
    echo ""
}

set_all() {
    local val="$1"
    for i in "${!SELECTED[@]}"; do
        SELECTED[$i]="$val"
    done
}

# Hide cursor; restore on exit
tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null || true' EXIT

while true; do
    draw_menu

    # Read one byte; arrow keys send ESC [ A/B/C/D
    IFS= read -rsn1 key
    if [ "$key" = $'\x1b' ]; then
        IFS= read -rsn2 -t 0.01 rest || rest=""
        key="$key$rest"
    fi

    case "$key" in
        $'\x1b[A'|k) (( CURSOR > 0 )) && CURSOR=$((CURSOR - 1)) ;;
        $'\x1b[B'|j) (( CURSOR < N - 1 )) && CURSOR=$((CURSOR + 1)) ;;
        ' ')
            if [ "${SELECTED[$CURSOR]}" = "1" ]; then
                SELECTED[$CURSOR]=0
            else
                SELECTED[$CURSOR]=1
            fi
            ;;
        a|A) set_all 1 ;;
        n|N) set_all 0 ;;
        q|Q) tput cnorm 2>/dev/null || true; echo ""; exit 0 ;;
        '') break ;;  # Enter
    esac
done

tput cnorm 2>/dev/null || true

# Map selections back to legacy variables used below
_shell="${SELECTED[0]}"
_config="${SELECTED[1]}"
_systemd="${SELECTED[2]}"
_scripts="${SELECTED[3]}"
_vscode="${SELECTED[4]}"
_opencode="${SELECTED[5]}"
_tmux="${SELECTED[6]}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo "Starting install..."
echo ""

# ============================================
# Shell
# ============================================
if [ "$_shell" = "1" ]; then
    echo "[*] Restoring shell configs..."
    cp .zshrc ~/ 2>/dev/null || true
    cp .bashrc ~/ 2>/dev/null || true
    cp .profile ~/ 2>/dev/null || true
    cp .gitconfig ~/ 2>/dev/null || true
    cp .p10k.zsh ~/ 2>/dev/null || true
    echo "    ✓ Shell configs restored"

    # Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "    Installing Oh My Zsh..."
        RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
        echo "    ✓ Oh My Zsh installed"
    else
        echo "    ✓ Oh My Zsh already present"
    fi

    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # zsh-autosuggestions plugin
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        echo "    Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
        echo "    ✓ zsh-autosuggestions installed"
    fi

    # powerlevel10k theme (installed but not active by default; available if user switches theme)
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        echo "    Installing powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" 2>/dev/null || true
        echo "    ✓ powerlevel10k installed"
    fi
fi

# ============================================
# App Configs
# ============================================
if [ "$_config" = "1" ]; then
    echo "[*] Restoring app configs..."
    mkdir -p ~/.config
    cp -r config/* ~/.config/ 2>/dev/null || true
    echo "    ✓ App configs restored"
fi

# ============================================
# Systemd
# ============================================
if [ "$_systemd" = "1" ]; then
    echo "[*] Restoring systemd services..."
    mkdir -p ~/.config/systemd/user
    cp -r systemd/user/* ~/.config/systemd/user/ 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    echo "    ✓ Systemd services restored"
fi

# ============================================
# Scripts
# ============================================
if [ "$_scripts" = "1" ]; then
    echo "[*] Restoring scripts..."
    mkdir -p ~/scripts
    mkdir -p ~/.local/bin
    cp -r scripts/* ~/scripts/ 2>/dev/null || true
    cp -r local-bin/* ~/.local/bin/ 2>/dev/null || true
    chmod +x ~/scripts/* 2>/dev/null || true
    chmod +x ~/.local/bin/* 2>/dev/null || true
    echo "    ✓ Scripts restored"
fi

# ============================================
# VS Code
# ============================================
if [ "$_vscode" = "1" ]; then
    echo "[*] Restoring VS Code..."
    mkdir -p ~/.config/Code/User
    cp vscode/settings.json ~/.config/Code/User/ 2>/dev/null || true
    cp vscode/keybindings.json ~/.config/Code/User/ 2>/dev/null || true
    cp vscode/mcp.json ~/.config/Code/User/ 2>/dev/null || true
    cp -r vscode/snippets ~/.config/Code/User/ 2>/dev/null || true
    
    echo "    ✓ VS Code settings restored"
    echo "    Installing extensions..."
    while IFS= read -r ext; do
        [[ -z "$ext" ]] && continue
        [[ "$ext" == *"{"* ]] && continue
        code --install-extension "$ext" --force 2>/dev/null || true
    done < vscode/extensions-list.txt
    echo "    ✓ VS Code extensions installed"
fi

# ============================================
# OpenCode
# ============================================
if [ "$_opencode" = "1" ]; then
    echo "[*] Installing OpenCode..."
    mkdir -p ~/.config/opencode ~/.config/opencode/.ocx
    cp opencode/opencode.json ~/.config/opencode/
    cp opencode/package.json ~/.config/opencode/
    cp opencode/dcp.jsonc ~/.config/opencode/ 2>/dev/null || true
    cp opencode/ocx.jsonc ~/.config/opencode/ 2>/dev/null || true
    cp opencode/.gitignore ~/.config/opencode/ 2>/dev/null || true
    mkdir -p ~/.config/opencode/themes
    cp -r opencode/themes/. ~/.config/opencode/themes/ 2>/dev/null || true

    # OCX-managed plugins (e.g. kdco/worktree). These are TypeScript files
    # that OpenCode auto-loads from the plugins/ directory. The receipt
    # records SHA-256 hashes so `ocx verify` can check integrity later.
    if [ -d opencode/plugins ]; then
        mkdir -p ~/.config/opencode/plugins
        cp -r opencode/plugins/. ~/.config/opencode/plugins/
    fi
    if [ -f opencode/.ocx/receipt.jsonc ]; then
        cp opencode/.ocx/receipt.jsonc ~/.config/opencode/.ocx/
    fi

    # Install plugins pinned in package.json. The auth plugins
    # (opencode-claude-auth, opencode-gemini-auth) are also resolved by
    # OpenCode at runtime, but pinning them here keeps versions reproducible.
    cd ~/.config/opencode
    if command -v bun >/dev/null 2>&1; then
        bun install 2>/dev/null || true
    else
        npm install 2>/dev/null || true
    fi
    cd "$SCRIPT_DIR"

    # OCX CLI manages registry-installed plugins (kdco/worktree, etc.).
    # Install it globally if missing so `ocx update` / `ocx verify` work.
    if ! command -v ocx >/dev/null 2>&1; then
        if command -v bun >/dev/null 2>&1; then
            echo "    Installing ocx CLI (manages worktree and other registry plugins)..."
            bun add -g ocx 2>/dev/null || true
        elif command -v npm >/dev/null 2>&1; then
            npm install -g ocx 2>/dev/null || true
        fi
    fi

    # opencode-snip prefixes shell commands with the `snip` binary to cut
    # tokens. If it's missing the plugin would break every bash call.
    if ! command -v snip >/dev/null 2>&1; then
        if command -v go >/dev/null 2>&1; then
            echo "    Installing snip CLI (required by opencode-snip)..."
            go install github.com/edouard-claude/snip/cmd/snip@latest 2>/dev/null || true
            # Make sure GOBIN ends up on PATH for future sessions.
            GOBIN_DIR="$(go env GOBIN 2>/dev/null)"
            [ -z "$GOBIN_DIR" ] && GOBIN_DIR="$(go env GOPATH 2>/dev/null)/bin"
            if [ -x "$GOBIN_DIR/snip" ]; then
                echo "    ✓ snip installed to $GOBIN_DIR/snip"
            else
                echo "    ! snip install failed; opencode-snip will be a no-op"
            fi
        else
            echo "    ! Go not installed; skipping snip CLI (install go and rerun)"
        fi
    fi

    echo "    ✓ OpenCode config installed"

    echo "    Installing skills..."
    mkdir -p ~/.agents/skills
    cp -r agents/skills/. ~/.agents/skills/ 2>/dev/null || true
    find ~/.agents/skills -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
    echo "    ✓ Skills installed"
fi

# ============================================
# Tmux
# ============================================
if [ "$_tmux" = "1" ]; then
    echo "[*] Installing tmux config..."
    # Remove any existing file/symlink first (handles broken symlinks pointing
    # to paths that only exist on the source machine).
    rm -f ~/.tmux.conf 2>/dev/null || true
    cp .tmux.conf ~/.tmux.conf
    # Mirror to XDG location so tmux finds it regardless of which path it
    # checks first.
    mkdir -p ~/.config/tmux
    rm -f ~/.config/tmux/tmux.conf 2>/dev/null || true
    cp .tmux.conf ~/.config/tmux/tmux.conf

    # tmux only reads the config when the server starts. If a server is
    # already running (e.g. you ran install.sh from inside tmux, or there's
    # a detached session from before), attaching to it gives you the OLD
    # config. Kill the server so the next `tmux` invocation reloads fresh.
    if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
        echo "    ! tmux server is running with the old config."
        if [ -n "$TMUX" ]; then
            echo "    ! You're inside tmux right now -- detach and run:"
            echo "    !     tmux kill-server && tmux"
        else
            tmux kill-server 2>/dev/null || true
            echo "    ✓ Killed running tmux server (start a new one with: tmux)"
        fi
    fi

    echo "    ✓ Tmux config installed"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Install Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  - Restart shell: source ~/.zshrc"
echo "  - Restart VS Code"
echo "  - Run 'opencode'"
echo ""
