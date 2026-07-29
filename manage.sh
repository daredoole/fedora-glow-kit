#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSUME="${FEDORA_PLASMA_GLOW_ASSUME:-}"
DRY_RUN=0
PROFILE=""
SECTION=""
REVERT_SECTION=""
RUN_AUDIT=0
DESKTOP="auto"

SECTION_IDS=(core extras kde ai security)
SECTION_TITLES=(
  "Core CLI and Shell"
  "Optional Apps and Extras"
  "KDE Plasma Desktop Customization"
  "AI CLI Tools"
  "Security Best Practices"
)
SECTION_DESCRIPTIONS=(
  "Portable command-line baseline, aliases, functions, prompt, zellij, fastfetch, optional Firefox, and optional terminal configs."
  "Optional editors, terminal apps, monitoring tools, terminal art, Flatpak app groups, RPM Fusion media tools, and daily-use apps."
  "KDE packages, lightweight theme assets, Panel Colorizer tuning, optional Rounded Corners, reviewed hotkeys, KWin plugins, and Konsole profile."
  "Opt-in AI terminal tools like Codex CLI and Claude Code without copying API keys, account files, prompts, histories, or tool state."
  "Firewall, update hygiene, optional USBGuard review, dnf-automatic, Flatpak permission review, and other safe baseline checks."
)

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
  bash manage.sh --profile daily --desktop gnome
  bash manage.sh --no --section kde
  bash manage.sh --revert kde
  bash manage.sh --audit

Options:
  --dry-run            Print what would run without making changes
  --yes                Answer yes to installer prompts
  --no                 Answer no to installer prompts
  --profile NAME       minimal, daily, dev, kde-polish, gnome-polish, media, gaming, privacy, ai, full-send
  --desktop NAME       auto, kde, gnome
  --section NAME       core, extras, kde, gnome, ai, security
  --revert NAME        core, extras, kde, gnome, ai, security, all
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
  --desktop)
    DESKTOP="${2:-}"
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

case "$DESKTOP" in
auto | kde | gnome) ;;
*)
  printf 'Unknown desktop: %s\n' "$DESKTOP" >&2
  exit 1
  ;;
esac

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
# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/lib/state.sh" ] && . "$ROOT_DIR/lib/state.sh"

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
  local id="$1" label script code
  case "$id" in
  core)
    label="Core CLI and Shell"
    script="$ROOT_DIR/install.sh"
    ;;
  extras)
    label="Optional Apps and Extras"
    script="$ROOT_DIR/install-extras.sh"
    ;;
  kde)
    label="KDE Plasma Customization"
    script="$ROOT_DIR/install-kde.sh"
    ;;
  gnome)
    label="GNOME Desktop Customization"
    script="$ROOT_DIR/install-gnome.sh"
    ;;
  ai)
    label="AI CLI Tools"
    script="$ROOT_DIR/install-ai.sh"
    ;;
  security)
    label="Security Best Practices"
    script="$ROOT_DIR/install-security.sh"
    ;;
  *)
    printf 'Unknown section: %s\n' "$id" >&2
    exit 1
    ;;
  esac
  if [ "$DRY_RUN" -eq 1 ]; then
    run_cmd "$label" bash "$script"
    return
  fi
  begin_transaction "$id"
  if run_cmd "$label" bash "$script"; then
    complete_transaction
  else
    code=$?
    fail_transaction "$code"
    return "$code"
  fi
}

detected_desktop() {
  local current
  if [ "$DESKTOP" != "auto" ]; then
    printf '%s\n' "$DESKTOP"
    return
  fi
  current="${XDG_CURRENT_DESKTOP:-} ${XDG_SESSION_DESKTOP:-} ${DESKTOP_SESSION:-}"
  case "${current,,}" in
  *kde* | *plasma*) printf 'kde\n' ;;
  *gnome*) printf 'gnome\n' ;;
  *)
    printf 'Unable to detect KDE or GNOME; pass --desktop kde or --desktop gnome.\n' >&2
    return 1
    ;;
  esac
}

section_index_by_id() {
  local id="$1" i
  for i in "${!SECTION_IDS[@]}"; do
    [ "${SECTION_IDS[$i]}" = "$id" ] && {
      printf '%s\n' "$i"
      return 0
    }
  done
  return 1
}

profile_sections() {
  local desktop
  case "$1" in
  minimal) printf '%s\n' core security ;;
  daily)
    desktop="$(detected_desktop)" || exit 1
    printf '%s\n' core extras "$desktop" security
    ;;
  dev) printf '%s\n' core extras ai security ;;
  kde-polish) printf '%s\n' kde ;;
  gnome-polish) printf '%s\n' gnome ;;
  media | gaming)
    desktop="$(detected_desktop)" || exit 1
    printf '%s\n' core extras "$desktop"
    ;;
  privacy) printf '%s\n' core security ;;
  ai) printf '%s\n' core ai ;;
  full-send)
    desktop="$(detected_desktop)" || exit 1
    printf '%s\n' core extras "$desktop" ai security
    ;;
  *)
    printf 'Unknown profile: %s\n' "$1" >&2
    exit 1
    ;;
  esac
}

profile_label() {
  case "$1" in
  minimal) printf 'Minimal' ;;
  daily) printf 'Daily desktop' ;;
  dev) printf 'Developer' ;;
  kde-polish) printf 'KDE polish only' ;;
  media) printf 'Media desktop' ;;
  gaming) printf 'Gaming desktop' ;;
  privacy) printf 'Privacy baseline' ;;
  ai) printf 'AI CLI' ;;
  full-send) printf 'Full send' ;;
  *) printf '%s' "$1" ;;
  esac
}

