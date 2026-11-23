/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents

KWinComponents.SceneEffect {
    id: effect

    property bool activated: false
    property real partialActivationFactor: 0
    readonly property bool gestureInProgress: false
    readonly property int animationDuration: Kirigami.Units.longDuration
    property string searchText: ""

    property var mainDelegate: Qt.createComponent("ScreenView.qml")
    delegate: mainDelegate

    Behavior on partialActivationFactor {
        NumberAnimation {
            duration: effect.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    KWinComponents.ShortcutHandler {
        name: "MacOSMissionControl"
        text: i18n("Toggle macOS Mission Control")
        sequence: "Meta+W"
        onActivated: effect.toggle()
    }

    Timer {
        id: deactivateTimer
        interval: effect.animationDuration
        onTriggered: {
            effect.visible = false;
            effect.searchText = "";
        }
    }

    function checkItemDraggedOutOfScreen(item) {
    }

    function checkItemDroppedOutOfScreen(globalPos, item) {
    }

    function toggle() {
        if (activated) {
            deactivate();
        } else {
            activate();
        }
    }

    function activate() {
        if (activated) {
            return;
        }
        deactivateTimer.stop();
        searchText = "";
        visible = true;
        activated = true;
        partialActivationFactor = 1.0;
    }

    function deactivate() {
        if (!activated) {
            return;
        }
        activated = false;
        partialActivationFactor = 0.0;
        deactivateTimer.start();
    }
}
