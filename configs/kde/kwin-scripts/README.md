# KWin Scripts

Detected local KWin scripts on the source system:

- `endtask-2025` - End Task 2025
- `safe-endtask` - Safe End Task
- `krohnkite` - dynamic tiling script
- `rememberwindowpositions` - restore application window positions

Enabled KWin plugin IDs detected:

- `krohnkite`
- `rememberwindowpositions`
- `endtask-modern`

Large third-party KWin script directories were not copied automatically because they can contain bundled code, UI files, generated assets, and local configuration assumptions. To include reviewed script packages, place each script directory here:

```text
configs/kde/kwin-scripts/<script-id>/metadata.json
configs/kde/kwin-scripts/<script-id>/contents/...
```

The KDE installer will install packaged directories found here with `kpackagetool6 --type KWin/Script --install`.

Detected Plasma panel/taskbar widgets on the source system included:

- Icon Tasks taskbar
- Kickoff launcher
- System tray
- KDE Connect
- Bluetooth
- Volume/media controls
- Clipboard
- Device notifier
- Weather
- Activity pager
- Show desktop
- Battery, brightness, notifications, print manager, camera indicator, power usage

The installer does not copy `plasma-org.kde.plasma.desktop-appletsrc` because panel layouts are monitor/user specific and can corrupt a target desktop if blindly copied. It installs portable widget support packages instead.
