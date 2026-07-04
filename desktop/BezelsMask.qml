pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland

import qs.services
import QtQuick
import QtQuick.Effects
import "../theme"

/**
 * Creates aesthetic rounded bezels across all connected monitors.
 * Uses an XOR region mask and an inverted MultiEffect mask to
 * render a solid surface with a transparent "cutout" for the workspace.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: bezelWindow

        // --- Model Integration ---
        required property var modelData
        screen: modelData

        // --- Window Configuration ---
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-bezels"
        WlrLayershell.exclusiveZone: -1 // Passthrough; do not reserve space

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // --- Input & Visual Masking ---
        // XOR intersection ensures clicks pass through the center cutout
        mask: Region {
            item: effectContainer
            intersection: Intersection.Xor
        }

        Item {
            id: effectContainer
            anchors.fill: parent

            Item {
                id: bezelLayer
                anchors.fill: parent
                layer.enabled: true

                // Primary Drop Shadow for the bezel edges
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#B0000000"
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                    blurMax: 20
                    shadowBlur: 0.5
                }

                Rectangle {
                    id: bezelBackground
                    anchors.fill: parent
                    color: Theme.surface
                    layer.enabled: true

                    // Subtracts the cutoutShape from the solid surface
                    layer.effect: MultiEffect {
                        maskSource: cutoutShape
                        maskEnabled: true
                        maskInverted: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }

                /**
                 * Cutout Definition
                 * Defines the area where the desktop remains visible.
                 */
                Item {
                    id: cutoutShape
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false // Source item only

                    Rectangle {
                        id: clippingRect
                        anchors.fill: parent

                        // Margins
                        anchors {
                            leftMargin: Layout.sideBarWidth
                            rightMargin: 0
                            topMargin: Layout.topBarHeight
                            bottomMargin: Layout.bottomBarHeight
                        }

                        radius: Layout.cornerRadius
                    }

                    // Cut out the bars themselves so the bezel doesn't draw over them and block clicks!
                    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: Layout.sideBarWidth }
                    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: Layout.topBarHeight }
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: Layout.bottomBarHeight }
                }
            }
        }
    }
}
