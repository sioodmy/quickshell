pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services // for Playerctl

Singleton {
    id: root
    
    // Array of objects: { time: float, text: string }
    property var parsedLyrics: []
    property int currentIndex: -1
    property bool showFullscreen: false
    property bool showOverlay: false
    
    property string currentLine: ""
    property string nextLine: ""
    
    property string currentTrack: Playerctl.artist + " - " + Playerctl.title
    
    Timer {
        id: debounceTimer
        interval: 1000 // Wait 1 second before fetching to avoid spam
        repeat: false
        onTriggered: {
            if (Playerctl.title !== "") {
                fetchProcess.artistArg = Playerctl.artist;
                fetchProcess.titleArg = Playerctl.title;
                fetchProcess.running = true;
            }
        }
    }
    
    Timer {
        id: retryTimer
        interval: 15000 // Retry after 15 seconds
        repeat: false
        onTriggered: {
            if (Playerctl.title !== "" && Playerctl.title === fetchProcess.titleArg) {
                fetchProcess.running = true;
            }
        }
    }

    onCurrentTrackChanged: {
        parsedLyrics = [];
        currentLine = "";
        nextLine = "";
        currentIndex = -1;
        
        fetchProcess.running = false;
        retryTimer.stop();
        debounceTimer.restart();
    }
    
    Process {
        id: fetchProcess
        property string artistArg: ""
        property string titleArg: ""
        command: ["bash", Quickshell.shellPath("scripts/fetch_lyrics.sh"), artistArg, titleArg]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseLrc(this.text);
            }
        }
    }
    
    function parseLrc(lrc) {
        if (lrc.trim() === "ERROR_API_FAILED") {
            console.log("Lyrics API failed. Retrying in 15 seconds...");
            retryTimer.start();
            return;
        }
        
        let lines = lrc.split('\n');
        let arr = [];
        let regex = /\[(\d+):(\d+\.\d+)\](.*)/;
        for (let i = 0; i < lines.length; i++) {
            let match = lines[i].match(regex);
            if (match) {
                let minutes = parseFloat(match[1]);
                let seconds = parseFloat(match[2]);
                let text = match[3].trim();
                if (text !== "") {
                    arr.push({ time: minutes * 60 + seconds, text: text });
                }
            }
        }
        root.parsedLyrics = arr;
        root.updateLine(Playerctl.position);
    }
    
    Connections {
        target: Playerctl
        function onPositionChanged() {
            root.updateLine(Playerctl.position);
        }
    }
    
    function updateLine(pos) {
        if (parsedLyrics.length === 0) {
            currentLine = "";
            nextLine = "";
            currentIndex = -1;
            return;
        }
        
        let idx = -1;
        for (let i = 0; i < parsedLyrics.length; i++) {
            if (pos >= parsedLyrics[i].time) {
                idx = i;
            } else {
                break;
            }
        }
        
        if (idx !== currentIndex) {
            currentIndex = idx;
            if (idx >= 0 && idx < parsedLyrics.length) {
                currentLine = parsedLyrics[idx].text;
                if (idx + 1 < parsedLyrics.length) {
                    nextLine = parsedLyrics[idx + 1].text;
                } else {
                    nextLine = "";
                }
            } else {
                currentLine = "";
                if (parsedLyrics.length > 0) {
                    nextLine = parsedLyrics[0].text;
                } else {
                    nextLine = "";
                }
            }
        }
    }
}
