import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

Item {
    id: root
    property QtObject dashWindow: null
    readonly property bool useCustomButtonImage: (Plasmoid.configuration.useCustomButtonImage && Plasmoid.configuration.customButtonImage.length != 0)

    Layout.minimumWidth: height
    Layout.preferredWidth: height
    Layout.fillHeight: true

    Kirigami.Icon {
        id: buttonIcon
        width: Math.round(parent.height * 0.78)
        height: Math.round(parent.height * 0.78)
        anchors.centerIn: parent
        source: useCustomButtonImage ? Plasmoid.configuration.customButtonImage : "@HOME@/.local/share/icons/MacTahoe/apps/scalable/appgrid.svg"
        active: mouseArea.containsMouse
        smooth: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            dashWindow.visible = !dashWindow.visible;
        }
    }

    Component.onCompleted: {
        dashWindow = Qt.createQmlObject("MenuRepresentation {}", root);
        plasmoid.activated.connect(function() {
            dashWindow.visible = !dashWindow.visible;
        });
    }
}
