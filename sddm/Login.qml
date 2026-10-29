import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

FocusScope {
    id: root
    property Item mainPasswordBox: passwordBox
    property bool showUsernamePrompt: false
    property string lastUserName
    property bool loginScreenUiVisible: true
    property var userListModel: null
    property int userListCurrentIndex: 0
    property bool showUserList: true
    property string notificationMessage: ""
    property Item userList: avatarContainer
    property bool actionItemsVisible: false
    property list<Item> actionItems

    signal loginRequest(string username, string password)

    function startLogin() {
        const username = lastUserName || "@USER@";
        const password = passwordBox.text;
        loginRequest(username, password);
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Item {
            id: avatarContainer
            Layout.alignment: Qt.AlignHCenter
            width: 56
            height: 56

            Image {
                id: avatarImg
                anchors.fill: parent
                source: Qt.resolvedUrl("faces/.face.icon")
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

        Rectangle {
            id: passwordPill
            Layout.alignment: Qt.AlignHCenter
            width: 196
            height: 30
            radius: 15
            color: Qt.rgba(1, 1, 1, 0.22)
            border.color: Qt.rgba(1, 1, 1, 0.38)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 4
                spacing: 4

                QQC2.TextField {
                    id: passwordBox
                    property bool showPassword: false
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: true
                    echoMode: showPassword ? TextInput.Normal : TextInput.Password
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

                    onAccepted: root.startLogin()

                    Connections {
                        target: sddm
                        function onLoginFailed() {
                            passwordBox.clear();
                            passwordBox.forceActiveFocus();
                        }
                    }
                }

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
                        onClicked: root.startLogin()
                    }
                }
            }
        }

        Text {
            text: root.notificationMessage || "Enter Password to Unlock"
            color: root.notificationMessage ? Qt.rgba(1, 0.65, 0.65, 0.95) : Qt.rgba(1, 1, 1, 0.55)
            font.family: "SF Pro Text"
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
