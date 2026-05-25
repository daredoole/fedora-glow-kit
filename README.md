# Fedora Plasma Glow Kit

A polished, safe, reversible Fedora 44 KDE Plasma setup kit.


A polished, safe, reversible Fedora 44 KDE Plasma setup kit.

Fedora Plasma Glow Kit is a safe, reusable Fedora starter kit built from a real Fedora KDE/Workstation setup. Its goal is to give a friend a polished Linux baseline: useful CLI tools, shell quality-of-life, terminal customization, Firefox privacy/performance settings, KDE theming, optional desktop apps, and optional developer utilities.

It is intentionally conservative. Installers ask before changing configs, back up files before edits, skip existing theme assets, and avoid copying private data such as browser profiles, SSH keys, tokens, work aliases, VPN state, cookies, history, credentials, or machine-specific project paths.

The installers are interactive. They prompt by section, such as packages, shell helpers, terminal configs, Firefox, KDE themes, KWin scripts, desktop apps, and extras. When an existing config file is changed, the script prints a unified diff immediately so you can see exactly what changed.

Credits for bundled assets, optional extension installs, themes, and upstream tools are tracked in [CREDITS.md](CREDITS.md).

## Quick Start

Guided setup with install/revert/skip choices per section:

```bash
git clone https://github.com/daredoole/fedora-plasma-glow-kit.git
cd fedora-plasma-glow-kit
bash manage.sh
```

If you are already inside the repo:

```bash
cd fedora-plasma-glow-kit
bash manage.sh
```

Core install:

```bash
cd fedora-plasma-glow-kit
bash install.sh
```

Optional extras:

```bash
cd fedora-plasma-glow-kit
bash install-extras.sh
```

KDE customization:

```bash
cd fedora-plasma-glow-kit
bash install-kde.sh
```

Security best-practice setup:

```bash
cd fedora-plasma-glow-kit
bash install-security.sh
```

AI CLI tools:

```bash
cd fedora-plasma-glow-kit
bash install-ai.sh
```

Revert kit-managed config changes:

```bash
cd fedora-plasma-glow-kit
bash revert.sh
```

Public-readiness audit before sharing:

```bash
cd fedora-plasma-glow-kit
bash scripts/audit-public.sh
```

Security policy:

```bash
less SECURITY.md
```

Disable terminal animation or color:

```bash
FEDORA_STARTER_NO_ANIMATION=1 bash install.sh
NO_COLOR=1 bash install.sh
```

## Mock Run / Dry Run

Use `manage.sh --dry-run` to preview what would run without invoking installers, writing files, installing packages, enabling services, or changing your system:

```bash
bash manage.sh --dry-run --profile daily
bash manage.sh --dry-run --section extras
bash manage.sh --dry-run --section kde
```

## Fresh Fedora Hardware Preflight

On a fresh Fedora install, update the system and firmware before applying desktop customization:

```bash
sudo dnf upgrade --refresh
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update
reboot
```

This matters most on new laptops, AMD APUs/GPUs, Wi-Fi chipsets, docks, and touchpads because the newest kernel, Mesa, and firmware packages can affect hardware behavior. The installer prompts for this check before making changes, but it does not run firmware updates automatically.

## Windows SSD Dual Boot Preflight

