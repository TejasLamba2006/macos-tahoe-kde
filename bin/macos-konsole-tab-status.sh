#!/usr/bin/env bash
# ponytail: updates Konsole tab icon/title + color (⏳ working, ✅ done, 🔔 permission needed) via KONSOLE_DBUS_SERVICE
state="${1:-done}"
[[ -z "${KONSOLE_DBUS_SERVICE:-}" || -z "${KONSOLE_DBUS_SESSION:-}" ]] && exit 0

case "$state" in
    working)
        qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.setTabTitleFormat 0 "⏳ %d : %n" >/dev/null 2>&1 || true
        qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.setTabColor "#0A84FF" >/dev/null 2>&1 || true
        ;;
    done)
        qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.setTabTitleFormat 0 "✅ %d : %n" >/dev/null 2>&1 || true
        qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.setTabColor "#30D158" >/dev/null 2>&1 || true
        ;;
    blocked)
        qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.setTabTitleFormat 0 "🔔 %d : %n" >/dev/null 2>&1 || true
        qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.setTabColor "#FF9F0A" >/dev/null 2>&1 || true
        ;;
esac
