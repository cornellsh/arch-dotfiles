#!/bin/bash

check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "Installing $1..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update && sudo apt-get install -y $1
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S --noconfirm $1
        fi
    fi
}

echo "Starting config setup..."

check_dependency "git"
check_dependency "tmux"
check_dependency "zsh"
check_dependency "curl"
check_dependency "ghostty"

# Install Zsh plugins
if [ -f /etc/debian_version ]; then
    if ! dpkg -s zsh-autosuggestions &> /dev/null; then
        echo "Installing zsh-autosuggestions..."
        sudo apt-get install -y zsh-autosuggestions
    fi
    if ! dpkg -s zsh-syntax-highlighting &> /dev/null; then
        echo "Installing zsh-syntax-highlighting..."
        sudo apt-get install -y zsh-syntax-highlighting
    fi
elif [ -f /etc/arch-release ]; then
    if ! pacman -Qi zsh-autosuggestions &> /dev/null; then
        echo "Installing zsh-autosuggestions..."
        sudo pacman -S --noconfirm zsh-autosuggestions
    fi
    if ! pacman -Qi zsh-syntax-highlighting &> /dev/null; then
        echo "Installing zsh-syntax-highlighting..."
        sudo pacman -S --noconfirm zsh-syntax-highlighting
    fi
fi

# Install Starship
if ! command -v starship &> /dev/null; then
    echo "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

backup_and_link() {
    src="$1"
    dest="$2"
    filename=$(basename "$dest")

    mkdir -p "$(dirname "$dest")"

    if [ -f "$dest" ] || [ -L "$dest" ]; then
        if [ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]; then
            return
        fi

        echo "Backing up $filename to ${filename}.backup"
        mv "$dest" "${dest}.backup"
    fi

    echo "Linking $filename"
    ln -s "$src" "$dest"
}

CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

backup_and_link "$CONFIG_DIR/.tmux.conf" "$HOME/.tmux.conf"
backup_and_link "$CONFIG_DIR/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
backup_and_link "$CONFIG_DIR/.zshrc" "$HOME/.zshrc"
backup_and_link "$CONFIG_DIR/starship.toml" "$HOME/.config/starship.toml"

# Ghostty configuration
echo "Configuring Ghostty..."
mkdir -p "$HOME/.config/ghostty/themes"
backup_and_link "$CONFIG_DIR/ghostty/config" "$HOME/.config/ghostty/config"
backup_and_link "$CONFIG_DIR/ghostty/themes/cornellsh" "$HOME/.config/ghostty/themes/cornellsh"

# DankMaterialShell configuration
echo "Configuring DankMaterialShell..."
mkdir -p "$HOME/.config/DankMaterialShell"
mkdir -p "$HOME/Documents/DankMaterialShell"
backup_and_link "$CONFIG_DIR/dankmaterialshell/settings.json" "$HOME/.config/DankMaterialShell/settings.json"
cp "$CONFIG_DIR/dankmaterialshell/cornellsh.json" "$HOME/Documents/DankMaterialShell/cornellsh.json"

# OpenCode configuration
if [ -f "$CONFIG_DIR/opencode.json" ]; then
    read -p "Install OpenCode? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$HOME/.config/opencode/themes"

        if [ -f "$CONFIG_DIR/.opencode/themes/cornell.sh.json" ]; then
            cp "$CONFIG_DIR/.opencode/themes/cornell.sh.json" "$HOME/.config/opencode/themes/cornell.sh.json"
        fi

        if [ -f "$HOME/.config/opencode/opencode.json" ]; then
            mv "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/opencode.json.backup"
        fi

        cp "$CONFIG_DIR/opencode.json" "$HOME/.config/opencode/opencode.json"
    fi
fi
        
        echo -e "${YELLOW}[WARN] Backing up existing $filename to ${filename}.backup${NC}"
        mv "$dest" "${dest}.backup"
    fi

    echo -e "${BLUE}[INFO] Linking $filename...${NC}"
    ln -s "$src" "$dest"
}

# Get the directory where this script is located
CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 4. Perform Links
backup_and_link "$CONFIG_DIR/.tmux.conf" "$HOME/.tmux.conf"
backup_and_link "$CONFIG_DIR/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
backup_and_link "$CONFIG_DIR/.zshrc" "$HOME/.zshrc"
backup_and_link "$CONFIG_DIR/starship.toml" "$HOME/.config/starship.toml"

# 4.1. Ghostty Configuration
echo -e "\n${BLUE}[INFO] Configuring Ghostty terminal...${NC}"
mkdir -p "$HOME/.config/ghostty/themes"

backup_and_link "$CONFIG_DIR/ghostty/config" "$HOME/.config/ghostty/config"
backup_and_link "$CONFIG_DIR/ghostty/themes/cornellsh" "$HOME/.config/ghostty/themes/cornellsh"

# 4.2. DankMaterialShell Configuration
echo -e "\n${BLUE}[INFO] Configuring DankMaterialShell...${NC}"
mkdir -p "$HOME/.config/DankMaterialShell"
mkdir -p "$HOME/Documents/DankMaterialShell" # For custom theme file

backup_and_link "$CONFIG_DIR/dankmaterialshell/settings.json" "$HOME/.config/DankMaterialShell/settings.json"
cp "$CONFIG_DIR/dankmaterialshell/cornellsh.json" "$HOME/Documents/DankMaterialShell/cornellsh.json"
echo -e "${GREEN}[OK] DankMaterialShell custom theme copied.${NC}"

# 5. OpenCode Configuration (optional)
if [ -f "$CONFIG_DIR/opencode.json" ]; then
    echo -e "\n${BLUE}[INFO] OpenCode config found.${NC}"
    read -p "Install OpenCode theme and config? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$HOME/.config/opencode/themes"

        if [ -f "$CONFIG_DIR/.opencode/themes/cornell.sh.json" ]; then
            cp "$CONFIG_DIR/.opencode/themes/cornell.sh.json" "$HOME/.config/opencode/themes/cornell.sh.json"
            echo -e "${GREEN}[OK] OpenCode theme installed${NC}"
        fi

        if [ -f "$HOME/.config/opencode/opencode.json" ]; then
            mv "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/opencode.json.backup"
            echo -e "${YELLOW}[WARN] Backed up existing opencode.json${NC}"
        fi

        cp "$CONFIG_DIR/opencode.json" "$HOME/.config/opencode/opencode.json"
        echo -e "${GREEN}[OK] OpenCode config installed${NC}"
    fi
fi

# WSL setup
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
    read -p "Apply WSL2 optimizations? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$CONFIG_DIR/wsl-setup.sh"
    fi
fi

# Theme setup
if [ -f "$CONFIG_DIR/themes-setup.sh" ]; then
    read -p "Install GTK/SDDM themes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$CONFIG_DIR/themes-setup.sh"
    fi
fi

echo "Setup complete"
echo "Run 'source ~/.zshrc' to apply changes"
