import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

/**
 * Session lock controller.
 *
 * Owns the PAM authentication context and exposes a simple IPC surface so the
 * power menu (or any external caller) can lock the session with:
 *   quickshell ipc call lock lock
 */
Scope {
    id: root

    property bool locked: false

    // Auth state surfaced to the lock surface UI.
    readonly property bool authenticating: pam.active
    property string statusMessage: ""
    property bool statusIsError: false
    // True while the unlock exit animation is playing after a successful PAM auth.
    property bool unlocking: false

    property string pendingPassword: ""

    function submit(password) {
        if (password.length === 0 || unlocking)
            return;
        if (pam.active)
            pam.abort();
        root.statusMessage = "";
        root.statusIsError = false;
        root.pendingPassword = password;
        pam.start();
    }

    function finishUnlock() {
        unlockAnimTimer.stop();
        root.unlocking = false;
        root.locked = false;
    }

    onLockedChanged: {
        if (locked) {
            root.unlocking = false;
            unlockAnimTimer.stop();
        } else {
            if (pam.active)
                pam.abort();
            root.pendingPassword = "";
            root.statusMessage = "";
            root.statusIsError = false;
            root.unlocking = false;
            unlockAnimTimer.stop();
        }
    }

    // Gives the lock surface time to play its unlock animation before the
    // Wayland session lock is released.
    Timer {
        id: unlockAnimTimer
        interval: 520
        onTriggered: root.finishUnlock()
    }

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (responseRequired) {
                pam.respond(root.pendingPassword);
            } else if (message.length > 0) {
                root.statusMessage = message;
                root.statusIsError = messageIsError;
            }
        }

        onCompleted: result => {
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                root.statusMessage = "";
                root.statusIsError = false;
                root.unlocking = true;
                unlockAnimTimer.restart();
            } else if (result === PamResult.MaxTries) {
                root.statusMessage = "Too many attempts";
                root.statusIsError = true;
            } else {
                root.statusMessage = "Incorrect password";
                root.statusIsError = true;
            }
        }

        onError: err => {
            root.pendingPassword = "";
            root.statusMessage = "Authentication error";
            root.statusIsError = true;
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.locked = true;
        }

        function unlock(): void {
            root.finishUnlock();
        }

        function toggle(): void {
            if (root.locked)
                root.finishUnlock();
            else
                root.locked = true;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        LockSurface {
            controller: root
        }
    }
}
