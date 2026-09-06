import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services
import qs.components

Row {
    id: root
    spacing: 12

    property string message: ""
    property string iconName: ""
    property string cookie: ""
    property string userName: ""
    property string prompt: ""
    property bool hasError: false
    property bool isYubikey: false

    signal cancelRequested()
    signal submitRequested(string password)

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.isYubikey ? "fingerprint" : "lock"
        font.pixelSize: 24
        color: Theme.primary
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: 350

        Text {
            text: root.message
            color: "#ffffff"
            font.family: "Google Sans Medium"
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            width: parent.width
        }
        Text {
            text: root.hasError ? "Authentication failed" : (root.isYubikey ? root.prompt : ("Password for " + root.userName))
            color: root.hasError ? Theme.error : "#bbbbbb"
            font.family: "Google Sans"
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width
        }
    }

    Rectangle {
        width: 250
        height: 32
        anchors.verticalCenter: parent.verticalCenter
        radius: 16
        color: Theme.surface_container_highest
        visible: !root.isYubikey
        border.width: 1
        border.color: polkitInput.activeFocus ? Theme.primary : "transparent"
        clip: true

        TextInput {
            id: polkitInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: "transparent"
            font.pixelSize: 14
            echoMode: TextInput.Normal
            selectByMouse: false
            cursorDelegate: Item {}

            Keys.onEscapePressed: root.cancelRequested()

            onAccepted: {
                if (text.length > 0) {
                    root.submitRequested(text);
                }
            }
        }
        
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Repeater {
                model: polkitInput.text.length

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
                        color: "#ffffff"
                    }

                    Rectangle {
                        visible: shapeSlot.kind === 1
                        anchors.centerIn: parent
                        width: 9
                        height: 9
                        radius: 1.5
                        color: "#ffffff"
                    }

                    Shape {
                        visible: shapeSlot.kind === 2
                        anchors.centerIn: parent
                        width: 11
                        height: 10
                        antialiasing: true

                        ShapePath {
                            fillColor: "#ffffff"
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
                visible: polkitInput.activeFocus
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

        Component.onCompleted: {
            if (!root.isYubikey) {
                polkitInput.forceActiveFocus();
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: cancelMouse.containsMouse ? Theme.surface_variant : "transparent"
            
            MaterialIcon {
                anchors.centerIn: parent
                icon: "close"
                font.pixelSize: 18
                color: Theme.on_surface
            }
            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cancelRequested()
            }
        }
        
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: Theme.primary
            visible: !root.isYubikey
            opacity: authMouse.containsMouse ? 0.8 : 1.0
            
            MaterialIcon {
                anchors.centerIn: parent
                icon: "check"
                font.pixelSize: 18
                color: Theme.on_primary
            }
            MouseArea {
                id: authMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (polkitInput.text.length > 0) {
                        root.submitRequested(polkitInput.text);
                    }
                }
            }
        }
    }
}
