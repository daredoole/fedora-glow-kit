#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

section() {
  printf '\n== %s ==\n' "$1"
}

mark_fail() {
  printf '[FAIL] %s\n' "$1"
  FAIL=1
}

check() {
  local label="$1"
  shift
  if "$@"; then
    printf '[OK] %s\n' "$label"
  else
    mark_fail "$label"
  fi
}

script_list() {
  find "$ROOT_DIR" \
    -path "$ROOT_DIR/.git" -prune -o \
    -path "$ROOT_DIR/configs/kde/themes" -prune -o \
    -path "$ROOT_DIR/configs/kde/plasmoids" -prune -o \
    -type f -name '*.sh' -print | sort
}

section "Shell syntax"
while IFS= read -r script; do
  check "bash -n ${script#"$ROOT_DIR"/}" bash -n "$script"
done < <(script_list)

section "ShellCheck"
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r script; do
    check "shellcheck ${script#"$ROOT_DIR"/}" shellcheck "$script"
  done < <(script_list)
else
  printf '[WARN] shellcheck not installed; skipping\n'
fi

section "Repository required files"
check "credits file exists" test -f "$ROOT_DIR/CREDITS.md"
check "license file exists" test -f "$ROOT_DIR/LICENSE.md"
check "security policy exists" test -f "$ROOT_DIR/SECURITY.md"
check "audit workflow exists" test -f "$ROOT_DIR/.github/workflows/audit.yml"
check "dependabot config exists" test -f "$ROOT_DIR/.github/dependabot.yml"
check "code owners file exists" test -f "$ROOT_DIR/.github/CODEOWNERS"
check "contributing file exists" test -f "$ROOT_DIR/CONTRIBUTING.md"
check "changelog file exists" test -f "$ROOT_DIR/CHANGELOG.md"
check "RPM spec exists" test -f "$ROOT_DIR/packaging/fedora-glow-kit.spec"
check "RPM lint policy exists" test -f "$ROOT_DIR/.rpmlintrc"
check "CLI manual page exists" test -f "$ROOT_DIR/packaging/glow-kit.1"
check "GUI manual page exists" test -f "$ROOT_DIR/packaging/glow-kit-gui.1"
check "CLI contract exists" test -f "$ROOT_DIR/docs/cli.md"
check "threat model exists" test -f "$ROOT_DIR/docs/threat-model.md"
check "diagnostics privacy contract exists" test -f "$ROOT_DIR/docs/diagnostics-and-privacy.md"
check "VM release harness exists" test -f "$ROOT_DIR/scripts/vm-release-test.sh"
check "VM guest gate exists" test -f "$ROOT_DIR/tests/vm/guest-release-gate.sh"

section "Application validation"
check "Python sources compile" python3 -m compileall -q "$ROOT_DIR/glow_kit"
check "Python tests pass" \
  bash -c 'cd "$1" && python3 -m unittest discover -s tests -p "test_*.py"' _ "$ROOT_DIR"
if command -v desktop-file-validate >/dev/null 2>&1; then
  check "desktop entry validates" \
    desktop-file-validate "$ROOT_DIR/packaging/fedora-glow-kit.desktop"
else
  printf '[WARN] desktop-file-validate not installed; skipping\n'
fi

section "Public safety scan"
check "no private key or credential-shaped files" \
  test -z "$(find "$ROOT_DIR" \
    -path "$ROOT_DIR/.git" -prune -o \
    -type f \( \
    -iname 'id_rsa' -o -iname 'id_ed25519' -o -iname '*.pem' -o -iname '*.key' -o \
    -iname '.env' -o -iname '*token*' -o -iname '*secret*' -o -iname '*credential*' \
    \) -print -quit)"

if command -v rg >/dev/null 2>&1; then
  check "no local home paths" \
    bash -c 'cd "$1" && ! rg -n --hidden --glob "!.git/**" --glob "!configs/kde/themes/**" --glob "!configs/kde/plasmoids/**" --glob "!*.png" "/home/[A-Za-z0-9_-]+|C:\\\\Users\\\\" .' _ "$ROOT_DIR"

  check "no personal project aliases or host shortcuts" \
    bash -c 'cd "$1" && ! rg -n --hidden --glob "!.git/**" --glob "!EXCLUDED_PRIVATE_ITEMS.md" --glob "!scripts/audit-public.sh" "alias[[:space:]]+[^=]+=.*/(projects|agents)/|~/projects|~/agents|WattRat|HomeRat|smartrat|fedora-agent|zellij-new|linuxbrew|ambient-saver|curl ifconfig\\.me" .' _ "$ROOT_DIR"

  check "no personal shell dumps" \
    bash -c 'cd "$1" && ! rg -n --hidden --glob "!.git/**" --glob "!EXCLUDED_PRIVATE_ITEMS.md" --glob "!scripts/audit-public.sh" "alias[[:space:]]+(wr|cdhr|agent|rat|dbx-fedora)=|alias[[:space:]]+p=.cd ~/projects" .' _ "$ROOT_DIR"

  check "no README placeholder clone URL" \
    bash -c 'cd "$1" && ! rg -n --hidden --glob "!.git/**" --glob "!scripts/audit-public.sh" "github.com/<you>|<you>/" .' _ "$ROOT_DIR"

  check "no legacy starter-kit branding in runtime paths" \
    bash -c 'cd "$1" && ! rg -n "STATE_DIR=.*fedora-starter-kit|state_dir=.*fedora-starter-kit" install*.sh manage.sh revert.sh shell glow_kit' _ "$ROOT_DIR"
else
  printf '[WARN] ripgrep not installed; skipping text safety scans\n'
fi

section "Secret scanners"
if command -v gitleaks >/dev/null 2>&1; then
  check "Gitleaks working tree scan" \
    gitleaks dir "$ROOT_DIR" --redact --no-banner --no-color
  if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    check "Gitleaks history scan" \
      gitleaks git "$ROOT_DIR" --redact --no-banner --no-color
  fi
else
  printf '[WARN] gitleaks not installed; skipping secret scan\n'
fi

check "no generated icon theme caches" \
  test -z "$(find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -type f -name 'icon-theme.cache' -print -quit)"

if [ -d "$ROOT_DIR/configs/kde/themes" ]; then
  check "uncredited staged theme assets are absent" \
    test -z "$(find "$ROOT_DIR/configs/kde/themes" \( -name 'Tokyo Night.colors' -o -name 'Sweet-Wallpapers' \) -print -quit)"
else
  printf '[OK] theme asset directory absent or not bundled\n'
fi

section "Repository size"
SIZE_MIB="$(du -sm "$ROOT_DIR" | awk '{print $1}')"
printf 'size: %s MiB\n' "$SIZE_MIB"
if [ "$SIZE_MIB" -gt 100 ]; then
  mark_fail "repo is larger than 100 MiB; remove generated assets or move them to release artifacts"
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
