# Fedora 44 KDE Plasma Recommendations

Fedora Plasma Glow Kit is designed for a normal Fedora KDE Plasma daily-driver setup: polished, useful, reversible, and not creepy about copying private data.

## First boot baseline

Recommended first steps:

```bash
sudo dnf upgrade --refresh
fwupdmgr refresh --force
fwupdmgr get-devices
fwupdmgr get-updates
```

Do firmware updates intentionally. Do not force firmware updates inside an unattended setup script.

## Flatpak and Flathub

Fedora Workstation, Silverblue, and Kinoite ship with Flatpak by default, and Flathub is the common source for desktop apps. KDE installs can manually add Flathub with:

```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Use Flatseal and Warehouse to review Flatpak permissions.

## RPM Fusion

RPM Fusion is useful for multimedia, gaming, and codec gaps, but it is still a third-party repository. Keep it opt-in and explain what it unlocks before enabling it.

## KDE Plasma polish

Safe defaults:

- Papirus icons
- KDE add-ons
- KDE Connect
- sensible animation speed
- optional Panel Colorizer presets
- optional KWin scripts only when reviewed
- no monitor-specific panel layout copy

Avoid blindly overwriting:

- `plasma-org.kde.plasma.desktop-appletsrc`
- `kwinrc`
- `kglobalshortcutsrc`
- existing theme/plugin directories

## Security defaults

Recommended:

- Keep SELinux enforcing
- Keep firewalld enabled
- Use fwupd for firmware checks
- Treat USBGuard as review-first
- Use a password manager
- Do not sync browser profiles, cookies, SSH keys, VPN state, tokens, or work aliases

## Good apps to offer

Daily:

- Bitwarden
- Flatseal
- Warehouse
- LocalSend
- Brave or Firefox
- KWrite
- FeatherPad
- KDE Connect

Developer:

- VS Code
- Podman Desktop
- Distrobox
- GitHub CLI
- git-delta
- lazygit
- uv
- pipx
- direnv
- just

Media/gaming:

- Steam
- Heroic Games Launcher
- Moonlight
- Bottles
- VLC or Haruna
- Tidal Hi-Fi unofficial clients where desired

AI:

- Codex CLI
- Claude Code CLI

No AI tool should receive copied API keys, tokens, prompts, histories, or account state from the source machine.
