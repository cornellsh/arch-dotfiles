#!/bin/bash
# Fix conflicting TLP configurations

echo "Disabling old TLP config files..."

# Disable old config files by renaming
mv /etc/tlp.d/99-optimization.conf /etc/tlp.d/99-optimization.conf.disabled 2>/dev/null
mv /etc/tlp.d/99-zenbook.conf /etc/tlp.d/99-zenbook.conf.disabled 2>/dev/null

echo "Old configs disabled."
echo ""
echo "Reloading TLP with correct configuration..."
tlp start

echo ""
echo "TLP configuration fixed!"
echo ""
echo "Run: tlp power-saver"
echo "Run: tlp-stat -p (to verify)"
