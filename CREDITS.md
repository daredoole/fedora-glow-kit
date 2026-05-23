# Credits

Fedora Plasma Glow Kit is a curated installer and configuration wrapper. It does not claim ownership of the upstream tools, themes, extensions, or artwork it installs or bundles. Third-party projects keep their own authorship, licenses, trademarks, and update channels.

This file credits bundled assets and opt-in upstream installs. When local metadata provides an author, license, or repository, it is listed. When this kit only has an install source, the official project or listing is linked.

## Bundled KDE Assets

These assets are included under `configs/kde/themes` or `configs/kde/plasmoids`.

| Asset | Author/Credit | Source/Repo | License From Metadata |
| --- | --- | --- | --- |
| Panel Colorizer plasmoid | Luis Bocanegra | https://github.com/luisbocanegra/plasma-panel-colorizer | GPL-3.0 |
| Panel Colorizer translation tooling note | Zren's i18n scripts | https://github.com/Zren/plasma-applet-lib | See upstream |
| Layan Plasma theme | Vinceliuice | https://github.com/vinceliuice/Layan-kde | GPL 3.0 |
| Orchis KDE look-and-feel, wallpaper, Aurorae variants, and related color assets | Vince Liuice / Vinceliuice | https://github.com/vinceliuice/Orchis-kde | GPLv3 / LGPL depending on asset metadata |
| Sweet and Sweet-Ambar-Blue Plasma themes | EliverLara | https://github.com/EliverLara/Sweet | CC BY-SA 4.0 |
| Sweet Aurorae variants | EliverLara | https://github.com/EliverLara/Sweet | GPLv3 |
| Papirus icon theme recommendation | Papirus Development Team | https://github.com/PapirusDevelopmentTeam/papirus-icon-theme | Installed from Fedora package, not bundled |

Large downloaded icon theme directories are intentionally not bundled. This avoids committing generated icon caches and keeps the public repository small.

The previously staged `Tokyo Night.colors` and `Sweet-Wallpapers` assets were removed before public release because the local files did not include enough source/license metadata.

## Bundled Config Inspiration

| Config | Credit |
| --- | --- |
| Fastfetch config | Built for this kit using Fastfetch's JSON config schema: https://github.com/fastfetch-cli/fastfetch |
| Starship prompt config | Built for this kit using Starship: https://github.com/starship/starship |
| Zellij config | Built for this kit using Zellij: https://github.com/zellij-org/zellij |
| Kitty config | Built for this kit using Kitty: https://github.com/kovidgoyal/kitty |
| Konsole profile/colors | Built for this kit; color choices are visually aligned with the credited Sweet theme family |

The `configs/fastfetch/dog.png` and `configs/fastfetch/dog_transparent.png` images are local starter-kit assets used for the sample Fastfetch layout. No third-party image source metadata is present in the repository.

## Firefox Extensions

The Firefox policy installs public AMO extension packages only when the user opts in. No extension state, settings, cookies, accounts, or browsing data are included.

| Extension | Author/Credit From AMO | Listing/Homepage | License From AMO |
| --- | --- | --- | --- |
| Consent-O-Matic | CAVI - Aarhus University, Midas Nouwens | https://addons.mozilla.org/firefox/addon/consent-o-matic/ | MIT License |
| Auto Tab Discard | tlintspr | https://addons.mozilla.org/firefox/addon/auto-tab-discard/ | Mozilla Public License 2.0 |
| Privacy Badger | EFF Technologists | https://addons.mozilla.org/firefox/addon/privacy-badger17/ | GNU GPL v3.0 only |
| Volume Control | manybuddies | https://addons.mozilla.org/firefox/addon/volume-control/ | All Rights Reserved |
| uBlock Origin | Raymond Hill | https://addons.mozilla.org/firefox/addon/ublock-origin/ | GNU GPL v3.0 only |
| Firefox Multi-Account Containers | Firefox | https://addons.mozilla.org/firefox/addon/multi-account-containers/ | Mozilla Public License 2.0 |
| Surfshark VPN Extension | Surfshark | https://addons.mozilla.org/firefox/addon/surfshark-vpn-proxy/ | All Rights Reserved |
| Enhancer for YouTube | Max RF | https://addons.mozilla.org/firefox/addon/enhancer-for-youtube/ | Custom License |
| SponsorBlock | Ajay (SponsorBlock) | https://addons.mozilla.org/firefox/addon/sponsorblock/ | GNU LGPL v3.0 only |
| Clear Cache | TenSoja | https://addons.mozilla.org/firefox/addon/clearcache/ | Mozilla Public License 2.0 |
| Port Authority | Hacks and Hops | https://addons.mozilla.org/firefox/addon/port-authority/ | GNU GPL v2.0 only |
| Don't track me Google | Rob W | https://addons.mozilla.org/firefox/addon/dont-track-me-google1/ | MIT License |
| Dark Reader | Dark Reader Ltd | https://addons.mozilla.org/firefox/addon/darkreader/ | MIT License |
| Bitwarden Password Manager | Bitwarden Inc. | https://addons.mozilla.org/firefox/addon/bitwarden-password-manager/ | GNU GPL v3.0 only |
| Reddit NSFW Unblocker | Naraka | https://addons.mozilla.org/firefox/addon/reddit-nsfw-unblocker/ | MIT License |
| Tomato Clock | Samuel Jun | https://addons.mozilla.org/firefox/addon/tomato-clock/ | GNU GPL v3.0 only |

