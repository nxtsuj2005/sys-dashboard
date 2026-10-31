import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// Compact header (Electron #compactbar): brand left, metrics + clock right.
// Values update on the shared 1 s tick; gauge arcs ease on the paced glide
// frames. Every text slot has a fixed width so changing numbers never shift the bar.
Rectangle {
    id: bar
    property bool tall: true          // >= 950 px screen height in Electron terms
    readonly property int metricPad: tall ? 20 : 13

    color: "#141c26"
    border.color: "#334253"
    radius: 3
    readonly property FxState fx: FxState { h: bar.height }
    transform: [fx.shear, fx.shift]
    opacity: fx.opacity
    FxCut { fx: bar.fx }

    Rectangle {   // 3 px accent edge on the left
        width: 3; height: parent.height; radius: 1
        color: "#79b1f8"
    }

    component Label: Text {
        color: "#90a4bb"
        font { family: Theme.mono; pixelSize: bar.tall ? 9 : 8; letterSpacing: 0.7 }
    }
    // Text reserving the width of its widest expected content (`sample`).
    component Slot: Text {
        id: slot
        property string sample
        readonly property TextMetrics tm: TextMetrics { font: slot.font; text: slot.sample }
        width: Math.ceil(tm.advanceWidth)
        Layout.preferredWidth: width
        elide: Text.ElideRight
        color: "#dce8f6"
        font { family: Theme.mono; pixelSize: bar.tall ? 12 : 11; weight: Font.Medium }
    }
    // Half-ring arc (SVG "M4 23 A16 16 0 0 1 36 23" in a 40x29 box) with the value inside.
    component Gauge: Item {
        id: g
        property real pct: 0
        property color fill: "#91bffd"
        readonly property Glide shown: Glide { to: Math.max(0, Math.min(100, g.pct)) }
        readonly property real s: (bar.tall ? 42 : 33) / 40
        implicitWidth: 40 * s
        implicitHeight: 29 * s
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#354252"; strokeWidth: 3 * g.s; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 20 * g.s; centerY: 23 * g.s; radiusX: 16 * g.s; radiusY: 16 * g.s; startAngle: 180; sweepAngle: 180 }
            }
            ShapePath {
                strokeColor: g.shown.value > 0.5 ? g.fill : "transparent"; strokeWidth: 3 * g.s; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 20 * g.s; centerY: 23 * g.s; radiusX: 16 * g.s; radiusY: 16 * g.s
                    startAngle: 180; sweepAngle: 180 * g.shown.value / 100
                }
            }
        }
        Text {
            x: 0; width: parent.width
            y: 17 * g.s
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(g.pct) + "%"
            color: "#e1ebf8"
            font { family: Theme.mono; pixelSize: 9; weight: Font.DemiBold }
        }
    }

    // Battery: read once every 30 s straight from sysfs (first BAT* supply wins).
    property int batPct: -1
    property string batStatus: ""
    property string batUnit: ""
    Command {
        every: 30000
        command: "sh -c 'for b in /sys/class/power_supply/BAT*; do [ -r \"$b/capacity\" ] || continue; "
               + "cat \"$b/capacity\" \"$b/status\"; for f in energy_now energy_full power_now charge_now charge_full current_now; do "
               + "printf \"%s=\" $f; cat \"$b/$f\" 2>/dev/null || echo; done; exit 0; done'"
        onFinished: (out) => {
            const l = out.split("\n");
            const pct = parseInt(l[0], 10);
            if (!Number.isFinite(pct)) { bar.batPct = -1; return; }
            const kv = {};
            for (const s of l.slice(2)) { const i = s.indexOf("="); if (i > 0) kv[s.slice(0, i)] = Number(s.slice(i + 1)); }
            bar.batPct = pct;
            bar.batStatus = l[1] || "";
            // Remaining time + draw, like the Electron pill's tooltip parts.
            const now = kv.energy_now || kv.charge_now, full = kv.energy_full || kv.charge_full;
            const rate = kv.power_now || kv.current_now;
            const parts = [];
            if (rate > 0 && now > 0) {
                const h = bar.batStatus === "Charging" ? Math.max(0, full - now) / rate : now / rate;
                if (h > 0 && h < 48) parts.push(Math.floor(h) + ":" + String(Math.round((h % 1) * 60)).padStart(2, "0") + " h");
                if (kv.power_now > 0) parts.push((kv.power_now / 1e6).toFixed(1) + " W");
            }
            bar.batUnit = parts.join(" · ");
        }
    }

    property string clock: ""
    property string date: ""
    function updateClock() {
        const now = new Date();
        clock = Qt.formatTime(now, "HH:mm:ss");
        date = now.toLocaleDateString(Qt.locale("de_DE"), "ddd, dd. MMM").toUpperCase();
    }
    Connections { target: Stats; function onTick() { bar.updateClock(); } }
    Component.onCompleted: updateClock()

    RowLayout {
        anchors { fill: parent; leftMargin: bar.tall ? 15 : 13; rightMargin: bar.tall ? 12 : 10 }
        spacing: 0

        Row {
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "S/"
                color: "#85b9fb"
                font { family: Theme.mono; pixelSize: bar.tall ? 16 : 14; bold: true }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                text: "SASSY<font color=\"#75acf5\">·</font>DASH"
                color: Theme.text
                font { family: Theme.sans; pixelSize: bar.tall ? 15 : 12; bold: true; letterSpacing: 0.8 }
            }
        }
        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.leftMargin: bar.metricPad; Layout.rightMargin: bar.metricPad
            spacing: 8
            Label { text: "CPU" }
            Gauge { pct: Stats.cpu }
        }
        RowLayout {
            Layout.leftMargin: bar.metricPad; Layout.rightMargin: bar.metricPad
            spacing: 8
            Label { text: "RAM" }
            Gauge { pct: Stats.ramPct; fill: "#95c9b5" }
            Slot {
                sample: "00.0 G / 00.0 G"
                color: "#98acc3"; font { pixelSize: 9; weight: Font.Normal }
                text: (Stats.ramUsed / 1073741824).toFixed(1) + " G / " + (Stats.ramTotal / 1073741824).toFixed(1) + " G" }
        }
        RowLayout {
            Layout.leftMargin: bar.metricPad; Layout.rightMargin: bar.metricPad
            spacing: 8
            Label { text: "SSD" }
            Gauge { pct: Stats.diskPct; fill: "#c1b5da" }
        }
        RowLayout {
            Layout.leftMargin: bar.metricPad; Layout.rightMargin: bar.metricPad
            spacing: 8
            Label { text: "NETZ" }
            Column {
                spacing: bar.tall ? 2 : 1
                Slot { sample: "↓ 1023.9 KiB/s"; text: "↓ " + Stats.downText; color: "#83bcff"; font.pixelSize: bar.tall ? 10 : 9 }
                Slot { sample: "↓ 1023.9 KiB/s"; text: "↑ " + Stats.upText; color: "#8bcbb3"; font.pixelSize: bar.tall ? 10 : 9 }
            }
        }
        RowLayout {
            Layout.leftMargin: bar.metricPad; Layout.rightMargin: bar.metricPad
            spacing: 7
            Label { text: "TEMP" }
            Slot { sample: "100°C"; text: Stats.temp > 0 ? Math.round(Stats.temp) + "°C" : "—"; color: "#dfbd84" }
        }
        RowLayout {
            Layout.leftMargin: bar.metricPad; Layout.rightMargin: bar.metricPad
            spacing: 7
            Label { text: "LOAD" }
            Slot { sample: "00.00"; text: Stats.load1.toFixed(2) }
        }
        RowLayout {   // battery pill, laptops only
            visible: bar.batPct >= 0
            Layout.leftMargin: 8; Layout.rightMargin: bar.metricPad
            spacing: 7
            Rectangle { implicitWidth: 1; implicitHeight: 22; color: "#344254"; Layout.rightMargin: 9 }
            Item {
                implicitWidth: 25; implicitHeight: 11
                Rectangle {
                    width: 22; height: 11; radius: 2
                    color: "transparent"; border.color: "#8aa8c2"
                    Rectangle {
                        x: 2; y: 2; height: parent.height - 4
                        width: (parent.width - 4) * Math.max(0, Math.min(100, bar.batPct)) / 100
                        color: bar.batPct <= 15 && bar.batStatus !== "Charging" ? "#e58f8a" : "#83c3ab"
                    }
                }
                Rectangle { x: 23; y: 3; width: 2; height: 5; color: "#8aa8c2" }
            }
            Slot { sample: "100% ⚡"; text: bar.batPct + "%" + (bar.batStatus === "Charging" ? " ⚡" : "") }
            Slot {
                visible: text !== ""
                sample: "00:00 h · 00.0 W"
                text: bar.batUnit
                color: "#98acc3"; font { pixelSize: bar.tall ? 9 : 8; weight: Font.Normal }
            }
        }

        Column {
            Layout.leftMargin: 8
            spacing: bar.tall ? 2 : 0
            Text {
                anchors.right: parent.right
                text: bar.clock
                color: Theme.text
                font { family: Theme.mono; pixelSize: bar.tall ? 15 : 13; weight: Font.Medium; letterSpacing: 1 }
            }
            Text {
                anchors.right: parent.right
                text: bar.date
                color: "#8ea4be"
                font { family: Theme.mono; pixelSize: bar.tall ? 8 : 7; letterSpacing: 0.6 }
            }
        }
    }
}
