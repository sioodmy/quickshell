pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property string imagePath: ""
    property bool active: false
    property bool ocring: false
    property bool wasSaved: false
    property bool wasCopied: false
    property bool wasOcred: false

    property string frozenPath: ""
    property bool overlayActive: false
    property string overlayMode: "menu"
    property bool editorActive: false
    // True after the menu closes and before grim/IPC marks the shot ready.
    // Keeps the island from flashing back to dock chrome mid-capture.
    property bool awaitingCapture: false

    // Dock morph handoff for the screenshot editor (same pattern as launcher / KeePass).
    property bool open: false
    property real openProgress: 0.0
    property var screen: null

    // Toolbox island footprint — morph target for the top glass shell.
    readonly property real editorTargetWidth: 940
    readonly property real editorTargetHeight: 80
    readonly property real editorTargetRadius: 20

    signal closeRequested()

    function requestClose() {
        closeRequested();
    }

    // Open the draw editor. Prefer this over setting editorActive so the notch
    // can be claimed in the same call stack before an island dismisses.
    function openEditor() {
        editorActive = true;
    }

    IpcHandler {
        target: "screenshot"
        function done(): void {
            readResult.running = true;
        }
        function cancel(): void {
            root.awaitingCapture = false;
            root.active = false;
        }
        function menu(): void {
            take_menu();
        }
        function take(): void {
            take_menu();
        }
        function show_overlay(): void {
            overlayMode = "menu";
            overlayActive = true;
        }
    }

    // Decode the shot before flipping `active` so the island only opens once
    // the preview is actually paint-ready (no empty "…" flash).
    Image {
        id: previewLoader
        width: 0
        height: 0
        visible: false
        asynchronous: true
        cache: true
        sourceSize.width: 400
        source: root.imagePath ? ("file://" + root.imagePath) : ""

        onStatusChanged: {
            if (!root.imagePath)
                return;
            if (status === Image.Ready || status === Image.Error)
                root._revealResult();
        }
    }

    function _revealResult() {
        if (root.active)
            return;
        root.awaitingCapture = false;
        root.active = true;
    }

    function take_menu() {
        imagePath = "";
        active = false;
        awaitingCapture = false;
        ocring = false;
        wasSaved = false;
        wasCopied = false;
        wasOcred = false;

        overlayMode = "menu";
        overlayActive = true;
    }

    function take() {
        take_menu();
    }

    Process {
        id: fullCaptureProc
        command: ["bash", "-c", "sleep 0.1; FILE=/tmp/quickshell-ss-$(date +%s%N).png; grim \"$FILE\" && echo \"$FILE\""]
        stdout: SplitParser {
            onRead: data => {
                let path = data.trim();
                if (path.length > 0 && path.startsWith("/")) {
                    root.imagePath = path;
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.awaitingCapture = false;
                root.active = false;
            }
        }
    }

    Process {
        id: areaCaptureProc
        command: ["bash", "-c", "sleep 0.1; FILE=/tmp/quickshell-ss-$(date +%s%N).png; GEOM=$(slurp 2>/dev/null); [ -n \"$GEOM\" ] && grim -g \"$GEOM\" \"$FILE\" && echo \"$FILE\""]
        stdout: SplitParser {
            onRead: data => {
                let path = data.trim();
                if (path.length > 0 && path.startsWith("/")) {
                    root.imagePath = path;
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.awaitingCapture = false;
                root.active = false;
            }
        }
    }

    function finishFullscreen() {
        awaitingCapture = true;
        overlayActive = false;
        fullCaptureProc.running = false;
        fullCaptureProc.running = true;
    }

    function finishArea() {
        awaitingCapture = true;
        overlayActive = false;
        areaCaptureProc.running = false;
        areaCaptureProc.running = true;
    }


    function finishWindow() {
        awaitingCapture = false;
        overlayActive = false;
        Quickshell.execDetached({ command: ["niri", "msg", "action", "screenshot-window"] });
    }

    function copyToClipboard() {
        if (imagePath === "") return;
        copyProc.command = ["bash", "-c", "wl-copy -t image/png < '" + imagePath + "'"];
        copyProc.running = true;
    }

    Process {
        id: copyProc
        onExited: { root.wasCopied = true; }
    }

    function save() {
        if (imagePath === "") return;
        let d = new Date();
        let name = d.toISOString().replace(/[:.]/g, "-");
        saveProc.command = ["bash", "-c",
            "mkdir -p ~/Pictures/Screenshots && cp '" + imagePath + "' ~/Pictures/Screenshots/" + name + ".png"
        ];
        saveProc.running = true;
    }

    Process {
        id: saveProc
        onExited: { root.wasSaved = true; }
    }

    function ocr() {
        if (imagePath === "" || ocring) return;
        ocring = true;
        ocrProc.command = ["bash", "-c",
            "tesseract '" + imagePath + "' - | wl-copy"
        ];
        ocrProc.running = true;
    }

    Process {
        id: ocrProc
        onExited: {
            root.ocring = false;
            root.wasOcred = true;
        }
    }

    function dismiss() {
        active = false;
        awaitingCapture = false;
    }
}
