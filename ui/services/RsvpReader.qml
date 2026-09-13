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
    
    // ORP related properties
    property string wordLeft: ""
    property string wordOrp: ""
    property string wordRight: ""
    
    // Ramp up state
    property real rampProgress: 0.0
    property real currentWpm: wpm

    onCurrentWordChanged: {
        updateOrpSplits(currentWord);
    }
    
    function updateOrpSplits(word) {
        if (!word) {
            wordLeft = ""; wordOrp = ""; wordRight = ""; return;
        }
        let cleanWord = word;
        let len = cleanWord.length;
        
        let orpIndex = 0;
        if (len === 1) orpIndex = 0;
        else if (len <= 5) orpIndex = 1;
        else if (len <= 9) orpIndex = 2;
        else if (len <= 13) orpIndex = 3;
        else orpIndex = 4;
        
        // Ensure within bounds
        orpIndex = Math.min(orpIndex, len - 1);
        
        wordLeft = cleanWord.substring(0, orpIndex);
        wordOrp = cleanWord.substring(orpIndex, orpIndex + 1);
        wordRight = cleanWord.substring(orpIndex + 1);
    }

    IpcHandler {
        target: "rsvp"
        function toggle(): void {
            root.toggle();
        }
    }

    property string _pasteBuffer: ""

    Process {
        id: pasteProc
        command: ["wl-paste", "--primary"]
        stdout: SplitParser {
            onRead: data => {
                root._pasteBuffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            let text = root._pasteBuffer.trim();
            root._pasteBuffer = "";

            if (text.length === 0) return;

            root.sourceText = text;
            // Split keeping track of newlines for paragraph breaks
            root.words = text.split(/\s+/).filter(w => w.length > 0);
            root.totalWords = root.words.length;
            root.wordCount = root.words.length;
            root.currentIndex = 0;
            root.progress = 0;
            
            updateOrpSplits(root.words[0]);

            if (root.totalWords > 0) {
                root.active = true;
                root.playing = true;
                root.rampProgress = 0.0;
            }
        }
    }

    function calculateNextDelay() {
        if (root.currentIndex >= root.totalWords) return 60000 / root.wpm;
        
        let word = root.words[root.currentIndex];
        
        // Speed ramp up: goes from 0.5 to 1.0 over 2 seconds (roughly 10 words at 300 WPM)
        // 1.0 means full speed
        let rampFactor = 0.5 + (0.5 * root.rampProgress);
        let effectiveWpm = root.wpm * rampFactor;
        
        let baseDelay = 60000 / effectiveWpm;
        let delay = baseDelay;
        
        // Adaptive punctuation delays
        let lastChar = word[word.length - 1];
        if (lastChar === '.' || lastChar === '!' || lastChar === '?') {
            delay += baseDelay * 1.5; // Extra delay for sentence end
        } else if (lastChar === ',' || lastChar === ';' || lastChar === ':') {
            delay += baseDelay * 0.8; // Extra delay for clauses
        }
        
        // Length-based pacing
        let len = word.length;
        if (len > 8) {
            delay += baseDelay * ((len - 8) * 0.1); // add 10% base delay per char over 8
        }
        
        return Math.round(delay);
    }

    Timer {
        id: advanceTimer
        interval: calculateNextDelay()
        repeat: true
        running: root.playing && root.active
        onTriggered: {
            if (root.rampProgress < 1.0) {
                // Approximate 2-second ramp up based on interval
                root.rampProgress = Math.min(1.0, root.rampProgress + (interval / 2000));
            }
            
            if (root.currentIndex < root.totalWords - 1) {
                root.currentIndex += 1;
                root.progress = root.totalWords > 1
                    ? root.currentIndex / (root.totalWords - 1)
                    : 1;
                advanceTimer.interval = calculateNextDelay();
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
            rampProgress = 0.0;
            pasteProc.running = true;
        } else {
            quit();
        }
    }

    function playPause() {
        if (!active) return;
        if (!playing && currentIndex >= totalWords - 1 && totalWords > 0) {
            currentIndex = 0;
            progress = 0;
        }
        if (!playing) {
            rampProgress = 0.0; // Reset ramp up when resuming
            advanceTimer.interval = calculateNextDelay();
        }
        playing = !playing;
    }

    function goBack() {
        if (!active) return;
        currentIndex = Math.max(0, currentIndex - 5);
        progress = totalWords > 1
            ? currentIndex / (totalWords - 1)
            : 0;
        if (playing) advanceTimer.interval = calculateNextDelay();
    }

    function speedUp() {
        wpm = Math.min(maxWpm, wpm + 50);
        if (playing) advanceTimer.interval = calculateNextDelay();
    }

    function speedDown() {
        wpm = Math.max(minWpm, wpm - 50);
        if (playing) advanceTimer.interval = calculateNextDelay();
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
        rampProgress = 0.0;
    }
}
