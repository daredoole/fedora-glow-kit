from __future__ import annotations

import os
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    from PySide6.QtCore import QUrl
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtWidgets import QApplication

    from glow_kit.gui import Bridge
except ImportError:
    QApplication = None


@unittest.skipIf(QApplication is None, "PySide6 is not installed")
class GuiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_control_deck_qml_loads(self) -> None:
        engine = QQmlApplicationEngine()
        engine.rootContext().setContextProperty("backend", Bridge())
        qml = Path(__file__).resolve().parents[1] / "glow_kit/qml/Main.qml"
        engine.load(QUrl.fromLocalFile(str(qml)))
        self.assertEqual(len(engine.rootObjects()), 1)
        engine.rootObjects()[0].close()
