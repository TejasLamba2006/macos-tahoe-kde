import os
import unittest
from pathlib import Path

from PyQt6.QtCore import QCoreApplication
from PyQt6.QtQml import QJSEngine

ROOT = Path(__file__).resolve().parents[1]


class DockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def test_pointer_local_scale_is_bounded_and_smooth(self):
        source = ROOT / "patches/dock/src/Magnification.js"
        self.assertTrue(source.exists(), "Dock scale implementation missing")
        engine = QJSEngine()
        script = source.read_text().replace(".pragma library", "")
        engine.evaluate(script)
        for hovered, distance, width, expected in (
            (False, 0, 48, 1),
            (True, 0, 48, 1.24),
            (True, 108, 48, 1),
            (True, 120, 48, 1),
            (True, 20, 0, 1),
        ):
            result = engine.evaluate(f"scaleFor({str(hovered).lower()}, {distance}, {width})")
            self.assertFalse(result.isError(), result.toString())
            self.assertAlmostEqual(result.toNumber(), expected, places=6)

        near = engine.evaluate("scaleFor(true, 30, 48)").toNumber()
        far = engine.evaluate("scaleFor(true, 60, 48)").toNumber()
        self.assertGreater(near, far)

    def test_native_task_context_and_motion_safeguards(self):
        task_text = (ROOT / "patches/dock/src/Task.qml").read_text()
        list_text = (ROOT / "patches/dock/src/TaskList.qml").read_text()

        for token in (
            "tasksRoot.taskList",
            "task.model.decoration",
            "dragHandler",
            "model.LauncherUrlWithoutIcon",
            "magnification",
            "dockBounce",
            "transformOrigin: Item.Bottom",
        ):
            self.assertIn(token, task_text)

        self.assertIn("dockPointerX", list_text)
        self.assertIn("dockHovered", list_text)

        preload = (ROOT / "patches/bartender/bartender_preload.cpp").read_text()
        self.assertIn("dock.rcc", preload)
        self.assertIn(
            'dockResourceLoaded && std::strstr(info.dli_fname, "org.kde.plasma.taskmanager.so")',
            preload,
        )


if __name__ == "__main__":
    unittest.main()
