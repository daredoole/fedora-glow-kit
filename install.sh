#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNF="${DNF:-dnf}"
STAMP="$(date +%Y%m%d-%H%M%S)"
INSTALLED=()
SKIPPED=()
CHANGED=()
LAST_BACKUP_PATH=""
STATE_DIR="$HOME/.local/state/fedora-plasma-glow-kit"
STATE_FILE="$STATE_DIR/install.state"

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
ui_intro 2>/dev/null || true
ui_title "Fedora Plasma Glow Kit" 2>/dev/null || echo "Fedora Plasma Glow Kit"

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

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/lib/preflight.sh" ] && . "$ROOT_DIR/lib/preflight.sh"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

record_state() {
  local key="$1" value="$2"
  mkdir -p "$STATE_DIR"
  grep -Fqx "$key=$value" "$STATE_FILE" 2>/dev/null || printf '%s=%s\n' "$key" "$value" >>"$STATE_FILE"
}

add_pkg_if_missing() {
  local cmd="$1"
  shift
  if command_exists "$cmd"; then
    SKIPPED+=("$cmd already present")
  else
    MISSING_PKGS+=("$@")
  fi
}

backup_path() {
  local target="$1"
  LAST_BACKUP_PATH=""
  if [ -e "$target" ] || [ -L "$target" ]; then
    cp -a "$target" "$target.bak.$STAMP"
    LAST_BACKUP_PATH="$target.bak.$STAMP"
    CHANGED+=("backed up $target")
  fi
}

show_file_diff() {
  local before="$1" after="$2"
  [ -n "$before" ] || return 0
  [ -f "$before" ] || return 0
  [ -f "$after" ] || return 0
  ui_section "Diff: $after" 2>/dev/null || printf '\nDiff: %s\n' "$after"
  diff -u --label "before:$after" --label "after:$after" "$before" "$after" || true
}

install_file() {
  local src="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] && cmp -s "$src" "$target"; then
    SKIPPED+=("$target already up to date")
    return
  fi
  if [ -e "$target" ] && ! ask "Overwrite $target?" "n"; then
    SKIPPED+=("left existing $target unchanged")
    return
  fi
  backup_path "$target"
  cp "$src" "$target"
  CHANGED+=("installed $target")
  show_file_diff "$LAST_BACKUP_PATH" "$target"
}

append_source_block() {
  local shell_file="$1"
  local marker="# fedora-plasma-glow-kit shell helpers"
  mkdir -p "$(dirname "$shell_file")"
  touch "$shell_file"
  if grep -Fq "$marker" "$shell_file"; then
    SKIPPED+=("$shell_file already sources starter-kit helpers")
    return
  fi
  if ask "Add starter-kit source block to $shell_file?" "y"; then
    backup_path "$shell_file"
    {
      printf '\n%s\n' "$marker"
      # shellcheck disable=SC2016
      printf '[ -f "$HOME/.config/shell/aliases.sh" ] && . "$HOME/.config/shell/aliases.sh"\n'
      # shellcheck disable=SC2016
      printf '[ -f "$HOME/.config/shell/functions.sh" ] && . "$HOME/.config/shell/functions.sh"\n'
    } >>"$shell_file"
    CHANGED+=("updated $shell_file")
    show_file_diff "$LAST_BACKUP_PATH" "$shell_file"
  else
    SKIPPED+=("did not update $shell_file")
  fi
}

if [ -r /etc/fedora-release ]; then
  ui_info "Detected $(cat /etc/fedora-release)" 2>/dev/null || echo "Detected $(cat /etc/fedora-release)"
else
  ui_warn "This script is intended for Fedora." 2>/dev/null || echo "This script is intended for Fedora." >&2
  ask "Continue anyway?" "n" || exit 1
fi

fedora_hardware_preflight

