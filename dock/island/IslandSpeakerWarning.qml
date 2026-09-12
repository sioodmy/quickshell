import QtQuick
import Quickshell
import qs.theme
import qs.components

Row {
    id: root
    spacing: 12

    signal dismissed()
    
    property int timeoutValue: 5000
    property int maxTimeout: 5000
    
    NumberAnimation on timeoutValue {
        id: countdownAnim
        from: root.maxTimeout
        to: 0
        duration: root.maxTimeout
        running: true
        onFinished: {
            if (root.timeoutValue <= 0) {
                unmute();
            }
        }
    }

    function unmute() {
        Quickshell.execDetached({ command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"] });
        countdownAnim.stop();
        root.dismissed();
    }
    
    function keepMuted() {
        countdownAnim.stop();
        root.dismissed();
    }

    Rectangle {
        width: 32
        height: 32
        radius: 16
        color: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)
        anchors.verticalCenter: parent.verticalCenter
        MaterialIcon {
            anchors.centerIn: parent
            icon: "volume_off"
            color: Theme.critical
            font.pixelSize: 16
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        width: 190
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: "Speakers Muted"
            font.family: "Google Sans"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.on_surface
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: "Auto-muted to prevent loud noise."
            font.family: "Google Sans"
            font.pixelSize: 12
            color: Theme.on_surface_variant
        }
    }

    Item { width: 4; height: 1 } // Spacer

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: 90
            height: 28
            radius: 14
            color: Theme.surface_variant
            
            Row {
                anchors.centerIn: parent
                spacing: 4
                MaterialIcon {
                    icon: "volume_off"
                    font.pixelSize: 13
                    color: Theme.on_surface_variant
                }
                Text {
                    text: "Keep"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.on_surface_variant
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.keepMuted()
            }
        }

        Rectangle {
            width: 90
            height: 28
            radius: 14
            color: Theme.primary
            
            Row {
                anchors.centerIn: parent
                spacing: 4
                MaterialIcon {
                    icon: "volume_up"
                    font.pixelSize: 13
                    color: Theme.on_primary
                }
                Text {
                    text: "Unmute"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.on_primary
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.unmute()
            }
        }
    }

    Item { width: 4; height: 1 } // Spacer

    // Circular Progress
    Item {
        width: 32
        height: 32
        anchors.verticalCenter: parent.verticalCenter
        
        Canvas {
            id: progressCircle
            anchors.fill: parent
            
            property real progress: root.timeoutValue / root.maxTimeout
            onProgressChanged: requestPaint()
            
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var r = width / 2 - 2;
                
                // BG
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.lineWidth = 2;
                ctx.strokeStyle = Theme.surface_variant;
                ctx.stroke();
                
                // FG
                if (progress > 0) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + (2 * Math.PI * progress));
                    ctx.lineWidth = 2;
                    ctx.strokeStyle = Theme.primary;
                    ctx.stroke();
                }
            }
        }
    }
}
