#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
ui_intro 2>/dev/null || true
ui_title "Fedora Glow Kit Guided Setup" 2>/dev/null || echo "Fedora Glow Kit Guided Setup"

choose_action() {
  local title="$1" description="$2" key
  printf '\n'
  ui_section "$title" 2>/dev/null || echo "$title"
  printf '%s\n' "$description"
  printf '  Space/Enter = install or setup\n'
  printf '  r           = revert or uninstall kit-managed changes\n'
  printf '  s           = skip\n'
  printf '  q           = quit\n'
  printf 'Choice: '
  IFS= read -r -n 1 key || true
  printf '\n'
  case "${key:- }" in
    ""|" ") return 0 ;;
    r|R) return 1 ;;
    s|S) return 2 ;;
    q|Q) exit 0 ;;
    *) ui_warn "Unknown choice; skipping $title" 2>/dev/null || true; return 2 ;;
  esac
}

run_section() {
  local id="$1" title="$2" description="$3" install_cmd="$4"
  if choose_action "$title" "$description"; then
    bash -c "$install_cmd"
  else
    case "$?" in
      1) bash "$ROOT_DIR/revert.sh" "$id" ;;
      2) ui_info "Skipped $title" 2>/dev/null || true ;;
    esac
  fi
}

run_section core "Core CLI and Shell" \
  "Installs the portable command-line baseline, aliases, functions, prompt, zellij, fastfetch, optional Firefox, and optional terminal configs." \
  "bash '$ROOT_DIR/install.sh'"

run_section extras "Optional Apps and Extras" \
  "Installs optional editors, terminal apps, monitoring tools, terminal art, Flatpak app groups, RPM Fusion media tools, and daily-use apps." \
  "bash '$ROOT_DIR/install-extras.sh'"

run_section kde "KDE Desktop Customization" \
  "Installs KDE packages, lightweight theme assets, Panel Colorizer tuning, optional Rounded Corners, reviewed hotkeys, KWin plugins, and Konsole profile." \
  "bash '$ROOT_DIR/install-kde.sh'"

run_section ai "AI CLI Tools" \
  "Installs opt-in AI terminal tools like Codex CLI and Claude Code without copying API keys, account files, prompts, histories, or tool state." \
  "bash '$ROOT_DIR/install-ai.sh'"

run_section security "Security Best Practices" \
  "Sets up practical Fedora security basics: SELinux tooling, firewalld, firmware update checks, optional dnf-automatic, and optional USBGuard policy generation." \
  "bash '$ROOT_DIR/install-security.sh'"

ui_title "Guided Setup Complete" 2>/dev/null || echo "Guided setup complete"
