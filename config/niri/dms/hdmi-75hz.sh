#!/bin/bash
# Wayland-compatible script to add 75Hz mode for HDMI monitors

export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}

# Wait for niri to be ready
sleep 2

# Check niri availability
if ! niri msg outputs >/dev/null 2>&1; then
    exit 0
fi

# Try to set mode via niri if possible
niri msg outputs status 2>/dev/null | grep -q "HDMI-A-1" && {
    # niri handles this via config, nothing to do here for wayland
    exit 0
}