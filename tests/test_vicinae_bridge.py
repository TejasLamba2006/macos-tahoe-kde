import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
SCRIPT = ROOT / "bin/krunner-dbus-bridge.py"


class VicinaeBridgeTests(unittest.TestCase):
    def test_bridge_uses_vicinae_toggle_and_service_fallback(self):
        text = SCRIPT.read_text()
        self.assertIn('["/usr/bin/vicinae", "toggle"]', text)
        self.assertIn('["systemctl", "--user", "start", "vicinae.service"]', text)

    def test_all_dbus_launcher_methods_route_through_launch(self):
        text = SCRIPT.read_text()
        for method in ("display", "query", "toggleDisplay", "Activate", "Open"):
            block = text.split(f"def {method}", 1)[1].split("\n    @", 1)[0]
            self.assertIn("launch()", block)


if __name__ == "__main__":
    unittest.main()
