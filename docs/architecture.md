# Architecture

## Entry points

- `manage.sh`: guided manager and CLI wrapper
- `install.sh`: core CLI and shell setup
- `install-extras.sh`: optional apps and heavier extras
- `install-kde.sh`: KDE Plasma customization
- `install-ai.sh`: opt-in AI CLI tools
- `install-security.sh`: practical Fedora security baseline
- `revert.sh`: revert kit-managed changes
- `scripts/audit-public.sh`: public-readiness audit
- `scripts/smoke-test.sh`: dry-run smoke test

## Shared libraries

- `lib/common.sh`: generic helpers
- `lib/state.sh`: install-state recording and legacy migration
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
