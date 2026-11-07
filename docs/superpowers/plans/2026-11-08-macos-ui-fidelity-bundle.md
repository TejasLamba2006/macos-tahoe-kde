# macOS UI Fidelity Bundle Implementation Plans

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement these plans task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Alt+Space reliably open Vicinae, then deliver independently revertible macOS-style Control Center, Notification Center, Dock, and Finder/Quick Look improvements.

**Architecture:** Five standalone modules share no mutable runtime state. Existing KDE backends/models remain authoritative; changes stay in QML presentation, explicit shortcuts, Dolphin configuration, and one MIME-driven Quick Look helper. Each module gets its own runtime verification and commit.

**Tech Stack:** KDE Plasma 6.8/QML 6, KGlobalAccel D-Bus, Vicinae CLI, KdeControlStation QML, Plasma notification/taskmanager QML resources, Python 3/PyQt6, Dolphin/KXMLGUI/KIO.

## Global Constraints

- Never call `org.kde.PlasmaShell.evaluateScript` from automatic services or hotplug paths.
- Restart Plasma only with `systemctl --user restart plasma-plasmashell.service`; never use `plasmashell --replace`.
- Preserve native KDE backends, notification history/actions, launcher identity matching, Dock stacking, and multi-monitor behavior.
- Keep all public-repository paths sanitized with `@HOME@`, `@USER@`, or `%h`.
- No Genie compositor implementation; retain KWin Magic Lamp.
- Save each subsystem in a separate commit so it can be reverted independently.
- After every Plasma/QML change, verify no new `TypeError`, `ReferenceError`, binding-loop, or unavailable-component messages.

---

# Plan 1: Alt+Space Vicinae Launcher

## File Structure

- Modify `bin/krunner-dbus-bridge.py`: D-Bus fallback that starts/toggles Vicinae.
- Create `applications/vicinae-applications.desktop`: direct KGlobalAccel launcher action.
- Modify `install.sh`: install desktop entry, register shortcut, preserve clipboard action.
- Create `tests/test_vicinae_bridge.py`: static and subprocess-level assertions.

### Task 1: Make Vicinae invocation self-healing

**Files:**
- Modify: `bin/krunner-dbus-bridge.py`
- Test: `tests/test_vicinae_bridge.py`

**Interfaces:**
- Produces: `launch(command: str = "applications") -> None`, called by D-Bus methods.
- Consumes: `/usr/bin/vicinae`, user service `vicinae.service`.

- [ ] **Step 1: Write failing tests**

```python
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "bin/krunner-dbus-bridge.py"


def test_bridge_uses_vicinae_toggle_and_service_fallback():
    text = SCRIPT.read_text()
    assert '["/usr/bin/vicinae", "toggle"]' in text
    assert "systemctl" in text
    assert "--user" in text
    assert "start" in text
    assert "vicinae.service" in text


def test_all_dbus_launcher_methods_route_through_launch():
    text = SCRIPT.read_text()
    for method in ("display", "query", "toggleDisplay", "Activate", "Open"):
        block = text.split(f"def {method}", 1)[1].split("\n    @", 1)[0]
        assert "launch()" in block
```

- [ ] **Step 2: Run tests and verify failure**

Run:
```bash
python -m pytest tests/test_vicinae_bridge.py -v
```
Expected: FAIL because service fallback and `launch()` do not exist.

- [ ] **Step 3: Implement minimal self-healing launcher**

Replace `toggle()` with:

```python
def launch():
    try:
        subprocess.run(
            ["systemctl", "--user", "start", "vicinae.service"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass
    subprocess.Popen(
        ["/usr/bin/vicinae", "toggle"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
```

Route `display`, `query`, `toggleDisplay`, `Activate`, `Open`, and non-clipboard `ActivateAction` through `launch()`.

- [ ] **Step 4: Run tests**

Run:
```bash
python -m pytest tests/test_vicinae_bridge.py -v
python -m py_compile bin/krunner-dbus-bridge.py
```
Expected: all tests PASS; compile exits 0.

- [ ] **Step 5: Commit**

```bash
git add bin/krunner-dbus-bridge.py tests/test_vicinae_bridge.py
git commit -m "fix(vicinae): make launcher bridge self-healing"
```

### Task 2: Register direct Alt+Space applications action

**Files:**
- Create: `applications/vicinae-applications.desktop`
- Modify: `install.sh`
- Test: `tests/test_vicinae_shortcut.py`

