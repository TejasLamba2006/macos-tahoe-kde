#!/usr/bin/env python3
# ponytail: floating PyQt6 Wireless ADB QR Scanner + Manual Code Pairing dialog for macOS Continuity Camera
import os
import random
import string
import subprocess
import sys
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QFont, QPixmap
from PyQt6.QtWidgets import (
    QApplication,
    QDialog,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QVBoxLayout,
)

class AdbPairDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Continuity Camera — Wireless ADB Pairing")
        self.setFixedSize(410, 470)
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.WindowStaysOnTopHint)
        self.setStyleSheet("""
            QDialog {
                background-color: #1c1d22;
                color: #ffffff;
                border-radius: 16px;
            }
            QLabel {
                color: #ebebf5;
                font-family: 'SF Pro Text', sans-serif;
            }
            QLineEdit {
                background-color: #2c2d35;
                color: #ffffff;
                border: 1px solid #444552;
                border-radius: 8px;
                padding: 6px 10px;
                font-size: 13px;
            }
            QPushButton {
                background-color: #0a84ff;
                color: #ffffff;
                border: none;
                border-radius: 8px;
                padding: 7px 14px;
                font-weight: 600;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #409cff;
            }
            QPushButton#cancelBtn {
                background-color: #3a3b44;
            }
        """)

        self.svc_name = "debug-" + "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
        self.password = "".join(random.choices(string.digits, k=6))
        self.qr_payload = f"WIFI:T:ADB;S:{self.svc_name};P:{self.password};;"
        self.qr_path = f"/run/user/{os.getuid()}/adb-qr.png"
        subprocess.run(["qrencode", "-s", "7", "-m", "2", "-o", self.qr_path, self.qr_payload], check=False)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(22, 20, 22, 20)
        layout.setSpacing(10)

        title = QLabel("Pair Phone for Continuity Camera")
        title.setFont(QFont("SF Pro Display", 15, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        sub = QLabel(
            "Option 1: On Android, open Developer options → Wireless debugging\n"
            "→ 'Pair device with QR code' and scan:"
        )
        sub.setStyleSheet("color: #aeaeb2; font-size: 12px;")
        sub.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(sub)

        qr_label = QLabel()
        qr_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        if os.path.exists(self.qr_path):
            pix = QPixmap(self.qr_path).scaled(190, 190, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            qr_label.setPixmap(pix)
        layout.addWidget(qr_label)

        self.status_lbl = QLabel("Waiting for phone to scan QR code…")
        self.status_lbl.setStyleSheet("color: #30d158; font-size: 12px; font-weight: 600;")
        self.status_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.status_lbl)

        or_lbl = QLabel("— OR Option 2: Enter IP:Port & 6-Digit Code Manually —")
        or_lbl.setStyleSheet("color: #8e8e93; font-size: 11px;")
        or_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(or_lbl)

        self.input_box = QLineEdit()
        self.input_box.setPlaceholderText("e.g. 192.168.1.33:39123 482910  (or just IP:Port)")
        self.input_box.returnPressed.connect(self.manual_pair)
        layout.addWidget(self.input_box)

        btn_row = QHBoxLayout()
        cancel_btn = QPushButton("Cancel")
        cancel_btn.setObjectName("cancelBtn")
        cancel_btn.clicked.connect(self.reject)

        pair_btn = QPushButton("Pair / Connect")
        pair_btn.clicked.connect(self.manual_pair)

        btn_row.addWidget(cancel_btn)
        btn_row.addWidget(pair_btn)
        layout.addLayout(btn_row)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.poll_mdns)
        self.timer.start(1000)

    def poll_mdns(self):
        try:
            out = subprocess.check_output(["adb", "mdns", "services"], text=True, stderr=subprocess.DEVNULL, timeout=1.0)
            for line in out.splitlines():
                # Look for QR pairing service (_adb-tls-pairing._tcp)
                if "_adb-tls-pairing._tcp" in line:
                    addr = line.split()[-1]
                    self.status_lbl.setText(f"Phone detected at {addr}! Pairing…")
                    QApplication.processEvents()
                    subprocess.run(["adb", "pair", addr, self.password], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)
                # Look for active connect service (_adb-tls-connect._tcp)
                if "_adb-tls-connect._tcp" in line:
                    conn_addr = line.split()[-1]
                    subprocess.run(["adb", "connect", conn_addr], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)

            state = subprocess.run(["adb", "get-state"], capture_output=True, text=True, timeout=1.0)
            if state.returncode == 0 and "device" in state.stdout:
                self.accept()
        except Exception:
            pass

    def manual_pair(self):
        text = self.input_box.text().strip()
        if not text:
            return
        parts = text.split()
        addr = parts[0]
        code = parts[1] if len(parts) > 1 else ""
        self.status_lbl.setText(f"Connecting to {addr}…")
        QApplication.processEvents()
        if code:
            subprocess.run(["adb", "pair", addr, code], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5.0)
            # Also try auto-connecting via mDNS after pairing
            try:
                out = subprocess.check_output(["adb", "mdns", "services"], text=True, stderr=subprocess.DEVNULL, timeout=1.0)
                for line in out.splitlines():
                    if "_adb-tls-connect._tcp" in line:
                        subprocess.run(["adb", "connect", line.split()[-1]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
            except Exception:
                pass
        else:
            subprocess.run(["adb", "connect", addr], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)

        state = subprocess.run(["adb", "get-state"], capture_output=True, text=True, timeout=1.0)
        if state.returncode == 0 and "device" in state.stdout:
            self.accept()
        else:
            self.status_lbl.setStyleSheet("color: #ff453a; font-size: 12px;")
            self.status_lbl.setText("Could not connect yet — check IP:Port or scan QR")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    dlg = AdbPairDialog()
    sys.exit(0 if dlg.exec() == QDialog.DialogCode.Accepted else 1)
