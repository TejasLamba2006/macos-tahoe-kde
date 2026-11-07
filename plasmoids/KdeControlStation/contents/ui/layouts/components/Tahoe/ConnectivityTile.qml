import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../components" as Components

Rectangle {
    id: card

    implicitHeight: 132
    radius: 16
    color: Qt.rgba(1, 1, 1, 0.10)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 5

        Components.NetworkBtn {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            isLongButton: true
            glassEffect: false
            roundedWidget: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            Components.BluetoothBtn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glassEffect: false
                roundedWidget: true
                noMargins: true
                fullSizeIcon: true
                title: ""
                showTitle: false
                sourceColor: "transparent"
            }

            Components.KDEConnect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glassEffect: false
                roundedWidget: true
                noMargins: true
                isLongButton: true
                title: "AirDrop"
            }
        }
    }
}
