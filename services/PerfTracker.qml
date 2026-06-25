pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpuUsage: 0
    property real ramUsage: 0
    property real batteryLevel: 100
    property string batteryStatus: "Full"
    property var topProcesses: []

    // History for charts
    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var ramHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    Process {
        id: statsProcess
        command: ["bash", Quickshell.shellPath("scripts/sys_stats.sh")]
        running: true // Keep running for historical chart data

        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim());
                    root.cpuUsage = parsed.cpu;
                    root.ramUsage = parsed.ram;
                    root.batteryLevel = parsed.bat;
                    root.batteryStatus = parsed.batStatus;
                    root.topProcesses = parsed.procs;

                    // Update history
                    let cHist = root.cpuHistory.slice(1);
                    cHist.push(parsed.cpu);
                    root.cpuHistory = cHist;

                    let rHist = root.ramHistory.slice(1);
                    rHist.push(parsed.ram);
                    root.ramHistory = rHist;

                } catch (e) {
                    console.error("Failed to parse sys stats: ", e);
                }
            }
        }
    }
}
