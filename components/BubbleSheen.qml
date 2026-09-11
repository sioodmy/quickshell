import QtQuick
import "../theme"

/**
 * Soft top specular for liquid bubble controls.
 * Fills the parent with a matching radius so it never reads as a second
 * rounded box peeking out from behind the capsule.
 */
Item {
    id: root
    anchors.fill: parent
    z: 0
    // Don't steal clicks from the parent control.
    enabled: false

    readonly property real matchedRadius: {
        if (parent && parent.radius !== undefined)
            return parent.radius;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.matchedRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bubble_sheen }
            GradientStop { position: 0.38; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 0.65; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
