# Threat Model

## Security boundary

The GUI and tray always run as the signed-in user. They inspect only the kit's
own state and start the same visible terminal workflow used by source installs.
They never run as root, retain authentication, or expose a local network
service.

System changes are performed by reviewed shell entry points. `sudo` prompts are
visible in the terminal. The kit does not install a privileged daemon or Polkit
helper.

## Protected assets

- user configuration and backups
- package, Flatpak, repository, extension, and service state
- the integrity of downloaded packages and bundled desktop assets
- personal identifiers, credentials, browser state, and device information

## Main threats and controls

| Threat | Control |
| --- | --- |
| Unintended system changes | Dry-run/plan output, explicit prompts, section-scoped transactions |
| Incomplete or over-broad rollback | Record only resources newly created or enabled by the kit |
| Command injection | Fixed command arrays, validated profile/section names, no `eval` |
| Privilege escalation | No privileged GUI/daemon; `sudo` remains interactive and visible |
| Supply-chain compromise | Fedora packages by default, opt-in repositories, checksums, SBOM, signed RPM |
| Secret or identifier disclosure | Gitleaks history/tree scans and identifier-free diagnostics schema |
| Malicious profile/state content | Fixed profiles, validated state keys, newline rejection, private permissions |

Third-party COPRs, Flatpak remotes, extensions, and media repositories remain
separate opt-in actions. The release gate permits no unresolved critical or
high-severity findings.
