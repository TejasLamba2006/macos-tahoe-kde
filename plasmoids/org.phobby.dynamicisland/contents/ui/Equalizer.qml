/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Real-time audio-reactive sound-wave bars + AlbumColor tint (#4).
*/
import QtQuick

Row {
    id: eq

    property bool running: false
    property color color: "white"
    property int bars: 4
    property real barWidth: 3
    property int stepsPerSecond: 20

    spacing: 2
    height: 14

    Loader {
        id: liveLevels
        active: eq.running && eq.visible
        source: "LevelsBridge.qml"
    }
    Binding {
        target: liveLevels.item
        property: "active"
        value: eq.running && eq.visible
        when: liveLevels.item !== null
    }

    readonly property bool hasLive: liveLevels.item !== null && (liveLevels.item.level > 0.005 || liveLevels.item.bass > 0.005)
    readonly property real liveLevel: liveLevels.item ? liveLevels.item.level : 0
    readonly property real liveBass: liveLevels.item ? liveLevels.item.bass : 0

    property real clock: 0
    Timer {
        interval: Math.round(1000 / Math.max(1, eq.stepsPerSecond))
        repeat: true
        running: eq.running && eq.visible
        onTriggered: eq.clock += interval
    }

    Repeater {
        model: eq.bars
        delegate: Rectangle {
            id: bar
            required property int index
            readonly property int base: 260 + (index * 97) % 170
            readonly property var moves: [[0.55 + (index % 2) * 0.45, base], [0.25, base * 0.8], [0.95 - (index % 3) * 0.2, base * 1.2], [0.35, base]]
            readonly property real round: base * 4

            function fallbackLevel(t: real): real {
                let from = moves[3][0];
                for (const move of moves) {
                    if (t < move[1]) return from + (move[0] - from) * (1 - Math.cos(Math.PI * t / move[1])) / 2;
                    t -= move[1];
                    from = move[0];
                }
                return from;
            }

            function audioReactiveLevel(): real {
                const b = eq.liveBass;
                const l = eq.liveLevel;
                const jitter = 0.08 * Math.sin(eq.clock * 0.02 + index * 1.7);
                let v = 0.22;
                if (index === 0) v = 0.18 + Math.min(0.82, b * 1.25 + jitter);
                else if (index === 1) v = 0.20 + Math.min(0.80, (b * 0.65 + l * 0.65) + jitter);
                else if (index === 2) v = 0.18 + Math.min(0.82, l * 1.20 - jitter);
                else v = 0.18 + Math.min(0.82, (l * 0.85 + Math.abs(l - b) * 0.6) + jitter);
                return Math.max(0.18, Math.min(1.0, v));
            }

            anchors.verticalCenter: parent.verticalCenter
            width: eq.barWidth
            radius: width / 2
            color: eq.color
            height: eq.height * (eq.running ? (eq.hasLive ? audioReactiveLevel() : fallbackLevel(eq.clock % round)) : 0.25)
            Behavior on height { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
        }
    }
}
