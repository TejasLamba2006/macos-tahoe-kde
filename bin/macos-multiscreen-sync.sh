#!/usr/bin/env bash
# ponytail: DRM connector reconciler — updates persistent connector mapping only; Plasma/KWin own live panel geometry during hotplug

STATE_FILE="/tmp/macos-multiscreen-topology.state"
PENDING_FILE="/tmp/macos-drm-disconnect-pending"

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
    except OSError:
        pass
connected.sort(key=lambda c: (0 if c.startswith("eDP") else 1, c))
print(",".join(connected))
'
}

sync_screen_connectors() {
    local topology="$1"
    python3 -I - "$topology" <<'PY'
import os, re, subprocess, sys
connected = [c for c in sys.argv[1].split(",") if c]
if not connected:
    raise SystemExit(1)

rc_path = os.path.expanduser("~/.config/plasmashellrc")
text = open(rc_path, "r", encoding="utf-8", errors="ignore").read() if os.path.exists(rc_path) else ""
m_sec = re.search(r"\[ScreenConnectors\]\n([^\[]*)", text)
current = {}
if m_sec:
    for line in m_sec.group(1).splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            current[k.strip()] = v.strip()

changed = False
wanted = {str(i): conn for i, conn in enumerate(connected)}
for key, conn in wanted.items():
    if current.get(key) != conn:
        subprocess.run(["kwriteconfig6", "--file", rc_path, "--group", "ScreenConnectors", "--key", key, conn], check=True)
        changed = True
for key in current.keys() - wanted.keys():
    subprocess.run(["kwriteconfig6", "--file", rc_path, "--group", "ScreenConnectors", "--key", key, "--delete"], check=True)
    changed = True
raise SystemExit(0 if changed else 1)
PY
}

count_of() {
    if [ -z "$1" ]; then printf '0\n'; else printf '%s\n' "$1" | tr ',' '\n' | wc -l; fi
}

LIVE_TOPO=$(get_live_topology)
[ -z "$LIVE_TOPO" ] && exit 0
PREV_TOPO=$(cat "$STATE_FILE" 2>/dev/null || true)

# First run only records reality. Never mutate or restart Plasma from startup discovery.
if [ -z "$PREV_TOPO" ]; then
    printf '%s\n' "$LIVE_TOPO" > "$STATE_FILE"
    sync_screen_connectors "$LIVE_TOPO" >/dev/null 2>&1 || true
    exit 0
fi

[ "$LIVE_TOPO" = "$PREV_TOPO" ] && { rm -f "$PENDING_FILE"; exit 0; }

LIVE_N=$(count_of "$LIVE_TOPO")
PREV_N=$(count_of "$PREV_TOPO")

# Confirm every topology change twice. A DRM hotplug mutates containments asynchronously;
# calling PlasmaShell.evaluateScript in that window crashed KConfigGroup::readEntry(maxLength).
if [ ! -f "$PENDING_FILE" ] || [ "$(cat "$PENDING_FILE" 2>/dev/null)" != "$LIVE_TOPO" ]; then
    printf '%s\n' "$LIVE_TOPO" > "$PENDING_FILE"
    exit 0
fi
rm -f "$PENDING_FILE"

sync_screen_connectors "$LIVE_TOPO" >/dev/null 2>&1 || true
printf '%s\n' "$LIVE_TOPO" > "$STATE_FILE"

# Connector mapping is read at startup. Restart only after the topology stayed stable for two ticks,
# and never execute panel scripting while Plasma is processing the DRM event.
systemctl --user restart plasma-plasmashell.service
