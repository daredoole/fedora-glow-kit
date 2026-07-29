#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGED=()
SKIPPED=()

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/lib/state.sh" ] && . "$ROOT_DIR/lib/state.sh"
ui_intro 2>/dev/null || true
ui_title "Fedora Plasma Glow Kit AI Tools" 2>/dev/null || echo "Fedora Plasma Glow Kit AI Tools"

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

install_npm_global_if_missing() {
  local cmd="$1" pkg="$2"
  if command_exists "$cmd"; then
    SKIPPED+=("$cmd already present")
    return
  fi
  if ! command_exists npm; then
    SKIPPED+=("npm unavailable for $pkg")
    return
  fi
  npm install -g "$pkg"
  record_state "npm" "$pkg"
  CHANGED+=("installed npm package $pkg")
}

ui_section "AI tool notes" 2>/dev/null || true
printf 'Codex CLI: official OpenAI npm package @openai/codex.\n'
printf 'Claude Code: official Anthropic npm package @anthropic-ai/claude-code.\n'
printf 'No API keys, tokens, account files, or AI tool state are copied.\n\n'

if ask "Install OpenAI Codex CLI?" "y"; then
  install_npm_global_if_missing codex @openai/codex
fi

if ask "Install Anthropic Claude Code CLI?" "y"; then
  install_npm_global_if_missing claude @anthropic-ai/claude-code
fi

echo
ui_title "AI Tools Summary" 2>/dev/null || echo "AI tools summary"
printf 'Changed:\n'
printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'
printf '  - %s\n' "${SKIPPED[@]:-(none)}"