Before shrinking a Windows 11 `C:` partition to make room for Fedora on the same SSD, run the audit script from an elevated PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\windows\Fedora-DualBoot-Preflight.ps1 -FedoraSpaceGB 120
```

To also export supported Windows browser bookmarks as HTML files for import on Fedora:

```powershell
.\scripts\windows\Fedora-DualBoot-Preflight.ps1 -FedoraSpaceGB 120 -ExportBrowserBookmarks
```

The default Windows reserve is 80 GB. For example, `-FedoraSpaceGB 74` requires about 154 GB free before shrinking because the script reserves 74 GB for Fedora plus 80 GB left free for Windows. You can lower the reserve with `-MinimumWindowsFreeAfterShrinkGB`, but leaving Windows with only a few GB free is not recommended.

The script checks admin rights, GPT/UEFI layout, BitLocker, Fast Startup, free space, recovery partitions, and the Windows-supported shrink range. It does not resize the disk or change Windows settings; if the checks pass, it prints the `Resize-Partition` command to run manually after backups and recovery-key prep.

Bookmark export is opt-in. It exports Chrome, Edge, Brave, and Vivaldi bookmark HTML files only; it does not copy browser profiles, cookies, passwords, sessions, history, Sync state, or extension data. In Fedora Firefox, import the HTML file with Bookmarks > Manage bookmarks > Import and Backup > Import Bookmarks from HTML.

## Package Source Policy

The kit prefers Fedora-managed packages first. CLI tools, KDE utilities, Catfish, ripgrep, codecs, security tools, and most extras install through `dnf` when available, so the installed system is not dependent on this repository after setup.

Flatpak is used for optional desktop apps where that is the cleaner upstream distribution path. npm is limited to explicit opt-in AI CLI tools. RPM Fusion and COPR actions stay prompt-gated because they add third-party package sources.


## Profiles

The guided installer is still interactive by default, but the manager also supports profile and dry-run modes:

```bash
bash manage.sh --dry-run --profile daily
bash manage.sh --yes --profile minimal
bash manage.sh --section kde
bash manage.sh --revert kde
bash manage.sh --audit
```

Available profiles:

- `minimal`
- `daily`
- `dev`
- `kde-polish`
- `media`
- `gaming`
- `privacy`
- `ai`
- `full-send`

See `docs/` for Fedora 44 KDE Plasma recommendations, app choices, security model, Firefox policy notes, AI tool notes, troubleshooting, and recovery.

## What It Does

`install.sh` installs the core command-line setup and optional safe configs:

- zsh, zsh autosuggestions/syntax/history helpers, starship, zellij, fastfetch
- ripgrep (`rg`), fd, bat, eza, fzf, zoxide
- jq, yq, btop, tree, tealdeer/tldr
- git, GitHub CLI, git-delta, git-lfs
- curl, wget, unzip, p7zip, rsync
- nano, vim
- Python, pip, pipx, uv
- Podman, podman-compose, distrobox
- direnv and just
- Flatpak and optional Flathub setup
- optional `zsh` default login shell setup
- optional polished starter `~/.zshrc` profile with history, completion, fzf, zoxide, direnv, Atuin, zsh plugin, and Starship hooks
- shell aliases/functions
- optional Firefox `user.js`
- optional Firefox extension policy
- optional kitty, Konsole, Powerline-style starship, zellij, and fastfetch configs

The shipped Starship prompt uses a Powerline/Nerd Font style with colored segments for user, directory, Git, active language runtimes, Docker context, and time. Install or select a Nerd Font in your terminal for the icons and separators to render correctly.

`install-extras.sh` installs optional heavier tools and app groups:

- Neovim, micro, kitty, WezTerm, lazygit, ripgrep
- lightweight GUI utilities: Catfish file search, KWrite, FeatherPad, GNOME Text Editor, and micro
- Go, Rust, Docker Compose
- nvtop, iotop, sysstat, VAAPI/VDPAU tools
- optional Tailscale package and separate `tailscaled` service enablement
- terminal art tools like cmatrix, asciiquarium, pipes, cbonsai, fortune, cowsay, lolcat, figlet, toilet, nyancat, sl, and tty-clock
- optional RPM Fusion repositories
- optional media codecs and Mesa VAAPI/VDPAU packages
- optional Bluetooth headphone codec/support packages
- optional Flatpak groups for daily apps, gaming/media, messaging/social, and advanced/privacy/dev tools

The recommended simple editor path is KWrite plus FeatherPad. They open quickly, support syntax highlighting and themes, and are better suited for quick config edits than a full IDE. Catfish adds a lightweight graphical file search option. The shell helper `qedit FILE` opens KWrite first, then FeatherPad, then GNOME Text Editor, then falls back to `$EDITOR`.

`install-kde.sh` installs KDE desktop customization:

- kdeplasma-addons
- papirus-icon-theme
- variety
- qt6-qttools
- Plasma taskbar/widget support packages
- optional portable starter panel widgets for Icon Tasks, tray, clock, weather placeholder, system monitor sensors, and battery/power
- KDE Connect tray integration
- Bluedevil Bluetooth tray support
- optional Bluetooth/headphone codec support
- downloaded KDE themes from `configs/kde/themes`
- optional third-party KWin Rounded Corners effect through `matinlotfali/KDE-Rounded-Corners`, off by default
- KDE animation speed factor `0.35`
- optional NetworkManager wait-online disable prompt for faster boots
- optional Plasma panel launcher-centering fix: left widgets stay left, Icon Tasks or Task Manager are centered between spacers, tray/clock stay right
- optional bundled Panel Colorizer widget install, skipped when already present
- optional Panel Colorizer tuning for transparent empty spacers, larger colorized widget margins, and translucent island borders/backgrounds
- optional Sweet-Dark-transparent Aurorae window decoration
- detected KWin plugin enablement for `krohnkite`, `rememberwindowpositions`, and `endtask-modern`
- reviewed KWin script packages placed under `configs/kde/kwin-scripts/<script-id>/`
- optional recommended KDE hotkeys after showing the shortcut list for review

`install-security.sh` installs and configures opt-in Fedora security basics:

- firewalld
- SELinux tooling and troubleshooting utilities
- fwupd firmware update timer
- optional dnf-automatic timer
- optional USBGuard policy generation for manual review

It does not silently enable disruptive USB blocking or firewall lockdowns.

`install-ai.sh` installs opt-in AI terminal tools:

- OpenAI Codex CLI via `npm install -g @openai/codex`
- Anthropic Claude Code via `npm install -g @anthropic-ai/claude-code`

No AI API keys, account files, tokens, prompts, histories, or tool state are copied.

`manage.sh` opens a keyboard-driven setup menu when run in an interactive terminal:

- Up/Down or `j`/`k`: move through sections
- Space: select or unselect a section
- Enter: run selected sections
- `p`: cycle starter profiles such as daily, dev, KDE polish, and full-send
- `a` / `n`: select all or none
- `r`: revert/uninstall kit-managed changes for the highlighted section
- `q`: quit

Non-interactive shells keep the plain guided fallback, and flags such as `--profile`, `--section`, `--dry-run`, `--yes`, and `--no` still work for scripts and repeatable installs.

`revert.sh` restores config backups or removes config files that still match the kit copy. It only prompts to uninstall DNF, Flatpak, npm, and COPR entries recorded as installed or enabled by this kit, so it avoids removing tools the user already had.

Future installs record kit-installed DNF, Flatpak, and npm AI packages in:

```bash
~/.local/state/fedora-starter-kit/install.state
```

Revert/uninstall prompts only target those recorded packages.

## Included Configs

- `shell/aliases.sh`
- `shell/functions.sh`
- `shell/ui.sh`
- `configs/zshrc.sample`
- `configs/starship.toml`
- `configs/zellij/config.kdl`
- `configs/fastfetch/config.jsonc`
- `configs/fastfetch/dog.png`
- `configs/fastfetch/dog_transparent.png`
- `configs/firefox/user.js`
- `configs/firefox/policies.json`
- `configs/kitty/kitty.conf`
- `configs/kitty/current-theme.conf`
- `configs/konsole/FedoraStarter.profile`
- `configs/konsole/Sweet-Starter.colorscheme`
- `configs/kde/themes`
- `configs/kde/kwin-enabled.conf`
- `configs/kde/recommended-hotkeys.md`
- `configs/kde/panel-layout-notes.md`

## KDE Themes

Downloaded non-default themes included:

- Plasma: Layan, Orchis-dark, Sweet, Sweet-Ambar-Blue
- Look and feel: Orchis dark
- Color schemes: Orchis, OrchisDark, Sweet, SweetAmbarBlue
- Aurorae decorations: Orchis variants and Sweet variants
- Icons: Papirus through Fedora packages. Large downloaded icon packs are documented but not bundled to keep the public repo small.
- Wallpapers: Orchis

Theme install is non-destructive: existing target paths are skipped, not overwritten.

Panel/taskbar layout files are not copied wholesale because Plasma panel config is monitor and user specific. The kit installs useful widget support instead: Icon Tasks, KDE Connect, Bluetooth/Bluedevil, media/volume, clipboard, device notifier, weather support, system monitor/sensor support, battery/power support, activity pager, Panel Colorizer, and KDE add-ons.

The KDE installer includes an optional portable starter panel widget preset. It can add generic widgets for Icon Tasks, system tray, clock, weather, system monitor sensors, and battery/power. It does not set a private weather location, sensor source, screen ID, or exact personal applet layout; those stay user-reviewed in Plasma edit mode.

The KDE installer includes an optional Panel Colorizer pass. It does not copy a full personal panel layout. It makes empty spacer widgets transparent, increases colorized widget island spacing/margins so icons are not tight against rounded borders, softens island opacity/borders, and keeps the center Icon Tasks launcher icons full size with a narrower vertical margin override.

The optional Rounded Corners effect uses a third-party COPR. The installer shows the COPR name and package before enabling it, defaults to no, and records the repo only if this kit enabled it.

The KDE installer can optionally disable `NetworkManager-wait-online.service`. This may reduce boot waiting, but it is off by default because it can affect services that explicitly wait for network-online at boot.

## Firefox

`configs/firefox/user.js` contains sanitized portable Firefox preferences for performance, reduced speculative network activity, hardware video acceleration, privacy controls, telemetry reduction, and UI quality-of-life.

`configs/firefox/policies.json` installs public enabled extensions through Firefox enterprise policy using `normal_installed`, so the user can disable or remove them. It does not include extension settings, extension storage, accounts, passwords, cookies, history, sync state, or browser profile data.

## Safety

The scripts are designed to be idempotent and non-destructive:

- already-installed commands are skipped
- unavailable Fedora packages are skipped instead of failing the whole setup
- existing dotfiles are backed up before replacement
- most config writes require confirmation
- config changes show a unified diff as they happen
- new files are reported as created
- existing KDE theme paths are skipped
- existing KWin scripts are skipped
- KWin script directories are not bundled unless deliberately reviewed and placed in the kit
- third-party COPR repositories are opt-in and clearly labeled before enablement
- RPM Fusion Mesa packages use `--skip-unavailable` because Fedora/RPM Fusion Mesa versions can temporarily mismatch
- bundled third-party assets are credited in `CREDITS.md`; assets without clear source/license metadata are excluded from the public repo

## Credits And License

See `CREDITS.md` for expanded attribution covering bundled KDE assets, Panel Colorizer, Firefox extensions, optional third-party repositories, and recommended upstream tools.

The starter-kit scripts and sanitized sample configs are MIT licensed. Bundled or referenced third-party assets keep their own upstream licenses; see `LICENSE.md` and `CREDITS.md`.

The public repo also includes GitHub hardening files:

- `.github/workflows/audit.yml` runs the public audit on pushes and pull requests.
- `.github/dependabot.yml` checks GitHub Actions updates weekly.
- `.github/CODEOWNERS` requires owner review when branch protection is enabled.
- `SECURITY.md` documents private vulnerability reporting and supply-chain contribution rules.

## Security Best Practices

This kit keeps the security defaults strong without making the system annoying:

- keep SELinux enforcing
- keep firewalld enabled on the public zone unless the user knowingly changes it
- use fwupd for firmware update checks
- use Flatpak permissions intentionally, with Flatseal/Warehouse available for review
- use a password manager instead of syncing secrets in dotfiles
- avoid copying browser profiles, cookies, extension storage, SSH keys, VPN state, and Git credentials
- use USBGuard only after reviewing the generated policy, because enabling it blindly can block legitimate devices
- use dnf-automatic as a timer only if the user wants automated update checks/download policy

Fedora documents firewalld and SELinux as core security layers, and Fedora’s dnf-automatic documentation describes timer-based automatic update workflows. KDE stores global shortcuts in user config and exposes shortcut management through System Settings.

## Undo

Remove installed config files:

```bash
rm -f ~/.config/shell/aliases.sh
rm -f ~/.config/shell/functions.sh
rm -f ~/.config/starship.toml
rm -f ~/.config/zellij/config.kdl
rm -f ~/.config/fastfetch/config.jsonc
rm -f ~/.mozilla/firefox/*.default-release/user.js
sudo rm -f /etc/firefox/policies/policies.json
rm -f ~/.config/kitty/kitty.conf
rm -f ~/.config/kitty/current-theme.conf
rm -f ~/.local/share/konsole/FedoraStarter.profile
rm -f ~/.local/share/konsole/Sweet-Starter.colorscheme
```

Restore a backup created by the installer:

```bash
ls -la ~/.zshrc.bak.* ~/.bashrc.bak.* ~/.config/starship.toml.bak.* 2>/dev/null
mv ~/.zshrc.bak.YYYYMMDD-HHMMSS ~/.zshrc
```

Undo KDE animation speed:

```bash
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 1.0
qdbus org.kde.KWin /KWin reconfigure
```

Remove packages manually:

```bash
sudo dnf remove PACKAGE_NAME
```

## Privacy Notes

This kit intentionally does not copy SSH keys, Git credentials, browser profiles, browser history, cookies, extension storage, VPN/Tailscale configs, private aliases, project paths, hostnames, tokens, or exact personal dotfiles. See `EXCLUDED_PRIVATE_ITEMS.md`.
