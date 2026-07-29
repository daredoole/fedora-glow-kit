# App Catalog

This catalog is intentionally opinionated, reversible, and package-manager first.

## Core CLI

| App | Source | What it does |
| --- | --- | --- |
| Firefox | DNF | Web browser used for the optional hardened policy/user.js setup. |
| zsh | DNF | Interactive shell with strong completion and plugin support. |
| zsh-autosuggestions | DNF | Inline command suggestions from history and completions. |
| zsh-syntax-highlighting | DNF | Live shell command syntax highlighting. |
| zsh-history-substring-search | DNF | Up/down history search using the typed prefix. |
| starship | DNF | Fast cross-shell prompt; the kit ships a Powerline/Nerd Font theme. |
| zellij | DNF | Terminal workspace, panes, and sessions. |
| fastfetch | DNF | System summary for terminal screenshots and diagnostics. |
| ripgrep (`rg`) | DNF | Fast recursive text search. |
| fd | DNF | Fast friendly file finder. |
| bat | DNF | Syntax-highlighted file viewer. |
| eza | DNF | Modern `ls` replacement with icons and Git status. |
| fzf | DNF | Fuzzy finder for shell workflows. |
| zoxide | DNF | Smarter `cd` based on directory history. |
| jq | DNF | JSON query and formatting tool. |
| yq | DNF | YAML query and formatting tool. |
| btop | DNF | Terminal system monitor. |
| tree | DNF | Directory tree viewer. |
| tealdeer | DNF | Fast `tldr` command examples. |
| git | DNF | Version control. |
| gh | DNF | GitHub CLI. |
| git-delta | DNF | Syntax-highlighted Git diffs. |
| git-lfs | DNF | Git large-file support. |
| curl | DNF | HTTP/file transfer CLI. |
| wget | DNF | HTTP/file download CLI. |
| unzip | DNF | Zip archive extraction. |
| p7zip | DNF | 7-Zip archive support. |
| rsync | DNF | Efficient file synchronization. |
| nano | DNF | Simple terminal editor. |
| vim | DNF | Modal terminal editor. |
| Python | DNF | Python runtime. |
| pip | DNF | Python package installer. |
| pipx | DNF | Isolated Python CLI app installer. |
| uv | DNF | Fast Python package and project tool. |
| Flatpak | DNF | Desktop app package system. |
| podman | DNF | Rootless container engine. |
| podman-compose | DNF | Compose workflows for Podman. |
| distrobox | DNF | Containerized Linux dev environments. |
| direnv | DNF | Per-directory environment loading. |
| just | DNF | Project command runner. |

## Extras From DNF

| App | Source | What it does |
| --- | --- | --- |
| neovim | DNF | Modern terminal editor. |
| micro | DNF | Simple terminal editor with familiar shortcuts. |
| kitty | DNF | GPU-accelerated terminal emulator. |
| WezTerm | DNF | Programmable terminal emulator. |
| lazygit | DNF | Terminal UI for Git. |
| Go | DNF | Go compiler and toolchain. |
| Rust / Cargo | DNF | Rust compiler and package manager. |
| Docker Compose | DNF | Compose file runner. |
| Catfish | DNF | Lightweight graphical file search. |
| KWrite | DNF | KDE graphical text editor. |
| FeatherPad | DNF | Lightweight graphical text editor. |
| GNOME Text Editor | DNF | Simple graphical text editor. |
| Tailscale | DNF | Mesh VPN client; service enablement is separate. |
| nvtop | DNF | GPU process monitor. |
| iotop | DNF | Disk I/O monitor. |
| sysstat | DNF | Historical CPU, memory, and I/O metrics. |
| vdpauinfo | DNF | VDPAU video acceleration diagnostics. |
| libva-utils | DNF | VAAPI video acceleration diagnostics. |

## Audio, Bluetooth, And Multimedia

| App | Source | What it does |
| --- | --- | --- |
| bluez | DNF | Linux Bluetooth stack. |
| bluedevil | DNF | KDE Bluetooth controls. |
| PipeWire | DNF | Modern Linux audio/video routing. |
| WirePlumber | DNF | PipeWire session manager. |
| libldac | DNF | LDAC Bluetooth audio codec support. |
| libfreeaptx | DNF | aptX Bluetooth audio codec support. |
| fdk-aac-free | DNF | AAC audio codec support. |
| ffmpeg | DNF/RPM Fusion | Audio/video conversion and playback backend. |
| GStreamer plugins | DNF/RPM Fusion | Multimedia playback codec support. |
| Mesa freeworld drivers | RPM Fusion | Optional VAAPI/VDPAU acceleration codecs where legally packaged. |

## KDE Desktop

