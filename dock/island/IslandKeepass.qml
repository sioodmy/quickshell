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
    property string pendingCopyRequest: ""
    property string pendingCopyId: ""
    property string pendingCopyField: ""
    property string failedCopyField: ""

    function copyField(field) {
        if (!entry || !BackendDaemon.available || !KeepassBackend.isUnlocked || SessionState.locked || pendingCopyRequest !== "") return;
        autoCloseDelay.stop();
        failedCopyField = "";
        if (field === "username") copiedUser = false;
        else if (field === "password") copiedPass = false;
        else if (field === "otp") copiedOtp = false;
        pendingCopyRequest = KeepassBackend.copyField(entry.id, field);
        if (pendingCopyRequest === "") {
            failedCopyField = field;
            return;
        }
        pendingCopyId = entry.id;
        pendingCopyField = field;
    }

    function clearState() {
        currentOtp = "";
        otpRemaining = 0;
        otpExpiresAt = 0;
        otpCountdown.stop();
        autoCloseDelay.stop();
        copiedUser = false;
        copiedPass = false;
        copiedOtp = false;
        pendingCopyRequest = "";
        pendingCopyId = "";
        pendingCopyField = "";
        failedCopyField = "";
    }

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
    property double otpExpiresAt: 0

    Connections {
        target: KeepassBackend
        function onOtpResult(id, code, remaining) {
            if (root.entry && root.entry.id === id && KeepassBackend.isUnlocked) {
                root.currentOtp = remaining > 0 ? code : "";
                root.otpRemaining = Math.max(0, remaining);
                root.otpExpiresAt = Date.now() + root.otpRemaining * 1000;
                if (root.otpRemaining > 0) otpCountdown.restart();
                else otpCountdown.stop();
            }
        }
        function onCopyResult(requestId, id, field, success) {
            if (root.pendingCopyRequest === "" || root.pendingCopyRequest !== requestId || !root.entry || root.entry.id !== id || root.pendingCopyId !== id || root.pendingCopyField !== field) return;
            root.pendingCopyRequest = "";
            root.pendingCopyId = "";
            root.pendingCopyField = "";
            if (!success) {
                root.failedCopyField = field;
                return;
            }
            if (field === "username") root.copiedUser = true;
            else if (field === "password") root.copiedPass = true;
            else if (field === "otp") root.copiedOtp = true;
            root.checkAutoClose();
        }
        function onLocked() {
            root.clearState();
            root.closeRequested();
        }
    }

    Timer {
        id: otpCountdown
        interval: 1000
        repeat: true
        running: root.otpRemaining > 0
        onTriggered: {
            root.otpRemaining = Math.max(0, Math.ceil((root.otpExpiresAt - Date.now()) / 1000));
            if (root.otpRemaining <= 0) {
                root.currentOtp = "";
                otpCountdown.stop();
                if (root.entry && root.entry.has_otp) {
                    KeepassBackend.getOtp(root.entry.id);
                }
            }
        }
    }

    onEntryChanged: {
        clearState();
        if (entry && entry.has_otp) {
            KeepassBackend.getOtp(entry.id);
        }
    }

    Timer {
        id: autoCloseDelay
        interval: 600
        onTriggered: root.closeRequested()
    }

    Timer {
        running: true
        interval: 60000
        onTriggered: root.closeRequested()
    }

    Rectangle {
        width: 32; height: 32; radius: 16
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.glass_accent
        border.width: 1
        border.color: Theme.glass_border

        MaterialIcon {
            anchors.centerIn: parent
            icon: "vpn_key"
            font.pixelSize: 16
            color: Theme.primary
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        width: 140

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.entry ? root.entry.title : ""
            textFormat: Text.PlainText
            font.family: "Google Sans"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.on_surface
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.entry && root.entry.username !== "" ? root.entry.username : "Credentials ready"
            textFormat: Text.PlainText
            font.family: "Google Sans"
            font.pixelSize: 12
            color: Theme.on_surface_variant
        }
    }

    Item { width: 4; height: 1 }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            visible: root.entry && root.entry.username !== ""
            width: userRow.implicitWidth + 16
            height: 28; radius: 14
            color: root.copiedUser ? Theme.glass_accent_soft
                : (userBtnMouse.containsMouse ? Theme.glass_hover : Theme.glass_raised)
            border.width: 1
            border.color: root.copiedUser ? Theme.primary : Theme.glass_border

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
                    text: root.pendingCopyField === "username" ? "Copying..." : root.failedCopyField === "username" ? "Copy failed" : root.copiedUser ? "Copied" : "User"
                    textFormat: Text.PlainText
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: root.copiedUser ? Theme.primary : Theme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: userBtnMouse
                enabled: BackendDaemon.available && KeepassBackend.isUnlocked && !SessionState.locked && root.pendingCopyRequest === ""
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyField("username")
            }
        }

        Rectangle {
            width: passRow.implicitWidth + 16
            height: 28; radius: 14
            color: root.copiedPass ? Theme.glass_accent_soft : Theme.glass_accent
            border.width: 1
            border.color: root.copiedPass ? Theme.primary : Theme.glass_border

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: passRow
                anchors.centerIn: parent
                spacing: 4
                MaterialIcon {
                    icon: root.copiedPass ? "check" : "key"
                    font.pixelSize: 13
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.pendingCopyField === "password" ? "Copying..." : root.failedCopyField === "password" ? "Copy failed" : root.copiedPass ? "Copied" : "Password"
                    textFormat: Text.PlainText
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: passBtnMouse
                enabled: BackendDaemon.available && KeepassBackend.isUnlocked && !SessionState.locked && root.pendingCopyRequest === ""
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyField("password")
            }
        }

        Rectangle {
            visible: root.entry && root.entry.has_otp
            width: otpRow.implicitWidth + 24
            height: 28; radius: 14
            color: root.copiedOtp ? Theme.glass_tertiary_soft : Theme.glass_tertiary
            border.width: 1
            border.color: root.copiedOtp ? Theme.tertiary : Theme.glass_border

            Behavior on color { ColorAnimation { duration: 120 } }

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
                            ctx.strokeStyle = Qt.alpha(Theme.tertiary, 0.3);
                            ctx.stroke();

                            if (progress > 0) {
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + (2 * Math.PI * progress));
                                ctx.lineWidth = 1.5;
                                ctx.strokeStyle = Theme.tertiary;
                                ctx.stroke();
                            }
                        }
                    }
                }

                MaterialIcon {
                    icon: root.copiedOtp ? "check" : "pin"
                    font.pixelSize: 13
                    color: Theme.tertiary
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.copiedOtp || root.currentOtp === ""
                }

                Text {
                    text: root.pendingCopyField === "otp" ? "Copying..." : root.failedCopyField === "otp" ? "Copy failed" : root.copiedOtp ? "Copied" : (root.currentOtp ? root.currentOtp.substring(0, 3) + " " + root.currentOtp.substring(3) : "OTP")
                    textFormat: Text.PlainText
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.tertiary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: otpBtnMouse
                enabled: BackendDaemon.available && KeepassBackend.isUnlocked && !SessionState.locked && root.pendingCopyRequest === ""
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyField("otp")
            }
        }
    }

    Item { width: 4; height: 1 }

    Rectangle {
        width: 32; height: 32; radius: 16
        anchors.verticalCenter: parent.verticalCenter
        color: closeBtnMouse.containsMouse ? Theme.glass_hover : "transparent"
        border.width: closeBtnMouse.containsMouse ? 1 : 0
        border.color: Theme.glass_border

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
