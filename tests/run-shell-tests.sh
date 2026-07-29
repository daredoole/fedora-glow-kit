#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
export TEST_DIR
trap 'rm -rf "$TEST_DIR"' EXIT

export HOME="$TEST_DIR/home"
export XDG_STATE_HOME="$TEST_DIR/state"
export NO_COLOR=1
export FEDORA_STARTER_NO_ANIMATION=1
mkdir -p "$HOME" "$XDG_STATE_HOME/fedora-starter-kit" "$TEST_DIR/bin"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

printf 'dnf=legacy-package\n' > "$XDG_STATE_HOME/fedora-starter-kit/install.state"
bash -c '. "$1/lib/state.sh"; migrate_legacy_state; state_values dnf' _ "$ROOT_DIR" |
  grep -Fqx legacy-package || fail "legacy state migration"
[ "$(stat -c %a "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state")" = "600" ] ||
  fail "state file permissions"

bash -c '. "$1/lib/state.sh"; begin_transaction core; record_state dnf example; complete_transaction' _ "$ROOT_DIR"
grep -Fqx 'managed=core|dnf|example' \
  "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state" ||
  fail "section-scoped transaction state"

bash "$ROOT_DIR/manage.sh" --dry-run --profile daily --desktop kde |
  grep -F install-kde.sh >/dev/null || fail "KDE profile plan"
bash "$ROOT_DIR/manage.sh" --dry-run --profile daily --desktop gnome |
  grep -F install-gnome.sh >/dev/null || fail "GNOME profile plan"
FEDORA_PLASMA_GLOW_ASSUME=yes bash "$ROOT_DIR/manage.sh" --dry-run --section core |
  grep -F 'FEDORA_PLASMA_GLOW_ASSUME=yes' >/dev/null ||
  fail "environment-provided assumption mode was not preserved"

bash -c 'source "$1/shell/functions.sh"; source "$1/shell/aliases.sh"; alias update; alias cleanup' _ "$ROOT_DIR" |
  grep -F glow_update >/dev/null || fail "safe update alias"

cat > "$TEST_DIR/bin/sudo" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$TEST_DIR/sudo.calls"
printf 'sudo %s\n' "\$*" >>"$TEST_DIR/ops.calls"
if [ "\${1:-}" = dnf ] && [ "\${2:-}" = remove ]; then
  for package in "\$@"; do
    case "\$package" in
      revert-package) touch "$TEST_DIR/revert-package.removed" ;;
      flatpak) touch "$TEST_DIR/flatpak-package.removed" ;;
    esac
  done
fi
if [ "\${1:-}" = dnf ] && [ "\${2:-}" = install ]; then
  for package in "\$@"; do
    case "\$package" in
      track-root) touch "$TEST_DIR/track-install.done" ;;
      baseline-dependent) touch "$TEST_DIR/baseline-dependent.restored" ;;
    esac
  done
fi
exit 0
EOF
cat > "$TEST_DIR/bin/rpm" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-qa" ]; then
  /usr/bin/rpm "$@"
  [ ! -f "$TEST_DIR/track-install.done" ] || printf 'tracked-dependency\n'
  if [ ! -f "$TEST_DIR/revert-package.removed" ] ||
    [ -f "$TEST_DIR/baseline-dependent.restored" ]; then
    printf 'baseline-dependent\n'
  fi
  exit 0
fi
if [ "${1:-}" = "-q" ] && [ "${2:-}" = "revert-package" ]; then
  [ ! -f "$TEST_DIR/revert-package.removed" ] || exit 1
  exit 0
fi
if [ "${1:-}" = "-q" ] && [ "${2:-}" = "flatpak" ]; then
  [ ! -f "$TEST_DIR/flatpak-package.removed" ] || exit 1
  exit 0
fi
exec /usr/bin/rpm "$@"
EOF
chmod +x "$TEST_DIR/bin/sudo"
chmod +x "$TEST_DIR/bin/rpm"

if PATH="$TEST_DIR/bin:$PATH" bash -c 'source "$1/shell/functions.sh"; glow_cleanup' _ "$ROOT_DIR" < /dev/null; then
  fail "noninteractive cleanup should be refused"
fi
[ ! -e "$TEST_DIR/sudo.calls" ] || fail "noninteractive cleanup invoked sudo"

PATH="$TEST_DIR/bin:$PATH" bash -c \
  '. "$1/lib/state.sh"; begin_transaction core; dnf_install_tracked dnf install -y track-root; complete_transaction' \
  _ "$ROOT_DIR"
grep -Fqx 'managed=core|dnf|tracked-dependency' \
  "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state" ||
  fail "DNF transaction dependencies were not recorded"

printf '%s\n' \
  'dnf=revert-package' \
  'managed=extras|dnf|revert-package' \
  'managed=extras|dnf_restore|restore-package' \
  > "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state"
PATH="$TEST_DIR/bin:$PATH" DNF=dnf FEDORA_PLASMA_GLOW_ASSUME=yes \
  bash "$ROOT_DIR/revert.sh" extras > /dev/null
grep -Fqx 'dnf remove -y --no-autoremove revert-package' "$TEST_DIR/sudo.calls" ||
  fail "revert did not use canonical section state"
grep -Fqx 'dnf install -y --allowerasing restore-package' "$TEST_DIR/sudo.calls" ||
  fail "revert did not restore a replaced package"
grep -Fqx 'dnf install -y --allowerasing baseline-dependent' "$TEST_DIR/sudo.calls" ||
  fail "revert did not restore a pre-existing dependent package"
if grep -Fq 'revert-package' "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state"; then
  fail "reverted state entry was not cleared"
fi
if grep -Fq 'restore-package' "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state"; then
  fail "restored state entry was not cleared"
fi
PATH="$TEST_DIR/bin:$PATH" DNF=dnf FEDORA_PLASMA_GLOW_ASSUME=yes \
  bash "$ROOT_DIR/revert.sh" extras > /dev/null ||
  fail "revert was not idempotent with empty managed package sets"

cat > "$TEST_DIR/bin/flatpak" <<'EOF'
#!/usr/bin/env bash
printf 'flatpak %s\n' "$*" >>"$TEST_DIR/ops.calls"
exit 0
EOF
chmod +x "$TEST_DIR/bin/flatpak"
rm -f "$TEST_DIR/ops.calls" "$TEST_DIR/revert-package.removed"
printf '%s\n' \
  'dnf=flatpak' \
  'flatpak_remote=flathub' \
  'managed=core|dnf|flatpak' \
  'managed=core|flatpak_remote|flathub' \
  > "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state"
PATH="$TEST_DIR/bin:$PATH" DNF=dnf FEDORA_PLASMA_GLOW_ASSUME=yes \
  bash "$ROOT_DIR/revert.sh" all > /dev/null ||
  fail "full revert exited before teardown ordering could be verified"
remote_line="$(grep -nF 'flatpak remote-delete --user flathub' "$TEST_DIR/ops.calls" | cut -d: -f1 || true)"
dnf_line="$(grep -nF 'sudo dnf remove -y --no-autoremove flatpak' "$TEST_DIR/ops.calls" | cut -d: -f1 || true)"
[ -n "$remote_line" ] && [ -n "$dnf_line" ] && [ "$remote_line" -lt "$dnf_line" ] ||
  fail "full revert did not remove Flatpak remotes before the Flatpak package"

printf '[OK] portable shell behavior tests passed\n'
