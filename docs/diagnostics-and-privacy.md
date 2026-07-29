# Diagnostics And Privacy Contract

Fedora Glow Kit has no telemetry, analytics, advertising identifier, crash
upload, account, or background network reporting.

`glow-kit diagnostics` reports only:

- product version
- operating-system name and major version
- normalized desktop type (`kde`, `gnome`, or `unknown`)
- supported-target result
- counts of kit-managed items and incomplete operations
- whether required commands are available

It does not collect usernames, home paths, hostnames, IP or MAC addresses,
serial numbers, UUIDs, disks, PCI devices, browser state, command history,
tokens, or file contents.

Reports print locally for review. Export is refused unless the user supplies
both `--export FILE` and `--confirm-export`. Exported files use mode `0600`.
Users may delete the report normally; the application retains no copy.
