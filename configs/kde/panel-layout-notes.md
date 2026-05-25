# KDE Panel / Taskbar Notes

Detected source panel:

- Panel containment ID: `2`
- Problem found: panel alignment was set to `center`
- Effect: all panel contents were centered as a group, including launcher widgets and right-side status/tray widgets
- Portable fix applied by the installer: set panel alignment to `left`, remove the margin separator that consumed expansion space, and place Icon Tasks or Task Manager between two Plasma panel spacers

Detected applet order:

```text
Kickoff launcher
Activity pager
Thermal monitor
Power usage
Weather
Panel Colorizer
Icon Tasks launchers
Margin separator
System tray
Digital clock
Show desktop
```

The kit does not copy the full Plasma panel layout because it is monitor/user specific. The KDE installer includes an opt-in helper that:

- sets the top panel alignment to `left`
- removes `org.kde.plasma.marginsseparator`
- ensures two `org.kde.plasma.panelspacer` widgets exist
- writes an applet order of: left widgets, spacer, Icon Tasks, spacer, tray/clock/show-desktop
- restarts `plasmashell` so the panel reloads the layout

Panel Colorizer tuning is also opt-in. When Panel Colorizer is installed and already present on a panel, the helper:

- widens widget island spacing to at least `10`
- sets normal widget island margins to at least `10px` left/right, `5px` top, and `8px` bottom
- lowers widget island background opacity to `0.82`
- sets the primary border opacity to `0.45`
- adds a `Starter Kit Transparent Spacers` override for `org.kde.plasma.panelspacer`
- associates that override only with spacer widgets so empty panel portions stay transparent
- adds a `Starter Kit Icon Tasks Full Size` override for `org.kde.plasma.icontasks`
- keeps Icon Tasks horizontal margins at `10px`, top margin at `1px`, and bottom margin at `3px` so pinned app icons stay full size

The bundled Panel Colorizer plasmoid is copied only when it is missing. Existing Panel Colorizer installs and full panel layouts are not overwritten.

Optional KWin Rounded Corners support is handled as a third-party package install, not a copied config. The installer can enable `matinlotfali/KDE-Rounded-Corners` and install `kwin-effect-roundedcorners`, but this is off by default and requires explicit confirmation.
