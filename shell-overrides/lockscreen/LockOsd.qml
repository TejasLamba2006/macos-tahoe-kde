/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: root

    property int timeout: 1600
    property var osdValue
    property int osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon
    property bool showingProgress: false

    implicitWidth: 230
    implicitHeight: 44

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 14
        spacing: 12

        Kirigami.Icon {
            id: iconItem
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            source: root.icon + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : "")
            visible: valid
        }

        // macOS 16-segment Chicklet Volume/Brightness Bar
        Row {
            id: segmentsRow
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            visible: root.showingProgress

            readonly property int totalChiclets: 16
            readonly property int activeChiclets: Math.round(Math.min(1.0, Math.max(0.0, Number(root.osdValue) / Math.max(1, root.osdMaxValue))) * totalChiclets)

            Repeater {
                model: segmentsRow.totalChiclets
                Rectangle {
                    required property int index
                    width: 8
                    height: 6
                    radius: 1.5
                    color: index < segmentsRow.activeChiclets
                           ? Qt.rgba(1, 1, 1, 0.95)
                           : Qt.rgba(1, 1, 1, 0.22)
                }
            }
        }

        // Text-only OSD fallback (e.g., Muted / Touchpad / Keyboard Layout)
        Text {
            id: textLabel
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            visible: !root.showingProgress
            text: root.osdValue ? String(root.osdValue) : ""
            color: Qt.rgba(1, 1, 1, 0.92)
            font.family: "SF Pro Text"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
