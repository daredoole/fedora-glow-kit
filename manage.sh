#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSUME=""
DRY_RUN=0
PROFILE=""
SECTION=""
REVERT_SECTION=""
RUN_AUDIT=0

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"

usage() {
  cat <<'USAGE'
Fedora Plasma Glow Kit

Usage:
  bash manage.sh                         Interactive guided setup
  bash manage.sh --dry-run --profile daily
  bash manage.sh --yes --section core
  bash manage.sh --no --section kde
  bash manage.sh --revert kde
  bash manage.sh --audit

Options:
  --dry-run            Print what would run without making changes
  --yes                Answer yes to installer prompts
  --no                 Answer no to installer prompts
  --profile NAME       minimal, daily, dev, kde-polish, media, gaming, privacy, ai, full-send
  --section NAME       core, extras, kde, ai, security
  --revert NAME        core, extras, kde, ai, security, all
  --audit              Run scripts/audit-public.sh
  -h, --help           Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --dry-run) DRY_RUN=1 ;;
  --yes) ASSUME="yes" ;;
  --no) ASSUME="no" ;;
  --profile)
    PROFILE="${2:-}"
    shift
    ;;
  --section)
    SECTION="${2:-}"
    shift
    ;;
  --revert)
    REVERT_SECTION="${2:-}"
    shift
    ;;
  --audit) RUN_AUDIT=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n\n' "$1" >&2
    usage
    exit 1
    ;;
  esac
  shift
done

ui_intro 2>/dev/null || true
ui_title "Fedora Plasma Glow Kit Guided Setup" 2>/dev/null || echo "Fedora Plasma Glow Kit Guided Setup"

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

if [ "$DRY_RUN" -eq 0 ] && [ "$RUN_AUDIT" -eq 0 ] && [ -z "$REVERT_SECTION" ]; then
  FEDORA_PLASMA_GLOW_ASSUME="$ASSUME" fedora_hardware_preflight
fi

run_cmd() {
  local label="$1"
  shift
  printf '\n'
  ui_section "$label" 2>/dev/null || echo "$label"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] FEDORA_PLASMA_GLOW_ASSUME=%s' "${ASSUME:-interactive}"
    printf ' %q' "$@"
    printf '\n'
  else
    FEDORA_PLASMA_GLOW_ASSUME="$ASSUME" "$@"
  fi
}

run_section_by_id() {
  case "$1" in
  core) run_cmd "Core CLI and Shell" bash "$ROOT_DIR/install.sh" ;;
  extras) run_cmd "Optional Apps and Extras" bash "$ROOT_DIR/install-extras.sh" ;;
  kde) run_cmd "KDE Plasma Customization" bash "$ROOT_DIR/install-kde.sh" ;;
  ai) run_cmd "AI CLI Tools" bash "$ROOT_DIR/install-ai.sh" ;;
  security) run_cmd "Security Best Practices" bash "$ROOT_DIR/install-security.sh" ;;
  *)
    printf 'Unknown section: %s\n' "$1" >&2
    exit 1
    ;;
  esac
}

profile_sections() {
  case "$1" in
  minimal) printf '%s\n' core security ;;
  daily) printf '%s\n' core extras kde security ;;
  dev) printf '%s\n' core extras ai security ;;
  kde-polish) printf '%s\n' kde ;;
  media) printf '%s\n' core extras kde ;;
  gaming) printf '%s\n' core extras kde ;;
  privacy) printf '%s\n' core security ;;
  ai) printf '%s\n' core ai ;;
  full-send) printf '%s\n' core extras kde ai security ;;
  *)
    printf 'Unknown profile: %s\n' "$1" >&2
    exit 1
    ;;
  esac
}

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
  "" | " ") return 0 ;;
  r | R) return 1 ;;
  s | S) return 2 ;;
  q | Q) exit 0 ;;
  *)
    ui_warn "Unknown choice; skipping $title" 2>/dev/null || true
    return 2
    ;;
  esac
}

interactive_section() {
  local id="$1" title="$2" description="$3"
  if choose_action "$title" "$description"; then
    run_section_by_id "$id"
  else
    case "$?" in
    1) run_cmd "Revert $id" bash "$ROOT_DIR/revert.sh" "$id" ;;
    2) ui_info "Skipped $title" 2>/dev/null || true ;;
    esac
  fi
}

if [ "$RUN_AUDIT" -eq 1 ]; then
  run_cmd "Public audit" bash "$ROOT_DIR/scripts/audit-public.sh"
  exit 0
fi

if [ -n "$REVERT_SECTION" ]; then
  run_cmd "Revert $REVERT_SECTION" bash "$ROOT_DIR/revert.sh" "$REVERT_SECTION"
  exit 0
fi

if [ -n "$SECTION" ]; then
  run_section_by_id "$SECTION"
  exit 0
fi

if [ -n "$PROFILE" ]; then
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    run_section_by_id "$id"
  done < <(profile_sections "$PROFILE")
  exit 0
fi

interactive_section core "Core CLI and Shell" \
  "Portable command-line baseline, aliases, functions, prompt, zellij, fastfetch, optional Firefox, and optional terminal configs."

interactive_section extras "Optional Apps and Extras" \
  "Optional editors, terminal apps, monitoring tools, terminal art, Flatpak app groups, RPM Fusion media tools, and daily-use apps."

interactive_section kde "KDE Plasma Desktop Customization" \
  "KDE packages, lightweight theme assets, Panel Colorizer tuning, optional Rounded Corners, reviewed hotkeys, KWin plugins, and Konsole profile."

interactive_section ai "AI CLI Tools" \
  "Opt-in AI terminal tools like Codex CLI and Claude Code without copying API keys, account files, prompts, histories, or tool state."

interactive_section security "Security Best Practices" \
  "Practical Fedora security basics: SELinux tooling, firewalld, firmware update checks, optional dnf-automatic, and optional USBGuard policy generation."

ui_title "Guided Setup Complete" 2>/dev/null || echo "Guided setup complete"
