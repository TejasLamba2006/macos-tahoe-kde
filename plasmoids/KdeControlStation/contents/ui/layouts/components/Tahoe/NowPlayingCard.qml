import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../components" as Components

Rectangle {
    id: card

    implicitHeight: 94
    radius: 16
    color: Qt.rgba(1, 1, 1, 0.10)

    Components.MediaPlayer {
        anchors.fill: parent
        anchors.margins: 4
        glassEffect: false
        roundedWidget: true
    }
}
