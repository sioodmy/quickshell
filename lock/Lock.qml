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

    property string pendingPassword: ""

    function submit(password) {
        if (password.length === 0)
            return;
        if (pam.active)
            pam.abort();
        root.statusMessage = "";
        root.statusIsError = false;
        root.pendingPassword = password;
        pam.start();
    }

    onLockedChanged: {
        if (!locked) {
            if (pam.active)
                pam.abort();
            root.pendingPassword = "";
            root.statusMessage = "";
            root.statusIsError = false;
        }
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
                root.locked = false;
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
            root.locked = false;
        }

        function toggle(): void {
            root.locked = !root.locked;
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
