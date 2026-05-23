# Contributing

Thanks for helping improve Fedora Plasma Glow Kit.

## Rules

- Do not add secrets or private data.
- Do not add `curl | sh`.
- Do not silently enable third-party repositories.
- Do not copy browser profiles, SSH keys, VPN state, cookies, extension storage, work aliases, or hostnames.
- Keep risky actions opt-in.
- Add credits and license/source notes for bundled third-party assets.
- Keep installers reversible.

## Before opening a PR

```bash
bash scripts/audit-public.sh
bash manage.sh --dry-run --profile minimal
bash manage.sh --dry-run --profile daily
```
