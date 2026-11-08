import QtQml 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls

import org.kde.plasma.plasmoid
//import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami 

import "../lib" as Lib
import "../js/colorType.js" as ColorType

Lib.CardButton {
    id: screenshotBtn

    visible: root.showScreenshot

    property bool mini: false 

    Layout.fillHeight: true
    Layout.fillWidth: true
    title: i18n("Screenshot")
    property string command: root.screenshotCommand ?? "spectacle"
    shouldStickIconSize: true
    Kirigami.Icon {
        anchors.fill: parent
        anchors.centerIn: parent
        source: "camera-photo-symbolic"
    }

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.onPressAction: captureMenu.open()
    Keys.onReturnPressed: captureMenu.open()
    Keys.onEnterPressed: captureMenu.open()
    Keys.onSpacePressed: captureMenu.open()
    onClicked: captureMenu.open()

    function launch(cmd) {
        if (root.hideWidgetBeforeScreenshot) {
            root.expanded = false;
        }
        // Native click/region selectors wait for user input, not a guessed popup fade delay.
        executable.exec(cmd);
    }

    Menu {
        id: captureMenu
        objectName: "captureMenu"
        parent: screenshotBtn
        x: 0
        y: screenshotBtn.height
        title: i18n("Screen Capture")

        MenuItem {
            text: i18n("Capture Rectangular Region")
            icon.name: "edit-select-all"
            onTriggered: screenshotBtn.launch("spectacle -r -w")
        }
        MenuItem {
            text: i18n("Capture Window")
            icon.name: "window"
            onTriggered: screenshotBtn.launch("spectacle -u -w")
        }
        MenuItem {
            text: i18n("Capture All Screens (Click to Capture)")
            icon.name: "video-display"
            onTriggered: screenshotBtn.launch("spectacle -f -w")
        }
        MenuSeparator {}
        MenuItem {
            text: i18n("Record Rectangular Region")
            icon.name: "media-record"
            onTriggered: screenshotBtn.launch("spectacle -R region")
        }
        MenuItem {
            text: i18n("Record Window")
            icon.name: "media-record"
            onTriggered: screenshotBtn.launch("spectacle -R window")
        }
        MenuItem {
            text: i18n("Record Screen")
            icon.name: "media-record"
            onTriggered: screenshotBtn.launch("spectacle -R screen")
        }
        MenuSeparator {}
        MenuItem {
            text: i18n("Open Spectacle")
            icon.name: "spectacle"
            onTriggered: screenshotBtn.launch(screenshotBtn.command === "spectacle" ? "spectacle -l" : screenshotBtn.command || "spectacle -l")
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: { 
            disconnectSource(sourceName)
        }
        
        function exec(cmd) {
            connectSource(cmd)
        }
    }
}
