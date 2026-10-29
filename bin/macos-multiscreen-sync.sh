#!/usr/bin/env bash
# ponytail: non-destructive multi-screen sync — adds missing macOS widgets in-place without ever deleting user-added widgets or configs

JS_SCRIPT=$(cat << 'EOJS'
var n = screenCount;
var allPanels = panels();

var topByScreen = {};
var bottomByScreen = {};

for (var i = 0; i < allPanels.length; i++) {
    var p = allPanels[i];
    if (p.screen < 0 || p.screen >= n) {
        p.remove();
        continue;
    }
    if (p.location === "top") {
        if (topByScreen[p.screen]) {
            p.remove();
        } else {
            topByScreen[p.screen] = p;
        }
    } else if (p.location === "bottom") {
        if (bottomByScreen[p.screen]) {
            p.remove();
        } else {
            bottomByScreen[p.screen] = p;
        }
    }
}

// Copy any user-customized widget config from Screen 0's panel when provisioning a secondary screen
function copyConfigFromPrimary(primaryPanel, widgetType, targetWidget, groups) {
    if (!primaryPanel || primaryPanel === targetWidget.parent) return false;
    var pw = primaryPanel.widgets();
    for (var i = 0; i < pw.length; i++) {
        if (pw[i].type === widgetType) {
            for (var g = 0; g < groups.length; g++) {
                pw[i].currentConfigGroup = [groups[g]];
                targetWidget.currentConfigGroup = [groups[g]];
                var keys = pw[i].configKeys;
                for (var k = 0; k < keys.length; k++) {
                    var val = pw[i].readConfig(keys[k]);
                    if (val !== undefined && val !== "") {
                        targetWidget.writeConfig(keys[k], val);
                    }
                }
            }
            return true;
        }
    }
    return false;
}

function ensureTopBar(panel, primaryTop) {
    panel.location = "top";
    panel.hiding = "none";
    panel.height = 28;
    panel.floating = false;
    panel.lengthMode = "fill";
    panel.alignment = "center";

    var existing = panel.widgets().map(function(w) { return w.type; });

    // Only populate if this is a brand-new / empty panel; NEVER wipe existing widgets!
    if (existing.length === 0) {
        var kickoff = panel.addWidget("org.kde.plasma.kickoff");
        kickoff.currentConfigGroup = ["General"];
        kickoff.writeConfig("icon", "start-here-symbolic");

        var winTitle = panel.addWidget("org.kde.windowtitle");
        winTitle.currentConfigGroup = ["Appearance"];
        winTitle.writeConfig("isBold", true);
        winTitle.writeConfig("visible", false);
        winTitle.writeConfig("noIcon", true);
        winTitle.writeConfig("activityIcon", false);
        winTitle.writeConfig("txt", "%a");
        winTitle.writeConfig("txtSameFound", "%a");
        winTitle.writeConfig("altTxt", "Finder");
        winTitle.writeConfig("fontSize", 13);
        winTitle.writeConfig("firstSpace", 6);
        winTitle.writeConfig("lastSpace", 10);
        winTitle.currentConfigGroup = ["Behavior"];
        winTitle.writeConfig("filterByScreen", true);

        var appMenu = panel.addWidget("org.kde.plasma.appmenu");
        appMenu.currentConfigGroup = ["Appearance"];
        appMenu.writeConfig("allScreens", false);

        panel.addWidget("org.kde.plasma.panelspacer");
        panel.addWidget("com.burakgon.keepawake");

        var tray = panel.addWidget("org.kde.plasma.systemtray");
        var sysTrayId = tray.readConfig("SystrayContainmentId");
        if (sysTrayId) {
            var sysTray = desktopById(sysTrayId);
            if (sysTray) {
                sysTray.currentConfigGroup = ["General"];
                sysTray.writeConfig("hiddenItems", [
                    "org.kde.plasma.notifications",
                    "org.kde.plasma.clipboard",
                    "org.kde.plasma.volume",
                    "org.kde.plasma.brightness",
                    "org.kde.plasma.battery",
                    "org.kde.plasma.bluetooth",
                    "org.kde.plasma.devicenotifier",
                    "org.kde.kdeconnect",
                    "org.kde.plasma.mediacontroller",
                    "org.kde.kscreen",
                    "org.kde.plasma.keyboardlayout",
                    "org.kde.plasma.keyboardindicator"
                ]);
                sysTray.writeConfig("shownItems", [
                    "org.kde.plasma.networkmanagement"
                ]);
            }
        }

        var cc = panel.addWidget("KdeControlStation");
        cc.currentConfigGroup = ["Appearance"];
        cc.writeConfig("layout", 3);
        cc.writeConfig("transparency", true);
        cc.writeConfig("transparencyLevel", 35);
        cc.writeConfig("useCustomButtonImage", true);
        cc.writeConfig("customButtonImage", "@HOME@/.local/share/plasma/plasmoids/KdeControlStation/contents/assets/control-center-symbolic.svg");

        var clock = panel.addWidget("org.kde.plasma.digitalclock");
        clock.currentConfigGroup = ["Appearance"];
        clock.writeConfig("showDate", true);
        clock.writeConfig("dateDisplayFormat", "BesideTime");
        clock.writeConfig("dateFormat", "custom");
        clock.writeConfig("customDateFormat", "ddd MMM d");
        clock.writeConfig("use24hFormat", 0);
        clock.writeConfig("autoFontAndSize", false);
        clock.writeConfig("fontSize", 10);
        clock.writeConfig("boldText", true);

        var island = panel.addWidget("org.phobby.dynamicisland");
        if (!copyConfigFromPrimary(primaryTop, "org.phobby.dynamicisland", island, ["General"])) {
            island.currentConfigGroup = ["General"];
            island.writeConfig("calendarSources", JSON.stringify([{
                id: "mvsfhu6pf7j5",
                type: "google",
                url: "",
                name: "Calendar",
                color: "#32d74b",
                enabled: true
            }]));
            island.writeConfig("weatherLocation", JSON.stringify({
                name: "New Delhi",
                admin: "National Capital Territory of Delhi",
                country: "India",
                latitude: 28.62137,
                longitude: 77.2148
            }));
            island.writeConfig("catFur", "orange");
            island.writeConfig("catSide", 2);
            island.writeConfig("catSize", 180);
            island.writeConfig("tourShown", true);
        }
    } else {
        if (existing.indexOf("org.phobby.dynamicisland") === -1) {
            var islandAdd = panel.addWidget("org.phobby.dynamicisland");
            copyConfigFromPrimary(primaryTop, "org.phobby.dynamicisland", islandAdd, ["General"]);
        }
        if (existing.indexOf("org.macos.privacydots") === -1) {
            panel.addWidget("org.macos.privacydots");
        }
    }
}

function ensureBottomDock(panel, primaryBot) {
    panel.location = "bottom";
    panel.hiding = "dodgewindows";
    panel.height = 62;
    panel.floating = true;
    panel.lengthMode = "fit";
    panel.alignment = "center";

    var existing = panel.widgets().map(function(w) { return w.type; });

    // Only populate if empty; otherwise add any missing dock widget non-destructively!
    if (existing.length === 0) {
        var tasks = panel.addWidget("org.kde.plasma.icontasks");
        if (!copyConfigFromPrimary(primaryBot, "org.kde.plasma.icontasks", tasks, ["General"])) {
            tasks.currentConfigGroup = ["General"];
            tasks.writeConfig("launchers", [
                "applications:org.kde.dolphin.desktop",
                "applications:google-chrome.desktop",
                "applications:firefox.desktop",
                "applications:com.microsoft.VSCodeInsiders.desktop",
                "applications:org.kde.konsole.desktop",
                "applications:discord.desktop",
                "applications:systemsettings.desktop"
            ]);
            tasks.writeConfig("showOnlyCurrentScreen", false);
            tasks.writeConfig("scaleAnimation", true);
            tasks.writeConfig("iconSpacing", 1);
            tasks.writeConfig("unhideOnAttention", false);
        }

        var launchpad = panel.addWidget("AndromedaLauncher");
        launchpad.currentConfigGroup = ["General"];
        launchpad.writeConfig("icon", "appgrid");
        launchpad.writeConfig("floating", true);
        launchpad.writeConfig("launcherPosition", 2);

        panel.addWidget("org.macos.dockseparator");
        panel.addWidget("org.macos.downloads");
        panel.addWidget("org.macos.trash");
    } else {
        if (existing.indexOf("org.macos.dockseparator") === -1) panel.addWidget("org.macos.dockseparator");
        if (existing.indexOf("org.macos.downloads") === -1) panel.addWidget("org.macos.downloads");
        if (existing.indexOf("org.macos.trash") === -1) panel.addWidget("org.macos.trash");
    }
}

var out = [];
var primaryTop = topByScreen[0] || null;
var primaryBot = bottomByScreen[0] || null;

for (var s = 0; s < n; s++) {
    var topP = topByScreen[s] || new Panel();
    topP.screen = s;
    ensureTopBar(topP, primaryTop);
    if (s === 0) primaryTop = topP;
    out.push("TOP:" + topP.id);

    var botP = bottomByScreen[s] || new Panel();
    botP.screen = s;
    ensureBottomDock(botP, primaryBot);
    if (s === 0) primaryBot = botP;
    out.push("BOT:" + botP.id);
}

var desk = desktops();
for (var d = 0; d < desk.length; d++) {
    if (desk[d].wallpaperPlugin !== "io.github.birkneralex.aerial") {
        desk[d].wallpaperPlugin = "io.github.birkneralex.aerial";
    }
    desk[d].currentConfigGroup = ["Wallpaper", "io.github.birkneralex.aerial", "General"];
    if (desk[d].readConfig("Shuffle") === "false" || desk[d].readConfig("Shuffle") === false) {
        desk[d].writeConfig("Shuffle", true);
    }
}

print(out.join(" "));
EOJS
)

PANEL_IDS=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS_SCRIPT")
for item in $PANEL_IDS; do
    kind="${item%%:*}"
    pid="${item#*:}"
    if [ "$kind" = "TOP" ]; then
        kwriteconfig6 --file plasmashellrc --group "PlasmaViews" --group "Panel $pid" --key panelVisibility 0
        kwriteconfig6 --file plasmashellrc --group "PlasmaViews" --group "Panel $pid" --key floating 0
        kwriteconfig6 --file plasmashellrc --group "PlasmaViews" --group "Panel $pid" --key panelOpacity 2
    elif [ "$kind" = "BOT" ]; then
        kwriteconfig6 --file plasmashellrc --group "PlasmaViews" --group "Panel $pid" --key panelVisibility 2
        kwriteconfig6 --file plasmashellrc --group "PlasmaViews" --group "Panel $pid" --key floating 1
        kwriteconfig6 --file plasmashellrc --group "PlasmaViews" --group "Panel $pid" --key panelLengthMode 1
        kwriteconfig6 --file plasmashellrc --group "PlasmaViews" --group "Panel $pid" --key panelOpacity 2
    fi
done
echo "Synced panels: $PANEL_IDS"
