pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property string mprisTitle: ""
    property string mprisArtist: ""
    property string mprisArtUrl: ""
    property bool mprisIsPlaying: false
    property bool mprisHasPlayer: false
    property double mprisPosition: 0
    property double mprisLength: 0

    // Exported fallback properties for lyrics and global player logic
    // We prefer the backendqs state, but if it has no player, we fall back to global MPRIS
    property bool useBackend: BackendDaemon.musicState.hasPlayer || BackendDaemon.musicState.playing

    property string title: useBackend ? BackendDaemon.musicState.title : mprisTitle
    property string artist: useBackend ? BackendDaemon.musicState.artist : mprisArtist
    property string artUrl: useBackend ? BackendDaemon.musicState.artUrl : mprisArtUrl
    property bool isPlaying: useBackend ? BackendDaemon.musicState.playing : mprisIsPlaying
    property bool hasPlayer: useBackend ? BackendDaemon.musicState.hasPlayer : mprisHasPlayer
    property double position: useBackend ? BackendDaemon.musicState.position : mprisPosition
    property double length: useBackend ? BackendDaemon.musicState.duration : mprisLength

    Process {
        id: posTracker
        command: ["bash", "-c", "while true; do playerctl position 2>/dev/null || echo '-1'; sleep 0.5; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                let p = parseFloat(trimmed);
                if (p >= 0) {
                    root.mprisPosition = p;
                } else {
                    root.mprisPosition = 0;
                }
            }
        }
    }

    Process {
        id: metadataTracker
        command: ["bash", "-c", "while true; do playerctl metadata -f '{{status}}|||{{artist}}|||{{title}}|||{{mpris:artUrl}}|||{{mpris:length}}' 2>/dev/null || echo 'NONE'; sleep 1; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed === "NONE" || trimmed === "") {
                    root.mprisHasPlayer = false;
                    root.mprisLength = 0;
                } else {
                    let parts = trimmed.split("|||");
                    if (parts.length >= 4) {
                        root.mprisHasPlayer = true;
                        let status = parts[0].trim();
                        root.mprisArtist = parts[1].trim();
                        root.mprisTitle = parts[2].trim();
                        
                        let rawUrl = parts[3].trim();
                        if (rawUrl.startsWith("file://") || rawUrl.startsWith("http")) {
                            root.mprisArtUrl = rawUrl;
                        } else if (rawUrl !== "") {
                            root.mprisArtUrl = "file://" + rawUrl;
                        } else {
                            root.mprisArtUrl = "";
                        }
                        
                        root.mprisIsPlaying = (status === "Playing");
                        
                        if (parts.length >= 5) {
                            let lenStr = parts[4].trim();
                            if (lenStr !== "") {
                                let l = parseFloat(lenStr);
                                if (!isNaN(l) && l > 0) {
                                    root.mprisLength = l / 1000000.0;
                                }
                            }
                        }
                    } else {
                        root.mprisHasPlayer = false;
                    }
                }
            }
        }
    }

    // Playback control wrappers to handle both local library and fallback
    function playPause() {
        if (useBackend) {
            MusicService.toggle();
        } else {
            Quickshell.execDetached({ command: ["playerctl", "play-pause"] });
            mprisIsPlaying = !mprisIsPlaying;
        }
    }

    function next() {
        if (useBackend) {
            MusicService.next();
        } else {
            Quickshell.execDetached({ command: ["playerctl", "next"] });
            mprisIsPlaying = true;
        }
    }

    function previous() {
        if (useBackend) {
            MusicService.previous();
        } else {
            Quickshell.execDetached({ command: ["playerctl", "previous"] });
            mprisIsPlaying = true;
        }
    }

    function setPosition(pos) {
        if (useBackend) {
            MusicService.setPosition(pos);
        } else {
            Quickshell.execDetached({ command: ["playerctl", "position", pos.toString()] });
        }
    }
}
