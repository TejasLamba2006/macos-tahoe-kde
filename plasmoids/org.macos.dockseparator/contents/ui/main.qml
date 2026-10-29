import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    Layout.minimumWidth: 10
    Layout.preferredWidth: 10
    Layout.maximumWidth: 10
    Layout.fillHeight: true

    Rectangle {
        width: 1
        height: Math.round(parent.height * 0.68)
        anchors.centerIn: parent
        color: "#ffffff"
        opacity: 0.25
    }
}
