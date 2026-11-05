/*
    SPDX-License-Identifier: LGPL-2.0-or-later
    ponytail: single-row horizontal macOS Bartender icon strip
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: hiddenTasksView

    property alias layout: hiddenTasks

    GridView {
        id: hiddenTasks
        anchors.centerIn: parent
        width: Math.max(1, count) * cellWidth
        height: cellHeight
        interactive: false

        readonly property int columns: Math.max(1, hiddenTasks.count)
        readonly property int minimumColumns: 1
        readonly property int delegateMaxTextLines: 1
        readonly property int delegateMargins: 2
        readonly property int delegateHeight: 28

        cellWidth: 32
        cellHeight: 28

        currentIndex: -1
        highlight: null
        highlightMoveDuration: 0
        pixelAligned: true

        readonly property int itemCount: model.count

        model: root.hiddenModel
        delegate: ItemLoader {
            width: hiddenTasks.cellWidth
            height: hiddenTasks.cellHeight
            Accessible.role: Accessible.ListItem
        }

        keyNavigationEnabled: true
        activeFocusOnTab: true
        KeyNavigation.up: hiddenTasksView.KeyNavigation.up
    }
}
