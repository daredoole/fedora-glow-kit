# shellcheck shell=bash
# Portable shell helper functions for Fedora.

mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

extract() {
  if [ ! -f "$1" ]; then
    printf 'extract: not a file: %s\n' "$1" >&2
    return 1
  fi

  case "$1" in
  *.tar.bz2) tar xjf "$1" ;;
  *.tar.gz) tar xzf "$1" ;;
  *.tar.xz) tar xJf "$1" ;;
  *.tar) tar xf "$1" ;;
  *.tbz2) tar xjf "$1" ;;
  *.tgz) tar xzf "$1" ;;
  *.zip) unzip "$1" ;;
  *.7z) 7z x "$1" ;;
  *.gz) gunzip "$1" ;;
  *)
    printf 'extract: unsupported archive: %s\n' "$1" >&2
    return 1
    ;;
  esac
}

path_prepend() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
  *":$1:"*) ;;
  *) export PATH="$1:$PATH" ;;
  esac
}

path_append() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
  *":$1:"*) ;;
  *) export PATH="$PATH:$1" ;;
  esac
}

serve_here() {
  local port="${1:-8000}"
  python3 -m http.server "$port"
}

_glow_confirm() {
  local prompt="$1" reply
  [ -t 0 ] || {
    printf '%s\n' "Confirmation requires an interactive terminal." >&2
    return 1
  }
  printf '%s [y/N] ' "$prompt"
  read -r reply
  case "$reply" in
  y | Y | yes | YES) return 0 ;;
  *) return 1 ;;
  esac
}

glow_update() {
  if command -v glow-kit >/dev/null 2>&1; then
    glow-kit update --apply "$@"
    return
  fi
  printf '%s\n' \
    "Update preview:" \
    "  sudo dnf upgrade --refresh" \
    "  flatpak update (when available)" \
    "  fwupdmgr get-updates (check only)"
  _glow_confirm "Run the package updates shown above?" || {
    printf '%s\n' "Update cancelled."
    return 1
  }
  sudo dnf upgrade --refresh
  command -v flatpak >/dev/null 2>&1 && flatpak update
  command -v fwupdmgr >/dev/null 2>&1 && fwupdmgr get-updates
}

glow_cleanup() {
  printf '%s\n' \
    "Cleanup preview:" \
    "  sudo dnf autoremove" \
    "  sudo dnf clean all"
  _glow_confirm "Remove unused packages and clear the DNF cache?" || {
    printf '%s\n' "Cleanup cancelled."
    return 1
  }
  sudo dnf autoremove
  sudo dnf clean all
}

update_all() {
  glow_update "$@"
}

qedit() {
  if command -v kwrite >/dev/null 2>&1; then
    kwrite "$@" >/dev/null 2>&1 &
  elif command -v featherpad >/dev/null 2>&1; then
    featherpad "$@" >/dev/null 2>&1 &
  elif command -v gnome-text-editor >/dev/null 2>&1; then
    gnome-text-editor "$@" >/dev/null 2>&1 &
  else
    "${EDITOR:-nano}" "$@"
  fi
}

ffz() {
  if [ -f "$HOME/.config/fastfetch/dog_transparent.png" ]; then
    clear
    fastfetch --sixel "$HOME/.config/fastfetch/dog_transparent.png" --logo-width 42 --logo-height 20 --logo-padding-top 10 --logo-padding-left 4 --logo-padding-right 4 "$@"
  elif [ -f "$HOME/.config/fastfetch/dog.png" ]; then
    clear
    fastfetch --sixel "$HOME/.config/fastfetch/dog.png" --logo-width 42 --logo-height 20 --logo-padding-top 10 --logo-padding-left 4 --logo-padding-right 4 "$@"
  else
    fastfetch "$@"
  fi
}

