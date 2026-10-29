// ponytail: event-driven KWin script that keeps Chrome Document PiP windows above main Chrome windows

function isChromeDocPiP(w) {
    if (!w || !w.normalWindow) return false;
    const cls = String(w.resourceClass || "");
    if (cls.indexOf("chrome") === -1 && cls.indexOf("chromium") === -1 && cls.indexOf("brave") === -1) return false;
    const cap = String(w.caption || "");
    if (cap.indexOf(" - Google Chrome") !== -1 || cap.indexOf(" - Chromium") !== -1 || cap.indexOf(" - Brave") !== -1) {
        return false;
    }
    return w.width <= 900 && w.height <= 900;
}

function updateWindow(w) {
    if (!w || !w.normalWindow) return;
    const cls = String(w.resourceClass || "");
    if (cls.indexOf("chrome") === -1 && cls.indexOf("chromium") === -1 && cls.indexOf("brave") === -1) return;

    if (isChromeDocPiP(w)) {
        if (!w.keepAbove) w.keepAbove = true;
        if (!w.skipTaskbar) w.skipTaskbar = true;
        if (!w.skipSwitcher) w.skipSwitcher = true;
    } else {
        const cap = String(w.caption || "");
        if (cap.indexOf(" - Google Chrome") !== -1 || cap.indexOf(" - Chromium") !== -1 || cap.indexOf(" - Brave") !== -1 || w.width > 900) {
            if (w.keepAbove) w.keepAbove = false;
            if (w.skipTaskbar) w.skipTaskbar = false;
            if (w.skipSwitcher) w.skipSwitcher = false;
        }
    }
}

function bindWindow(w) {
    updateWindow(w);
    w.captionChanged.connect(function() { updateWindow(w); });
    w.frameGeometryChanged.connect(function() { updateWindow(w); });
}

const wins = workspace.windowList();
for (let i = 0; i < wins.length; i++) {
    bindWindow(wins[i]);
}
workspace.windowAdded.connect(bindWindow);
