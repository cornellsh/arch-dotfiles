# Fixed TLP battery optimization configuration for ASUS Zenbook UX5401ZA

# CPU scaling governor (only performance/powersave available)
CPU_SCALING_GOVERNOR_ON_AC=performance
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

# Intel GPU limits (only max frequency needed)
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
