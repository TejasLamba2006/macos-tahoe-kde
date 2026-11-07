#!/usr/bin/env python3
import ctypes
import sys
from pathlib import Path

from PyQt6.QtCore import QFile, QIODevice

MODULES = {
    "notifications": {
        "library": "/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.notifications.so",
        "prefix": ":/qt/qml/plasma/applet/org/kde/plasma/notifications/",
        "files": [
            "FullRepresentation.qml",
            "DraggableDelegate.qml",
            "delegates/DelegateHistory.qml",
            "delegates/DelegateHistoryGrouped.qml",
            "components/NotificationHeader.qml",
        ],
        "output": "patches/notification-center/upstream",
    },
    "taskmanager": {
        "library": "/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.taskmanager.so",
        "prefix": ":/qt/qml/plasma/applet/org/kde/plasma/taskmanager/",
        "files": ["Task.qml", "TaskList.qml", "TaskBadgeOverlay.qml"],
        "output": "patches/dock/upstream",
    },
}


def extract(name: str, root: Path) -> None:
    module = MODULES[name]
    ctypes.CDLL(module["library"])
    output = root / module["output"]
    for relative in module["files"]:
        source = QFile(module["prefix"] + relative)
        if not source.open(QIODevice.OpenModeFlag.ReadOnly):
            raise RuntimeError(f"cannot read QRC resource: {relative}")
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(bytes(source.readAll()))
        print(target)


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in MODULES:
        raise SystemExit(f"usage: {sys.argv[0]} {'|'.join(MODULES)}")
    extract(sys.argv[1], Path(__file__).resolve().parents[1])
