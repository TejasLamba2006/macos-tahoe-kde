# 03. Spotlight (`Vicinae`) on Wayland & KWin Window Rules

![Spotlight Vicinae](https://raw.githubusercontent.com/TejasLamba2006/macos-tahoe-arch/main/assets/screenshots/05-spotlight-vicinae.png)

## 1. Why `Win+Space` Opens KRunner Instead of Your Launcher on Wayland

On KDE Plasma 6 Wayland, `kwin_wayland` manages global shortcuts through `kglobalaccel` and activates `org.kde.krunner` via D-Bus activation (`org.freedesktop.Application.Activate` or `org.kde.krunner.App.display`).

If you just uninstall or kill `krunner`, pressing `Alt+Space` or `Win+Space` throws:
```
Method "Activate" with signature "a{sv}" on interface "org.freedesktop.Application" doesn't exist
```

### The Fix (`bin/krunner-dbus-bridge.py`)
We claim `org.kde.krunner` on the session D-Bus and implement both `org.kde.krunner.App` (`display`, `query`, `toggleDisplay`, `displayWithClipboardContents`, `Teardown`) and `org.freedesktop.Application` (`Activate`, `Open`, `ActivateAction`):
- `Win+Space` / `Alt+Space` -> `vicinae toggle`
- `Win+V` (`RunClipboard`) -> `vicinae cmd launch clipboard:history`

## 2. Keeping Google Meet's Floating Overlay on Top (`kwin/chrome-pip-top/`)

When you switch tabs away from an active Google Meet call in Chrome, Chrome opens a **Document Picture-in-Picture** window. On Wayland (`--ozone-platform=wayland`):
1. Wayland's `xdg-shell` protocol does not allow regular clients to set `keepAbove` on their own windows.
2. Unlike standard video PiP (which is titled `"Picture-in-Picture"`), Chrome names Document PiP windows after the page title (`"Meet - <Meeting Name>"`) without the `" - Google Chrome"` suffix.
3. If you write a static KWin Window Rule matching Chrome windows whose title doesn't end in `" - Google Chrome"`, it accidentally matches **every brand-new main Chrome window** at creation time (when its title is still `""`) and locks `keepAbove=true` on your main browser too, so clicking the main browser covers the Meet overlay.

`kwin/chrome-pip-top/contents/code/main.js` solves this by listening to `windowAdded`, `captionChanged`, and `frameGeometryChanged` in KWin:
- If a Chrome window lacks `" - Google Chrome"` **and** is `<= 900x900`, it sets `keepAbove = true`, `skipTaskbar = true`, `skipSwitcher = true`.
- If a Chrome window gains `" - Google Chrome"` or resizes above `900px`, it immediately resets `keepAbove = false`.
