pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland

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

            Rectangle {
                id: bezelBackground
                anchors.fill: parent
                color: Theme.surface
                layer.enabled: true
                layer.mipmap: false

                // Subtracts the cutoutShape from the solid surface and adds an inner shadow
                layer.effect: MultiEffect {
                    maskSource: cutoutShape
                    maskEnabled: true
                    maskInverted: true
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                    
                    shadowEnabled: true
                    shadowColor: "#B0000000"
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                    blurMax: 20
                    shadowBlur: 0.5
                }
            }

            /**
             * Cutout Definition
             * Defines the area where the desktop remains visible.
             */
            Item {
                id: cutoutShape
                anchors.fill: parent
                visible: false // Source item only

                Rectangle {
                    id: clippingRect
                    anchors.fill: parent
                    radius: Layout.cornerRadius
                }
            }
        }
    }
}
