import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class KonsoleDevanagariTests(unittest.TestCase):
    def test_konsole_profile_enables_harfbuzz_brahmic_word_mode(self):
        profile = (REPO / "konsole/macOS.profile").read_text()
        for token in ("WordMode=true", "WordModeBrahmic=true", "BidiRenderingEnabled=true"):
            self.assertIn(token, profile)

    def test_fontconfig_includes_noto_sans_devanagari_fallback_and_installs(self):
        fonts = (REPO / "fontconfig/fonts.conf").read_text()
        self.assertGreaterEqual(fonts.count("<family>Noto Sans Devanagari</family>"), 3)
        installer = (REPO / "install.sh").read_text()
        self.assertIn("fontconfig/fonts.conf", installer)


if __name__ == "__main__":
    unittest.main()
