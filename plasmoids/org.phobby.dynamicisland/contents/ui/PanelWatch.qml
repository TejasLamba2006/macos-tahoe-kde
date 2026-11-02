/*
    SPDX-License-Identifier: GPL-2.0-or-later
    ponytail: replaced self-reentrant D-Bus evaluateScript call (which caused plasmashell SIGSEGV in KConfigGroup::readEntry when a monitor is unplugged) with Qt.application.screens geometry
*/
import QtQuick

Item {
    id: watch

    property var core: null
    property bool enabled: false
    property var hint: null
    onHintChanged: if (enabled) refresh()
    property var screens: []
    property var topPanels: []
    property bool ready: false

    function topPanelAt(x: real, y: real): var {
        for (const p of topPanels) if (p.screen.x === x && p.screen.y === y) return p;
        return { screen: { x: x, y: y, width: 1920, height: 1080 }, height: 28, autohide: false, floating: false };
    }

    function refresh(): void {
        if (!enabled) return;
        const scrs = [];
        const pans = [];
        const appScreens = Qt.application.screens;
        for (let i = 0; i < appScreens.length; ++i) {
            const s = appScreens[i];
            const g = { x: s.virtualX, y: s.virtualY, width: s.width, height: s.height };
            scrs.push(g);
            pans.push({ screen: g, height: 28, autohide: false, floating: false });
        }
        watch.screens = scrs;
        watch.topPanels = pans;
        watch.ready = true;
    }

    onEnabledChanged: refresh()
    onCoreChanged: refresh()
    Component.onCompleted: refresh()
}
