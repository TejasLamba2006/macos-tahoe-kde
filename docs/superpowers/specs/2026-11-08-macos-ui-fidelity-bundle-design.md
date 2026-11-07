# macOS UI Fidelity Bundle Design

**Date:** 2026-11-08
**Repository:** `macos-tahoe-kde`

## Goal

Improve visible macOS fidelity across launcher, Control Center, Notification Center, Dock, and Dolphin without destabilizing Plasma's monitor or panel lifecycle.

## Scope

### 1. Alt+Space → Vicinae Applications

- Bind `Alt+Space` directly to `vicinae toggle` through KGlobalAccel.
- Retain `plasma-krunner.service` and `krunner-dbus-bridge.py` for callers that invoke `org.kde.krunner` over D-Bus.
- Remove only conflicting KRunner/Vicinae shortcuts.
- Verify cold start, already-running toggle, and repeated open/close.

### 2. macOS Control Center

Modify existing `KdeControlStation`; do not create another top-bar plasmoid.

Layout:
- Rounded dark-glass card with macOS spacing and SF typography.
- Connectivity tile: Wi-Fi, Bluetooth, AirDrop/KDE Connect state.
- Independent tiles: Focus, Dark Mode, Stage Manager, Screen Mirroring.
- Full-width brightness and volume sliders.
- Now Playing footer with artwork and playback controls.

Behavior:
- Reuse current NetworkManager, BlueZ, PowerDevil, MPRIS, KWin, and KDE Connect backends.
- Expanded secondary pages remain available behind each tile.
- Undefined backend values render safe disabled states rather than QML errors.

### 3. macOS Notification Center

Restyle Plasma's existing notification history instead of replacing notification transport.

Layout:
- Right-aligned floating glass sheet.
- App-grouped notifications with icon, timestamp, expand/collapse, group clear, and clear-all.
- Compact widget stack beneath history: Calendar/agenda, weather, and device battery.

Behavior:
- Preserve Plasma notification history, DND, actions, inline replies, and job progress.
- Notification storage remains native; visual layer only changes presentation.
- Empty state follows macOS spacing and typography.

### 4. Dock Fidelity

Improve existing bottom panel and `org.kde.plasma.icontasks`.

Features:
- Pointer-local magnification affecting nearby icons with smooth falloff.
- Bounce animation for launch and attention.
- macOS-style running indicators.
- Recent-app divider and folder-stack presentation.
- Preserve launcher identity matching, icon stacking, Dodge Windows, and multi-monitor duplication.

Excluded:
- No new Genie compositor effect. Existing KWin Magic Lamp stays because custom minimize effects add compositor crash risk.

### 5. Finder-style Dolphin

Prefer Dolphin configuration, KXMLGUI, service menus, and theme overrides over forking Dolphin.

Changes:
- Compact unified toolbar and macOS sidebar spacing.
- Sidebar groups for Favorites, Locations, Cloud, Handoff/AirDrop, Windows SSD, and Network.
- Column View preset where supported; Details View remains available.
- Spacebar Quick Look using a lightweight preview window backed by KDE thumbnailers and existing media/PDF handlers.
- Bottom path/status treatment matching Finder.

Quick Look supports images, PDFs, video, audio, text, Markdown, and source files. Unsupported formats show file metadata and Open button.

## Architecture and Isolation

Each module is independently installable and revertible:

1. `vicinae-shortcut` — shortcut and D-Bus bridge configuration.
2. `control-center` — `KdeControlStation` QML only.
3. `notification-center` — notification applet QML resource override.
4. `dock-fidelity` — icon-task QML plus existing panel config.
5. `finder-dolphin` — Dolphin config/KXMLGUI plus Quick Look helper.

No module may mutate panel geometry during DRM hotplug. Automatic services must not call `org.kde.PlasmaShell.evaluateScript`.

## Data Flow

- Control Center reads existing KDE backends and invokes their existing actions.
- Notification Center reads Plasma's native notification model and calendar/weather/battery backends.
- Dock reads task model/window state and computes visual scale only; launcher data remains Plasma-owned.
- Dolphin Quick Look receives one selected URL, resolves MIME type, chooses an existing preview backend, and opens one transient preview window.
- Vicinae shortcut calls `vicinae toggle`; D-Bus bridge remains a fallback interface.

## Error Handling

- QML backend properties use explicit null/undefined guards.
- Optional backends hide or disable their tile instead of failing component load.
- Resource overrides retain original files in repository and install backups before replacement.
- Quick Look times out thumbnail generation and falls back to metadata.
- Shortcut installation detects and reports conflicting bindings before replacing only relevant entries.

## Verification

For each module:

1. QML syntax/load check where applicable.
2. Runtime journal check for new `TypeError`, `ReferenceError`, binding-loop, or unavailable-component messages.
3. Visual screenshot on both monitors.
4. Confirm `plasmashell` PID remains stable unless an intentional one-time restart occurred.
5. Confirm panel topology remains `eDP-1,HDMI-A-5` and no automatic `evaluateScript` caller exists.
6. Commit module separately for isolated rollback.

Module-specific checks:
- Vicinae: `Alt+Space` toggles from stopped and running states.
- Control Center: every tile and slider invokes correct backend.
- Notification Center: grouped actions, DND, clear, reply, and jobs work.
- Dock: magnification, stacking, attention, and two-monitor behavior work.
- Dolphin: Quick Look opens/closes with Space and handles all supported MIME groups.

## Implementation Order

1. Vicinae shortcut
2. Control Center
3. Notification Center
4. Dock fidelity
5. Finder-style Dolphin and Quick Look

Each step reaches a working checkpoint before the next begins.
