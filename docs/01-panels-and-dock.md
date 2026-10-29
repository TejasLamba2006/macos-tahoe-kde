# 01. Multi-Monitor Top Menu Bar & Bottom Floating Dock

![Top Bar](https://raw.githubusercontent.com/TejasLamba2006/macos-tahoe-kde/main/assets/screenshots/02-top-bar-dynamic-island.png)
![Bottom Dock](https://raw.githubusercontent.com/TejasLamba2006/macos-tahoe-kde/main/assets/screenshots/03-floating-dock.png)

## Why Stock Plasma Panels Break on Dual Monitors

When you unplug or wake an external monitor (`HDMI-A-1` + `eDP-1`), KDE Plasma 6 does two frustrating things:
1. Secondary monitors don't automatically inherit your top menu bar and bottom dock unless cloned.
2. Desktop icons assigned to a temporarily disabled screen get moved into `[ScreenMapping] itemsOnDisabledScreens=` inside `~/.config/plasma-org.kde.plasma.desktop-appletsrc` and vanish from your main desktop.

### How `bin/macos-screen-watcher.sh` Fixes Both
- Runs as a user service (`macos-multiscreen-dock.service`).
- Checks `screenCount` every 10 seconds. If any monitor is missing its Top Bar, Bottom Dock, or Aerial wallpaper, it runs `macos-multiscreen-sync.sh` non-destructively (it never wipes widgets you added manually, it copies widget config from Screen 0 to secondary monitors).
- Automatically checks `itemsOnDisabledScreens` in `plasma-org.kde.plasma.desktop-appletsrc` and merges stranded `desktop:/` entries back onto Screen 0.

## Why Custom Dock Icons Look Smaller Than `icontasks` (and the Fix)

If you put a custom QML applet (or `org.kde.plasma.marginsseparator`) inside a Plasma 6 dock next to `org.kde.plasma.icontasks`:
1. `marginsseparator` flips `inSlimMarginsArea` inside Plasma's `PanelLayout.qml`, shrinking every applet to its right.
2. Any applet that doesn't set `Plasmoid.constraintHints: Plasmoid.CanFillArea` gets padded by `AppletContainer`, making it ~20% smaller than the main app icons.

Look at `plasmoids/org.macos.downloads/contents/ui/main.qml` and `plasmoids/org.macos.trash/contents/ui/main.qml`:
```qml
PlasmoidItem {
    id: root
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    preferredRepresentation: fullRepresentation
```
And `plasmoids/org.macos.dockseparator` draws a clean `1px` vertical line (`Qt.rgba(1, 1, 1, 0.24)`) without triggering `MarginAreasSeparator`.

## Top Menu Bar Blur (`better_blur_dx` + `MacTahoe-Dark`)

By default, maximizing a window on `MacTahoe-Dark` triggers `AdaptiveTransparency`, switching the top bar to `solid/widgets/panel-background.svgz` and killing the blur. Furthermore, `better_blur_dx` defaults to `BlurDocks=false`.

To keep the top menu bar frosted at all times:
1. Force `panelOpacity=2` (`translucent`) on all panels in `plasmashellrc`.
2. Enable `BlurDocks=true` and `BlurMenus=true` under `[Effect-better-blur-dx]` in `~/.config/kwinrc`.
