pragma Singleton

import Quickshell
import Quickshell.Io

/** Backlight brightness provider/controller backed by brightnessctl. */
Singleton {
    id: root

    // 0.0 .. 1.0
    property real value: 0.0
    property bool available: false

    function parseMachineOutput(text) {
        text = text.trim();
        if (!text) return NaN;

        let parts = text.split(",");
        if (parts.length < 5) return NaN;

        // brightnessctl >= 0.5: device,class,current,percent%,max
        if (parts[1].trim() === "backlight") {
            let pct = parts[3].trim();
            if (pct.endsWith("%")) return parseFloat(pct.slice(0, -1));
        }

        // brightnessctl < 0.5: class,name,current,max,percent%
        if (parts[0].trim() === "backlight") {
            let pct = parts[4].trim();
            if (pct.endsWith("%")) return parseFloat(pct.slice(0, -1));
        }

        let current = parseFloat(parts[2]);
        let max = parseFloat(parts[parts.length - 1]);
        if (!isNaN(current) && !isNaN(max) && max > 0) return (current / max) * 100;

        return NaN;
    }

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
                let v = root.parseMachineOutput(this.text);
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

    IpcHandler {
        target: "brightness"
        function up() {
            root.setPercent((root.value * 100) + 5);
        }
        function down() {
            root.setPercent((root.value * 100) - 5);
        }
        function set(val: real) {
            root.setPercent(val);
        }
    }
}
