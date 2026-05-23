#!/usr/bin/env bash

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_DIM=$'\033[2m'
  UI_CYAN=$'\033[36m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_BLUE=$'\033[34m'
  UI_MAGENTA=$'\033[35m'
else
  UI_RESET=''
  UI_BOLD=''
  UI_DIM=''
  UI_CYAN=''
  UI_GREEN=''
  UI_YELLOW=''
  UI_BLUE=''
  UI_MAGENTA=''
fi

ui_divider() {
  printf '%s%s%s\n' "$UI_DIM" '────────────────────────────────────────────────────────────' "$UI_RESET"
}

ui_title() {
  ui_divider
  printf '%s%s%s\n' "$UI_BOLD$UI_CYAN" "$1" "$UI_RESET"
  ui_divider
}

ui_section() {
  printf '\n%s◆ %s%s\n' "$UI_MAGENTA$UI_BOLD" "$1" "$UI_RESET"
}

ui_info() {
  printf '%s•%s %s\n' "$UI_BLUE" "$UI_RESET" "$1"
}

ui_ok() {
  printf '%s✓%s %s\n' "$UI_GREEN" "$UI_RESET" "$1"
}

ui_warn() {
  printf '%s!%s %s\n' "$UI_YELLOW" "$UI_RESET" "$1"
}

ui_intro() {
  [ -t 1 ] || return 0
  [ -z "${FEDORA_STARTER_NO_ANIMATION:-}" ] || return 0
  local frames=('▰▱▱▱▱' '▰▰▱▱▱' '▰▰▰▱▱' '▰▰▰▰▱' '▰▰▰▰▰')
  local frame
  printf '%s' "$UI_CYAN"
  for frame in "${frames[@]}"; do
    printf '\rFedora Glow Kit %s' "$frame"
    sleep 0.05
  done
  printf '\rFedora Glow Kit ready     %s\n' "$UI_RESET"
}
