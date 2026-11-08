import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class TahoeColorsAndIslandClockTests(unittest.TestCase):
    # --- STATIC SPEC / TOKEN CHECKS ---

    def test_static_main_xml_show_clock_default_false(self):
        """[STATIC] Dynamic Island showClock entry in main.xml must default to false."""
        xml_path = ROOT / "plasmoids/org.phobby.dynamicisland/contents/config/main.xml"
        tree = ET.parse(xml_path)
        ns = {"kcfg": "http://www.kde.org/standards/kcfg/1.0"}
        entry = tree.find('.//kcfg:entry[@name="showClock"]', ns)
        self.assertIsNotNone(entry, "showClock entry not found in main.xml")
        default = entry.find("kcfg:default", ns)
        self.assertIsNotNone(default, "default element not found for showClock")
        self.assertEqual(
            default.text.strip(),
            "false",
            f"showClock default is {default.text.strip()}; expected false"
        )

    def test_static_installer_applies_mactahoe_colorscheme(self):
        """[STATIC] install.sh must invoke plasma-apply-colorscheme without silent error discarding."""
        installer_text = (ROOT / "install.sh").read_text()
        self.assertIn(
            "plasma-apply-colorscheme MacTahoeDark",
            installer_text,
            "install.sh does not apply MacTahoeDark color scheme"
        )
        self.assertNotIn(
            "plasma-apply-colorscheme MacTahoeDark 2>/dev/null || true",
            installer_text,
            "install.sh must not silently discard plasma-apply-colorscheme failure"
        )

    def test_static_island_qml_contains_clock_guards(self):
        """[STATIC] Island.qml source retains mode hierarchy and clock guard tokens."""
        island_source = (ROOT / "plasmoids/org.phobby.dynamicisland/contents/ui/Island.qml").read_text()
        self.assertIn("Clock {", island_source)
        self.assertIn("visible: island.showClock", island_source)
        self.assertIn("running: parent.visible && island.showClock", island_source)
        self.assertIn("visible: !island.showClock", island_source)
        mode_match = re.search(r"readonly property string mode:\s*([^\n]+(?:\n\s+[^\n]+)*)", island_source)
        self.assertIsNotNone(mode_match, "mode property definition not found in Island.qml")
        mode_expr = mode_match.group(1)
        self.assertIn('"split"', mode_expr)
        self.assertIn('"live"', mode_expr)
        self.assertIn('"idle"', mode_expr)

    # --- REAL RUNTIME EXECUTION CHECKS ---

    def test_runtime_production_clock_stops_timer_offscreen(self):
        """[RUNTIME] Clock.qml shuts down its minute timer when running=false in offscreen Qt."""
        env = os.environ.copy()
        env.pop("LD_PRELOAD", None)
        env.update({
            "QT_QPA_PLATFORM": "offscreen",
            "QT_QUICK_BACKEND": "software",
        })
        worker_code = """
import os, sys
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_BACKEND'] = 'software'
from pathlib import Path
from PyQt6 import sip
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlEngine, QQmlComponent
from PyQt6.QtCore import QUrl, QObject

app = QGuiApplication([])
engine = QQmlEngine()
lang = engine.newObject()
lang.setProperty('timeFormat', engine.toScriptValue('hh:mm'))
engine.globalObject().setProperty('Lang', lang)

clock_path = Path(sys.argv[1]).resolve()
comp = QQmlComponent(engine, QUrl.fromLocalFile(str(clock_path)))
obj = comp.create()
assert obj is not None, [e.toString() for e in comp.errors()]
assert obj.property('running') is True
timer = [c for c in obj.findChildren(QObject) if c.metaObject().className() == 'QQmlTimer'][0]
assert timer.property('running') is True

# Stop clock
obj.setProperty('running', False)
assert obj.property('running') is False
assert timer.property('running') is False

# Safe Qt cleanup
timer = None
sip.delete(obj)
sip.delete(comp)
print('PASS')
"""
        clock_file = ROOT / "plasmoids/org.phobby.dynamicisland/contents/ui/Clock.qml"
        res = subprocess.run(
            [sys.executable, "-B", "-I", "-c", worker_code, str(clock_file)],
            env=env, capture_output=True, text=True, timeout=10
        )
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertIn("PASS", res.stdout)

    def test_runtime_plasma_apply_colorscheme_unifies_palette(self):
        """[RUNTIME] plasma-apply-colorscheme applies worktree MacTahoeDark in fully isolated XDG."""
        with tempfile.TemporaryDirectory(prefix="color-test-") as tmpdir:
            tmp_path = Path(tmpdir)
            config_dir = tmp_path / "config"
            data_dir = tmp_path / "data"
            cache_dir = tmp_path / "cache"
            runtime_dir = tmp_path / "runtime"
            for d in (config_dir, data_dir, cache_dir, runtime_dir):
                d.mkdir(mode=0o700)

            # Copy worktree scheme into isolated XDG_DATA_HOME/color-schemes/
            scheme_dest = data_dir / "color-schemes"
            scheme_dest.mkdir(parents=True)
            shutil.copy(ROOT / "themes/MacTahoeDark.colors", scheme_dest / "MacTahoeDark.colors")

            # Initialize kdeglobals with BreezeDark fixture
            shutil.copy(Path.home() / ".config/kdeglobals", config_dir / "kdeglobals")

            env = os.environ.copy()
            env.pop("LD_PRELOAD", None)
            env.update({
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "XDG_CONFIG_HOME": str(config_dir),
                "XDG_DATA_HOME": str(data_dir),
                "XDG_DATA_DIRS": f"{data_dir}:/usr/local/share:/usr/share",
                "XDG_CACHE_HOME": str(cache_dir),
                "XDG_RUNTIME_DIR": str(runtime_dir),
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(tmp_path / "no-session-bus"),
                "TZ": "UTC",
                "LC_ALL": "C",
            })

            res = subprocess.run(
                ["plasma-apply-colorscheme", "MacTahoeDark"],
                env=env, capture_output=True, text=True, timeout=10
            )
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)

            # Verify ColorScheme updated to MacTahoeDark
            read_scheme = subprocess.run(
                ["kreadconfig6", "--file", str(config_dir / "kdeglobals"), "--group", "General", "--key", "ColorScheme"],
                capture_output=True, text=True
            )
            self.assertEqual(read_scheme.stdout.strip(), "MacTahoeDark")

            # Verify Button BackgroundNormal transformed to Tahoe dark gray 36,36,36
            read_btn_bg = subprocess.run(
                ["kreadconfig6", "--file", str(config_dir / "kdeglobals"), "--group", "Colors:Button", "--key", "BackgroundNormal"],
                capture_output=True, text=True
            )
            self.assertEqual(read_btn_bg.stdout.strip(), "36,36,36")

            # Verify Selection BackgroundNormal transformed to Tahoe blue accent 49,91,239
            read_sel_bg = subprocess.run(
                ["kreadconfig6", "--file", str(config_dir / "kdeglobals"), "--group", "Colors:Selection", "--key", "BackgroundNormal"],
                capture_output=True, text=True
            )
            self.assertEqual(read_sel_bg.stdout.strip(), "49,91,239")

            # Verify contrast preserved
            read_contrast = subprocess.run(
                ["kreadconfig6", "--file", str(config_dir / "kdeglobals"), "--group", "KDE", "--key", "contrast"],
                capture_output=True, text=True
            )
            self.assertEqual(read_contrast.stdout.strip(), "4")


if __name__ == "__main__":
    unittest.main()
