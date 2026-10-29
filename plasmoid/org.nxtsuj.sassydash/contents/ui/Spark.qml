import QtQuick
import org.kde.quickcharts as Charts

// Rolling line chart (max two lines), GPU-drawn by QuickCharts. Samples are
// pushed on Stats.tick so every chart updates in the same frame.
Charts.LineChart {
    id: chart
    property var values: []                  // current sample per line
    property var colors: [Theme.accent]
    property int history: 60
    property real maximum: 100               // <= 0 → automatic range
    property int every: 1                    // sample every n ticks

    property var h0: new Array(history).fill(0)
    property var h1: new Array(history).fill(0)
    readonly property Charts.ArraySource line0: Charts.ArraySource { array: chart.h0 }
    readonly property Charts.ArraySource line1: Charts.ArraySource { array: chart.h1 }

    smooth: true
    lineWidth: 1.5
    fillOpacity: 0.12
    yRange { from: 0; to: chart.maximum; automatic: chart.maximum <= 0 }
    colorSource: Charts.ArraySource { array: chart.colors }
    valueSources: chart.values.length > 1 ? [line0, line1] : [line0]

    Connections {
        target: Stats
        function onTick() {
            if (Stats.ticks % chart.every) return;
            chart.h0 = chart.h0.slice(1 - chart.history).concat([chart.values[0] ?? 0]);
            if (chart.values.length > 1) chart.h1 = chart.h1.slice(1 - chart.history).concat([chart.values[1] ?? 0]);
        }
    }
}
