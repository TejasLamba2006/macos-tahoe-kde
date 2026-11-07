import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1] / "patches/notification-center"


class NotificationOverrideTests(unittest.TestCase):
    def test_required_upstream_snapshots_exist(self):
        for rel in (
            "upstream/FullRepresentation.qml",
            "upstream/delegates/DelegateHistory.qml",
            "upstream/delegates/DelegateHistoryGrouped.qml",
            "upstream/components/NotificationHeader.qml",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_notification_overrides_preserve_models_and_style(self):
        source = ROOT / "src"
        joined = "\n".join(p.read_text() for p in source.rglob("*.qml"))
        for token in ("onActionInvoked:", "onReplied:", "onCloseClicked:", "dismissed", "#ee1c1c1e", "radius: 16"):
            self.assertIn(token, joined)

    def test_widget_stack_reuses_configured_calendar_weather_and_battery(self):
        path = ROOT / "src/WidgetStack.qml"
        self.assertTrue(path.is_file(), "shared-source notification widgets missing")
        text = path.read_text()
        for token in ("IcsCalendarBackend.qml", "WeatherBackend.qml", "BatteryControlModel", "calendarSources", "weatherLocation", "error", "loaded"):
            self.assertIn(token, text)

    def test_bartender_preload_registers_notification_resource(self):
        repo = Path(__file__).parents[1]
        text = (repo / "patches/bartender/bartender_preload.cpp").read_text()
        self.assertIn("notification-center.rcc", text)
        self.assertIn("org.kde.plasma.notifications.so", text)


if __name__ == "__main__":
    unittest.main()
