#!/usr/bin/env bash
set -Eeuo pipefail

DESKTOP="${1:-}"
ARCHIVE="${2:-/tmp/fedora-glow-kit.tar.gz}"
RESULTS_DIR="${RESULTS_DIR:-$HOME/glow-kit-qa-results}"

case "$DESKTOP" in
kde | gnome) ;;
*)
  printf 'Usage: %s kde|gnome [source-archive]\n' "$0" >&2
  exit 2
  ;;
esac

mkdir -p "$RESULTS_DIR"
exec > >(tee "$RESULTS_DIR/$DESKTOP.log") 2>&1

on_error() {
  local code=$?
  printf 'FAIL: line=%s exit=%s command=%s\n' \
    "${BASH_LINENO[0]:-unknown}" "$code" "$BASH_COMMAND" >&2
  exit "$code"
}
trap on_error ERR

step() {
  printf '\n== %s ==\n' "$1"
}

assert_json_value() {
  local path="$1" key="$2" expected="$3"
  python3 - "$path" "$key" "$expected" <<'PY'
import json
import sys

path, key, expected = sys.argv[1:]
value = json.load(open(path, encoding="utf-8"))[key]
if str(value).lower() != expected.lower():
    raise SystemExit(f"{key}: expected {expected!r}, got {value!r}")
PY
}

step "Validate clean Fedora target"
# shellcheck disable=SC1091
. /etc/os-release
test "$ID" = fedora
test "$VERSION_ID" = 44
test ! -e /run/ostree-booted

step "Install test-only prerequisites"
sudo dnf upgrade --refresh -y
sudo dnf install -y --skip-unavailable \
  desktop-file-utils python3 python3-pyside6 qt6-qtdeclarative shellcheck

WORK_DIR="$(mktemp -d "$HOME/fedora-glow-kit.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
tar -xzf "$ARCHIVE" -C "$WORK_DIR"
ROOT_DIR="$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d -name 'fedora-glow-kit-*' -print -quit)"
test -n "$ROOT_DIR"
cd "$ROOT_DIR"

step "Capture baseline"
rpm -qa --qf '%{NAME}\n' | sort -u >"$RESULTS_DIR/packages.before"
sudo dnf repolist --enabled -q | sort >"$RESULTS_DIR/repos.before"
systemctl list-unit-files --state=enabled --no-legend | sort >"$RESULTS_DIR/services.before"

step "Run automated audit and regression suites"
bash scripts/audit-public.sh
python3 -m unittest discover -s tests -p 'test_*.py'
bash tests/run-shell-tests.sh

step "Prove dry-run makes no persistent state"
test ! -e "$HOME/.local/state/fedora-plasma-glow-kit"
bash manage.sh --dry-run --profile daily --desktop "$DESKTOP" --yes
test ! -e "$HOME/.local/state/fedora-plasma-glow-kit"

step "Apply minimal profile and prove rerun idempotence"
bash manage.sh --profile minimal --desktop "$DESKTOP" --yes
rpm -qa --qf '%{NAME}\n' | sort -u >"$RESULTS_DIR/packages.minimal"
bash manage.sh --profile minimal --desktop "$DESKTOP" --yes
rpm -qa --qf '%{NAME}\n' | sort -u >"$RESULTS_DIR/packages.minimal-rerun"
cmp "$RESULTS_DIR/packages.minimal" "$RESULTS_DIR/packages.minimal-rerun"

step "Apply desktop polish and exercise failure recovery"
bash manage.sh --profile "$DESKTOP-polish" --desktop "$DESKTOP" --yes
if DNF=/bin/false bash manage.sh --section "$DESKTOP" --desktop "$DESKTOP" --yes; then
  printf 'Injected package-manager failure unexpectedly succeeded.\n' >&2
  exit 1
fi
bash bin/glow-kit status --desktop "$DESKTOP" --json >"$RESULTS_DIR/status.failed.json"
assert_json_value "$RESULTS_DIR/status.failed.json" incomplete_transactions 1
bash manage.sh --section "$DESKTOP" --desktop "$DESKTOP" --yes
bash bin/glow-kit status --desktop "$DESKTOP" --json >"$RESULTS_DIR/status.recovered.json"
assert_json_value "$RESULTS_DIR/status.recovered.json" incomplete_transactions 0

step "Apply daily profile"
bash manage.sh --profile daily --desktop "$DESKTOP" --yes

step "Validate private diagnostics"
bash bin/glow-kit diagnostics --desktop "$DESKTOP" --json >"$RESULTS_DIR/diagnostics.json"
python3 - "$RESULTS_DIR/diagnostics.json" <<'PY'
import json
import pathlib
import sys

report = json.dumps(json.load(open(sys.argv[1], encoding="utf-8"))).lower()
for forbidden in ("glowqa", "localhost", "/home/", "serial", "mac_address", "ip_address"):
    if forbidden in report:
        raise SystemExit(f"diagnostics leaked forbidden identifier: {forbidden}")
if "local-only" not in report:
    raise SystemExit("diagnostics privacy contract missing")
PY
test "$(stat -c %a "$HOME/.local/state/fedora-plasma-glow-kit/install.state")" = 600

step "Smoke-test GUI and tray fallback headlessly"
if timeout 8 env QT_QPA_PLATFORM=offscreen bash bin/glow-kit-gui; then
  gui_code=0
else
  gui_code=$?
fi
if timeout 8 env QT_QPA_PLATFORM=offscreen bash bin/glow-kit-gui --tray; then
  tray_code=0
else
  tray_code=$?
fi
case "$gui_code:$tray_code" in
0:0 | 0:124 | 124:0 | 124:124) ;;
*)
  printf 'GUI/tray smoke failed: gui=%s tray=%s\n' "$gui_code" "$tray_code" >&2
  exit 1
  ;;
esac

step "Full revert and clean-state comparison"
bash manage.sh --revert all --desktop "$DESKTOP" --yes
bash bin/glow-kit status --desktop "$DESKTOP" --json >"$RESULTS_DIR/status.reverted.json"
assert_json_value "$RESULTS_DIR/status.reverted.json" incomplete_transactions 0
assert_json_value "$RESULTS_DIR/status.reverted.json" managed_items 0
rpm -qa --qf '%{NAME}\n' | sort -u >"$RESULTS_DIR/packages.after"
sudo dnf repolist --enabled -q | sort >"$RESULTS_DIR/repos.after"
systemctl list-unit-files --state=enabled --no-legend | sort >"$RESULTS_DIR/services.after"
cmp "$RESULTS_DIR/packages.before" "$RESULTS_DIR/packages.after"
cmp "$RESULTS_DIR/repos.before" "$RESULTS_DIR/repos.after"
cmp "$RESULTS_DIR/services.before" "$RESULTS_DIR/services.after"

printf '\nPASS: Fedora 44 %s release gate\n' "$DESKTOP"
