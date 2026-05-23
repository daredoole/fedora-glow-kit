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
    *) printf 'extract: unsupported archive: %s\n' "$1" >&2; return 1 ;;
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

update_all() {
  sudo dnf upgrade --refresh
  if command -v flatpak >/dev/null 2>&1; then
    flatpak update
  fi
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

halp() {
  cat <<'EOF'
Fedora Plasma Glow Kit help

Core commands:
  update_all             Update DNF packages and Flatpaks
  mkcd DIR               Create a directory and cd into it
  extract FILE           Extract common archive formats
  serve_here [PORT]      Serve the current directory with Python
  qedit [FILE]           Open a quick GUI editor, falling back to $EDITOR
  ffz                    Run fastfetch with the centered transparent dog logo

Useful aliases:
  ll, la, tree           Better listings
  gs, ga, gc, gp, gl     Git shortcuts
  ff                     fastfetch
  gpu, diskio, sysday    Monitoring helpers when installed
  matrix, aquarium       Terminal art when installed
  edit, qedit            Quick config/text editing

Recommended KDE hotkeys:
  Meta+W                 Toggle Overview
  Meta+G                 Toggle Grid View
  Meta+T                 Toggle Tiles Editor
  Meta+D                 Peek at Desktop
  Meta+Shift+D           Minimize all windows
  Meta+Ctrl+Esc          Kill/select unresponsive window
  Meta+L                 Lock session

Krohnkite reference, if installed:
  Meta+H/J/K/L           Focus left/down/up/right
  Meta+Shift+H/J/K/L     Move window left/down/up/right
  Meta+Ctrl+H/J/K/L      Resize window left/down/up/right
  Meta+Shift+F           Toggle float all
  Meta+Shift+Space       Retile

Security baseline:
  Keep SELinux enforcing, firewalld enabled, firmware updated with fwupd,
  browser/password-manager data out of dotfile sync, and review USBGuard
  before enabling device blocking.
EOF
}
