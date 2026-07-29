#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNF="${DNF:-dnf}"
CHANGED=()
SKIPPED=()

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/lib/state.sh" ] && . "$ROOT_DIR/lib/state.sh"
# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/lib/preflight.sh" ] && . "$ROOT_DIR/lib/preflight.sh"

ui_intro 2> /dev/null || true
ui_title "Fedora Glow Kit GNOME" 2> /dev/null || echo "Fedora Glow Kit GNOME"
fedora_hardware_preflight

ask() {
  local prompt="$1" default="${2:-n}" reply
  case "${FEDORA_PLASMA_GLOW_ASSUME:-}" in
    yes | YES | y | Y | true | TRUE | 1) return 0 ;;
    no | NO | n | N | false | FALSE | 0) return 1 ;;
  esac
  read -r -p "$prompt [$default] " reply || true
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]
}

install_gnome_packages() {
  local packages=(gnome-tweaks gnome-extensions-app gnome-shell-extension-appindicator papirus-icon-theme)
  local package new_packages=()
  for package in "${packages[@]}"; do
    rpm -q "$package" > /dev/null 2>&1 || new_packages+=("$package")
  done
  dnf_install_tracked "$DNF" install -y "${packages[@]}"
  for package in "${new_packages[@]}"; do
    if rpm -q "$package" >/dev/null 2>&1; then
      record_state dnf "$package"
    else
      SKIPPED+=("$package unavailable from enabled repositories")
    fi
  done
  CHANGED+=("installed GNOME polish packages")
}

setting_exists() {
  local schema="$1" key="$2"
  gsettings list-keys "$schema" 2> /dev/null | grep -Fqx "$key"
}

set_gnome_setting() {
  local schema="$1" key="$2" value="$3" current encoded
  if ! setting_exists "$schema" "$key"; then
    SKIPPED+=("GNOME setting unavailable: $schema $key")
    return
  fi
  current="$(gsettings get "$schema" "$key")"
  if [ "$current" = "$value" ]; then
    SKIPPED+=("GNOME setting already applied: $schema $key")
    return
  fi
  if ! state_values_for_section gnome gsetting | grep -Fq "$schema|$key|"; then
    encoded="$(printf '%s' "$current" | base64 --wrap=0)"
    record_state gsetting "$schema|$key|$encoded"
  fi
  gsettings set "$schema" "$key" "$value"
  CHANGED+=("set GNOME setting $schema $key")
}

if ask "Install GNOME Tweaks, Extensions, AppIndicator support, and Papirus icons?" "y"; then
  install_gnome_packages
else
  SKIPPED+=("GNOME polish packages")
fi

if command -v gsettings > /dev/null 2>&1 && ask "Apply the reversible Fedora Glow appearance profile?" "y"; then
  set_gnome_setting org.gnome.desktop.interface color-scheme "'prefer-dark'"
  set_gnome_setting org.gnome.desktop.interface icon-theme "'Papirus-Dark'"
  set_gnome_setting org.gnome.desktop.interface clock-show-weekday true
  set_gnome_setting org.gnome.desktop.wm.preferences button-layout "'appmenu:minimize,maximize,close'"
else
  SKIPPED+=("GNOME appearance profile")
fi

if command -v gnome-extensions > /dev/null 2>&1 &&
  ask "Enable AppIndicator tray support for this GNOME account?" "n"; then
  extension="appindicatorsupport@rgcjonas.gmail.com"
  if ! gnome-extensions info "$extension" 2> /dev/null | grep -Fq "State: ENABLED"; then
    if gnome-extensions enable "$extension"; then
      record_state gnome_extension "$extension"
      CHANGED+=("enabled GNOME AppIndicator extension")
    else
      SKIPPED+=("AppIndicator requires a GNOME Shell restart or new login")
    fi
  else
    SKIPPED+=("GNOME AppIndicator extension already enabled")
  fi
fi

echo
ui_title "GNOME Summary" 2> /dev/null || echo "GNOME summary"
printf 'Changed:\n'
printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'
printf '  - %s\n' "${SKIPPED[@]:-(none)}"