**Interfaces:**
- Produces KGlobalAccel action ID: `vicinae-applications.desktop,_launch`.
- Shortcut: `Alt+Space`.

- [ ] **Step 1: Write failing static test**

```python
from pathlib import Path

ROOT = Path(__file__).parents[1]


def test_vicinae_desktop_action():
    text = (ROOT / "applications/vicinae-applications.desktop").read_text()
    assert "Exec=/usr/bin/vicinae toggle" in text
    assert "X-KDE-GlobalAccel-CommandShortcut=true" in text


def test_installer_registers_alt_space():
    text = (ROOT / "install.sh").read_text()
    assert "vicinae-applications.desktop" in text
    assert "Alt+Space" in text
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
python -m pytest tests/test_vicinae_shortcut.py -v
```
Expected: FAIL because desktop entry does not exist.

- [ ] **Step 3: Add desktop entry**

```ini
[Desktop Entry]
Type=Application
Name=Vicinae Applications
Comment=Open the Vicinae application launcher
Exec=/usr/bin/vicinae toggle
Icon=system-search-symbolic
Terminal=false
Categories=Utility;
X-KDE-GlobalAccel-CommandShortcut=true
```

Add installer steps:

```bash
install -Dm755 applications/vicinae-applications.desktop \
  "$HOME/.local/share/applications/vicinae-applications.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
kbuildsycoca6 2>/dev/null || true
kwriteconfig6 --file kglobalshortcutsrc \
  --group vicinae-applications.desktop \
  --key _launch 'Alt+Space,Alt+Space,Vicinae Applications'
qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reconfigure 2>/dev/null || true
```

Clear only `Alt+Space` from KRunner `_launch`; preserve its other shortcuts and `RunClipboard`.

- [ ] **Step 4: Run static and live verification**

```bash
python -m pytest tests/test_vicinae_shortcut.py -v
systemctl --user stop vicinae.service
qdbus6 org.kde.kglobalaccel /component/vicinae_applications_desktop \
  org.kde.kglobalaccel.Component.invokeShortcut _launch
sleep 1
systemctl --user is-active vicinae.service
```
Expected: tests PASS and service prints `active`.

Then press `Alt+Space` twice: first opens Applications view; second closes it.

- [ ] **Step 5: Commit**

```bash
git add applications/vicinae-applications.desktop install.sh tests/test_vicinae_shortcut.py
git commit -m "fix(shortcuts): bind Alt+Space directly to Vicinae"
```

---

# Plan 2: macOS Control Center

## File Structure

- Modify `plasmoids/KdeControlStation/contents/ui/layouts/Tahoe.qml`: top-level macOS grid.
- Create `plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe/ConnectivityTile.qml`: Wi-Fi/Bluetooth/AirDrop group.
- Create `.../Tahoe/QuickToggle.qml`: reusable square tile.
- Create `.../Tahoe/SliderCard.qml`: macOS slider shell around existing controls.
- Create `.../Tahoe/NowPlayingCard.qml`: existing MPRIS component shell.
- Modify `plasmoids/KdeControlStation/contents/ui/lib/Card.qml`: safe glass/card tokens only if Tahoe needs them.
- Create `tests/test_control_center_qml.py`: syntax/property regression checks.

### Task 3: Build Tahoe layout primitives

**Files:**
- Create: `plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe/QuickToggle.qml`
- Create: `plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe/SliderCard.qml`
- Test: `tests/test_control_center_qml.py`

**Interfaces:**
- `QuickToggle`: properties `title`, `subtitle`, `icon`, `checked`, `enabled`; signal `triggered()`.
- `SliderCard`: properties `title`, `icon`; default property alias `content`.

- [ ] **Step 1: Write failing tests**

```python
from pathlib import Path

ROOT = Path(__file__).parents[1] / "plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe"


def test_quick_toggle_contract():
    text = (ROOT / "QuickToggle.qml").read_text()
    for token in ("property string title", "property string subtitle", "property string icon", "property bool checked", "signal triggered"):
        assert token in text


def test_slider_card_contract():
    text = (ROOT / "SliderCard.qml").read_text()
    assert "default property alias content" in text
    assert "property string title" in text
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_control_center_qml.py -v
```
Expected: FAIL with missing files.

- [ ] **Step 3: Implement `QuickToggle.qml`**

