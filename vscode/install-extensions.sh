#!/bin/bash
# Install VS Code Extensions
# Run this script on a new machine to restore all extensions

echo "Installing VS Code extensions..."

while IFS= read -r ext; do
    # Skip if line is empty or contains JSON
    if [[ -z "$ext" ]] || [[ "$ext" == *"{"* ]]; then
        continue
    fi
    echo "Installing: $ext"
    code --install-extension "$ext" --force 2>/dev/null || echo "Failed: $ext"
done < "extensions-list.txt"

echo "Done installing extensions!"
