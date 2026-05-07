#!/bin/bash

# GTK and SDDM Theme Setup Script

echo "Starting GTK and SDDM theme setup..."

install_aur() {
    local package=$1
    if ! yay -Qi "$package" &> /dev/null; then
        echo "Installing $package from AUR..."
        yay -S --noconfirm "$package"
    fi
}

install_system() {
    local package=$1
    if ! pacman -Qi "$package" &> /dev/null; then
        echo "Installing $package..."
        sudo pacman -S --noconfirm "$package"
    fi
}

# Check for yay (AUR helper)
if ! command -v yay &> /dev/null; then
    echo "Error: yay is required for AUR packages. Install it first."
    exit 1
fi

# Install packages
echo "Installing Mojave GTK theme..."
install_aur "mojave-gtk-theme"

echo "Installing macOS cursors..."
install_aur "macos-tahoe-cursor"

echo "Installing Papirus icon theme..."
if ! pacman -Qi "papirus-icon-theme" &> /dev/null; then
    install_system "papirus-icon-theme"
fi

echo "Installing where-is-my-sddm-theme..."
install_aur "where-is-my-sddm-theme-git"

# Configure GTK settings
echo "Configuring GTK theme..."
gsettings set org.gnome.desktop.interface gtk-theme "Mojave-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme "macos-tahoe-cursor" 2>/dev/null || true

# Configure SDDM
if command -v sddm &> /dev/null; then
    echo "Configuring SDDM..."
    sudo mkdir -p /etc/sddm.conf.d/

    sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << 'EOF'
[Theme]
Current=where_is_my_sddm_theme
EOF

    if [ -f "/etc/sddm.conf.d/niri.conf" ] && grep -q "CompositorCommand=niri" /etc/sddm.conf.d/niri.conf; then
        echo "Removing CompositorCommand=niri from SDDM config..."
        sudo sed -i '/CompositorCommand=niri/d' /etc/sddm.conf.d/niri.conf
    fi
fi

# Optional nwg-look
if ! pacman -Qi "nwg-look" &> /dev/null; then
    read -p "Install nwg-look? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        yay -S --noconfirm "nwg-look"
    fi
fi

echo "Theme setup complete"
echo "Theme: Mojave-Dark GTK, Papirus-Dark icons, macOS-Tahoe cursor"
echo "SDDM: where-is-my-sddm-theme"
echo "Run 'nwg-look' to configure GTK themes"
echo "Run 'sudo systemctl restart sddm' to apply SDDM theme"
