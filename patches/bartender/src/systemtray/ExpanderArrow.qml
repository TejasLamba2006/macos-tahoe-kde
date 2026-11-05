/*
    SPDX-License-Identifier: LGPL-2.0-or-later
    ponytail: macOS Bartender clean chevron pill in the menu bar
*/
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: tooltip

    readonly property int arrowAnimationDuration: 180
    property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    implicitWidth: vertical ? iconSize : 20
    implicitHeight: vertical ? 20 : iconSize
    activeFocusOnTab: true

    Accessible.name: subText
    Accessible.description: i18n("Show menu bar items")
    Accessible.role: Accessible.Button
    Accessible.onPressAction: systemTrayState.expanded = !systemTrayState.expanded

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Select:
            systemTrayState.expanded = !systemTrayState.expanded;
        }
    }

    subText: systemTrayState.expanded ? i18n("Hide menu bar items") : i18n("Show menu bar items")

    property bool wasExpanded
    property bool hovered: hoverHandler.hovered

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        onPressedChanged: {
            if (pressed) {
                tooltip.wasExpanded = systemTrayState.expanded;
            }
        }
        onTapped: (eventPoint, button) => {
            systemTrayState.expanded = !tooltip.wasExpanded;
            expandedRepresentation.hiddenLayout.currentIndex = -1;
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 18
        height: 18
        radius: 5
        color: systemTrayState.expanded ? Qt.rgba(1, 1, 1, 0.22) : (tooltip.hovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent")
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: systemTrayState.expanded ? "›" : "‹"
            color: "#ffffff"
            font.family: "SF Pro Text"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            opacity: systemTrayState.expanded ? 1.0 : 0.88
        }
    }
}
