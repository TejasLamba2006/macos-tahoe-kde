/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox

    currentIndex: (instantiator.object as AppSwitcherDialog)?.currentIndex ?? currentIndex

    Instantiator {
        id: instantiator
        active: tabBox.visible
        delegate: AppSwitcherDialog {}
    }

    component AppSwitcherDialog: PlasmaCore.Dialog {
        property alias currentIndex: icons.currentIndex
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        visible: tabBox.visible
        flags: Qt.ToolTip | Qt.X11BypassWindowManagerHint
        x: tabBox.screenGeometry.x + Math.round((tabBox.screenGeometry.width - hudCard.width) * 0.5)
        y: tabBox.screenGeometry.y + Math.round((tabBox.screenGeometry.height - hudCard.height) * 0.5)

        mainItem: Rectangle {
            id: hudCard
            radius: 22
            color: Qt.rgba(0.11, 0.11, 0.13, 0.86)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)

            readonly property int iconCell: 92
            readonly property int iconDraw: 68
            readonly property int maxCols: Math.max(1, Math.floor((tabBox.screenGeometry.width * 0.86 - 40) / iconCell))
            readonly property int cols: Math.max(1, Math.min(tabBox.model.rowCount(), maxCols))
            readonly property int rows: Math.max(1, Math.ceil(tabBox.model.rowCount() / maxCols))

            implicitWidth: cols * iconCell + 40
            implicitHeight: rows * iconCell + 56
            width: implicitWidth
            height: implicitHeight

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 18
                anchors.bottomMargin: 12
                spacing: 8

                GridView {
                    id: icons
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: hudCard.cols * hudCard.iconCell
                    implicitHeight: hudCard.rows * hudCard.iconCell
                    width: implicitWidth
                    height: implicitHeight
                    cellWidth: hudCard.iconCell
                    cellHeight: hudCard.iconCell
                    currentIndex: tabBox.currentIndex
                    focus: true
                    flow: GridView.LeftToRight
                    keyNavigationWraps: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 90

                    model: tabBox.model

                    highlight: Rectangle {
                        width: hudCard.iconCell - 8
                        height: hudCard.iconCell - 8
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1.5
                        border.color: Qt.rgba(1, 1, 1, 0.28)
                    }

                    delegate: Item {
                        id: cell
                        required property int index
                        required property var model
                        readonly property string caption: model.caption || ""

                        width: hudCard.iconCell
                        height: hudCard.iconCell

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: hudCard.iconDraw
                            height: hudCard.iconDraw
                            source: cell.model.icon
                            active: cell.index === icons.currentIndex
                            smooth: true
                        }

                        TapHandler {
                            onSingleTapped: {
                                if (cell.index === icons.currentIndex) {
                                    icons.model.activate(cell.index);
                                    return;
                                }
                                icons.currentIndex = cell.index;
                            }
                            onDoubleTapped: icons.model.activate(cell.index)
                        }
                    }
                }

                PlasmaComponents3.Label {
                    id: captionLabel
                    Layout.fillWidth: true
                    text: icons.currentItem ? (icons.currentItem as Item).caption : ""
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideMiddle
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Connections {
                target: tabBox
                function onCurrentIndexChanged() {
                    icons.currentIndex = tabBox.currentIndex;
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Up) {
                    icons.moveCurrentIndexUp();
                } else if (event.key === Qt.Key_Down) {
                    icons.moveCurrentIndexDown();
                } else if (event.key === Qt.Key_Left) {
                    icons.moveCurrentIndexLeft();
                } else if (event.key === Qt.Key_Right) {
                    icons.moveCurrentIndexRight();
                }
            }
        }

        onSceneGraphError: () => {}
    }
}
