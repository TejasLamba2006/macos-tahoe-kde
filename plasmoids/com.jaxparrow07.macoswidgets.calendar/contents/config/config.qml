import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.configuration
import org.kde.plasma.workspace.calendar as PlasmaCalendar

ConfigModel {
    id: configModel

    // General + Events (Akonadi) as tabs on one page.
    ConfigCategory {
        name: i18n("Calendar")
        icon: "view-calendar"
        source: "config/ConfigCalendar.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }

    // Remaining plugins (holidays, astronomical, etc.) use their own built-in config pages.
    readonly property PlasmaCalendar.EventPluginsManager _epm: PlasmaCalendar.EventPluginsManager {
        Component.onCompleted: {
            populateEnabledPluginsList(Plasmoid.configuration.enabledCalendarPlugins);
        }
    }

    readonly property Instantiator _pluginPages: Instantiator {
        model: configModel._epm.model
        delegate: ConfigCategory {
            required property string display
            required property string decoration
            required property string configUi
            required property string configModule
            required property string configComponent
            required property string pluginId

            name: display
            icon: decoration
            source: configUi
            configUiModule: configModule
            configUiComponent: configComponent
            visible: pluginId !== "pimevents"
                     && Plasmoid.configuration.enabledCalendarPlugins.indexOf(pluginId) > -1
        }

        onObjectAdded: (index, object) => {
            configModel.appendCategory(object)
            aboutTimer.restart()
        }
        onObjectRemoved: (index, object) => configModel.removeCategory(object)
    }

    // "More & Support" must be last, but ConfigModel can only append, and the
    // plugin pages above arrive asynchronously (after this model completes).
    // So it's appended once, shortly after the last plugin page is added;
    // the timer is also started on completion for setups with no plugins.
    readonly property ConfigCategory _aboutCategory: ConfigCategory {
        name: i18n("More & Support")
        icon: Qt.resolvedUrl("../ui/icons/about/bmc-icon.svg")
        source: "config/ConfigAbout.qml"
    }

    property bool _aboutAdded: false

    readonly property Timer _aboutTimer: Timer {
        id: aboutTimer
        interval: 150
        onTriggered: {
            if (configModel._aboutAdded) return
            configModel._aboutAdded = true
            configModel.appendCategory(configModel._aboutCategory)
        }
    }

    Component.onCompleted: aboutTimer.start()
}
