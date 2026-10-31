import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors

Card {
    title: "System-Graph"
    headerExtras: [
        Legend { label: "CPU"; swatch: Theme.accent },
        Legend { label: "RAM"; swatch: Theme.green }
    ]

    component Legend: Row {
        property string label
        property color swatch
        spacing: 5
        Rectangle { width: 7; height: 2; color: parent.swatch; anchors.verticalCenter: parent.verticalCenter }
        Text { text: parent.label; color: Theme.muted; font { family: Theme.mono; pixelSize: 9; letterSpacing: 1 } }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Spark {
            Layout.fillWidth: true
            Layout.fillHeight: true
            history: 120
            grid: true
            values: [Stats.cpu, Stats.ramPct]
            colors: [Theme.accent, Theme.green]
        }

        // Electron #core-bars: 4-column grid, at most 8 bars; above 8 cores each
        // bar averages a contiguous group ("C0–3"). Bars ease on the paced glide frames.
        GridLayout {
            id: bars
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.topMargin: -2
            columns: 4
            columnSpacing: 12
            rowSpacing: 6
            readonly property int total: Stats.cores
            readonly property int n: Math.min(total, 8)
            Rectangle { Layout.columnSpan: 4; Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
            Repeater {
                model: bars.n
                delegate: ColumnLayout {
                    id: core
                    required property int index
                    readonly property int a: Math.floor(index * bars.total / bars.n)
                    readonly property int b: Math.floor((index + 1) * bars.total / bars.n)
                    readonly property bool grouped: bars.total > bars.n
                    property real pct
                    readonly property Glide shown: Glide { to: core.pct }
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 3
                    Instantiator {
                        id: sensors
                        model: core.b - core.a
                        delegate: Sensors.Sensor { required property int index; sensorId: "cpu/cpu" + (core.a + index) + "/usage" }
                    }
                    Connections {
                        target: Stats
                        function onTick() {
                            let sum = 0;
                            for (let i = 0; i < sensors.count; i++) sum += Number(sensors.objectAt(i)?.value) || 0;
                            core.pct = Math.max(0, Math.min(100, sensors.count ? sum / sensors.count : 0));
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: !core.grouped ? "Core " + core.a : core.b - core.a > 1 ? "C" + core.a + "–" + (core.b - 1) : "C" + core.a
                            color: Theme.muted
                            font { family: Theme.mono; pixelSize: 9 }
                        }
                        Text { text: Math.round(core.pct) + "%"; color: Theme.muted; font { family: Theme.mono; pixelSize: 9 } }
                    }
                    Rectangle {   // track with a faint static hatch, like .bar-track
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        color: Theme.panel
                        border.color: Theme.border
                        clip: true
                        Row {
                            x: -height; spacing: 5
                            Repeater {
                                model: Math.ceil(parent.parent.width / 7) + 2
                                Rectangle { width: 2; height: 9; y: -2; rotation: 45; color: Qt.rgba(0.6, 0.65, 0.7, 0.07) }
                            }
                        }
                        Rectangle {
                            id: fill
                            height: parent.height
                            width: parent.width * core.shown.value / 100
                            readonly property color c: core.pct > 80 ? Theme.red : core.pct > 60 ? Theme.orange : Theme.accent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.tint(Theme.bg, Qt.alpha(fill.c, 0.6)) }
                                GradientStop { position: 1; color: fill.c }
                            }
                        }
                    }
                }
            }
        }
    }
}
