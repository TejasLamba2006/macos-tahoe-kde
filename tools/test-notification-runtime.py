#!/usr/bin/env python3
"""Exercise actual notification widget backends without a Python Qt log handler."""
import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

from PyQt6 import sip
from PyQt6.QtCore import QTimer, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlComponent, QQmlEngine, QJSValue

app = QGuiApplication([])
engine = QQmlEngine()
engine.addImportPath(str(Path.home() / ".local/lib/qml"))
source = Path(__file__).resolve().parents[1] / "patches/notification-center/src/WidgetStack.qml"
component = QQmlComponent(engine, QUrl.fromLocalFile(str(source)))
widget = component.create()
assert widget is not None, [e.toString() for e in component.errors()]
widget.setProperty("width", 390)
QTimer.singleShot(8000, app.quit)
app.exec()
settings = widget.property("settings").toVariant()
assert "calendarSources" in settings, "Dynamic Island calendar sources were not read"
for name in ("calendar", "weather"):
    backend = widget.property(name)
    if isinstance(backend, QJSValue):
        backend = backend.toQObject()
    assert backend is not None, f"{name} backend failed to instantiate"
    if name == "calendar":
        assert backend.property("loaded"), "Calendar download/parser did not settle"
    else:
        assert backend.property("ready") or backend.property("problem"), "Weather neither loaded nor reported failure"
    print(f"PASS: {name} backend constructed and settled")
    del backend
sip.delete(widget)
sip.delete(component)
sip.delete(engine)
sip.delete(app)
print("PASS: clean Qt teardown")
