import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.draganddrop as DragDrop
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => { disconnectSource(source) }
        function exec(cmd) { executable.connectSource(cmd) }
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function isImageFile(name) {
        const lower = String(name || "").toLowerCase();
        return lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg")
            || lower.endsWith(".webp") || lower.endsWith(".gif") || lower.endsWith(".svg");
    }

    function iconForFile(name, isDir) {
        if (isDir) return "folder";
        const lower = String(name || "").toLowerCase();
        if (lower.endsWith(".pdf")) return "application-pdf";
        if (lower.endsWith(".zip") || lower.endsWith(".tar") || lower.endsWith(".gz") || lower.endsWith(".zst") || lower.endsWith(".7z")) return "package-x-generic";
        if (lower.endsWith(".mp4") || lower.endsWith(".mkv") || lower.endsWith(".mov") || lower.endsWith(".webm")) return "video-x-generic";
        if (lower.endsWith(".mp3") || lower.endsWith(".wav") || lower.endsWith(".flac") || lower.endsWith(".ogg") || lower.endsWith(".m4a")) return "audio-x-generic";
        if (lower.endsWith(".deb") || lower.endsWith(".rpm") || lower.endsWith(".pkg.tar.zst") || lower.endsWith(".appimage")) return "system-software-install";
        return "text-x-generic";
    }

    compactRepresentation: Item {
        id: compactRoot
        Layout.minimumWidth: height
        Layout.preferredWidth: height
        Layout.fillHeight: true

        Kirigami.Icon {
            width: Math.round(parent.height * 0.82)
            height: Math.round(parent.height * 0.82)
            anchors.centerIn: parent
            source: "@HOME@/.local/share/icons/MacTahoe/places/scalable/folder-download.svg"
            active: compactMouse.containsMouse
            smooth: true
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    executable.exec("xdg-open @HOME@/Downloads");
                } else {
                    root.expanded = !root.expanded;
                }
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: "Downloads"
            subText: "Click for recent stack · Middle-click to open Finder"
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: stackPopup
        Layout.minimumWidth: 388
        Layout.preferredWidth: 404
        Layout.minimumHeight: 330
        Layout.preferredHeight: 360
        collapseMarginsHint: true

        Loader {
            id: modelLoader
            active: root.expanded
            sourceComponent: FolderListModel {
                folder: "file://@HOME@/Downloads"
                showDirs: true
                showDotAndDotDot: false
                showHidden: false
                sortField: FolderListModel.Time
                sortReversed: false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: "Downloads"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: modelLoader.item ? `${Math.min(12, modelLoader.item.count)} recent` : ""
                    opacity: 0.65
                    font.pixelSize: 11
                }
            }

            GridView {
                id: stackGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: 92
                cellHeight: 98
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: modelLoader.item ? Math.min(12, modelLoader.item.count) : 0

                delegate: Item {
                    id: tile
                    required property int index
                    width: stackGrid.cellWidth
                    height: stackGrid.cellHeight

                    readonly property string fileName: modelLoader.item ? (modelLoader.item.get(index, "fileName") || "") : ""
                    readonly property string filePath: modelLoader.item ? (modelLoader.item.get(index, "filePath") || "") : ""
                    readonly property url fileUrl: modelLoader.item ? (modelLoader.item.get(index, "fileURL") || "") : ""
                    readonly property bool fileIsDir: modelLoader.item ? Boolean(modelLoader.item.get(index, "fileIsDir")) : false

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 12
                        color: tileHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: tileHover.hovered ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.09)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48

                                Image {
                                    id: imgThumb
                                    anchors.fill: parent
                                    visible: root.isImageFile(tile.fileName) && status === Image.Ready
                                    source: root.isImageFile(tile.fileName) ? tile.fileUrl : ""
                                    sourceSize: Qt.size(96, 96)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                Kirigami.Icon {
                                    anchors.fill: parent
                                    visible: !imgThumb.visible
                                    source: root.iconForFile(tile.fileName, tile.fileIsDir)
                                }
                            }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: tile.fileName
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                maximumLineCount: 2
                                wrapMode: Text.WrapAnywhere
                                elide: Text.ElideMiddle
                            }
                        }

                        DragDrop.DragArea {
                            anchors.fill: parent
                            delegate: parent
                            mimeData {
                                url: tile.fileUrl
                            }

                            TapHandler {
                                onTapped: {
                                    if (tile.filePath.length > 0) {
                                        executable.exec("xdg-open " + root.shellQuote(tile.filePath));
                                        root.expanded = false;
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            id: tileHover
                        }
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    visible: stackGrid.count === 0
                    iconName: "folder-download"
                    text: "Downloads is empty"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                icon.name: "system-file-manager"
                text: "Open in Finder"
                onClicked: {
                    executable.exec("xdg-open @HOME@/Downloads");
                    root.expanded = false;
                }
            }
        }
    }
}
