import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    // Players + Lyrics as tabs on one page.
    ConfigCategory {
        name: i18n("Music")
        icon: "media-playback-start"
        source: "config/ConfigMusic.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("More & Support")
        icon: Qt.resolvedUrl("../ui/icons/about/bmc-icon.svg")
        source: "config/ConfigAbout.qml"
    }
}
