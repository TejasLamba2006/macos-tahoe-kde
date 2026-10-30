/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Dynamic Island "Dropover / Alcove" File Holding Shelf + 1-Click AirDrop (LocalSend / KDE Connect) + Continuity Camera (#1 & #7).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var core: null
    property string savedShelf: "[]"
    signal shelfEdited(string json)

    property bool dragging: false
    property bool dropping: false
    readonly property bool interacting: visible && dragging
    readonly property bool holdOpen: visible && (dragging || dropping)
    readonly property bool asking: false
    readonly property bool tall: visible && (items.length > 2 || activePorts.length > 0 || handoffUrl !== "")

    property var items: []
    property var activePorts: []
    property string handoffUrl: ""
    property var dragger: null
    property bool camRunning: false

    Component.onCompleted: {
        loadShelf();
        pollPortsAndHandoff();
    }
    onSavedShelfChanged: loadShelf()

    Timer {
        interval: 2500
        running: page.visible
        repeat: true
        onTriggered: page.pollPortsAndHandoff()
    }

    function pollPortsAndHandoff(): void {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "file:///run/user/1000/macos-ports-status.json", true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                if (!xhr.responseText) return;
                try {
                    const data = JSON.parse(xhr.responseText);
                    if (Array.isArray(data.ports)) page.activePorts = data.ports;
                    page.handoffUrl = String(data.handoffUrl || "");
                } catch (e) {}
            }
        };
        xhr.send();
    }

    function killPort(pid: int, port: int): void {
        if (!core) return;
        core.startDetached("@HOME@/.local/bin/macos-port-ctl", ["kill", String(pid), String(port)]);
        activePorts = activePorts.filter(p => p.port !== port);
    }

    function openHandoffUrl(): void {
        if (!handoffUrl) return;
        Qt.openUrlExternally(handoffUrl);
        if (core) {
            core.startDetached("@HOME@/.local/bin/macos-port-ctl", ["open-handoff", handoffUrl]);
        }
    }

    function loadShelf(): void {
        try {
            const parsed = JSON.parse(savedShelf || "[]");
            if (Array.isArray(parsed)) items = parsed;
        } catch (e) {
            items = [];
        }
    }

    function saveShelf(): void {
        shelfEdited(JSON.stringify(items));
    }

    function addUrls(urls: var): void {
        if (!urls || urls.length === 0) return;
        const next = items.slice();
        for (let i = 0; i < urls.length; ++i) {
            const raw = String(urls[i]);
            const path = raw.replace(/^file:\/\//, "");
            const decoded = decodeURIComponent(path);
            const parts = decoded.split("/");
            const name = parts[parts.length - 1] || decoded;
            if (!next.some(x => x.path === decoded)) {
                next.unshift({ path: decoded, name: name, url: raw });
            }
        }
        items = next.slice(0, 12);
        saveShelf();
    }

    function removePath(path: string): void {
        items = items.filter(x => x.path !== path);
        saveShelf();
    }

    function clearAll(): void {
        items = [];
        saveShelf();
    }

    function dragOut(localPath: string): void {
        if (dragging || core === null || typeof core.fileDrag !== "function") return;
        if (dragger === null) dragger = core.fileDrag();
        if (dragger === null) return;
        dragging = dragger.start(page, localPath, "application-octet-stream");
    }

    Connections {
        target: page.dragger
        ignoreUnknownSignals: true
        function onFinished(dropped) { page.dragging = false; }
    }

    function airDropFile(localPath: string): void {
        if (!core) return;
        core.startDetached("localsend", [localPath]);
    }

    function kdeConnectShare(localPath: string): void {
        if (!core) return;
        core.startDetached("@HOME@/.local/bin/macos-phone-share", [localPath]);
    }

    function toggleContinuityCamera(facing: string): void {
        if (!core) return;
        if (camRunning && facing === "") {
            core.startDetached("@HOME@/.local/bin/macos-continuity-camera", ["stop"]);
            camRunning = false;
        } else {
            core.startDetached("@HOME@/.local/bin/macos-continuity-camera", ["start", facing || "back"]);
            camRunning = true;
        }
    }

    DropArea {
        anchors.fill: parent
        onEntered: drag => {
            if (drag.hasUrls) {
                drag.accept(Qt.CopyAction);
                page.dropping = true;
            }
        }
        onExited: page.dropping = false
        onDropped: drop => {
            page.dropping = false;
            if (drop.hasUrls) {
                page.addUrls(drop.urls);
                drop.acceptProposedAction();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Continuity Camera Bar (#7)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 10
            color: page.camRunning ? Qt.rgba(0.20, 0.78, 0.35, 0.22) : page.theme.faint
            border.width: 1
            border.color: page.camRunning ? page.theme.live : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Kirigami.Icon {
                    source: "camera-video-symbolic"
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    color: page.camRunning ? page.theme.live : page.theme.text
                }
                Text {
                    Layout.fillWidth: true
                    text: page.camRunning ? "Continuity Camera (/dev/video9 Live)" : "Continuity Camera (Phone Webcam)"
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PillButton {
                    theme: page.theme
                    text: page.camRunning ? "Stop" : "Rear Cam"
                    primary: page.camRunning
                    onClicked: page.toggleContinuityCamera(page.camRunning ? "" : "back")
                }
                PillButton {
                    theme: page.theme
                    text: "Front"
                    visible: !page.camRunning
                    onClicked: page.toggleContinuityCamera("front")
                }
            }
        }

        // Handoff Universal Clipboard & URL Banner (#5)
        Rectangle {
            visible: page.handoffUrl !== ""
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 10
            color: Qt.rgba(0.24, 0.56, 1.0, 0.18)
            border.width: 1
            border.color: page.theme.blue

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Kirigami.Icon {
                    source: "internet-web-browser-symbolic"
                    Layout.preferredWidth: 15
                    Layout.preferredHeight: 15
                    color: page.theme.blue
                }
                Text {
                    Layout.fillWidth: true
                    text: "Handoff: " + page.handoffUrl.replace(/^https?:\/\//, "")
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PillButton {
                    theme: page.theme
                    text: "Open Link"
                    primary: true
                    onClicked: page.openHandoffUrl()
                }
            }
        }

        // Live Localhost Dev Ports Manager (#10)
        ColumnLayout {
            visible: page.activePorts.length > 0
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "Active Localhost Dev Ports (" + page.activePorts.length + ")"
                color: page.theme.subText
                font.pointSize: page.theme.fontTiny
                font.weight: Font.DemiBold
            }

            Repeater {
                model: page.activePorts.slice(0, 4)
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 8
                    color: page.theme.faint

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 6

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            color: page.theme.live
                        }
                        Text {
                            text: ":" + modelData.port
                            color: page.theme.live
                            font.pointSize: page.theme.fontSmall
                            font.weight: Font.Bold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name + " (PID " + modelData.pid + ")"
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            elide: Text.ElideRight
                        }
                        PillButton {
                            theme: page.theme
                            text: "Open"
                            onClicked: Qt.openUrlExternally(modelData.url)
                        }
                        PillButton {
                            theme: page.theme
                            text: "Kill"
                            onClicked: page.killPort(modelData.pid, modelData.port)
                        }
                    }
                }
            }
        }

        // Shelf Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: "Dropover File Shelf (" + page.items.length + ")"
                color: page.theme.subText
                font.pointSize: page.theme.fontTiny
                font.weight: Font.DemiBold
            }
            PillButton {
                visible: page.items.length > 0
                theme: page.theme
                text: "Clear"
                onClicked: page.clearAll()
            }
        }

        // Empty Drop Zone
        Rectangle {
            visible: page.items.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: 74
            radius: 12
            color: page.dropping ? Qt.rgba(0.25, 0.55, 1.0, 0.22) : page.theme.faint
            border.width: 1
            border.color: page.dropping ? page.theme.blue : page.theme.track

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    source: "folder-download-symbolic"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    color: page.theme.subText
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Drag & drop any files into the Notch to hold or AirDrop"
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall
                }
            }
        }

        // Held Files List (Drag out or 1-Click AirDrop)
        ListView {
            visible: page.items.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: Math.min(150, page.items.length * 36)
            clip: true
            spacing: 4
            model: page.items

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 32
                radius: 8
                color: rowHover.hovered ? page.theme.control : page.theme.faint

                HoverHandler { id: rowHover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 6

                    Kirigami.Icon {
                        source: "text-x-generic-symbolic"
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        color: page.theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        elide: Text.ElideMiddle

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.OpenHandCursor
                            property point pressPos: Qt.point(0, 0)
                            onPressed: mouse => { pressPos = Qt.point(mouse.x, mouse.y); }
                            onPositionChanged: mouse => {
                                if (Math.abs(mouse.x - pressPos.x) + Math.abs(mouse.y - pressPos.y) > 6) {
                                    page.dragOut(modelData.path);
                                }
                            }
                            onClicked: Qt.openUrlExternally("file://" + modelData.path)
                        }
                    }

                    PillButton {
                        theme: page.theme
                        text: "AirDrop"
                        onClicked: page.airDropFile(modelData.path)
                    }

                    PillButton {
                        theme: page.theme
                        text: "Phone"
                        onClicked: page.kdeConnectShare(modelData.path)
                    }

                    IconButton {
                        iconName: "window-close-symbolic"
                        iconSize: 11
                        implicitWidth: 20
                        implicitHeight: 20
                        color: page.theme.subText
                        hoverColor: page.theme.faint
                        onClicked: page.removePath(modelData.path)
                    }
                }
            }
        }
    }
}
