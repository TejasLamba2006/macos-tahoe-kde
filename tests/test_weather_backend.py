import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
BACKEND_PATH = ROOT / "plasmoids/org.phobby.dynamicisland/contents/ui/backend/WeatherBackend.qml"


class WeatherBackendTests(unittest.TestCase):
    def test_production_weather_backend_offscreen(self):
        result = subprocess.run(
            [sys.executable, "-B", "-I", str(Path(__file__).resolve()), "--qt-worker"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=25,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Ran 7 tests", result.stderr)
        self.assertIn("Qt teardown completed", result.stdout)
        print(result.stderr + result.stdout, end="")


def run_qt_worker():
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    from PyQt6 import sip
    from PyQt6.QtCore import QMetaObject, QTimer, QUrl
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtQml import QJSValue, QQmlComponent, QQmlEngine

    class MockOpenMeteoHandler(http.server.BaseHTTPRequestHandler):
        status_to_return = 200
        custom_body = None
        delhi_started = None
        release_delhi = None
        slow_started = None
        release_slow = None

        def do_GET(self):
            if "28.62" in self.path and MockOpenMeteoHandler.delhi_started is not None:
                MockOpenMeteoHandler.delhi_started.set()
                if MockOpenMeteoHandler.release_delhi is not None:
                    MockOpenMeteoHandler.release_delhi.wait(timeout=5)

            if MockOpenMeteoHandler.slow_started is not None:
                MockOpenMeteoHandler.slow_started.set()
                if MockOpenMeteoHandler.release_slow is not None:
                    MockOpenMeteoHandler.release_slow.wait(timeout=5)

            self.send_response(MockOpenMeteoHandler.status_to_return)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            if MockOpenMeteoHandler.custom_body is not None:
                self.wfile.write(MockOpenMeteoHandler.custom_body)
                return

            lat = 48.8566 if "48.85" in self.path else 28.6214
            temp = 12.0 if lat > 40 else 19.4
            payload = {
                "latitude": lat, "longitude": 77.2148, "utc_offset_seconds": 19800, "timezone": "Asia/Kolkata",
                "current": {"time": "2026-11-08T05:30", "temperature_2m": temp, "apparent_temperature": temp + 1.8, "relative_humidity_2m": 79, "is_day": 0, "precipitation": 0, "weather_code": 0, "wind_speed_10m": 0.5, "wind_direction_10m": 90},
                "hourly": {"time": ["2026-11-08T05:00"], "temperature_2m": [temp], "apparent_temperature": [temp + 1.8], "relative_humidity_2m": [79], "precipitation_probability": [0], "precipitation": [0], "weather_code": [0], "wind_speed_10m": [0.5], "wind_direction_10m": [90], "is_day": [0]},
                "daily": {"time": ["2026-11-08"], "weather_code": [0], "temperature_2m_max": [temp + 8.0], "temperature_2m_min": [temp - 2.0], "sunrise": ["2026-11-08T06:38"], "sunset": ["2026-11-08T17:31"], "precipitation_probability_max": [0], "precipitation_sum": [0]}
            }
            self.wfile.write(json.dumps(payload).encode("utf-8"))

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), MockOpenMeteoHandler)
    server_port = server.server_address[1]
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()

    app = QGuiApplication([])
    engine = QQmlEngine()

    class WeatherTests(unittest.TestCase):
        def setUp(self):
            MockOpenMeteoHandler.status_to_return = 200
            MockOpenMeteoHandler.custom_body = None
            MockOpenMeteoHandler.delhi_started = None
            MockOpenMeteoHandler.release_delhi = None
            MockOpenMeteoHandler.slow_started = None
            MockOpenMeteoHandler.release_slow = None
            self.component = QQmlComponent(engine, QUrl.fromLocalFile(str(BACKEND_PATH)))
            self.backend = self.component.create()
            self.assertIsNotNone(self.backend, [e.toString() for e in self.component.errors()])
            self.backend.setProperty("forecastBase", f"http://127.0.0.1:{server_port}/forecast")
            engine.globalObject().setProperty("backend", engine.newQObject(self.backend))

        def tearDown(self):
            engine.globalObject().setProperty("backend", QJSValue())
            if self.backend is not None:
                sip.delete(self.backend)
                self.backend = None
            if self.component is not None:
                sip.delete(self.component)
                self.component = None

        def settle(self):
            for _ in range(120):
                QTimer.singleShot(20, app.quit)
                app.exec()
                if not self.backend.property("loading") and (self.backend.property("ready") or len(self.backend.property("problem")) > 0):
                    break
            self.assertFalse(self.backend.property("loading"), "Backend remained loading after settle timeout")

        def test_settles_ready_with_real_provider_structure(self):
            self.backend.setProperty(
                "location",
                '{"name":"New Delhi","admin":"National Capital Territory of Delhi","country":"India","latitude":28.62137,"longitude":77.2148}',
            )
            self.settle()
            self.assertTrue(self.backend.property("ready"))
            self.assertEqual(self.backend.property("problem"), "")
            self.assertEqual(self.backend.property("placeName"), "New Delhi")
            self.assertAlmostEqual(self.backend.property("temperature"), 19.4, places=1)
            self.assertEqual(self.backend.property("degreeUnit"), "°C")
            self.assertEqual(engine.evaluate("backend.degrees(backend.temperature)").toString(), "19°")
            self.assertEqual(engine.evaluate("backend.describe(backend.current.kind, backend.current.day)").toString(), "Clear")

        def test_units_conversion_metric_and_imperial(self):
            self.backend.setProperty(
                "location",
                '{"name":"New Delhi","admin":"National Capital Territory of Delhi","country":"India","latitude":28.62137,"longitude":77.2148}',
            )
            self.settle()
            self.assertEqual(self.backend.property("degreeUnit"), "°C")
            self.assertEqual(engine.evaluate("backend.degrees(19.4)").toString(), "19°")

            self.backend.setProperty("imperial", True)
            self.assertEqual(self.backend.property("degreeUnit"), "°F")
            self.assertEqual(engine.evaluate("backend.degrees(19.4)").toString(), "67°")

        def test_error_status_sets_service_problem_without_crashing(self):
            MockOpenMeteoHandler.status_to_return = 429
            MockOpenMeteoHandler.custom_body = b'{"error":true,"reason":"Daily API request limit exceeded"}'
            self.backend.setProperty(
                "location",
                '{"name":"New Delhi","admin":"National Capital Territory of Delhi","country":"India","latitude":28.62137,"longitude":77.2148}',
            )
            self.settle()
            self.assertFalse(self.backend.property("ready"))
            self.assertEqual(self.backend.property("problem"), "service")
            self.assertGreater(self.backend.property("lastAttemptAt"), 0)

        def test_direct_refresh_burst_cooldown_guards_all_callers(self):
            engine.evaluate("var mockClock = 100000000; backend.clock = function() { return mockClock; };")
            MockOpenMeteoHandler.status_to_return = 429
            MockOpenMeteoHandler.custom_body = b'{"error":true,"reason":"Daily API request limit exceeded"}'
            self.backend.setProperty(
                "location",
                '{"name":"New Delhi","admin":"National Capital Territory of Delhi","country":"India","latitude":28.62137,"longitude":77.2148}',
            )
            self.settle()
            self.assertEqual(self.backend.property("requests"), 1)

            # Direct burst of refresh() calls must be suppressed by entry cooldown
            for _ in range(5):
                engine.evaluate("backend.refresh();")
            self.settle()
            self.assertEqual(self.backend.property("requests"), 1)

            # Advance clock only 20s (< 60s): refreshIfStale and direct refresh still suppressed
            engine.evaluate("mockClock += 20000;")
            QMetaObject.invokeMethod(self.backend, "refreshIfStale")
            engine.evaluate("backend.refresh();")
            self.settle()
            self.assertEqual(self.backend.property("requests"), 1)

            # After 60s cooldown elapsed, next request succeeds
            engine.evaluate("mockClock += 45000;")  # 65s total
            MockOpenMeteoHandler.status_to_return = 200
            MockOpenMeteoHandler.custom_body = None
            engine.evaluate("backend.refresh();")
            self.settle()
            self.assertEqual(self.backend.property("requests"), 2)
            self.assertTrue(self.backend.property("ready"))
            self.assertEqual(self.backend.property("problem"), "")

        def test_slow_inflight_request_blocks_direct_refresh_beyond_cooldown(self):
            engine.evaluate("var mockClock = 100000000; backend.clock = function() { return mockClock; };")
            MockOpenMeteoHandler.slow_started = threading.Event()
            MockOpenMeteoHandler.release_slow = threading.Event()

            self.backend.setProperty(
                "location",
                '{"name":"New Delhi","admin":"National Capital Territory of Delhi","country":"India","latitude":28.62137,"longitude":77.2148}',
            )
            # Wait until request arrives at server and is held in-flight
            for _ in range(50):
                if MockOpenMeteoHandler.slow_started.is_set():
                    break
                QTimer.singleShot(10, app.quit)
                app.exec()
            self.assertTrue(self.backend.property("loading"))
            self.assertEqual(self.backend.property("requests"), 1)

            # Even if clock moves beyond 60s cooldown, active loading must block second refresh
            engine.evaluate("mockClock += 120000;")  # +120s
            engine.evaluate("backend.refresh();")
            self.assertEqual(self.backend.property("requests"), 1)

            # Release slow request and allow settlement
            MockOpenMeteoHandler.release_slow.set()
            self.settle()
            self.assertFalse(self.backend.property("loading"))
            self.assertTrue(self.backend.property("ready"))

        def test_retains_old_forecast_after_429_failure(self):
            self.backend.setProperty(
                "location",
                '{"name":"New Delhi","admin":"National Capital Territory of Delhi","country":"India","latitude":28.62137,"longitude":77.2148}',
            )
            self.settle()
            self.assertTrue(self.backend.property("ready"))
            self.assertEqual(self.backend.property("placeName"), "New Delhi")
            initial_temp = self.backend.property("temperature")

            # Subsequent fetch returns 429
            MockOpenMeteoHandler.status_to_return = 429
            MockOpenMeteoHandler.custom_body = b'{"error":true,"reason":"Daily API request limit exceeded"}'
            engine.evaluate("backend.refresh(true);")  # force bypass cooldown
            self.settle()
            self.assertEqual(self.backend.property("problem"), "service")
            # Old forecast and ready state must be retained so UI does not blank out
            self.assertTrue(self.backend.property("ready"))
            self.assertEqual(self.backend.property("temperature"), initial_temp)

        def test_held_request_late_old_place_response_does_not_clobber(self):
            MockOpenMeteoHandler.delhi_started = threading.Event()
            MockOpenMeteoHandler.release_delhi = threading.Event()

            # Place A (Delhi) is initiated and held on server
            self.backend.setProperty(
                "location",
                '{"name":"New Delhi","admin":"National Capital Territory of Delhi","country":"India","latitude":28.62137,"longitude":77.2148}',
            )
            for _ in range(50):
                if MockOpenMeteoHandler.delhi_started.is_set():
                    break
                QTimer.singleShot(10, app.quit)
                app.exec()
            self.assertTrue(MockOpenMeteoHandler.delhi_started.is_set())

            # Switch coordinates to Place B (Paris); Paris completes immediately
            self.backend.setProperty(
                "location",
                '{"name":"Paris","admin":"Ile-de-France","country":"France","latitude":48.8566,"longitude":2.3522}',
            )
            self.settle()
            self.assertEqual(self.backend.property("placeName"), "Paris")
            self.assertAlmostEqual(self.backend.property("temperature"), 12.0, places=1)

            # Now release Delhi response; must be dropped by sequence check and not clobber Paris
            MockOpenMeteoHandler.release_delhi.set()
            for _ in range(20):
                QTimer.singleShot(20, app.quit)
                app.exec()
            self.assertEqual(self.backend.property("placeName"), "Paris")
            self.assertAlmostEqual(self.backend.property("temperature"), 12.0, places=1)
            self.assertFalse(self.backend.property("loading"))

    try:
        runner = unittest.TextTestRunner(verbosity=2)
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(WeatherTests)
        result = runner.run(suite)
    finally:
        server.shutdown()
        sip.delete(engine)
        sip.delete(app)
    print("Qt teardown completed")
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--qt-worker"]:
        sys.exit(run_qt_worker())
    unittest.main()
