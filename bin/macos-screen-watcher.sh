#!/usr/bin/env bash
# ponytail: event-driven multi-screen daemon — never polls evaluateScript in a loop; adds Restart=always drop-in to plasma-plasmashell

wait_for_plasma() {
    for _ in $(seq 1 30); do
        if busctl --user status org.kde.plasmashell >/dev/null 2>&1; then
            sleep 1
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

wait_for_plasma && {
    heal_desktop_icons
    ~/.local/bin/macos-multiscreen-sync.sh
}

LAST_OUTPUTS=""
while true; do
    sleep 15
    if ! busctl --user status org.kde.plasmashell >/dev/null 2>&1; then
        systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
        systemctl --user start plasma-plasmashell.service 2>/dev/null || true
        sleep 4
        heal_desktop_icons
        ~/.local/bin/macos-multiscreen-sync.sh
        continue
    fi

    heal_desktop_icons
    CUR_OUTPUTS=$(kscreen-doctor -o 2>/dev/null | grep -E "Output:" | sort | tr '\n' '|' || true)
    if [ -n "$CUR_OUTPUTS" ] && [ "$CUR_OUTPUTS" != "$LAST_OUTPUTS" ]; then
        LAST_OUTPUTS="$CUR_OUTPUTS"
        ~/.local/bin/macos-multiscreen-sync.sh
    fi
done
