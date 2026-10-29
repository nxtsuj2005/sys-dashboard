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
            values: [Stats.cpu, Stats.ramPct]
            colors: [Theme.accent, Theme.green]
        }

        // One thin bar per core; scales to many cores without grouping.
        Row {
            id: bars
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            readonly property int n: Stats.cores
            spacing: n > 16 ? 1 : 3
            Repeater {
                model: bars.n
                delegate: Item {
                    id: core
                    required property int index
                    width: (bars.width - bars.spacing * (bars.n - 1)) / bars.n
                    height: bars.height
                    Sensors.Sensor { id: s; sensorId: "cpu/cpu" + core.index + "/usage" }
                    property real pct
                    Connections {
                        target: Stats
                        function onTick() { core.pct = Math.max(0, Math.min(100, Number(s.value) || 0)); }
                    }
                    Rectangle { anchors.fill: parent; color: Theme.panel; radius: 1 }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: parent.height * core.pct / 100
                        radius: 1
                        color: core.pct >= 90 ? Theme.red : core.pct >= 70 ? Theme.orange : Theme.accent
                    }
                }
            }
        }
    }
}
