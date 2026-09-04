pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property var words: []
    property int currentIndex: 0
    property bool playing: false
    property int wpm: 300
    property int minWpm: 100
    property int maxWpm: 900
    property string sourceText: ""
    property int totalWords: 0
    property int wordCount: 0
    property real progress: 0
    property string currentWord: words.length > 0 && currentIndex < words.length ? words[currentIndex] : ""

    IpcHandler {
        target: "rsvp"
        function toggle(): void {
            root.toggle();
        }
    }

    // Buffer for accumulating multi-line clipboard text
    property string _pasteBuffer: ""

    // Grab the primary (highlighted text) selection from Wayland
    Process {
        id: pasteProc
        command: ["wl-paste", "--primary", "--no-newline"]
        stdout: SplitParser {
            onRead: data => {
                if (root._pasteBuffer.length > 0) {
                    root._pasteBuffer += " ";
                }
                root._pasteBuffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            let text = root._pasteBuffer.trim();
            root._pasteBuffer = "";

            if (text.length === 0) return;

            root.sourceText = text;
            root.words = text.split(/\s+/).filter(w => w.length > 0);
            root.totalWords = root.words.length;
            root.wordCount = root.words.length;
            root.currentIndex = 0;
            root.progress = 0;

            if (root.totalWords > 0) {
                root.active = true;
                root.playing = true;
            }
        }
    }

    Timer {
        id: advanceTimer
        interval: Math.round(60000 / root.wpm)
        repeat: true
        running: root.playing && root.active
        onTriggered: {
            if (root.currentIndex < root.totalWords - 1) {
                root.currentIndex += 1;
                root.progress = root.totalWords > 1
                    ? root.currentIndex / (root.totalWords - 1)
                    : 1;
            } else {
                root.playing = false;
                root.progress = 1;
            }
        }
    }

    function toggle() {
        if (!active) {
            sourceText = "";
            words = [];
            currentIndex = 0;
            totalWords = 0;
            progress = 0;
            playing = false;
            pasteProc.running = true;
        } else {
            quit();
        }
    }

    function playPause() {
        if (!active) return;
        // Restart from beginning if at the end
        if (!playing && currentIndex >= totalWords - 1 && totalWords > 0) {
            currentIndex = 0;
            progress = 0;
        }
        playing = !playing;
    }

    function goBack() {
        if (!active) return;
        currentIndex = Math.max(0, currentIndex - 5);
        progress = totalWords > 1
            ? currentIndex / (totalWords - 1)
            : 0;
    }

    function speedUp() {
        wpm = Math.min(maxWpm, wpm + 50);
    }

    function speedDown() {
        wpm = Math.max(minWpm, wpm - 50);
    }

    function quit() {
        active = false;
        playing = false;
        currentIndex = 0;
        words = [];
        sourceText = "";
        totalWords = 0;
        wordCount = 0;
        progress = 0;
    }
}
