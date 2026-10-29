/*
    SPDX-License-Identifier: GPL-2.0-or-later
    macOS AirPods / Bluetooth Audio connect & disconnect card with battery ring,
    sound effect, and UPnP / PipeWire battery fallback (#3).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property var bluetooth
    required property Theme theme
    property bool enabled: true
    property int lowBattery: 15

    property var known: ({})      // address → name of connected devices

    SoundPlayer {
        id: connectSound
    }

    function batteryTrailing(pct: int): var {
        const val = pct >= 0 ? pct : 100;
        return {
            type: "ring",
            value: val / 100,
            color: val <= lowBattery ? theme.red : theme.live,
            text: pct >= 0 ? (String(pct) + "%") : "✓"
        };
    }

    Connections {
        target: provider.bluetooth
        function onConnectedDevicesChanged() { Qt.callLater(provider.diff); }
    }
    Component.onCompleted: diff()

    function diff(): void {
        const now = {};
        for (const d of bluetooth.connectedDevices) {
            now[d.address] = d.name;
            if (!(d.address in known) && enabled) {
                connectSound.play("file://@HOME@/.local/share/sounds/macOS/stereo/complete.oga");
                const pct = bluetooth.batteryOf(d);
                manager.flash({
                    key: "bt-" + d.address,
                    icon: bluetooth.iconFor(d),
                    color: theme.live,
                    title: d.name,
                    subtitle: pct >= 0 ? ("Connected · " + pct + "% Battery") : Lang.i18n("Connected · Audio Ready"),
                    trailing: batteryTrailing(pct),
                    duration: 4200
                });
            }
        }
        for (const addr in known) {
            if (!(addr in now) && enabled) {
                manager.flash({
                    key: "bt-" + addr,
                    icon: "network-bluetooth-symbolic",
                    color: theme.subText,
                    title: known[addr],
                    subtitle: Lang.i18n("Disconnected"),
                    duration: 3000
                });
            }
        }
        known = now;
    }

    // Low battery warning per connected device (once until it recovers).
    Instantiator {
        model: provider.bluetooth.connectedDevices
        delegate: QtObject {
            required property var modelData
            property bool warned: false
            readonly property int pct: provider.bluetooth.batteryOf(modelData)
            onPctChanged: {
                if (pct >= 0 && pct < provider.lowBattery && !warned && provider.enabled) {
                    warned = true;
                    provider.manager.flash({
                        key: "bt-low-" + modelData.address,
                        icon: provider.bluetooth.iconFor(modelData),
                        color: provider.theme.red,
                        title: modelData.name,
                        subtitle: Lang.i18n("Battery low") + " (" + pct + "%)",
                        trailing: provider.batteryTrailing(pct),
                        duration: 5000
                    });
                } else if (pct >= provider.lowBattery + 5) {
                    warned = false;
                }
            }
        }
    }
}
