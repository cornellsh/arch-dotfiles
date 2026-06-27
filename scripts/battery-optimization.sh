# Battery optimization script for ASUS Zenbook UX5401ZA
# Run with: sudo ./battery-optimization.sh

set -e

echo "=== ASUS Zenbook Battery Optimization ==="
echo ""

# Phase 1: Immediate optimizations (no reboot)
echo "[1/4] Applying immediate optimizations..."

# Switch TLP to power-saver mode
echo "  - Switching TLP to power-saver mode"
tlp power-saver

# Stop and disable Docker (not needed for watching movies)
echo "  - Stopping Docker service"
systemctl stop docker
systemctl disable docker

# Apply TLP settings immediately
echo "  - Applying TLP settings"
tlp start

# Phase 2: Backup current bootloader config
echo ""
echo "[2/4] Backing up bootloader configuration..."
cp /boot/loader/entries/2025-10-11_21-51-12_linux.conf /boot/loader/entries/2025-10-11_21-51-12_linux.conf.backup

# Phase 3: Apply TLP configuration
echo ""
echo "[3/4] Applying TLP configuration..."

# Create TLP drop-in config
cat > /etc/tlp.d/99-battery-optimization.conf <<'EOF'
# CPU scaling governor (optimized for battery)
CPU_SCALING_GOVERNOR_ON_AC=schedutil
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_SCALING_GOVERNOR_ON_SAV=powersave

# CPU energy performance policy
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_ENERGY_PERF_POLICY_ON_SAV=power

# CPU performance limits
CPU_MIN_PERF_ON_AC=10
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=10
CPU_MAX_PERF_ON_BAT=60
CPU_MIN_PERF_ON_SAV=10
CPU_MAX_PERF_ON_SAV=40

# Disable turbo boost on battery
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_BOOST_ON_SAV=0

# Disable HWP dynamic boost on battery
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0
CPU_HWP_DYN_BOOST_ON_SAV=0

# Platform profile
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power
PLATFORM_PROFILE_ON_SAV=low-power

# Intel GPU limits
INTEL_GPU_MAX_FREQ_ON_AC=0
INTEL_GPU_MAX_FREQ_ON_BAT=1200
INTEL_GPU_MAX_FREQ_ON_SAV=900

# Wi-Fi power saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Audio power saving
SOUND_POWER_SAVE_ON_AC=1
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y

# PCIe ASPM (more aggressive on battery)
PCIE_ASPM_ON_AC=powersave
PCIE_ASPM_ON_BAT=powersupersave

# Runtime PM
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# USB autosuspend
USB_AUTOSUSPEND=1
EOF

echo "  - TLP configuration written"

# Phase 4: Update kernel cmdline (requires reboot)
echo ""
echo "[4/4] Updating kernel cmdline for battery optimization..."
echo "  - Enabling deep C-states (removing processor.max_cstate=1)"
echo "  - Enabling Intel Panel Self Refresh (i915.enable_psr=1)"
echo "  - Enabling NVMe power saving (nvme_core.default_ps_max_latency_us=2000)"
echo ""

cat > /boot/loader/entries/2025-10-11_21-51-12_linux.conf <<'EOF'
# Created by: archinstall
# Created on: 2025-10-11_21-51-12
# Modified for ASUS Zenbook UX5401Z battery optimization - 2026-02-18
title   Arch Linux (linux)
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=PARTUUID=72b6db4d-4dd0-4caa-b90b-a2031f1cfbf8:root root=/dev/mapper/root zswap.enabled=0 rw rootfstype=ext4 acpi_osi=Linux nowatchdog nmi_watchdog=0 i915.enable_guc=3 i915.enable_fbc=1 i915.enable_psr=1 i915.modeset=1 nvme_core.default_ps_max_latency_us=2000 pcie_aspm.policy=powersupersave intel_iommu=on transparent_hugepage=always
EOF

echo "  - Bootloader configuration updated"
echo ""

echo "=== Optimization Complete ==="
echo ""
echo "What has been done:"
echo "  ✓ TLP switched to power-saver mode"
echo "  ✓ Docker service stopped and disabled"
echo "  ✓ TLP configuration optimized for battery"
echo "  ✓ Kernel cmdline updated for power efficiency"
echo ""
echo "What you need to do:"
echo "  1. REBOOT to apply kernel cmdline changes"
echo "  2. After reboot, TLP will automatically use battery-optimized settings"
echo ""
echo "Optional adjustments:"
echo "  - Adjust brightness: brightnessctl set 15-25%"
echo "  - Switch between modes: tlp performance/balanced/power-saver"
echo "  - Check status: tlp-stat -s"
echo ""
echo "To revert kernel changes:"
echo "  sudo cp /boot/loader/entries/2025-10-11_21-51-12_linux.conf.backup /boot/loader/entries/2025-10-11_21-51-12_linux.conf"
