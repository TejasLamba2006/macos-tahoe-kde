/*
    SPDX-License-Identifier: LGPL-2.0-or-later
    ponytail: macOS Bartender icon-only tray items with subtle rounded hover pill
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: abstractItem

    required property int index
    required property var model
    required property int status
    required property int effectiveStatus

    required property string itemId
    property alias text: label.text

    required mainText
    required subText
    required textFormat

    readonly property alias iconContainer: iconContainer
    readonly property bool inHiddenLayout: effectiveStatus === PlasmaCore.Types.PassiveStatus
    readonly property bool inVisibleLayout: effectiveStatus === PlasmaCore.Types.ActiveStatus

    property bool effectivePressed: false

    readonly property int margins: 2
    readonly property int maxTextLines: 1

    signal activated(var pos)
    signal clicked(var mouse)
    signal pressed(var mouse)
    signal wheel(var wheel)
    signal contextMenu(var mouse)

    PulseAnimation {
        targetItem: iconContainer
        running: (abstractItem.status === PlasmaCore.Types.NeedsAttentionStatus
                || abstractItem.status === PlasmaCore.Types.RequiresAttentionStatus)
            && Kirigami.Units.longDuration > 0
    }

    Rectangle {
        visible: abstractItem.inHiddenLayout
        anchors.centerIn: parent
        width: 28
        height: 24
        radius: 6
        color: mouseArea.containsPress
            ? Qt.rgba(1, 1, 1, 0.24)
            : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouseArea
        propagateComposedEvents: true
        z: abstractItem.inHiddenLayout ? 1 : 0
        anchors.fill: abstractItem
        hoverEnabled: true
        drag.filterChildren: true
        acceptedButtons: Qt.AllButtons
        onPositionChanged: if (abstractItem.inHiddenLayout) {
            root.hiddenLayout.currentIndex = abstractItem.index
        }
        onClicked: mouse => { abstractItem.clicked(mouse) }
        onPressed: mouse => {
            if (abstractItem.inHiddenLayout) {
                root.hiddenLayout.currentIndex = abstractItem.index
            }
            abstractItem.hideImmediately()
            abstractItem.pressed(mouse)
        }
        onPressAndHold: mouse => {
            if (mouse.button === Qt.LeftButton) {
                abstractItem.contextMenu(mouse)
            }
        }
        onWheel: wheel => {
            abstractItem.wheel(wheel);
            wheel.accepted = false;
        }
    }

    RowLayout {
        anchors.fill: abstractItem
        anchors.margins: 0
        spacing: 0

        FocusScope {
            id: iconContainer

            readonly property bool pressed: abstractItem.effectivePressed || mouseArea.containsPress

            onPressedChanged: {
                if (pressed) {
                    growAnimation.stop();
                    shrinkAnimation.start();
                } else if (!shrinkAnimation.running) {
                    growAnimation.start();
                }
            }

            activeFocusOnTab: !abstractItem.inHiddenLayout
            focus: true
            Accessible.name: abstractItem.text
            Accessible.description: abstractItem.subText
            Accessible.role: Accessible.Button
            Accessible.onPressAction: abstractItem.activated(Plasmoid.popupPosition(iconContainer, iconContainer.width/2, iconContainer.height/2));

            NumberAnimation {
                id: shrinkAnimation
                target: iconContainer
                property: "scale"
                to: 0.9
                duration: Kirigami.Units.veryShortDuration
                easing.type: Easing.OutQuart
                onFinished: {
                    if (!iconContainer.pressed) {
                        growAnimation.start();
                    }
                }
            }

            NumberAnimation {
                id: growAnimation
                target: iconContainer
                property: "scale"
                to: 1
                duration: Kirigami.Units.longDuration - shrinkAnimation.duration
                easing.type: Easing.OutCubic
            }

            Keys.onPressed: event => {
                switch (event.key) {
                    case Qt.Key_Space:
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                    case Qt.Key_Select:
                        abstractItem.activated(Qt.point(width/2, height/2));
                        break;
                    case Qt.Key_Menu:
                        abstractItem.contextMenu(null);
                        event.accepted = true;
                        break;
                }
            }

            property alias container: abstractItem
            property alias inVisibleLayout: abstractItem.inVisibleLayout
            readonly property int size: abstractItem.inVisibleLayout ? root.itemSize : 18

            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            implicitWidth: root.vertical && abstractItem.inVisibleLayout ? abstractItem.width : size
            implicitHeight: !root.vertical && abstractItem.inVisibleLayout ? abstractItem.height : size
        }

        PlasmaComponents3.Label {
            id: label
            visible: false
            text: ""
        }
    }
}
