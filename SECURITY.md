# Security Policy

Fedora Glow Kit is a public starter kit for Fedora setup scripts and sanitized configuration samples. Please treat supply-chain issues seriously: install scripts, third-party repository prompts, browser extension policies, packaged KDE assets, and shell startup changes are all security-sensitive.

## Supported Versions

Only the `main` branch is supported.

## Reporting A Vulnerability

Please report security issues privately through GitHub Security Advisories:

https://github.com/daredoole/fedora-glow-kit/security/advisories/new

If GitHub advisories are unavailable, open a minimal public issue that says a private security report is needed, without posting exploit details, secrets, or private hostnames.

## Security Expectations

- Do not submit secrets, SSH keys, browser profiles, cookies, VPN state, private hostnames, or work/client configuration.
- Do not add `curl | sh`, unpinned remote script execution, or silent third-party repository enablement.
- Any third-party repo, COPR, Flatpak source, browser extension, or external installer must be opt-in and clearly described.
- Bundled third-party assets need credits and license/source metadata in `CREDITS.md`.
- Installers must back up existing user config before modifying it and must avoid destructive defaults.
- Run `bash scripts/audit-public.sh` before opening a pull request.

## Release Verification

Official release RPMs, source RPMs, and checksum manifests are signed by:

```text
Fedora Glow Kit Release <49536135+daredoole@users.noreply.github.com>
2568 7433 D39D 55AC 2549 18FC 100D AE86 F925 437B
```

Do not trust a release key with a different fingerprint. Each tagged release
publishes the public key, a detached `SHA256SUMS.asc` signature, an SPDX SBOM,
and GitHub build-provenance attestations.

## Disclosure Preference

For confirmed issues, prefer a fix-first disclosure: privately report, patch, release, then publish details once users have had time to update.
