#!/usr/bin/env python3
# ponytail: watches PipeWire screen-sharing (debounced 2-tick start / 3-tick stop), snapshots & restores exact desktop icon positions, writes /run/user/UID/macos-privacy-status.json, and keeps WhatsApp Web Privacy Blur active
import base64
import glob
import json
import os
import socket
import subprocess
import time
import urllib.request
import dbus

EMPTY_DIR = "/tmp/empty-desktop"
os.makedirs(EMPTY_DIR, exist_ok=True)
STATUS_PATH = f"/run/user/{os.getuid()}/macos-privacy-status.json"
POS_BACKUP_PATH = os.path.expanduser("~/.config/macos-desktop-positions-backup.json")

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
    return bool(screen_apps)

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
        raw_sharing = poll_privacy_status()

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
