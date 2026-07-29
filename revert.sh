#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECTION="${1:-all}"
DNF="${DNF:-dnf}"
CHANGED=()
SKIPPED=()

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/lib/state.sh" ] && . "$ROOT_DIR/lib/state.sh"
ui_title "Fedora Plasma Glow Kit Revert" 2>/dev/null || echo "Fedora Plasma Glow Kit Revert"

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

remove_if_matches() {
  local src="$1" target="$2"
  [ -e "$target" ] || {
    SKIPPED+=("missing $target")
    return
  }
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
  [ -n "$latest" ] || {
    SKIPPED+=("no backup for $target")
    return
  }
  if ask "Restore $latest to $target?" "y"; then
    cp -a "$latest" "$target"
    CHANGED+=("restored $target from backup")
  fi
}

recorded_values() {
  local section="$1" key="$2"
  if [ "$section" = "all" ]; then
    state_values "$key"
  else
    state_values_for_section "$section" "$key"
  fi
}

remove_recorded_npm() {
  local section="$1" pkg
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if ask "Uninstall npm package recorded by kit: $pkg?" "n"; then
      npm uninstall -g "$pkg"
      remove_managed_state "$section" npm "$pkg"
      CHANGED+=("removed npm package $pkg")
    fi
  done < <(recorded_values "$section" npm)
}

remove_recorded_dnf() {
  local section="$1" pkg before after approved_file cascaded_file
  local approved=() removed=() cascaded_packages=()
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if ask "Remove DNF package recorded as installed by kit: $pkg?" "n"; then
      if [ "$pkg" = "flatpak" ] && [ -n "$(state_values flatpak_remote)" ]; then
        SKIPPED+=("flatpak retained while a kit-managed remote is still present")
        continue
      fi
      if rpm -q "$pkg" >/dev/null 2>&1; then
        approved+=("$pkg")
      else
        SKIPPED+=("$pkg was already absent")
        remove_managed_state "$section" dnf "$pkg"
      fi
    fi
  done < <(recorded_values "$section" dnf)
  [ "${#approved[@]}" -gt 0 ] || return 0
  before="$(mktemp)"
  after="$(mktemp)"
  approved_file="$(mktemp)"
  cascaded_file="$(mktemp)"
  installed_package_names >"$before"
  printf '%s\n' "${approved[@]}" | sort -u >"$approved_file"
  sudo "$DNF" remove -y --no-autoremove "${approved[@]}"
  installed_package_names >"$after"
  comm -23 "$before" "$after" |
    grep -Fvx -f "$approved_file" >"$cascaded_file" || true
  if [ -s "$cascaded_file" ]; then
    mapfile -t cascaded_packages <"$cascaded_file"
    sudo "$DNF" install -y --allowerasing "${cascaded_packages[@]}"
    CHANGED+=("restored DNF packages removed as dependents: ${cascaded_packages[*]}")
  fi
  for pkg in "${approved[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      SKIPPED+=("$pkg could not be removed and remains managed")
    else
      removed+=("$pkg")
      CHANGED+=("removed DNF package $pkg")
    fi
  done
  remove_managed_states_bulk "$section" dnf "${removed[@]}"
  rm -f "$before" "$after" "$approved_file" "$cascaded_file"
}

restore_recorded_dnf() {
  local section="$1" pkg
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if ask "Restore DNF package replaced by the kit: $pkg?" "y"; then
      if ! rpm -q "$pkg" >/dev/null 2>&1; then
        sudo "$DNF" install -y --allowerasing "$pkg"
        # A replacement transaction can leave the restored package marked as a
        # dependency. Preserve it across future `dnf autoremove` runs.
        if ! sudo "$DNF" mark user "$pkg" >/dev/null 2>&1; then
          sudo "$DNF" mark install "$pkg" >/dev/null 2>&1 || true
        fi
        CHANGED+=("restored DNF package $pkg")
      fi
      remove_managed_state "$section" dnf_restore "$pkg"
    fi
  done < <(recorded_values "$section" dnf_restore)
}

remove_recorded_flatpak() {
  local section="$1" app
  local approved=()
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    if ask "Uninstall Flatpak recorded as installed by kit: $app?" "n"; then
      if flatpak info --user "$app" >/dev/null 2>&1; then
        approved+=("$app")
      else
        SKIPPED+=("$app was already absent")
        remove_managed_state "$section" flatpak "$app"
      fi
    fi
  done < <(recorded_values "$section" flatpak)
  [ "${#approved[@]}" -gt 0 ] || return 0
  flatpak uninstall --user -y "${approved[@]}"
  for app in "${approved[@]}"; do
    if flatpak info --user "$app" >/dev/null 2>&1; then
      SKIPPED+=("$app could not be removed and remains managed")
    else
      remove_managed_state "$section" flatpak "$app"
      CHANGED+=("removed Flatpak $app")
    fi
  done
}

remove_recorded_copr() {
  local section="$1" repo
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    if ask "Disable COPR recorded as enabled by kit: $repo?" "n"; then
      sudo "$DNF" -y copr remove "$repo"
      remove_managed_state "$section" copr "$repo"
      CHANGED+=("disabled COPR $repo")
    fi
  done < <(recorded_values "$section" copr)
}

disable_recorded_services() {
  local section="$1" service
  while IFS= read -r service; do
    [ -n "$service" ] || continue
    if ask "Disable service enabled by the kit: $service?" "n"; then
      if systemctl cat "$service" >/dev/null 2>&1; then
        sudo systemctl disable --now "$service"
        CHANGED+=("disabled service $service")
      else
        SKIPPED+=("$service unit was already absent")
      fi
      remove_managed_state "$section" service "$service"
    fi
  done < <(recorded_values "$section" service)
}

