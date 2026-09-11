import QtQuick
import qs.theme
import qs.services
import qs.components

Row {
    id: root
    spacing: 12

    signal dismissed()

    Rectangle {
        id: previewContainer
        width: 142
        height: 80
        radius: 12
        color: Theme.surface_container_high
        clip: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                FileStash.addPath(Screenshot.imagePath);
                Screenshot.dismiss();
                root.dismissed();
            }
        }

        Image {
            id: previewImg
            anchors.fill: parent
            source: Screenshot.imagePath ? ("file://" + Screenshot.imagePath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 400
            visible: status === Image.Ready
        }

        // Placeholder while grim is still writing / image is loading.
        Text {
            anchors.centerIn: parent
            visible: previewImg.status !== Image.Ready
            text: Screenshot.awaitingCapture ? "…" : "No preview"
            color: Theme.on_surface_variant
            font.family: "Google Sans"
            font.pixelSize: 12
        }
    }

    Grid {
        anchors.verticalCenter: parent.verticalCenter
        columns: 2
        spacing: 8

        component ActionPill: Rectangle {
            id: pill
            property string icon
            property string label
            property bool done: false
            property bool busy: false
            signal triggered()

            width: 96
            height: 36
            radius: 18
            color: {
                if (done) return Qt.alpha(Theme.primary, 0.18);
                if (pillMouse.containsMouse) return Qt.alpha(Theme.primary, 0.14);
                return Qt.alpha(Theme.on_surface, 0.08);
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: pillMouse.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Row {
                anchors.centerIn: parent
                spacing: 6
                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: pill.done ? "check" : (pill.busy ? "sync" : pill.icon)
                    font.pixelSize: 13
                    color: pill.done ? Theme.primary : Theme.on_surface_variant
                    RotationAnimation on rotation {
                        running: pill.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.label
                    font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                    color: pill.done ? Theme.primary : Theme.on_surface
                }
            }
            MouseArea {
                id: pillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pill.triggered()
            }
        }

        Timer { id: closeDelayTimer; interval: 400; onTriggered: { Screenshot.dismiss(); root.dismissed(); } }

        ActionPill {
            icon: "content_copy"
            label: "Copy"
            done: Screenshot.wasCopied
            onTriggered: { Screenshot.copyToClipboard(); closeDelayTimer.start(); }
        }
        ActionPill {
            icon: "save"
            label: "Save"
            done: Screenshot.wasSaved
            onTriggered: { Screenshot.save(); closeDelayTimer.start(); }
        }
        ActionPill {
            icon: "edit"
            label: "Draw"
            onTriggered: { Screenshot.editorActive = true; root.dismissed(); }
        }
        ActionPill {
            icon: "text_fields"
            label: "OCR Text"
            done: Screenshot.wasOcred
            busy: Screenshot.ocring
            onTriggered: Screenshot.ocr()
        }
    }
}
