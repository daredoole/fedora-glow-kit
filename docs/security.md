# Security Model

Fedora Plasma Glow Kit should be safe to run on a friend's machine.

## Never copy

- SSH keys
- Git credentials
- browser profiles
- browser cookies
- browser history
- extension storage
- VPN configs
- Tailscale state
- API keys
- AI CLI auth files
- work aliases
- private hostnames
- project paths

## Prompt before

- RPM Fusion
- COPRs
- global npm packages
- Firefox enterprise policy
- USBGuard rules
- system services
- KDE panel mutations
- KWin scripts
- theme overwrites

## Defaults

- SELinux should remain enforcing.
- firewalld should be enabled.
- fwupd should be used for firmware checks.
- USBGuard should be generated for review before enabling blocking.
