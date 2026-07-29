#!/usr/bin/env bash
# Shared package helpers for Fedora Plasma Glow Kit.

install_dnf_packages() {
  local pkgs=("$@")
  local pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  dnf_install_tracked "${DNF:-dnf}" install -y "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      record_state dnf "$pkg"
    fi
  done
}

install_dnf_packages_skip_unavailable() {
  local pkgs=("$@")
  local pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  dnf_install_tracked "${DNF:-dnf}" install -y --skip-unavailable "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      record_state dnf "$pkg"
    fi
  done
}

install_flatpak_apps() {
  local apps=("$@")
  local app remote_was_present=0
  local pending_apps=()
  flatpak remotes --user --columns=name 2>/dev/null | grep -Fqx flathub && remote_was_present=1
  if [ "$remote_was_present" -eq 0 ]; then
    if ! flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
      return 0
    fi
    record_state flatpak_remote flathub
  fi
  for app in "${apps[@]}"; do
    if flatpak info --user "$app" >/dev/null 2>&1; then
      continue
    fi
    if flatpak remote-info --user flathub "$app" >/dev/null 2>&1; then
      pending_apps+=("$app")
    fi
  done
  [ "${#pending_apps[@]}" -gt 0 ] || return 0
  flatpak install --user --noninteractive -y flathub "${pending_apps[@]}" || true
  for app in "${pending_apps[@]}"; do
    if flatpak info --user "$app" >/dev/null 2>&1; then
      record_state flatpak "$app"
    elif flatpak install --user --noninteractive -y flathub "$app"; then
      record_state flatpak "$app"
    fi
  done
}
