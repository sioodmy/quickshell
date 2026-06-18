import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 10

    property var items: []
    property int pageSize: 5
    property bool showAll: false

    readonly property var visibleItems: showAll ? items : items.slice(0, pageSize)
    readonly property bool hasMore: items.length > pageSize

    function refresh() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        command: ["bash", "-c", Quickshell.shellPath("scripts/cliphist-visual.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = this.text.split('\n').filter(l => l.trim() !== "").map(line => {
                    let parts = line.split('\t');
                    return {
                        "raw": parts[0] + '\t' + (parts[1] || ""),
                        "display": parts[1] || "",
                        "imagePath": parts[2] || ""
                    };
                });
            }
        }
    }

    Process {
        id: copyProc
        property string selectedRaw: ""
        command: ["bash", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "_", selectedRaw]
    }

    Process {
        id: wipeProc
        command: ["bash", "-c", "cliphist wipe"]
        onRunningChanged: if (!running) root.refresh()
    }

    Component.onCompleted: refresh()

    // Header
    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Clipboard"
            color: Theme.on_surface
            font { family: "Google Sans"; pixelSize: 15; weight: Font.DemiBold }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.items.length > 0
            text: "Clear"
            color: clearMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: wipeProc.running = true
            }
        }
    }

    Text {
        visible: root.items.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Clipboard is empty"
        color: Theme.on_surface_variant
        font { family: "Google Sans"; pixelSize: 13 }
        topPadding: 8
        bottomPadding: 8
    }

    Repeater {
        model: root.visibleItems

        Rectangle {
            id: clip
            required property var modelData

            width: parent.width
            height: 44
            radius: 14
            color: clipMouse.containsMouse
                ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                : Theme.surface_container_high

            Behavior on color { ColorAnimation { duration: 120 } }

            Image {
                id: thumb
                visible: clip.modelData.imagePath && clip.modelData.imagePath.length > 0
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                source: visible ? ("file://" + clip.modelData.imagePath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Text {
                anchors.left: thumb.visible ? thumb.right : parent.left
                anchors.leftMargin: thumb.visible ? 10 : 14
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: clip.modelData.imagePath && clip.modelData.imagePath.length > 0
                    ? "Image"
                    : (clip.modelData.display || "").trim()
                color: Theme.on_surface
                font { family: "Google Sans"; pixelSize: 13 }
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    copyProc.selectedRaw = clip.modelData.raw;
                    copyProc.running = true;
                    ControlCenter.hide();
                }
            }
        }
    }

    Rectangle {
        visible: root.hasMore
        width: parent.width
        height: 34
        radius: 17
        color: showMoreMouse.containsMouse
            ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
            : Theme.surface_container_high

        Text {
            anchors.centerIn: parent
            text: root.showAll
                ? "Show less"
                : ("Show " + (root.items.length - root.pageSize) + " more")
            color: showMoreMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
        }

        MouseArea {
            id: showMoreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showAll = !root.showAll
        }
    }
}
