# 04. Privacy Indicators & Screen-Sharing Protection

## 1. Menu Bar Privacy Dots (`plasmoids/org.macos.privacydots`)

macOS shows an orange dot when the microphone is active, green when the camera is on, and purple when screen recording.

`bin/macos-privacy-status.py` inspects two sources every 2 seconds:
1. `pw-dump` for active (`state == "running"`) PipeWire streams (`Stream/Input/Audio`, `Stream/Input/Video`, `Video/Source`), ignoring internal virtual filters like `easyeffects`.
2. Direct V4L2 device handles (`fuser /dev/video*`) to catch browsers or apps reading `/dev/video0` directly.

When idle, `org.macos.privacydots` sets `Plasmoid.status = PlasmaCore.Types.HiddenStatus` and `Layout.preferredWidth = 0`. When any capture starts, it renders the colored dots in the top bar and lists the capturing apps on click.

## 2. Screen-Sharing Privacy Daemon (`bin/macos-screenshare-privacy.py`)

Running via `systemd/macos-screenshare-privacy.service`, this daemon watches for active PipeWire screen-cast streams (`kwin`, `xdpw`, `portal`) and performs three actions:

1. **Auto "Do Not Disturb":** Calls `org.freedesktop.Notifications.Inhibit("macos-screenshare-privacy", "Screen Sharing Active", {})`. While you are sharing your screen on Google Meet, Zoom, or Discord, zero notification popups can appear on screen. When the stream stops, it calls `UnInhibit(cookie)`.
2. **Auto "Presentation Mode" (Hide Desktop Icons):** Switches the Desktop containment `url` to `/tmp/empty-desktop` during screen shares so your `~/Desktop` launchers and files disappear cleanly without losing their saved icon positions, restoring `desktop:/` as soon as you stop sharing.
3. **WhatsApp Web Privacy Blur (`chrome-ext/` + CDP auto-reinject):** Blurs all chat list rows (`#pane-side`), messages (`#main`), and contact headers until you hover your mouse over a specific item. Press **`Alt+X`** anytime inside WhatsApp Web to toggle the blur off or back on.
