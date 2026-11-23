# Roadmap & Feature Requests

Here is what is already working and what we are looking at next. If you want one of these prioritized, or have another macOS feature in mind, [open an issue](../../issues/new?template=feature-request.yml).

## Shipped
- [x] Dynamic N-monitor Top Menu Bar & Bottom Floating Dock sync (`macos-multiscreen-sync.sh`)
- [x] Self-healing desktop icon recovery when monitors sleep/unplug (`macos-screen-watcher.sh`)
- [x] Uniform `0.82x` dock icon sizing (`org.macos.dockseparator`, `org.macos.downloads`, `org.macos.trash`, `AndromedaLauncher`)
- [x] Dock pointer-local magnification & launch bounce (`patches/dock/`)
- [x] Dock "Downloads Stack" Grid Popup (`plasmoids/org.macos.downloads/`)
- [x] Apple TV Aerial video wallpapers with 0-day download throttle patch + covered/battery auto-pause (`patch-aerial-core.py`, `patches/aerial-main.qml`)
- [x] macOS Sequoia / Tahoe Lock Screen & SDDM Login Screen with cached Aerial video playback
- [x] 16-Chiclet macOS Volume & Brightness OSD Pill (`shell-overrides/osd/`)
- [x] Frosted-glass macOS Logout / Restart / Shut Down sheet (`shell-overrides/logout/`)
- [x] Wayland `Alt+Space` Spotlight & `Win+V` Clipboard bridge to Vicinae (`krunner-dbus-bridge.py`)
- [x] `Win+W` Mission Control declarative KWin effect with MRU window sizing & Spaces (`kwin/macos-mission-control/`)
- [x] `Cmd+Tab` / `Alt+Tab` Large-Icon App Switcher HUD (`kwin/tabbox/macos-app-switcher/`)
- [x] Notification Center frosted glass cards (`patches/notification-center/`)
- [x] Finder Quick Look (`Meta+Y` + Dolphin context menu) (`bin/macos-quicklook`, `servicemenus/macos-quicklook.desktop`)
- [x] Live Text Anywhere — English + Hindi OCR & QR (`Meta+Shift+2`) (`bin/macos-live-text`)
- [x] Finder Right-Click "Quick Actions" & Tahoe Colored/Emoji Folders (`bin/macos-quick-action`, `bin/macos-folder-badge`, `servicemenus/`)
- [x] Real Force Quit Applications dialog (`Meta+Alt+Esc` & Apple Menu) (`bin/macos-force-quit`)
- [x] Per-Window Screen Capture Exclusion Mask / Stealth toggle (`Meta+Shift+H`) (`kwin/macos-stealth-window/`)
- [x] Google Meet Document PiP Always-on-Top KWin script (`chrome-pip-top`)
- [x] Menu Bar Privacy Dots (Orange Mic / Green Camera / Purple Screen Share) (`org.macos.privacydots`)
- [x] Auto Do-Not-Disturb & Presentation Mode (hide desktop icons) during screen shares (`macos-screenshare-privacy.py`)
- [x] Dynamic Island Shelf + AirDrop (`LocalSend` / `KDE Connect` Quick Drop) (`org.phobby.dynamicisland`)
- [x] WhatsApp Web Privacy Blur-until-hover with `Alt+X` toggle
- [x] Private Wi-Fi MAC randomization, `rtw89` power-save stability, and KDE Connect D-Bus livelock fix (`etc/`, `plasmoids/org.kde.kdeconnect/`)
- [x] Konsole Devanagari/Hindi shaping + `Noto Sans Devanagari` fallback (`konsole/macOS.profile`, `fontconfig/fonts.conf`)

## Up Next (Open for Requests / PRs)
- [ ] **macOS Screenshot Workflow (`Meta+Shift+3 / 4 / 5`):** Save `Screen Shot YYYY-MM-DD at HH.MM.SS.png` to `~/Desktop` + auto-copy to clipboard + camera shutter sound + floating corner thumbnail.
- [ ] **App-Level Window Shortcuts (`Meta+H`, `Meta+Alt+H`, `Meta+M`, `Meta+Q`):** Hide active app, Hide Others, Minimize, and Quit.
- [ ] **Top-Right Notification Banners & MagSafe Charging Chime:** Slide notifications in at top-right below the menu bar and trigger the MagSafe chime on AC plug-in.
- [ ] **Finder Keyboard Navigation in Dolphin & Emoji Picker (`Ctrl+Meta+Space`):** `Cmd+Backspace` move to Trash, `Cmd+Up` parent folder, `Cmd+Down` open selected item, and `ShowFullPath=true`.
- [ ] **macOS Hot Corners:** Bottom-Right for `ShowDesktop` and Bottom-Left for `LockScreen` with `150ms` edge delay.
- [ ] **App Exposé Gesture:** Per-app window spread alongside Mission Control.
