# Release Testing

A release candidate is accepted only after the automated audit is green and
the following clean-system matrix passes.

| Target | Install | Rerun | Failure recovery | Full revert | GUI/tray |
| --- | --- | --- | --- | --- | --- |
| Fedora 44 KDE Plasma VM | Required | Required | Required | Required | Required |
| Fedora 44 GNOME VM | Required | Required | Required | Required | Required |
| Fedora 44 physical system | Required | Required | Required | Required | Required |

For every target:

1. Capture a clean snapshot.
2. Run dry-run and confirm no persistent writes.
3. Apply `minimal`, then rerun it and verify idempotence.
4. Apply the matching desktop-polish profile.
5. Interrupt one section and verify it appears as incomplete.
6. Resume or revert that section.
7. Apply `daily`, then revert `all`.
8. Compare packages, repositories, services, extensions, settings, and user
   files with the snapshot.
9. Exercise keyboard navigation, 100%/150%/200% scaling, dark/light themes,
   missing-tray fallback, notifications, and reduced motion.
10. Review diagnostics and exported reports for identifiers.

Silverblue, Kinoite, Fedora 43, and Fedora Rawhide must be rejected as
unsupported rather than partially modified.

## Disposable VM gate

The KDE and GNOME command-path matrix can be reproduced with the official
Fedora 44 Cloud Base image. The harness verifies the published image checksum,
boots a fresh KVM overlay for each desktop, runs install/rerun/failure recovery,
checks identifier-free diagnostics and headless GUI/tray fallback, then performs
a full revert and compares packages, repositories, and enabled services.

```bash
bash scripts/vm-release-test.sh \
  --image ~/Downloads/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
```

VM overlays default to the disk-backed
`${XDG_CACHE_HOME:-$HOME/.cache}/fedora-glow-kit/vm-tests` directory because
many Fedora systems mount `/tmp` as a size-limited tmpfs. Use
`--work-dir PATH` to select another location. The harness checks free capacity
before booting a guest; `--keep` preserves its disks, logs, and result files.

The physical-system row still requires a human-controlled snapshot and visual
checks. Do not run mutating release tests on an unsnapshotted daily-use system.

## Release signing gate

The protected Actions secrets `RPM_SIGNING_KEY_B64` and
`RPM_SIGNING_KEY_ID` must be configured before pushing a version tag. The
release workflow signs both RPM and source RPM packages, exports the public
key, signs `SHA256SUMS`, and publishes GitHub provenance attestations.

Expected public-key fingerprint:

```text
2568 7433 D39D 55AC 2549 18FC 100D AE86 F925 437B
```

After publication, download every release asset and verify:

```bash
gpg --import fedora-glow-kit-release-key.asc
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum --check SHA256SUMS
rpm --checksig fedora-glow-kit-*.rpm
```
