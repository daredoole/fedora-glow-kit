# Changelog

## Unreleased

- Add the optional PySide6 control deck, system tray, XDG settings, and desktop entry.
- Add the `glow-kit` status, plan, apply, revert, update, diagnostics, and audit interface.
- Add an equivalent Fedora 44 GNOME polish profile with reversible settings.
- Centralize state under `fedora-plasma-glow-kit`, migrate legacy state, and record section-scoped transactions.
- Fix rollback reading the obsolete state path and cover packages, Flatpaks, remotes, COPRs, services, GNOME settings, and extensions.
- Replace direct `update` and `cleanup` aliases with preview-and-confirm helpers.
- Add RPM packaging, signed tag-release automation, checksums, SBOM generation, and provenance attestations.
- Expand tests for both desktops, state migration, privacy, safe aliases, QML loading, and dry-run profiles.
- Add a threat model, diagnostics privacy contract, and clean-system release matrix.
- Rename project to Fedora Plasma Glow Kit.
- Add flag-aware `manage.sh` with `--dry-run`, `--yes`, `--no`, `--profile`, `--section`, `--revert`, and `--audit`.
- Add profile scaffolding.
- Add stronger CI for audit, formatting, Markdown, workflow linting, and Fedora dry-run smoke tests.
- Add documentation for Fedora 44 KDE Plasma recommendations, apps, security, Firefox, AI tools, troubleshooting, recovery, private data policy, and architecture.
- Add shared helper library scaffolding.
- Improve public audit checks.
