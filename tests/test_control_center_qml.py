import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
TAHOE = ROOT / "plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe"
LAYOUT = ROOT / "plasmoids/KdeControlStation/contents/ui/layouts/Tahoe.qml"


class ControlCenterQmlTests(unittest.TestCase):
    def test_quick_toggle_contract(self):
        text = (TAHOE / "QuickToggle.qml").read_text()
        for token in (
            "property string title",
            "property string subtitle",
            "property string icon",
            "property bool checked",
            "signal triggered",
        ):
            self.assertIn(token, text)

    def test_slider_card_contract(self):
        text = (TAHOE / "SliderCard.qml").read_text()
        self.assertIn("default property alias content", text)
        self.assertIn("property string title", text)

    def test_tahoe_uses_all_required_sections(self):
        text = LAYOUT.read_text()
        for token in (
            "ConnectivityTile",
            "DndButton",
            "ColorSchemeSwitcher",
            "BrightnessSlider",
            "Volume",
            "NowPlayingCard",
        ):
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
