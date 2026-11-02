#!/usr/bin/env bash
# ponytail: 100% dynamic DRM connector & panel reconciler — reads live connected DRM outputs (eDP-*, HDMI-A-*, DP-*), maps [ScreenConnectors] dynamically, ensures every connected screen has Top Menu Bar + Bottom Dock + Aerial Wallpaper, and refreshes PlasmaViews geometry

sync_screen_connectors() {
    python3 -I -c '
import glob, os, re, subprocess, sys

# 1. Discover live connected DRM outputs dynamically (internal eDP first as Screen 0, external HDMI/DP/etc. as Screen 1..N)
connected = []
for status_file in sorted(glob.glob("/sys/class/drm/card*-*/status")):
    try:
        if open(status_file).read().strip() == "connected":
            dirname = os.path.basename(os.path.dirname(status_file))
            conn_name = re.sub(r"^card\d+-", "", dirname)
            if conn_name not in connected:
                connected.append(conn_name)
    except Exception:
        pass

connected.sort(key=lambda c: (0 if c.startswith("eDP") else 1, c))
if not connected:
    sys.exit(1)

rc_path = os.path.expanduser("~/.config/plasmashellrc")
text = open(rc_path, "r", encoding="utf-8", errors="ignore").read() if os.path.exists(rc_path) else ""

m_sec = re.search(r"\[ScreenConnectors\]\n([^\[]*)", text)
current_map = {}
if m_sec:
    for line in m_sec.group(1).splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            current_map[k.strip()] = v.strip()

changed = False
for idx, conn in enumerate(connected):
    k = str(idx)
    if current_map.get(k) != conn:
        for old_k, old_v in list(current_map.items()):
            if old_v == conn and old_k != k:
                subprocess.run(["kwriteconfig6", "--file", rc_path, "--group", "ScreenConnectors", "--key", old_k, "--delete"])
        subprocess.run(["kwriteconfig6", "--file", rc_path, "--group", "ScreenConnectors", "--key", k, conn])
        changed = True

app_rc = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
if os.path.exists(app_rc):
    app_txt = open(app_rc, "r", encoding="utf-8", errors="ignore").read()
    if "url=file:///tmp/empty-desktop" in app_txt:
        open(app_rc, "w", encoding="utf-8").write(app_txt.replace("url=file:///tmp/empty-desktop", "url=desktop:/"))
        changed = True

sys.exit(0 if changed else 1)
'
}

STATE_FILE="/tmp/macos-multiscreen-topology.state"

get_live_topology() {
    python3 -I -c '
import glob, os, re
connected = []
for status_file in sorted(glob.glob("/sys/class/drm/card*-*/status")):
    try:
        if open(status_file).read().strip() == "connected":
            conn = re.sub(r"^card\d+-", "", os.path.basename(os.path.dirname(status_file)))
            if conn not in connected:
                connected.append(conn)
    except Exception:
        pass
connected.sort(key=lambda c: (0 if c.startswith("eDP") else 1, c))
print(",".join(connected))
'
}

reconcile_panels_and_views() {
    if ! busctl --user status org.kde.plasmashell >/dev/null 2>&1; then
        return 1
    fi
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var n = screenCount;
var allPanels = panels();
var topByScreen = {};
var bottomByScreen = {};
var homelessTop = [];
var homelessBot = [];

for (var i = 0; i < allPanels.length; i++) {
    var p = allPanels[i];
    if (p.location === "top") {
        if (p.screen >= 0 && p.screen < n && !topByScreen[p.screen]) {
            topByScreen[p.screen] = p;
        } else if (p.screen < 0 || p.screen >= n) {
            homelessTop.push(p);
        }
    } else if (p.location === "bottom") {
        if (p.screen >= 0 && p.screen < n && !bottomByScreen[p.screen]) {
            bottomByScreen[p.screen] = p;
        } else if (p.screen < 0 || p.screen >= n) {
            homelessBot.push(p);
        }
    }
}

for (var s = 0; s < n; s++) {
    var topP = topByScreen[s] || homelessTop.shift();
    if (topP) {
        if (topP.screen !== s) topP.screen = s;
        topP.location = "top";
        topP.floating = true;
        topP.floating = false;
        topP.hiding = "autohide";
        topP.hiding = "none";
        topP.lengthMode = "fill";
        topP.height = 28;
    }
    var botP = bottomByScreen[s] || homelessBot.shift();
    if (botP) {
        if (botP.screen !== s) botP.screen = s;
        botP.location = "bottom";
        botP.floating = true;
        botP.hiding = "dodgewindows";
        botP.lengthMode = "fit";
        botP.height = 62;
    }
}

var desk = desktops();
for (var d = 0; d < desk.length; d++) {
    desk[d].currentConfigGroup = ["General"];
    if (desk[d].readConfig("url") === "file:///tmp/empty-desktop") {
        desk[d].writeConfig("url", "desktop:/");
    }
    if (desk[d].wallpaperPlugin !== "io.github.birkneralex.aerial") {
        desk[d].wallpaperPlugin = "io.github.birkneralex.aerial";
    }
}
' >/dev/null 2>&1 || true
}

LIVE_TOPO=$(get_live_topology)
PREV_TOPO=$(cat "$STATE_FILE" 2>/dev/null || true)

if sync_screen_connectors; then
    echo "ScreenConnectors updated dynamically ($LIVE_TOPO); restarting plasmashell..."
    systemctl --user restart plasma-plasmashell.service
    sleep 4
    reconcile_panels_and_views
    echo "$LIVE_TOPO" > "$STATE_FILE"
elif [ "$LIVE_TOPO" != "$PREV_TOPO" ]; then
    sleep 2
    reconcile_panels_and_views
    echo "$LIVE_TOPO" > "$STATE_FILE"
fi
