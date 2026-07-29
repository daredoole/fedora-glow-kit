# Public Release Checklist

Repository name: `fedora-glow-kit`

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
bash scripts/smoke-test.sh
```

Create the public repo after the audit passes:

```bash
git init
git add .
git commit -m "Initial Fedora Plasma Glow Kit"
gh repo create fedora-glow-kit --public --source=. --remote=origin --push
```

After publishing, enable repository protections:

```bash
gh api --method PUT repos/daredoole/fedora-glow-kit/vulnerability-alerts
gh api --method PUT repos/daredoole/fedora-glow-kit/automated-security-fixes
```

Protect `main` in GitHub settings or through the API:

- block force pushes
- block branch deletion
- require pull requests before merging
- require review from code owners
- require conversation resolution
- require linear history
- restrict GitHub Actions token permissions to read-only by default

Do not publish until these are true:

- no personal usernames, local paths, hostnames, work domains, SSH keys, tokens, browser profiles, cookies, VPN state, or Git credentials
- `CREDITS.md` lists bundled third-party assets, extension authors, optional third-party repositories, and major upstream tools
- `LICENSE.md` makes clear that starter-kit code/configs are MIT licensed while third-party assets retain their own licenses
- `SECURITY.md` exists and explains private reporting plus supply-chain contribution rules
- `.github/workflows/audit.yml` runs the public audit in CI
- tagged releases sign the RPM and source RPM, publish the public key, sign the checksum manifest, publish an SPDX SBOM, and create provenance attestations
- `.github/dependabot.yml` tracks GitHub Actions updates
- `.github/CODEOWNERS` names a required owner
- installers prompt before optional desktop changes, third-party repos, media codecs, security policy changes, and removals
- existing dotfiles are backed up before edits
- existing configs/assets are skipped or diffed before overwrite
- `CREDITS.md` credits bundled assets, optional extension installs, and major upstream tools
- bundled third-party assets without clear source/license metadata are removed or documented
- both Fedora 44 KDE and GNOME clean-VM matrices pass install, rerun, interrupted-operation recovery, and full revert
- the GUI passes keyboard, scaling, dark/light, missing-tray, and reduced-motion checks
- diagnostics and exported reports contain no personal or device identifiers
- no unresolved critical or high-severity security findings remain
- `bash scripts/audit-public.sh` passes
