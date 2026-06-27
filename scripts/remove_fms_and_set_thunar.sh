#!/usr/bin/env bash
set -euo pipefail

# Script to remove other file managers and ensure Thunar is default
# Usage: ./remove_fms_and_set_thunar.sh

PACKAGES=(pcmanfm-qt nautilus libfm-qt)
LOG="$HOME/remove_fms_and_set_thunar.log"

echo "Log: $LOG"
echo "Starting removal helper at $(date)" | tee -a "$LOG"

echo
echo "1) Showing pacman dry-run (what would be removed):"
pacman -Rns --print "${PACKAGES[@]}" 2>&1 | tee -a "$LOG" || true

read -r -p $'\nIf the removals above look safe, type YES to continue with actual removal: ' CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  echo "Aborting. No packages were removed." | tee -a "$LOG"
  exit 0
fi

echo "Running removal..." | tee -a "$LOG"
sudo pacman -Rns "${PACKAGES[@]}" | tee -a "$LOG"

echo
echo "2) Setting Thunar as default file manager (xdg-mime)" | tee -a "$LOG"
xdg-mime default Thunar.desktop inode/directory 2>&1 | tee -a "$LOG" || true

if command -v update-desktop-database >/dev/null 2>&1; then
  echo "Updating desktop database (local)..." | tee -a "$LOG"
  update-desktop-database "$HOME/.local/share/applications" 2>&1 | tee -a "$LOG" || true
fi

echo "Restarting xdg-desktop-portal user services" | tee -a "$LOG"
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland 2>&1 | tee -a "$LOG" || true

echo
echo "3) Fixing XDG user dirs and renaming lowercase folders if present" | tee -a "$LOG"
USERDIRS=(Downloads Documents)
for d in "downloads" "documents"; do
  lc="$HOME/$d"
  uc="$HOME/$(tr '[:lower:]' '[:upper:]' <<< ${d:0:1})${d:1}"
  # uc builds "Downloads" from "downloads"
  if [ -e "$lc" ] && [ ! -e "$uc" ]; then
    echo "Renaming $lc -> $uc" | tee -a "$LOG"
    mv -v "$lc" "$uc" 2>&1 | tee -a "$LOG" || true
  elif [ -e "$lc" ] && [ -e "$uc" ]; then
    echo "Both $lc and $uc exist. Skipping rename. Please resolve manually." | tee -a "$LOG"
  else
    echo "$lc not present, nothing to rename." | tee -a "$LOG"
  fi
done

echo "Running xdg-user-dirs-update" | tee -a "$LOG"
xdg-user-dirs-update 2>&1 | tee -a "$LOG" || true

echo
echo "4) Verification" | tee -a "$LOG"
echo "xdg-mime query default inode/directory: $(xdg-mime query default inode/directory 2>/dev/null || true)" | tee -a "$LOG"

echo "Attempting to open $HOME with xdg-open (this should launch Thunar)" | tee -a "$LOG"
xdg-open "$HOME" >/dev/null 2>&1 || true
sleep 1
echo "Processes matching Thunar (pgrep -af thunar):" | tee -a "$LOG"
pgrep -af thunar 2>&1 | tee -a "$LOG" || true

echo
echo "Done. See $LOG for full output." | tee -a "$LOG"

exit 0
