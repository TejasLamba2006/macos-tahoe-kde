import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: height
    Layout.preferredWidth: height
    Layout.fillHeight: true

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => { disconnectSource(source) }
        function exec(cmd) { executable.connectSource(cmd) }
    }

    Kirigami.Icon {
        width: Math.round(parent.height * 0.82)
        height: Math.round(parent.height * 0.82)
        anchors.centerIn: parent
        source: "@HOME@/.local/share/icons/MacTahoe/places/scalable/folder-download.svg"
        active: mouseArea.containsMouse
        smooth: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: executable.exec("xdg-open @HOME@/Downloads")
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: "Downloads"
    }
}
