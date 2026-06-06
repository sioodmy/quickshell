import QtQuick
import Quickshell
import qs.theme
import qs.services

Rectangle {
    id: root

    property string targetMonitor: ""
    property Item currentActiveDot: null

    readonly property int animDurationShort: 150
    readonly property int dotHeight: 20
    readonly property int spacingAmount: 5

    implicitWidth: mainLayout.width + 12
    implicitHeight: mainLayout.height + 8
    color: Theme.surface_container
    radius: height / 2

    // The Global Sliding Highlight
    Rectangle {
        id: slidingHighlight

        property real targetX: {
            if (!currentActiveDot)
                return 0;
            let tx = 0;
            for (let i = 0; i < dotRepeater.count; i++) {
                let child = dotRepeater.itemAt(i);
                if (!child)
                    continue;
                if (child === currentActiveDot)
                    break;
                if (child.isVisible) {
                    tx += child.targetWidth + mainLayout.spacing;
                }
            }
            return tx;
        }

        y: mainLayout.y
        x: mainLayout.x + targetX
        width: currentActiveDot ? currentActiveDot.targetWidth : 0
        height: root.dotHeight
        radius: height / 2

        color: currentActiveDot?.isFocused ? (Theme.primary ?? "#6750A4") : (Theme.primary_container ?? "#EADDFF")
        Behavior on color {
            ColorAnimation {
                duration: root.animDurationShort
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }
    }

    Row {
        id: mainLayout
        anchors.centerIn: parent
        spacing: root.spacingAmount

        Repeater {
            id: dotRepeater
            model: NiriService.workspaces

            delegate: Item {
                id: workspaceDot

                readonly property bool isVisible: model.output === root.targetMonitor
                readonly property bool isFocused: model.isFocused
                readonly property bool isActive: model.isActive
                readonly property int wsId: model.id
                readonly property bool hasWindows: model.activeWindowId > 0

                visible: isVisible

                onIsFocusedChanged: if (isFocused)
                    root.currentActiveDot = workspaceDot
                onIsActiveChanged: if (isActive && !isFocused)
                    root.currentActiveDot = workspaceDot

                Component.onCompleted: {
                    if (isFocused || (isActive && !root.currentActiveDot)) {
                        root.currentActiveDot = workspaceDot;
                    }
                }

                readonly property real targetWidth: {
                    if (!isVisible)
                        return 0;
                    if (isFocused)
                        return 32;
                    if (isActive)
                        return 26;
                    if (hasWindows)
                        return dotHover.hovered ? 26 : 22;
                    return dotHover.hovered ? 24 : 20;
                }

                width: targetWidth
                height: root.dotHeight

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                Rectangle {
                    id: inactivePill
                    anchors.fill: parent
                    radius: height / 2

                    opacity: (workspaceDot.isFocused || workspaceDot.isActive) ? 0.0 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    color: dotHover.hovered ? (Theme.secondary_container ?? "#E8DEF8") : (Theme.surface_container_high ?? "#ECE6F0")
                    Behavior on color {
                        ColorAnimation {
                            duration: root.animDurationShort
                        }
                    }
                }

                scale: dotTap.pressed ? 0.92 : (dotHover.hovered ? 1.04 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.5
                    }
                }

                TapHandler {
                    id: dotTap
                    margin: 8
                    onTapped: NiriService.focusWorkspaceById(workspaceDot.wsId)
                }
                HoverHandler {
                    id: dotHover
                    margin: 8
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
