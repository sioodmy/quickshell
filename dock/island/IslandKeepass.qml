import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services
import qs.components

Row {
    id: root
    spacing: 12

    property var entry: null
    signal closeRequested()

    property bool copiedUser: false
    property bool copiedPass: false
    property bool copiedOtp: false

    function checkAutoClose() {
        let needOtp = root.entry && root.entry.has_otp;
        let needUser = root.entry && root.entry.username !== "";
        let readyUser = !needUser || copiedUser;
        let readyOtp = !needOtp || copiedOtp;
        if (readyUser && copiedPass && readyOtp) {
            autoCloseDelay.start();
        }
    }

    property string currentOtp: ""
    property int otpRemaining: 0

    Connections {
        target: KeepassBackend
        function onOtpResult(id, code, remaining) {
            if (root.entry && root.entry.id === id) {
                root.currentOtp = code;
                root.otpRemaining = remaining;
                otpCountdown.restart();
            }
        }
    }

    Timer {
        id: otpCountdown
        interval: 1000
        repeat: true
        running: root.otpRemaining > 0
        onTriggered: {
            root.otpRemaining--;
            if (root.otpRemaining <= 0) {
                if (root.entry && root.entry.has_otp) {
                    KeepassBackend.getOtp(root.entry.id);
                }
            }
        }
    }

    onEntryChanged: {
        if (entry && entry.has_otp) {
            KeepassBackend.getOtp(entry.id);
        } else {
            currentOtp = "";
            otpRemaining = 0;
            otpCountdown.stop();
        }
    }

    // Small delay so user sees the final checkmark before it closes
    Timer {
        id: autoCloseDelay
        interval: 600
        onTriggered: root.closeRequested()
    }

    // Safety timeout
    Timer {
        running: true
        interval: 60000
        onTriggered: root.closeRequested()
    }

    // Icon
    Rectangle {
        width: 32; height: 32; radius: 16
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

        MaterialIcon {
            anchors.centerIn: parent
            icon: root.entry && root.entry.is_smart ? "auto_awesome" : "vpn_key"
            font.pixelSize: 16
            color: Theme.primary
        }
    }

    // Title
    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        width: 140

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.entry ? root.entry.title : ""
            font.family: "Google Sans"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.on_surface
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.entry && root.entry.username !== "" ? root.entry.username : "Credentials ready"
            font.family: "Google Sans"
            font.pixelSize: 12
            color: Theme.on_surface_variant
        }
    }

    Item { width: 4; height: 1 } // Spacer

    // Action buttons
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Username
        Rectangle {
            visible: root.entry && root.entry.username !== ""
            width: userRow.implicitWidth + 16
            height: 28; radius: 14
            color: root.copiedUser ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (userBtnMouse.containsMouse ? Theme.surface_variant : Theme.surface_container_highest)
            border.width: root.copiedUser ? 1 : 0
            border.color: Theme.primary

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: userRow
                anchors.centerIn: parent
                spacing: 4
                MaterialIcon {
                    icon: root.copiedUser ? "check" : "person"
                    font.pixelSize: 13
                    color: root.copiedUser ? Theme.primary : Theme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.copiedUser ? "Copied" : "User"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: root.copiedUser ? Theme.primary : Theme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: userBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.entry) {
                        KeepassBackend.copyField(root.entry.id, "username");
                        root.copiedUser = true;
                        root.checkAutoClose();
                    }
                }
            }
        }

        // Password
        Rectangle {
            width: passRow.implicitWidth + 16
            height: 28; radius: 14
            color: root.copiedPass ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Theme.primary
            border.width: root.copiedPass ? 1 : 0
            border.color: Theme.primary
            opacity: passBtnMouse.containsMouse ? 0.85 : 1.0

            Row {
                id: passRow
                anchors.centerIn: parent
                spacing: 4
                MaterialIcon {
                    icon: root.copiedPass ? "check" : "key"
                    font.pixelSize: 13
                    color: root.copiedPass ? Theme.primary : Theme.on_primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.copiedPass ? "Copied" : "Password"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: root.copiedPass ? Theme.primary : Theme.on_primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: passBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.entry) {
                        KeepassBackend.copyField(root.entry.id, "password");
                        root.copiedPass = true;
                        root.checkAutoClose();
                    }
                }
            }
        }

        // OTP
        Rectangle {
            visible: root.entry && root.entry.has_otp
            width: otpRow.implicitWidth + 24
            height: 28; radius: 14
            color: root.copiedOtp ? Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.15) : Theme.tertiary
            border.width: root.copiedOtp ? 1 : 0
            border.color: Theme.tertiary
            opacity: otpBtnMouse.containsMouse ? 0.85 : 1.0

            Row {
                id: otpRow
                anchors.centerIn: parent
                spacing: 6
                
                Item {
                    width: 14; height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.copiedOtp && root.currentOtp !== ""
                    
                    Canvas {
                        anchors.fill: parent
                        property real progress: root.otpRemaining / 30.0
                        onProgressChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cx = width / 2;
                            var cy = height / 2;
                            var r = width / 2 - 1.5;
                            
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                            ctx.lineWidth = 1.5;
                            ctx.strokeStyle = Qt.rgba(Theme.on_tertiary.r, Theme.on_tertiary.g, Theme.on_tertiary.b, 0.3);
                            ctx.stroke();
                            
                            if (progress > 0) {
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + (2 * Math.PI * progress));
                                ctx.lineWidth = 1.5;
                                ctx.strokeStyle = Theme.on_tertiary;
                                ctx.stroke();
                            }
                        }
                    }
                }

                MaterialIcon {
                    icon: root.copiedOtp ? "check" : "pin"
                    font.pixelSize: 13
                    color: root.copiedOtp ? Theme.tertiary : Theme.on_tertiary
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.copiedOtp || root.currentOtp === ""
                }
                
                Text {
                    text: root.copiedOtp ? "Copied" : (root.currentOtp ? root.currentOtp.substring(0, 3) + " " + root.currentOtp.substring(3) : "OTP")
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: root.copiedOtp ? Theme.tertiary : Theme.on_tertiary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: otpBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.entry) {
                        KeepassBackend.copyField(root.entry.id, "otp");
                        root.copiedOtp = true;
                        root.checkAutoClose();
                    }
                }
            }
        }
    }

    Item { width: 4; height: 1 } // Spacer

    // Close
    Rectangle {
        width: 32; height: 32; radius: 16
        anchors.verticalCenter: parent.verticalCenter
        color: closeBtnMouse.containsMouse ? Theme.surface_variant : "transparent"

        MaterialIcon {
            anchors.centerIn: parent
            icon: "close"
            font.pixelSize: 18
            color: Theme.on_surface
        }

        MouseArea {
            id: closeBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }
    }
}
