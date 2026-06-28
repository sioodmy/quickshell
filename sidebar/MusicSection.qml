import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services

Item {
    id: root
    
    onVisibleChanged: {
        if (visible && !BackendDaemon.musicLibrary) {
            BackendDaemon.send({action: "music_library"});
        }
    }

    property var library: BackendDaemon.musicLibrary ? BackendDaemon.musicLibrary.albums : []
    property var selectedAlbum: null
    
    property string searchQuery: ""
    property var filteredAlbums: {
        if (!library) return [];
        if (searchQuery === "") return library;
        let q = searchQuery.toLowerCase();
        let res = [];
        for (let i = 0; i < library.length; i++) {
            let album = library[i];
            if (album.title.toLowerCase().includes(q) || album.artist.toLowerCase().includes(q)) {
                res.push(album);
                continue;
            }
            let matches = false;
            for (let j = 0; j < album.tracks.length; j++) {
                if (album.tracks[j].title.toLowerCase().includes(q)) {
                    matches = true;
                    break;
                }
            }
            if (matches) res.push(album);
        }
        return res;
    }

    // Helper: format seconds to m:ss
    function formatTime(secs) {
        if (isNaN(secs) || secs < 0) return "0:00";
        let m = Math.floor(secs / 60);
        let s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Top: Now Playing Info — only visible when something is playing or paused
    Rectangle {
        id: nowPlayingInfo
        anchors.top: parent.top
        width: parent.width
        height: BackendDaemon.musicState.hasPlayer ? 140 : 0
        radius: 20
        color: nowPlayingMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high
        clip: true
        visible: height > 0
        opacity: BackendDaemon.musicState.hasPlayer ? 1.0 : 0.0

        Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: nowPlayingMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: BackendDaemon.musicState.hasPlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (BackendDaemon.musicState.hasPlayer) {
                    Lyrics.showFullscreen = true;
                }
            }
        }

        // Floating ambient circles
        Item {
            anchors.fill: parent
            visible: opacity > 0
            opacity: BackendDaemon.musicState.playing ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 500 } }

            Rectangle {
                width: 160
                height: 160
                radius: 80
                color: Theme.primary
                opacity: 0.15
                x: parent.width - 100
                y: -60

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: BackendDaemon.musicState.playing && root.visible
                    NumberAnimation { to: nowPlayingInfo.width - 40; duration: 8000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: nowPlayingInfo.width - 120; duration: 9000; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: BackendDaemon.musicState.playing && root.visible
                    NumberAnimation { to: 10; duration: 7000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -70; duration: 8500; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                width: 120
                height: 120
                radius: 60
                color: Theme.secondary
                opacity: 0.2
                x: parent.width - 180
                y: 40

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: BackendDaemon.musicState.playing && root.visible
                    NumberAnimation { to: nowPlayingInfo.width - 220; duration: 7500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: nowPlayingInfo.width - 160; duration: 6500; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: BackendDaemon.musicState.playing && root.visible
                    NumberAnimation { to: 70; duration: 8000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 20; duration: 7000; easing.type: Easing.InOutSine }
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Row {
                width: parent.width
                height: 72
                spacing: 16

                Rectangle {
                    width: 72
                    height: 72
                    radius: 12
                    color: Theme.surface_container_highest
                    clip: true

                    Image {
                        id: nowPlayingImg
                        anchors.fill: parent
                        source: BackendDaemon.musicState.artUrl !== "" ? BackendDaemon.musicState.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: nowPlayingImg.width
                                    height: nowPlayingImg.height
                                    radius: 12
                                }
                            }
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 28
                        color: Theme.on_surface_variant
                        visible: nowPlayingImg.status !== Image.Ready
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 72 - 16
                    spacing: 2

                    Text {
                        text: BackendDaemon.musicState.title !== "" ? BackendDaemon.musicState.title : "Not Playing"
                        font.family: "Google Sans Medium"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Theme.on_surface
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: BackendDaemon.musicState.artist !== "" ? BackendDaemon.musicState.artist : ""
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        width: parent.width
                        visible: text !== ""
                    }
                }
            }

            // Seekbar
            Item {
                width: parent.width
                height: 28
                visible: BackendDaemon.musicState.hasPlayer

                // Time labels
                Text {
                    id: currentTimeLabel
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: formatTime(BackendDaemon.musicState.position)
                    font.family: "Google Sans"
                    font.pixelSize: 11
                    color: Theme.on_surface_variant
                    opacity: 0.8
                }
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: formatTime(BackendDaemon.musicState.duration)
                    font.family: "Google Sans"
                    font.pixelSize: 11
                    color: Theme.on_surface_variant
                    opacity: 0.8
                }

                // Track bar
                Item {
                    id: seekTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 14

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: seekMouse.containsMouse || seekMouse.pressed ? 6 : 4
                        radius: height / 2
                        color: Theme.surface_variant

                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Rectangle {
                            height: parent.height
                            radius: height / 2
                            color: Theme.primary
                            width: BackendDaemon.musicState.duration > 0 ? Math.max(height, parent.width * Math.min(BackendDaemon.musicState.position / BackendDaemon.musicState.duration, 1.0)) : height

                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            // Seek knob
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: seekMouse.containsMouse || seekMouse.pressed ? 14 : 0
                                height: width
                                radius: width / 2
                                color: Theme.primary
                                opacity: seekMouse.containsMouse || seekMouse.pressed ? 1.0 : 0.0

                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (BackendDaemon.musicState.duration > 0) {
                                let ratio = mouse.x / width;
                                MusicService.setPosition(ratio * BackendDaemon.musicState.duration);
                            }
                        }
                    }
                }
            }
        }
    }

    // Middle: Search Bar
    Rectangle {
        id: searchBar
        anchors.top: nowPlayingInfo.visible ? nowPlayingInfo.bottom : parent.top
        anchors.topMargin: nowPlayingInfo.visible ? 16 : 0
        width: parent.width
        height: 48
        radius: 24
        color: searchInput.activeFocus ? Theme.surface_variant : Theme.surface_container

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on anchors.topMargin { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: Theme.on_surface_variant
            }

            TextInput {
                id: searchInput
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                color: Theme.on_surface
                font.family: "Google Sans"
                font.pixelSize: 14
                selectionColor: Theme.primary
                selectedTextColor: Theme.on_primary
                clip: true
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search library..."
                    color: Theme.on_surface_variant
                    font: parent.font
                    visible: parent.text.length === 0 && !parent.activeFocus
                }
                
                onTextChanged: root.searchQuery = text
            }
        }
        visible: root.selectedAlbum === null
    }

    // List: Albums
    ListView {
        id: list
        anchors.top: searchBar.bottom
        anchors.topMargin: 16
        anchors.bottom: controlsBar.top
        anchors.bottomMargin: 16
        width: parent.width
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        visible: root.selectedAlbum === null
        
        model: root.filteredAlbums
        
        delegate: Rectangle {
            id: albumDelegate
            width: ListView.view.width
            height: 64
            radius: 16
            color: delegateMouse.containsMouse ? Theme.surface_variant : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 16
                
                Rectangle {
                    id: coverContainer
                    width: 48
                    height: 48
                    radius: 8
                    color: Theme.surface_container_highest
                    clip: true
                    
                    Image {
                        id: albumCoverImg
                        anchors.fill: parent
                        source: modelData.cover_path ? "file://" + modelData.cover_path : ""
                        fillMode: Image.PreserveAspectCrop
                        
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: albumCoverImg.width
                                    height: albumCoverImg.height
                                    radius: 8
                                }
                            }
                        }
                    }
                    
                    // Fallback icon when no cover
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: Theme.on_surface_variant
                        visible: albumCoverImg.status !== Image.Ready
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: "#80000000"
                        radius: 8
                        opacity: coverMouse.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰐊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 20
                            color: "white"
                        }
                    }
                    
                    MouseArea {
                        id: coverMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.tracks.length > 0) {
                                MusicService.playTrack(modelData, 0)
                            }
                        }
                    }
                }
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48 - 16
                    
                    Text {
                        text: modelData.title
                        font.family: "Google Sans Medium"
                        font.pixelSize: 15
                        color: Theme.on_surface
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: modelData.artist
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }
            
            MouseArea {
                id: delegateMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedAlbum = modelData
            }
        }
    }

    // Detail: Album
    Item {
        id: albumDetail
        anchors.top: nowPlayingInfo.bottom
        anchors.topMargin: nowPlayingInfo.height > 0 ? 16 : 0
        anchors.bottom: controlsBar.top
        anchors.bottomMargin: 16
        width: parent.width
        visible: root.selectedAlbum !== null
        
        ListView {
            id: trackList
            anchors.fill: parent
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            
            model: root.selectedAlbum ? root.selectedAlbum.tracks : null
            
            header: Item {
                width: ListView.view.width
                height: 280
                
                // Back Button
                Rectangle {
                    x: 0; y: 0; z: 10
                    width: 48; height: 48
                    radius: 24
                    color: backMouse.containsMouse ? Theme.surface_variant : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰁍" // Back arrow
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        color: Theme.on_surface
                    }
                    
                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedAlbum = null
                    }
                }
                
                // Album Cover
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 48
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 140; height: 140
                    radius: 16
                    color: Theme.surface_container_highest
                    
                    Image {
                        id: detailCover
                        anchors.fill: parent
                        source: (root.selectedAlbum && root.selectedAlbum.cover_path) ? "file://" + root.selectedAlbum.cover_path : ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle { width: 140; height: 140; radius: 16 }
                            }
                        }
                    }

                    // Play all button overlaid
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -12
                        width: 48; height: 48
                        radius: 24
                        color: Theme.primary
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰐊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                            color: Theme.on_primary
                            anchors.horizontalCenterOffset: 2
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.selectedAlbum) MusicService.playTrack(root.selectedAlbum, 0)
                        }
                    }
                }
                
                // Title and Artist
                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 32
                    
                    Text {
                        text: root.selectedAlbum ? root.selectedAlbum.title : ""
                        font.family: "Google Sans Medium"
                        font.pixelSize: 22
                        color: Theme.on_surface
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: root.selectedAlbum ? root.selectedAlbum.artist : ""
                        font.family: "Google Sans"
                        font.pixelSize: 14
                        color: Theme.on_surface_variant
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }
            
            delegate: Rectangle {
                width: ListView.view.width
                height: 48
                radius: 12
                color: trackMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"
                
                property bool isThisPlaying: BackendDaemon.musicState.title !== "" && BackendDaemon.musicState.title === modelData.title
                
                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.leftMargin: 24
                    spacing: 16
                    
                    Item {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: modelData.track_number
                            font.family: "Google Sans"
                            font.pixelSize: 14
                            color: Theme.on_surface_variant
                            visible: !isThisPlaying
                        }
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            visible: isThisPlaying
                            
                            Repeater {
                                model: 3
                                Item {
                                    width: 3
                                    height: 14
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: 3
                                        height: 4
                                        radius: 1.5
                                        color: Theme.primary
                                        
                                        SequentialAnimation on height {
                                            loops: Animation.Infinite
                                            running: isThisPlaying && BackendDaemon.musicState.playing
                                            NumberAnimation { to: index === 0 ? 8 : (index === 1 ? 14 : 10); duration: index === 0 ? 300 : (index === 1 ? 250 : 350); easing.type: Easing.InOutSine }
                                            NumberAnimation { to: index === 0 ? 14 : (index === 1 ? 6 : 14); duration: index === 0 ? 250 : (index === 1 ? 300 : 200); easing.type: Easing.InOutSine }
                                            NumberAnimation { to: index === 0 ? 6 : (index === 1 ? 12 : 6); duration: index === 0 ? 350 : (index === 1 ? 200 : 250); easing.type: Easing.InOutSine }
                                        }
                                        
                                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }
                    }
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.title
                        font.family: "Google Sans"
                        font.pixelSize: 14
                        font.weight: isThisPlaying ? Font.Bold : Font.Normal
                        color: isThisPlaying ? Theme.primary : Theme.on_surface
                        elide: Text.ElideRight
                        width: parent.width - 24 - 16
                    }
                }
                
                MouseArea {
                    id: trackMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MusicService.playTrack(root.selectedAlbum, index)
                }
            }
        }
    }

    // Bottom: Sticky Controls
    // Bottom: Sticky Controls
    Rectangle {
        id: controlsBar
        property bool showVolume: false
        
        anchors.bottom: parent.bottom
        width: parent.width
        height: showVolume ? 132 : 96
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        radius: 32
        color: Theme.surface_container_highest

        component CBtn: Rectangle {
            property string icon
            property color icnColor: Theme.on_surface
            signal clicked()
            width: 44; height: 44; radius: 22
            anchors.verticalCenter: parent.verticalCenter
            color: cbm.containsMouse ? Theme.surface_variant : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
                anchors.centerIn: parent
                text: parent.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                color: parent.icnColor
            }
            MouseArea {
                id: cbm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.clicked()
            }
        }

        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 16

            // Top Row: Playback Buttons
            Item {
                width: parent.width
                height: 56

                Row {
                    anchors.centerIn: parent
                    spacing: 18

                    CBtn {
                        icon: "󰕾" // Speaker
                        icnColor: controlsBar.showVolume ? Theme.primary : Theme.on_surface_variant
                        onClicked: controlsBar.showVolume = !controlsBar.showVolume
                    }

                    CBtn {
                        icon: "󰒮"
                        onClicked: MusicService.previous()
                    }

                    Rectangle {
                        id: playPauseBtn
                        width: 56
                        height: 56
                        radius: 28
                        color: Theme.primary_container
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: playPauseIcon
                            anchors.centerIn: parent
                            text: BackendDaemon.musicState.playing ? "󰏤" : "󰐊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 28
                            color: Theme.on_primary_container

                            scale: 1.0
                            onTextChanged: playBounce.restart()
                            SequentialAnimation {
                                id: playBounce
                                NumberAnimation { target: playPauseIcon; property: "scale"; to: 0.7; duration: 100; easing.type: Easing.OutCubic }
                                NumberAnimation { target: playPauseIcon; property: "scale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                            }
                        }

                        scale: playPauseMouse.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        
                        MouseArea {
                            id: playPauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicService.toggle()
                        }
                    }

                    CBtn {
                        icon: "󰒭"
                        onClicked: MusicService.next()
                    }

                    CBtn {
                        icon: "󰑖" // Repeat icon
                        icnColor: BackendDaemon.musicState.loopAlbum ? Theme.primary : Theme.on_surface_variant
                        onClicked: MusicService.toggleLoop()
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenterOffset: 12
                            color: Theme.primary
                            opacity: BackendDaemon.musicState.loopAlbum ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            // Bottom Row: Volume Slider
            Item {
                width: parent.width
                height: 20
                opacity: controlsBar.showVolume ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                visible: opacity > 0
                
                Rectangle {
                    id: volTrack
                    anchors.centerIn: parent
                    width: parent.width - 16 // Clean margin
                    height: 6
                    radius: 3
                    color: Theme.surface_variant
                    
                    property real uiVolume: BackendDaemon.musicState.volume
                    
                    Connections {
                        target: BackendDaemon
                        function onMusicStateChanged() {
                            if (!volMouse.pressed) {
                                volTrack.uiVolume = BackendDaemon.musicState.volume;
                            }
                        }
                    }
                    
                    // Fill
                    Rectangle {
                        height: parent.height
                        width: parent.width * parent.uiVolume
                        radius: 3
                        color: Theme.on_surface
                    }
                    
                    // Interactive Thumb
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: (parent.width * parent.uiVolume) - (width / 2)
                        width: volMouse.containsMouse || volMouse.pressed ? 16 : 12
                        height: width
                        radius: width / 2
                        color: Theme.on_surface
                        
                        // Drop shadow for the thumb
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#40000000"
                            shadowBlur: 0.5
                            shadowVerticalOffset: 2
                        }
                        
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    }
                    
                    MouseArea {
                        id: volMouse
                        anchors.fill: parent
                        anchors.margins: -12 // Very forgiving hitbox
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                let vol = Math.max(0, Math.min(1, mouse.x / volTrack.width));
                                volTrack.uiVolume = vol;
                                MusicService.setVolume(vol);
                            }
                        }
                        onClicked: (mouse) => {
                            let vol = Math.max(0, Math.min(1, mouse.x / volTrack.width));
                            volTrack.uiVolume = vol;
                            MusicService.setVolume(vol);
                        }
                    }
                }
            }
        }
    }
}
