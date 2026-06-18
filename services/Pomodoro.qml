pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property int workDuration: 25 * 60
    property int shortBreakDuration: 5 * 60
    property int longBreakDuration: 15 * 60

    property int mode: 0 // 0: Work, 1: Short Break, 2: Long Break
    property int timeRemaining: workDuration
    property bool isRunning: false

    signal timeUp()

    property string formattedTime: {
        let m = Math.floor(timeRemaining / 60);
        let s = timeRemaining % 60;
        return m.toString().padStart(2, '0') + ":" + s.toString().padStart(2, '0');
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
                    root.timeUp();
                    Quickshell.execDetached({ command: ["notify-send", "-a", "Pomodoro", "-u", "critical", root.mode === 0 ? "Work session complete! Take a break." : "Break complete! Back to work."] });
                }
            } else {
                root.isRunning = false;
            }
        }
    }

    function toggle() {
        isRunning = !isRunning;
    }

    function reset() {
        isRunning = false;
        if (mode === 0) timeRemaining = workDuration;
        else if (mode === 1) timeRemaining = shortBreakDuration;
        else if (mode === 2) timeRemaining = longBreakDuration;
    }

    function setMode(newMode) {
        mode = newMode;
        reset();
    }

    function adjustTime(minutes) {
        let deltaSeconds = minutes * 60;
        if (mode === 0) workDuration = Math.max(60, workDuration + deltaSeconds);
        else if (mode === 1) shortBreakDuration = Math.max(60, shortBreakDuration + deltaSeconds);
        else if (mode === 2) longBreakDuration = Math.max(60, longBreakDuration + deltaSeconds);
        
        if (!isRunning) {
            reset();
        } else {
            timeRemaining = Math.max(0, timeRemaining + deltaSeconds);
        }
    }
}
