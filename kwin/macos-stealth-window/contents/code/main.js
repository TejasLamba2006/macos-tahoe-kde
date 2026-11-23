// Toggle excludeFromCapture on the active window so it stays visible locally
// while becoming completely invisible to Discord / Google Meet / OBS / PipeWire screen shares.

function toggleStealthWindow() {
    const w = workspace.activeWindow;
    if (!w || !w.normalWindow) {
        return;
    }
    const nextState = !w.excludeFromCapture;
    w.excludeFromCapture = nextState;
    const appTitle = String(w.resourceClass || w.caption || "Window");
    callDBus(
        "org.phobby.DynamicIsland",
        "/org/phobby/DynamicIsland",
        "org.phobby.DynamicIsland",
        "Flash",
        {
            title: nextState ? "Hidden from Screen Share" : "Visible on Screen Share",
            subtitle: appTitle,
            icon: nextState ? "view-hidden" : "view-visible",
            color: nextState ? "purple" : "blue",
            duration: 2200
        }
    );
}

registerShortcut(
    "MacOSStealthWindow",
    "Toggle Window Hidden from Screen Share",
    "Meta+Shift+H",
    toggleStealthWindow
);
