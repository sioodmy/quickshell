pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Org-mode agenda service.
 * Parses all .org files in ~/Notes via a bash script and exposes
 * structured agenda data to QML components.
 */
Singleton {
    id: root

    // Full parsed agenda items (sorted: active first, then by date)
    property var items: []

    // Set of date strings ("YYYY-MM-DD") that have agenda entries
    property var datesWithEvents: ({})

    // Loading state
    property bool loading: false

    // Today's items only
    readonly property var todayItems: {
        let today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        return items.filter(function(e) {
            return e.deadline === today || e.scheduled === today;
        });
    }

    // Active items (TODO/NEXT/WAITING — not completed)
    readonly property var activeItems: {
        return items.filter(function(e) {
            return e.state === "TODO" || e.state === "NEXT" || e.state === "WAITING";
        });
    }

    // Completed items (DONE/CANCELLED)
    readonly property var completedItems: {
        return items.filter(function(e) {
            return e.state === "DONE" || e.state === "CANCELLED";
        });
    }

    // Overdue items
    readonly property var overdueItems: {
        let today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        return activeItems.filter(function(e) {
            let d = e.deadline || e.scheduled || "";
            return d !== "" && d < today;
        });
    }

    // Items for a specific date
    function itemsForDate(dateStr) {
        return items.filter(function(e) {
            return e.deadline === dateStr || e.scheduled === dateStr;
        });
    }

    // Check if a date has events
    function hasEventsOnDate(year, month, day) {
        let d = year + "-" + (month + 1).toString().padStart(2, '0') + "-" + day.toString().padStart(2, '0');
        return datesWithEvents.hasOwnProperty(d);
    }

    // Refresh data from disk
    function refresh() {
        root.loading = true;
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        command: ["bash", Quickshell.shellPath("scripts/parse_org_agenda.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text);
                    root.items = parsed;
                    console.log("OrgAgenda: loaded", parsed.length, "items");

                    // Build date lookup
                    let dates = {};
                    for (let i = 0; i < parsed.length; i++) {
                        let e = parsed[i];
                        if (e.deadline) dates[e.deadline] = true;
                        if (e.scheduled) dates[e.scheduled] = true;
                    }
                    root.datesWithEvents = dates;
                } catch (err) {
                    console.error("OrgAgenda: Failed to parse JSON:", err, "raw:", this.text.substring(0, 200));
                    root.items = [];
                    root.datesWithEvents = {};
                }
                root.loading = false;
            }
        }
    }

    // Auto-refresh on startup
    Component.onCompleted: refresh()

    // Periodic refresh (every 60 seconds)
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
