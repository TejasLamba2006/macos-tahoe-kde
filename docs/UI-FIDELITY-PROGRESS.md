# UI fidelity progress and verification

## Completed

- Vicinae: `Alt+Space` registered through `X-KDE-Shortcuts`; native KGlobalAccel invocation and daemon health checked.
- Control Center: surgical spacing/radius restyle of existing Tahoe grid; broken wrapper implementation reverted. No fake Stage Manager or Screen Mirroring controls.
- Notification Center: native Plasma history/cards restyled, native app grouping/actions/replies/job handlers preserved; calendar/weather sources read from Dynamic Island configuration; battery uses native model. Tray popup expanded to accommodate widgets.
- UI resources built from checked-in source using `tools/install-ui-resources.py --output DIRECTORY [--install]`. Install backs up existing resources and replaces binaries atomically. Only the existing preload library is used.

## Verification

Run from any directory:

```bash
REPO=/path/to/macos-tahoe-kde
python3 -I -m unittest discover -s "$REPO/tests" -v
python3 -I "$REPO/tools/install-ui-resources.py" --output /path/to/new/build-directory
# Local-machine integration check (configured Dynamic Island required):
timeout 25 python3 -I "$REPO/tools/test-notification-runtime.py"
```

Observed live: grouped test notification cards; calendar event `Busy`, 1:00 PM; battery 80%; both menu-bar panels present; no new notification-related QML errors. Calendar/backend construction and clean Qt teardown verified.

Weather currently reports a service error, rendered as **Weather unavailable**; this is not a successful weather forecast check. Native notification action/reply wiring is retained from upstream, but interactive reply and job pause/resume have not yet been end-to-end tested. Existing brightness applet `PopupDialog.qml:105` null error remains upstream/unrelated.

## Remaining

- Dock pointer-local magnification, attention/launch motion, and running indicators.
- Finder-style Dolphin defaults, Places integration, and Space-key Quick Look.
- Real Stage Manager needs a separate supported window-grouping implementation, not an Overview button renamed to Stage Manager.
- Dolphin has no native Miller-column view; do not advertise Details View as Column View.

After each push, verify revision parity, built/deployed resource parity, tests, live screenshots and relevant logs. A syntax pass is not a behavior pass.
