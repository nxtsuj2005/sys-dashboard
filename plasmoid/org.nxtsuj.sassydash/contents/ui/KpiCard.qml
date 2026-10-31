import QtQuick
import QtQuick.Layouts

Card {
    id: kpi
    property string value: "—"
    property string sub: ""
    property color valueColor: Theme.text
    property alias spark: spark

    // Trend arrow (Electron updateKpiTrends): compare against `back` ticks ago,
    // show ▲/▼ only past `threshold`; ▲ turns red at `hotAt`.
    property real trendValue: NaN
    property int back: 4
    property real threshold: 5
    property real hotAt: Infinity
    property var trendHist: []
    property int trend: 0
    Connections {
        target: Stats
        enabled: !isNaN(kpi.trendValue)
        function onTick() {
            const h = kpi.trendHist.slice(-kpi.back).concat([kpi.trendValue]);
            kpi.trendHist = h;
            const d = h.length > kpi.back ? h[h.length - 1] - h[0] : 0;
            kpi.trend = Math.abs(d) >= kpi.threshold ? Math.sign(d) : 0;
        }
    }
    headerExtras: Text {
        text: kpi.trend > 0 ? "▲" : kpi.trend < 0 ? "▼" : ""
        color: kpi.trend > 0 ? (kpi.trendValue >= kpi.hotAt ? Theme.red : Theme.accent)
                             : Qt.tint(Theme.muted, "#b33fb950")
        font { family: Theme.mono; pixelSize: 11 }
    }

    padding: 9
    titleGap: 3

    ColumnLayout {
        anchors.fill: parent
        spacing: 3
        Text {
            text: kpi.value
            color: kpi.valueColor
            font { family: Theme.display; pixelSize: kpi.height >= 92 ? 30 : 25; weight: Font.Bold; letterSpacing: 0.5 }
            Behavior on color { ColorAnimation { duration: 350 } }
        }
        Text {
            visible: kpi.sub !== ""
            text: kpi.sub
            color: Theme.muted
            font { family: Theme.mono; pixelSize: 10 }
        }
        Spark {
            id: spark
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 12
        }
    }
}
