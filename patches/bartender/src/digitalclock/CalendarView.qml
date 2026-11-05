/*
    SPDX-License-Identifier: GPL-2.0-or-later
    ponytail: macOS Sequoia / Tahoe Calendar & Agenda popup for top menu bar clock
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.digitalclock
import org.kde.kirigami as Kirigami
import org.kde.plasma.clock

PlasmaExtras.Representation {
    id: calendar

    readonly property var appletInterface: root

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    Layout.minimumWidth: 500
    Layout.preferredWidth: 500
    Layout.maximumWidth: 500

    Layout.minimumHeight: 280
    Layout.preferredHeight: 280
    Layout.maximumHeight: 280

    collapseMarginsHint: true

    // Dummy monthView alias so digitalclock/main.qml onExpandedChanged compatibility holds
    readonly property QtObject monthView: QtObject {
        readonly property QtObject viewHeader: QtObject {
            readonly property QtObject configureButton: QtObject {
                function forceActiveFocus(reason) {}
            }
        }
        function resetToToday() {
            const n = new Date();
            calendar.today = n;
            calendar.viewYear = n.getFullYear();
            calendar.viewMonth = n.getMonth();
            calendar.selectedDate = new Date(n.getFullYear(), n.getMonth(), n.getDate());
        }
    }

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property date selectedDate: new Date(today.getFullYear(), today.getMonth(), today.getDate())

    readonly property int firstDow: Plasmoid.configuration.firstDayOfWeek > -1
        ? Plasmoid.configuration.firstDayOfWeek
        : Qt.locale().firstDayOfWeek

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayShortSun: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var weekdayShortMon: ["M", "T", "W", "T", "F", "S", "S"]
    readonly property var weekdayShort: firstDow === 1 ? weekdayShortMon : weekdayShortSun

    function isWeekendCol(col) {
        return firstDow === 1 ? (col === 5 || col === 6) : (col === 0 || col === 6);
    }

    property var monthDays: []
    function rebuildMonthDays() {
        const firstOfMonth = new Date(viewYear, viewMonth, 1);
        let offset = firstOfMonth.getDay() - firstDow;
        if (offset < 0) offset += 7;
        const lastDay = new Date(viewYear, viewMonth + 1, 0).getDate();
        const out = new Array(42);
        for (let i = 0; i < 42; i++) {
            const day = i - offset + 1;
            out[i] = (day < 1 || day > lastDay) ? 0 : day;
        }
        monthDays = out;
    }

    onViewYearChanged: { rebuildMonthDays(); syncBackend(); rebuildEvents(); }
    onViewMonthChanged: { rebuildMonthDays(); syncBackend(); rebuildEvents(); }
    onSelectedDateChanged: rebuildEvents()

    PlasmaCalendar.EventPluginsManager {
        id: eventPluginsManager
        enabledPlugins: Plasmoid.configuration.enabledCalendarPlugins
        onPluginsChanged: rebuildTimer.restart()
    }

    PlasmaCalendar.Calendar {
        id: calendarBackend
        days: 7
        weeks: 6
        firstDayOfWeek: calendar.firstDow
        today: calendar.today
        Component.onCompleted: {
            daysModel.setPluginsManager(eventPluginsManager);
        }
    }

    PlasmaCalendar.Calendar {
        id: nextMonthBackend
        days: 7
        weeks: 6
        firstDayOfWeek: calendar.firstDow
        today: calendar.today
        Component.onCompleted: {
            daysModel.setPluginsManager(eventPluginsManager);
            var d = new Date(calendar.viewYear, calendar.viewMonth + 1, 1);
            goToYearAndMonth(d.getFullYear(), d.getMonth() + 1);
        }
    }

    function syncBackend() {
        calendarBackend.goToYearAndMonth(viewYear, viewMonth + 1);
        var d1 = new Date(viewYear, viewMonth + 1, 1);
        nextMonthBackend.goToYearAndMonth(d1.getFullYear(), d1.getMonth() + 1);
    }

    Connections {
        target: calendarBackend.daysModel
        function onAgendaUpdated() { rebuildTimer.restart(); }
    }
    Connections {
        target: nextMonthBackend.daysModel
        function onAgendaUpdated() { rebuildTimer.restart(); }
    }

    Timer {
        id: rebuildTimer
        interval: 100
        repeat: false
        onTriggered: calendar.rebuildEvents()
    }

    ListModel {
        id: eventsModel
    }

    function pillColorFor(ev) {
        var c = ev.eventColor ? ev.eventColor.toString() : "";
        if (c.length > 0 && c !== "#000000" && c !== "#00000000") return c;
        if (ev.eventType === "Holiday") return "#FF453A";
        if (ev.eventType === "Todo") return "#FF9F0A";
        return "#0A84FF";
    }

    function rebuildEvents() {
        eventsModel.clear();
        var baseDate = calendar.selectedDate;
        var startDay = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate());
        var endDay = new Date(startDay.getTime() + 14 * 86400000);
        var seen = {};
        var todayItems = [];
        var upcomingItems = [];

        for (var d = new Date(startDay); d < endDay; d = new Date(d.getTime() + 86400000)) {
            var dm = (d.getFullYear() === viewYear && d.getMonth() === viewMonth)
                ? calendarBackend.daysModel
                : nextMonthBackend.daysModel;
            var raw = dm.eventsForDate(d);
            if (!raw || raw.length === 0) continue;

            var list = [];
            for (var i = 0; i < raw.length; i++) list.push(raw[i]);
            list.sort(function(a, b) {
                if (a.isAllDay && !b.isAllDay) return -1;
                if (!a.isAllDay && b.isAllDay) return 1;
                return a.startDateTime.getTime() - b.startDateTime.getTime();
            });

            for (var j = 0; j < list.length; j++) {
                var ev = list[j];
                var key = ev.title + "|" + ev.startDateTime.getTime();
                if (seen[key]) continue;
                seen[key] = true;

                var isSel = d.getTime() === startDay.getTime();
                var tLabel = ev.isAllDay
                    ? (isSel ? "All-day" : Qt.formatDateTime(d, "ddd, MMM d"))
                    : (isSel ? Qt.formatDateTime(ev.startDateTime, "h:mm AP") : Qt.formatDateTime(d, "ddd d") + " · " + Qt.formatDateTime(ev.startDateTime, "h:mm AP"));

                var item = {
                    isHeader: false,
                    title: ev.title,
                    timeLabel: tLabel,
                    pillColor: pillColorFor(ev)
                };
                if (isSel) todayItems.push(item);
                else upcomingItems.push(item);
            }
        }

        var selTitle = (startDay.getFullYear() === today.getFullYear() && startDay.getMonth() === today.getMonth() && startDay.getDate() === today.getDate())
            ? "TODAY"
            : Qt.formatDateTime(startDay, "ddd, MMM d").toUpperCase();

        if (todayItems.length > 0) {
            eventsModel.append({ isHeader: true, title: selTitle, timeLabel: "", pillColor: "" });
            for (var ti = 0; ti < todayItems.length; ti++) eventsModel.append(todayItems[ti]);
        }
        if (upcomingItems.length > 0) {
            eventsModel.append({ isHeader: true, title: "UPCOMING", timeLabel: "", pillColor: "" });
            for (var ui = 0; ui < Math.min(upcomingItems.length, 8); ui++) eventsModel.append(upcomingItems[ui]);
        }
    }

    Component.onCompleted: {
        rebuildMonthDays();
        syncBackend();
        rebuildTimer.start();
    }

    header: Item {}

    // Full macOS Dark Frosted Glass Card
    Rectangle {
        anchors.fill: parent
        anchors.margins: -8
        radius: 16
        color: "#ee1c1c1e"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 20

        // Left Column: macOS Agenda / Events
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Selected Date Header (macOS style: red weekday + bold day)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: Qt.formatDateTime(calendar.selectedDate, "dddd").toUpperCase()
                        color: "#FF453A"
                        font.family: "SF Pro Text"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                    Text {
                        text: Qt.formatDateTime(calendar.selectedDate, "MMMM d")
                        color: "#ffffff"
                        font.family: "SF Pro Display"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: addArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    visible: ApplicationIntegration.calendarInstalled
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: "#ffffff"
                        font.family: "SF Pro Text"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ApplicationIntegration.launchCalendar()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Events list or empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: eventsModel.count === 0
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No Upcoming Events"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: "SF Pro Text"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }

                ListView {
                    id: evList
                    anchors.fill: parent
                    visible: eventsModel.count > 0
                    model: eventsModel
                    spacing: 6
                    clip: true

                    delegate: Item {
                        required property int index
                        required property bool isHeader
                        required property string title
                        required property string timeLabel
                        required property string pillColor

                        width: evList.width
                        height: isHeader ? 20 : 38

                        Text {
                            visible: parent.isHeader
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            text: parent.title
                            color: Qt.rgba(1, 1, 1, 0.50)
                            font.family: "SF Pro Text"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.7
                        }

                        Rectangle {
                            visible: !parent.isHeader
                            anchors.fill: parent
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                x: 8
                                y: 7
                                width: 3.5
                                height: parent.height - 14
                                radius: 1.75
                                color: parent.parent.pillColor || "#0A84FF"
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: parent.parent.parent.title
                                    color: "#ffffff"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: parent.parent.parent.timeLabel
                                    color: Qt.rgba(1, 1, 1, 0.60)
                                    font.family: "SF Pro Text"
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        // Subtle Vertical Divider
        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        // Right Column: macOS Month Grid
        ColumnLayout {
            Layout.preferredWidth: 216
            Layout.maximumWidth: 216
            Layout.fillHeight: true
            spacing: 8

            // Month header + < > arrows
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: calendar.monthNames[calendar.viewMonth].toUpperCase() + " " + calendar.viewYear
                    color: "#FF453A"
                    font.family: "SF Pro Text"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                }

                Item { Layout.fillWidth: true }

                // Prev month
                Rectangle {
                    width: 22
                    height: 22
                    radius: 6
                    color: prevHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Qt.rgba(1, 1, 1, 0.80)
                        font.family: "SF Pro Text"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: prevHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (calendar.viewMonth === 0) {
                                calendar.viewMonth = 11;
                                calendar.viewYear -= 1;
                            } else {
                                calendar.viewMonth -= 1;
                            }
                        }
                    }
                }

                // Today dot
                Rectangle {
                    width: 22
                    height: 22
                    radius: 6
                    color: todayHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.80)
                    }
                    MouseArea {
                        id: todayHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: monthView.resetToToday()
                    }
                }

                // Next month
                Rectangle {
                    width: 22
                    height: 22
                    radius: 6
                    color: nextHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Qt.rgba(1, 1, 1, 0.80)
                        font.family: "SF Pro Text"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: nextHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (calendar.viewMonth === 11) {
                                calendar.viewMonth = 0;
                                calendar.viewYear += 1;
                            } else {
                                calendar.viewMonth += 1;
                            }
                        }
                    }
                }
            }

            // Weekday Header Row (S M T W T F S)
            Row {
                Layout.fillWidth: true
                height: 20
                Repeater {
                    model: 7
                    delegate: Item {
                        required property int index
                        width: 216 / 7
                        height: 20
                        Text {
                            anchors.centerIn: parent
                            text: calendar.weekdayShort[parent.index]
                            color: "#ffffff"
                            opacity: calendar.isWeekendCol(parent.index) ? 0.42 : 0.72
                            font.family: "SF Pro Text"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // 6x7 Day Grid
            Grid {
                Layout.fillWidth: true
                Layout.fillHeight: true
                rows: 6
                columns: 7

                Repeater {
                    model: 42
                    delegate: Item {
                        required property int index
                        width: 216 / 7
                        height: 30

                        readonly property int day: calendar.monthDays[index] || 0
                        readonly property bool empty: day === 0
                        readonly property bool isToday: !empty
                            && day === calendar.today.getDate()
                            && calendar.viewMonth === calendar.today.getMonth()
                            && calendar.viewYear === calendar.today.getFullYear()
                        readonly property bool isSelected: !empty
                            && day === calendar.selectedDate.getDate()
                            && calendar.viewMonth === calendar.selectedDate.getMonth()
                            && calendar.viewYear === calendar.selectedDate.getFullYear()
                        readonly property bool isWeekend: calendar.isWeekendCol(index % 7)

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            visible: !parent.empty && (parent.isToday || parent.isSelected || dayMouse.containsMouse)
                            color: parent.isToday
                                ? "#FF453A"
                                : (parent.isSelected ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10))
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !parent.empty
                            text: parent.day
                            color: "#ffffff"
                            opacity: (parent.isToday || parent.isSelected) ? 1.0 : (parent.isWeekend ? 0.48 : 0.92)
                            font.family: "SF Pro Text"
                            font.pixelSize: 12
                            font.weight: (parent.isToday || parent.isSelected) ? Font.Bold : Font.Medium
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            enabled: !parent.empty
                            hoverEnabled: true
                            onClicked: {
                                calendar.selectedDate = new Date(calendar.viewYear, calendar.viewMonth, parent.day);
                            }
                        }
                    }
                }
            }
        }
    }
}
