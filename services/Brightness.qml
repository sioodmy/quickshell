pragma Singleton

import Quickshell
import Quickshell.Io

/** Backlight brightness provider/controller backed by brightnessctl. */
Singleton {
    id: root

    // 0.0 .. 1.0
    property real value: 0.0
    property bool available: false

    function setPercent(percent) {
        let p = Math.max(0, Math.min(100, Math.round(percent)));
        root.value = p / 100.0;
        root.available = true;
        setProc.command = ["brightnessctl", "set", `${p}%`];
        setProc.running = true;
    }

    function refresh() {
        readProc.running = true;
    }

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // brightnessctl -m => "backlight,<name>,<cur>,<max>,<percent>%"
                let text = this.text.trim();
                if (!text) return;
                let parts = text.split(",");
                if (parts.length < 5) return;
                let percentStr = parts[4].trim().replace("%", "");
                let v = parseFloat(percentStr);
                if (isNaN(v)) return;
                root.value = v / 100.0;
                root.available = true;
            }
        }
    }

    Process {
        id: setProc
    }

    // React to external brightness changes (keys, other tools).
    Process {
        command: ["sh", "-c", "udevadm monitor --subsystem-match=backlight --udev"]
        running: true
        stdout: SplitParser {
            onRead: root.refresh()
        }
    }
}
