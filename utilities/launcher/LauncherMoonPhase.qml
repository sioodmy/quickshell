import QtQuick

Canvas {
    id: root

    property real illPercent: 50
    property bool isWaxing: true

    onIllPercentChanged: requestPaint()
    onIsWaxingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        var cx = width / 2;
        var cy = height / 2;
        var r = width / 2;

        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12);
        ctx.fill();

        var p = illPercent / 100.0;
        var w = Math.abs(p - 0.5) * 2 * r;

        ctx.save();
        ctx.beginPath();
        if (isWaxing) {
            ctx.rect(cx, cy - r, r, r * 2);
        } else {
            ctx.rect(cx - r, cy - r, r, r * 2);
        }
        ctx.clip();

        if (p < 0.5) {
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.95);
            ctx.fill();

            ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath();
            ctx.ellipse(cx - w, cy - r, w * 2, r * 2);
            ctx.fillStyle = Qt.rgba(0, 0, 0, 1);
            ctx.fill();

            ctx.globalCompositeOperation = "source-over";
            ctx.beginPath();
            ctx.ellipse(cx - w, cy - r, w * 2, r * 2);
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12);
            ctx.fill();
        } else {
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.95);
            ctx.fill();
        }
        ctx.restore();

        if (p >= 0.5) {
            ctx.save();
            ctx.beginPath();
            if (isWaxing) {
                ctx.rect(cx - r, cy - r, r, r * 2);
            } else {
                ctx.rect(cx, cy - r, r, r * 2);
            }
            ctx.clip();

            ctx.beginPath();
            ctx.ellipse(cx - w, cy - r, w * 2, r * 2);
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.95);
            ctx.fill();
            ctx.restore();
        }

        var crater = Math.max(1, r * 0.15);
        ctx.fillStyle = Qt.rgba(0, 0, 0, 0.15);
        ctx.beginPath(); ctx.arc(cx - r * 0.35, cy - r * 0.35, crater, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(cx + r * 0.35, cy + r * 0.25, crater * 1.2, 0, Math.PI * 2); ctx.fill();
    }
}
