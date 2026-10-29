# Roadmap & Feature Requests

Here is what is already working and what we are looking at next. If you want one of these prioritized, or have another macOS feature in mind, [open an issue](../../issues/new?template=feature-request.yml).

## Shipped
- [x] Dynamic N-monitor Top Menu Bar & Bottom Floating Dock sync (`macos-multiscreen-sync.sh`)
- [x] Self-healing desktop icon recovery when monitors sleep/unplug (`macos-screen-watcher.sh`)
- [x] Uniform `0.82x` dock icon sizing (`org.macos.dockseparator`, `org.macos.downloads`, `org.macos.trash`, `AndromedaLauncher`)
- [x] Apple TV Aerial video wallpapers with 0-day download throttle binary patch (`patch-aerial-core.py`)
- [x] macOS Sequoia / Tahoe Lock Screen & SDDM Login Screen with cached Aerial video playback
- [x] 16-Chiclet macOS Volume & Brightness OSD Pill (`shell-overrides/osd/`)
- [x] Frosted-glass macOS Logout / Restart / Shut Down sheet (`shell-overrides/logout/`)
- [x] Wayland `Win+Space` Spotlight & `Win+V` Clipboard bridge to Vicinae (`krunner-dbus-bridge.py`)
- [x] Google Meet Document PiP Always-on-Top KWin script (`chrome-pip-top`)
- [x] Menu Bar Privacy Dots (Orange Mic / Green Camera / Purple Screen Share) (`org.macos.privacydots`)
- [x] Auto Do-Not-Disturb & Presentation Mode (hide desktop icons) during screen shares (`macos-screenshare-privacy.py`)
- [x] WhatsApp Web Privacy Blur-until-hover with `Alt+X` toggle
- [x] Private Wi-Fi MAC randomization & Encrypted DNS-over-TLS (`etc/`)

## Up Next (Open for Requests / PRs)
- [ ] **Quick Look (`Spacebar` Preview in Dolphin):** Instant file/image/PDF/code preview window when pressing `Space` in Dolphin, matching Finder's Quick Look.
- [ ] **macOS Screenshot HUD (`Meta+Shift+3 / 4 / 5`):** Floating thumbnail in the bottom-right corner after taking a screenshot that can be dragged directly into apps or clicked to mark up.
- [ ] **Stage Manager / App Exposé Gesture:** 3-finger / 4-finger trackpad swipe gestures mapped to KWin Overview and per-app window spread.
- [ ] **AirDrop Equivalent in Menu Bar (`LocalSend` / `KDE Connect` Quick Drop):** Drag-and-drop file tray target in the top bar or Dynamic Island.
- [ ] **Per-Window Screen Capture Exclusion Mask:** Hiding specific floating notes or password managers from KWin's PipeWire screencast stream while keeping them visible on your physical monitor.
