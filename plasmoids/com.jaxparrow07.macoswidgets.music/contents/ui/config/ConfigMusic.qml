// Music settings: one sidebar entry with Players / Lyrics tabs.
// Both tabs stay instantiated (only `visible` toggles), so a single Apply
// saves every cfg_* value. SliderField.qml is symlinked from 1-common/config.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.private.mpris as Mpris

KCMUtils.SimpleKCM {
    id: root

    // ── Players ───────────────────────────────────────────────────────────
    // Comma-separated MPRIS player identities.
    property string cfg_playerFilter: ""
    // true = hide the checked players; false = show only the checked ones.
    property alias cfg_filterMode: hideCheckedRadio.checked
    property alias cfg_autoHideEnabled: autoHideCheck.checked
    property alias cfg_autoHideTimeout: autoHideField.value
    property alias cfg_artRefreshEnabled: artRefreshCheck.checked

    // ── Lyrics ────────────────────────────────────────────────────────────
    property alias cfg_lyricsActiveOpacity: activeOpacityField.value
    property alias cfg_lyricsInactiveOpacity: inactiveOpacityField.value
    property alias cfg_lyricsFontSizeWide: wideFontField.value
    property alias cfg_lyricsFontSizeTall: tallFontField.value
    property alias cfg_lyricsBlur: lyricsBlurCheck.checked
    property alias cfg_showTrackTitleInLyrics: showTrackTitleCheck.checked

    readonly property var _checkedPlayers: {
        const raw = cfg_playerFilter || ""
        return raw.split(",").map(s => s.trim()).filter(s => s !== "")
    }

    function _togglePlayer(identity) {
        const list = _checkedPlayers.slice()
        const idx = list.indexOf(identity)
        if (idx >= 0) list.splice(idx, 1)
        else list.push(identity)
        cfg_playerFilter = list.join(",")
    }

    Mpris.Mpris2Model { id: mprisModel }

    function _reloadPlayers() {
        const ids = []
        const CONTAINER_ROLE = Qt.UserRole + 1
        // Row 0 is the "multiplexer" entry, not a real player.
        for (let i = 1; i < mprisModel.rowCount(); i++) {
            const player = mprisModel.data(mprisModel.index(i, 0), CONTAINER_ROLE)
            if (player && player.identity && ids.indexOf(player.identity) < 0)
                ids.push(player.identity)
        }
        // Keep players that are checked but not running, so they can be unchecked.
        for (const id of _checkedPlayers)
            if (ids.indexOf(id) < 0) ids.push(id)
        playerRepeater.model = ids
    }

    Component.onCompleted: _reloadPlayers()

    // Tabs run edge to edge, like other KDE tabbed settings pages.
    headerPaddingEnabled: false
    header: QQC2.TabBar {
        id: tabBar
        objectName: "configTabBar"
        QQC2.TabButton { text: i18n("Players") }
        QQC2.TabButton { text: i18n("Lyrics") }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // ── Players ───────────────────────────────────────────────────────
        Kirigami.FormLayout {
            id: playersForm
            Layout.fillWidth: true
            visible: tabBar.currentIndex === 0
            twinFormLayouts: [lyricsForm]

            QQC2.RadioButton {
                id: showCheckedRadio
                Kirigami.FormData.label: i18n("Players:")
                text: i18n("Only show the checked players")
                checked: !hideCheckedRadio.checked
                onToggled: hideCheckedRadio.checked = !checked
            }

            QQC2.RadioButton {
                id: hideCheckedRadio
                text: i18n("Hide the checked players")
            }

            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                wrapMode: Text.WordWrap
                opacity: 0.75
                text: hideCheckedRadio.checked
                    ? i18n("Checked players are ignored by the widget.")
                    : i18n("When nothing is checked, every player is shown.")
            }

            QQC2.Button {
                Kirigami.FormData.label: i18n("Detected players:")
                icon.name: "view-refresh"
                text: i18n("Refresh")
                onClicked: root._reloadPlayers()
            }

            ColumnLayout {
                spacing: 0

                Repeater {
                    id: playerRepeater
                    delegate: QQC2.CheckBox {
                        required property string modelData
                        text: modelData
                        checked: root._checkedPlayers.indexOf(modelData) >= 0
                        onToggled: root._togglePlayer(modelData)
                    }
                }

                QQC2.Label {
                    visible: playerRepeater.count === 0
                    opacity: 0.75
                    text: i18n("No media players are running. Start one, then press Refresh.")
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("When idle")
            }

            QQC2.CheckBox {
                id: autoHideCheck
                Kirigami.FormData.label: i18n("Auto-hide:")
                text: i18n("Hide the widget when nothing is playing")
            }

            SliderField {
                id: autoHideField
                Kirigami.FormData.label: i18n("Hide after:")
                enabled: autoHideCheck.checked
                // Up to 10 minutes; longer values set by the old spin box are
                // kept as-is unless the slider is moved.
                from: 5; to: 600; stepSize: 5
                format: (v) => v < 60 ? i18nc("seconds", "%1 s", v)
                             : v % 60 === 0 ? i18nc("minutes", "%1 min", v / 60)
                             : i18nc("minutes and seconds", "%1 min %2 s", Math.floor(v / 60), v % 60)
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Album art")
            }

            QQC2.CheckBox {
                id: artRefreshCheck
                Kirigami.FormData.label: i18n("Cover refresh:")
                text: i18n("Briefly pause and resume on track change")
            }

            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                wrapMode: Text.WordWrap
                opacity: 0.75
                text: i18n("Helps players that don't update the cover on their own. Causes a short playback hiccup.")
            }
        }

        // ── Lyrics ────────────────────────────────────────────────────────
        Kirigami.FormLayout {
            id: lyricsForm
            Layout.fillWidth: true
            visible: tabBar.currentIndex === 1
            twinFormLayouts: [playersForm]

            QQC2.CheckBox {
                id: showTrackTitleCheck
                Kirigami.FormData.label: i18n("Track title:")
                text: i18n("Show the track title above the lyrics")
            }

            QQC2.CheckBox {
                id: lyricsBlurCheck
                Kirigami.FormData.label: i18n("Upcoming lines:")
                text: i18n("Blur them")
            }

            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                wrapMode: Text.WordWrap
                opacity: 0.75
                text: i18n("Turn off on slower hardware.")
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Opacity")
            }

            SliderField {
                id: activeOpacityField
                Kirigami.FormData.label: i18n("Current line:")
                from: 50; to: 100; stepSize: 5
                format: (v) => i18nc("percentage", "%1%", v)
            }

            SliderField {
                id: inactiveOpacityField
                Kirigami.FormData.label: i18n("Other lines:")
                from: 5; to: 80; stepSize: 5
                format: (v) => i18nc("percentage", "%1%", v)
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Text size")
            }

            // Stored in per-mille of the widget size; shown as a percentage.
            SliderField {
                id: wideFontField
                Kirigami.FormData.label: i18n("Wide layout:")
                from: 40; to: 150; stepSize: 5
                format: (v) => i18nc("percentage", "%1%", (v / 10).toFixed(1))
            }

            SliderField {
                id: tallFontField
                Kirigami.FormData.label: i18n("Tall layout:")
                from: 30; to: 120; stepSize: 5
                format: (v) => i18nc("percentage", "%1%", (v / 10).toFixed(1))
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Source")
            }

        }

        // Data-use note (see also the weather widget's Open-Meteo note).
        // Keep it in sync with _fetchLyrics() in main.qml: lyrics are
        // looked up on every track change, even with the lyrics view closed.
        QQC2.Label {
            visible: tabBar.currentIndex === 1
            // Full form width, starting at the "Source" divider's left edge,
            // rather than squeezed into the form's field column.
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: lyricsForm.implicitWidth
            wrapMode: Text.WordWrap
            opacity: 0.7
            textFormat: Text.StyledText
            linkColor: Kirigami.Theme.linkColor
            text: i18n("Lyrics come from <a href=\"%1\">LRCLIB</a> (lrclib.net), a free, nonprofit database of user-contributed lyrics. No account or API key is needed.<br><br>When the track changes, its title, artist, album and length are sent to lrclib.net to find lyrics, even if the lyrics view is closed. As with any web request, LRCLIB also sees your IP address.<br><br>LRCLIB doesn't publish a separate privacy policy; its <a href=\"%2\">API Terms of Use</a> apply. Lyrics may be protected by copyright and are shown for personal use only.",
                       "https://lrclib.net",
                       "https://lrclib.net/developers/terms")
            onLinkActivated: (link) => Qt.openUrlExternally(link)

            HoverHandler {
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }
}
