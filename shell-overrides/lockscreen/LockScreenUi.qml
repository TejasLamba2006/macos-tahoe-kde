/*
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2026 Kristen McWilliam <kristen@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Qt5Compat.GraphicalEffects

import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.accessibility
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.ki18n

import org.kde.plasma.private.sessions
import org.kde.breeze.components

Item {
    id: lockScreenUi

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software
    property bool expectingPrompt: false
    property bool showPrompt: false

    readonly property var cachedAerialVideos: [
        "file://@HOME@/.cache/aerial-wallpaper/videos/0FA98CA1-0005-4C98-8DCF-8BE7A6B159CE.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/22162A9B-DB90-4517-867C-C676BC3E8E95.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/2F72BC1E-3D76-456C-81EB-842EBA488C27.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/35693AEA-F8C4-4A80-B77D-C94B20A68956.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/3D729CFC-9000-48D3-A052-C5BD5B7A6842.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/3FFA2A97-7D28-49EA-AA39-5BC9051B2745.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/44166C39-8566-4ECA-BD16-43159429B52F.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/6324F6EB-E0F1-468F-AC2E-A983EBDDD53B.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/7530C83C-8F7B-42C6-BB71-5FA2ED070BEC.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/7719B48A-2005-4011-9280-2F64EEC6FD91.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/81337355-E156-4242-AAF4-711768D30A54.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/82175C1F-153C-4EC8-AE37-2860EA828004.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/82BD33C9-B6D2-47E7-9C42-AA3B7758921A.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/83C65C90-270C-4490-9C69-F51FE03D7F06.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/8C31B06F-91A4-4F7C-93ED-56146D7F48B9.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/9CCB8297-E9F5-4699-AE1F-890CFBD5E29C.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/A63179A7-BC32-4307-89F0-112694889A03.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/AA5E82B9-289A-480C-A14B-242989107275.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/B876B645-3955-420E-99DF-60139E451CF3.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/CE9B5D5B-B6E7-47C5-8C04-59BF182E98FB.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/DD47D8E1-CB66-4C12-BFEA-2ADB0D8D1E2E.mov",
        "file://@HOME@/.cache/aerial-wallpaper/videos/FE8E1F9D-59BA-4207-B626-28E34D810D0A.mov"
    ]

    function pickRandomAerial() {
        const idx = Math.floor(Math.random() * cachedAerialVideos.length);
        return cachedAerialVideos[idx];
    }

    function handleMessage(msg) {
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg
        }
        lockScreenRoot.uiVisible = true
    }

    property string pendingPassword

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    PlasmaClock.Clock {
        id: macTimeSource
        trackSeconds: false
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) {
                return;
            }
            const msg = i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed");
            lockScreenUi.handleMessage(msg);
            root.clearPassword();
            authenticator.startAuthenticating();
            notificationRemoveTimer.restart();
            rejectPasswordAnimation.start();
        }

        function onSucceeded() {
            authenticator.stopAuthenticating()

            if (!lockScreenUi.expectingPrompt) {
                Qt.quit()
            }
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"),
                    {
                        userListModel: users
                    },
                    StackView.Immediate,
                );
                mainStack.forceActiveFocus();
            }
        }

        function onInfoMessageChanged() {
            lockScreenUi.handleMessage(authenticator.infoMessage);
        }

        function onErrorMessageChanged() {
            lockScreenUi.handleMessage(authenticator.errorMessage);
        }

        function onPromptChanged() {
            lockScreenUi.handleMessage(authenticator.prompt);
        }
        function onPromptForSecretChanged() {
            mainBlock.showPassword = false;
            mainBlock.mainPasswordBox.forceActiveFocus();
            if (lockScreenUi.showPrompt) {
                lockScreenUi.handleMessage(authenticator.promptForSecret);
            }
        }
    }

    SessionManagement {
        id: sessionManagement
    }

    AccessibilityStatus {
        id: accessibilityStatus
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            root.clearPassword();
        }
    }

    RejectPasswordAnimation {
        id: rejectPasswordAnimation
        target: mainBlock
    }

    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: true
        property bool seenPositionChange: false
        property bool blockUI: containsMouse && (mainStack.depth > 1 || mainBlock.mainPasswordBox.text.length > 0 || Keyboards.KWinVirtualKeyboard.visible)

        x: parent.x
        y: parent.y
        width: parent.width
        height: parent.height
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: {
            uiVisible = seenPositionChange;
            seenPositionChange = true;
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate();
            }

            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
            authenticator.startAuthenticating();
        }

        Timer {
            interval: 1000
            running: !authenticator.unlocked && parent.uiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
        }

        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }
        ScreenLocker.ActiveScreenMonitor {
            id: activeScreenMonitor
            lockscreenState: ScreenLocker.LockscreenState
            window: lockScreenRoot.Window.window
            onActiveChanged: {
                if(!active) {
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Keys.onEscapePressed: {
            if (uiVisible) {
                uiVisible = false;
                if (Keyboards.KWinVirtualKeyboard.visible) {
                    Keyboards.KWinVirtualKeyboard.active = false;
                }
                root.clearPassword();
            }
        }
        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }
        Timer {
            id: fadeoutTimer
            interval: 30000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    mainBlock.mainPasswordBox.showPassword = false;
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }

        PropertyAnimation {
            id: launchAnimation
            target: lockScreenRoot
            property: "opacity"
            from: 0
            to: 1
            duration: Kirigami.Units.longDuration
        }

        // Instant MacTahoe 4K fallback wallpaper (never black)
        Image {
            anchors.fill: parent
            source: "file://@HOME@/.local/share/wallpapers/MacTahoe/contents/images/3840x2160.jpeg"
            fillMode: Image.PreserveAspectCrop
        }

        // Direct cached Aerial video player (plays immediately without network access)
        VideoOutput {
            id: lockVideoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            opacity: lockPlayer.playbackState === MediaPlayer.PlayingState ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
            }
        }

        MediaPlayer {
            id: lockPlayer
            videoOutput: lockVideoOutput
            loops: MediaPlayer.Infinite
            onErrorOccurred: (error, errorString) => {
                source = lockScreenUi.pickRandomAerial();
                play();
            }
        }

        Component.onCompleted: {
            launchAnimation.start();
            authenticator.startAuthenticating();
            lockPlayer.source = lockScreenUi.pickRandomAerial();
            lockPlayer.play();
        }

        // Subtle dark vignette at top and bottom so clock and avatar pop over live Aerial video
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

        // macOS Sonoma / Sequoia / Tahoe Top Clock & Date
        ColumnLayout {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.height * 0.095)
            spacing: -8
            visible: config.alwaysShowClock

            Text {
                id: macDateLabel
                text: Qt.formatDate(macTimeSource.dateTime, "dddd, MMMM d")
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: "SF Pro Display"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignHCenter
                layer.enabled: !lockScreenUi.softwareRendering
                layer.effect: DropShadow {
                    verticalOffset: 2
                    radius: 12
                    samples: 25
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
            }

            Text {
                id: macTimeLabel
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
                layer.enabled: !lockScreenUi.softwareRendering
                layer.effect: DropShadow {
                    verticalOffset: 4
                    radius: 20
                    samples: 32
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
            }
        }

        ListModel {
            id: users

            Component.onCompleted: {
                users.append({
                    name: kscreenlocker_userName,
                    realName: "@USER_FULLNAME@",
                    icon: kscreenlocker_userImage !== ""
                          ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                          : "file://@HOME@/.face.icon",
                })
            }
        }

        StackView {
            id: mainStack
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: Math.round(parent.height * 0.065)
            }
            height: 240
            focus: true
            visible: true

            initialItem: MainBlock {
                id: mainBlock
                lockScreenUiVisible: lockScreenRoot.uiVisible
                userListModel: users

                StackView.onStatusChanged: {
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear();
                        mainPasswordBox.focus = true;
                        root.notification = "";
                    }
                }

                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Caps Lock is on"));
                    }
                    if (accessibilityStatus.slowKeysEnabled) {
                        parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Slow Keys are enabled"));
                    }
                    if (root.notification) {
                        parts.push(root.notification);
                    }
                    return parts.join(" • ");
                }

                onPasswordResult: password => {
                    authenticator.respond(password)
                }
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
        }

        // Top-right macOS Lock Screen status bar (Keyboard layout + Battery)
        RowLayout {
            id: footer
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 10
                rightMargin: 18
            }
            spacing: 12

            PlasmaComponents3.ToolButton {
                id: keyboardButton
                focusPolicy: Qt.TabFocus
                icon.name: "input-keyboard"
                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                }
                text: keyboardLayoutSwitcher.layoutNames.shortName
                onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()
                visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts
            }

            Battery {}
        }
    }
}
