/*
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt5Compat.GraphicalEffects

import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.kirigami as Kirigami
import org.kde.breeze.components

Item {
    id: root

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    width: 1920
    height: 1080

    property string notificationMessage

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    PlasmaClock.Clock {
        id: macTimeSource
        trackSeconds: false
    }

    Item {
        id: wallpaper
        anchors.fill: parent
        Repeater {
            model: screenModel

            Background {
                x: geometry.x; y: geometry.y; width: geometry.width; height: geometry.height
                sceneBackgroundType: config.type
                sceneBackgroundColor: config.color
                sceneBackgroundImage: config.background
            }
        }
    }

    LinearGradient {
        anchors.fill: parent
        start: Qt.point(0, 0)
        end: Qt.point(0, parent.height)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.05) }
            GradientStop { position: 0.65; color: Qt.rgba(0, 0, 0, 0.05) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.48) }
        }
    }

    RejectPasswordAnimation {
        id: rejectPasswordAnimation
        target: mainStack
    }

    MouseArea {
        id: loginScreenRoot
        anchors.fill: parent

        property bool uiVisible: true
        property bool blockUI: mainStack.depth > 1 || userListComponent.mainPasswordBox.text.length > 0 || Keyboards.KWinVirtualKeyboard.visible

        hoverEnabled: true
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: uiVisible = true;

        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }

        // macOS Sonoma / Sequoia / Tahoe Top Clock & Date
        ColumnLayout {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.height * 0.095)
            spacing: -8
            visible: config.showClock === "true"

            Text {
                text: Qt.formatDate(macTimeSource.dateTime, "dddd, MMMM d")
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: "SF Pro Display"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignHCenter
                layer.enabled: !root.softwareRendering
                layer.effect: DropShadow {
                    verticalOffset: 2
                    radius: 12
                    samples: 25
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
            }

            Text {
                text: {
                    let h = macTimeSource.dateTime.getHours() % 12;
                    if (h === 0) h = 12;
                    const m = String(macTimeSource.dateTime.getMinutes()).padStart(2, "0");
                    return h + ":" + m;
                }
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: "SF Pro Display"
                font.pixelSize: 112
                font.weight: Font.Bold
                font.letterSpacing: -2
                Layout.alignment: Qt.AlignHCenter
                layer.enabled: !root.softwareRendering
                layer.effect: DropShadow {
                    verticalOffset: 4
                    radius: 20
                    samples: 32
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
            }
        }

        QQC2.StackView {
            id: mainStack
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: Math.round(parent.height * 0.065)
            }
            height: 250
            focus: true

            Timer {
                running: true
                repeat: false
                interval: 200
                onTriggered: mainStack.forceActiveFocus()
            }

            initialItem: Login {
                id: userListComponent
                userListModel: userModel
                loginScreenUiVisible: loginScreenRoot.uiVisible
                userListCurrentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
                lastUserName: userModel.lastUser
                showUserList: true

                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push(i18ndc("plasma-desktop-sddm-theme", "@info:status", "Caps Lock is on"));
                    }
                    if (root.notificationMessage) {
                        parts.push(root.notificationMessage);
                    }
                    return parts.join(" • ");
                }

                onLoginRequest: (username, password) => {
                    root.notificationMessage = ""
                    sddm.login(username, password, sessionButton.currentIndex)
                }
            }
        }

        // Top-right macOS status bar
        RowLayout {
            id: footer
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 10
                rightMargin: 18
            }
            spacing: 12

            SessionButton {
                id: sessionButton
                onSessionChanged: {
                    userListComponent.mainPasswordBox.forceActiveFocus();
                }
            }

            KeyboardButton {
                id: keyboardButton
                onKeyboardLayoutChanged: {
                    userListComponent.mainPasswordBox.forceActiveFocus();
                }
            }

            Battery {}
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.notificationMessage = i18nd("plasma-desktop-sddm-theme", "Login Failed")
            footer.enabled = true
            mainStack.enabled = true
            userListComponent.userList.opacity = 1
            rejectPasswordAnimation.start()
        }
        function onInformationMessage(message) {
            root.notificationMessage = message
        }
    }
}
