#!/usr/bin/env bash
# Shared state helpers for Fedora Plasma Glow Kit.

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${STATE_DIR:-$STATE_HOME/fedora-plasma-glow-kit}"
LEGACY_STATE_DIR="${LEGACY_STATE_DIR:-$STATE_HOME/fedora-starter-kit}"
STATE_FILE="${STATE_FILE:-$STATE_DIR/install.state}"
LEGACY_STATE_FILE="$LEGACY_STATE_DIR/install.state"

migrate_legacy_state() {
  umask 077
  mkdir -p "$STATE_DIR"
  if [ ! -f "$STATE_FILE" ] && [ -f "$LEGACY_STATE_FILE" ]; then
    cp -a "$LEGACY_STATE_FILE" "$STATE_FILE"
  fi
  touch "$STATE_FILE"
  chmod 600 "$STATE_FILE"
}

valid_state_key() {
  [[ "$1" =~ ^[a-z][a-z0-9_-]*$ ]]
}

valid_state_value() {
  [[ "$1" != *$'\n'* && "$1" != *$'\r'* ]]
}

append_state_line() {
  local line="$1"
  migrate_legacy_state
  grep -Fqx "$line" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$line" >>"$STATE_FILE"
}

record_state() {
  local key="$1" value="$2"
  valid_state_key "$key" || {
    printf 'Invalid state key: %s\n' "$key" >&2
    return 2
  }
  valid_state_value "$value" || {
    printf 'State values may not contain newlines.\n' >&2
    return 2
  }
  append_state_line "$key=$value"
  if [ -n "${GLOW_SECTION:-}" ]; then
    append_state_line "managed=$GLOW_SECTION|$key|$value"
  fi
  if [ -n "${GLOW_TRANSACTION_ID:-}" ]; then
    append_state_line "action=$GLOW_TRANSACTION_ID|$key|$value"
  fi
}

installed_package_names() {
  rpm -qa --qf '%{NAME}\n' | sort -u
}

dnf_install_tracked() {
  local manager="$1" before after package code=0
  shift
  before="$(mktemp)"
  after="$(mktemp)"
  installed_package_names >"$before"
  if sudo "$manager" "$@"; then
    code=0
  else
    code=$?
  fi
  installed_package_names >"$after"
  while IFS= read -r package; do
    [ -n "$package" ] || continue
    record_state dnf "$package"
  done < <(comm -13 "$before" "$after")
  rm -f "$before" "$after"
  return "$code"
}

state_values() {
  local key="$1"
  valid_state_key "$key" || return 2
  migrate_legacy_state
  grep "^${key}=" "$STATE_FILE" | cut -d= -f2- || true
}

state_values_for_section() {
  local section="$1" key="$2" prefix
  valid_state_key "$key" || return 2
  migrate_legacy_state
  prefix="managed=$section|$key|"
  awk -v prefix="$prefix" \
    'index($0, prefix) == 1 { print substr($0, length(prefix) + 1) }' \
    "$STATE_FILE"
}

remove_state_line() {
  local line="$1" temp
  migrate_legacy_state
  temp="$(mktemp "$STATE_DIR/install.state.XXXXXX")"
  grep -Fvx "$line" "$STATE_FILE" >"$temp" || true
  chmod 600 "$temp"
  mv -f "$temp" "$STATE_FILE"
}

remove_managed_state() {
  local section="$1" key="$2" value="$3" line
  if [ "$section" = "all" ]; then
    while IFS= read -r line; do
      case "$line" in
      managed=*"|$key|$value") remove_state_line "$line" ;;
      esac
    done <"$STATE_FILE"
  else
    remove_state_line "managed=$section|$key|$value"
  fi
  remove_state_line "$key=$value"
}

remove_managed_states_bulk() {
  local section="$1" key="$2" values_file temp
  shift 2
  [ "$#" -gt 0 ] || return 0
  migrate_legacy_state
  values_file="$(mktemp "$STATE_DIR/remove-values.XXXXXX")"
  temp="$(mktemp "$STATE_DIR/install.state.XXXXXX")"
  printf '%s\n' "$@" >"$values_file"
  awk -v section="$section" -v key="$key" '
    NR == FNR {
      remove_value[$0] = 1
      next
    }
    index($0, key "=") == 1 {
      value = substr($0, length(key) + 2)
      if (value in remove_value) next
    }
    index($0, "managed=") == 1 {
      count = split(substr($0, 9), fields, "|")
      if (count >= 3 && fields[2] == key) {
        value = substr(substr($0, 9), length(fields[1]) + length(fields[2]) + 3)
        if ((section == "all" || fields[1] == section) && (value in remove_value)) next
      }
    }
    { print }
  ' "$values_file" "$STATE_FILE" >"$temp"
  chmod 600 "$temp"
  mv -f "$temp" "$STATE_FILE"
  rm -f "$values_file"
}

begin_transaction() {
  local section="$1"
  migrate_legacy_state
  GLOW_TRANSACTION_ID="$(date -u +%s)-$$-$RANDOM"
  GLOW_SECTION="$section"
  export GLOW_TRANSACTION_ID GLOW_SECTION
  append_state_line "transaction=$GLOW_TRANSACTION_ID|$section|started"
}

complete_transaction() {
  [ -n "${GLOW_TRANSACTION_ID:-}" ] || return 0
  append_state_line "transaction=$GLOW_TRANSACTION_ID|${GLOW_SECTION:-unknown}|complete"
  unset GLOW_TRANSACTION_ID GLOW_SECTION
}

fail_transaction() {
  local code="${1:-1}"
  [ -n "${GLOW_TRANSACTION_ID:-}" ] || return 0
  append_state_line "transaction=$GLOW_TRANSACTION_ID|${GLOW_SECTION:-unknown}|failed:$code"
  unset GLOW_TRANSACTION_ID GLOW_SECTION
}

resolve_transactions() {
  local section="${1:-all}" resolution="${2:-reverted}"
  [ -f "$STATE_FILE" ] || [ -f "$LEGACY_STATE_FILE" ] || return 0
  migrate_legacy_state
  append_state_line \
    "transaction=resolution-$(date -u +%s)-$$-$RANDOM|$section|$resolution"
}
