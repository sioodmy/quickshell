import QtQuick
import qs.theme

/** Android-style filled slider with an inline icon and percentage. */
Item {
    id: ctrl

    property real value: 0.0          // 0..1
    property string icon: ""
    property color accent: Theme.primary
    property bool enabledControl: true

    signal moved(real v)

    implicitHeight: 48

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface_container_high
        opacity: ctrl.enabledControl ? 1.0 : 0.5

        Rectangle {
            id: fill
            height: parent.height
            radius: parent.radius
            width: Math.max(height, parent.width * Math.min(1, Math.max(0, ctrl.value)))
            color: ctrl.accent

            Behavior on width {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: ctrl.icon
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
            color: Theme.on_primary
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(ctrl.value * 100) + "%"
            font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
            color: Theme.on_surface
        }

        MouseArea {
            anchors.fill: parent
            enabled: ctrl.enabledControl
            cursorShape: Qt.PointingHandCursor

            function apply(mx) {
                let v = Math.max(0, Math.min(1, mx / width));
                ctrl.value = v;
                ctrl.moved(v);
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
        }
    }
}
