import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    property string title: ""
    property string icon: ""
    default property alias content: contentHost.data

    implicitHeight: 68
    radius: 14
    color: Qt.rgba(1, 1, 1, 0.10)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Kirigami.Icon {
                width: 14
                height: 14
                source: card.icon
                color: "white"
            }

            Text {
                Layout.fillWidth: true
                text: card.title
                color: "white"
                font.family: "SF Pro Text"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Item {
            id: contentHost
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
