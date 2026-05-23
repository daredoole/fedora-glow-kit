# Public Release Checklist

Recommended repository name: `fedora-glow-kit`

Why this name:

- short and memorable
- broad enough for Workstation/KDE
- fits the goal: a polished Fedora setup with terminal, shell, desktop, and safety defaults

Good alternatives:

- `fedora-starter-kit`
- `fedora-kde-starter-kit`
- `fedora-workstation-glow-up`

Before publishing:

```bash
cd fedora-glow-kit
bash scripts/audit-public.sh
```

Create the public repo after the audit passes:

```bash
git init
git add .
git commit -m "Initial Fedora Glow Kit"
gh repo create fedora-glow-kit --public --source=. --remote=origin --push
```

Do not publish until these are true:

- no personal usernames, local paths, hostnames, work domains, SSH keys, tokens, browser profiles, cookies, VPN state, or Git credentials
- `CREDITS.md` lists bundled third-party assets, extension authors, optional third-party repositories, and major upstream tools
- `LICENSE.md` makes clear that starter-kit code/configs are MIT licensed while third-party assets retain their own licenses
- installers prompt before optional desktop changes, third-party repos, media codecs, security policy changes, and removals
- existing dotfiles are backed up before edits
- existing configs/assets are skipped or diffed before overwrite
- `CREDITS.md` credits bundled assets, optional extension installs, and major upstream tools
- bundled third-party assets without clear source/license metadata are removed or documented
- `bash scripts/audit-public.sh` passes
