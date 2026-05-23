# Excluded Private Items

The audit used conservative filtering. Items below were skipped or replaced with generic samples.

## Excluded From Install Script

- Exact `~/.zshrc` and `~/.bashrc`: contained useful patterns, but also personal aliases and machine-specific setup.
- Project path aliases such as `~/projects/...` and named personal project shortcuts: not portable.
- Aliases `rat` and `zellij-new`: flagged as personal or environment-specific.
- NVM/corepack wrapper functions from shell config: useful locally, but shell-manager state should be installed intentionally by the target user.
- Exact `~/.config/starship.toml`: private-pattern match; replaced with a clean portable prompt.
- Exact `~/.config/zellij/config.kdl`: private-pattern match and many custom keybinds; replaced with a minimal portable config.
- Zellij mobile layouts: may contain device-specific workflow assumptions; manual review needed.
- Exact `~/.config/fastfetch/config.jsonc`: private-pattern match and host/hardware details; replaced with a generic config.
- `~/.local/bin` scripts: many are useful locally, but names indicate machine/window/project workflows. Review before sharing.
- `dotenv` and `keyring` in `~/.local/bin`: sensitive-looking helper names, excluded.
- Browser, VPN, client, and identity-adjacent config directories: excluded by policy.
- Flatpak apps tied to identity, messaging, finance, VPN, or private workflows: not installed by default.
- Firefox profile data: excluded entirely. No cookies, history, sessions, extension storage, logins, Sync state, search history, site permissions, or browser account data were copied.
- Browser bookmarks are only handled by the optional Windows preflight export, which writes portable bookmark HTML files and does not copy browser profiles.
- Firefox extension settings: excluded because extension storage can contain account state, site lists, browsing-derived data, tokens, or personal preferences.
- Firefox built-in Mozilla system extensions: excluded from extension install policy because Firefox manages them itself.
- `Remove Paywall`: excluded from the install policy because the audit did not identify a safe public AMO install URL.
- Firefox VPN/account extension state: excluded. The optional policy can install the public extension package, but does not include any VPN credentials, server choices, identities, or account state.
- Exact Konsole `konsolerc`: not copied because it controls whole-app state. A portable profile and color scheme are provided instead.
- Konsole bookmarks files: excluded because they can contain local paths, hosts, or workflow history.
- Exact kitty backup/theme directory: not copied wholesale. A sanitized kitty config and portable theme file are provided instead.
- `ambient-*` aliases and local animation/window scripts: excluded because they depend on local scripts not included in the starter kit and may contain machine-specific assumptions.
- `dbx-fedora`: excluded because it references a specific Distrobox container name. The generic `dbx` alias is included instead.
- The failed Mesa freeworld package transaction was not treated as installed state. Extras use `--skip-unavailable` for those packages because RPM Fusion Mesa versions can temporarily lag Fedora updates.
- Full local KWin script directories were not copied automatically. Detected script IDs and enabled plugin IDs are included, and the installer can install reviewed packaged script directories if they are placed under `configs/kde/kwin-scripts/`.
- KWin tiling UUID groups from `kwinrc` were excluded because they are monitor/layout specific.
- KDE theme assets were included only from generic local theme directories. KDE app state, bookmarks, recent files, monitor layout, task switcher state, activities, and user-specific Plasma layout files were not copied.
- Large downloaded icon theme directories were excluded from the public repo because they made the repo too large and included generated cache files. `papirus-icon-theme` is installed from Fedora packages instead.
- `Tokyo Night.colors` and `Sweet-Wallpapers` were removed from the public kit because the staged files did not include enough source/license metadata for clean attribution.
- Plasma panel/taskbar layout file `plasma-org.kde.plasma.desktop-appletsrc` was not copied because it is monitor/user specific and can corrupt another user's desktop layout. Portable widget support packages are installed instead.
- The full source panel layout was not copied. Only the portable panel alignment fix is included, because full panel applet order, screen IDs, widget IDs, and monitor placement are user-specific.
- KWin Rounded Corners is included only as an opt-in third-party COPR install. The COPR is not silently enabled and no local KWin effect configuration is copied.

## Template Example Only

Do not copy real SSH or work aliases. Use placeholders in documentation only:

```sh
alias server='ssh user@example-host'
```
