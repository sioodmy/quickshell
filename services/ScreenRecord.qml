pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property bool recording: false
    property bool recordAudio: false
    property bool active: false
    property bool wasOpened: false
    property bool wasRemoved: false

    property string videoPath: ""
    property string fileName: ""
    property string thumbPath: ""
    property string geometry: ""
    property string recorderBin: ""
    property string lastError: ""
    property int elapsedSec: 0
    property int recordPid: 0

    readonly property string elapsedText: {
        const m = Math.floor(elapsedSec / 60);
        const s = elapsedSec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property string pidFile: "/tmp/quickshell-rec.pid"
    readonly property string pathFile: "/tmp/quickshell-rec.path"
    readonly property string errFile: "/tmp/quickshell-rec-error"
    readonly property string statusFile: "/tmp/quickshell-rec-status"

    IpcHandler {
        target: "screenrecord"
        function stop(): void {
            root.stop();
        }
        function fullscreen(): void {
            root.startFullscreen();
        }
        function area(): void {
            root.startArea();
        }
        function launch_area(geom: string): void {
            if (geom && geom.length > 0) {
                root.geometry = geom;
                root._launchRecorder(geom);
            }
        }
        function toggle_audio(): void {
            root.recordAudio = !root.recordAudio;
        }
        function started(): void {
            root._onStarted();
        }
        function finished(): void {
            root._onFinished();
        }
        function fail(): void {
            root._onFail();
        }
    }

    Component.onCompleted: resolveBin.running = true

    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSec += 1
    }

    // Keep indicator honest if the recorder dies outside our stop() path.
    Timer {
        id: watchdog
        interval: 1500
        repeat: true
        running: root.recording
        onTriggered: pidCheck.running = true
    }

    Process {
        id: resolveBin
        command: ["bash", "-lc", "command -v wf-recorder || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p.length > 0)
                    root.recorderBin = p;
            }
        }
    }


    Process {
        id: pidCheck
        command: ["bash", "-c",
            "PID=$(cat '" + root.pidFile + "' 2>/dev/null); " +
            "if [ -n \"$PID\" ] && kill -0 \"$PID\" 2>/dev/null; then echo alive; else echo dead; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.recording)
                    return;
                if (text.trim() === "dead")
                    root._onFinished();
            }
        }
    }

    Process {
        id: stopProc
    }

    Process {
        id: thumbProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "ok") {
                    // Still notify with filename even without a thumbnail.
                    root.thumbPath = "";
                } else {
                    root.thumbPath = "/tmp/quickshell-rec-thumb.jpg";
                }
                root.wasOpened = false;
                root.wasRemoved = false;
                root.active = true;
            }
        }
    }

    Process {
        id: removeProc
        onExited: {
            root.wasRemoved = true;
            root.videoPath = "";
            root.thumbPath = "";
        }
    }

    Process {
        id: readError
        command: ["bash", "-c", "cat '" + root.errFile + "' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastError = text.trim();
                if (root.lastError.length > 0) {
                    Quickshell.execDetached({
                        command: ["notify-send", "-a", "Quickshell", "-u", "critical", "Screen Record", root.lastError]
                    });
                }
            }
        }
    }

    function _prepareOutput() {
        const d = new Date();
        const pad = n => (n < 10 ? "0" : "") + n;
        const stamp = d.getFullYear() + "-"
            + pad(d.getMonth() + 1) + "-"
            + pad(d.getDate()) + "_"
            + pad(d.getHours()) + "-"
            + pad(d.getMinutes()) + "-"
            + pad(d.getSeconds());
        root.fileName = "Recording-" + stamp + ".mp4";
        root.videoPath = Quickshell.env("HOME") + "/Videos/" + root.fileName;
        root.thumbPath = "";
        root.elapsedSec = 0;
        root.wasOpened = false;
        root.wasRemoved = false;
        root.active = false;
        root.lastError = "";
        root.recordPid = 0;
    }

    function _shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function _launchRecorder(geom) {
        if (root.recording)
            return;

        root._prepareOutput();

        const audioFlag = root.recordAudio ? "-a" : "";
        const geomFlag = geom && geom.length ? ("-g " + _shellQuote(geom)) : "";
        const out = _shellQuote(root.videoPath);
        const binHint = root.recorderBin.length ? _shellQuote(root.recorderBin) : "''";

        // Detached launcher mirrors the working screenshot pattern: resolve binary
        // via login shell PATH (NixOS), write pid/path, then IPC back.
        const script = [
            "set +e",
            "rm -f '" + root.errFile + "' '" + root.pidFile + "' '" + root.pathFile + "' '" + root.statusFile + "'",
            "mkdir -p \"$HOME/Videos\" || { echo 'Could not create ~/Videos' > '" + root.errFile + "'; quickshell ipc call screenrecord fail; exit 1; }",
            "REC=" + binHint,
            "if [ -z \"$REC\" ] || [ ! -x \"$REC\" ]; then REC=$(command -v wf-recorder 2>/dev/null); fi",
            "if [ -z \"$REC\" ] || [ ! -x \"$REC\" ]; then REC=$(bash -lc 'command -v wf-recorder' 2>/dev/null); fi",
            // NixOS: package may exist in the store before it lands on PATH.
            "if [ -z \"$REC\" ] || [ ! -x \"$REC\" ]; then REC=$(ls -1 /nix/store/*-wf-recorder-*/bin/wf-recorder 2>/dev/null | tail -n1); fi",
            "if [ -z \"$REC\" ] || [ ! -x \"$REC\" ]; then",
            "  echo 'wf-recorder not found in PATH. Add it to your NixOS config and restart quickshell.' > '" + root.errFile + "'",
            "  quickshell ipc call screenrecord fail",
            "  exit 1",
            "fi",
            "echo \"$REC\" > /tmp/quickshell-rec-bin",
            "echo " + out + " > '" + root.pathFile + "'",
            "\"$REC\" -f " + out + " " + geomFlag + " " + audioFlag + " > /tmp/quickshell-rec-out.log 2> /tmp/quickshell-rec-err.log &",
            "PID=$!",
            "echo \"$PID\" > '" + root.pidFile + "'",
            "sleep 0.35",
            "if ! kill -0 \"$PID\" 2>/dev/null; then",
            "  ERR=$(cat /tmp/quickshell-rec-err.log 2>/dev/null | tail -n 5)",
            "  [ -n \"$ERR\" ] || ERR='wf-recorder exited immediately'",
            "  echo \"$ERR\" > '" + root.errFile + "'",
            "  quickshell ipc call screenrecord fail",
            "  exit 1",
            "fi",
            "echo started > '" + root.statusFile + "'",
            "quickshell ipc call screenrecord started",
            "wait \"$PID\"",
            "echo finished > '" + root.statusFile + "'",
            "quickshell ipc call screenrecord finished"
        ].join("\n");

        Quickshell.execDetached({ command: ["bash", "-c", script] });
    }

    function _onStarted() {
        root.recording = true;
        root.elapsedSec = 0;
        readPid.running = true;
    }

    Process {
        id: readPid
        command: ["bash", "-c", "cat '" + root.pidFile + "' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                if (!isNaN(n))
                    root.recordPid = n;
            }
        }
    }

    function _onFinished() {
        if (!root.recording && root.videoPath === "")
            return;
        root.recording = false;
        root.recordPid = 0;
        elapsedTimer.stop();
        if (root.videoPath.length > 0) {
            thumbProc.command = ["bash", "-c",
                "if [ -s " + root._shellQuote(root.videoPath) + " ]; then " +
                "ffmpeg -y -ss 0 -i " + root._shellQuote(root.videoPath) +
                " -vframes 1 -q:v 3 /tmp/quickshell-rec-thumb.jpg 2>/dev/null; " +
                "echo ok; else echo fail; fi"
            ];
            thumbProc.running = false;
            thumbProc.running = true;
        }
    }

    function _onFail() {
        root.recording = false;
        root.recordPid = 0;
        root.videoPath = "";
        root.fileName = "";
        root.thumbPath = "";
        readError.running = false;
        readError.running = true;
    }

    function startFullscreen() {
        if (root.recording)
            return;
        Screenshot.overlayActive = false;
        fullscreenDelay.restart();
    }

    Timer {
        id: fullscreenDelay
        interval: 200
        onTriggered: root._launchRecorder("")
    }

    function startArea() {
        if (root.recording)
            return;
        Screenshot.overlayActive = false;
        Quickshell.execDetached({ command: ["bash", "-c",
            "sleep 0.25; GEOM=$(slurp 2>/dev/null); [ -n \"$GEOM\" ] && quickshell ipc call screenrecord launch_area \"$GEOM\""
        ] });
    }

    function stop() {
        if (!root.recording && root.recordPid === 0) {
            // Still try pid file in case UI state drifted.
        }
        stopProc.command = ["bash", "-c",
            "PID=$(cat '" + root.pidFile + "' 2>/dev/null); " +
            "if [ -n \"$PID\" ]; then kill -INT \"$PID\" 2>/dev/null || kill -TERM \"$PID\" 2>/dev/null; fi; " +
            "pkill -INT -x wf-recorder 2>/dev/null; true"
        ];
        stopProc.running = false;
        stopProc.running = true;
    }

    function openFile() {
        if (root.videoPath === "")
            return;
        Quickshell.execDetached({
            command: ["xdg-open", root.videoPath]
        });
        root.wasOpened = true;
    }

    function removeFile() {
        if (root.videoPath === "")
            return;
        removeProc.command = ["bash", "-c",
            "rm -f " + root._shellQuote(root.videoPath) + " " + root._shellQuote(root.thumbPath)
        ];
        removeProc.running = true;
    }

    function dismiss() {
        root.active = false;
    }

    function toggleAudio() {
        root.recordAudio = !root.recordAudio;
    }
}
