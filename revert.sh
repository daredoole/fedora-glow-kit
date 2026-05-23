#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECTION="${1:-all}"
DNF="${DNF:-dnf}"
STATE_FILE="$HOME/.local/state/fedora-starter-kit/install.state"
CHANGED=()
SKIPPED=()

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
ui_title "Fedora Glow Kit Revert" 2>/dev/null || echo "Fedora Glow Kit Revert"

ask() {
  local prompt="$1" default="${2:-n}" reply
  read -r -p "$prompt [$default] " reply || true
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]
}

remove_if_matches() {
  local src="$1" target="$2"
  [ -e "$target" ] || { SKIPPED+=("missing $target"); return; }
  if [ -f "$src" ] && [ -f "$target" ] && cmp -s "$src" "$target"; then
    rm -f "$target"
    CHANGED+=("removed $target")
  elif ask "$target differs from kit copy. Remove anyway?" "n"; then
    rm -rf "$target"
    CHANGED+=("removed differing $target")
  else
    SKIPPED+=("left $target")
  fi
}

restore_latest_backup() {
  local target="$1" latest
  latest="$(find "$(dirname "$target")" -maxdepth 1 -name "$(basename "$target").bak.*" -type f 2>/dev/null | sort | tail -n 1 || true)"
  [ -n "$latest" ] || { SKIPPED+=("no backup for $target"); return; }
  if ask "Restore $latest to $target?" "y"; then
    cp -a "$latest" "$target"
    CHANGED+=("restored $target from backup")
  fi
}

remove_recorded_npm() {
  [ -f "$STATE_FILE" ] || { SKIPPED+=("no install state file for npm removals"); return; }
  grep '^npm=' "$STATE_FILE" | cut -d= -f2- | while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if ask "Uninstall npm package recorded by kit: $pkg?" "n"; then
      npm uninstall -g "$pkg"
    fi
  done
}

remove_recorded_dnf() {
  [ -f "$STATE_FILE" ] || { SKIPPED+=("no install state file for DNF removals"); return; }
  grep '^dnf=' "$STATE_FILE" | cut -d= -f2- | while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if ask "Remove DNF package recorded as installed by kit: $pkg?" "n"; then
      sudo dnf remove -y "$pkg"
    fi
  done
}

remove_recorded_flatpak() {
  [ -f "$STATE_FILE" ] || { SKIPPED+=("no install state file for Flatpak removals"); return; }
  grep '^flatpak=' "$STATE_FILE" | cut -d= -f2- | while IFS= read -r app; do
    [ -n "$app" ] || continue
    if ask "Uninstall Flatpak recorded as installed by kit: $app?" "n"; then
      flatpak uninstall -y "$app"
    fi
  done
}

remove_recorded_copr() {
  [ -f "$STATE_FILE" ] || { SKIPPED+=("no install state file for COPR removals"); return; }
  grep '^copr=' "$STATE_FILE" | cut -d= -f2- | while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    if ask "Disable COPR recorded as enabled by kit: $repo?" "n"; then
      sudo "$DNF" -y copr remove "$repo"
    fi
  done
}

revert_core() {
  ui_section "Core configs" 2>/dev/null || true
  remove_if_matches "$ROOT_DIR/shell/aliases.sh" "$HOME/.config/shell/aliases.sh"
  remove_if_matches "$ROOT_DIR/shell/functions.sh" "$HOME/.config/shell/functions.sh"
  remove_if_matches "$ROOT_DIR/configs/starship.toml" "$HOME/.config/starship.toml"
  remove_if_matches "$ROOT_DIR/configs/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
  remove_if_matches "$ROOT_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  remove_if_matches "$ROOT_DIR/configs/fastfetch/dog.png" "$HOME/.config/fastfetch/dog.png"
  restore_latest_backup "$HOME/.zshrc"
  [ -f "$HOME/.bashrc" ] && restore_latest_backup "$HOME/.bashrc"
}

revert_kde() {
  ui_section "KDE configs" 2>/dev/null || true
  remove_if_matches "$ROOT_DIR/configs/konsole/FedoraStarter.profile" "$HOME/.local/share/konsole/FedoraStarter.profile"
  remove_if_matches "$ROOT_DIR/configs/konsole/Sweet-Starter.colorscheme" "$HOME/.local/share/konsole/Sweet-Starter.colorscheme"
  restore_latest_backup "$HOME/.config/kdeglobals"
  restore_latest_backup "$HOME/.config/kwinrc"
  restore_latest_backup "$HOME/.config/kglobalshortcutsrc"
}

revert_ai() {
  ui_section "AI CLI tools" 2>/dev/null || true
  remove_recorded_npm
}

case "$SECTION" in
  core) revert_core ;;
  kde) revert_kde ;;
  ai) revert_ai ;;
  extras) remove_recorded_dnf; remove_recorded_flatpak ;;
  security) remove_recorded_dnf ;;
  all) revert_core; revert_kde; revert_ai; remove_recorded_dnf; remove_recorded_flatpak; remove_recorded_copr ;;
  *) ui_warn "Unknown section: $SECTION" 2>/dev/null || true ;;
esac

echo
ui_title "Revert Summary" 2>/dev/null || echo "Revert summary"
printf 'Changed:\n'; printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'; printf '  - %s\n' "${SKIPPED[@]:-(none)}"