Use `Rectangle` with `radius: 14`, checked fill `#0A84FF`, unchecked fill `Qt.rgba(1,1,1,0.10)`, SF text, safe disabled opacity, `TapHandler`, and a `Kirigami.Icon`. Emit `triggered()` only when enabled.

- [ ] **Step 4: Implement `SliderCard.qml`**

Use a `Rectangle` (`radius: 14`, `color: Qt.rgba(1,1,1,0.10)`) containing title/icon header and a content slot. No backend logic.

- [ ] **Step 5: Run tests and QML syntax checks**

```bash
python -m pytest tests/test_control_center_qml.py -v
qmlformat --check \
  plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe/QuickToggle.qml \
  plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe/SliderCard.qml
```
Expected: PASS and exit 0.

- [ ] **Step 6: Commit**

```bash
git add plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe tests/test_control_center_qml.py
git commit -m "feat(control-center): add Tahoe layout primitives"
```

### Task 4: Compose connectivity, sliders, and Now Playing

**Files:**
- Create: `.../Tahoe/ConnectivityTile.qml`
- Create: `.../Tahoe/NowPlayingCard.qml`
- Modify: `plasmoids/KdeControlStation/contents/ui/layouts/Tahoe.qml`
- Test: `tests/test_control_center_qml.py`

**Interfaces:**
- Consumes existing `Components.NetworkBtn`, `BluetoothBtn`, `KDEConnect`, `DndButton`, `ColorSchemeSwitcher`, `BrightnessSlider`, `Volume`, `MediaPlayer`.
- Produces complete `Tahoe.qml` selected by existing layout index 3.

- [ ] **Step 1: Extend failing tests**

```python
def test_tahoe_uses_all_required_sections():
    text = (Path(__file__).parents[1] / "plasmoids/KdeControlStation/contents/ui/layouts/Tahoe.qml").read_text()
    for token in ("ConnectivityTile", "DndButton", "ColorSchemeSwitcher", "BrightnessSlider", "Volume", "NowPlayingCard"):
        assert token in text
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_control_center_qml.py::test_tahoe_uses_all_required_sections -v
```
Expected: FAIL because new components are absent.

- [ ] **Step 3: Implement connectivity card**

Compose existing backend-aware controls in a `2x2` card: Network wide row; Bluetooth and KDE Connect/AirDrop half rows. Keep their original click/page behavior.

- [ ] **Step 4: Implement Now Playing card**

Wrap `Components.MediaPlayer` in a rounded `Rectangle`, preserve its current backend/actions, and use null-safe visibility when no MPRIS player exists.

- [ ] **Step 5: Rewrite `Tahoe.qml` layout**

Structure:

```qml
ColumnLayout {
    RowLayout {
        ConnectivityTile { Layout.fillWidth: true }
        GridLayout {
            columns: 2
            Components.DndButton { }
            Components.ColorSchemeSwitcher { }
            Components.CommandRun { title: "Stage Manager"; command: "qdbus6 org.kde.KWin /Effects toggleOverview" }
            Components.KDEConnect { }
        }
    }
    SliderCard { Components.BrightnessSlider { } }
    SliderCard { Components.Volume { } }
    NowPlayingCard { Layout.fillWidth: true }
}
```

Use existing components; do not duplicate backend logic.

- [ ] **Step 6: Verify**

```bash
python -m pytest tests/test_control_center_qml.py -v
qmlformat --check plasmoids/KdeControlStation/contents/ui/layouts/Tahoe.qml \
  plasmoids/KdeControlStation/contents/ui/layouts/components/Tahoe/*.qml
```
Install changed files, restart Plasma once, open Control Center, exercise every tile/slider, then:

