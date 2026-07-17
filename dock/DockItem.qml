import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../theme"
import qs.services

/**
 * Simplified vertical bar dock item.
 * No borders, no running dots, smaller icons.
 */
Item {
    id: root

    property var itemData: ({})
    property bool isLauncher: false
    property bool isSidebarToggle: false

    readonly property string desktopId: itemData.desktopId || ""
    readonly property string appName: isLauncher ? "Launcher" : (isSidebarToggle ? "Sidebar" : (itemData.name || desktopId))
    readonly property string appIcon: isLauncher || isSidebarToggle ? "" : (itemData.icon || "")
    readonly property bool isRunning: isLauncher || isSidebarToggle ? false : (itemData.running || false)
    readonly property bool isPinned: isLauncher || isSidebarToggle ? true : (itemData.pinned || false)
    readonly property bool isAppFocused: !isLauncher && !isSidebarToggle && (itemData.windows ? itemData.windows.some(function(w) { return w.isFocused; }) : false)

    // Signals for parent
    signal hoverChanged(bool hovered)
    signal contextMenuRequested()

    property bool isHovered: hover.hovered

    readonly property int slotSize: Math.min(width, height)
    readonly property int effectiveIconSize: slotSize > 0 ? Math.round(slotSize * 0.92) : 22

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
        
        // Keep scale modest — OutBack overshoot was letting icons spill past workspace pills
        scale: leftTap.pressed ? 0.88 : (hover.hovered ? 1.06 : (root.isAppFocused ? 1.03 : (root.isRunning ? 0.9 : 1.0)))
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Hover overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Launcher / Sidebar icon
        Text {
            anchors.centerIn: parent
            visible: root.isLauncher || root.isSidebarToggle
            text: root.isLauncher ? "" : "󰍜" // Search icon for launcher, sidebar icon for sidebar
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 16
            }
            color: Theme.on_surface
        }

        // App icon
        Image {
            id: appIconImage
            anchors.centerIn: parent
            width: root.effectiveIconSize
            height: root.effectiveIconSize
            visible: !root.isLauncher && !root.isSidebarToggle
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
                if (root.isLauncher || root.isSidebarToggle) return "";
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
            visible: !root.isLauncher && !root.isSidebarToggle && appIconImage.status === Image.Error
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
        onTapped: {
            if (root.isLauncher) {
                Quickshell.execDetached({ command: ["quickshell", "ipc", "call", "appLauncher", "toggle"] });
            } else if (root.isSidebarToggle) {
                Quickshell.execDetached({ command: ["quickshell", "ipc", "call", "sidebar", "toggle"] });
            } else {
                DockBackend.activateApp(root.desktopId);
            }
        }
    }

    TapHandler {
        id: rightTap
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (!root.isLauncher && !root.isSidebarToggle) root.contextMenuRequested();
        }
    }

    signal dragStarted()
    signal dragUpdated(real globalX, real globalY)
    signal dragEnded(real globalX, real globalY)

    DragHandler {
        id: dragHandler
        target: null
        enabled: !root.isLauncher && !root.isSidebarToggle
        
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
