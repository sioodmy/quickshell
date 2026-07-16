import QtQuick
import QtQuick.Effects
import "../../theme"

Item {
    id: root

    property real value: 0.0
    property string label: ""
    property string icon: ""
    property string valueText: Math.round(value * 100) + "%"
    property color accent: Theme.primary
    property bool active: false

    signal moved(real v)

    implicitHeight: 72
    opacity: active ? 1 : 0
    visible: opacity > 0.02

    Behavior on opacity {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    function nudge(delta) {
        var v = Math.max(0, Math.min(1, value + delta));
        value = v;
        moved(v);
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        radius: 20
        color: Theme.surface_container_high
        clip: true

        Rectangle {
            id: fill
            height: parent.height
            radius: parent.radius
            width: Math.max(height, parent.width * Math.min(1, Math.max(0, root.value)))
            color: root.accent

            Behavior on width {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 14

            Text {
                id: iconText
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 22
                }
                color: root.value > 0.12 ? Theme.on_primary : Theme.on_surface

                scale: 1.0
                onTextChanged: iconBounce.restart()
                SequentialAnimation {
                    id: iconBounce
                    NumberAnimation { target: iconText; property: "scale"; to: 1.25; duration: 100; easing.type: Easing.OutQuad }
                    NumberAnimation { target: iconText; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBounce }
                }

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - iconText.width - percentLabel.width - parent.spacing * 2
                height: labelText.implicitHeight

                Text {
                    id: labelText
                    text: root.label
                    color: root.value > 0.25 ? Theme.on_primary : Theme.on_surface
                    font {
                        family: "Google Sans"
                        pixelSize: 15
                        weight: Font.DemiBold
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            Text {
                id: percentLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.valueText
                font {
                    family: "Google Sans"
                    pixelSize: 14
                    weight: Font.Medium
                }
                color: root.value > 0.85 ? Theme.on_primary : Theme.on_surface
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function apply(mx) {
                var v = Math.max(0, Math.min(1, mx / width));
                root.value = v;
                root.moved(v);
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
        }
    }
}
