# Troubleshooting

## Audit fails

Run:

```bash
bash scripts/audit-public.sh
```

Common causes:

- old branding still present
- placeholder clone URL still present
- ShellCheck warning
- private-looking file name
- generated icon cache
- repo too large

## KDE panel looks wrong

Restore the backed-up panel config:

```bash
ls -la ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak.*
cp BACKUP ~/.config/plasma-org.kde.plasma.desktop-appletsrc
systemctl --user restart plasma-plasmashell.service
```

## Scripts answer prompts unexpectedly

Check:

```bash
echo "$FEDORA_PLASMA_GLOW_ASSUME"
```

Unset it for normal interactive mode:

```bash
unset FEDORA_PLASMA_GLOW_ASSUME
```
