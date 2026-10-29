#!/usr/bin/env python3
# ponytail: polls PipeWire + /dev/video* and outputs JSON of active Mic, Camera, and Screen Recording apps
import glob
import json
import os
import subprocess

mic_apps = []
cam_apps = []
screen_apps = []

try:
    out = subprocess.check_output(["pw-dump"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
    nodes = json.loads(out)
    for obj in nodes:
        info = obj.get("info", {})
        if not isinstance(info, dict):
            continue
        state = info.get("state")
        props = info.get("props", {})
        if not isinstance(props, dict):
            continue
        mc = props.get("media.class", "")
        node_name = str(props.get("node.name", ""))
        app_name = props.get("application.name") or props.get("node.description") or node_name

        # Ignore internal EasyEffects filter nodes
        if node_name.startswith("easyeffects") or node_name.startswith("output.easyeffects") or node_name.startswith("input.easyeffects"):
            continue

        if mc == "Stream/Input/Audio" and state == "running":
            if app_name and app_name not in mic_apps and "Peak detect" not in app_name:
                mic_apps.append(app_name)
        elif mc == "Stream/Input/Video" and state == "running":
            if "kwin" in node_name.lower() or "xdpw" in node_name.lower() or "screen" in node_name.lower():
                if app_name and app_name not in screen_apps:
                    screen_apps.append(app_name)
        elif mc == "Video/Source" and state == "running":
            if "kwin" in node_name.lower() or "screen" in node_name.lower() or "portal" in node_name.lower():
                label = app_name if app_name and "kwin" not in app_name.lower() else "Screen Sharing"
                if label not in screen_apps:
                    screen_apps.append(label)
            elif "v4l2" in node_name.lower():
                if "Camera" not in cam_apps:
                    cam_apps.append(props.get("node.description") or "Camera")
except Exception:
    pass

# Also check direct V4L2 /dev/video* file descriptors (e.g. Chrome/Firefox WebRTC opening /dev/video0 directly)
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

print(json.dumps({
    "mic": mic_apps,
    "cam": cam_apps,
    "screen": screen_apps,
    "active": bool(mic_apps or cam_apps or screen_apps)
}))
