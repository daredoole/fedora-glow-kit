#!/usr/bin/env bash
set -euo pipefail

DNF="${DNF:-dnf}"
CHANGED=()
SKIPPED=()
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.local/state/fedora-plasma-glow-kit"
STATE_FILE="$STATE_DIR/install.state"

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
ui_intro 2>/dev/null || true
ui_title "Fedora Plasma Glow Kit Extras" 2>/dev/null || echo "Fedora Plasma Glow Kit Extras"

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

fedora_hardware_preflight

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

record_state() {
  local key="$1" value="$2"
  mkdir -p "$STATE_DIR"
  grep -Fqx "$key=$value" "$STATE_FILE" 2>/dev/null || printf '%s=%s\n' "$key" "$value" >>"$STATE_FILE"
}

install_dnf() {
  local pkgs=("$@") pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "$DNF" install -y "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
  CHANGED+=("installed ${pkgs[*]}")
}

install_dnf_skip_unavailable() {
  local pkgs=("$@") pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  sudo "$DNF" install -y --skip-unavailable "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && record_state dnf "$pkg"
  done
  CHANGED+=("attempted install with skip-unavailable: ${pkgs[*]}")
}

flatpak_install() {
  local apps=("$@") app new_apps=()
  for app in "${apps[@]}"; do
    flatpak info "$app" >/dev/null 2>&1 || new_apps+=("$app")
  done
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub "${apps[@]}"
  for app in "${new_apps[@]}"; do
    flatpak info "$app" >/dev/null 2>&1 && record_state flatpak "$app"
  done
  CHANGED+=("installed Flatpaks: ${apps[*]}")
}

if ask "Install extra editors, terminals, and dev tools?" "y"; then
  ui_section "Developer Extras" 2>/dev/null || true
  install_dnf_skip_unavailable neovim micro kitty wezterm lazygit ripgrep git-delta golang rust cargo docker-compose direnv git-lfs just distrobox podman-compose
else
  SKIPPED+=("extra dev tools")
fi

if ask "Install lightweight GUI file search and text editors?" "y"; then
  ui_section "Lightweight GUI Utilities" 2>/dev/null || true
  install_dnf_skip_unavailable catfish kwrite featherpad gnome-text-editor micro
fi

if ask "Install KDE desktop customization packages?" "y"; then
  ui_section "KDE Extras" 2>/dev/null || true
  install_dnf_skip_unavailable kdeplasma-addons papirus-icon-theme variety qt6-qttools
fi

if ask "Install Bluetooth headphone codec/support packages?" "y"; then
  ui_section "Bluetooth Audio" 2>/dev/null || true
  install_dnf_skip_unavailable bluez bluedevil pipewire pipewire-pulseaudio pipewire-alsa wireplumber libldac libfreeaptx fdk-aac-free ffmpeg gstreamer1-plugin-openh264 gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly
  sudo systemctl enable --now bluetooth || true
  CHANGED+=("enabled bluetooth service")
fi

if ask "Install monitoring and sysadmin tools?" "y"; then
  ui_section "Monitoring" 2>/dev/null || true
  install_dnf_skip_unavailable nvtop iotop sysstat vdpauinfo libva-utils
fi

if ask "Install Tailscale mesh VPN package from Fedora repos?" "n"; then
  ui_section "Tailscale" 2>/dev/null || true
  install_dnf_skip_unavailable tailscale
fi

if command_exists tailscale && ask "Enable and start tailscaled service? This does not join a tailnet." "n"; then
  sudo systemctl enable --now tailscaled
  CHANGED+=("enabled tailscaled service")
  ui_info "Run 'sudo tailscale up' when ready to sign in and join a tailnet." 2>/dev/null || true
fi

if ask "Enable and start sysstat service?" "n"; then
  sudo systemctl enable --now sysstat
  CHANGED+=("enabled sysstat")
fi

if ask "Install terminal art and animation tools?" "y"; then
  ui_section "Terminal Art" 2>/dev/null || true
  install_dnf_skip_unavailable cmatrix asciiquarium pipes-sh fortune-mod cowsay rubygem-lolcat figlet toilet cbonsai tty-clock nyancat sl
fi

if ask "Enable RPM Fusion free/nonfree repositories?" "n"; then
  fedora_version="$(rpm -E %fedora)"
  sudo "$DNF" install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
  CHANGED+=("enabled RPM Fusion")
fi

if ask "Install common multimedia codecs from RPM Fusion?" "n"; then
  install_dnf_skip_unavailable gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly lame ffmpeg
fi

if ask "Install RPM Fusion Mesa VAAPI/VDPAU video acceleration packages?" "n"; then
  echo "Using --skip-unavailable because RPM Fusion Mesa packages can temporarily lag Fedora Mesa updates."
  install_dnf_skip_unavailable mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld vdpauinfo libva-utils
fi

if command_exists flatpak; then
  if ask "Install daily desktop Flatpaks?" "n"; then
    flatpak_install \
      com.brave.Browser \
      com.visualstudio.code \
      com.bitwarden.desktop \
      com.github.tchx84.Flatseal \
      io.github.flattool.Warehouse \
      it.mijorus.gearlever \
      codes.merritt.Nyrna \
      org.localsend.localsend_app \
      org.cryptomator.Cryptomator \
      org.ferdium.Ferdium \
      org.gnome.gitlab.somas.Apostrophe \
      org.kde.marknote
  fi

  if ask "Install gaming and media Flatpaks?" "n"; then
    flatpak_install \
      com.valvesoftware.Steam \
      com.heroicgameslauncher.hgl \
      com.moonlight_stream.Moonlight \
      com.parsecgaming.parsec \
      com.stremio.Stremio \
      com.mastermindzh.tidal-hifi
  fi

  if ask "Install messaging/social Flatpaks?" "n"; then
    flatpak_install \
      dev.vencord.Vesktop \
      io.github.milkshiift.GoofCord \
      io.github.kotatogram \
      app.bluebubbles.BlueBubbles \
      com.slack.Slack
  fi

  if ask "Install advanced/privacy/dev Flatpaks?" "n"; then
    flatpak_install \
      com.surfshark.Surfshark \
      dev.deedles.Trayscale \
      io.podman_desktop.PodmanDesktop \
      com.google.AndroidStudio \
      io.github.stacklok.toolhive_studio \
      me.timschneeberger.jdsp4linux
  fi
else
  SKIPPED+=("Flatpak apps because flatpak is not installed")
fi

echo
ui_title "Extras Summary" 2>/dev/null || echo "Extras summary"
printf 'Changed:\n'
printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'
printf '  - %s\n' "${SKIPPED[@]:-(none)}"
