import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Controls
import "../theme"
import qs.services
import qs.components

PanelWindow {
    id: root

    // Centered window
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    screen: Quickshell.primaryScreen || null

    color: "transparent"
    visible: isActive

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "polkit"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    
    // Dim the background
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        opacity: isActive ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Prevent dismiss by clicking outside for security
            }
        }
    }

    property bool isActive: false
    property string currentActionId: ""
    property string currentMessage: ""
    property string currentIcon: ""
    property string currentCookie: ""
    property string currentUserName: ""
    property string currentPrompt: ""
    property bool isError: false
    property bool isYubikey: false

    Connections {
        target: BackendDaemon
        function onPolkitShowAuth(action_id, message, icon_name, cookie, user_name, prompt) {
            root.currentActionId = action_id;
            root.currentMessage = message;
            root.currentIcon = icon_name;
            root.currentCookie = cookie;
            root.currentUserName = user_name;
            root.currentPrompt = prompt;
            root.isError = false;
            
            // Check if Yubikey prompt
            root.isYubikey = prompt.toLowerCase().indexOf("touch") !== -1 || prompt.toLowerCase().indexOf("fido") !== -1 || prompt.toLowerCase().indexOf("yubikey") !== -1;
            
            passwordInput.text = "";
            root.isActive = true;
            if (!root.isYubikey) {
                passwordInput.forceActiveFocus();
            }
        }
        function onPolkitResult(cookie, success) {
            if (cookie === root.currentCookie) {
                if (success) {
                    root.isActive = false;
                } else {
                    root.isError = true;
                    passwordInput.text = "";
                    if (!root.isYubikey) {
                        passwordInput.forceActiveFocus();
                    }
                }
            }
        }
        function onPolkitDismiss(cookie) {
            if (cookie === root.currentCookie) {
                root.isActive = false;
            }
        }
    }

    Rectangle {
        id: dialog
        width: 420
        height: contentColumn.height + 48
        anchors.centerIn: parent
        color: Theme.surface_container_high
        radius: 28

        scale: root.isActive ? 1.0 : 0.95
        opacity: root.isActive ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Column {
            id: contentColumn
            width: parent.width - 48
            anchors.centerIn: parent
            spacing: 16

            Row {
                spacing: 16
                width: parent.width

                MaterialIcon {
                    icon: root.isYubikey ? "fingerprint" : "lock"
                    font.pixelSize: 32
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Authentication Required"
                    color: Theme.on_surface
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: root.currentMessage
                color: Theme.on_surface_variant
                font.pixelSize: 14
                width: parent.width
                wrapMode: Text.Wrap
            }
            
            StyledText {
                text: root.isError ? "Authentication failed. Try again." : (root.isYubikey ? root.currentPrompt : ("Password for " + root.currentUserName + ":"))
                color: root.isError ? Theme.error : Theme.on_surface
                font.pixelSize: 14
                width: parent.width
                wrapMode: Text.Wrap
                visible: true
            }

            Rectangle {
                width: parent.width
                height: 48
                radius: 12
                color: Theme.surface_container_highest
                visible: !root.isYubikey
                border.width: 1
                border.color: passwordInput.activeFocus ? Theme.primary : "transparent"

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    clip: true

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: "transparent"
                        font.pixelSize: 16
                        echoMode: TextInput.Normal
                        selectByMouse: false
                        cursorDelegate: Item {} // Hide native cursor

                        onAccepted: {
                            if (passwordInput.text.length > 0) {
                                BackendDaemon.polkitSubmit(root.currentCookie, passwordInput.text);
                            }
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Repeater {
                            model: passwordInput.text.length

                            Item {
                                id: shapeSlot
                                width: 11
                                height: 11
                                readonly property int kind: index % 3

                                Rectangle {
                                    visible: shapeSlot.kind === 0
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: width / 2
                                    color: Theme.on_surface
                                }

                                Rectangle {
                                    visible: shapeSlot.kind === 1
                                    anchors.centerIn: parent
                                    width: 9
                                    height: 9
                                    radius: 1.5
                                    color: Theme.on_surface
                                }

                                Shape {
                                    visible: shapeSlot.kind === 2
                                    anchors.centerIn: parent
                                    width: 11
                                    height: 10
                                    layer.enabled: shapeSlot.kind === 2
                                    layer.samples: 4

                                    ShapePath {
                                        fillColor: Theme.on_surface
                                        strokeWidth: 0
                                        startX: 5.5; startY: 0.5
                                        PathLine { x: 10.5; y: 9.5 }
                                        PathLine { x: 0.5; y: 9.5 }
                                        PathLine { x: 5.5; y: 0.5 }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: pwCaret
                            width: 2
                            height: 16
                            radius: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.primary
                            visible: passwordInput.activeFocus
                            opacity: 1

                            SequentialAnimation on opacity {
                                running: pwCaret.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: 530 }
                                PropertyAction { value: 0 }
                                PauseAnimation { duration: 530 }
                                PropertyAction { value: 1 }
                            }
                        }
                    }
                }
            }

            Item { height: 8; width: 1 } // Spacer

            Row {
                anchors.right: parent.right
                spacing: 12

                Rectangle {
                    width: cancelBtnRow.width + 32
                    height: 40
                    radius: 20
                    color: "transparent"
                    
                    Row {
                        id: cancelBtnRow
                        anchors.centerIn: parent
                        spacing: 8
                        
                        MaterialIcon {
                            icon: "close"
                            font.pixelSize: 18
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Cancel"
                            color: Theme.primary
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Theme.surface_container_highest
                        onExited: parent.color = "transparent"
                        onClicked: {
                            BackendDaemon.polkitCancel(root.currentCookie);
                            root.isActive = false;
                        }
                    }
                }

                Rectangle {
                    width: root.isYubikey ? 0 : authBtnRow.width + 40
                    height: root.isYubikey ? 0 : 40
                    radius: 20
                    color: Theme.primary
                    visible: !root.isYubikey
                    clip: true
                    
                    Row {
                        id: authBtnRow
                        anchors.centerIn: parent
                        spacing: 8
                        
                        MaterialIcon {
                            icon: "lock_open"
                            font.pixelSize: 18
                            color: Theme.on_primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Authenticate"
                            color: Theme.on_primary
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.8
                        onExited: parent.opacity = 1.0
                        onClicked: {
                            if (passwordInput.text.length > 0) {
                                BackendDaemon.polkitSubmit(root.currentCookie, passwordInput.text);
                            }
                        }
                    }
                }
            }
        }
    }
}
