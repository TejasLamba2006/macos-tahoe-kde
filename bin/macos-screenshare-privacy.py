#!/usr/bin/env python3
# ponytail: watches PipeWire screen-sharing (debounced 2-tick start / 3-tick stop), snapshots & restores exact desktop icon positions, writes /run/user/UID/macos-privacy-status.json, and keeps WhatsApp Web Privacy Blur active
import base64
import glob
import json
import os
import re
import socket
import subprocess
import time
import urllib.request
import dbus

EMPTY_DIR = "/tmp/empty-desktop"
os.makedirs(EMPTY_DIR, exist_ok=True)
STATUS_PATH = f"/run/user/{os.getuid()}/macos-privacy-status.json"
PORTS_PATH = f"/run/user/{os.getuid()}/macos-ports-status.json"
POS_BACKUP_PATH = os.path.expanduser("~/.config/macos-desktop-positions-backup.json")

IGNORE_PROCS = {
    "systemd", "systemd-resolve", "kdeconnectd", "spotify", "Discord",
    "chrome", "open-whispr-app", "sherpa-onnx-ws-", "openclaw-gatewa",
    "cupsd", "sshd", "avahi-daemon", "dnsmasq", "warp-svc", "adb"
}
IGNORE_PORTS = {53, 631, 1716, 5037, 5355, 6006, 6463, 8200, 9222, 9223, 18789, 18791, 18792}
LAST_HANDOFF_CLIP = ""
LAST_HANDOFF_URL = ""
PAUSED_BY_DUCKING = set()
CACHED_GCAL_MEETING = None
LAST_GCAL_SCAN = 0
ANNOUNCED_MEETING_IDS = set()

WA_INJECT_JS = r"""
(() => {
  if (document.getElementById('macos-wa-privacy-blur')) return 'already-active';
  const st = document.createElement('style');
  st.id = 'macos-wa-privacy-blur';
  st.textContent = `
    html:not(.wa-privacy-off) #pane-side [role="row"] > div,
    html:not(.wa-privacy-off) #pane-side [role="listitem"] > div {
      filter: blur(7px) !important;
      transition: filter 0.18s ease-in-out !important;
    }
    html:not(.wa-privacy-off) #pane-side [role="row"]:hover > div,
    html:not(.wa-privacy-off) #pane-side [role="listitem"]:hover > div {
      filter: none !important;
    }
    html:not(.wa-privacy-off) #main [role="row"] > div,
    html:not(.wa-privacy-off) #main .message-in,
    html:not(.wa-privacy-off) #main .message-out {
      filter: blur(6px) !important;
      transition: filter 0.18s ease-in-out !important;
    }
    html:not(.wa-privacy-off) #main [role="row"]:hover > div,
    html:not(.wa-privacy-off) #main .message-in:hover,
    html:not(.wa-privacy-off) #main .message-out:hover {
      filter: none !important;
    }
    html:not(.wa-privacy-off) #main header img,
    html:not(.wa-privacy-off) #main header span[dir="auto"] {
      filter: blur(5px) !important;
      transition: filter 0.18s ease-in-out !important;
    }
    html:not(.wa-privacy-off) #main header:hover img,
    html:not(.wa-privacy-off) #main header:hover span[dir="auto"] {
      filter: none !important;
    }
  `;
  (document.head || document.documentElement).appendChild(st);

  if (!window.__waPrivacyKeyBound) {
    window.__waPrivacyKeyBound = true;
    window.addEventListener('keydown', (e) => {
      if (e.altKey && (e.code === 'KeyX' || e.key === 'x' || e.key === 'X')) {
        e.preventDefault();
        e.stopPropagation();
        document.documentElement.classList.toggle('wa-privacy-off');
      }
    }, true);
  }
  return 'injected';
})()
"""

def cdp_eval(ws_url, expression):
    try:
        rest = ws_url.split("://", 1)[1]
        host_port, path = rest.split("/", 1)
        host, port = host_port.split(":")
        path = "/" + path
        s = socket.create_connection((host, int(port)), timeout=1.0)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host_port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        s.sendall(req.encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = s.recv(4096)
            if not chunk:
                break
            resp += chunk

        payload = json.dumps({
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {"expression": expression}
        }).encode("utf-8")
        mask = os.urandom(4)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        length = len(payload)
        if length < 126:
            header = bytes([0x81, 0x80 | length]) + mask
        elif length < 65536:
            header = bytes([0x81, 0x80 | 126, (length >> 8) & 0xFF, length & 0xFF]) + mask
        else:
            header = bytes([0x81, 0x80 | 127]) + length.to_bytes(8, "big") + mask
        s.sendall(header + masked)
        s.recv(4096)
        s.close()
    except Exception:
        pass

def ensure_whatsapp_blur():
    for port in (9222, 9223):
        try:
            raw = urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=0.8).read().decode()
            targets = json.loads(raw)
            for t in targets:
                if t.get("type") == "page" and "web.whatsapp.com" in t.get("url", ""):
                    ws_url = t.get("webSocketDebuggerUrl")
                    if ws_url:
                        cdp_eval(ws_url, WA_INJECT_JS)
        except Exception:
            pass