```bash
journalctl --user -u plasma-plasmashell.service --since "2 minutes ago" --no-pager \
 | grep -E 'KdeControlStation|TypeError|ReferenceError|Binding loop|unavailable' && exit 1 || true
```
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add plasmoids/KdeControlStation tests/test_control_center_qml.py
git commit -m "feat(control-center): redesign Tahoe layout"
```

---

# Plan 3: macOS Notification Center

## File Structure

- Create `patches/notification-center/src/notification-center.qrc`: resource map.
- Create `patches/notification-center/src/FullRepresentation.qml`: right-side sheet composition.
- Create `patches/notification-center/src/delegates/DelegateHistory.qml`: card style.
- Create `patches/notification-center/src/delegates/DelegateHistoryGrouped.qml`: app grouping style.
- Create `patches/notification-center/src/components/NotificationHeader.qml`: macOS header.
- Create `patches/notification-center/notification_preload.cpp`: QResource registration and notification AOT-cache bypass, process-gated to `plasmashell`.
- Modify `systemd/plasma-plasmashell.service.d/limit-nofile.conf`: preload both libraries using a colon-separated value.
- Create `tests/test_notification_override.py`.

### Task 5: Extract native notification QML references

**Files:**
- Create: `patches/notification-center/upstream/FullRepresentation.qml`
- Create: `patches/notification-center/upstream/delegates/DelegateHistory.qml`
- Create: `patches/notification-center/upstream/delegates/DelegateHistoryGrouped.qml`
- Create: `patches/notification-center/upstream/components/NotificationHeader.qml`
- Test: `tests/test_notification_override.py`

**Interfaces:**
- Upstream snapshots are reference inputs only; production overrides live under `src/`.

- [ ] **Step 1: Write failing resource-coverage test**

```python
from pathlib import Path
ROOT = Path(__file__).parents[1] / "patches/notification-center"


def test_required_upstream_snapshots_exist():
    for rel in (
        "upstream/FullRepresentation.qml",
        "upstream/delegates/DelegateHistory.qml",
        "upstream/delegates/DelegateHistoryGrouped.qml",
        "upstream/components/NotificationHeader.qml",
    ):
        assert (ROOT / rel).is_file()
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_notification_override.py -v
```
Expected: FAIL with missing snapshots.

- [ ] **Step 3: Extract exact native sources**

Create `tools/extract-plasma-qrc.py` that loads `/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.notifications.so` with `ctypes.CDLL`, reads each `:/qt/qml/plasma/applet/org/kde/plasma/notifications/...` path using `QFile`, and writes it to `patches/notification-center/upstream/`.

- [ ] **Step 4: Run extraction and tests**

```bash
python tools/extract-plasma-qrc.py notifications
python -m pytest tests/test_notification_override.py -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/extract-plasma-qrc.py patches/notification-center/upstream tests/test_notification_override.py
git commit -m "test(notification-center): snapshot native Plasma QML"
```

### Task 6: Style notification history without replacing its model

**Files:**
- Create: `patches/notification-center/src/FullRepresentation.qml`
- Create: `patches/notification-center/src/delegates/DelegateHistory.qml`
- Create: `patches/notification-center/src/delegates/DelegateHistoryGrouped.qml`
- Create: `patches/notification-center/src/components/NotificationHeader.qml`
- Modify: `tests/test_notification_override.py`

**Interfaces:**
- Preserve all model/action/reply/job signals from upstream files.
- Change presentation only.

- [ ] **Step 1: Add failing preservation/style tests**

```python
def test_notification_overrides_preserve_actions_and_replies():
    root = Path(__file__).parents[1] / "patches/notification-center/src"
    joined = "\n".join(p.read_text() for p in root.rglob("*.qml"))
    for token in ("actionInvoked", "replied", "dismissed", "closeClicked"):
        assert token in joined
    assert '#ee1c1c1e' in joined
    assert "radius: 16" in joined
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_notification_override.py -v
```
Expected: FAIL because overrides do not exist.

- [ ] **Step 3: Copy upstream files to `src/` and make surgical visual edits**

- `FullRepresentation.qml`: right-aligned 390px sheet, `#ee1c1c1e`, radius 16, 12px spacing; preserve list models, DND, jobs, clear-all.
- `DelegateHistory.qml`: rounded card `#14ffffff`, app icon, SF typography, timestamp, action/reply controls unchanged.
- `DelegateHistoryGrouped.qml`: group header + stack spacing; preserve expansion and group clear.
- `NotificationHeader.qml`: macOS header spacing and compact dismiss/expand controls.

Do not rename signals or model properties.

- [ ] **Step 4: Run tests and QML checks**

```bash
python -m pytest tests/test_notification_override.py -v
qmlformat --check patches/notification-center/src/**/*.qml patches/notification-center/src/*.qml
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add patches/notification-center/src tests/test_notification_override.py
git commit -m "feat(notification-center): add macOS history presentation"
```

### Task 7: Register notification overrides safely

**Files:**
- Create: `patches/notification-center/src/notification-center.qrc`
- Create: `patches/notification-center/notification_preload.cpp`
- Modify: `systemd/plasma-plasmashell.service.d/limit-nofile.conf`
- Modify: `install.sh`
- Test: `tests/test_notification_override.py`

