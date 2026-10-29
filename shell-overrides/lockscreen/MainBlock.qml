/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt5Compat.GraphicalEffects

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

FocusScope {
    id: sessionManager

    property bool passwordInputVisible: true
    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: true
    property bool showPassword: false
    property var userListModel: null
    property string notificationMessage: ""
    property Item authenticationTypeItem: null
    property list<Item> actionItems
    property Item userList: avatarContainer

    signal passwordResult(string password)
    signal userSelected()

    function playHighlightAnimation() {
        bounceAnimation.start();
    }

    function startLogin() {
        const password = passwordBox.text;
        loginButton.forceActiveFocus();
        passwordResult(password);
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        // Circular User Avatar (macOS bottom stack)
        Item {
            id: avatarContainer
            Layout.alignment: Qt.AlignHCenter
            width: 56
            height: 56

            Image {
                id: avatarImg
                anchors.fill: parent
                source: "file://@HOME@/.face.icon"
                sourceSize: Qt.size(112, 112)
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: 28
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: avatarImg
                maskSource: avatarMask
                layer.enabled: true
                layer.effect: DropShadow {
                    verticalOffset: 2
                    radius: 10
                    samples: 20
                    color: Qt.rgba(0, 0, 0, 0.5)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.35)
                border.width: 1
            }
        }

        // User Full Name
        Text {
            text: "@USER_FULLNAME@"
            color: Qt.rgba(1, 1, 1, 0.95)
            font.family: "SF Pro Display"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignHCenter
            layer.enabled: true
            layer.effect: DropShadow {
                verticalOffset: 1
                radius: 6
                samples: 15
                color: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        // Frosted Glass Pill Password Input ("Enter Password")
        Rectangle {
            id: passwordPill
            Layout.alignment: Qt.AlignHCenter
            width: 196
            height: 30
            radius: 15
            color: Qt.rgba(1, 1, 1, 0.22)
            border.color: Qt.rgba(1, 1, 1, 0.38)
            border.width: 1
            visible: sessionManager.passwordInputVisible

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 4
                spacing: 4

                QQC2.TextField {
                    id: passwordBox
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: true
                    echoMode: sessionManager.showPassword ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: "white"
                    selectionColor: Qt.rgba(1, 1, 1, 0.35)
                    selectedTextColor: "white"
                    font.family: "SF Pro Text"
                    font.pixelSize: 13
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "Enter Password"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.65)
                    background: Item {}

                    text: PasswordSync.password
                    cursorVisible: visible && text.length > 0

                    onAccepted: {
                        sessionManager.startLogin();
                    }

                    Connections {
                        target: root
                        function onClearPassword() {
                            passwordBox.forceActiveFocus();
                            passwordBox.text = "";
                            passwordBox.text = Qt.binding(() => PasswordSync.password);
                        }
                        function onNotificationRepeated() {
                            sessionManager.playHighlightAnimation();
                        }
                    }
                }

                Binding {
                    target: PasswordSync
                    property: "password"
                    value: passwordBox.text
                }

                // Circular Submit Arrow inside the pill (shows when typing)
                Rectangle {
                    id: loginButton
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 11
                    color: Qt.rgba(1, 1, 1, passwordBox.text.length > 0 ? 0.32 : 0.0)
                    border.color: Qt.rgba(1, 1, 1, passwordBox.text.length > 0 ? 0.6 : 0.0)
                    border.width: 1
                    opacity: passwordBox.text.length > 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        color: "white"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sessionManager.startLogin()
                    }
                }
            }
        }

        // Notification / Error label below pill
        Text {
            id: notificationsLabel
            text: sessionManager.notificationMessage || "Touch ID or Enter Password"
            color: sessionManager.notificationMessage ? Qt.rgba(1, 0.65, 0.65, 0.95) : Qt.rgba(1, 1, 1, 0.55)
            font.family: "SF Pro Text"
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter

            SequentialAnimation {
                id: bounceAnimation
                loops: 1
                PropertyAnimation {
                    target: notificationsLabel
                    properties: "scale"
                    from: 1.0
                    to: 1.1
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutQuad
                }
                PropertyAnimation {
                    target: notificationsLabel
                    properties: "scale"
                    from: 1.1
                    to: 1.0
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InQuad
                }
            }
        }
    }
}
