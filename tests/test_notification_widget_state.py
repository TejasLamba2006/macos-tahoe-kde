import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NotificationWidgetStateTests(unittest.TestCase):
    def test_production_widget_state_offscreen(self):
        # A separate process also works when another test already owns QCoreApplication.
        with tempfile.TemporaryDirectory(prefix="notification-widget-state-") as directory:
            home = Path(directory)
            for name in ("config", "data", "cache", "runtime"):
                (home / name).mkdir(mode=0o700)
            backend = home / "data/plasma/plasmoids/org.phobby.dynamicisland/contents/ui/backend"
            backend.mkdir(parents=True)
            # Only external data is replaced; WidgetStack.qml is loaded verbatim.
            (backend / "IcsCalendarBackend.qml").write_text("""import QtQuick
Item {
    property string sourcesJson: "[]"
    property bool loaded: true
    property var events: []
    property var errors: ({})
}
""")
            (backend / "WeatherBackend.qml").write_text("""import QtQuick
Item {
    property string location: ""
    property bool imperial: false
    property string placeName: "Fixture weather"
    property bool ready: true
    property real temperature: 0
    property var current: ({kind: "clear", day: true})
    function degrees(value) { return Math.round(imperial ? value * 9 / 5 + 32 : value) + "°"; }
    function describe(kind, day) { return "Sunny"; }
}
""")
            env = os.environ.copy()
            env.pop("LD_PRELOAD", None)
            env.update({
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "QML_XHR_ALLOW_FILE_READ": "1",
                "XDG_CONFIG_HOME": str(home / "config"),
                "XDG_DATA_HOME": str(home / "data"),
                "XDG_CACHE_HOME": str(home / "cache"),
                "XDG_RUNTIME_DIR": str(home / "runtime"),
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(home / "no-session-bus"),
                "TZ": "UTC",
                "LC_ALL": "C",
            })
            result = subprocess.run(
                [sys.executable, "-B", "-I", str(Path(__file__).resolve()), "--qt-worker"],
                cwd=ROOT, env=env, capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Ran 7 tests", result.stderr)
            self.assertIn("Qt teardown completed", result.stdout)
            print(result.stderr + result.stdout, end="")


def run_qt_worker():
    from datetime import datetime, timezone
    import time

    from PyQt6 import sip
    from PyQt6.QtCore import QLocale, QObject, QMetaObject, QTimer, QUrl
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtQml import QJSValue, QQmlComponent, QQmlEngine
    from PyQt6.QtQuick import QQuickWindow

    app = QGuiApplication([])
    QLocale.setDefault(QLocale.c())
    engine = QQmlEngine()
    window = QQuickWindow()
    start = int(datetime(2019, 1, 7, 23, 59, tzinfo=timezone.utc).timestamp() * 1000)
    config = Path(os.environ["XDG_CONFIG_HOME"]) / "plasma-org.kde.plasma.desktop-appletsrc"

    class WidgetBindings(unittest.TestCase):
        def setUp(self):
            self.widget = self.component = None
            self.calendar = self.weather = self.timer = self.headings = None
            self.addCleanup(self.destroy_widget)
            config.write_text("calendarSources=[]\nweatherLocation=Fixture\nweatherUnits=1\n")
            self.component = QQmlComponent(engine, QUrl.fromLocalFile(str(
                ROOT / "patches/notification-center/src/WidgetStack.qml")))
            self.widget = self.component.create()
            self.assertIsNotNone(self.widget, [error.toString() for error in self.component.errors()])
            QQmlEngine.setObjectOwnership(self.widget, QQmlEngine.ObjectOwnership.CppOwnership)
            self.widget.setParentItem(window.contentItem())
            self.widget.setProperty("width", 390)
            engine.globalObject().setProperty("widget", engine.newQObject(self.widget))
            self.settle()
            for name in ("calendar", "weather"):
                value = self.widget.property(name)
                setattr(self, name, value.toQObject() if isinstance(value, QJSValue) else value)
                self.assertIsNotNone(getattr(self, name), name + " fixture did not load")
            self.evaluate(f"""widget.calendar.events = [
                {{title: "Expires", start: {start - 60000}, end: {start + 60000}, allDay: false}},
                {{title: "Later", start: {start + 60000}, end: {start + 3600000}, allDay: false}}
            ]""")
            self.timer, = [child for child in self.widget.findChildren(QObject)
                           if child.metaObject().className() == "QQmlTimer"]
            self.assertEqual(self.timer.property("interval"), 60000)
            self.assertTrue(self.timer.property("running"))

        def destroy_widget(self):
            engine.globalObject().setProperty("widget", QJSValue())
            self.calendar = self.weather = self.timer = self.headings = None
            if self.widget is not None:
                self.widget.setParentItem(None)
                sip.delete(self.widget)
            if self.component is not None:
                sip.delete(self.component)

        def evaluate(self, script):
            value = engine.evaluate(script)
            self.assertFalse(value.isError(), value.toString())
            return value

        def settle(self):
            QTimer.singleShot(25, app.quit)
            app.exec()

        def set_now(self, timestamp):
            # False means a dynamic QObject property, not declared/reactive QML state.
            self.assertTrue(self.widget.setProperty("now", timestamp),
                            "WidgetStack lacks declared reactive now property")

        def date_headings(self):
            return [heading.property("text") for heading in self.headings]

        def current_headings(self):
            current = datetime.fromtimestamp(self.widget.property("now") / 1000, timezone.utc)
            return [current.strftime("%A").upper(), current.strftime("%B") + " " + str(current.day)]

        def find_headings(self):
            self.headings = []
            for text in ("MONDAY", "January 7"):
                matches = [child for child in self.widget.findChildren(QObject)
                           if child.property("text") == text]
                self.assertEqual(len(matches), 1, "Date heading missing: " + text)
                self.headings.append(matches[0])

        def titles(self):
            return [event["title"] for event in self.widget.property("upcoming").toVariant()]

        def read_settings(self, units):
            config.write_text("calendarSources=[]\nweatherLocation=Fixture\n" + units)
            QMetaObject.invokeMethod(self.widget, "readSettings")
            self.settle()

        def test_expiry_boundary_uses_reactive_clock(self):
            self.set_now(start)
            self.assertEqual(self.titles(), ["Expires", "Later"])
            self.set_now(start + 60000)
            self.assertEqual(self.titles(), ["Later"])
            self.set_now(start + 3600000)
            self.assertEqual(self.titles(), [])

        def test_date_headings_roll_over_at_midnight(self):
            self.set_now(start)
            self.find_headings()
            self.set_now(start + 60000)
            self.assertEqual(self.date_headings(), ["TUESDAY", "January 8"])

        def test_reopen_refreshes_immediately_after_hidden_day(self):
            self.widget.setProperty("visible", False)
            self.assertFalse(self.timer.property("running"))
            self.set_now(start)
            self.find_headings()
            self.assertEqual(self.titles(), ["Expires", "Later"])
            before = time.time() * 1000
            self.widget.setProperty("visible", True)
            after = time.time() * 1000
            # No event-loop wait or timer tick after reopening.
            self.assertGreaterEqual(self.widget.property("now"), before - 2)
            self.assertLessEqual(self.widget.property("now"), after + 2)
            self.assertEqual(self.titles(), [])
            self.assertEqual(self.date_headings(), self.current_headings())

        def test_existing_minute_timer_refreshes_clock_and_settings(self):
            self.set_now(start)
            self.find_headings()
            config.write_text("calendarSources=[]\nweatherLocation=Fixture\nweatherUnits=0\n")
            before = time.time() * 1000
            self.timer.setProperty("interval", 1)
            self.settle()
            self.timer.setProperty("interval", 60000)
            after = time.time() * 1000
            self.assertGreaterEqual(self.widget.property("now"), before - 2)
            self.assertLessEqual(self.widget.property("now"), after + 2)
            self.assertEqual(self.titles(), [])
            self.assertEqual(self.date_headings(), self.current_headings())
            self.assertFalse(self.weather.property("imperial"))

        def test_reader_honors_fahrenheit_preference(self):
            self.assertEqual(self.widget.property("settings").toVariant().get("weatherUnits"), 1)
            self.assertTrue(self.weather.property("imperial"))

        def test_zero_and_missing_preference_use_celsius(self):
            for units in ("weatherUnits=0\n", ""):
                with self.subTest(units=units):
                    self.read_settings(units)
                    self.assertFalse(self.weather.property("imperial"))
                    self.assertEqual(self.evaluate("widget.weather").toQObject(), self.weather)

        def test_preference_changes_update_existing_backend(self):
            for units in (0, 1, 0):
                with self.subTest(units=units):
                    self.evaluate(f"widget.settings = ({{weatherUnits: {units}}})")
                    self.assertEqual(self.weather.property("imperial"), units == 1)
                    self.assertEqual(self.evaluate("widget.weather").toQObject(), self.weather)

    try:
        result = unittest.TextTestRunner(verbosity=2).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(WidgetBindings))
    finally:
        sip.delete(window)
        sip.delete(engine)
        sip.delete(app)
    print("Qt teardown completed")
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--qt-worker"]:
        sys.exit(run_qt_worker())
    unittest.main()
