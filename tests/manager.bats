#!/usr/bin/env bats

@test "GNOME daily profile previews the GNOME installer" {
  run env NO_COLOR=1 FEDORA_STARTER_NO_ANIMATION=1 \
    bash manage.sh --dry-run --profile daily --desktop gnome
  [ "$status" -eq 0 ]
  [[ "$output" == *"install-gnome.sh"* ]]
  [[ "$output" != *"install-kde.sh"* ]]
}

@test "KDE daily profile previews the KDE installer" {
  run env NO_COLOR=1 FEDORA_STARTER_NO_ANIMATION=1 \
    bash manage.sh --dry-run --profile daily --desktop kde
  [ "$status" -eq 0 ]
  [[ "$output" == *"install-kde.sh"* ]]
  [[ "$output" != *"install-gnome.sh"* ]]
}

@test "safe update aliases point at confirmed functions" {
  run bash -c 'source shell/functions.sh; source shell/aliases.sh; alias update; alias cleanup'
  [ "$status" -eq 0 ]
  [[ "$output" == *"glow_update"* ]]
  [[ "$output" == *"glow_cleanup"* ]]
}

@test "noninteractive cleanup never invokes package removal" {
  fakebin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fakebin"
  printf '#!/usr/bin/env bash\nprintf called >>"%s"\n' "$BATS_TEST_TMPDIR/calls" > "$fakebin/sudo"
  chmod +x "$fakebin/sudo"
  run env PATH="$fakebin:$PATH" bash -c 'source shell/functions.sh; glow_cleanup'
  [ "$status" -eq 1 ]
  [ ! -e "$BATS_TEST_TMPDIR/calls" ]
}
