import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
NC = REPO / "patches/notification-center"


class NotificationOverrideTests(unittest.TestCase):
    def test_upstream_snapshots_exist(self):
        for rel in (
            "upstream/FullRepresentation.qml",
            "upstream/delegates/DelegateHistory.qml",
            "upstream/delegates/DelegateHistoryGrouped.qml",
        ):
            self.assertTrue((NC / rel).is_file(), f"Missing {rel}")

    def test_does_not_override_draggable_delegate_or_popup_or_widget_stack(self):
        src = NC / "src"
        self.assertFalse((src / "DraggableDelegate.qml").exists())
        self.assertFalse((src / "NotificationPopup.qml").exists())
        self.assertFalse((src / "WidgetStack.qml").exists())
        qrc = (src / "notification-center.qrc").read_text()
        self.assertNotIn("DraggableDelegate.qml", qrc)
        self.assertNotIn("WidgetStack.qml", qrc)

    def test_history_delegates_preserve_native_grid_and_add_outer_macos_glass_card(self):
        full = (NC / "src/FullRepresentation.qml").read_text()
        hist = (NC / "src/delegates/DelegateHistory.qml").read_text()
        grouped = (NC / "src/delegates/DelegateHistoryGrouped.qml").read_text()
        for token in (
            "onActionInvoked:",
            "onReplied:",
            "onCloseClicked:",
            "onSuspendJobClicked:",
            "onResumeJobClicked:",
            "onKillJobClicked:",
            "radius: 14",
        ):
            self.assertIn(token, full)
        # Never inject a Rectangle child directly inside BaseDelegate (GridLayout)
        self.assertNotIn("radius: 14", hist)
        self.assertNotIn("radius: 14", grouped)

    def test_bartender_preload_registers_notification_center_safely(self):
        preload = (REPO / "patches/bartender/bartender_preload.cpp").read_text()
        self.assertIn("notification-center.rcc", preload)
        self.assertIn("notificationResourceLoaded && std::strstr(info.dli_fname, \"org.kde.plasma.notifications.so\")", preload)
        self.assertIn("unsetenv(\"LD_PRELOAD\")", preload)


if __name__ == "__main__":
    unittest.main()