| App | Source | What it does |
| --- | --- | --- |
| kdeplasma-addons | DNF | Extra Plasma widgets and desktop features. |
| plasma-systemmonitor | DNF | Plasma system monitor widgets and pages. |
| ksystemstats | DNF | Sensor backend for Plasma system monitor widgets. |
| power-profiles-daemon | DNF | Power profile and battery/performance integration. |
| lm_sensors | DNF | Hardware temperature and sensor detection support. |
| papirus-icon-theme | DNF | Broad icon theme coverage. |

## GNOME Desktop

| App | Source | What it does |
| --- | --- | --- |
| GNOME Tweaks | DNF | Reviews and adjusts supported GNOME appearance options. |
| Extensions | DNF | Manages installed GNOME Shell extensions. |
| AppIndicator support | DNF | Optional tray support for StatusNotifierItem applications. |
| Papirus icons | DNF | Shared KDE/GNOME icon profile with complete rollback. |
| variety | DNF | Wallpaper rotation utility. |
| qt6-qttools | DNF | Qt tools useful for KDE configuration. |
| kdeconnectd | DNF | Phone and device integration backend. |
| bluedevil | DNF | KDE Bluetooth integration. |

## Security And Firmware

| App | Source | What it does |
| --- | --- | --- |
| firewalld | DNF | Fedora firewall service. |
| policycoreutils | DNF | SELinux management tools. |
| policycoreutils-python-utils | DNF | Extra SELinux troubleshooting utilities. |
| setroubleshoot-server | DNF | SELinux alert and diagnosis service. |
| fwupd | DNF | Firmware update service for supported hardware. |
| dnf-automatic | DNF | Optional automatic update timer. |
| usbguard | DNF | Optional USB device control policy tool. |

## AI CLI Tools

| App | Source | What it does |
| --- | --- | --- |
| OpenAI Codex CLI | npm opt-in | Terminal coding assistant CLI; no keys or account state are copied. |
| Claude Code | npm opt-in | Anthropic terminal coding assistant CLI; no keys or account state are copied. |

## Terminal Fun

| App | Source | What it does |
| --- | --- | --- |
| cmatrix | DNF | Matrix-style terminal animation. |
| asciiquarium | DNF | Terminal aquarium animation. |
| pipes-sh | DNF | Animated terminal pipes. |
| fortune-mod | DNF | Random quotes. |
| cowsay | DNF | Speech bubble output. |
| rubygem-lolcat | DNF | Rainbow terminal colorizer. |
| figlet | DNF | Large ASCII text. |
| toilet | DNF | Styled ASCII text. |
| cbonsai | DNF | Bonsai tree terminal animation. |
| tty-clock | DNF | Terminal clock. |
| nyancat | DNF | Nyan Cat terminal animation. |
| sl | DNF | Steam locomotive terminal joke. |

## Flatpaks

| App | Source | What it does |
| --- | --- | --- |
| Brave | Flathub | Web browser. |
| VS Code | Flathub | Graphical code editor. |
| Bitwarden | Flathub | Password manager. |
| Flatseal | Flathub | Flatpak permissions editor. |
| Warehouse | Flathub | Flatpak management UI. |
| Gear Lever | Flathub | AppImage manager. |
| Nyrna | Flathub | Suspend/resume graphical apps. |
| LocalSend | Flathub | Local-network file sharing. |
| Cryptomator | Flathub | Encrypted vaults for cloud storage. |
| Ferdium | Flathub | Multi-service messaging wrapper. |
| Apostrophe | Flathub | Markdown editor. |
| Marknote | Flathub | KDE note app. |
| Steam | Flathub | Game store and launcher. |
| Heroic | Flathub | Epic/GOG/Amazon game launcher. |
| Moonlight | Flathub | Game streaming client. |
| Parsec | Flathub | Remote desktop/game streaming. |
| Stremio | Flathub | Media streaming center. |
| TIDAL Hi-Fi | Flathub | TIDAL desktop client. |
| Vesktop | Flathub | Discord-compatible client with Vencord. |
| GoofCord | Flathub | Lightweight Discord client. |
| Kotatogram | Flathub | Telegram client. |
| BlueBubbles | Flathub | iMessage bridge client. |
| Slack | Flathub | Team chat. |
| Surfshark | Flathub | VPN client. |
| Trayscale | Flathub | Unofficial Tailscale GUI; requires Tailscale daemon. |
| Podman Desktop | Flathub | Graphical container management. |
| Android Studio | Flathub | Android IDE. |
| ToolHive Studio | Flathub | Graphical ToolHive manager. |
| JamesDSP for Linux | Flathub | PipeWire audio effects. |

## Risk Tiers

Low-risk defaults are Fedora packages and user-owned dotfiles with backups.

Medium-risk items include Flatpak apps, KDE config edits, browser policies, and optional service enablement.

High-risk items include COPRs, RPM Fusion, global npm packages, VPN sign-in, and anything that changes system services.
