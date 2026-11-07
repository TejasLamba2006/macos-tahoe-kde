import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../components" as Components
import "components/Tahoe" as Tahoe

Rectangle {
    id: wrapper
    anchors.fill: parent
    radius: 18
    color: "#e61c1c1e"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.14)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 132
            spacing: 7

            Tahoe.ConnectivityTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            GridLayout {
                Layout.preferredWidth: 142
                Layout.fillHeight: true
                columns: 2
                rows: 2
                columnSpacing: 5
                rowSpacing: 5

                Components.DndButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    glassEffect: true
                    roundedWidget: true
                    isLongButton: false
                    title: "Focus"
                }

                Components.ColorSchemeSwitcher {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    glassEffect: true
                    roundedWidget: true
                    noMargins: true
                    fullSizeIcon: true
                    title: "Dark Mode"
                    sourceColor: "transparent"
                }

                Components.CommandRun {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Stage Manager"
                    icon: "view-grid-symbolic"
                    command: "qdbus6 org.kde.KWin /Effects toggleOverview"
                    glassEffect: true
                    roundedWidget: true
                    isLongButton: false
                }

                Components.CommandRun {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Screen Mirroring"
                    icon: "video-display-symbolic"
                    command: "kscreen-doctor --info"
                    glassEffect: true
                    roundedWidget: true
                    isLongButton: false
                }
            }
        }

        Tahoe.SliderCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            title: "Display"
            icon: "display-brightness-symbolic"

            Components.BrightnessSlider {
                anchors.fill: parent
                canTogglePage: true
                glassEffect: false
                cornerRadius: 12
                mediumSizeSlider: true
            }
        }

        Tahoe.SliderCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            title: "Sound"
            icon: "audio-volume-high-symbolic"

            Components.Volume {
                anchors.fill: parent
                glassEffect: false
                cornerRadius: 12
                mediumSizeSlider: true
            }
        }

        Tahoe.NowPlayingCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 94
        }
    }
}
