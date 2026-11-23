import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MC = REPO / "kwin/macos-mission-control"


class MissionControlOverrideTests(unittest.TestCase):
    def test_upstream_window_heap_delegate_exists(self):
        upstream = MC / "upstream/WindowHeapDelegate.qml"
        self.assertTrue(upstream.is_file())
        self.assertFalse((REPO / "shell-overrides/kwin/WindowHeapDelegate.qml").exists())

    def test_mission_control_effect_package_and_mru_sizing(self):
        self.assertTrue((MC / "metadata.json").is_file())
        self.assertTrue((MC / "contents/config/main.xml").is_file())
        main_qml = (MC / "contents/ui/main.qml").read_text()
        screen_qml = (MC / "contents/ui/ScreenView.qml").read_text()
        delegate_qml = (MC / "contents/ui/MacOSWindowHeapDelegate.qml").read_text()

        self.assertIn('name: "MacOSMissionControl"', main_qml)
        self.assertIn('sequence: "Meta+W"', main_qml)
        self.assertIn("MacOSWindowHeapDelegate {", screen_qml)
        self.assertGreaterEqual(screen_qml.count("gesturePolicy: TapHandler.ReleaseWithinBounds"), 3)

        for token in (
            "ExpoCell {",
            "KWinComponents.WindowThumbnail {",
            "KWinComponents.Workspace.activeWindow = thumb.window;",
            "thumb.windowHeap.activated();",
            "radius: 8",
            "radius: 6",
            "#0A84FF",
            "mruRank",
            "mruWeight",
            "effectiveScale",
            "thumb.window.active",
            "naturalWidth: thumb.window.width * thumb.effectiveScale",
            "naturalHeight: thumb.window.height * thumb.effectiveScale",
        ):
            self.assertIn(token, delegate_qml)

    def test_installer_deploys_macos_mission_control_without_dirtying_pacman_kwin(self):
        installer = (REPO / "install.sh").read_text()
        self.assertIn("macos-mission-control", installer)
        self.assertIn("MacOSMissionControl", installer)
        self.assertNotIn("/org/kde/kwin/private/effects", installer)


if __name__ == "__main__":
    unittest.main()
