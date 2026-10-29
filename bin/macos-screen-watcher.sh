#!/usr/bin/env bash
# ponytail: self-healing multi-screen daemon — preserves user widgets, auto-recovers disabled-screen desktop icons, and syncs N monitors

wait_for_plasma() {
    for _ in $(seq 1 30); do
        if qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "print(screenCount);" >/dev/null 2>&1; then
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
    # Format: screenIdx,activityId,count,item1,item2,...
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

while true; do
    sleep 10
    heal_desktop_icons
    STATE=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        var n = screenCount;
        var p = panels().filter(function(x){ return x.screen >= 0 && x.screen < n; });
        var wps = desktops().map(function(d){ return d.wallpaperPlugin; }).join(",");
        var hasTop = 0, hasBot = 0;
        for (var i = 0; i < p.length; i++) {
            if (p[i].location === "top" && p[i].widgets().length >= 5) hasTop++;
            if (p[i].location === "bottom" && p[i].widgets().length >= 4) hasBot++;
        }
        print(n + ":" + hasTop + ":" + hasBot + ":" + wps);
    ' 2>/dev/null || true)

    if [ -n "$STATE" ]; then
        IFS=":" read -r SCREENS HASTOP HASBOT WPS <<< "$STATE"
        if [ "$HASTOP" -lt "$SCREENS" ] || [ "$HASBOT" -lt "$SCREENS" ] || echo "$WPS" | grep -qv "io.github.birkneralex.aerial"; then
            ~/.local/bin/macos-multiscreen-sync.sh
        fi
    fi
done