set_selected_profile() {
  local profile="$1" id idx
  SELECTED=()
  for idx in "${!SECTION_IDS[@]}"; do
    SELECTED[idx]=0
  done
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    idx="$(section_index_by_id "$id")" || continue
    SELECTED[idx]=1
  done < <(profile_sections "$profile")
}

render_section_picker() {
  local cursor="$1" profile="$2" i mark pointer label
  printf '\033[?25l'
  printf '\033[H\033[2J'
  ui_title "Fedora Plasma Glow Kit Guided Setup" 2>/dev/null || printf 'Fedora Plasma Glow Kit Guided Setup\n'
  printf '\nChoose what to run. Use arrows or j/k to move, Space to toggle, Enter to run.\n'
  printf 'Profile: %s\n\n' "$(profile_label "$profile")"
  for i in "${!SECTION_IDS[@]}"; do
    mark=" "
    [ "${SELECTED[$i]:-0}" -eq 1 ] && mark="x"
    pointer=" "
    [ "$i" -eq "$cursor" ] && pointer=">"
    label="${SECTION_TITLES[$i]}"
    printf ' %s [%s] %-34s %s\n' "$pointer" "$mark" "$label" "${SECTION_DESCRIPTIONS[$i]}"
  done
  printf '\n'
  printf 'Controls: ↑/↓ move  Space toggle  Enter run  p profile  a all  n none  r revert highlighted  q quit\n'
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Mode: dry-run, no system changes will be made.\n'
  fi
}

read_menu_key() {
  local key rest
  IFS= read -r -s -n 1 key || {
    printf 'enter\n'
    return
  }
  if [ "$key" = $'\033' ]; then
    IFS= read -r -s -n 2 -t 0.05 rest || true
    case "$rest" in
    "[A") printf 'up\n' ;;
    "[B") printf 'down\n' ;;
    *) printf 'escape\n' ;;
    esac
    return
  fi
  case "$key" in
  "") printf 'enter\n' ;;
  " ") printf 'space\n' ;;
  k | K) printf 'up\n' ;;
  j | J) printf 'down\n' ;;
  p | P) printf 'profile\n' ;;
  a | A) printf 'all\n' ;;
  n | N) printf 'none\n' ;;
  r | R) printf 'revert\n' ;;
  q | Q) printf 'quit\n' ;;
  *) printf 'other\n' ;;
  esac
}

section_picker() {
  local cursor=0 key idx profile_idx=1
  local profiles=(minimal daily dev kde-polish media gaming privacy ai full-send)
  set_selected_profile daily
  trap 'printf "\033[?25h\n"' EXIT
  while true; do
    render_section_picker "$cursor" "${profiles[$profile_idx]}"
    key="$(read_menu_key)"
    case "$key" in
    up)
      if [ "$cursor" -eq 0 ]; then
        cursor=$((${#SECTION_IDS[@]} - 1))
      else
        cursor=$((cursor - 1))
      fi
      ;;
    down)
      cursor=$(((cursor + 1) % ${#SECTION_IDS[@]}))
      ;;
    space)
      if [ "${SELECTED[$cursor]:-0}" -eq 1 ]; then
        SELECTED[cursor]=0
      else
        SELECTED[cursor]=1
      fi
      ;;
    profile)
      profile_idx=$(((profile_idx + 1) % ${#profiles[@]}))
      set_selected_profile "${profiles[$profile_idx]}"
      ;;
    all)
      for idx in "${!SECTION_IDS[@]}"; do
        SELECTED[idx]=1
      done
      ;;
    none)
      for idx in "${!SECTION_IDS[@]}"; do
        SELECTED[idx]=0
      done
      ;;
    revert)
      printf '\033[?25h\033[H\033[2J'
      run_cmd "Revert ${SECTION_IDS[$cursor]}" bash "$ROOT_DIR/revert.sh" "${SECTION_IDS[$cursor]}"
      trap - EXIT
      return 0
      ;;
    enter)
      printf '\033[?25h\033[H\033[2J'
      trap - EXIT
      local ran=0
      for idx in "${!SECTION_IDS[@]}"; do
        if [ "${SELECTED[$idx]:-0}" -eq 1 ]; then
          run_section_by_id "${SECTION_IDS[$idx]}"
          ran=1
        fi
      done
      [ "$ran" -eq 1 ] || ui_info "No sections selected." 2>/dev/null || true
      return 0
      ;;
    quit | escape)
      printf '\033[?25h\033[H\033[2J'
      trap - EXIT
      return 0
      ;;
    esac
  done
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

if [ -t 0 ] && [ -t 1 ]; then
  section_picker
  exit 0
fi

interactive_section core "Core CLI and Shell" \
  "Portable command-line baseline, aliases, functions, prompt, zellij, fastfetch, optional Firefox, and optional terminal configs."

interactive_section extras "Optional Apps and Extras" \
  "Optional editors, terminal apps, monitoring tools, terminal art, Flatpak app groups, RPM Fusion media tools, and daily-use apps."

interactive_section kde "KDE Plasma Desktop Customization" \
  "KDE packages, lightweight theme assets, Panel Colorizer tuning, optional Rounded Corners, reviewed hotkeys, KWin plugins, and Konsole profile."

interactive_section gnome "GNOME Desktop Customization" \
  "GNOME tools, reversible appearance settings, optional AppIndicator tray support, and a curated Fedora Workstation profile."

interactive_section ai "AI CLI Tools" \
  "Opt-in AI terminal tools like Codex CLI and Claude Code without copying API keys, account files, prompts, histories, or tool state."

interactive_section security "Security Best Practices" \
  "Practical Fedora security basics: SELinux tooling, firewalld, firmware update checks, optional dnf-automatic, and optional USBGuard policy generation."

ui_title "Guided Setup Complete" 2>/dev/null || echo "Guided setup complete"
