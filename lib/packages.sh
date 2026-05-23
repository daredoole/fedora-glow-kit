#!/usr/bin/env bash
# Shared package helpers for Fedora Plasma Glow Kit.

install_dnf_packages() {
  local pkgs=("$@")
  local pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "${DNF:-dnf}" install -y "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
}

install_dnf_packages_skip_unavailable() {
  local pkgs=("$@")
  local pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "${DNF:-dnf}" install -y --skip-unavailable "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
}

install_flatpak_apps() {
  local apps=("$@")
  local app new_apps=()
  for app in "${apps[@]}"; do
    flatpak info "$app" >/dev/null 2>&1 || new_apps+=("$app")
  done
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub "${apps[@]}"
  for app in "${new_apps[@]}"; do
    flatpak info "$app" >/dev/null 2>&1 && record_state flatpak "$app"
  done
}