enable_recorded_services() {
  local section="$1" service
  while IFS= read -r service; do
    [ -n "$service" ] || continue
    if ask "Re-enable service disabled by the kit: $service?" "y"; then
      if systemctl cat "$service" >/dev/null 2>&1; then
        sudo systemctl enable "$service"
        CHANGED+=("re-enabled service $service")
      else
        SKIPPED+=("$service unit is unavailable")
      fi
      remove_managed_state "$section" disabled_service "$service"
    fi
  done < <(recorded_values "$section" disabled_service)
}

remove_recorded_flatpak_remotes() {
  local section="$1" remote
  while IFS= read -r remote; do
    [ -n "$remote" ] || continue
    if ask "Remove Flatpak remote added by the kit: $remote?" "n"; then
      flatpak uninstall --user --unused -y >/dev/null 2>&1 || true
      if flatpak remote-delete --user "$remote"; then
        remove_managed_state "$section" flatpak_remote "$remote"
        CHANGED+=("removed Flatpak remote $remote")
      else
        SKIPPED+=("$remote still has installed refs; remote left in place")
      fi
    fi
  done < <(recorded_values "$section" flatpak_remote)
}

revert_core() {
  ui_section "Core configs" 2>/dev/null || true
  remove_if_matches "$ROOT_DIR/shell/aliases.sh" "$HOME/.config/shell/aliases.sh"
  remove_if_matches "$ROOT_DIR/shell/functions.sh" "$HOME/.config/shell/functions.sh"
  remove_if_matches "$ROOT_DIR/configs/starship.toml" "$HOME/.config/starship.toml"
  remove_if_matches "$ROOT_DIR/configs/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
  remove_if_matches "$ROOT_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  remove_if_matches "$ROOT_DIR/configs/fastfetch/dog_transparent.png" "$HOME/.config/fastfetch/dog_transparent.png"
  remove_if_matches "$ROOT_DIR/configs/fastfetch/dog.png" "$HOME/.config/fastfetch/dog.png"
  restore_latest_backup "$HOME/.zshrc"
  if [ -f "$HOME/.bashrc" ]; then
    restore_latest_backup "$HOME/.bashrc"
  fi
}

revert_kde() {
  ui_section "KDE configs" 2>/dev/null || true
  remove_if_matches "$ROOT_DIR/configs/konsole/FedoraStarter.profile" "$HOME/.local/share/konsole/FedoraStarter.profile"
  remove_if_matches "$ROOT_DIR/configs/konsole/Sweet-Starter.colorscheme" "$HOME/.local/share/konsole/Sweet-Starter.colorscheme"
  restore_latest_backup "$HOME/.config/kdeglobals"
  restore_latest_backup "$HOME/.config/kwinrc"
  restore_latest_backup "$HOME/.config/kglobalshortcutsrc"
}

revert_gnome() {
  local entry schema key encoded value extension
  ui_section "GNOME configs" 2>/dev/null || true
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    IFS='|' read -r schema key encoded <<<"$entry"
    value="$(printf '%s' "$encoded" | base64 --decode)"
    if ask "Restore GNOME setting $schema $key to its previous value?" "y"; then
      gsettings set "$schema" "$key" "$value"
      remove_managed_state gnome gsetting "$entry"
      CHANGED+=("restored GNOME setting $schema $key")
    fi
  done < <(recorded_values gnome gsetting)
  while IFS= read -r extension; do
    [ -n "$extension" ] || continue
    if ask "Disable GNOME extension enabled by the kit: $extension?" "y"; then
      gnome-extensions disable "$extension"
      remove_managed_state gnome gnome_extension "$extension"
      CHANGED+=("disabled GNOME extension $extension")
    fi
  done < <(recorded_values gnome gnome_extension)
  remove_recorded_dnf gnome
}

revert_ai() {
  ui_section "AI CLI tools" 2>/dev/null || true
  remove_recorded_npm ai
}

case "$SECTION" in
core)
  revert_core
  remove_recorded_flatpak_remotes core
  remove_recorded_dnf core
  ;;
kde)
  revert_kde
  disable_recorded_services kde
  enable_recorded_services kde
  remove_recorded_dnf kde
  remove_recorded_copr kde
  ;;
gnome) revert_gnome ;;
ai) revert_ai ;;
extras)
  disable_recorded_services extras
  remove_recorded_flatpak extras
  remove_recorded_flatpak_remotes extras
  remove_recorded_dnf extras
  restore_recorded_dnf extras
  remove_recorded_copr extras
  ;;
security)
  disable_recorded_services security
  remove_recorded_dnf security
  ;;
all)
  revert_core
  revert_kde
  revert_gnome
  revert_ai
  disable_recorded_services all
  enable_recorded_services all
  remove_recorded_flatpak all
  remove_recorded_flatpak_remotes all
  remove_recorded_dnf all
  restore_recorded_dnf all
  remove_recorded_copr all
  ;;
*)
  ui_warn "Unknown section: $SECTION" 2>/dev/null || true
  exit 2
  ;;
esac

resolve_transactions "$SECTION" reverted

echo
ui_title "Revert Summary" 2>/dev/null || echo "Revert summary"
printf 'Changed:\n'
printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'
printf '  - %s\n' "${SKIPPED[@]:-(none)}"
