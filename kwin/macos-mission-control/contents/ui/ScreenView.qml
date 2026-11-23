/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import org.kde.kwin.private.effects
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

FocusScope {
    id: screenView
    focus: true

    readonly property QtObject targetScreen: KWinComponents.SceneView.screen
    readonly property QtObject currentDesktop: KWinComponents.Workspace.currentDesktop

    KWinComponents.WindowModel {
        id: stackModel
    }

    KWinComponents.VirtualDesktopModel {
        id: desktopModel
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (effect.searchText !== "") {
                effect.searchText = "";
            } else {
                effect.deactivate();
            }
            event.accepted = true;
        }
    }
    Keys.priority: Keys.AfterItem
    Keys.forwardTo: [heap, searchField]

    Item {
        width: backgroundItem.width
        height: backgroundItem.height
        KWinComponents.DesktopBackground {
            id: backgroundItem
            activity: KWinComponents.Workspace.currentActivity
            desktop: screenView.currentDesktop
            outputName: screenView.targetScreen.name
            visible: false
        }
        FastBlur {
            anchors.fill: parent
            source: backgroundItem
            radius: 64
            opacity: effect.partialActivationFactor
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.68 * effect.partialActivationFactor
        color: Kirigami.Theme.backgroundColor

        TapHandler {
            onTapped: effect.deactivate()
        }
    }

    // Top Spaces / Virtual Desktops Bar + Search Field
    Column {
        id: topChrome
        anchors.top: parent.top
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Kirigami.Units.largeSpacing
        opacity: effect.partialActivationFactor
        z: 100

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: desktopModel

                Column {
                    id: spaceCard
                    required property KWinComponents.VirtualDesktop desktop
                    required property int index
                    readonly property bool isCurrent: screenView.currentDesktop === spaceCard.desktop
                    readonly property real previewH: Kirigami.Units.gridUnit * 4.5
                    readonly property real previewW: previewH * (screenView.targetScreen.geometry.width / Math.max(1, screenView.targetScreen.geometry.height))

                    spacing: 6

                    Item {
                        width: spaceCard.previewW
                        height: spaceCard.previewH
                        clip: true

                        KWinComponents.DesktopBackground {
                            id: spaceBg
                            width: screenView.targetScreen.geometry.width
                            height: screenView.targetScreen.geometry.height
                            activity: KWinComponents.Workspace.currentActivity
                            desktop: spaceCard.desktop
                            outputName: screenView.targetScreen.name
                            scale: spaceCard.previewH / Math.max(1, screenView.targetScreen.geometry.height)
                            transformOrigin: Item.TopLeft
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: spaceBg.width
                                    height: spaceBg.height
                                    radius: width / 24
                                }
                            }
                        }

                        Repeater {
                            model: KWinComponents.WindowFilterModel {
                                activity: KWinComponents.Workspace.currentActivity
                                desktop: spaceCard.desktop
                                screenName: screenView.targetScreen.name
                                windowModel: stackModel
                                windowType: ~KWinComponents.WindowFilterModel.Dock &
                                            ~KWinComponents.WindowFilterModel.Desktop &
                                            ~KWinComponents.WindowFilterModel.Notification &
                                            ~KWinComponents.WindowFilterModel.CriticalNotification
                            }
                            KWinComponents.WindowThumbnail {
                                wId: model.window.internalId
                                x: (model.window.x - screenView.targetScreen.geometry.x) * (spaceCard.previewH / Math.max(1, screenView.targetScreen.geometry.height))
                                y: (model.window.y - screenView.targetScreen.geometry.y) * (spaceCard.previewH / Math.max(1, screenView.targetScreen.geometry.height))
                                width: model.window.width * (spaceCard.previewH / Math.max(1, screenView.targetScreen.geometry.height))
                                height: model.window.height * (spaceCard.previewH / Math.max(1, screenView.targetScreen.geometry.height))
                                z: model.window.stackingOrder
                                visible: !model.window.minimized
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 8
                            color: "transparent"
                            border.width: spaceCard.isCurrent ? 2.5 : 1
                            border.color: spaceCard.isCurrent ? "#0A84FF" : Qt.rgba(1, 1, 1, 0.22)
                        }

                        DropArea {
                            anchors.fill: parent
                            onEntered: drag => { drag.accepted = true; }
                            onDropped: drop => {
                                drop.accepted = true;
                                if (drop.source && drop.source.desktops !== undefined) {
                                    drop.source.desktops = [spaceCard.desktop];
                                }
                            }
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                if (spaceCard.isCurrent) {
                                    effect.deactivate();
                                } else {
                                    KWinComponents.Workspace.currentDesktop = spaceCard.desktop;
                                }
                            }
                        }

                        Loader {
                            active: desktopModel.rowCount() > 1 && spaceHover.hovered
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 4
                            sourceComponent: Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: Qt.rgba(0.12, 0.12, 0.14, 0.88)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.25)
                                PC3.Label {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: "#FFFFFF"
                                    font.pixelSize: 13
                                }
                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: desktopModel.remove(spaceCard.index)
                                }
                            }
                        }

                        HoverHandler {
                            id: spaceHover
                        }
                    }

                    PC3.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: spaceCard.desktop.name
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.weight: spaceCard.isCurrent ? Font.DemiBold : Font.Normal
                    }
                }
            }

            // "+" Add Space card
            Item {
                readonly property real previewH: Kirigami.Units.gridUnit * 4.5
                readonly property real previewW: previewH * (screenView.targetScreen.geometry.width / Math.max(1, screenView.targetScreen.geometry.height))
                width: previewW
                height: previewH

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.18)

                    PC3.Label {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 28
                        color: "#FFFFFF"
                    }
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: desktopModel.create(desktopModel.rowCount())
                }
            }
        }

        PlasmaExtras.SearchField {
            id: searchField
            anchors.horizontalCenter: parent.horizontalCenter
            width: Kirigami.Units.gridUnit * 18
            text: effect.searchText
            onTextChanged: {
                effect.searchText = text;
                heap.resetSelected();
            }
        }
    }

    // Main Mission Control Window Heap with MRU Sizing
    WindowHeap {
        id: heap
        anchors {
            top: topChrome.bottom
            topMargin: Kirigami.Units.largeSpacing
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: Kirigami.Units.largeSpacing * 1.5
        }
        focus: true
        padding: Kirigami.Units.largeSpacing
        animationDuration: effect.animationDuration
        animationEnabled: effect.activated
        organized: effect.activated

        model: KWinComponents.WindowFilterModel {
            activity: KWinComponents.Workspace.currentActivity
            desktop: screenView.currentDesktop
            screenName: screenView.targetScreen.name
            windowModel: stackModel
            filter: effect.searchText
            minimizedWindows: true
            windowType: ~KWinComponents.WindowFilterModel.Dock &
                        ~KWinComponents.WindowFilterModel.Desktop &
                        ~KWinComponents.WindowFilterModel.Notification &
                        ~KWinComponents.WindowFilterModel.CriticalNotification
        }

        delegate: MacOSWindowHeapDelegate {
            windowHeap: heap
            contentItemParent: screenView
            partialActivationFactor: effect.partialActivationFactor
            gestureInProgress: false
            onDownGestureTriggered: window.closeWindow()
        }

        onActivated: effect.deactivate()
    }
}
