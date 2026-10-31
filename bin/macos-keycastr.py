#!/usr/bin/env python3
# ponytail: macOS Keycastr / CleanShot Keystroke Visualizer HUD — reads /dev/input/event* and renders frosted macOS shortcut pills
import glob
import os
import select
import signal
import struct
import sys
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QColor, QFont, QGuiApplication, QPainter, QPainterPath
from PyQt6.QtWidgets import QApplication, QLabel, QHBoxLayout, QWidget

PID_FILE = f"/run/user/{os.getuid()}/macos-keycastr.pid"

# Linux input-event-codes (EV_KEY = 1)
MOD_KEYS = {
    29: "⌃", 97: "⌃",     # Left/Right Ctrl
    56: "⌥", 100: "⌥",    # Left/Right Option (Alt)
    42: "⇧", 54: "⇧",     # Left/Right Shift
    125: "⌘", 126: "⌘",   # Left/Right Command (Meta)
}

KEY_NAMES = {
    1: "⎋ Esc", 14: "⌫", 15: "⇥ Tab", 28: "↩ Return", 57: "Space",
    2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7", 9: "8", 10: "9", 11: "0",
    12: "-", 13: "=", 16: "Q", 17: "W", 18: "E", 19: "R", 20: "T", 21: "Y", 22: "U", 23: "I", 24: "O", 25: "P",
    26: "[", 27: "]", 30: "A", 31: "S", 32: "D", 33: "F", 34: "G", 35: "H", 36: "J", 37: "K", 38: "L",
    39: ";", 40: "'", 41: "`", 43: "\\", 44: "Z", 45: "X", 46: "C", 47: "V", 48: "B", 49: "N", 50: "M",
    51: ",", 52: ".", 53: "/",
    59: "F1", 60: "F2", 61: "F3", 62: "F4", 63: "F5", 64: "F6", 65: "F7", 66: "F8", 67: "F9", 68: "F10", 87: "F11", 88: "F12",
    103: "↑", 108: "↓", 105: "←", 106: "→", 111: "⌦",
}


class KeycastrOverlay(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Keycastr")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
            | Qt.WindowType.WindowTransparentForInput
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(20, 10, 20, 10)
        self.label = QLabel("")
        self.label.setFont(QFont("SF Pro Display", 18, QFont.Weight.DemiBold))
        self.label.setStyleSheet("color: #FFFFFF; letter-spacing: 1px;")
        layout.addWidget(self.label)

        self.hide_timer = QTimer(self)
        self.hide_timer.setSingleShot(True)
        self.hide_timer.timeout.connect(self.hide)

        self.held_mods = set()
        self.fds = []
        self.open_keyboards()

        self.poll_timer = QTimer(self)
        self.poll_timer.timeout.connect(self.poll_events)
        self.poll_timer.start(16)

    def open_keyboards(self):
        for p in glob.glob("/dev/input/event*"):
            try:
                name_path = f"/sys/class/input/{os.path.basename(p)}/device/name"
                name = open(name_path).read().strip().lower() if os.path.exists(name_path) else ""
                if any(k in name for k in ("keyboard", "kbd", "translated set 2", "usb")):
                    fd = os.open(p, os.O_RDONLY | os.O_NONBLOCK)
                    self.fds.append(fd)
            except Exception:
                pass

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        path = QPainterPath()
        path.addRoundedRect(1, 1, self.width() - 2, self.height() - 2, 16, 16)
        painter.fillPath(path, QColor(18, 19, 24, 225))
        painter.setPen(QColor(255, 255, 255, 48))
        painter.drawPath(path)

    def show_combo(self, text):
        self.label.setText(text)
        self.adjustSize()
        scr = QGuiApplication.primaryScreen()
        if scr:
            geo = scr.geometry()
            self.move(geo.x() + (geo.width() - self.width()) // 2, geo.y() + geo.height() - 135)
        self.show()
        self.raise_()
        self.hide_timer.start(1350)

    def poll_events(self):
        if not self.fds:
            return
        r, _, _ = select.select(self.fds, [], [], 0)
        for fd in r:
            try:
                while True:
                    buf = os.read(fd, 24)
                    if len(buf) < 24:
                        break
                    _, _, ev_type, code, val = struct.unpack("llHHi", buf)
                    if ev_type != 1:
                        continue
                    if code in MOD_KEYS:
                        if val == 1:
                            self.held_mods.add(MOD_KEYS[code])
                        elif val == 0:
                            self.held_mods.discard(MOD_KEYS[code])
                    elif val == 1 and code in KEY_NAMES:
                        key_str = KEY_NAMES[code]
                        # Show shortcuts with modifiers or special keys (Return/Tab/Esc/F-keys/Space)
                        if self.held_mods or len(key_str) > 1:
                            ordered_mods = [m for m in ("⌃", "⌥", "⇧", "⌘") if m in self.held_mods]
                            combo = " + ".join(ordered_mods + [key_str])
                            self.show_combo(combo)
            except BlockingIOError:
                pass
            except Exception:
                pass


def is_running():
    if not os.path.exists(PID_FILE):
        return False
    try:
        os.kill(int(open(PID_FILE).read().strip()), 0)
        return True
    except Exception:
        return False


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if cmd == "status":
        print("running" if is_running() else "stopped")
        return
    if cmd == "stop" or (cmd == "toggle" and is_running()):
        if is_running():
            try:
                os.kill(int(open(PID_FILE).read().strip()), signal.SIGTERM)
            except Exception:
                pass
            try:
                os.remove(PID_FILE)
            except Exception:
                pass
        os.system("~/.local/bin/island-push --flash --title 'Keycastr OFF' --subtitle 'Keystroke visualizer hidden' --icon input-keyboard-symbolic --color gray --duration 2000 >/dev/null 2>&1 &")
        print("stopped")
        return

    if cmd in ("start", "toggle"):
        if os.fork() > 0:
            os.system("~/.local/bin/island-push --flash --title 'Keycastr ON' --subtitle 'Showing live macOS shortcut pills (⌘ ⌥ ⌃ ⇧)' --icon input-keyboard-symbolic --color purple --duration 2600 >/dev/null 2>&1 &")
            print("running")
            return
        os.setsid()
        with open(PID_FILE, "w") as f:
            f.write(str(os.getpid()))
        app = QApplication(sys.argv)
        overlay = KeycastrOverlay()
        sys.exit(app.exec())


if __name__ == "__main__":
    main()
