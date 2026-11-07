/*
    SPDX-License-Identifier: LGPL-2.0-or-later
    ponytail: macOS Bartender floating frosted dark pill bar (zero KDE chrome)
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

Item {
    id: popup

    readonly property bool showingGrid: systemTrayState.activeApplet === null
    readonly property bool showingNotifications: !!systemTrayState.activeApplet?.fullRepresentationItem?.historyModel
    readonly property int pillW: Math.max(64, root.hiddenModel.count * 32 + 16)
    readonly property int pillH: 36

    Layout.minimumWidth: showingGrid ? pillW : Kirigami.Units.gridUnit * 20
    Layout.preferredWidth: showingGrid ? pillW : Kirigami.Units.gridUnit * 20
    Layout.maximumWidth: showingGrid ? pillW : Kirigami.Units.gridUnit * 24

    Layout.minimumHeight: showingGrid ? pillH : showingNotifications ? 620 : Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: showingGrid ? pillH : showingNotifications ? 620 : Kirigami.Units.gridUnit * 18
    Layout.maximumHeight: showingGrid ? pillH : showingNotifications ? 800 : Kirigami.Units.gridUnit * 24

    property alias hiddenLayout: hiddenItemsView.layout
    property alias plasmoidContainer: container

    // macOS Bartender dark glass pill plate (covers popup margins cleanly)
    Rectangle {
        visible: popup.showingGrid
        anchors.fill: parent
        anchors.margins: -6
        radius: 10
        color: "#ea1c1c1e"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    PlasmaExtras.PlasmoidHeading {
        id: plasmoidHeading
        visible: !popup.showingGrid
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: !popup.showingGrid ? (trayHeading.height + bottomPadding + container.headingHeight) : 0
    }

    ColumnLayout {
        id: expandedRepresentation
        anchors.fill: parent
        spacing: popup.showingGrid ? 0 : plasmoidHeading.bottomPadding

        RowLayout {
            id: trayHeading
            visible: !popup.showingGrid
            Layout.fillWidth: true

            PlasmaComponents.ToolButton {
                id: backButton
                visible: !popup.showingGrid && (popup.hiddenLayout.itemCount > 0)
                icon.name: mirrored ? "go-previous-symbolic-rtl" : "go-previous-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18nc("@action:button", "Go Back")
                onClicked: if (typeof systemTrayState.activeApplet?.backAction !== "undefined" && systemTrayState.activeApplet.backAction.enabled) {
                    systemTrayState.activeApplet?.backAction.trigger()
                } else {
                    systemTrayState.setActiveApplet(null)
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                leftPadding: backButton.visible ? 0 : Kirigami.Units.largeSpacing
                level: 1
                text: systemTrayState.activeApplet ? systemTrayState.activeApplet.plasmoid.title : ""
                maximumLineCount: 1
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            PlasmaComponents.ToolButton {
                id: pinButton
                visible: false
                checkable: true
                checked: Plasmoid.configuration.pin
                onToggled: Plasmoid.configuration.pin = checked
            }
        }

        HiddenItemsView {
            id: hiddenItemsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 0
            visible: popup.showingGrid

            onVisibleChanged: {
                if (visible) {
                    layout.forceActiveFocus();
                    systemTrayState.oldVisualIndex = systemTrayState.newVisualIndex = -1;
                }
            }
        }

        PlasmoidPopupsContainer {
            id: container
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !popup.showingGrid
            Layout.topMargin: mergeHeadings ? 0 : dialog.topPadding

            onVisibleChanged: {
                if (visible) {
                    forceActiveFocus();
                }
            }
        }
    }

    PlasmaExtras.PlasmoidHeading {
        id: plasmoidFooter
        position: PlasmaComponents.ToolBar.Footer
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        visible: !popup.showingGrid && container.appletHasFooter
        height: container.footerHeight
        z: -9999
    }
}
