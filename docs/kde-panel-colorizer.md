# KDE Panel Colorizer Notes

Panel Colorizer can look excellent, but Plasma panels are user, monitor, and widget specific.

## Rules

- Do not copy full personal panel layouts.
- Always back up `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.
- Prefer transparent spacer overrides over moving every widget by hand.
- Restart plasmashell only after writing a backup.

## Recovery

```bash
ls -la ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak.*
cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak.YYYYMMDD-HHMMSS ~/.config/plasma-org.kde.plasma.desktop-appletsrc
systemctl --user restart plasma-plasmashell.service
```

If spacers show as random rectangles, disable the spacer preset in Panel Colorizer or restore the backup.
