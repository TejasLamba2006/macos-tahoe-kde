import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]


class VicinaeShortcutTests(unittest.TestCase):
    def test_vicinae_desktop_action(self):
        text = (ROOT / "applications/vicinae-applications.desktop").read_text()
        self.assertIn("Exec=/usr/bin/vicinae toggle", text)
        self.assertIn("X-KDE-Shortcuts=Alt+Space", text)

    def test_installer_registers_alt_space(self):
        text = (ROOT / "install.sh").read_text()
        self.assertIn("vicinae-applications.desktop", text)
        self.assertIn("Alt+Space", text)
        self.assertIn("org.kde.krunner.service", text)
        self.assertIn("org.kde.krunner.desktop", text)

    def test_krunner_service_avoids_graphical_session_cycle(self):
        text = (ROOT / "systemd/plasma-krunner.service").read_text()
        self.assertIn("After=graphical-session.target vicinae.service", text)


if __name__ == "__main__":
    unittest.main()
