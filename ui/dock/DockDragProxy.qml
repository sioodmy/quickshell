import QtQuick
import "../theme"

Item {
    id: root

    property real dragX: 0
    property real dragY: 0
    property Item draggingApp: null
    property bool dropHoverActive: false

    property real followX: dragX
    property real followY: dragY
    property bool active: draggingApp !== null
    // Animations write here so they don't break the scale binding
    property real popBoost: 1.0
    property real wobbleSpin: 0

    width: 40
    height: 40
    x: followX - width / 2
    y: followY - height / 2
    z: 100
    visible: active
    opacity: active ? 1 : 0
    transformOrigin: Item.Center
    rotation: wobbleSpin

    scale: {
        var base = 0.4
        if (active)
            base = root.dropHoverActive ? 1.35 : 1.15
        return base * popBoost
    }

    onActiveChanged: {
        if (active) {
            followBehaviorX.enabled = false
            followBehaviorY.enabled = false
            followX = root.dragX
            followY = root.dragY
            followBehaviorX.enabled = true
            followBehaviorY.enabled = true
            popBoost = 1.0
            grabPop.restart()
            wobbleLoop.restart()
        } else {
            wobbleLoop.stop()
            wobbleSpin = 0
            popBoost = 1.0
        }
    }

    onDragXChanged: {
        if (root.active)
            root.followX = root.dragX
    }

    onDragYChanged: {
        if (root.active)
            root.followY = root.dragY
    }

    Behavior on followX {
        id: followBehaviorX
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }
    Behavior on followY {
        id: followBehaviorY
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 2.8
        }
    }
    Behavior on opacity { NumberAnimation { duration: 90 } }

    SequentialAnimation {
        id: grabPop
        NumberAnimation {
            target: root
            property: "popBoost"
            to: 1.25
            duration: 90
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "popBoost"
            to: 1.0
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }
    }

    SequentialAnimation {
        id: wobbleLoop
        loops: Animation.Infinite
        NumberAnimation {
            target: root
            property: "wobbleSpin"
            to: 16
            duration: 90
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "wobbleSpin"
            to: -14
            duration: 160
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "wobbleSpin"
            to: 10
            duration: 130
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "wobbleSpin"
            to: -6
            duration: 110
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "wobbleSpin"
            to: 0
            duration: 90
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 14
        height: parent.height + 14
        radius: width / 2
        color: Qt.alpha(Theme.primary, root.dropHoverActive ? 0.45 : 0.22)
        scale: root.dropHoverActive ? 1.2 : 1.0
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
        }
    }

    Image {
        anchors.centerIn: parent
        width: parent.width * 0.88
        height: parent.height * 0.88
        fillMode: Image.PreserveAspectFit
        mipmap: true
        source: {
            if (!root.draggingApp)
                return ""
            var icon = root.draggingApp.itemData
                ? (root.draggingApp.itemData.icon || "")
                : ""
            if (!icon || icon === "")
                return "image://icon/application-x-executable"
            if (icon.startsWith("/"))
                return "file://" + icon
            return "image://icon/" + icon
        }
    }
}
