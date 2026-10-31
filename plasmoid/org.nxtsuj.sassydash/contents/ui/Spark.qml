import QtQuick
import org.kde.quickcharts as Charts

// Rolling line chart (max two lines), GPU-drawn by QuickCharts. Samples are
// pushed on Stats.tick; between samples the chart slides left one step on the
// paced Stats frames (Electron's continuous glide), so only its x moves.
Item {
    id: spark
    property var values: []                  // current sample per line
    property var colors: [Theme.accent]
    property int history: 60
    property real maximum: 100               // <= 0 → automatic range
    property int every: 1                    // sample every n ticks
    property bool grid: false                // faint dashed quarter lines (System-Graph)

    property var h0: new Array(history).fill(0)
    property var h1: new Array(history).fill(0)

    // history points span width + one step; the newest one starts hidden past the right edge.
    readonly property real step: width / Math.max(1, history - 2)
    readonly property real phase: ((Stats.ticks % every) + Stats.eased) / every
    clip: true

    Charts.LineChart {
        id: chart
        readonly property Charts.ArraySource line0: Charts.ArraySource { array: spark.h0 }
        readonly property Charts.ArraySource line1: Charts.ArraySource { array: spark.h1 }
        x: -spark.phase * spark.step
        width: spark.width + spark.step
        height: spark.height
        smooth: true
        lineWidth: 1.5
        fillOpacity: 0.12
        yRange { from: 0; to: spark.maximum; automatic: spark.maximum <= 0 }
        colorSource: Charts.ArraySource { array: spark.colors }
        valueSources: spark.values.length > 1 ? [line0, line1] : [line0]
    }

    Repeater {
        model: spark.grid ? 3 : 0
        Row {
            required property int index
            y: Math.round(spark.height * (index + 1) / 4)
            spacing: 3
            Repeater {
                model: Math.ceil(spark.width / 6)
                Rectangle { width: 3; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
            }
        }
    }

    Connections {
        target: Stats
        function onTick() {
            if (Stats.ticks % spark.every) return;
            spark.h0 = spark.h0.slice(1 - spark.history).concat([spark.values[0] ?? 0]);
            if (spark.values.length > 1) spark.h1 = spark.h1.slice(1 - spark.history).concat([spark.values[1] ?? 0]);
        }
    }
}