if ! command -v halp >/dev/null 2>&1; then
  halp() {
    _halp_alias() {
      local name="$1" desc="$2" line cmd
      line="$(alias "$name" 2>/dev/null)" || return 0
      cmd="${line#*=}"
      cmd="${cmd#\'}"
      cmd="${cmd%\'}"
      [ "${#cmd}" -gt 32 ] && cmd="${cmd:0:29}..."
      printf '  %-22s -> %-32s %s\n' "$name" "$cmd" "$desc"
    }

    _halp_section() {
      printf '\n%s\n' "$1"
    }

    cat <<'EOF'
Fedora Plasma Glow Kit help

Core commands:
  update / update_all    Preview and confirm DNF, Flatpak, and firmware checks
  cleanup                Preview and confirm DNF autoremove/cache cleanup
  mkcd DIR               Create a directory and cd into it
  extract FILE           Extract common archive formats
  serve_here [PORT]      Serve the current directory with Python
  qedit [FILE]           Open a quick GUI editor, falling back to $EDITOR
  ffz                    Run fastfetch with the centered kit logo when available

Recommended KDE hotkeys:
  Meta+W                 Toggle Overview
  Meta+G                 Toggle Grid View
  Meta+T                 Toggle Tiles Editor
  Meta+D                 Peek at Desktop
  Meta+Shift+D           Minimize all windows
  Meta+Ctrl+Esc          Kill/select unresponsive window
  Meta+L                 Lock session

Optional tiling reference:
  Meta+H/J/K/L           Focus left/down/up/right when a tiling script uses Vim keys
  Meta+Shift+H/J/K/L     Move windows when configured by the user's tiling script
  Meta+Ctrl+H/J/K/L      Resize windows when configured by the user's tiling script

Security baseline:
  Keep SELinux enforcing, firewalld enabled, firmware updated with fwupd,
  browser/password-manager data out of dotfile sync, and review USBGuard
  before enabling device blocking.

Grouped aliases:
EOF

    _halp_section "files & shell"
    _halp_alias cat "bat as plain cat"
    _halp_alias ls "long listing with icons/git"
    _halp_alias ll "all files with icons/git"
    _halp_alias la "all files"
    _halp_alias tree "tree listing with icons"
    _halp_alias c "clear terminal"
    _halp_alias h "history"
    _halp_alias grep "colored grep"
    _halp_alias path "print PATH one entry per line"

    _halp_section "packages & updates"
    _halp_alias update "preview and confirm all updates"
    _halp_alias cleanup "preview and confirm cleanup"
    _halp_alias pkg-search "search Fedora packages"
    _halp_alias pkg-install "install Fedora package"
    _halp_alias pkg-remove "remove Fedora package"

    _halp_section "navigation & editing"
    _halp_alias .. "up one directory"
    _halp_alias ... "up two directories"
    _halp_alias reload "restart login shell"
    _halp_alias zconf "edit zshrc"
    _halp_alias aliases "edit kit aliases"
    _halp_alias edit "quick GUI editor"
    _halp_alias helpme "show this help"

    _halp_section "git"
    _halp_alias gs "status"
    _halp_alias ga "add all"
    _halp_alias gc "commit"
    _halp_alias gp "push"
    _halp_alias gl "compact graph log"
    _halp_alias gd "diff"
    _halp_alias gco "checkout"
    _halp_alias gb "branch"
    _halp_alias lg "lazygit"

    _halp_section "system & services"
    _halp_alias df "disk free"
    _halp_alias free "memory usage"
    _halp_alias ports "list listening ports"
    _halp_alias reboot-now "reboot now"
    _halp_alias poweroff-now "power off now"
    _halp_alias suspend-now "suspend session"
    _halp_alias jlog "journal errors"
    _halp_alias jlogf "follow journal errors"
    _halp_alias failed-units "failed systemd units"
    _halp_alias service-enable "enable service"
    _halp_alias service-disable "disable service"
    _halp_alias service-restart "restart service"
    _halp_alias service-status "service status"

    _halp_section "dev & containers"
    _halp_alias dbx "distrobox"
    _halp_alias pc "podman compose"
    _halp_alias j "just command runner"

    _halp_section "monitoring"
    _halp_alias ff "fastfetch"
    _halp_alias gpu "GPU monitor"
    _halp_alias diskio "live disk I/O"
    _halp_alias sysday "daily sysstat report"
    _halp_alias sarcpu "CPU sample"
    _halp_alias sario "I/O sample"
    _halp_alias vdpau-check "VDPAU diagnostics"
    _halp_alias vaapi-check "VAAPI diagnostics"

    _halp_section "terminal fun"
    _halp_alias aquarium "fish tank"
    _halp_alias matrix "cyan matrix rain"
    _halp_alias matrix-rain "green matrix rain"
    _halp_alias bonsai "slow bonsai animation"
    _halp_alias bonsai-fast "default bonsai"
    _halp_alias pipes "straight pipes"
    _halp_alias pipes-curved "curved pipes"
    _halp_alias pipes-angled "angled pipes"
    _halp_alias clock "terminal clock"
    _halp_alias nyan "nyancat"
    _halp_alias train "steam train"
    _halp_alias rainbow "lolcat"
    _halp_alias say "large slant text"
    _halp_alias sayb "colored block text"
    _halp_alias rfortune "rainbow fortune"
    _halp_alias prettycow "fortune cow rainbow"
  }
fi
