import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class AerialPauseTests(unittest.TestCase):
    def test_aerial_pauses_when_covered_or_on_battery_and_resumes_on_show_desktop(self):
        src = (REPO / "patches/aerial-main.qml").read_text()
        for token in (
            "import org.kde.plasma.wallpapers.image as PlasmaWallpaper",
            "import org.kde.plasma.private.battery as Battery",
            "import org.kde.kwindowsystem",
            "PlasmaWallpaper.MaximizedWindowMonitor {",
            "Battery.BatteryControlModel {",
            "readonly property bool isCovered: activeWindowMonitor.count > 0 && !KWindowSystem.showingDesktop",
            "readonly property bool onBattery: battery.hasBatteries && !battery.pluggedIn",
            "readonly property bool shouldPause: isCovered || onBattery",
            "onShouldPauseChanged:",
            "onPlaybackStateChanged:",
        ):
            self.assertIn(token, src)

    def test_aerial_unloads_fallback_image_when_video_loaded(self):
        src = (REPO / "patches/aerial-main.qml").read_text()
        self.assertIn("Loader {", src)
        self.assertIn("sourceSize: Qt.size(", src)


if __name__ == "__main__":
    unittest.main()
