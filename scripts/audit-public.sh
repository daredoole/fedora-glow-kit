#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

section() {
  printf '\n== %s ==\n' "$1"
}

check() {
  local label="$1"
  shift
  if "$@"; then
    printf '[OK] %s\n' "$label"
  else
    printf '[FAIL] %s\n' "$label"
    FAIL=1
  fi
}

section "Shell syntax"
while IFS= read -r script; do
  check "bash -n ${script#"$ROOT_DIR"/}" bash -n "$script"
done < <(find "$ROOT_DIR" -maxdepth 2 -path "$ROOT_DIR/.git" -prune -o -type f -name '*.sh' -print | sort)

section "ShellCheck"
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r script; do
    check "shellcheck ${script#"$ROOT_DIR"/}" shellcheck "$script"
  done < <(find "$ROOT_DIR" -maxdepth 2 -path "$ROOT_DIR/.git" -prune -o -type f -name '*.sh' -print | sort)
else
  printf '[WARN] shellcheck not installed; skipping\n'
fi

section "Public safety scan"
LOCAL_USER="$(id -un 2>/dev/null || true)"
check "credits file exists" test -f "$ROOT_DIR/CREDITS.md"
check "license file exists" test -f "$ROOT_DIR/LICENSE.md"
check "no private key or credential-shaped files" \
  test -z "$(find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -type f \( \
    -iname 'id_rsa' -o -iname 'id_ed25519' -o -iname '*.pem' -o -iname '*.key' -o \
    -iname '.env' -o -iname '*token*' -o -iname '*secret*' -o -iname '*credential*' \
  \) -print -quit)"

if [ -n "$LOCAL_USER" ]; then
  check "no local user paths or current username" \
    bash -c "cd '$ROOT_DIR' && ! rg -n --hidden --glob '!.git/**' --glob '!configs/kde/themes/**' --glob '!configs/kde/plasmoids/**' --glob '!*.png' '/home/[A-Za-z0-9_-]+|${LOCAL_USER}' ."
else
  check "no local user paths" \
    bash -c "cd '$ROOT_DIR' && ! rg -n --hidden --glob '!.git/**' --glob '!configs/kde/themes/**' --glob '!configs/kde/plasmoids/**' --glob '!*.png' '/home/[A-Za-z0-9_-]+' ."
fi

check "no generated icon theme caches" \
  test -z "$(find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -type f -name 'icon-theme.cache' -print -quit)"

check "uncredited staged theme assets are absent" \
  test -z "$(find "$ROOT_DIR/configs/kde/themes" \( -name 'Tokyo Night.colors' -o -name 'Sweet-Wallpapers' \) -print -quit)"

section "Repository size"
SIZE_MIB="$(du -sm "$ROOT_DIR" | awk '{print $1}')"
printf 'size: %s MiB\n' "$SIZE_MIB"
if [ "$SIZE_MIB" -gt 100 ]; then
  printf '[FAIL] repo is larger than 100 MiB; remove generated assets or move them to release artifacts\n'
  FAIL=1
else
  printf '[OK] repo is under 100 MiB\n'
fi

section "Result"
if [ "$FAIL" -eq 0 ]; then
  printf 'Public audit passed.\n'
else
  printf 'Public audit failed.\n'
fi
exit "$FAIL"
