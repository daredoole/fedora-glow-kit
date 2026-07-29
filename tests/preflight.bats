#!/usr/bin/env bats

setup() {
	export RELEASE_FILE="$BATS_TEST_TMPDIR/os-release"
	export OSTREE_MARKER="$BATS_TEST_TMPDIR/ostree-booted"
}

@test "Fedora 44 Workstation passes the support gate" {
	printf 'ID=fedora\nVERSION_ID=44\nVARIANT_ID=workstation\n' >"$RELEASE_FILE"
	run bash -c \
		'. ./lib/preflight.sh; require_supported_fedora "$1" "$2"' \
		_ "$RELEASE_FILE" "$OSTREE_MARKER"
	[ "$status" -eq 0 ]
}

@test "a different Fedora release is rejected before installation" {
	printf 'ID=fedora\nVERSION_ID=43\nVARIANT_ID=workstation\n' >"$RELEASE_FILE"
	run bash -c \
		'. ./lib/preflight.sh; require_supported_fedora "$1" "$2"' \
		_ "$RELEASE_FILE" "$OSTREE_MARKER"
	[ "$status" -eq 1 ]
	[[ "$output" == *"supports Fedora 44 only"* ]]
}

@test "immutable Fedora variants are rejected before installation" {
	printf 'ID=fedora\nVERSION_ID=44\nVARIANT_ID=kinoite\n' >"$RELEASE_FILE"
	run bash -c \
		'. ./lib/preflight.sh; require_supported_fedora "$1" "$2"' \
		_ "$RELEASE_FILE" "$OSTREE_MARKER"
	[ "$status" -eq 1 ]
	[[ "$output" == *"immutable Fedora variants"* ]]
}
