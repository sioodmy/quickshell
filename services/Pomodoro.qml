pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int workDuration: 25 * 60
    property int shortBreakDuration: 5 * 60
    property int longBreakDuration: 15 * 60

    // 0: Focus, 1: Short Break, 2: Long Break
    property int mode: 0
    property int timeRemaining: workDuration
    property bool isRunning: false
    property int completedSessions: 0
    property int sessionsUntilLong: 4

    signal timeUp()

    readonly property int currentDuration: {
        if (mode === 1)
            return shortBreakDuration;
        if (mode === 2)
            return longBreakDuration;
        return workDuration;
    }

    readonly property real progress: {
        var d = currentDuration;
        if (d <= 0)
            return 0;
        return Math.max(0, Math.min(1, 1 - (timeRemaining / d)));
    }

    // Ring fill shows time remaining (full at start, empties as time passes)
    readonly property real remainingProgress: {
        var d = currentDuration;
        if (d <= 0)
            return 0;
        return Math.max(0, Math.min(1, timeRemaining / d));
    }

    readonly property string modeLabel: {
        if (mode === 1)
            return "Short Break";
        if (mode === 2)
            return "Long Break";
        return "Focus";
    }

    readonly property string modeIcon: {
        if (mode === 1)
            return "󰅶";
        if (mode === 2)
            return "󰒲";
        return "󱎫";
    }

    readonly property bool shouldShow: isRunning
        || (mode === 0 && timeRemaining !== workDuration)
        || (mode === 1 && timeRemaining !== shortBreakDuration)
        || (mode === 2 && timeRemaining !== longBreakDuration)

    property string formattedTime: {
        let m = Math.floor(timeRemaining / 60);
        let s = timeRemaining % 60;
        return m.toString().padStart(2, '0') + ":" + s.toString().padStart(2, '0');
    }

    readonly property string formattedMinutes: {
        let m = Math.ceil(timeRemaining / 60);
        return m.toString();
    }

    Timer {
        id: timer
        interval: 1000
        repeat: true
        running: root.isRunning
        onTriggered: {
            if (root.timeRemaining > 0) {
                root.timeRemaining -= 1;
                if (root.timeRemaining === 0) {
                    root.isRunning = false;
                    root._onComplete();
                }
            } else {
                root.isRunning = false;
            }
        }
    }

    IpcHandler {
        target: "pomodoro"
        function toggle() { root.toggle(); }
        function reset() { root.reset(); }
        function start() {
            if (!root.isRunning)
                root.isRunning = true;
        }
        function stop() {
            root.isRunning = false;
        }
        function work() { root.setMode(0); }
        function short_break() { root.setMode(1); }
        function long_break() { root.setMode(2); }
    }

    function toggle() {
        isRunning = !isRunning;
    }

    function reset() {
        isRunning = false;
        timeRemaining = currentDuration;
    }

    function setMode(newMode) {
        mode = newMode;
        reset();
    }

    function setDuration(minutes) {
        var secs = Math.max(1, Math.min(120, Math.round(minutes))) * 60;
        if (mode === 0)
            workDuration = secs;
        else if (mode === 1)
            shortBreakDuration = secs;
        else
            longBreakDuration = secs;

        if (!isRunning)
            timeRemaining = secs;
        else
            timeRemaining = Math.min(timeRemaining, secs);
    }

    function adjustTime(minutes) {
        let deltaSeconds = minutes * 60;
        if (mode === 0)
            workDuration = Math.max(60, workDuration + deltaSeconds);
        else if (mode === 1)
            shortBreakDuration = Math.max(60, shortBreakDuration + deltaSeconds);
        else
            longBreakDuration = Math.max(60, longBreakDuration + deltaSeconds);

        if (!isRunning)
            reset();
        else
            timeRemaining = Math.max(0, timeRemaining + deltaSeconds);
    }

    function _onComplete() {
        timeUp();

        var msg;
        if (mode === 0) {
            completedSessions += 1;
            msg = "Focus complete! Take a break.";
            if (completedSessions % sessionsUntilLong === 0)
                setMode(2);
            else
                setMode(1);
        } else {
            msg = "Break over — back to focus.";
            setMode(0);
        }

        // Soft auto-advance into the next phase
        isRunning = true;

        Quickshell.execDetached({
            command: ["notify-send", "-a", "Pomodoro", "-u", "critical", msg]
        });
    }
}
