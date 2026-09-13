pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false
    property int intensity: 50

    readonly property int temperature: Math.round(6500 - (intensity / 100.0 * 5500))

    function toggle() {
        if (enabled) disable();
        else enable();
    }

    function enable() {
        root.enabled = true;
        applyFilter();
    }

    function disable() {
        root.enabled = false;
        killProc.running = true;
    }

    function setIntensity(val) {
        root.intensity = Math.max(0, Math.min(100, val));
        if (root.enabled)
            applyFilter();
    }

    function applyFilter() {
        restartProc.command = ["bash", "-c",
            "pkill -x wlsunset 2>/dev/null; sleep 0.15; exec wlsunset -T " + root.temperature + " -t " + root.temperature];
        restartProc.running = true;
    }

    Process {
        id: killProc
        command: ["pkill", "-x", "wlsunset"]
    }

    Process {
        id: restartProc
    }

    Process {
        id: checkProc
        command: ["pgrep", "-x", "wlsunset"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.enabled = true;
            }
        }
    }
}
