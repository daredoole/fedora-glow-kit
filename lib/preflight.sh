#!/usr/bin/env bash
# Fresh-install hardware readiness reminder.

fedora_hardware_preflight() {
  [ "${FEDORA_PLASMA_GLOW_PREFLIGHT_ACK:-}" = "1" ] && return 0

  if [ -n "${FEDORA_PLASMA_GLOW_ASSUME:-}" ]; then
    ui_section "Fresh Install Preflight" 2>/dev/null || printf '\nFresh Install Preflight\n'
    ui_warn "Before applying this kit on new hardware, update Fedora, check firmware updates, reboot, then rerun setup." 2>/dev/null || true
    export FEDORA_PLASMA_GLOW_PREFLIGHT_ACK=1
    return 0
  fi

  ui_section "Fresh Install Preflight" 2>/dev/null || printf '\nFresh Install Preflight\n'
  printf 'For best hardware support, especially on new laptops or AMD APUs/GPUs, update Fedora packages, firmware metadata, and reboot into the newest kernel before applying customization.\n\n'

  if command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | grep -Eiq 'AMD|ATI|Radeon'; then
    ui_info "AMD graphics hardware appears present; kernel, Mesa, and linux-firmware updates matter here." 2>/dev/null || true
  fi

  if ask "Have you run Fedora updates, checked firmware updates, and rebooted if needed?" "n"; then
    export FEDORA_PLASMA_GLOW_PREFLIGHT_ACK=1
    return 0
  fi

  cat <<'EOF'
Recommended first-run prep:

  sudo dnf upgrade --refresh
  sudo fwupdmgr refresh --force
  sudo fwupdmgr get-updates
  sudo fwupdmgr update
  reboot

After reboot, confirm the running kernel with:

  uname -r
EOF

  if ! ask "Continue setup without completing that prep?" "y"; then
    printf 'Stopping before making kit changes. Re-run setup after updates and reboot.\n'
    exit 1
  fi

  export FEDORA_PLASMA_GLOW_PREFLIGHT_ACK=1
}
