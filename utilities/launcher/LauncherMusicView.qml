import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services

Item {
    id: root

    property string filterQuery: ""
    property real revealProgress: 1.0
    property int selectedIndex: 0
    property int selectedTrackIndex: 0

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    onVisibleChanged: {
        if (visible && !BackendDaemon.musicLibrary)
            BackendDaemon.send({action: "music_library"});
    }

    property var library: BackendDaemon.musicLibrary ? BackendDaemon.musicLibrary.albums : []
    property var selectedAlbum: null

    property var filteredAlbums: {
        if (!library) return [];
        if (filterQuery === "") return library;
        let q = filterQuery.toLowerCase();
        let res = [];
        for (let i = 0; i < library.length; i++) {
            let album = library[i];
            if (album.title.toLowerCase().includes(q) || album.artist.toLowerCase().includes(q)) {
                res.push(album);
                continue;
            }
            for (let j = 0; j < album.tracks.length; j++) {
                if (album.tracks[j].title.toLowerCase().includes(q)) {
                    res.push(album);
                    break;
                }
            }
        }
        return res;
    }

    readonly property real estimatedSelectedY: {
        if (selectedAlbum !== null)
            return 80 + selectedTrackIndex * 52;
        return selectedIndex * 72;
    }

    function scoreMatch(text, query) {
        if (!text) return -1;
        var tl = text.toString().toLowerCase();
        var ql = query.toLowerCase();
        if (tl === ql) return 1000;
        if (tl.startsWith(ql)) return 800;
        var words = tl.split(/[\s\-_]+/);
        for (var i = 0; i < words.length; i++)
            if (words[i].startsWith(ql)) return 600;
        if (query.length >= 3 && tl.indexOf(ql) !== -1) return 200;
        return -1;
    }

    function clampSelectedIndex() {
        if (selectedAlbum !== null) {
            if (!selectedAlbum.tracks || selectedAlbum.tracks.length === 0)
                selectedTrackIndex = 0;
            else if (selectedTrackIndex >= selectedAlbum.tracks.length)
                selectedTrackIndex = selectedAlbum.tracks.length - 1;
            else if (selectedTrackIndex < 0)
                selectedTrackIndex = 0;
            return;
        }
        if (filteredAlbums.length === 0) selectedIndex = 0;
        else if (selectedIndex >= filteredAlbums.length) selectedIndex = filteredAlbums.length - 1;
        else if (selectedIndex < 0) selectedIndex = 0;
    }

    function incrementSelection() {
        if (selectedAlbum !== null) {
            if (!selectedAlbum.tracks || selectedAlbum.tracks.length === 0) return;
            selectedTrackIndex = (selectedTrackIndex + 1) % selectedAlbum.tracks.length;
            return;
        }
        if (filteredAlbums.length === 0) return;
        selectedIndex = (selectedIndex + 1) % filteredAlbums.length;
    }

    function decrementSelection() {
        if (selectedAlbum !== null) {
            if (!selectedAlbum.tracks || selectedAlbum.tracks.length === 0) return;
            selectedTrackIndex = selectedTrackIndex <= 0
                ? selectedAlbum.tracks.length - 1
                : selectedTrackIndex - 1;
            return;
        }
        if (filteredAlbums.length === 0) return;
        selectedIndex = selectedIndex <= 0 ? filteredAlbums.length - 1 : selectedIndex - 1;
    }

    function findTopPlayMatch(query) {
        if (!query || !library) return null;
        var best = null;
        var bestScore = -1;
        for (var m = 0; m < library.length; m++) {
            var album = library[m];
            for (var t = 0; t < album.tracks.length; t++) {
                var track = album.tracks[t];
                var trackScore = Math.max(scoreMatch(track.title, query), scoreMatch(album.artist, query));
                if (trackScore > bestScore) {
                    bestScore = trackScore;
                    best = { type: "track", album: album, trackIndex: t };
                }
            }
            var albumScore = Math.max(scoreMatch(album.title, query), scoreMatch(album.artist, query));
            if (albumScore > bestScore) {
                bestScore = albumScore;
                best = { type: "album", album: album, trackIndex: 0 };
            }
        }
        return bestScore >= 0 ? best : null;
    }

    function activateTopMatch() {
        var q = filterQuery.trim();
        if (q === "") return activateSelected();
        var match = findTopPlayMatch(q);
        if (!match) return false;
        MusicService.playTrack(match.album, match.trackIndex);
        return true;
    }

    function activateSelected() {
        if (selectedAlbum !== null) {
            if (!selectedAlbum.tracks || selectedAlbum.tracks.length === 0) return false;
            MusicService.playTrack(selectedAlbum, selectedTrackIndex);
            return true;
        }
        if (filteredAlbums.length === 0) return false;
        selectedAlbum = filteredAlbums[selectedIndex];
        return false;
    }

    onFilterQueryChanged: selectedIndex = 0
    onFilteredAlbumsChanged: clampSelectedIndex()
    onSelectedAlbumChanged: selectedTrackIndex = 0
    onSelectedIndexChanged: if (albumList.visible) albumList.positionViewAtIndex(selectedIndex, ListView.Contain)
    onSelectedTrackIndexChanged: if (trackListView.visible) trackListView.positionViewAtIndex(selectedTrackIndex, ListView.Contain)

    readonly property var topMatch: findTopPlayMatch(filterQuery.trim())
    readonly property real selectedScrollY: estimatedSelectedY

    function formatTime(secs) {
        if (isNaN(secs) || secs < 0) return "0:00";
        let m = Math.floor(secs / 60);
        let s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ─── Album List ───
    ListView {
        id: albumList
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        visible: root.selectedAlbum === null
        model: root.filteredAlbums

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 32
            visible: root.filteredAlbums.length === 0 && root.filterQuery !== ""
            text: "No matching albums"
            color: Theme.on_surface_variant
            font.family: "Google Sans"
            font.pixelSize: 14
            opacity: 0.8
        }

        delegate: Rectangle {
            id: albumDelegate
            width: ListView.view.width
            height: 68
            radius: 14
            property bool isSelected: index === root.selectedIndex
            color: isSelected
                ? Theme.secondary_container
                : (albumMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: 3
                height: isSelected ? 32 : 0
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                radius: 1.5
                color: Theme.primary
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 14

                Rectangle {
                    id: albumCover
                    width: 52
                    height: 52
                    radius: 10
                    color: Theme.surface_variant
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: modelData.cover_path ? "file://" + modelData.cover_path : ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle { width: coverImg.width; height: coverImg.height; radius: 10 }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                        color: Theme.on_surface_variant
                        visible: coverImg.status !== Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "#80000000"
                        opacity: coverPlayMouse.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰐊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: coverPlayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.tracks.length > 0)
                                MusicService.playTrack(modelData, 0);
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 52 - 14 - trackCountBadge.width - 8
                    spacing: 2

                    Text {
                        text: modelData.title
                        font.family: "Google Sans Medium"
                        font.pixelSize: 14
                        color: Theme.on_surface
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: modelData.artist
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Rectangle {
                    id: trackCountBadge
                    anchors.verticalCenter: parent.verticalCenter
                    width: trackCountText.implicitWidth + 14
                    height: 22
                    radius: 11
                    color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)

                    Text {
                        id: trackCountText
                        anchors.centerIn: parent
                        text: modelData.tracks ? modelData.tracks.length : "0"
                        font.family: "Google Sans"
                        font.pixelSize: 11
                        color: Theme.on_surface_variant
                    }
                }
            }

            MouseArea {
                id: albumMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedAlbum = modelData
            }
        }
    }

    // ─── Album Detail / Track Picker ───
    Item {
        id: albumDetail
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.bottom: parent.bottom
        width: parent.width
        visible: root.selectedAlbum !== null
        clip: true

        ListView {
            id: trackListView
            anchors.fill: parent
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.selectedAlbum ? root.selectedAlbum.tracks : null

            header: Column {
                width: trackListView.width
                spacing: 0

                Item {
                    width: parent.width
                    height: 12
                }

                Item {
                    width: parent.width
                    height: 72

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36
                            radius: 18
                            anchors.verticalCenter: parent.verticalCenter
                            color: backBtnMouse.containsMouse ? Theme.surface_variant : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰁍"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: Theme.on_surface
                            }

                            MouseArea {
                                id: backBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedAlbum = null
                            }
                        }

                        Rectangle {
                            width: 56; height: 56
                            radius: 12
                            color: Theme.surface_variant
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Image {
                                id: detailArt
                                anchors.fill: parent
                                source: (root.selectedAlbum && root.selectedAlbum.cover_path) ? "file://" + root.selectedAlbum.cover_path : ""
                                fillMode: Image.PreserveAspectCrop
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: ShaderEffectSource {
                                        sourceItem: Rectangle { width: detailArt.width; height: detailArt.height; radius: 12 }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36 - 56 - 36 - parent.spacing * 3
                            spacing: 2

                            Text {
                                text: root.selectedAlbum ? root.selectedAlbum.title : ""
                                font.family: "Google Sans Medium"
                                font.pixelSize: 16
                                color: Theme.on_surface
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: root.selectedAlbum ? root.selectedAlbum.artist : ""
                                font.family: "Google Sans"
                                font.pixelSize: 12
                                color: Theme.on_surface_variant
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Rectangle {
                            id: playAllBtn
                            width: 36; height: 36
                            radius: 18
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            scale: playAllMouse.containsMouse ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 1
                                text: "󰐊"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: Theme.on_primary
                            }

                            MouseArea {
                                id: playAllMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.selectedAlbum) MusicService.playTrack(root.selectedAlbum, 0)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 24
                    height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)
                }

                Item { width: 1; height: 8 }
            }

            delegate: Rectangle {
                id: trackDelegate
                width: ListView.view.width
                height: 48
                radius: 12
                property bool isPlaying: BackendDaemon.musicState.title !== "" && BackendDaemon.musicState.title === modelData.title
                property bool isSelected: index === root.selectedTrackIndex

                color: isSelected
                    ? Theme.secondary_container
                    : (trackMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.05) : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }

                Rectangle {
                    width: 3
                    height: isSelected ? 24 : 0
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 1.5
                    color: Theme.primary
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    Item {
                        width: 24; height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: modelData.track_number
                            font.family: "Google Sans"
                            font.pixelSize: 13
                            color: Theme.on_surface_variant
                            visible: !isPlaying
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            visible: isPlaying

                            Repeater {
                                model: 3
                                Item {
                                    width: 3; height: 14
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: 3; height: 4
                                        radius: 1.5
                                        color: Theme.primary

                                        SequentialAnimation on height {
                                            loops: Animation.Infinite
                                            running: isPlaying && BackendDaemon.musicState.playing
                                            NumberAnimation { to: index === 0 ? 8 : (index === 1 ? 14 : 10); duration: index === 0 ? 300 : (index === 1 ? 250 : 350); easing.type: Easing.InOutSine }
                                            NumberAnimation { to: index === 0 ? 14 : (index === 1 ? 6 : 14); duration: index === 0 ? 250 : (index === 1 ? 300 : 200); easing.type: Easing.InOutSine }
                                            NumberAnimation { to: index === 0 ? 6 : (index === 1 ? 12 : 6); duration: index === 0 ? 350 : (index === 1 ? 200 : 250); easing.type: Easing.InOutSine }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24 - 14 - durationLabel.width - 14
                        text: modelData.title
                        font.family: isPlaying ? "Google Sans Medium" : "Google Sans"
                        font.pixelSize: 14
                        color: isPlaying ? Theme.primary : Theme.on_surface
                        elide: Text.ElideRight
                    }

                    Text {
                        id: durationLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.duration ? formatTime(modelData.duration) : ""
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        color: Theme.on_surface_variant
                        opacity: 0.7
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
}