## Optional Third-Party Desktop Sources

| Item | Credit | Source |
| --- | --- | --- |
| KWin Rounded Corners effect | matinlotfali | https://github.com/matinlotfali/KDE-Rounded-Corners |
| RPM Fusion repositories and multimedia packages | RPM Fusion project | https://rpmfusion.org/ |
| Flathub applications | Flathub and each application upstream | https://flathub.org/ |

Third-party repositories are opt-in and clearly labeled before they are enabled.

## Recommended CLI And Developer Tools

These tools are installed from Fedora, Flathub, npm, or the user's configured package sources. They are not vendored in this repository.

| Tool | Upstream |
| --- | --- |
| zsh | https://www.zsh.org/ |
| Starship | https://github.com/starship/starship |
| Zellij | https://github.com/zellij-org/zellij |
| Fastfetch | https://github.com/fastfetch-cli/fastfetch |
| ripgrep (`rg`) | https://github.com/BurntSushi/ripgrep |
| fd | https://github.com/sharkdp/fd |
| bat | https://github.com/sharkdp/bat |
| eza | https://github.com/eza-community/eza |
| fzf | https://github.com/junegunn/fzf |
| zoxide | https://github.com/ajeetdsouza/zoxide |
| jq | https://github.com/jqlang/jq |
| yq | https://github.com/mikefarah/yq |
| btop | https://github.com/aristocratos/btop |
| tealdeer | https://github.com/tealdeer-rs/tealdeer |
| Git | https://git-scm.com/ |
| GitHub CLI | https://github.com/cli/cli |
| delta | https://github.com/dandavison/delta |
| Git LFS | https://git-lfs.com/ |
| uv | https://github.com/astral-sh/uv |
| direnv | https://github.com/direnv/direnv |
| just | https://github.com/casey/just |
| Podman | https://podman.io/ |
| Distrobox | https://github.com/89luca89/distrobox |
| Tailscale | https://tailscale.com/ |
| Neovim | https://github.com/neovim/neovim |
| micro | https://github.com/zyedidia/micro |
| kitty | https://github.com/kovidgoyal/kitty |
| WezTerm | https://github.com/wez/wezterm |
| lazygit | https://github.com/jesseduffield/lazygit |
| Catfish | https://gitlab.xfce.org/apps/catfish |
| OpenAI Codex CLI | https://www.npmjs.com/package/@openai/codex |
| Claude Code | https://www.npmjs.com/package/@anthropic-ai/claude-code |

## Fedora, KDE, And Security Projects

This kit is built for Fedora and KDE Plasma and credits the upstream projects it depends on:

- Fedora Project: https://fedoraproject.org/
- KDE Plasma: https://kde.org/plasma-desktop/
- KDE Gear/Konsole/KWrite and related KDE applications: https://kde.org/
- firewalld: https://firewalld.org/
- SELinux: https://selinuxproject.org/
- fwupd: https://fwupd.org/
- USBGuard: https://usbguard.github.io/

## Notes For Future Maintainers

- If a bundled asset is added, add its author, repo/homepage, and license here before publishing.
- If metadata is missing, either add a clear "metadata not present" note here or remove the asset from the public repo.
- Do not bundle private configs, browser profiles, credentials, local panel layouts, or generated cache files.