**Interfaces:**
- Produces `~/.local/share/macos-tahoe/notification-center.rcc` and `~/.local/lib/libmacos_notification_center.so`.
- Process gate: `/proc/self/comm == plasmashell`.

- [ ] **Step 1: Extend failing preload tests**

```python
def test_preload_is_plasmashell_gated_and_bypasses_only_notifications():
    text = (Path(__file__).parents[1] / "patches/notification-center/notification_preload.cpp").read_text()
    assert '"plasmashell"' in text
    assert "org.kde.plasma.notifications.so" in text
    assert "QmlUnitCacheHookRegistration" in text
    assert 'unsetenv("LD_PRELOAD")' in text
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_notification_override.py -v
```
Expected: FAIL because preload source is absent.

- [ ] **Step 3: Implement resource and preload**

Mirror the proven `patches/bartender/bartender_preload.cpp` pattern. Register only `notification-center.rcc`; use `dladdr(hook->lookupCachedQmlUnit)` and skip cache hook only when path contains `org.kde.plasma.notifications.so`. Never invoke the hook while loader lock is held.

Set service environment:

```ini
Environment="LD_PRELOAD=%h/.local/lib/libmacos_bartender.so:%h/.local/lib/libmacos_notification_center.so"
```

Each constructor calls `unsetenv("LD_PRELOAD")` only after its own library has loaded into `plasmashell`; verify both libraries still load with colon list before retaining this pattern. If first constructor clearing prevents second preload, consolidate notification registration into `libmacos_bartender.so` instead of adding a second library.

- [ ] **Step 4: Build and verify resources**

```bash
rcc -binary patches/notification-center/src/notification-center.qrc -o /tmp/notification-center.rcc
g++ -shared -fPIC -O2 patches/notification-center/notification_preload.cpp \
  $(pkg-config --cflags --libs Qt6Core Qt6Qml) -ldl -o /tmp/libmacos_notification_center.so
python -m pytest tests/test_notification_override.py -v
```
Expected: exit 0.

- [ ] **Step 5: Install and runtime verify**

Install resources/libraries, daemon-reload, restart Plasma once, open notification history, send test notification:

```bash
notify-send -a "macOS Test" "Notification Center" "Actions and grouping remain active"
journalctl --user -u plasma-plasmashell.service --since "2 minutes ago" --no-pager \
 | grep -E 'notifications|TypeError|ReferenceError|Binding loop|unavailable' && exit 1 || true
```
Expected: no QML error output; grouped card appears.

- [ ] **Step 6: Commit**

```bash
git add patches/notification-center systemd/plasma-plasmashell.service.d/limit-nofile.conf install.sh tests/test_notification_override.py
git commit -m "feat(notification-center): register macOS Plasma overrides"
```

---

# Plan 4: Dock Fidelity

## File Structure

- Create `patches/dock/src/dock.qrc`.
- Create `patches/dock/src/Task.qml`: pointer-local scale and indicators based on upstream task QML.
- Create `patches/dock/src/TaskList.qml`: expose pointer coordinate to delegates.
- Create `patches/dock/src/TaskBadgeOverlay.qml`: badge polish if needed.
- Create `patches/dock/dock_preload.cpp` or consolidate into bartender preload.
- Modify `install.sh` and Plasma preload config.
- Create `tests/test_dock_override.py`.

### Task 8: Snapshot and test taskmanager interfaces

**Files:**
- Create: `patches/dock/upstream/Task.qml`
- Create: `patches/dock/upstream/TaskList.qml`
- Create: `patches/dock/upstream/TaskBadgeOverlay.qml`
- Modify: `tools/extract-plasma-qrc.py`
- Test: `tests/test_dock_override.py`

**Interfaces:**
- Preserve task activation, grouping, launcher, drag/drop, progress, audio, tooltip, and window model behavior.

- [ ] **Step 1: Write failing snapshot tests**

```python
from pathlib import Path
ROOT = Path(__file__).parents[1] / "patches/dock/upstream"

def test_taskmanager_snapshots_exist():
    for name in ("Task.qml", "TaskList.qml", "TaskBadgeOverlay.qml"):
        assert (ROOT / name).is_file()
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_dock_override.py -v
```
Expected: FAIL.

- [ ] **Step 3: Extend extractor and snapshot native files**

Add taskmanager module mapping to `tools/extract-plasma-qrc.py`, then run:

