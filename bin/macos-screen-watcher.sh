#!/usr/bin/env bash
# ponytail: self-healing multi-screen daemon — verifies plasma-org.kde.plasma.desktop-appletsrc has lastScreen=0..N-1 panels without calling evaluateScript in a loop

wait_for_plasma() {
    for _ in $(seq 1 30); do
        if busctl --user status org.kde.plasmashell >/dev/null 2>&1; then
            sleep 2
            return 0
        fi
        sleep 1
    done
    return 1
}

heal_desktop_icons() {
    local rc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    local disabled
    disabled=$(kreadconfig6 --file "$rc" --group ScreenMapping --key itemsOnDisabledScreens 2>/dev/null || true)
    if [ -n "$disabled" ]; then
        python3 -I -c '
import os, re, subprocess
rc = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
with open(rc, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

m_dis = re.search(r"^itemsOnDisabledScreens=(.+)$", text, re.M)
m_map = re.search(r"^screenMapping=(.*)$", text, re.M)
if m_dis and m_dis.group(1).strip():
    parts = [p.strip() for p in m_dis.group(1).strip().split(",") if p.strip()]
    if len(parts) >= 4:
        scr, act = parts[0], parts[1]
        items = [p for p in parts[3:] if p.startswith("desktop:/")]
        existing = m_map.group(1).strip() if m_map else ""
        new_entries = ",".join(f"{it},0,{act}" for it in items if it not in existing)
        merged = (existing + "," + new_entries).strip(",") if existing else new_entries
        subprocess.run(["kwriteconfig6", "--file", rc, "--group", "ScreenMapping", "--key", "itemsOnDisabledScreens", ""])
        subprocess.run(["kwriteconfig6", "--file", rc, "--group", "ScreenMapping", "--key", "screenMapping", merged])
'
    fi
}

needs_panel_sync() {
    python3 -I -c '
import os, re, subprocess, sys
out = subprocess.check_output(["kscreen-doctor", "-o"], text=True, stderr=subprocess.DEVNULL)
out = re.sub(r"\x1b\[[0-9;]*m", "", out)
screens = out.count("enabled")
if screens < 1:
    sys.exit(1)

rc = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
if not os.path.exists(rc):
    sys.exit(0)

text = open(rc, errors="ignore").read()
# Count top (location=3) and bottom (location=4) panels per screen
tops = set()
bots = set()
for block in re.split(r"\n(?=\[Containments\]\[\d+\]\n)", text):
    if "formfactor=2" in block:
        m_scr = re.search(r"^lastScreen=(\d+)", block, re.M)
        m_loc = re.search(r"^location=(\d+)", block, re.M)
        if m_scr and m_loc:
            s = int(m_scr.group(1))
            loc = int(m_loc.group(1))
            if loc == 3:
                tops.add(s)
            elif loc == 4:
                bots.add(s)

for s in range(screens):
    if s not in tops or s not in bots:
        sys.exit(0)
sys.exit(1)
'
}

wait_for_plasma && {
    heal_desktop_icons
    ~/.local/bin/macos-multiscreen-sync.sh
}

while true; do
    sleep 10
    if ! busctl --user status org.kde.plasmashell >/dev/null 2>&1; then
        systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
        systemctl --user start plasma-plasmashell.service 2>/dev/null || true
        sleep 4
        heal_desktop_icons
        ~/.local/bin/macos-multiscreen-sync.sh
        continue
    fi

    heal_desktop_icons
    if needs_panel_sync; then
        ~/.local/bin/macos-multiscreen-sync.sh
    fi
done
