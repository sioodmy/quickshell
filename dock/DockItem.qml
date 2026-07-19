import QtQuick
import "../theme"

/**
 * Simplified vertical bar dock item.
 * No borders, no running dots, smaller icons.
 */
Item {
    id: root

    property var itemData: ({})

    readonly property string desktopId: itemData.desktopId || ""
    readonly property string appName: itemData.name || desktopId
    readonly property string appIcon: itemData.icon || ""

    // Signals for parent
    signal hoverChanged(bool hovered)
    signal contextMenuRequested()

    property bool isHovered: hover.hovered

    readonly property int slotSize: Math.min(width, height)
    readonly property int effectiveIconSize: slotSize > 0 ? Math.round(slotSize * 0.95) : 22

    width: 32
    height: 32

    // --- Main icon container ---
    Rectangle {
        id: iconBg
        anchors.centerIn: parent
        width: root.slotSize
        height: root.slotSize
        radius: width / 2
        transformOrigin: Item.Center
        
        // Transparent by default, highlight on hover
        color: "transparent"
        
        // Stay inside the slot — hover/press only, never grow past the layout box
        scale: leftTap.pressed ? 0.9 : (hover.hovered ? 1.03 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Hover overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // App icon
        Image {
            id: appIconImage
            anchors.centerIn: parent
            width: root.effectiveIconSize
            height: root.effectiveIconSize
            fillMode: Image.PreserveAspectFit
            mipmap: true

            property var tryIcons: {
                var icon = root.appIcon;
                if (!icon || icon === "") return ["application-x-executable"];
                if (icon.startsWith("/")) return [icon];
                return [icon, icon.toLowerCase(), icon.toLowerCase() + "-desktop", "application-x-executable"];
            }
            property int tryIndex: 0

            source: {
                var icon = tryIcons[0];
                if (icon.startsWith("/")) return "file://" + icon;
                return "image://icon/" + icon;
            }

            onStatusChanged: {
                if (status === Image.Error && tryIndex < tryIcons.length - 1) {
                    tryIndex++;
                    var icon = tryIcons[tryIndex];
                    source = icon.startsWith("/") ? ("file://" + icon) : ("image://icon/" + icon);
                }
            }
        }

        // Fallback text icon
        Text {
            anchors.centerIn: parent
            visible: appIconImage.status === Image.Error
            text: root.appName.length > 0 ? root.appName.charAt(0).toUpperCase() : "?"
            font {
                family: "Google Sans"
                pixelSize: Math.max(11, Math.round(root.effectiveIconSize * 0.68))
                weight: Font.Bold
            }
            color: Theme.on_surface
        }
    }

    // --- Pointer Handlers ---
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: root.hoverChanged(hovered)
    }

    TapHandler {
        id: leftTap
        acceptedButtons: Qt.LeftButton
        onTapped: DockBackend.activateApp(root.desktopId)
    }

    TapHandler {
        id: rightTap
        acceptedButtons: Qt.RightButton
        onTapped: root.contextMenuRequested()
    }

    signal dragStarted()
    signal dragUpdated(real globalX, real globalY)
    signal dragEnded(real globalX, real globalY)

    DragHandler {
        id: dragHandler
        target: null
        
        onActiveChanged: {
            if (active) {
                root.dragStarted();
            } else {
                var globalPos = mapToItem(null, dragHandler.translation.x + width / 2, dragHandler.translation.y + height / 2);
                root.dragEnded(globalPos.x, globalPos.y);
            }
        }
        onTranslationChanged: {
            var globalPos = mapToItem(null, dragHandler.translation.x + width / 2, dragHandler.translation.y + height / 2);
            root.dragUpdated(globalPos.x, globalPos.y);
        }
    }
}
