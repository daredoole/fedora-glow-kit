# Architecture

## Entry points

- `bin/glow-kit`: stable CLI for status, planning, applying, reverting, updates, diagnostics, and audits
- `bin/glow-kit-gui`: optional unprivileged Qt control deck and tray helper
- `manage.sh`: guided manager and CLI wrapper
- `install.sh`: core CLI and shell setup
- `install-extras.sh`: optional apps and heavier extras
- `install-kde.sh`: KDE Plasma customization
- `install-gnome.sh`: GNOME Workstation customization
- `install-ai.sh`: opt-in AI CLI tools
- `install-security.sh`: practical Fedora security baseline
- `revert.sh`: revert kit-managed changes
- `scripts/audit-public.sh`: public-readiness audit
- `scripts/smoke-test.sh`: dry-run smoke test

## Shared libraries

- `glow_kit/core.py`: profiles, desktop detection, state/status, settings, diagnostics, and terminal launching
- `glow_kit/cli.py`: validated public command interface and JSON contracts
- `glow_kit/gui.py`: PySide6 bridge, tray, local preferences, and terminal handoff
- `lib/common.sh`: generic helpers
- `lib/state.sh`: private transaction/state recording, section ownership, and legacy migration
- `lib/packages.sh`: package helpers

## Design principles

- interactive by default
- dry-run capable
- idempotent
- backups before writes
- risky actions opt-in
- no private data
- no silent third-party repositories
- no monitor-specific KDE panel copies
- no privileged GUI or resident daemon
- local-only diagnostics with no personal or device identifiers
- Fedora packages by default; third-party sources remain explicit opt-ins
