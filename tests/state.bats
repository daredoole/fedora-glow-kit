#!/usr/bin/env bats

setup() {
  export TEST_HOME="$BATS_TEST_TMPDIR/home"
  export HOME="$TEST_HOME"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$HOME" "$XDG_STATE_HOME/fedora-starter-kit"
}

@test "legacy state migrates to the canonical private path" {
  printf 'dnf=legacy-package\n' > "$XDG_STATE_HOME/fedora-starter-kit/install.state"
  run bash -c '. ./lib/state.sh; migrate_legacy_state; state_values dnf'
  [ "$status" -eq 0 ]
  [ "$output" = "legacy-package" ]
  [ "$(stat -c %a "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state")" = "600" ]
}

@test "transactions record section-scoped managed items" {
  run bash -c '. ./lib/state.sh; begin_transaction core; record_state dnf example; complete_transaction'
  [ "$status" -eq 0 ]
  run grep -F 'managed=core|dnf|example' "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state"
  [ "$status" -eq 0 ]
  run grep -E 'transaction=.*\\|core\\|complete' "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state"
  [ "$status" -eq 0 ]
}

@test "revert resolution records transaction recovery" {
  run bash -c '. ./lib/state.sh; begin_transaction core; fail_transaction 1; resolve_transactions core reverted'
  [ "$status" -eq 0 ]
  run grep -E 'transaction=resolution-.*\|core\|reverted' \
    "$XDG_STATE_HOME/fedora-plasma-glow-kit/install.state"
  [ "$status" -eq 0 ]
}

@test "state rejects embedded newlines" {
  run bash -c '. ./lib/state.sh; record_state dnf $'"'"'bad\nvalue'"'"''
  [ "$status" -eq 2 ]
}
