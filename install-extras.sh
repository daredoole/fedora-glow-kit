#!/usr/bin/env bash
set -euo pipefail

DNF="${DNF:-dnf}"
CHANGED=()
SKIPPED=()
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/lib/state.sh" ] && . "$ROOT_DIR/lib/state.sh"
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

install_dnf() {
  local pkgs=("$@") pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  dnf_install_tracked "$DNF" install -y "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      record_state dnf "$pkg"
    else
      SKIPPED+=("$pkg unavailable from enabled repositories")
    fi
  done
  CHANGED+=("installed ${pkgs[*]}")
}

install_dnf_skip_unavailable() {
  local pkgs=("$@") pkg new_pkgs=()
  for pkg in "${pkgs[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_pkgs+=("$pkg")
  done
  dnf_install_tracked "$DNF" install -y --skip-unavailable "${pkgs[@]}"
  for pkg in "${new_pkgs[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      record_state dnf "$pkg"
    else
      SKIPPED+=("$pkg unavailable from enabled repositories")
    fi
  done
  CHANGED+=("attempted install with skip-unavailable: ${pkgs[*]}")
}

flatpak_install() {
  local apps=("$@") app remote_was_present=0
  local pending_apps=()
  flatpak remotes --user --columns=name 2>/dev/null | grep -Fqx flathub && remote_was_present=1
  if [ "$remote_was_present" -eq 0 ]; then
    if ! flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
      SKIPPED+=("Flathub remote could not be added; optional Flatpaks skipped")
      return 0
    fi
    record_state flatpak_remote flathub
  fi
  for app in "${apps[@]}"; do
    if flatpak info --user "$app" >/dev/null 2>&1; then
      SKIPPED+=("$app already installed")
      continue
    fi
    if flatpak remote-info --user flathub "$app" >/dev/null 2>&1; then
      pending_apps+=("$app")
    else
      SKIPPED+=("$app unavailable from Flathub")
    fi
  done
  [ "${#pending_apps[@]}" -gt 0 ] || return 0

  if ! flatpak install --user --noninteractive -y flathub "${pending_apps[@]}"; then
    SKIPPED+=("Flatpak batch transaction failed; retrying apps individually")
  fi
  for app in "${pending_apps[@]}"; do
    if flatpak info --user "$app" >/dev/null 2>&1; then
      record_state flatpak "$app"
      CHANGED+=("installed Flatpak $app")
    elif flatpak install --user --noninteractive -y flathub "$app"; then
      record_state flatpak "$app"
      CHANGED+=("installed Flatpak $app after batch fallback")
    else
      SKIPPED+=("$app failed to install from Flathub")
    fi
  done
}

enable_rpm_fusion() {
  local fedora_version pkg
  local packages=(rpmfusion-free-release rpmfusion-nonfree-release)
  local new_packages=()
  fedora_version="$(rpm -E %fedora)"
  for pkg in "${packages[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || new_packages+=("$pkg")
  done
  dnf_install_tracked "$DNF" install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
  for pkg in "${new_packages[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      record_state dnf "$pkg"
    fi
  done
  CHANGED+=("enabled RPM Fusion")
}

install_rpm_fusion_ffmpeg() {
  local ffmpeg_was_present=0 ffmpeg_free_was_present=0
  rpm -q ffmpeg >/dev/null 2>&1 && ffmpeg_was_present=1
  rpm -q ffmpeg-free >/dev/null 2>&1 && ffmpeg_free_was_present=1

  dnf_install_tracked "$DNF" install -y --allowerasing ffmpeg

  if [ "$ffmpeg_was_present" -eq 0 ] && rpm -q ffmpeg >/dev/null 2>&1; then
    record_state dnf ffmpeg
  fi
  if [ "$ffmpeg_free_was_present" -eq 1 ] &&
    ! rpm -q ffmpeg-free >/dev/null 2>&1 &&
    ! state_values dnf | grep -Fqx ffmpeg-free; then
    record_state dnf_restore ffmpeg-free
  fi
  CHANGED+=("installed RPM Fusion ffmpeg")
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
  bluetooth_was_enabled=0
  systemctl is-enabled --quiet bluetooth 2>/dev/null && bluetooth_was_enabled=1
  ui_section "Bluetooth Audio" 2>/dev/null || true
  install_dnf_skip_unavailable bluez bluedevil pipewire pipewire-pulseaudio pipewire-alsa wireplumber libldac libfreeaptx fdk-aac-free gstreamer1-plugin-openh264 gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly
  if sudo systemctl enable --now bluetooth; then
    [ "$bluetooth_was_enabled" -eq 1 ] || record_state service bluetooth
  fi
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
  tailscale_was_enabled=0
  systemctl is-enabled --quiet tailscaled 2>/dev/null && tailscale_was_enabled=1
  sudo systemctl enable --now tailscaled
  [ "$tailscale_was_enabled" -eq 1 ] || record_state service tailscaled
  CHANGED+=("enabled tailscaled service")
  ui_info "Run 'sudo tailscale up' when ready to sign in and join a tailnet." 2>/dev/null || true
fi

if ask "Enable and start sysstat service?" "n"; then
  sysstat_was_enabled=0
  systemctl is-enabled --quiet sysstat 2>/dev/null && sysstat_was_enabled=1
  sudo systemctl enable --now sysstat
  [ "$sysstat_was_enabled" -eq 1 ] || record_state service sysstat
  CHANGED+=("enabled sysstat")
fi

if ask "Install terminal art and animation tools?" "y"; then
  ui_section "Terminal Art" 2>/dev/null || true
  install_dnf_skip_unavailable cmatrix asciiquarium pipes-sh fortune-mod cowsay rubygem-lolcat figlet toilet cbonsai tty-clock nyancat sl
fi

if ask "Enable RPM Fusion free/nonfree repositories?" "n"; then
  enable_rpm_fusion
fi

if ask "Install common multimedia codecs from RPM Fusion?" "n"; then
  install_dnf_skip_unavailable gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly lame
  install_rpm_fusion_ffmpeg
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
