import QtQuick
import qs.theme

/**
 * Material Design 3 styled card for a single org agenda entry.
 * Shows state chip, title, deadline/scheduled info, tags, and body preview.
 *
 * Usage: set entryData to the org entry object.
 */
Rectangle {
    id: root

    property var entryData: ({})
    property bool showDate: false
    property bool isOverdue: false

    // Guard all property reads against missing/undefined data
    readonly property string _title: entryData.title || ""
    readonly property string _state: entryData.state || ""
    readonly property string _file: entryData.file || ""
    readonly property string _deadline: entryData.deadline || ""
    readonly property string _deadlineTime: entryData.deadline_time || ""
    readonly property string _scheduled: entryData.scheduled || ""
    readonly property string _scheduledTime: entryData.scheduled_time || ""
    readonly property string _body: entryData.body || ""
    readonly property var _tags: entryData.tags || []

    height: cardContent.implicitHeight + 16
    radius: 16
    color: cardMouse.containsMouse
        ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
        : Theme.surface_container

    border.color: root.isOverdue
        ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.25)
        : "transparent"
    border.width: root.isOverdue ? 1 : 0

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    // Subtle press/hover scale
    scale: cardMouse.pressed ? 0.97 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    // State indicator stripe on the left
    Rectangle {
        id: stateStripe
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 16
        radius: 2
        color: {
            if (root.isOverdue) return Theme.critical;
            if (root._state === "DONE" || root._state === "CANCELLED")
                return Theme.outline;
            if (root._state === "TODO" || root._state === "NEXT")
                return Theme.primary;
            if (root._state === "WAITING")
                return Theme.tertiary;
            return Theme.outline_variant;
        }

        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Column {
        id: cardContent
        anchors.left: stateStripe.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        // ── Top row: state chip + title ──
        Row {
            width: parent.width
            spacing: 6

            // State chip
            Rectangle {
                visible: root._state !== ""
                width: stateChipText.implicitWidth + 12
                height: 18
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    if (root._state === "DONE") return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                    if (root._state === "CANCELLED") return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12);
                    if (root._state === "TODO") return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15);
                    if (root._state === "NEXT") return Theme.primary_container;
                    if (root._state === "WAITING") return Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.15);
                    return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                }

                Text {
                    id: stateChipText
                    anchors.centerIn: parent
                    text: {
                        if (root._state === "TODO") return "TODO";
                        if (root._state === "DONE") return "✓";
                        if (root._state === "NEXT") return "NEXT";
                        if (root._state === "WAITING") return "WAIT";
                        if (root._state === "CANCELLED") return "✕";
                        if (root._state === "HOLD") return "HOLD";
                        return root._state;
                    }
                    color: {
                        if (root._state === "DONE") return Theme.primary;
                        if (root._state === "CANCELLED") return Theme.outline;
                        if (root._state === "TODO" || root._state === "NEXT") return Theme.primary;
                        if (root._state === "WAITING") return Theme.tertiary;
                        return Theme.on_surface_variant;
                    }
                    font { family: "Google Sans"; pointSize: 8; weight: Font.Bold }
                }
            }

            // Title
            Text {
                width: parent.width - (root._state !== "" ? stateChipText.implicitWidth + 18 : 0)
                text: root._title
                color: (root._state === "DONE" || root._state === "CANCELLED")
                    ? Theme.on_surface_variant
                    : Theme.on_surface
                font {
                    family: "Google Sans"
                    pointSize: 11
                    weight: Font.DemiBold
                    strikeout: root._state === "DONE" || root._state === "CANCELLED"
                }
                elide: Text.ElideRight
                maximumLineCount: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Date/time row ──
        Row {
            visible: root._deadline !== "" || root._scheduled !== "" || root.showDate
            spacing: 8

            // Deadline badge
            Row {
                visible: root._deadline !== ""
                spacing: 3

                Text {
                    text: "󰃰"
                    color: root.isOverdue ? Theme.critical : Theme.on_surface_variant
                    font { family: "JetBrainsMono Nerd Font"; pointSize: 9 }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: {
                        if (root._deadline === "") return "";
                        let parts = root._deadline.split("-");
                        let d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                        let formatted = Qt.formatDate(d, "MMM d");
                        if (root._deadlineTime) formatted += " " + root._deadlineTime;
                        return formatted;
                    }
                    color: root.isOverdue ? Theme.critical : Theme.on_surface_variant
                    font {
                        family: "Google Sans"; pointSize: 9; weight: Font.Medium
                        italic: root.isOverdue
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Scheduled badge
            Row {
                visible: root._scheduled !== "" && root._deadline === ""
                spacing: 3

                Text {
                    text: "󰸗"
                    color: Theme.on_surface_variant
                    font { family: "JetBrainsMono Nerd Font"; pointSize: 9 }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: {
                        if (root._scheduled === "") return "";
                        let parts = root._scheduled.split("-");
                        let d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                        let formatted = Qt.formatDate(d, "MMM d");
                        if (root._scheduledTime) formatted += " " + root._scheduledTime;
                        return formatted;
                    }
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pointSize: 9; weight: Font.Medium }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── Tags row ──
        Row {
            visible: root._tags.length > 0
            spacing: 4

            Repeater {
                model: root._tags

                Rectangle {
                    required property var modelData
                    width: tagText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.12)

                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: modelData
                        color: Theme.secondary
                        font { family: "Google Sans"; pointSize: 8; weight: Font.Medium }
                    }
                }
            }
        }

        // ── Body preview ──
        Text {
            visible: root._body !== ""
            width: parent.width
            text: root._body.split("\\n")[0]
            color: Theme.on_surface_variant
            opacity: 0.7
            font { family: "Google Sans"; pointSize: 9 }
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // ── Source file badge ──
        Text {
            visible: root._file !== ""
            text: "from " + root._file
            color: Theme.on_surface_variant
            opacity: 0.35
            font { family: "Google Sans"; pointSize: 8; weight: Font.Medium; italic: true }
        }
    }
}
