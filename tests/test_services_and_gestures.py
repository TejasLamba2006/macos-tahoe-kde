import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class SystemServicesAndGesturesTests(unittest.TestCase):
    def test_multiscreen_dock_service_avoids_graphical_session_cycle(self):
        text = (REPO / "systemd/macos-multiscreen-dock.service").read_text()
        self.assertNotIn("After=graphical-session.target", text)
        self.assertIn("After=plasma-plasmashell.service", text)
        self.assertIn("WantedBy=graphical-session.target", text)

    def test_three_finger_gestures_targets_macos_mission_control_and_waits_for_kwin(self):
        script = (REPO / "bin/three-finger-gestures/three-finger-gestures.py").read_text()
        self.assertIn('"up": ("kwin", "MacOSMissionControl")', script)
        self.assertIn("macos-mission-control", script)
        svc = (REPO / "systemd/three-finger-gestures.service").read_text()
        self.assertIn("After=plasma-kwin_wayland.service", svc)

    def test_krunner_bridge_clipboard_uses_start_new_session(self):
        script = (REPO / "bin/krunner-dbus-bridge.py").read_text()
        block = script.split("def clipboard():", 1)[1].split("class KRunnerApp", 1)[0]
        self.assertIn("start_new_session=True", block)


if __name__ == "__main__":
    unittest.main()