```bash
python tools/extract-plasma-qrc.py taskmanager
```

- [ ] **Step 4: Verify and commit**

```bash
python -m pytest tests/test_dock_override.py -v
git add tools/extract-plasma-qrc.py patches/dock/upstream tests/test_dock_override.py
git commit -m "test(dock): snapshot native taskmanager QML"
```

### Task 9: Add pointer-local magnification and indicators

**Files:**
- Create: `patches/dock/src/Task.qml`
- Create: `patches/dock/src/TaskList.qml`
- Create: `patches/dock/src/TaskBadgeOverlay.qml`
- Modify: `tests/test_dock_override.py`

**Interfaces:**
- `TaskList.qml` produces `property real dockPointerX`, `property bool dockHovered`.
- `Task.qml` consumes those values and computes scale with maximum `1.34` and two-neighbor falloff.

- [ ] **Step 1: Write failing visual-logic tests**

```python
def test_dock_magnification_is_bounded_and_local():
    root = Path(__file__).parents[1] / "patches/dock/src"
    task = (root / "Task.qml").read_text()
    task_list = (root / "TaskList.qml").read_text()
    assert "dockPointerX" in task_list
    assert "dockHovered" in task_list
    assert "Math.min(1.34" in task
    assert "distance" in task
    assert "Behavior on scale" in task


def test_native_task_behaviors_preserved():
    text = (Path(__file__).parents[1] / "patches/dock/src/Task.qml").read_text()
    for token in ("activate", "group", "launcher", "Drag", "ToolTip"):
        assert token.lower() in text.lower()
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_dock_override.py -v
```
Expected: FAIL.

- [ ] **Step 3: Copy upstream to `src/` and add pointer coordinate**

In `TaskList.qml`, add a `HoverHandler` and map point position to list coordinates. Expose:

```qml
property real dockPointerX: hover.point.position.x
property bool dockHovered: hover.hovered
```

- [ ] **Step 4: Add bounded scale to `Task.qml`**

Compute task center and distance:

```qml
readonly property real pointerDistance: Math.abs((x + width / 2) - taskList.dockPointerX)
readonly property real magnification: !taskList.dockHovered
    ? 1
    : Math.min(1.34, 1 + 0.34 * Math.max(0, 1 - pointerDistance / (width * 2.25)))
scale: magnification
transformOrigin: Item.Bottom
Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
```

Do not change layout width/height, task model, or launcher identity.

- [ ] **Step 5: Restyle running/attention indicators**

Use a 4px white running dot with 0.85 opacity, and a bounded `SequentialAnimation` bounce for `NeedsAttention`. Preserve native activation and progress overlays.

- [ ] **Step 6: Verify**

```bash
python -m pytest tests/test_dock_override.py -v
qmlformat --check patches/dock/src/*.qml
```
Install and test hover across all pinned/running icons, Chrome stacking, group popup, drag reorder, launch, attention, and both monitor docks. Verify no Plasma errors.

- [ ] **Step 7: Commit**

```bash
git add patches/dock/src tests/test_dock_override.py
git commit -m "feat(dock): add macOS magnification and indicators"
```

### Task 10: Register taskmanager override

**Files:**
- Create: `patches/dock/src/dock.qrc`
- Create: `patches/dock/dock_preload.cpp` or modify `patches/bartender/bartender_preload.cpp`
- Modify: `install.sh`
- Modify: `systemd/plasma-plasmashell.service.d/limit-nofile.conf`
- Test: `tests/test_dock_override.py`

- [ ] **Step 1: Add failing registration tests**

Assert resource aliases exist, process gate is `plasmashell`, and AOT bypass matches only `org.kde.plasma.taskmanager.so`.

- [ ] **Step 2: Run failure**

```bash
python -m pytest tests/test_dock_override.py -v
```

- [ ] **Step 3: Implement and build**

Prefer consolidating registration into existing `libmacos_bartender.so` to avoid multiple `LD_PRELOAD` constructors clearing the environment. Register `dock.rcc` from the existing constructor and add `org.kde.plasma.taskmanager.so` to the `dladdr` allowlist.

- [ ] **Step 4: Runtime verification**

Restart Plasma once. Confirm PID remains stable for 5 minutes of hover/launch/reorder. Confirm no automatic `evaluateScript` call exists:

```bash
! grep -R "org.kde.PlasmaShell.evaluateScript" ~/.local/bin/macos-*screen* ~/.local/bin/macos-multiscreen-sync.sh
```

