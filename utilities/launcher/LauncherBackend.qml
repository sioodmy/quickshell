import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"

Item {
    id: backend

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    property string searchText: ""
    property string calcResult: ""
    property string calcExpression: ""

    // CHANGE THIS TO YOUR ACTUAL TERMINAL
    property string myTerminal: "foot"

    function launchApp(desktopEntry) {
        var finalCommand = [];

        // Wrap the launch in UWSM so systemd tracks the app properly
        finalCommand.push("run-as-service");

        if (desktopEntry.runInTerminal) {
            finalCommand.push(myTerminal);
            finalCommand.push("--");
        }

        finalCommand = finalCommand.concat(desktopEntry.command);

        Quickshell.execDetached({
            command: finalCommand,
            workingDirectory: desktopEntry.workingDirectory
        });

        backend.calcResult = "";
        backend.calcExpression = "";
        backend.closeMenuRequested();
    }

    onSearchTextChanged: {
        calcDebounce.restart();
    }

    Timer {
        id: calcDebounce
        interval: 200
        onTriggered: {
            var query = backend.searchText.trim();
            if (query === "") {
                backend.calcResult = "";
                backend.calcExpression = "";
                return;
            }
            // Only evaluate if it looks like a math/conversion expression
            if (/[0-9]/.test(query) || /^[\(\-\+]/.test(query)) {
                rinkProcess.expressionArg = query;
                rinkProcess.running = true;
            } else {
                backend.calcResult = "";
                backend.calcExpression = "";
            }
        }
    }

    Process {
        id: rinkProcess
        property string expressionArg: ""
        command: ["rink", expressionArg]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text.trim();
                var lines = raw.split("\n");
                // rink outputs: "> expression" then "result" on next line
                if (lines.length >= 2) {
                    var result = lines[1].trim();
                    // Filter out error messages
                    if (result.indexOf("No such") !== -1 ||
                        result.indexOf("Expected") !== -1 ||
                        result.indexOf("Could not") !== -1 ||
                        result.indexOf("Unknown") !== -1 ||
                        result.indexOf("did you mean") !== -1 ||
                        result.indexOf("error") !== -1) {
                        backend.calcResult = "";
                        backend.calcExpression = "";
                    } else {
                        backend.calcExpression = rinkProcess.expressionArg;
                        backend.calcResult = result;
                    }
                } else {
                    backend.calcResult = "";
                    backend.calcExpression = "";
                }
            }
        }
    }

    Process {
        id: copyCalcResult
        property string resultText: ""
        command: ["bash", "-c", 'printf "%s" "$1" | wl-copy', "_", resultText]
    }

    function copyResult() {
        if (backend.calcResult !== "") {
            // Extract just the numeric value (before the parenthetical unit description)
            var clean = backend.calcResult;
            var parenIdx = clean.indexOf(" (");
            if (parenIdx !== -1)
                clean = clean.substring(0, parenIdx).trim();
            copyCalcResult.resultText = clean;
            copyCalcResult.running = true;
        }
    }

    IpcHandler {
        target: "appLauncher"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
