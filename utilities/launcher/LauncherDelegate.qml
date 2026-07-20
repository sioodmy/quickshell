import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../../theme"
import qs.services

Item {
    id: delegateRoot
    width: ListView.view.width
    
    property bool isWolfram: itemType === "action" && modelData.actionId === "wolfram"
    property bool isDictionary: itemType === "action" && modelData.actionId === "dictionary"
    property bool hasExpanded: (isWolfram && ctrl.backendqsSvg !== "") || (isDictionary && ctrl.dictStatus === "ok")
    
    height: {
        if (!hasExpanded) return 72;
        if (isWolfram) return 180;
        if (isDictionary) return 72 + dictContent.height + 16;
        return 72;
    }
    
    Behavior on height {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    property bool isSelected: ListView.isCurrentItem
    property bool isHovered: itemMouseArea.containsMouse

    // Determine item type
    property string itemType: modelData.type || "app"

    // App properties
    property string descriptionText: {
        if (itemType === "app") {
            var e = modelData.entry;
            return e && e.genericName ? e.genericName : (e && e.comment ? e.comment : "");
        } else if (itemType === "focus") {
            return modelData.windowTitle || "";
        } else if (itemType === "emoji") {
            return "";
        } else if (itemType === "action") {
            return modelData.description || "";
        } else if (itemType === "music_album") {
            return modelData.album.artist || "";
        } else if (itemType === "music_track") {
            return modelData.album.artist + " • " + modelData.album.title;
        } else if (itemType === "file") {
            return modelData.file ? modelData.file.dir : "";
        } else if (itemType === "system_command") {
            return modelData.description || "";
        } else if (itemType === "bookmark") {
            return modelData.bookmark ? modelData.bookmark.url : "";
        }
        return "";
    }

    property string nameText: {
        if (itemType === "app" || itemType === "focus") {
            return modelData.entry ? modelData.entry.name : "";
        } else if (itemType === "emoji") {
            return modelData.display || "";
        } else if (itemType === "action") {
            return modelData.name || "";
        } else if (itemType === "music_album") {
            return modelData.album.title || "";
        } else if (itemType === "music_track") {
            return modelData.track.title || "";
        } else if (itemType === "file") {
            return modelData.file ? modelData.file.name : "";
        } else if (itemType === "system_command") {
            return modelData.name || "";
        } else if (itemType === "bookmark") {
            return modelData.bookmark ? modelData.bookmark.name : "";
        }
        return "";
    }

    function activate(shiftHeld) {
        if (itemType === "app") {
            ctrl.launchApp(modelData.entry);
        } else if (itemType === "focus") {
            ctrl.focusWindow(modelData.windowId);
        } else if (itemType === "emoji") {
            ctrl.copyEmoji(modelData.emoji, shiftHeld || false);
        } else if (itemType === "action") {
            if (modelData.actionId === "wolfram") {
                ctrl.openWolframAlpha();
            } else if (modelData.actionId === "dictionary") {
                ctrl.copyDictResult();
            } else if (modelData.actionId === "websearch") {
                ctrl.openWebSearch();
            }
        } else if (itemType === "music_album") {
            MusicService.playTrack(modelData.album, 0);
            ctrl.toggleLauncher();
        } else if (itemType === "music_track") {
            MusicService.playTrack(modelData.album, modelData.trackIndex);
            ctrl.toggleLauncher();
        } else if (itemType === "file") {
            ctrl.openFile(modelData.file.path);
        } else if (itemType === "system_command") {
            ctrl.executeSystemCommand(modelData.actionId, modelData.actionValue);
        } else if (itemType === "bookmark") {
            ctrl.openUrl(modelData.bookmark.url);
        }
    }

    // Legacy compat for old key handler
    function launch() {
        activate(false);
    }

    Rectangle {
        id: itemBox
        anchors.centerIn: parent
        width: parent.width - 32
        height: parent.height - 4
        radius: 16

        scale: itemMouseArea.pressed ? 0.98 : (delegateRoot.isSelected || delegateRoot.isHovered ? 1.015 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        color: delegateRoot.isSelected ? Theme.secondary_container : (delegateRoot.isHovered ? Qt.lighter(Theme.surface_container_low, 1.08) : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            id: activeIndicator
            width: 4
            height: delegateRoot.isSelected ? parent.height * 0.5 : 0
            opacity: delegateRoot.isSelected ? 1.0 : 0.0
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: itemType === "emoji" ? Theme.tertiary : (itemType === "action" || itemType === "system_command" ? Theme.secondary : (itemType === "focus" ? Theme.tertiary : (itemType === "file" ? Theme.secondary : Theme.primary)))
            Behavior on height {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuart
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        Item {
            id: topRow
            width: parent.width
            height: 72
            anchors.top: parent.top

            // --- Icon area ---
            Item {
                id: iconContainer
                width: 42
                height: 42
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                // App icon (desktop entry icon)
                IconImage {
                    id: appIcon
                    anchors.fill: parent
                    visible: delegateRoot.itemType === "app" || delegateRoot.itemType === "focus"

                    source: {
                        if (delegateRoot.itemType !== "app" && delegateRoot.itemType !== "focus") return "";
                        var entry = modelData.entry;
                        if (!entry || !entry.icon || entry.icon === "") {
                            return "image://icon/application-x-executable";
                        }
                        if (entry.icon.startsWith("/")) {
                            return "file://" + entry.icon;
                        }
                        return "image://icon/" + entry.icon;
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            source = "image://icon/application-x-executable";
                        }
                    }
                }
                
                // Music Cover art
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    visible: itemType === "music_album" || itemType === "music_track"
                    color: Theme.surface_container_highest
                    
                    Image {
                        id: launcherAlbumCover
                        anchors.fill: parent
                        source: (itemType === "music_album" || itemType === "music_track") && modelData.album.cover_path 
                                ? "file://" + modelData.album.cover_path 
                                : ""
                        fillMode: Image.PreserveAspectCrop
                        
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: launcherAlbumCover.width
                                    height: launcherAlbumCover.height
                                    radius: 8
                                }
                            }
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: Theme.on_surface_variant
                        visible: !parent.children[0].status || parent.children[0].status === Image.Error
                    }
                }

                // Emoji character as icon
                Text {
                    anchors.centerIn: parent
                    visible: delegateRoot.itemType === "emoji"
                    text: delegateRoot.itemType === "emoji" ? modelData.emoji : ""
                    font {
                        family: "Noto Color Emoji"
                        pixelSize: 36
                    }
                    renderType: Text.NativeRendering
                }

                // Action icon — nerd font glyph or icon theme icon
                Text {
                    anchors.centerIn: parent
                    visible: delegateRoot.itemType === "action" && modelData.iconFamily !== "__icon_theme__"
                    text: (delegateRoot.itemType === "action" && modelData.iconFamily !== "__icon_theme__") ? modelData.icon : ""
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 26
                    }
                    color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                }

                // Action icon — from icon theme (e.g. Helium browser)
                IconImage {
                    id: actionThemeIcon
                    anchors.fill: parent
                    visible: delegateRoot.itemType === "action" && modelData.iconFamily === "__icon_theme__"
                    source: {
                        if (delegateRoot.itemType === "action" && modelData.iconFamily === "__icon_theme__") {
                            return "image://icon/" + modelData.icon;
                        }
                        return "";
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            source = "image://icon/web-browser";
                        }
                    }
                }

                // System command icon (nerd font glyph)
                Text {
                    anchors.centerIn: parent
                    visible: delegateRoot.itemType === "system_command"
                    text: delegateRoot.itemType === "system_command" ? modelData.icon : ""
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 26
                    }
                    color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                }

                // File type icon (nerd font glyph)
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    visible: delegateRoot.itemType === "file"
                    color: Theme.surface_container_highest

                    Text {
                        anchors.centerIn: parent
                        text: delegateRoot.itemType === "file" && modelData.file ? ctrl.mimeIcon(modelData.file.mime_cat) : ""
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 22
                        }
                        color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                    }

                    // Extension badge
                    Rectangle {
                        visible: delegateRoot.itemType === "file" && modelData.file && modelData.file.ext !== ""
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -4
                        anchors.bottomMargin: -2
                        width: extLabel.implicitWidth + 6
                        height: 14
                        radius: 4
                        color: Theme.tertiary_container

                        Text {
                            id: extLabel
                            anchors.centerIn: parent
                            text: (delegateRoot.itemType === "file" && modelData.file) ? modelData.file.ext.toUpperCase() : ""
                            font {
                                family: "Google Sans"
                                pixelSize: 8
                                weight: Font.Bold
                            }
                            color: Theme.on_tertiary_container
                        }
                    }
                }

                // Bookmark icon
                Item {
                    anchors.fill: parent
                    visible: delegateRoot.itemType === "bookmark"

                    IconImage {
                        anchors.fill: parent
                        source: "image://icon/helium"
                        onStatusChanged: {
                            if (status === Image.Error) {
                                source = "image://icon/web-browser";
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -6
                        anchors.bottomMargin: -6
                        width: 24
                        height: 24
                        radius: 12
                        color: Theme.surface_container_low

                        Image {
                            id: faviconImage
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: delegateRoot.itemType === "bookmark" && modelData.bookmark ? "file://" + modelData.bookmark.icon_path : ""
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: Theme.on_surface_variant
                            visible: faviconImage.status !== Image.Ready
                        }
                    }
                }
            }

            Column {
                anchors.left: iconContainer.right
                anchors.right: actionPill.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 2

                Text {
                    width: parent.width
                    text: delegateRoot.nameText
                    color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface
                    elide: Text.ElideRight
                    font {
                        family: "Google Sans"
                        pixelSize: 16
                        weight: Font.DemiBold
                    }
                    renderType: Text.QtRendering
                }

                Text {
                    width: parent.width
                    text: delegateRoot.descriptionText
                    visible: delegateRoot.descriptionText !== ""
                    color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                    opacity: delegateRoot.isSelected ? 0.8 : 1.0
                    elide: Text.ElideRight
                    font {
                        family: "Google Sans"
                        pixelSize: 13
                    }
                }
            }

            Rectangle {
                id: actionPill
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: pillRow.width + 24
                height: 32
                radius: 16
                color: {
                    if (delegateRoot.itemType === "emoji")
                        return Theme.tertiary;
                    if (delegateRoot.itemType === "action" || delegateRoot.itemType === "system_command")
                        return Theme.secondary;
                    if (delegateRoot.itemType === "focus")
                        return Theme.tertiary;
                    if (delegateRoot.itemType === "file")
                        return Theme.secondary;
                    if (delegateRoot.itemType === "bookmark")
                        return Theme.secondary;
                    return Theme.primary;
                }
                opacity: delegateRoot.isSelected ? 1.0 : 0.0
                scale: delegateRoot.isSelected ? 1.0 : 0.8

                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutBack
                    }
                }

                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        topPadding: 2
                        verticalAlignment: Text.AlignVCenter
                        text: {
                            if (delegateRoot.itemType === "focus")
                                return "Focus";
                            if (delegateRoot.itemType === "emoji")
                                return "Copy";
                            if (delegateRoot.itemType === "action") {
                                if (modelData.actionId === "wolfram")
                                    return "Open";
                                if (modelData.actionId === "dictionary")
                                    return "Copy";
                                return "Search";
                            }
                            if (delegateRoot.itemType === "system_command") {
                                return "Run";
                            }
                            if (delegateRoot.itemType === "file")
                                return "Open";
                            if (delegateRoot.itemType === "bookmark")
                                return "Open";
                            return "Launch";
                        }
                        color: {
                            if (delegateRoot.itemType === "emoji")
                                return Theme.on_tertiary;
                            if (delegateRoot.itemType === "action" || delegateRoot.itemType === "system_command")
                                return Theme.on_secondary;
                            if (delegateRoot.itemType === "focus")
                                return Theme.on_tertiary;
                            if (delegateRoot.itemType === "file")
                                return Theme.on_secondary;
                            if (delegateRoot.itemType === "bookmark")
                                return Theme.on_secondary;
                            return Theme.on_primary;
                        }
                        font {
                            family: "Google Sans Medium"
                            pixelSize: 13
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        topPadding: 2
                        verticalAlignment: Text.AlignVCenter
                        text: {
                            if (delegateRoot.itemType === "focus")
                                return "󰇧";
                            if (delegateRoot.itemType === "emoji")
                                return "󰆏";
                            if (delegateRoot.itemType === "action") {
                                if (modelData.actionId === "dictionary")
                                    return "󰆏";
                                return "󰇧";
                            }
                            if (delegateRoot.itemType === "system_command") {
                                return "󰐍";
                            }
                            if (delegateRoot.itemType === "bookmark") {
                                return "";
                            }
                            return "󰌑";
                        }
                        color: {
                            if (delegateRoot.itemType === "emoji")
                                return Theme.on_tertiary;
                            if (delegateRoot.itemType === "action" || delegateRoot.itemType === "system_command")
                                return Theme.on_secondary;
                            if (delegateRoot.itemType === "focus")
                                return Theme.on_tertiary;
                            if (delegateRoot.itemType === "file")
                                return Theme.on_secondary;
                            if (delegateRoot.itemType === "bookmark")
                                return Theme.on_secondary;
                            return Theme.on_primary;
                        }
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 16
                        }
                    }
                }
            }
        }
        
        Item {
            id: previewArea
            anchors.top: topRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: delegateRoot.itemType === "action" && (modelData.actionId === "wolfram" || modelData.actionId === "dictionary")
            clip: true
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 0
                radius: 12
                color: Qt.rgba(0,0,0,0.1)
                visible: delegateRoot.itemType === "action" && modelData.actionId === "wolfram"
                
                Image {
                    anchors.centerIn: parent
                    source: ctrl.backendqsSvg
                    fillMode: Image.PreserveAspectFit
                    width: parent.width - 32
                    height: parent.height - 32
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    smooth: true
                    antialiasing: true
                    opacity: ctrl.backendqsStatus === "ok" ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                Item {
                    anchors.fill: parent
                    visible: ctrl.backendqsStatus === "loading" || ctrl.backendqsStatus === "error"
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Thinking"
                            color: "#ffffff"
                            font.family: "Google Sans"
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                            opacity: 0.95
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3 * 20
                            height: 30
                            
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: "#ffffff"
                                    x: index * 20
                                    y: 10
                                    
                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        running: true
                                        
                                        PauseAnimation { duration: index * 100 }
                                        NumberAnimation { from: 10; to: 0; duration: 250; easing.type: Easing.OutSine }
                                        NumberAnimation { from: 0; to: 10; duration: 250; easing.type: Easing.InSine }
                                        PauseAnimation { duration: (2 - index) * 100 + 300 }
                                    }
                                    
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: true
                                        
                                        PauseAnimation { duration: index * 100 }
                                        NumberAnimation { from: 0.3; to: 1.0; duration: 250; easing.type: Easing.OutSine }
                                        NumberAnimation { from: 1.0; to: 0.3; duration: 250; easing.type: Easing.InSine }
                                        PauseAnimation { duration: (2 - index) * 100 + 300 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: dictContent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: dictColumn.implicitHeight + 24
                radius: 12
                color: Qt.rgba(0,0,0,0.1)
                visible: delegateRoot.itemType === "action" && modelData.actionId === "dictionary"
                opacity: ctrl.dictStatus === "ok" ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                
                Column {
                    id: dictColumn
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    spacing: 4
                    
                    Row {
                        spacing: 8
                        Text {
                            id: dictWordText
                            text: ctrl.dictWord
                            font.family: "Google Sans"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: Theme.on_surface
                        }
                        Text {
                            text: ctrl.dictPhonetic
                            font.family: "Google Sans"
                            font.pixelSize: 16
                            color: Theme.on_surface_variant
                            anchors.baseline: dictWordText.baseline
                        }
                    }
                    
                    Text {
                        width: parent.width
                        text: ctrl.dictDefinition
                        wrapMode: Text.WordWrap
                        font.family: "Google Sans"
                        font.pixelSize: 14
                        color: Theme.on_surface
                    }
                }
            }
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: delegateRoot.ListView.view.currentIndex = index
            onClicked: mouse => delegateRoot.activate(mouse.modifiers & Qt.ShiftModifier)
        }
    }
}
