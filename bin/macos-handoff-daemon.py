#!/usr/bin/env python3
# ponytail: bidirectional Universal Clipboard (text, URLs, and images) over KDE Connect + Wireless ADB scrcpy-server
import glob
import hashlib
import json
import os
import re
import socket
import struct
import subprocess
import threading
import time
import dbus

HANDOFF_STATE_PATH = f"/run/user/{os.getuid()}/macos-handoff-state.json"
CACHE_DIR = f"/run/user/{os.getuid()}/handoff-images"
os.makedirs(CACHE_DIR, exist_ok=True)

SCRCPY_JAR = "/usr/share/scrcpy/scrcpy-server"
SCRCPY_VER = "5.0.1"
LOCAL_PORT = 27193
SCID = "07a1b2c3"


class HandoffBridge:
    def __init__(self):
        self.bus = dbus.SessionBus()
        self.serial = None
        self.kde_dev = None
        self.conn = None
        self.proc = None
        self.lock = threading.Lock()

        self.last_text = ""
        self.last_img_hash = ""
        self.last_phone_media_id = None
        self.known_downloads = set(self.scan_download_images())
        self.handoff_url = ""
        self.handoff_preview = ""
        self.handoff_image = ""
        self.call_state = ""       # "", "incoming", "dialing", "active"
        self.call_number = ""
        self.call_name = ""
        self.hfp_connected = False
        self.mirror_running = False
        self.audio_route = "phone"
        self.contacts = []
        self.load_contacts()

    def load_contacts(self):
        # 1. Trigger KDE Connect contacts sync if device is available
        if self.kde_dev:
            try:
                c_obj = self.bus.get_object("org.kde.kdeconnect", f"/modules/kdeconnect/devices/{self.kde_dev}/contacts")
                c_iface = dbus.Interface(c_obj, "org.kde.kdeconnect.device.contacts")
                c_iface.synchronizeRemoteWithLocal()
            except Exception:
                pass

        by_num = {}
        # 2. Parse KDE Connect vCard files (~/.local/share/kpeoplevcard/kdeconnect-*)
        vcard_root = os.path.expanduser("~/.local/share/kpeoplevcard")
        for vcf in glob.glob(os.path.join(vcard_root, "kdeconnect-*", "*.vcf")):
            try:
                raw = open(vcf, "r", encoding="utf-8", errors="ignore").read()
                fn_m = re.search(r"^FN(?:;[^:]*)?:(.+)$", raw, re.M)
                if not fn_m:
                    continue
                name = fn_m.group(1).strip()
                # Decode Quoted-Printable UTF-8 if present
                if "ENCODING=QUOTED-PRINTABLE" in raw and "=" in name:
                    import quopri
                    try:
                        name = quopri.decodestring(name.encode("ascii", errors="ignore")).decode("utf-8", errors="ignore").strip()
                    except Exception:
                        pass
                for tel_m in re.finditer(r"^TEL(?:;[^:]*)?:(.+)$", raw, re.M):
                    num = re.sub(r"[^\d+]", "", tel_m.group(1).strip())
                    if len(num) >= 6 and name and not name.startswith("Identified by"):
                        key = num[-10:]
                        by_num[key] = {"name": name, "number": num}
            except Exception:
                pass

        # 3. Also pull from ADB Contacts Provider if ADB is active
        if self.serial:
            try:
                out = subprocess.check_output(
                    [
                        "adb", "-s", self.serial, "shell",
                        "content query --uri content://com.android.contacts/data/phones --projection display_name:data1"
                    ],
                    text=True, stderr=subprocess.DEVNULL, timeout=2.5
                )
                for line in out.splitlines():
                    m = re.search(r"display_name=([^,]+),\s*data1=(.+)$", line)
                    if m:
                        name = m.group(1).strip()
                        num = re.sub(r"[^\d+]", "", m.group(2).strip())
                        if len(num) >= 6 and name and name != "NULL":
                            by_num[num[-10:]] = {"name": name, "number": num}
            except Exception:
                pass

        self.contacts = sorted(by_num.values(), key=lambda x: x["name"].lower())

    def resolve_contact_name(self, number):
        clean = re.sub(r"[^\d+]", "", str(number or ""))
        if len(clean) >= 6:
            tail = clean[-10:]
            for c in self.contacts:
                if c["number"].endswith(tail) or tail.endswith(c["number"][-10:]):
                    return c["name"]
        return ""

    def check_telephony_and_mirror(self):
        # 1. Check if iPhone Mirroring window is running
        pid_file = f"/run/user/{os.getuid()}/macos-phone-mirror.pid"
        self.mirror_running = False
        if os.path.exists(pid_file):
            try:
                pid = int(open(pid_file).read().strip())
                os.kill(pid, 0)
                self.mirror_running = True
            except Exception:
                pass

        # 2. Check audio route preference (~/.config/macos-phone-audio-route)
        route_file = os.path.expanduser("~/.config/macos-phone-audio-route")
        if not os.path.exists(route_file):
            # Default to "phone" so normal phone music/reels don't unexpectedly play on PC unless toggled or calling
            try:
                open(route_file, "w").write("phone")
            except Exception:
                pass
            subprocess.Popen([os.path.expanduser("~/.local/bin/macos-phone-ctl"), "audio-route", "phone"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            self.audio_route = open(route_file).read().strip() or "phone"
        except Exception:
            self.audio_route = "phone"

        # 3. Check PipeWire Bluetooth HFP AudioGateway1 & active calls
        try:
            mgr = self.bus.get_object("org.pipewire.Telephony", "/org/pipewire/Telephony")
            om = dbus.Interface(mgr, "org.freedesktop.DBus.ObjectManager")
            objs = om.GetManagedObjects()
            ag_paths = [p for p, ifs in objs.items() if "org.pipewire.Telephony.AudioGateway1" in ifs]
            self.hfp_connected = bool(ag_paths)

            active_call_found = False
            for path, ifs in objs.items():
                if "org.ofono.VoiceCall" in ifs:
                    props = ifs["org.ofono.VoiceCall"]
                    state = str(props.get("State", ""))
                    line_id = str(props.get("LineIdentification", ""))
                    resolved = self.resolve_contact_name(line_id)
                    name = resolved or str(props.get("Name", "")) or line_id or "Phone Call"
                    if state in ("incoming", "waiting", "dialing", "alerting", "active", "held"):
                        active_call_found = True
                        prev_state = self.call_state
                        self.call_state = "incoming" if state in ("incoming", "waiting") else ("dialing" if state in ("dialing", "alerting") else "active")
                        self.call_number = line_id
                        self.call_name = name
                        if self.call_state != prev_state:
                            sub = f"Incoming Call • {line_id}" if self.call_state == "incoming" else f"Speaking on {'Laptop' if self.audio_route == 'laptop' else 'Phone'} • {line_id}"
                            subprocess.Popen(
                                [
                                    os.path.expanduser("~/.local/bin/island-push"),
                                    "--id", "phone-call",
                                    "--category", "call",
                                    "--title", name,
                                    "--subtitle", sub,
                                    "--icon", "call-start-symbolic",
                                    "--color", "green",
                                    "--priority", "98",
                                ],
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                            )
                        break

            if not active_call_found and self.call_state:
                self.call_state = ""
                self.call_number = ""
                self.call_name = ""
                subprocess.Popen(
                    [os.path.expanduser("~/.local/bin/island-push"), "--id", "phone-call", "--done", "--status", "cancel"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
        except Exception:
            self.hfp_connected = False

        if not self.hfp_connected and getattr(self, "_bt_tick", 0) % 15 == 0:
            subprocess.Popen(
                [os.path.expanduser("~/.local/bin/macos-phone-ctl"), "connect-audio"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        self._bt_tick = getattr(self, "_bt_tick", 0) + 1

    def scan_download_images(self):
        dl = os.path.expanduser("~/Downloads")
        if not os.path.isdir(dl):
            return []
        out = []
        for ext in ("*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"):
            out.extend(glob.glob(os.path.join(dl, ext)))
        return out

    def write_state(self):
        state = {
            "connected": bool(self.conn is not None or self.kde_dev or self.hfp_connected),
            "device": self.serial or self.kde_dev or "",
            "hfpConnected": self.hfp_connected,
            "audioRoute": self.audio_route,
            "mirrorRunning": self.mirror_running,
            "callState": self.call_state,
            "callNumber": self.call_number,
            "callName": self.call_name,
            "contactsCount": len(self.contacts),
            "contacts": self.contacts,
            "handoffUrl": self.handoff_url,
            "handoffPreview": self.handoff_preview,
            "handoffImage": self.handoff_image,
        }
        try:
            tmp = HANDOFF_STATE_PATH + ".tmp"
            with open(tmp, "w") as f:
                json.dump(state, f)
            os.replace(tmp, HANDOFF_STATE_PATH)
        except Exception:
            pass

    def island_flash(self, title, subtitle, icon="edit-paste", color="blue"):
        subprocess.Popen(
            [
                os.path.expanduser("~/.local/bin/island-push"),
                "--flash",
                "--title", title,
                "--subtitle", subtitle[:60],
                "--icon", icon,
                "--color", color,
                "--duration", "3000",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def island_url_activity(self, url):
        host = re.sub(r"^https?://(www\.)?", "", url).split("/")[0]
        subprocess.Popen(
            [
                os.path.expanduser("~/.local/bin/island-push"),
                "--id", "handoff-url",
                "--category", "transfer",
                "--title", "Handoff URL Ready",
                "--subtitle", host,
                "--icon", "internet-web-browser-symbolic",
                "--color", "blue",
                "--timeout", "15",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def find_kdeconnect_device(self):
        try:
            daemon = self.bus.get_object("org.kde.kdeconnect", "/modules/kdeconnect")
            d_iface = dbus.Interface(daemon, "org.kde.kdeconnect.daemon")
            try:
                d_iface.forceOnNetworkChange()
            except Exception:
                pass
            devs = list(d_iface.devices(True, True))
            if devs:
                self.kde_dev = str(devs[0])
                return self.kde_dev
        except Exception:
            pass
        self.kde_dev = None
        return None

    def find_adb_serial(self):
        try:
            out = subprocess.check_output(["adb", "devices"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
            devs = []
            for line in out.splitlines()[1:]:
                parts = line.split()
                if len(parts) >= 2 and parts[1] == "device":
                    devs.append(parts[0])
            for d in devs:
                if re.match(r"^\d+\.\d+\.\d+\.\d+:\d+$", d):
                    return d
            if devs:
                return devs[0]
        except Exception:
            pass

        try:
            p = subprocess.Popen(
                ["avahi-browse", "-rp", "_adb-tls-connect._tcp"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
            )
            time.sleep(1.2)
            p.terminate()
            out, _ = p.communicate(timeout=1.0)
            for line in out.splitlines():
                if line.startswith("=") and "IPv4" in line:
                    cols = line.split(";")
                    if len(cols) >= 9:
                        target = f"{cols[7]}:{cols[8]}"
                        subprocess.run(["adb", "connect", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.5)
                        return target
        except Exception:
            pass
        return None

    def get_desktop_text(self):
        try:
            out = subprocess.check_output(["wl-paste", "--no-newline", "--type", "text/plain;charset=utf-8"], text=True, stderr=subprocess.DEVNULL, timeout=0.5).strip()
            if out:
                return out
        except Exception:
            pass
        try:
            klipper = self.bus.get_object("org.kde.klipper", "/klipper")
            iface = dbus.Interface(klipper, "org.kde.klipper.klipper")
            val = str(iface.getClipboardContents() or "").strip()
            if val and not val.startswith("▨ "):
                return val
        except Exception:
            pass
        return ""

    def set_desktop_text(self, text):
        try:
            klipper = self.bus.get_object("org.kde.klipper", "/klipper")
            iface = dbus.Interface(klipper, "org.kde.klipper.klipper")
            iface.setClipboardContents(text)
        except Exception:
            pass
        try:
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            p.communicate(input=text.encode("utf-8"), timeout=1.0)
        except Exception:
            pass

    def get_desktop_image_bytes(self):
        try:
            types = subprocess.check_output(["wl-paste", "--list-types"], text=True, stderr=subprocess.DEVNULL, timeout=0.6).splitlines()
            img_mime = None
            for m in ("image/png", "image/jpeg", "image/webp"):
                if m in types:
                    img_mime = m
                    break
            if not img_mime:
                return None, None
            data = subprocess.check_output(["wl-paste", "--type", img_mime], stderr=subprocess.DEVNULL, timeout=1.5)
            if data and len(data) > 64:
                return data, img_mime
        except Exception:
            pass
        return None, None

    def set_desktop_image_file(self, path):
        try:
            with open(path, "rb") as f:
                data = f.read()
            self.last_img_hash = hashlib.sha256(data).hexdigest()
            mime = "image/png" if path.lower().endswith(".png") else "image/jpeg"
            p = subprocess.Popen(["wl-copy", "--type", mime], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            p.communicate(input=data, timeout=2.0)
            self.handoff_image = path
            self.write_state()
        except Exception:
            pass

    def push_text_to_phone(self, text):
        sent = False
        # Channel 1: KDE Connect clipboard plugin (instant over Wi-Fi LAN)
        if self.kde_dev:
            try:
                clip_obj = self.bus.get_object("org.kde.kdeconnect", f"/modules/kdeconnect/devices/{self.kde_dev}/clipboard")
                clip_iface = dbus.Interface(clip_obj, "org.kde.kdeconnect.device.clipboard")
                clip_iface.sendClipboard()
                sent = True
            except Exception:
                pass

        # Channel 2: scrcpy-server control socket over ADB (if connected)
        with self.lock:
            if self.conn:
                try:
                    raw = text.encode("utf-8")[:262140]
                    pkt = struct.pack(">BQBI", 9, 1, 0, len(raw)) + raw
                    self.conn.sendall(pkt)
                    sent = True
                except Exception:
                    self.conn = None

        if sent:
            self.island_flash("Handoff → Phone", text, "edit-copy", "green")
        return sent

    def push_image_to_phone(self, data, mime):
        ext = ".png" if "png" in mime else ".jpg"
        local_tmp = os.path.join(CACHE_DIR, f"Handoff_Clip_{int(time.time())}{ext}")
        try:
            with open(local_tmp, "wb") as f:
                f.write(data)
        except Exception:
            return

        sent = False
        # Channel 1: KDE Connect shareUrl (transfers image directly to phone over LAN)
        if self.kde_dev:
            try:
                share_obj = self.bus.get_object("org.kde.kdeconnect", f"/modules/kdeconnect/devices/{self.kde_dev}/share")
                share_iface = dbus.Interface(share_obj, "org.kde.kdeconnect.device.share")
                share_iface.shareUrl(f"file://{local_tmp}")
                sent = True
            except Exception:
                pass

        # Channel 2: ADB push + MediaScanner (if ADB active)
        if self.serial:
            remote_path = f"/sdcard/Pictures/{os.path.basename(local_tmp)}"
            try:
                subprocess.run(["adb", "-s", self.serial, "push", local_tmp, remote_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)
                subprocess.run(
                    ["adb", "-s", self.serial, "shell", f"am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://{remote_path}"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0
                )
                sent = True
            except Exception:
                pass

        if sent:
            self.handoff_image = local_tmp
            self.write_state()
            self.island_flash("Handoff → Phone", f"Image synced to phone ({len(data)//1024} KB)", "image-x-generic-symbolic", "green")

    def poll_phone_latest_image(self):
        # 1. Check ~/Downloads for newly received KDE Connect image shares
        current_dl = set(self.scan_download_images())
        new_dl = current_dl - self.known_downloads
        self.known_downloads = current_dl
        if new_dl:
            newest = max(new_dl, key=lambda p: os.path.getmtime(p))
            if time.time() - os.path.getmtime(newest) < 15:
                self.set_desktop_image_file(newest)
                self.island_flash("Handoff ← Phone", f"Image copied to desktop clipboard ({os.path.basename(newest)})", "image-x-generic-symbolic", "blue")
                return

        # 2. Check ADB MediaStore for new screenshots/photos on phone
        if not self.serial or not self.conn:
            return
        try:
            out = subprocess.check_output(
                [
                    "adb", "-s", self.serial, "shell",
                    'content query --uri content://media/external/images/media --projection _id:_data:date_added --sort "date_added DESC" | head -n 1'
                ],
                text=True, stderr=subprocess.DEVNULL, timeout=1.5
            ).strip()
            m_id = re.search(r"_id=(\d+)", out)
            m_path = re.search(r"_data=([^,]+),\s*date_added=", out)
            if not m_id or not m_path:
                return
            img_id = int(m_id.group(1))
            remote_path = m_path.group(1).strip()
            if self.last_phone_media_id is None:
                self.last_phone_media_id = img_id
                return
            if img_id > self.last_phone_media_id:
                self.last_phone_media_id = img_id
                if "Handoff_Clip_" in remote_path:
                    return
                ext = os.path.splitext(remote_path)[1] or ".jpg"
                local_dst = os.path.join(CACHE_DIR, f"phone_{img_id}{ext}")
                subprocess.run(["adb", "-s", self.serial, "pull", remote_path, local_dst], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)
                if os.path.exists(local_dst):
                    self.set_desktop_image_file(local_dst)
                    self.island_flash("Handoff ← Phone", f"Image copied to desktop clipboard ({os.path.basename(remote_path)})", "image-x-generic-symbolic", "blue")
        except Exception:
            pass

    def reader_loop(self, conn):
        buf = b""
        try:
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                buf += chunk
                while len(buf) > 0:
                    msg_type = buf[0]
                    if msg_type == 0:
                        if len(buf) < 5:
                            break
                        ln = struct.unpack(">I", buf[1:5])[0]
                        if len(buf) < 5 + ln:
                            break
                        text = buf[5:5 + ln].decode("utf-8", errors="ignore").strip()
                        buf = buf[5 + ln:]
                        if text and text != self.last_text:
                            self.last_text = text
                            self.handoff_preview = text[:120]
                            self.set_desktop_text(text)
                            if re.match(r"^https?://[^\s<>\"']+$", text):
                                self.handoff_url = text
                                self.island_url_activity(text)
                            else:
                                self.island_flash("Handoff ← Phone", text, "edit-paste", "blue")
                            self.write_state()
                    elif msg_type == 1:
                        if len(buf) < 9:
                            break
                        buf = buf[9:]
                    else:
                        buf = b""
        except Exception:
            pass
        finally:
            with self.lock:
                if self.conn is conn:
                    self.conn = None
            self.write_state()

    def connect_scrcpy_server(self):
        ser = self.find_adb_serial()
        if not ser:
            self.serial = None
            return False
        self.serial = ser
        try:
            subprocess.run(["adb", "-s", ser, "push", SCRCPY_JAR, "/data/local/tmp/scrcpy-server.jar"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
            srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            srv.bind(("127.0.0.1", LOCAL_PORT))
            srv.listen(2)
            srv.settimeout(4.0)

            subprocess.run(["adb", "-s", ser, "reverse", f"localabstract:scrcpy_{SCID}", f"tcp:{LOCAL_PORT}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
            self.proc = subprocess.Popen(
                [
                    "adb", "-s", ser, "shell",
                    f"CLASSPATH=/data/local/tmp/scrcpy-server.jar app_process / com.genymobile.scrcpy.Server {SCRCPY_VER} scid={SCID} log_level=info video=false audio=false control=true cleanup=false"
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            conn, _ = srv.accept()
            srv.close()
            conn.settimeout(2.0)
            _ = conn.recv(64)
            conn.settimeout(None)
            with self.lock:
                self.conn = conn
            self.poll_phone_latest_image()
            self.write_state()
            t = threading.Thread(target=self.reader_loop, args=(conn,), daemon=True)
            t.start()
            return True
        except Exception:
            try:
                srv.close()
            except Exception:
                pass
            return False

    def run(self):
        self.last_text = self.get_desktop_text()
        img_data, _ = self.get_desktop_image_bytes()
        if img_data:
            self.last_img_hash = hashlib.sha256(img_data).hexdigest()

        tick = 0
        while True:
            self.find_kdeconnect_device()
            self.check_telephony_and_mirror()
            if self.conn is None and tick % 5 == 0:
                self.connect_scrcpy_server()
            self.write_state()

            # 1. Desktop <-> Phone text & URL sync
            desk_text = self.get_desktop_text()
            if desk_text and desk_text != self.last_text:
                self.last_text = desk_text
                self.handoff_preview = desk_text[:120]
                if re.match(r"^https?://[^\s<>\"']+$", desk_text):
                    self.handoff_url = desk_text
                    self.island_url_activity(desk_text)
                self.push_text_to_phone(desk_text)
                self.write_state()

            # 2. Desktop -> Phone image sync
            img_data, img_mime = self.get_desktop_image_bytes()
            if img_data:
                h = hashlib.sha256(img_data).hexdigest()
                if h != self.last_img_hash:
                    self.last_img_hash = h
                    self.push_image_to_phone(img_data, img_mime)

            # 3. Phone -> Desktop image sync
            if tick % 2 == 0:
                self.poll_phone_latest_image()
            if tick % 30 == 0:
                self.load_contacts()

            tick += 1
            time.sleep(1.0)


if __name__ == "__main__":
    HandoffBridge().run()
