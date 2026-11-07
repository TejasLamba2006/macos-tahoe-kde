import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami

Rectangle {
    id: control

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool checked: false
    property bool interactive: true
    signal triggered()

    implicitWidth: 112
    implicitHeight: 62
    radius: 14
    color: checked ? "#0A84FF" : Qt.rgba(1, 1, 1, 0.10)
    opacity: enabled ? 1 : 0.45

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 9

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 17
            color: control.checked ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12)

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: control.icon
                color: "white"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: control.title
                color: "white"
                font.family: "SF Pro Text"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: control.subtitle
                color: Qt.rgba(1, 1, 1, 0.62)
                font.family: "SF Pro Text"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    TapHandler {
        enabled: control.enabled && control.interactive
        onPressedChanged: control.scale = pressed ? 0.97 : 1
        onTapped: control.triggered()
    }
}
