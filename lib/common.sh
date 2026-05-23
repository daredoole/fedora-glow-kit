#!/usr/bin/env bash
# Shared CLI helpers for Fedora Plasma Glow Kit.

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

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