def cdp_eval_value(ws_url, expression):
    try:
        rest = ws_url.split("://", 1)[1]
        host_port, path = rest.split("/", 1)
        host, port = host_port.split(":")
        s = socket.create_connection((host, int(port)), timeout=1.2)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET /{path} HTTP/1.1\r\nHost: {host_port}\r\n"
            "Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        )
        s.sendall(req.encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = s.recv(4096)
            if not chunk:
                break
            resp += chunk
        payload = json.dumps({
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {"expression": expression, "returnByValue": True}
        }).encode("utf-8")
        mask = os.urandom(4)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        ln = len(payload)
        hdr = (bytes([0x81, 0x80 | ln]) if ln < 126 else bytes([0x81, 0x80 | 126, (ln >> 8) & 0xFF, ln & 0xFF])) + mask
        s.sendall(hdr + masked)
        s.settimeout(1.2)
        buf = b""
        while True:
            try:
                c = s.recv(65536)
                if not c:
                    break
                buf += c
                if b'"result"' in buf:
                    break
            except Exception:
                break
        s.close()
        idx = buf.find(b"{")
        if idx != -1:
            end_idx = buf.rfind(b"}")
            if end_idx != -1:
                obj = json.loads(buf[idx:end_idx + 1].decode("utf-8", errors="ignore"))
                return obj.get("result", {}).get("result", {}).get("value")
    except Exception:
        pass
    return None

def handle_smart_media_ducking(bus, mic_apps, call_active=False):
    global PAUSED_BY_DUCKING
    should_duck = bool(mic_apps or call_active)
    try:
        names = [str(n) for n in bus.list_names() if str(n).startswith("org.mpris.MediaPlayer2.")]
    except Exception:
        names = []

    if should_duck:
        for svc in names:
            try:
                obj = bus.get_object(svc, "/org/mpris/MediaPlayer2")
                props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
                status = str(props.Get("org.mpris.MediaPlayer2.Player", "PlaybackStatus"))
                if status == "Playing":
                    player = dbus.Interface(obj, "org.mpris.MediaPlayer2.Player")
                    player.Pause()
                    PAUSED_BY_DUCKING.add(svc)
            except Exception:
                pass
    elif PAUSED_BY_DUCKING:
        for svc in list(PAUSED_BY_DUCKING):
            if svc in names:
                try:
                    obj = bus.get_object(svc, "/org/mpris/MediaPlayer2")
                    props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
                    status = str(props.Get("org.mpris.MediaPlayer2.Player", "PlaybackStatus"))
                    if status == "Paused":
                        player = dbus.Interface(obj, "org.mpris.MediaPlayer2.Player")
                        player.Play()
                except Exception:
                    pass
        PAUSED_BY_DUCKING.clear()

def poll_gcal_meeting_links():
    global CACHED_GCAL_MEETING, LAST_GCAL_SCAN, ANNOUNCED_MEETING_IDS
    now = time.time()
    if now - LAST_GCAL_SCAN < 20:
        return CACHED_GCAL_MEETING
    LAST_GCAL_SCAN = now

    js = r"""
    (() => {
      const html = document.documentElement.innerHTML;
      const out = [];
      const re = /"https:\/\/www\.google\.com\/calendar\/event\?eid\\u003d([^"]+)"/g;
      let m;
      while ((m = re.exec(html)) !== null) {
        const chunk = html.slice(Math.max(0, m.index - 100), m.index + 2500);
        const titleMatch = chunk.match(/,\d+,\d+,"([^"]+)"/);
        const tsMatch = chunk.match(/\[null,\[(\d{13})\],"[^"]+"\],\[null,\[(\d{13})\],"[^"]+"\]/);
        const meetMatch = chunk.match(/https:\/\/meet\.google\.com\/[a-z]{3}-[a-z]{4}-[a-z]{3}/);
        if (titleMatch && meetMatch) {
          out.push({
            eid: m[1],
            title: titleMatch[1],
            startMs: tsMatch ? Number(tsMatch[1]) : 0,
            endMs: tsMatch ? Number(tsMatch[2]) : 0,
            meetUrl: meetMatch[0]
          });
        }
      }
      const chips = Array.from(document.querySelectorAll('[data-eventid]')).map(el => el.innerText.replace(/\n+/g, ' | ').trim()).filter(Boolean);
      return { events: out, chips: chips.slice(0, 10) };
    })()
    """
    for port in (9222, 9223):
        try:
            raw = urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=0.8).read().decode()
            targets = json.loads(raw)
            for t in targets:
                if t.get("type") == "page" and "calendar.google.com" in t.get("url", ""):
                    val = cdp_eval_value(t.get("webSocketDebuggerUrl", ""), js)
                    if isinstance(val, dict):
                        events = val.get("events", [])
                        chips = val.get("chips", [])
                        if events:
                            best = events[-1]
                            CACHED_GCAL_MEETING = {
                                "title": best.get("title", "Google Meet"),
                                "url": best.get("meetUrl", ""),
                                "chip": chips[-1] if chips else ""
                            }
                            # Check if any chip starts within 1-2 minutes
                            if CACHED_GCAL_MEETING["url"] and CACHED_GCAL_MEETING["url"] not in ANNOUNCED_MEETING_IDS:
                                ANNOUNCED_MEETING_IDS.add(CACHED_GCAL_MEETING["url"])
                                subprocess.Popen(
                                    [
                                        os.path.expanduser("~/.local/bin/island-push"),
                                        "--flash",
                                        "--title", f"Meet Ready: {CACHED_GCAL_MEETING['title']}",
                                        "--subtitle", CACHED_GCAL_MEETING["url"].replace("https://", ""),
                                        "--icon", "camera-video-symbolic",
                                        "--color", "green",
                                        "--duration", "4500"
                                    ],
                                    stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL
                                )
                            return CACHED_GCAL_MEETING
        except Exception:
            pass
    return CACHED_GCAL_MEETING