MISSING_PKGS=()
add_pkg_if_missing zsh zsh
add_pkg_if_missing firefox firefox
add_pkg_if_missing direnv direnv
add_pkg_if_missing starship starship
add_pkg_if_missing zellij zellij
add_pkg_if_missing fastfetch fastfetch
add_pkg_if_missing fzf fzf
add_pkg_if_missing zoxide zoxide
add_pkg_if_missing rg ripgrep
add_pkg_if_missing fd fd-find
add_pkg_if_missing bat bat
add_pkg_if_missing eza eza
add_pkg_if_missing jq jq
add_pkg_if_missing yq yq
add_pkg_if_missing btop btop
add_pkg_if_missing tree tree
add_pkg_if_missing tldr tealdeer
add_pkg_if_missing git git
add_pkg_if_missing gh gh
add_pkg_if_missing delta git-delta
add_pkg_if_missing git-lfs git-lfs
add_pkg_if_missing just just
add_pkg_if_missing unzip unzip
add_pkg_if_missing 7z p7zip p7zip-plugins
add_pkg_if_missing rsync rsync
add_pkg_if_missing curl curl
add_pkg_if_missing wget wget
add_pkg_if_missing nano nano
add_pkg_if_missing vim vim-enhanced
add_pkg_if_missing flatpak flatpak
add_pkg_if_missing python3 python3
add_pkg_if_missing pip3 python3-pip
add_pkg_if_missing pipx pipx
add_pkg_if_missing uv uv
add_pkg_if_missing podman podman
add_pkg_if_missing podman-compose podman-compose
add_pkg_if_missing distrobox distrobox

if [ "${#MISSING_PKGS[@]}" -gt 0 ] && ask "Install core CLI/dev packages?" "y"; then
  mapfile -t UNIQUE_PKGS < <(printf '%s\n' "${MISSING_PKGS[@]}" | sort -u)
  ui_section "Packages" 2>/dev/null || true
  ui_info "Packages to attempt: ${UNIQUE_PKGS[*]}" 2>/dev/null || echo "Packages to attempt: ${UNIQUE_PKGS[*]}"
  ui_info "Using --skip-unavailable so one missing Fedora package does not stop the whole setup." 2>/dev/null || true
  sudo "$DNF" install -y --skip-unavailable "${UNIQUE_PKGS[@]}"
  for pkg in "${UNIQUE_PKGS[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      record_state dnf "$pkg"
      INSTALLED+=("$pkg")
    else
      SKIPPED+=("$pkg unavailable or not installed")
    fi
  done
else
  SKIPPED+=("core package installation skipped or all core commands already present")
fi

if ask "Install shell aliases and functions?" "y"; then
  ui_section "Shell Helpers" 2>/dev/null || true
  install_file "$ROOT_DIR/shell/aliases.sh" "$HOME/.config/shell/aliases.sh"
  install_file "$ROOT_DIR/shell/functions.sh" "$HOME/.config/shell/functions.sh"
else
  SKIPPED+=("shell aliases/functions")
fi

if ask "Install terminal prompt, zellij, and fastfetch configs?" "y"; then
  ui_section "Terminal Configs" 2>/dev/null || true
  install_file "$ROOT_DIR/configs/starship.toml" "$HOME/.config/starship.toml"
  install_file "$ROOT_DIR/configs/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
  install_file "$ROOT_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  install_file "$ROOT_DIR/configs/fastfetch/dog_transparent.png" "$HOME/.config/fastfetch/dog_transparent.png"
  install_file "$ROOT_DIR/configs/fastfetch/dog.png" "$HOME/.config/fastfetch/dog.png"
else
  SKIPPED+=("terminal prompt/zellij/fastfetch configs")
fi

if [ -f "$ROOT_DIR/configs/kitty/kitty.conf" ] && ask "Install sanitized kitty config?" "n"; then
  ui_section "Kitty" 2>/dev/null || true
  install_file "$ROOT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
  install_file "$ROOT_DIR/configs/kitty/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"
fi

if [ -f "$ROOT_DIR/configs/konsole/FedoraStarter.profile" ] && ask "Install sanitized Konsole profile and color scheme?" "n"; then
  ui_section "Konsole" 2>/dev/null || true
  install_file "$ROOT_DIR/configs/konsole/FedoraStarter.profile" "$HOME/.local/share/konsole/FedoraStarter.profile"
  install_file "$ROOT_DIR/configs/konsole/Sweet-Starter.colorscheme" "$HOME/.local/share/konsole/Sweet-Starter.colorscheme"
