import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var micApps: []
    property var camApps: []
    property var screenApps: []
    readonly property bool anyActive: micApps.length > 0 || camApps.length > 0 || screenApps.length > 0

    Plasmoid.status: anyActive ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    preferredRepresentation: compactRepresentation

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const xhr = new XMLHttpRequest();
            xhr.open("GET", "file:///run/user/1000/macos-privacy-status.json", true);
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.responseText) {
                    try {
                        const parsed = JSON.parse(xhr.responseText.trim());
                        root.micApps = parsed.mic || [];
                        root.camApps = parsed.cam || [];
                        root.screenApps = parsed.screen || [];
                    } catch (e) {}
                }
            };
            xhr.send();
        }
    }

    compactRepresentation: MouseArea {
        id: compactRoot
        visible: root.anyActive
        Layout.preferredWidth: root.anyActive ? dotsRow.implicitWidth + 10 : 0
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.fillHeight: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded

        Row {
            id: dotsRow
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                visible: root.micApps.length > 0
                width: 8
                height: 8
                radius: 4
                color: "#FF9500"
            }

            Rectangle {
                visible: root.camApps.length > 0
                width: 8
                height: 8
                radius: 4
                color: "#34C759"
            }

            Rectangle {
                visible: root.screenApps.length > 0
                width: 8
                height: 8
                radius: 4
                color: "#5856D6"
            }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 260
        Layout.preferredHeight: col.implicitHeight + 24

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                text: "Privacy & Active Capture"
                color: "white"
                font.family: "SF Pro Display"
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            RowLayout {
                visible: root.micApps.length > 0
                spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: "#FF9500" }
                Text {
                    text: "Microphone: " + root.micApps.join(", ")
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.family: "SF Pro Text"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                visible: root.camApps.length > 0
                spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: "#34C759" }
                Text {
                    text: "Camera: " + root.camApps.join(", ")
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.family: "SF Pro Text"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                visible: root.screenApps.length > 0
                spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: "#5856D6" }
                Text {
                    text: "Screen Recording: " + root.screenApps.join(", ")
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.family: "SF Pro Text"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
