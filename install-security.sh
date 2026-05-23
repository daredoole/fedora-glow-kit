#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNF="${DNF:-dnf}"
CHANGED=()
SKIPPED=()
STATE_DIR="$HOME/.local/state/fedora-plasma-glow-kit"
STATE_FILE="$STATE_DIR/install.state"

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
ui_intro 2>/dev/null || true
ui_title "Fedora Plasma Glow Kit Security" 2>/dev/null || echo "Fedora Plasma Glow Kit Security"

ask() {
  local prompt="$1" default="${2:-n}" reply
  case "${FEDORA_PLASMA_GLOW_ASSUME:-}" in
    yes|YES|y|Y|true|TRUE|1) return 0 ;;
    no|NO|n|N|false|FALSE|0) return 1 ;;
  esac
  read -r -p "$prompt [$default] " reply || true
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

record_state() {
  local key="$1" value="$2"
  mkdir -p "$STATE_DIR"
  grep -Fqx "$key=$value" "$STATE_FILE" 2>/dev/null || printf '%s=%s\n' "$key" "$value" >> "$STATE_FILE"
}

install_security_packages() {
  local pkgs=(firewalld policycoreutils policycoreutils-python-utils setroubleshoot-server fwupd dnf-automatic usbguard) pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "$DNF" install -y "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
}

ui_section "Current posture" 2>/dev/null || true
command_exists getenforce && ui_info "SELinux: $(getenforce)" 2>/dev/null || true
command_exists firewall-cmd && ui_info "firewalld: $(firewall-cmd --state 2>/dev/null || echo unavailable)" 2>/dev/null || true
command_exists firewall-cmd && ui_info "firewalld zone: $(firewall-cmd --get-default-zone 2>/dev/null || echo unknown)" 2>/dev/null || true

if ask "Install practical Fedora security tools?" "y"; then
  install_security_packages
  CHANGED+=("installed security tools")
fi

if ask "Enable and start firewalld?" "y"; then
  sudo systemctl enable --now firewalld
  CHANGED+=("enabled firewalld")
fi

if command_exists getenforce && [ "$(getenforce)" != "Enforcing" ]; then
  if ask "Set SELinux enforcing for this boot?" "n"; then
    sudo setenforce 1
    CHANGED+=("set SELinux enforcing for current boot")
  fi
fi

if ask "Enable fwupd refresh timer for firmware update checks?" "y"; then
  sudo systemctl enable --now fwupd-refresh.timer || true
  CHANGED+=("enabled fwupd refresh timer")
fi

if ask "Enable dnf-automatic timer for update notifications/download policy?" "n"; then
  sudo systemctl enable --now dnf-automatic.timer
  CHANGED+=("enabled dnf-automatic timer")
fi

if ask "Generate a USBGuard policy for manual review? This does not enable USB blocking." "n"; then
  if command_exists usbguard; then
    sudo usbguard generate-policy | sudo tee /etc/usbguard/rules.conf >/dev/null
    CHANGED+=("generated USBGuard policy at /etc/usbguard/rules.conf")
  else
    SKIPPED+=("usbguard command unavailable")
  fi
fi

echo
ui_title "Security Summary" 2>/dev/null || echo "Security summary"
printf 'Changed:\n'; printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'; printf '  - %s\n' "${SKIPPED[@]:-(none)}"