- [ ] **Step 5: Commit**

```bash
git add patches/dock patches/bartender install.sh tests/test_dock_override.py
git commit -m "feat(dock): register taskmanager visual overrides"
```

---

# Plan 5: Finder-style Dolphin and Quick Look

## File Structure

- Create `bin/macos-quicklook.py`: one-file MIME dispatcher and PyQt6 preview window.
- Create `applications/macos-quicklook.desktop`: launcher/service entry.
- Create `dolphin/dolphinui.rc`: unified toolbar and Space shortcut action integration.
- Create `dolphin/dolphinrc`: Finder-like defaults.
- Create `dolphin/user-places.fragment.xml`: required Places entries.
- Modify `install.sh`: merge settings/places safely and register shortcut/service menu.
- Create `tests/test_quicklook.py` and `tests/test_dolphin_config.py`.

### Task 11: Implement MIME resolver for Quick Look

**Files:**
- Create: `bin/macos-quicklook.py`
- Test: `tests/test_quicklook.py`

**Interfaces:**
- Produces `preview_kind(path: Path, mime: str | None = None) -> str` returning `image|pdf|video|audio|text|metadata`.
- CLI: `macos-quicklook.py FILE`.

- [ ] **Step 1: Write failing tests**

```python
import importlib.util
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "bin/macos-quicklook.py"
spec = importlib.util.spec_from_file_location("quicklook", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_preview_kind_groups():
    assert mod.preview_kind(Path("a.png"), "image/png") == "image"
    assert mod.preview_kind(Path("a.pdf"), "application/pdf") == "pdf"
    assert mod.preview_kind(Path("a.mp4"), "video/mp4") == "video"
    assert mod.preview_kind(Path("a.mp3"), "audio/mpeg") == "audio"
    assert mod.preview_kind(Path("a.md"), "text/markdown") == "text"
    assert mod.preview_kind(Path("a.bin"), "application/octet-stream") == "metadata"
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_quicklook.py -v
```
Expected: FAIL because module is absent.

- [ ] **Step 3: Implement resolver**

Use `mimetypes.guess_type`, explicit PDF check, `text/*`, and suffix fallback for Markdown/source extensions. No external dependency.

- [ ] **Step 4: Verify**

```bash
python -m pytest tests/test_quicklook.py -v
python -m py_compile bin/macos-quicklook.py
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add bin/macos-quicklook.py tests/test_quicklook.py
git commit -m "feat(quicklook): add MIME preview resolver"
```

### Task 12: Build the Quick Look preview window

**Files:**
- Modify: `bin/macos-quicklook.py`
- Modify: `tests/test_quicklook.py`

**Interfaces:**
- `QuickLookWindow(path: Path)`; closes on Space/Escape; left/right emits sibling navigation request.

- [ ] **Step 1: Add failing headless tests**

```python
def test_window_contract_and_close_keys():
    text = SCRIPT.read_text()
    assert "class QuickLookWindow" in text
    assert "Qt.Key.Key_Space" in text
    assert "Qt.Key.Key_Escape" in text
    assert "QMediaPlayer" in text
    assert "QPdfView" in text
```

- [ ] **Step 2: Run failure**

```bash
QT_QPA_PLATFORM=offscreen python -m pytest tests/test_quicklook.py -v
```

- [ ] **Step 3: Implement window**

- Dark translucent `QMainWindow`, 900x640, centered.
- Image: `QLabel` + scaled `QPixmap`.
- PDF: `QPdfDocument` + `QPdfView`.
- Video/audio: `QMediaPlayer`, `QAudioOutput`, `QVideoWidget`; audio shows metadata/icon.
- Text/Markdown/source: read max 2 MiB into read-only `QPlainTextEdit` with SF Mono.
- Metadata fallback: icon, filename, MIME, size, modified time, Open button.
- Space/Escape closes; no file mutation.

- [ ] **Step 4: Verify headless and representative files**

```bash
QT_QPA_PLATFORM=offscreen python -m pytest tests/test_quicklook.py -v
python bin/macos-quicklook.py assets/screenshots/03-floating-dock.png
python bin/macos-quicklook.py README.md
```
Expected: tests PASS; manual windows open and close with Space.

- [ ] **Step 5: Commit**

```bash
git add bin/macos-quicklook.py tests/test_quicklook.py
git commit -m "feat(quicklook): add macOS preview window"
```

