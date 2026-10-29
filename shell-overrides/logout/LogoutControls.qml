/*
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.components as PlasmaComponents
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.breeze.components
import org.kde.plasma.private.sessions

Item {
    id: controls
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    anchors.fill: parent

    readonly property Item hostRoot: parent
    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault

    opacity: 0
    onHostRootChanged: fadeIn.restart()

    NumberAnimation {
        id: fadeIn
        target: controls
        property: "opacity"
        from: 0
        to: 1
        duration: Kirigami.Units.longDuration
        easing.type: Easing.InOutQuad
    }

    KCoreAddons.KUser {
        id: kuser
    }

    SessionsModel {
        id: otherSessionsModel
        includeUnusedSessions: false
        includeOwnSession: false
    }

    // macOS Sequoia / Tahoe Frosted Glass Shutdown / Logout Sheet
    Rectangle {
        id: macCard
        anchors.centerIn: parent
        width: Math.max(480, mainCol.implicitWidth + 64)
        height: mainCol.implicitHeight + 56
        radius: 22
        color: Qt.rgba(0.14, 0.15, 0.18, 0.86)
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1

        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 10
            radius: 32
            samples: 48
            color: Qt.rgba(0, 0, 0, 0.6)
        }

        // Prevent clicks inside card from cancelling
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: mainCol
            anchors.centerIn: parent
            spacing: 16

            // Circular User Avatar
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 64
                height: 64

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: "file://@HOME@/.face.icon"
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: 32
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: avatarImg
                    maskSource: avatarMask
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 32
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                    border.width: 1
                }
            }

            Text {
                text: kuser.fullName || "@USER_FULLNAME@"
                color: "white"
                font.family: "SF Pro Display"
                font.pixelSize: 18
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                opacity: controls.hostRoot.countingDown ? 1 : 0.8
                color: Qt.rgba(1, 1, 1, 0.78)
                font.family: "SF Pro Text"
                font.pixelSize: 13
                text: {
                    if (!controls.hostRoot.countingDown) {
                        return "Are you sure you want to shut down your computer now?";
                    }
                    switch (sdtype) {
                        case ShutdownType.ShutdownTypeReboot:
                            return "If you do nothing, the computer will restart automatically in " + controls.hostRoot.remainingTime + " seconds.";
                        case ShutdownType.ShutdownTypeNone:
                            return "If you do nothing, you will be logged out automatically in " + controls.hostRoot.remainingTime + " seconds.";
                        case ShutdownType.ShutdownTypeHalt:
                        default:
                            return "If you do nothing, the computer will shut down automatically in " + controls.hostRoot.remainingTime + " seconds.";
                    }
                }
            }

            GridLayout {
                id: logoutButtonsRow
                rowSpacing: 20
                columnSpacing: 24
                Layout.topMargin: 8
                Layout.alignment: Qt.AlignHCenter

                readonly property int buttonCount: visibleChildren.length
                columns: Math.max(1, buttonCount)

                LogoutButton {
                    id: suspendButton
                    objectName: "suspendButton"
                    icon.name: "system-suspend"
                    text: "Sleep"
                    onClicked: controls.hostRoot.sleepRequested()
                    visible: spdMethods.SuspendState && controls.showAllOptions
                }
                LogoutButton {
                    id: rebootButton
                    objectName: "rebootButton"
                    icon.name: softwareUpdatePending ? "system-reboot-update" : "system-reboot"
                    text: "Restart…"
                    onClicked: {
                        if (softwareUpdatePending) {
                            controls.hostRoot.rebootUpdateRequested();
                        } else {
                            controls.hostRoot.rebootRequested();
                        }
                    }
                    focus: sdtype === ShutdownType.ShutdownTypeReboot
                    visible: maysd && (sdtype === ShutdownType.ShutdownTypeReboot || controls.showAllOptions)
                }
                LogoutButton {
                    id: shutdownButton
                    objectName: "shutdownButton"
                    icon.name: softwareUpdatePending ? "system-shutdown-update" : "system-shutdown"
                    text: "Shut Down…"
                    onClicked: {
                        if (softwareUpdatePending) {
                            controls.hostRoot.haltUpdateRequested();
                        } else {
                            controls.hostRoot.haltRequested();
                        }
                    }
                    focus: sdtype === ShutdownType.ShutdownTypeHalt || controls.showAllOptions
                    visible: maysd && (sdtype === ShutdownType.ShutdownTypeHalt || controls.showAllOptions)
                }
                LogoutButton {
                    id: logoutButton
                    objectName: "logoutButton"
                    icon.name: "system-log-out"
                    text: "Log Out"
                    onClicked: controls.hostRoot.logoutRequested()
                    focus: sdtype === ShutdownType.ShutdownTypeNone
                    visible: canLogout && (sdtype === ShutdownType.ShutdownTypeNone || controls.showAllOptions)
                }
                LogoutButton {
                    id: cancelButton
                    objectName: "cancelButton"
                    icon.name: "dialog-cancel"
                    text: "Cancel"
                    onClicked: controls.hostRoot.cancelRequested()
                }
            }
        }
    }
}
