pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    signal unlocked(bool success, string error)
    signal searchResult(var results)
    signal copyDone()
    signal entrySelected(var entry)
    signal otpResult(string id, string code, int remaining)
    
    function unlock(password) {
        BackendDaemon.send({ action: "keepass_unlock", password: password });
    }
    
    function search(query) {
        BackendDaemon.send({ action: "keepass_search", query: query });
    }
    
    function copyField(id, field) {
        BackendDaemon.send({ action: "keepass_copy", id: id, field: field });
    }
    
    function lock() {
        BackendDaemon.send({ action: "keepass_lock" });
    }
    
    function getOtp(id) {
        BackendDaemon.send({ action: "keepass_get_otp", id: id });
    }
    
    Connections {
        target: BackendDaemon
        function onEventReceived(event) {
            if (event.type === "keepass_unlock_result") {
                root.unlocked(event.success, event.error || "");
            } else if (event.type === "keepass_search_result") {
                root.searchResult(event.results);
            } else if (event.type === "keepass_copy_done") {
                root.copyDone();
            } else if (event.type === "keepass_otp_result") {
                root.otpResult(event.id, event.code, event.remaining);
            }
        }
    }
}
