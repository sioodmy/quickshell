pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isUnlocked: false
    property bool unlockPending: false
    property bool lockPending: false
    property string pendingUnlockRequest: ""
    property string pendingLockRequest: ""
    // Shared across request types and never reset on daemon restarts.
    property double requestCounter: 0

    signal unlocked(bool success, string error)
    signal locked()
    signal searchResult(var results)
    signal copyResult(string requestId, string id, string field, bool success)
    signal entrySelected(var entry)
    signal otpResult(string id, string code, int remaining)
    
    function nextRequestId() {
        return String(++requestCounter);
    }

    function unlock(password) {
        if (!BackendDaemon.available || SessionState.locked || unlockPending || isUnlocked || lockPending)
            return;
        pendingUnlockRequest = nextRequestId();
        unlockPending = true;
        BackendDaemon.send({ action: "keepass_unlock", request_id: pendingUnlockRequest, password: password });
    }
    
    function search(query, clientTitle) {
        if (!BackendDaemon.available || !isUnlocked || SessionState.locked) return;
        BackendDaemon.send({ action: "keepass_search", query: query, client_title: clientTitle || null });
    }
    
    function copyField(id, field) {
        if (!BackendDaemon.available || !isUnlocked || SessionState.locked || lockPending) return "";
        let requestId = nextRequestId();
        BackendDaemon.send({ action: "keepass_copy", request_id: requestId, id: id, field: field });
        return requestId;
    }
    
    function lock() {
        if (!BackendDaemon.available) {
            pendingLockRequest = "";
            lockPending = false;
            reset();
            return;
        }
        if (lockPending) return;
        // Keep unlock blocked until the daemon acknowledges cancellation/locking.
        pendingLockRequest = nextRequestId();
        lockPending = true;
        reset();
        BackendDaemon.send({ action: "keepass_lock", request_id: pendingLockRequest });
    }

    function reset() {
        isUnlocked = false;
        unlockPending = false;
        pendingUnlockRequest = "";
        locked();
    }
    
    function getOtp(id) {
        if (!BackendDaemon.available || !isUnlocked || SessionState.locked) return;
        BackendDaemon.send({ action: "keepass_get_otp", id: id });
    }

    Connections {
        target: SessionState
        function onLockedChanged() {
            if (SessionState.locked) root.lock();
        }
    }
    
    Connections {
        target: BackendDaemon
        function onBackendStarted() {
            root.pendingLockRequest = "";
            root.lockPending = false;
            root.reset();
            if (SessionState.locked) root.lock();
        }
        function onBackendStopped() {
            root.pendingLockRequest = "";
            root.lockPending = false;
            root.reset();
        }
        function onEventReceived(event) {
            if (event.type === "keepass_locked") {
                // Cancel an unlock submitted after this automatic event was queued.
                if (root.unlockPending && !root.lockPending) root.lock();
                else root.reset();
            } else if (event.type === "keepass_lock_result") {
                if (!root.lockPending || event.request_id !== root.pendingLockRequest) return;
                root.pendingLockRequest = "";
                root.lockPending = false;
            } else if (event.type === "keepass_unlock_result") {
                if (!root.unlockPending || event.request_id !== root.pendingUnlockRequest || root.lockPending || SessionState.locked) return;
                root.pendingUnlockRequest = "";
                root.unlockPending = false;
                root.isUnlocked = event.success === true;
                root.unlocked(event.success, event.error || "");
            } else if (!root.isUnlocked || SessionState.locked) {
                return;
            } else if (event.type === "keepass_search_result") {
                root.searchResult(event.results);
            } else if (event.type === "keepass_copy_result") {
                root.copyResult(event.request_id, event.id, event.field, event.success);
            } else if (event.type === "keepass_otp_result") {
                root.otpResult(event.id, event.code, event.remaining);
            }
        }
    }
}
