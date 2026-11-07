import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.battery as Battery

ColumnLayout {
    id: widgets
    spacing: 10
    implicitHeight: 290

    property var settings: ({})
    readonly property url backendRoot: StandardPaths.writableLocation(StandardPaths.GenericDataLocation)
        + "/plasma/plasmoids/org.phobby.dynamicisland/contents/ui/backend/"
    readonly property var calendar: calendarLoader.item
    readonly property var weather: weatherLoader.item
    readonly property var upcoming: calendar && calendar.loaded
        ? calendar.events.filter(e => e.end > Date.now()).slice(0, 2) : []
    readonly property bool calendarError: calendar && Object.keys(calendar.errors).length > 0

    function readSettings() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || (xhr.status !== 0 && xhr.status !== 200)) return;
            const config = {};
            for (const line of xhr.responseText.split("\n")) {
                if (line.startsWith("calendarSources=")) config.calendarSources = line.slice(16);
                if (line.startsWith("weatherLocation=")) config.weatherLocation = line.slice(16);
            }
            widgets.settings = config;
        };
        xhr.open("GET", StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
                 + "/plasma-org.kde.plasma.desktop-appletsrc");
        xhr.send();
    }

    Component.onCompleted: readSettings()
    Timer { interval: 60000; repeat: true; running: widgets.visible; onTriggered: widgets.readSettings() }

    Loader {
        id: calendarLoader
        source: widgets.backendRoot + "IcsCalendarBackend.qml"
        onLoaded: item.sourcesJson = Qt.binding(() => widgets.settings.calendarSources || "[]")
    }
    Loader {
        id: weatherLoader
        source: widgets.backendRoot + "WeatherBackend.qml"
        onLoaded: item.location = Qt.binding(() => widgets.settings.weatherLocation || "")
    }
    Battery.BatteryControlModel { id: battery }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 146
        radius: 16
        color: "#ee1c1c1e"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6
            Text {
                text: Qt.formatDate(new Date(), "dddd").toUpperCase()
                color: "#ff453a"
                font.family: "SF Pro Text"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: Qt.formatDate(new Date(), "MMMM d")
                color: "white"
                font.family: "SF Pro Display"
                font.pixelSize: 22
                font.weight: Font.Bold
            }
            Repeater {
                model: widgets.upcoming
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Rectangle { width: 3; height: 25; radius: 1.5; color: modelData.color || "#0a84ff" }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: "white"
                        font.family: "SF Pro Text"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.allDay ? qsTr("All day") : Qt.formatTime(new Date(modelData.start), "h:mm AP")
                        color: "#b3b3ba"
                        font.pixelSize: 11
                    }
                }
            }
            Text {
                visible: widgets.upcoming.length === 0
                text: !widgets.calendar || !widgets.calendar.loaded ? qsTr("Loading calendar…")
                    : widgets.calendarError ? qsTr("Calendar unavailable — check Island settings")
                    : qsTr("No upcoming events")
                color: "#b3b3ba"
                font.pixelSize: 12
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 112
            radius: 16
            color: "#ee1c1c1e"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                Text {
                    Layout.fillWidth: true
                    text: widgets.weather ? widgets.weather.placeName : qsTr("Weather")
                    color: "white"
                    font.family: "SF Pro Text"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    text: widgets.weather && widgets.weather.ready ? widgets.weather.degrees(widgets.weather.temperature) : "—"
                    color: "white"
                    font.family: "SF Pro Display"
                    font.pixelSize: 32
                }
                Text {
                    Layout.fillWidth: true
                    text: widgets.weather && widgets.weather.ready
                        ? widgets.weather.describe(widgets.weather.current.kind, widgets.weather.current.day)
                        : qsTr("Weather unavailable")
                    color: "#b3b3ba"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 112
            radius: 16
            color: "#ee1c1c1e"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                Text { text: qsTr("Batteries"); color: "white"; font.family: "SF Pro Text"; font.pixelSize: 12 }
                Text {
                    text: battery.hasBatteries ? battery.percent + "%" : "—"
                    color: "white"
                    font.family: "SF Pro Display"
                    font.pixelSize: 32
                }
                Text {
                    text: battery.hasBatteries ? (battery.pluggedIn ? qsTr("Power connected") : qsTr("On battery")) : qsTr("No battery")
                    color: "#b3b3ba"
                    font.pixelSize: 11
                }
            }
        }
    }
}
