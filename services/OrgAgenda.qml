pragma Singleton

import QtQuick
import Quickshell

/**
 * Org-mode agenda service.
 * Connects to the unified BackendDaemon for agenda data.
 */
Singleton {
    id: root

    // Full parsed agenda items (sorted: active first, then by date)
    readonly property var items: BackendDaemon.agendaItems

    // Set of date strings ("YYYY-MM-DD") that have agenda entries
    property var datesWithEvents: ({})

    // Loading state (no longer really applicable since it's instant from daemon, but keep for compat)
    property bool loading: items === undefined || items.length === 0

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

    // Refresh data from disk (Daemon does this automatically, but we can send a manual refresh event)
    function refresh() {
        BackendDaemon.send({"action": "agenda_refresh"});
    }

    onItemsChanged: {
        let dates = {};
        for (let i = 0; i < items.length; i++) {
            let e = items[i];
            if (e.deadline) dates[e.deadline] = true;
            if (e.scheduled) dates[e.scheduled] = true;
        }
        root.datesWithEvents = dates;
    }
}