fi

find_firefox_profile() {
  local root="$HOME/.mozilla/firefox" ini="$HOME/.mozilla/firefox/profiles.ini" rel
  [ -f "$ini" ] || return 1
  rel="$(awk -F= '
    /^\[Profile/ { path=""; def=0 }
    /^Path=/ { path=$2 }
    /^Default=1/ { def=1 }
    def && path { print path; exit }
  ' "$ini")"
  [ -n "$rel" ] || rel="$(find "$root" -maxdepth 1 -type d -name '*default-release*' -printf '%f\n' 2>/dev/null | head -n 1)"
  [ -n "$rel" ] || return 1
  case "$rel" in
  /*) printf '%s\n' "$rel" ;;
  *) printf '%s/%s\n' "$root" "$rel" ;;
  esac
}

install_firefox_policy() {
  local src="$ROOT_DIR/configs/firefox/policies.json"
  local target="/etc/firefox/policies/policies.json"
  local backup=""
  if sudo test -e "$target" && sudo cmp -s "$src" "$target"; then
    SKIPPED+=("$target already up to date")
    return
  fi
  if sudo test -e "$target" && ! ask "Overwrite system Firefox policy at $target?" "n"; then
    SKIPPED+=("left existing Firefox policy unchanged")
    return
  fi
  sudo mkdir -p "$(dirname "$target")"
  if sudo test -e "$target"; then
    backup="$target.bak.$STAMP"
    sudo cp -a "$target" "$backup"
    CHANGED+=("backed up $target")
  fi
  sudo cp "$src" "$target"
  CHANGED+=("installed Firefox extension policy")
  if [ -n "$backup" ]; then
    ui_section "Diff: $target" 2>/dev/null || printf '\nDiff: %s\n' "$target"
    sudo diff -u --label "before:$target" --label "after:$target" "$backup" "$target" || true
  fi
}

if [ -f "$ROOT_DIR/configs/firefox/user.js" ] && ask "Install sanitized Firefox user.js to the default profile?" "n"; then
  ui_section "Firefox user.js" 2>/dev/null || true
  if firefox_profile="$(find_firefox_profile)"; then
    install_file "$ROOT_DIR/configs/firefox/user.js" "$firefox_profile/user.js"
  else
    SKIPPED+=("Firefox profile not found")
  fi
fi

if [ -f "$ROOT_DIR/configs/firefox/policies.json" ] && ask "Install system Firefox policy for extension installs?" "n"; then
  ui_section "Firefox Policy" 2>/dev/null || true
  install_firefox_policy
fi

if command_exists git && command_exists delta && ask "Configure git to use delta for diffs?" "n"; then
  backup_path "$HOME/.gitconfig"
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.side-by-side true
  git config --global delta.line-numbers true
  CHANGED+=("configured git delta")
  show_file_diff "$LAST_BACKUP_PATH" "$HOME/.gitconfig"
fi

if command_exists git-lfs && ask "Run git lfs install for this user?" "n"; then
  git lfs install
  CHANGED+=("initialized git lfs")
fi

if ask "Update shell startup files to source starter-kit helpers?" "y"; then
  ui_section "Shell Startup" 2>/dev/null || true
  append_source_block "$HOME/.zshrc"
  if [ -f "$HOME/.bashrc" ]; then
    append_source_block "$HOME/.bashrc"
  fi
else
  SKIPPED+=("shell startup source block")
fi

if command_exists flatpak && ask "Ensure Flathub remote is configured?" "y"; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  CHANGED+=("ensured Flathub remote")
fi

echo
ui_title "Summary" 2>/dev/null || echo "Summary"
echo "Installed packages: ${INSTALLED[*]:-(none)}"
printf 'Changed:\n'
printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'
printf '  - %s\n' "${SKIPPED[@]:-(none)}"
echo "Restart your shell or run: exec \"\$SHELL\" -l"
