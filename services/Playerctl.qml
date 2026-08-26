pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property bool useBackend: BackendDaemon.musicState.hasPlayer || BackendDaemon.musicState.playing

    property string title: BackendDaemon.musicState.title
    property string artist: BackendDaemon.musicState.artist
    property string artUrl: BackendDaemon.musicState.artUrl
    property bool isPlaying: BackendDaemon.musicState.playing
    property bool hasPlayer: BackendDaemon.musicState.hasPlayer
    property double position: BackendDaemon.musicState.position
    property double length: BackendDaemon.musicState.duration

    function playPause() {
        MusicService.toggle();
    }

    function next() {
        MusicService.next();
    }

    function previous() {
        MusicService.previous();
    }

    function setPosition(pos) {
        MusicService.setPosition(pos);
    }
}
