#!/usr/bin/env bash
# ponytail: non-destructive multi-screen sync — never calls p.remove() on panels with lastScreen < 0 so KDE never deletes secondary screen panels during monitor wake/re-enumeration

JS_SCRIPT=$(cat << 'EOJS'
var n = screenCount;
var allPanels = panels();

var topByScreen = {};
var bottomByScreen = {};
var homelessTop = [];
var homelessBot = [];

for (var i = 0; i < allPanels.length; i++) {
    var p = allPanels[i];
    if (p.location === "top") {
        if (p.screen >= 0 && p.screen < n) {
            if (!topByScreen[p.screen]) {
                topByScreen[p.screen] = p;
            }
        } else {
            homelessTop.push(p);
        }
    } else if (p.location === "bottom") {
        if (p.screen >= 0 && p.screen < n) {
            if (!bottomByScreen[p.screen]) {
                bottomByScreen[p.screen] = p;
            }
        } else {
            homelessBot.push(p);
        }
    }
}

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
        winTitle.writeConfig("filterByScreen", false);

        var appMenu = panel.addWidget("org.kde.plasma.appmenu");
        appMenu.currentConfigGroup = ["Appearance"];
        appMenu.writeConfig("allScreens", true);

        panel.addWidget("org.kde.plasma.panelspacer");
        panel.addWidget("com.burakgon.keepawake");

        var tray = panel.addWidget("org.kde.plasma.systemtray");
        tray.currentConfigGroup = ["General"];
        tray.writeConfig("hiddenItems", [
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
        tray.writeConfig("shownItems", [
            "org.kde.plasma.networkmanagement"
        ]);

        var cc = panel.addWidget("KdeControlStation");
        cc.currentConfigGroup = ["Appearance"];
        cc.writeConfig("layout", 3);
        cc.writeConfig("transparency", true);
        cc.writeConfig("transparencyLevel", 35);
        cc.writeConfig("useCustomButtonImage", true);
        cc.writeConfig("customButtonImage", "@HOME@/.local/share/plasma/plasmoids/KdeControlStation/contents/assets/control-center-symbolic.svg");

        var g = screenGeometry(panel.screen);
        var clock = panel.addWidget("org.kde.plasma.digitalclock");
        clock.currentConfigGroup = ["Appearance"];
        clock.writeConfig("showDate", true);
        clock.writeConfig("dateDisplayFormat", 1);
        clock.writeConfig("dateFormat", "custom");
        clock.writeConfig("customDateFormat", "ddd MMM d");
        clock.writeConfig("use24hFormat", 0);
        clock.writeConfig("autoFontAndSize", false);
        clock.writeConfig("fontFamily", "SF Pro Text");
        clock.writeConfig("fontWeight", 600);
        clock.writeConfig("fontStyleName", "Semibold");
        clock.writeConfig("fontSize", g.x > 0 ? 7 : 12);
        clock.writeConfig("boldText", true);

        var island = panel.addWidget("org.phobby.dynamicisland");
        if (!copyConfigFromPrimary(primaryTop, "org.phobby.dynamicisland", island, ["General"])) {
            island.currentConfigGroup = ["General"];
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
            island.writeConfig("ambientGlow", true);
        }

        panel.addWidget("org.macos.privacydots");
    } else {
        if (existing.indexOf("org.phobby.dynamicisland") === -1) {
            var islandAdd = panel.addWidget("org.phobby.dynamicisland");
            copyConfigFromPrimary(primaryTop, "org.phobby.dynamicisland", islandAdd, ["General"]);
        }
        if (existing.indexOf("org.macos.privacydots") === -1) {
            panel.addWidget("org.macos.privacydots");
        }
        var g2 = screenGeometry(panel.screen);
        var pw = panel.widgets();
        for (var wi = 0; wi < pw.length; wi++) {
            if (pw[wi].type === "org.kde.plasma.digitalclock") {
                pw[wi].currentConfigGroup = ["Appearance"];
                pw[wi].writeConfig("showDate", true);
                pw[wi].writeConfig("dateDisplayFormat", 1);
                pw[wi].writeConfig("dateFormat", "custom");
                pw[wi].writeConfig("customDateFormat", "ddd MMM d");
                pw[wi].writeConfig("use24hFormat", 0);
                pw[wi].writeConfig("autoFontAndSize", false);
                pw[wi].writeConfig("fontFamily", "SF Pro Text");
                pw[wi].writeConfig("fontWeight", 600);
                pw[wi].writeConfig("fontStyleName", "Semibold");
                pw[wi].writeConfig("fontSize", g2.x > 0 ? 7 : 12);
                pw[wi].writeConfig("boldText", true);
            } else if (pw[wi].type === "org.kde.plasma.systemtray") {
                pw[wi].currentConfigGroup = ["General"];
                pw[wi].writeConfig("hiddenItems", [
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
                    "org.kde.plasma.keyboardindicator",
                    "Yakuake",
                    "vicinae",
                    "Easy Effects",
                    "uKzAWcJM_C",
                    "spotify-client",
                    "discord_status_icon_1",
                    "Cachy-Update",
                    "open-whispr_status_icon_1",
                    "plasmashell_microphone",
                    "org.kde.merkuro.contact.applet",
                    "org.kde.plasma.cameraindicator",
                    "org.kde.plasma.manage-inputmethod",
                    "org.kde.plasma.weather",
                    "org.kde.plasma.dwellclicker"
                ]);
                pw[wi].writeConfig("shownItems", [
                    "org.kde.plasma.networkmanagement"
                ]);
            } else if (pw[wi].type === "org.kde.windowtitle") {
                pw[wi].currentConfigGroup = ["Appearance"];
                pw[wi].writeConfig("isBold", true);
                pw[wi].writeConfig("visible", false);
                pw[wi].writeConfig("noIcon", true);
                pw[wi].writeConfig("activityIcon", false);
                pw[wi].writeConfig("txt", "%a");
                pw[wi].writeConfig("txtSameFound", "%a");
                pw[wi].writeConfig("altTxt", "Finder");
                pw[wi].writeConfig("fontSize", 13);
                pw[wi].writeConfig("firstSpace", 6);
                pw[wi].writeConfig("lastSpace", 10);
                pw[wi].currentConfigGroup = ["Behavior"];
                pw[wi].writeConfig("filterByScreen", false);
            } else if (pw[wi].type === "org.kde.plasma.appmenu") {
                pw[wi].currentConfigGroup = ["Appearance"];
                pw[wi].writeConfig("allScreens", true);
            }
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
                "applications:systemsettings.desktop",
                "applications:spotify-launcher.desktop"
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
    var topP = topByScreen[s] || homelessTop.shift() || new Panel();
    topP.screen = s;
    ensureTopBar(topP, primaryTop);
    if (s === 0) primaryTop = topP;
    out.push("TOP:" + topP.id + ":" + s);

    var botP = bottomByScreen[s] || homelessBot.shift() || new Panel();
    botP.screen = s;
    ensureBottomDock(botP, primaryBot);
    if (s === 0) primaryBot = botP;
    out.push("BOT:" + botP.id + ":" + s);
}

var desk = desktops();
for (var d = 0; d < desk.length; d++) {
    desk[d].currentConfigGroup = ["General"];
    if (desk[d].readConfig("url") === "file:///tmp/empty-desktop") {
        desk[d].writeConfig("url", "desktop:/");
    }
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
    IFS=":" read -r kind pid scr <<< "$item"
    kwriteconfig6 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group "Containments" --group "$pid" --key "lastScreen" "$scr"
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
