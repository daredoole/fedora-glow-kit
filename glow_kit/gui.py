from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from .core import (
    build_plan,
    diagnostics_text,
    launch_terminal,
    load_settings,
    project_root,
    save_settings,
    status_payload,
)


class Bridge(QObject):
    trayChanged = Signal()

    def __init__(self, tray: QSystemTrayIcon | None = None) -> None:
        super().__init__()
        self._tray = tray

    @Property(bool, notify=trayChanged)
    def trayActive(self) -> bool:  # noqa: N802 - Qt property name
        return bool(self._tray and self._tray.isVisible())

    @Slot(result="QVariant")
    def settings(self) -> dict[str, object]:
        return load_settings()

    @Slot(result=str)
    def status(self) -> str:
        payload = status_payload()
        support = "Release target verified" if payload["supported"] else "Unsupported Fedora target"
        return (
            f"{support}\n"
            f"{payload['desktop'].title()} session · {payload['managed_items']} managed items · "
            f"{payload['incomplete_transactions']} incomplete operations"
        )

    @Slot(str, str, result=str)
    def plan(self, profile: str, desktop: str) -> str:
        try:
            payload = build_plan(profile, desktop)
        except ValueError as error:
            return f"Plan unavailable: {error}"
        return "\n".join(
            f"{index + 1}. {item['label']}  ·  {item['risk']} risk"
            for index, item in enumerate(payload["actions"])
        )

    @Slot(str, str)
    def launchApply(self, profile: str, desktop: str) -> None:  # noqa: N802
        launch_terminal([cli_executable(), "apply", "--profile", profile, "--desktop", desktop])

    @Slot()
    def launchUpdate(self) -> None:  # noqa: N802
        launch_terminal([cli_executable(), "update"])

    @Slot()
    def launchRevert(self) -> None:  # noqa: N802
        launch_terminal([cli_executable(), "revert"])

    @Slot(result=str)
    def diagnostics(self) -> str:
        return diagnostics_text()

    @Slot(str, str, bool)
    def save(self, profile: str, desktop: str, autostart: bool) -> None:
        save_settings(
            {
                "profile": profile,
                "desktop": desktop,
                "tray_autostart": autostart,
                "safe_aliases": True,
            }
        )
        set_autostart(autostart)


def set_autostart(enabled: bool) -> None:
    target = Path.home() / ".config/autostart/fedora-glow-kit.desktop"
    if not enabled:
        target.unlink(missing_ok=True)
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    executable = shutil.which("glow-kit-gui") or str(project_root() / "bin/glow-kit-gui")
    target.write_text(
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Name=Fedora Glow Kit\n"
        f"Exec={executable} --tray\n"
        "Icon=fedora-glow-kit\n"
        "Terminal=false\n"
        "X-GNOME-Autostart-enabled=true\n",
        encoding="utf-8",
    )
    target.chmod(0o600)


def cli_executable() -> str:
    return shutil.which("glow-kit") or str(project_root() / "bin/glow-kit")


def icon_path() -> Path:
    candidates = [
        project_root() / "assets/fedora-glow-kit.svg",
        Path("/usr/share/icons/hicolor/scalable/apps/fedora-glow-kit.svg"),
    ]
    return next((path for path in candidates if path.is_file()), candidates[0])


def main() -> int:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Fusion")
    app = QApplication(sys.argv)
    app.setApplicationName("Fedora Glow Kit")
    app.setOrganizationName("Fedora Glow Kit")
    app.setWindowIcon(QIcon(str(icon_path())))

    tray: QSystemTrayIcon | None = None
    if QSystemTrayIcon.isSystemTrayAvailable():
        tray = QSystemTrayIcon(QIcon(str(icon_path())), app)
        tray.setToolTip("Fedora Glow Kit")
        menu = QMenu()
        show_action = menu.addAction("Open control deck")
        update_action = menu.addAction("Check updates")
        revert_action = menu.addAction("Recovery")
        menu.addSeparator()
        quit_action = menu.addAction("Quit")
        tray.setContextMenu(menu)
        tray.show()

    bridge = Bridge(tray)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", bridge)
    qml = Path(__file__).resolve().parent / "qml/Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml)))
    if not engine.rootObjects():
        return 1
    window = engine.rootObjects()[0]

    if tray:
        show_action.triggered.connect(
            lambda: (window.show(), window.raise_(), window.requestActivate())
        )
        update_action.triggered.connect(bridge.launchUpdate)
        revert_action.triggered.connect(bridge.launchRevert)
        quit_action.triggered.connect(app.quit)
        tray.activated.connect(
            lambda reason: (
                window.show() if reason == QSystemTrayIcon.ActivationReason.Trigger else None
            )
        )
        app.setQuitOnLastWindowClosed(False)

    settings = load_settings()
    start_hidden = "--tray" in sys.argv and bool(settings["tray_autostart"]) and tray
    if not start_hidden:
        window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
