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

    IpcHandler {
        target: "screenshot"
        function done(): void {
            readResult.running = true;
        }
    }

    // Read the result file to get the screenshot path
    Process {
        id: readResult
        command: ["cat", "/tmp/quickshell-ss-result"]
        stdout: SplitParser {
            onRead: data => {
                let path = data.trim();
                if (path.length > 0 && path.startsWith("/")) {
                    root.imagePath = path;
                    root.active = true;
                }
            }
        }
    }

    function take() {
        ControlCenter.hide();
        imagePath = "";
        active = false;
        ocring = false;
        wasSaved = false;
        wasCopied = false;
        wasOcred = false;

        // Fully detached so slurp isn't blocked by Quickshell overlays
        Quickshell.execDetached({ command: ["bash", "-c",
            "sleep 0.5; FILE=/tmp/quickshell-ss-$(date +%s%N).png; GEOM=$(slurp 2>/dev/null); [ -n \"$GEOM\" ] && grim -g \"$GEOM\" \"$FILE\" && echo \"$FILE\" > /tmp/quickshell-ss-result && quickshell ipc call screenshot done"
        ] });
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
    }
}
