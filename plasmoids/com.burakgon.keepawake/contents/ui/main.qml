import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // ---- state ----
    property bool sleepOnly: false   // keep-awake.service active        (display can sleep)
    property bool fullOn:    false   // keep-awake-full.service active   (display stays on)
    property bool busy: false

    readonly property bool active: sleepOnly || fullOn
    readonly property bool allowDisplaySleep: Plasmoid.configuration.allowDisplaySleep

    readonly property string activeIcon:   "redshift-status-on"
    readonly property string inactiveIcon: "redshift-status-off"

    readonly property string svcSleep: "keep-awake.service"
    readonly property string svcFull:  "keep-awake-full.service"

    readonly property string checkSleep: "systemctl --user is-active " + svcSleep
    readonly property string checkFull:  "systemctl --user is-active " + svcFull

    Plasmoid.icon: active ? activeIcon : inactiveIcon
    Plasmoid.status: active ? PlasmaCore.Types.ActiveStatus
                            : PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18n("Keep Awake")
    toolTipSubText: !active
        ? i18n("Inactive — normal power management")
        : (fullOn
            ? i18n("Active — system and display stay awake")
            : i18n("Active — system will not sleep (screen can still turn off)"))

    // ---- runner ----
    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            const stdout = (data["stdout"] !== undefined ? data["stdout"] : "").toString().trim()
            disconnectSource(sourceName)

            if (sourceName === root.checkSleep) {
                root.sleepOnly = (stdout === "active")
            } else if (sourceName === root.checkFull) {
                root.fullOn = (stdout === "active")
            } else {
                // start/stop finished — re-poll state shortly after
                root.busy = false
                recheckTimer.restart()
            }
        }

        function run(cmd) {
            disconnectSource(cmd)
            connectSource(cmd)
        }
    }

    function refresh() {
        runner.run(checkSleep)
        runner.run(checkFull)
    }

    function targetService() {
        return allowDisplaySleep ? svcSleep : svcFull
    }

    function toggle() {
        if (busy) return
        busy = true
        if (active) {
            // One command keeps busy true until both services are stopped.
            runner.run("systemctl --user stop " + svcSleep + " " + svcFull)
        } else {
            runner.run("systemctl --user start " + targetService())
        }
    }

    // If the user flips "Allow display to sleep" while active, switch services live.
    onAllowDisplaySleepChanged: {
        if (!active || busy) return
        busy = true
        // The units conflict, so starting the target stops the other service
        // in the same systemd transaction.
        runner.run("systemctl --user start " + targetService())
    }

    Timer {
        id: pollTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: refresh()
    }

    Timer {
        id: recheckTimer
        interval: 400
        repeat: false
        onTriggered: refresh()
    }

    compactRepresentation: MouseArea {
        id: compactRoot
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.expanded = !root.expanded
            } else if (mouse.button === Qt.MiddleButton) {
                root.toggle()
            }
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: root.active ? root.activeIcon : root.inactiveIcon
            active: compactRoot.containsMouse
            opacity: root.busy ? 0.6 : 1.0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 14
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            source: root.active ? root.activeIcon : root.inactiveIcon
            opacity: root.busy ? 0.6 : 1.0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.active ? i18n("Keep Awake is ON") : i18n("Keep Awake is OFF")
            font.bold: true
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
            text: !root.active
                ? i18n("System will sleep according to power settings.")
                : (root.fullOn
                    ? i18n("Suspend and screen blanking are blocked.")
                    : i18n("Suspend is blocked. Screen can still turn off normally."))
        }

        Item { Layout.fillHeight: true }

        // ---- Allow display to sleep switch ----
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("Allow display to sleep")
            }

            Item { Layout.fillWidth: true }

            QQC2.Switch {
                id: displaySleepSwitch
                checked: root.allowDisplaySleep
                onToggled: Plasmoid.configuration.allowDisplaySleep = checked
            }
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.55
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            text: root.allowDisplaySleep
                ? i18n("Screen will turn off per Power Management settings.")
                : i18n("Screen will stay on while Keep Awake is active.")
        }

        QQC2.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            enabled: !root.busy
            text: root.active ? i18n("Turn Off") : i18n("Turn On")
            icon.name: root.active ? "media-playback-stop" : "media-playback-start"
            onClicked: root.toggle()
        }
    }
}
