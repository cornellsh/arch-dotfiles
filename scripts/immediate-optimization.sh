#!/bin/bash
# Immediate battery optimizations (no reboot required)
# Run with: sudo ./immediate-optimization.sh

set -e

echo "=== Immediate Battery Optimizations ==="
echo ""

# Switch TLP to power-saver mode
echo "Switching TLP to power-saver mode..."
tlp power-saver

# Stop and disable Docker
echo "Stopping Docker service..."
systemctl stop docker
systemctl disable docker

# Apply TLP settings
echo "Applying TLP battery profile..."
tlp start

# Set low brightness
echo "Setting display brightness to 20%..."
brightnessctl set 20%

echo ""
echo "=== Done ==="
echo ""
echo "These changes are now active but will be reset on reboot."
echo "Run ./battery-optimization.sh for permanent optimizations."
