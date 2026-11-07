#!/usr/bin/env bash
# ponytail: dynamic self-healing multi-screen watcher — reconciles live DRM connector names and heals desktop icons without racing Plasma's hotplug handling

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
        act = parts[1]
        items = [p for p in parts[3:] if p.startswith("desktop:/")]
        existing = m_map.group(1).strip() if m_map else ""
        new_entries = ",".join(f"{it},0,{act}" for it in items if it not in existing)
        merged = (existing + "," + new_entries).strip(",") if existing else new_entries
        subprocess.run(["kwriteconfig6", "--file", rc, "--group", "ScreenMapping", "--key", "itemsOnDisabledScreens", ""])
        subprocess.run(["kwriteconfig6", "--file", rc, "--group", "ScreenMapping", "--key", "screenMapping", merged])
'
    fi
}

# Preserve last known topology across service restarts. Deleting it turns startup into a false hotplug.
wait_for_plasma && {
    heal_desktop_icons
    ~/.local/bin/macos-multiscreen-sync.sh
}

while true; do
    sleep 4
    if ! busctl --user status org.kde.plasmashell >/dev/null 2>&1; then
        systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
        systemctl --user start plasma-plasmashell.service 2>/dev/null || true
        wait_for_plasma || continue
        heal_desktop_icons
        ~/.local/bin/macos-multiscreen-sync.sh
        continue
    fi

    heal_desktop_icons
    ~/.local/bin/macos-multiscreen-sync.sh
done
