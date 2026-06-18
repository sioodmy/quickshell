pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property bool isPlaying: false
    property bool hasPlayer: false

    Process {
        id: metadataTracker
        command: ["bash", "-c", "while true; do playerctl metadata -f '{{status}}|||{{artist}}|||{{title}}|||{{mpris:artUrl}}' 2>/dev/null || echo 'NONE'; sleep 1; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed === "NONE" || trimmed === "") {
                    root.hasPlayer = false;
                } else {
                    let parts = trimmed.split("|||");
                    if (parts.length >= 4) {
                        root.hasPlayer = true;
                        let status = parts[0].trim();
                        root.artist = parts[1].trim();
                        root.title = parts[2].trim();
                        
                        let rawUrl = parts[3].trim();
                        if (rawUrl.startsWith("file://")) {
                            root.artUrl = rawUrl;
                        } else if (rawUrl.startsWith("http")) {
                            root.artUrl = rawUrl;
                        } else if (rawUrl !== "") {
                            root.artUrl = "file://" + rawUrl;
                        } else {
                            root.artUrl = "";
                        }

                        root.isPlaying = (status === "Playing");
                    }
                }
            }
        }
    }

    function playPause() {
        Quickshell.execDetached({ command: ["playerctl", "play-pause"] });
    }

    function next() {
        Quickshell.execDetached({ command: ["playerctl", "next"] });
    }

    function previous() {
        Quickshell.execDetached({ command: ["playerctl", "previous"] });
    }
}
