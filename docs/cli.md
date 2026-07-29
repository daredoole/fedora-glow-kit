# Command-Line Interface

`glow-kit` is the stable automation surface for Fedora Glow Kit. Run
`./bin/glow-kit` from a source checkout or `glow-kit` after RPM installation.

## Commands

| Command | Purpose | Mutates the system |
| --- | --- | --- |
| `status [--json]` | Show target support and kit-managed state | No |
| `plan [--profile NAME] [--desktop TARGET] [--json]` | Resolve an install plan | No |
| `apply [--profile NAME] [--desktop TARGET] [--yes]` | Run a Fedora 44 install flow | Yes |
| `revert [SECTION] [--yes]` | Remove only recorded kit changes | Yes |
| `update [--apply] [--yes] [--json]` | Preview or run safe updates | Only with `--apply` |
| `diagnostics [--json]` | Print a local identifier-free report | No |
| `diagnostics --export FILE --confirm-export` | Save a reviewed private report | Writes one file |
| `audit` | Run the public-readiness checks | No system changes |

`TARGET` is `auto`, `kde`, or `gnome`. `apply` refuses non-Fedora 44 and
immutable/OSTree targets before starting an installer. `plan`, `status`,
diagnostics, audit, and revert remain available for inspection and recovery.

## Automation Contract

`status`, `plan`, `update`, and `diagnostics` support `--json`. Every JSON
document includes `schema_version`; consumers should reject versions they do
not understand and ignore unknown fields.

Example:

```bash
./bin/glow-kit plan --profile daily --desktop kde --json
./bin/glow-kit status --json
```

The plan response includes the resolved desktop, selected profile, ordered
actions, per-action risk, and whether confirmation is required. Status reports
only normalized operating-system/desktop values and aggregate state counts. It
does not report usernames, hostnames, home paths, addresses, serial numbers, or
device inventory.

## Exit Codes

- `0`: success
- `1`: user cancellation or an invoked maintenance command failed
- `2`: invalid request, unsupported apply target, missing runtime, or refused
  diagnostic export
- Other non-zero values may be propagated from an installer or update command.

Mutating commands are deliberately visible and terminal-based. The GUI previews
the same plan and launches this CLI in a terminal; it does not request
privileges itself.