def poll_privacy_status():
    mic_apps = []
    cam_apps = []
    screen_apps = []

    try:
        out = subprocess.check_output(["pw-dump"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
        nodes = json.loads(out)
        for obj in nodes:
            info = obj.get("info", {})
            if not isinstance(info, dict) or info.get("state") != "running":
                continue
            props = info.get("props", {})
            if not isinstance(props, dict):
                continue
            mc = props.get("media.class", "")
            node_name = str(props.get("node.name", ""))
            app_name = props.get("application.name") or props.get("node.description") or node_name

            if node_name.startswith(("easyeffects", "output.easyeffects", "input.easyeffects")):
                continue

            if mc == "Stream/Input/Audio":
                if app_name and app_name not in mic_apps and "Peak detect" not in app_name:
                    mic_apps.append(app_name)
            elif mc in ("Stream/Input/Video", "Stream/Output/Video"):
                if any(k in node_name.lower() for k in ("kwin", "xdpw", "screen", "portal", "webrtc", "gsr")):
                    if app_name and app_name not in screen_apps:
                        screen_apps.append(app_name)
            elif mc == "Video/Source":
                if any(k in node_name.lower() for k in ("kwin", "screen", "portal")):
                    label = app_name if app_name and "kwin" not in app_name.lower() else "Screen Sharing"
                    if label not in screen_apps:
                        screen_apps.append(label)
                elif "v4l2" in node_name.lower():
                    if "Camera" not in cam_apps:
                        cam_apps.append(props.get("node.description") or "Camera")
    except Exception:
        pass

    for vdev in glob.glob("/dev/video*"):
        try:
            res = subprocess.run(["fuser", vdev], capture_output=True, text=True, timeout=0.5)
            pids = (res.stdout + " " + res.stderr).split()
            for p in pids:
                p_clean = "".join(ch for ch in p if ch.isdigit())
                if p_clean:
                    comm_path = f"/proc/{p_clean}/comm"
                    if os.path.exists(comm_path):
                        comm = open(comm_path).read().strip()
                        if comm not in ("pipewire", "wireplumber") and comm not in cam_apps:
                            cam_apps.append(comm)
        except Exception:
            pass

    status = {
        "mic": mic_apps,
        "cam": cam_apps,
        "screen": screen_apps,
        "active": bool(mic_apps or cam_apps or screen_apps)
    }
    try:
        tmp = STATUS_PATH + ".tmp"
        with open(tmp, "w") as f:
            json.dump(status, f)
        os.replace(tmp, STATUS_PATH)
    except Exception:
        pass
    return bool(screen_apps), mic_apps

def poll_ports_and_handoff(bus):
    global LAST_HANDOFF_CLIP, LAST_HANDOFF_URL
    ports = []
    seen_ports = set()
    try:
        out = subprocess.check_output(["ss", "-tlnp"], text=True, stderr=subprocess.DEVNULL, timeout=1.0)
        for line in out.splitlines()[1:]:
            parts = line.split()
            if len(parts) < 4:
                continue
            local_addr = parts[3]
            m_port = re.search(r":(\d+)$", local_addr)
            if not m_port:
                continue
            port = int(m_port.group(1))
            if port in IGNORE_PORTS or port in seen_ports or port < 1024:
                continue
            m_proc = re.search(r'\("([^"]+)",pid=(\d+)', line)
            if not m_proc:
                continue
            proc_name, pid_str = m_proc.group(1), m_proc.group(2)
            if proc_name in IGNORE_PROCS:
                continue
            # Skip ephemeral high ports (>32768) unless common dev runtime
            if port >= 32768 and proc_name not in ("node", "bun", "deno", "python", "python3", "uvicorn", "gunicorn", "vite", "next-server", "ruby", "go", "cargo", "php", "java"):
                continue
            cmdline = proc_name
            try:
                raw_cmd = open(f"/proc/{pid_str}/cmdline", "rb").read().replace(b"\x00", b" ").decode("utf-8", errors="ignore").strip()
                if raw_cmd:
                    short = " ".join(os.path.basename(tok) if tok.startswith("/") else tok for tok in raw_cmd.split()[:3])
                    cmdline = short[:42]
            except Exception:
                pass
            seen_ports.add(port)
            ports.append({
                "port": port,
                "pid": int(pid_str),
                "name": proc_name,
                "cmd": cmdline,
                "url": f"http://localhost:{port}"
            })
    except Exception:
        pass
    ports.sort(key=lambda x: x["port"])

    # Merge Handoff state written by macos-handoff-daemon.py
    handoff_state = {}
    handoff_state_path = f"/run/user/{os.getuid()}/macos-handoff-state.json"
    if os.path.exists(handoff_state_path):
        try:
            with open(handoff_state_path, "r") as hf:
                handoff_state = json.load(hf)
        except Exception:
            handoff_state = {}

    # Also detect URLs copied on desktop via Klipper
    clip_text = ""
    try:
        klipper = bus.get_object("org.kde.klipper", "/klipper")
        clip_iface = dbus.Interface(klipper, "org.kde.klipper.klipper")
        clip_text = str(clip_iface.getClipboardContents() or "").strip()
    except Exception:
        pass

    m_url = re.match(r"^(https?://[^\s<>\"']+)$", clip_text)
    if m_url:
        found_url = m_url.group(1)
        if found_url != LAST_HANDOFF_URL:
            LAST_HANDOFF_URL = found_url

    # Merge Granola Meeting Notes & Calendar state
    meeting_state = {}
    meeting_state_path = f"/run/user/{os.getuid()}/macos-meeting-state.json"
    if os.path.exists(meeting_state_path):
        try:
            with open(meeting_state_path, "r") as mf:
                meeting_state = json.load(mf)
        except Exception:
            meeting_state = {}

    # Battery Conservation (80% Charge Limit) & Bartender + Keycastr state
    battery_limit_on = False
    try:
        b_val = open("/sys/devices/platform/legion/battery_conservation").read().strip()
        battery_limit_on = (b_val == "1")
    except Exception:
        pass

    bartender_clean = True
    bt_file = os.path.expanduser("~/.config/macos-bartender-mode")
    if os.path.exists(bt_file):
        try:
            bartender_clean = (open(bt_file).read().strip() == "clean")
        except Exception:
            pass

    keycastr_on = False
    kc_pid_file = f"/run/user/{os.getuid()}/macos-keycastr.pid"
    if os.path.exists(kc_pid_file):
        try:
            os.kill(int(open(kc_pid_file).read().strip()), 0)
            keycastr_on = True
        except Exception:
            pass

    gcal_meet = poll_gcal_meeting_links()

    payload = {
        "ports": ports,
        "handoffConnected": bool(handoff_state.get("connected", False)),
        "handoffDevice": handoff_state.get("device", ""),
        "hfpConnected": bool(handoff_state.get("hfpConnected", False)),
        "audioRoute": handoff_state.get("audioRoute", "phone"),
        "mirrorRunning": bool(handoff_state.get("mirrorRunning", False)),
        "callState": handoff_state.get("callState", ""),
        "callNumber": handoff_state.get("callNumber", ""),
        "callName": handoff_state.get("callName", ""),
        "contactsCount": int(handoff_state.get("contactsCount", 0)),
        "contacts": handoff_state.get("contacts", []),
        "handoffUrl": handoff_state.get("handoffUrl") or LAST_HANDOFF_URL,
        "handoffPreview": handoff_state.get("handoffPreview") or (clip_text[:120] if clip_text else ""),
        "handoffImage": handoff_state.get("handoffImage", ""),
        "meetingRecording": bool(meeting_state.get("recording", False)),
        "meetingTitle": meeting_state.get("title", "Meeting Notes"),
        "meetingCalendarEvent": meeting_state.get("calendarEvent"),
        "meetingPreview": meeting_state.get("transcriptPreview", []),
        "meetingLastNote": meeting_state.get("lastNotePath", ""),
        "gcalMeet": gcal_meet,
        "batteryLimit80": battery_limit_on,
        "bartenderClean": bartender_clean,
        "keycastrRunning": keycastr_on
    }
    try:
        tmp = PORTS_PATH + ".tmp"
        with open(tmp, "w") as f:
            json.dump(payload, f)
        os.replace(tmp, PORTS_PATH)
    except Exception:
        pass

def set_desktop_icons_visible(visible):
    if not visible:
        # Only overwrite backup if desktop is currently showing real desktop:/ icons (not empty-desktop)
        js_read = """
        var out = {};
        var d = desktops();
        for (var i = 0; i < d.length; i++) {
            d[i].currentConfigGroup = ["General"];
            var u = d[i].readConfig("url");
            var pos = d[i].readConfig("positions");
            if ((!u || u === "desktop:/") && pos && pos.length > 25) {
                out[d[i].id] = pos;
            }
        }
        print(JSON.stringify(out));
        """
        try:
            res = subprocess.check_output(
                ["qdbus6", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", js_read],
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
            if res and res != "{}":
                with open(POS_BACKUP_PATH, "w") as f:
                    f.write(res)
        except Exception:
            pass

        js_hide = """
        var d = desktops();
        for (var i = 0; i < d.length; i++) {
            d[i].currentConfigGroup = ["General"];
            d[i].writeConfig("url", "file:///tmp/empty-desktop");
        }
        """
        subprocess.run(
            ["qdbus6", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", js_hide],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    else:
        # Restore desktop:/ URL and immediately restore backed-up icon positions
        saved = {}
        if os.path.exists(POS_BACKUP_PATH):
            try:
                with open(POS_BACKUP_PATH, "r") as f:
                    saved = json.load(f)
            except Exception:
                saved = {}
        saved_json = json.dumps(saved)
        js_restore = f"""
        var saved = {saved_json};
        var d = desktops();
        for (var i = 0; i < d.length; i++) {{
            d[i].currentConfigGroup = ["General"];
            d[i].writeConfig("url", "desktop:/");
            if (saved[d[i].id]) {{
                d[i].writeConfig("positions", saved[d[i].id]);
            }}
        }}
        """
        subprocess.run(
            ["qdbus6", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", js_restore],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

def main():
    bus = dbus.SessionBus()
    inhibit_cookie = None
    was_sharing = False
    share_streak = 0
    stop_streak = 0
    boot_healed = False

    while True:
        ensure_whatsapp_blur()
        raw_sharing, mic_apps = poll_privacy_status()
        poll_ports_and_handoff(bus)
        call_active = False
        try:
            hs_path = f"/run/user/{os.getuid()}/macos-handoff-state.json"
            if os.path.exists(hs_path):
                call_active = bool(json.load(open(hs_path)).get("callState", ""))
        except Exception:
            pass
        handle_smart_media_ducking(bus, mic_apps, call_active)

        if not boot_healed and not raw_sharing:
            set_desktop_icons_visible(True)
            boot_healed = True

        if raw_sharing:
            share_streak += 1
            stop_streak = 0
        else:
            stop_streak += 1
            share_streak = 0

        if share_streak >= 2 and not was_sharing:
            try:
                notif = bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
                iface = dbus.Interface(notif, "org.freedesktop.Notifications")
                inhibit_cookie = int(iface.Inhibit("macos-screenshare-privacy", "Screen Sharing Active", dbus.Dictionary({}, signature="sv")))
            except Exception:
                inhibit_cookie = None

            set_desktop_icons_visible(False)
            was_sharing = True

        elif stop_streak >= 3 and was_sharing:
            if inhibit_cookie is not None:
                try:
                    notif = bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
                    iface = dbus.Interface(notif, "org.freedesktop.Notifications")
                    iface.UnInhibit(dbus.UInt32(inhibit_cookie))
                except Exception:
                    pass
                inhibit_cookie = None

            set_desktop_icons_visible(True)
            was_sharing = False

        time.sleep(2.0)

if __name__ == "__main__":
    main()
