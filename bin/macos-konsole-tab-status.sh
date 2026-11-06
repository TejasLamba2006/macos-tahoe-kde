#!/usr/bin/env bash
# ponytail: updates Konsole tab icon/title + color (⏳ yellow working, ✅ green done, 🔔 blue waiting)
state="${1:-done}"
svc="${KONSOLE_DBUS_SERVICE:-}"
sess="${KONSOLE_DBUS_SESSION:-}"

# Fallback: discover Konsole D-Bus service & session from process tree if env vars missing
if [[ -z "$svc" || -z "$sess" ]]; then
    read -r svc sess < <(python3 -I -c '
import os
pid = os.getpid()
while pid > 1:
    try:
        env = open(f"/proc/{pid}/environ", "rb").read().split(b"\x00")
        d = {}
        for item in env:
            if b"=" in item:
                k, v = item.split(b"=", 1)
                if k in (b"KONSOLE_DBUS_SERVICE", b"KONSOLE_DBUS_SESSION"):
                    d[k.decode()] = v.decode()
        if "KONSOLE_DBUS_SERVICE" in d and "KONSOLE_DBUS_SESSION" in d:
            print(d["KONSOLE_DBUS_SERVICE"], d["KONSOLE_DBUS_SESSION"])
            break
        stat = open(f"/proc/{pid}/stat").read()
        ppid = int(stat.split(")")[1].split()[1])
        if ppid == pid:
            break
        pid = ppid
    except Exception:
        break
' 2>/dev/null)
fi

[[ -z "$svc" || -z "$sess" ]] && exit 0

case "$state" in
    working|loading)
        qdbus6 "$svc" "$sess" org.kde.konsole.Session.setTabTitleFormat 0 "⏳ %d : %n" >/dev/null 2>&1 || true
        qdbus6 "$svc" "$sess" org.kde.konsole.Session.setTabColor "#FFD60A" >/dev/null 2>&1 || true
        ;;
    done)
        qdbus6 "$svc" "$sess" org.kde.konsole.Session.setTabTitleFormat 0 "✅ %d : %n" >/dev/null 2>&1 || true
        qdbus6 "$svc" "$sess" org.kde.konsole.Session.setTabColor "#30D158" >/dev/null 2>&1 || true
        ;;
    blocked|waiting)
        qdbus6 "$svc" "$sess" org.kde.konsole.Session.setTabTitleFormat 0 "🔔 %d : %n" >/dev/null 2>&1 || true
        qdbus6 "$svc" "$sess" org.kde.konsole.Session.setTabColor "#0A84FF" >/dev/null 2>&1 || true
        ;;
esac
