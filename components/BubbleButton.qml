import QtQuick
import "../theme"

/**
 * Apple-liquid capsule control — luminous bubble on glass, not frosted-on-frosted.
 *
 * variant: "neutral" | "accent" | "secondary" | "tertiary" | "critical"
 */
Rectangle {
    id: root

    property string variant: "neutral"
    property bool filled: false
    property bool selected: false
    property string icon: ""
    property string label: ""
    property color contentColor: {
        if (variant === "accent" || (filled && variant === "neutral"))
            return Theme.primary;
        if (variant === "secondary")
            return Theme.secondary;
        if (variant === "tertiary")
            return Theme.tertiary;
        if (variant === "critical")
            return Theme.critical;
        return Theme.on_surface;
    }
    property real iconSize: 14
    property real fontSize: 12
    property real horizontalPadding: 14
    property bool showBorder: true

    signal clicked()

    implicitWidth: Math.max(height, row.implicitWidth + horizontalPadding * 2)
    implicitHeight: 32
    radius: height / 2

    readonly property color _idle: {
        if (variant === "critical")
            return filled ? Theme.bubble_critical : Theme.bubble_critical_soft;
        if (variant === "accent")
            return filled ? Theme.bubble_accent : Theme.bubble_accent_soft;
        if (variant === "secondary")
            return filled ? Theme.bubble_secondary : Theme.bubble_secondary_soft;
        if (variant === "tertiary")
            return filled ? Theme.bubble_tertiary : Theme.bubble_tertiary_soft;
        return Theme.bubble;
    }
    readonly property color _hover: {
        if (variant === "critical")
            return Theme.bubble_critical;
        if (variant === "accent")
            return Theme.bubble_accent;
        if (variant === "secondary")
            return Theme.bubble_secondary;
        if (variant === "tertiary")
            return Theme.bubble_tertiary;
        return Theme.bubble_hover;
    }

    color: (mouse.containsMouse || selected) ? _hover : _idle
    border.width: showBorder ? 1 : 0
    border.color: {
        if (selected || filled) {
            if (variant === "critical") return Qt.alpha(Theme.critical, 0.55);
            if (variant === "secondary") return Qt.alpha(Theme.secondary, 0.5);
            if (variant === "tertiary") return Qt.alpha(Theme.tertiary, 0.5);
            if (variant === "accent" || filled) return Qt.alpha(Theme.primary, 0.5);
        }
        return Theme.bubble_border;
    }

    scale: mouse.pressed ? 0.94 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    BubbleSheen {}

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        z: 1

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            font.pixelSize: root.iconSize
            color: root.contentColor
        }

        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.contentColor
            font {
                family: "Google Sans"
                pixelSize: root.fontSize
                weight: Font.Medium
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
