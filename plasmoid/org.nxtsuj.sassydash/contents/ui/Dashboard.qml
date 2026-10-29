import QtQuick
import QtQuick.Layouts

Rectangle {
    id: dash
    color: Theme.bg
    // Explicit split of the flexible height; Layouts' stretch weights proved unreliable here.
    readonly property real flex: Math.max(0, height - 3 * Theme.gap - 42 - 100 - 170 - 4 * Theme.gap)

    ColumnLayout {
        anchors { fill: parent; margins: Theme.gap }
        spacing: Theme.gap

        TopBar { Layout.fillWidth: true; Layout.preferredHeight: 42 }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            spacing: Theme.gap
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                readonly property real pct: Stats.cpu
                title: "CPU"
                value: Math.round(pct) + "%"
                valueColor: Theme.level(pct, 70, 90)
                spark.values: [pct]
            }
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                readonly property real pct: Stats.ramPct
                title: "RAM"
                value: Math.round(pct) + "%"
                sub: Stats.ramUsedText + " / " + Stats.ramTotalText
                valueColor: Theme.level(pct, 80, 92)
                spark.values: [pct]
                spark.colors: [Theme.green]
            }
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                readonly property real pct: Stats.diskPct
                title: "Speicher"
                value: Math.round(pct) + "%"
                sub: Stats.diskFreeText + " frei"
                valueColor: Theme.level(pct, 85, 95)
                spark.values: [pct]
                spark.every: 10
            }
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                title: "Netzwerk"
                value: "↓ " + Stats.downText
                sub: "↑ " + Stats.upText
                spark.values: [Stats.down]
                spark.maximum: 0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: dash.flex * 0.45
            Layout.minimumHeight: 160
            spacing: Theme.gap
            SystemCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 2 }
            ServicesCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1 }
            ProcsCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1 }
        }

        TerminalCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            Layout.maximumHeight: 170
            spacing: Theme.gap
            NetCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1 }
            NotesCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1 }
        }
    }
}
