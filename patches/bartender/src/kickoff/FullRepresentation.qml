/*
    SPDX-License-Identifier: GPL-2.0-or-later
    ponytail: macOS Apple Menu () dropdown replacing KDE Kickoff Start Menu
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

Item {
    id: root

    property Item normalPage: Item {
        property real preferredSideBarWidth: 0
    }
    property bool blockingHoverFocus: false
    property var interceptedPosition: null
    readonly property var appletInterface: kickoff

    implicitWidth: 246
    implicitHeight: menuColumn.implicitHeight + 12

    Layout.minimumWidth: 246
    Layout.preferredWidth: 246
    Layout.maximumWidth: 246

    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
        function exec(cmd) {
            kickoff.expanded = false;
            connectSource(cmd);
        }
    }

    // macOS Apple Menu dark frosted glass sheet
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 11
        color: "#ee1e1e20"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    component MenuRow: Rectangle {
        id: rowItem
        property string label: ""
        property string shortcutText: ""
        property string command: ""
        property bool hasSubArrow: false

        Layout.fillWidth: true
        Layout.leftMargin: 5
        Layout.rightMargin: 5
        height: 24
        radius: 5
        color: rowMouse.containsMouse ? "#0A84FF" : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: rowItem.label
                color: "#ffffff"
                font.family: "SF Pro Text"
                font.pixelSize: 13
                font.weight: Font.Normal
                elide: Text.ElideRight
            }

            Text {
                visible: rowItem.shortcutText.length > 0 || rowItem.hasSubArrow
                text: rowItem.hasSubArrow ? "›" : rowItem.shortcutText
                color: rowMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45)
                font.family: "SF Pro Text"
                font.pixelSize: rowItem.hasSubArrow ? 14 : 12
                font.weight: Font.Normal
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (rowItem.command.length > 0) {
                    runner.exec(rowItem.command);
                }
            }
        }
    }

    component MenuDivider: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        height: 1
        color: Qt.rgba(1, 1, 1, 0.12)
    }

    ColumnLayout {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 6
        spacing: 1

        MenuRow {
            label: "About This Mac"
            command: "kinfocenter"
        }

        MenuDivider {}

        MenuRow {
            label: "System Settings…"
            command: "systemsettings"
        }

        MenuRow {
            label: "App Store / Applications…"
            command: "/usr/bin/vicinae toggle"
        }

        MenuDivider {}

        MenuRow {
            label: "Force Quit / Activity Monitor…"
            shortcutText: "⌥⌘⎋"
            command: "plasma-systemmonitor"
        }

        MenuDivider {}

        MenuRow {
            label: "Sleep"
            command: "systemctl suspend"
        }

        MenuRow {
            label: "Restart…"
            command: "qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot"
        }

        MenuRow {
            label: "Shut Down…"
            command: "qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptShutDown"
        }

        MenuDivider {}

        MenuRow {
            label: "Lock Screen"
            shortcutText: "⌃⌘Q"
            command: "loginctl lock-session"
        }

        MenuRow {
            label: "Log Out " + (quickshellUser.name || "User") + "…"
            shortcutText: "⇧⌘Q"
            command: "qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptLogout"
        }
    }

    QtObject {
        id: quickshellUser
        property string name: "@USER_FULLNAME@"
    }
}
