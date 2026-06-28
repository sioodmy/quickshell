pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    function playTrack(album, index) {
        let paths = [];
        for (let i = 0; i < album.tracks.length; i++) {
            paths.push(album.tracks[i].path);
        }
        BackendDaemon.send({
            action: "music_play_album",
            tracks: paths,
            start_index: index
        });
        
        let s = BackendDaemon.musicState;
        s.title = album.tracks[index].title;
        s.artist = album.artist;
        let rawUrl = album.cover_path ? album.cover_path : "";
        s.artUrl = (rawUrl.startsWith("file://") || rawUrl.startsWith("http")) ? rawUrl : (rawUrl !== "" ? "file://" + rawUrl : "");
        s.playing = true;
        s.hasPlayer = true;
        BackendDaemon.musicState = s;
    }

    function toggle() {
        let isPlaying = BackendDaemon.musicState.playing;
        BackendDaemon.send({ "action": isPlaying ? "music_pause" : "music_resume" });
        let s = BackendDaemon.musicState;
        s.playing = !isPlaying;
        BackendDaemon.musicState = s;
    }
    
    function next() {
        BackendDaemon.send({ "action": "music_next" });
        let s = BackendDaemon.musicState;
        s.playing = true;
        BackendDaemon.musicState = s;
    }

    function previous() {
        BackendDaemon.send({ "action": "music_previous" });
        let s = BackendDaemon.musicState;
        s.playing = true;
        BackendDaemon.musicState = s;
    }

    function setPosition(pos) {
        BackendDaemon.send({ "action": "music_seek", "position": pos });
    }

    function setVolume(vol) {
        BackendDaemon.send({ "action": "music_set_volume", "volume": vol });
        let s = BackendDaemon.musicState;
        s.volume = vol;
        BackendDaemon.musicState = s;
    }

    function toggleLoop() {
        BackendDaemon.send({ "action": "music_toggle_loop" });
        let s = BackendDaemon.musicState;
        s.loopAlbum = !s.loopAlbum;
        BackendDaemon.musicState = s;
    }
}
