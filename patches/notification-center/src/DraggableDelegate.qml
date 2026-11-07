/*
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Templates as T

import org.kde.kirigami as Kirigami

T.SwipeDelegate {
    id: swipeDelegate

    property bool draggable
    signal dismissRequested

    function close() {
        swipe.open(T.SwipeDelegate.Left)
    }

    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
    leftPadding: 14
    rightPadding: 14
    topPadding: 12
    bottomPadding: 12

    background: Rectangle {
        radius: 16
        color: "#ee1c1c1e"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    swipe.enabled: draggable && Kirigami.Settings.tabletMode
    swipe.onCompleted: dismissRequested()
    swipe.transition: Transition {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InQuad
        }
    }
    opacity: 1 - Math.abs(swipe.position)
    swipe.right: Item {
        anchors.fill:parent
    }
    swipe.left: Item {
        anchors.fill:parent
    }
}
