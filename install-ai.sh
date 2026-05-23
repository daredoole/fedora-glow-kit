#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGED=()
SKIPPED=()

# shellcheck source=/dev/null
# shellcheck disable=SC1091
[ -f "$ROOT_DIR/shell/ui.sh" ] && . "$ROOT_DIR/shell/ui.sh"
ui_intro 2>/dev/null || true
ui_title "Fedora Glow Kit AI Tools" 2>/dev/null || echo "Fedora Glow Kit AI Tools"

ask() {
  local prompt="$1" default="${2:-n}" reply
  read -r -p "$prompt [$default] " reply || true
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

record_state() {
  local key="$1" value="$2" state_dir="$HOME/.local/state/fedora-starter-kit"
  mkdir -p "$state_dir"
  grep -Fqx "$key=$value" "$state_dir/install.state" 2>/dev/null || printf '%s=%s\n' "$key" "$value" >> "$state_dir/install.state"
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
printf 'Hermes: no trusted local command/package was detected; this script only runs HERMES_INSTALL_COMMAND if you provide it.\n'
printf 'No API keys, tokens, account files, or AI tool state are copied.\n\n'

if ask "Install OpenAI Codex CLI?" "y"; then
  install_npm_global_if_missing codex @openai/codex
fi

if ask "Install Anthropic Claude Code CLI?" "y"; then
  install_npm_global_if_missing claude @anthropic-ai/claude-code
fi

if ask "Install Hermes using HERMES_INSTALL_COMMAND, if set?" "n"; then
  if [ -n "${HERMES_INSTALL_COMMAND:-}" ]; then
    bash -c "$HERMES_INSTALL_COMMAND"
    CHANGED+=("ran HERMES_INSTALL_COMMAND")
  else
    SKIPPED+=("Hermes install skipped; HERMES_INSTALL_COMMAND not set")
  fi
fi

echo
ui_title "AI Tools Summary" 2>/dev/null || echo "AI tools summary"
printf 'Changed:\n'; printf '  - %s\n' "${CHANGED[@]:-(none)}"
printf 'Skipped:\n'; printf '  - %s\n' "${SKIPPED[@]:-(none)}"