### Task 13: Apply Finder-style Dolphin defaults and Places

**Files:**
- Create: `dolphin/dolphinrc`
- Create: `dolphin/dolphinui.rc`
- Create: `dolphin/user-places.fragment.xml`
- Create: `applications/macos-quicklook.desktop`
- Modify: `install.sh`
- Test: `tests/test_dolphin_config.py`

**Interfaces:**
- Dolphin Quick Look action invokes `macos-quicklook.py` with selected local URL.
- Places include Home, Desktop, Documents, Downloads, Windows SSD, Handoff, Cloud, Network.

- [ ] **Step 1: Write failing config tests**

```python
from pathlib import Path
ROOT = Path(__file__).parents[1]


def test_finder_defaults_and_places():
    rc = (ROOT / "dolphin/dolphinrc").read_text()
    assert "MenuBar=Disabled" in rc
    assert "ShowFullPath=false" in rc
    places = (ROOT / "dolphin/user-places.fragment.xml").read_text()
    for name in ("Handoff", "Cloud", "Windows SSD", "Network"):
        assert name in places


def test_quicklook_desktop_entry():
    text = (ROOT / "applications/macos-quicklook.desktop").read_text()
    assert "macos-quicklook.py %F" in text
```

- [ ] **Step 2: Run and verify failure**

```bash
python -m pytest tests/test_dolphin_config.py -v
```

- [ ] **Step 3: Add config files**

`dolphinrc` sets disabled menu bar, static 22px Places icons, tooltips, preview plugins, and Finder-like startup view. `dolphinui.rc` defines compact Back/Forward/View/Search toolbar ordering and a Quick Look action. `user-places.fragment.xml` uses sanitized URLs such as `file://@HOME@/Downloads` and `file:///run/media/@USER@/Windows-SSD`.

- [ ] **Step 4: Add safe installer merge**

Back up current `dolphinrc`, `dolphinui.rc`, and `user-places.xbel`. Use `kwriteconfig6` for Dolphin scalar settings. Use Python XML parsing to append only places whose URLs are absent; never overwrite the whole `user-places.xbel`.

Register Quick Look action/shortcut without stealing Space in text-entry contexts. Scope it to Dolphin's action collection.

- [ ] **Step 5: Verify**

```bash
python -m pytest tests/test_dolphin_config.py -v
xmllint --noout dolphin/user-places.fragment.xml dolphin/dolphinui.rc
```

Install, restart Dolphin, verify toolbar/Places, select image/PDF/video/text and press Space, then inspect logs:

```bash
journalctl --user --since "2 minutes ago" --no-pager | grep -E 'dolphin|macos-quicklook|Traceback|TypeError' && exit 1 || true
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add dolphin applications/macos-quicklook.desktop install.sh tests/test_dolphin_config.py
git commit -m "feat(dolphin): add Finder styling and Quick Look"
```

---

## Final Integration Verification

- [ ] Run all tests:

```bash
python -m pytest tests/test_vicinae_bridge.py tests/test_vicinae_shortcut.py \
  tests/test_control_center_qml.py tests/test_notification_override.py \
  tests/test_dock_override.py tests/test_quicklook.py tests/test_dolphin_config.py -v
```
Expected: all PASS.

- [ ] Verify service health and no failed units:

```bash
systemctl --user --failed --no-pager
systemctl --user is-active plasma-plasmashell.service plasma-krunner.service vicinae.service macos-multiscreen-dock.service
```
Expected: zero failed units; each service `active`.

- [ ] Verify crash guard:

```bash
! grep -R "org.kde.PlasmaShell.evaluateScript" \
  ~/.local/bin/macos-screen-watcher.sh ~/.local/bin/macos-multiscreen-sync.sh
pid_before=$(systemctl --user show plasma-plasmashell.service -p MainPID --value)
sleep 60
pid_after=$(systemctl --user show plasma-plasmashell.service -p MainPID --value)
test "$pid_before" = "$pid_after"
```
Expected: no grep output; same PID.

- [ ] Capture screenshots on both monitors for Control Center, Notification Center, Dock, and Dolphin.

- [ ] Verify public repository contains no personal data:

```bash
git grep -nEi 'tejaslamba|tejas22feb|/home/[^@]' -- ':!docs/superpowers/specs/*'
```
Expected: no unintended matches.

- [ ] Push only after every module's commit and final verification pass.
