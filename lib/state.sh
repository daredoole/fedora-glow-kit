#!/usr/bin/env bash
# Shared state helpers for Fedora Plasma Glow Kit.

STATE_DIR="${STATE_DIR:-$HOME/.local/state/fedora-plasma-glow-kit}"
LEGACY_STATE_DIR="${LEGACY_STATE_DIR:-$HOME/.local/state/fedora-starter-kit}"
STATE_FILE="${STATE_FILE:-$STATE_DIR/install.state}"
LEGACY_STATE_FILE="$LEGACY_STATE_DIR/install.state"

migrate_legacy_state() {
  mkdir -p "$STATE_DIR"
  if [ ! -f "$STATE_FILE" ] && [ -f "$LEGACY_STATE_FILE" ]; then
    cp -a "$LEGACY_STATE_FILE" "$STATE_FILE"
  fi
}

record_state() {
  local key="$1" value="$2"
  migrate_legacy_state
  grep -Fqx "$key=$value" "$STATE_FILE" 2>/dev/null || printf '%s=%s\n' "$key" "$value" >>"$STATE_FILE"
}

state_values() {
  local key="$1"
  migrate_legacy_state
  [ -f "$STATE_FILE" ] || return 0
  grep "^${key}=" "$STATE_FILE" | cut -d= -f2- || true
}
