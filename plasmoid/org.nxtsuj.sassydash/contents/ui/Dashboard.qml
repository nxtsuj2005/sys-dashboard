import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

// Row/column split of the final Electron #app grid (last CSS override wins):
//   >= 950 px: 46 / 96 / minmax(220,1fr) / 32vh / minmax(230,23vh)
//   <  950 px: 32 / 88 / minmax(190,1fr) / minmax(207,27vh) / minmax(202,26vh)
// Layouts' stretch factors proved unreliable here, so heights are computed.
Rectangle {
    id: dash
    color: Theme.bg
    readonly property bool tall: height >= 950
    readonly property int gap: Theme.gap
    readonly property real headerH: tall ? 46 : 32
    readonly property real kpiH: tall ? 96 : 88
    readonly property real termH: tall ? height * 0.32 : Math.max(207, height * 0.27)
    readonly property real bottomH: tall ? Math.max(230, height * 0.23) : Math.max(202, height * 0.26)
    readonly property real mainH: Math.max(tall ? 220 : 190, height - 2 * gap - 4 * gap - headerH - kpiH - termH - bottomH)

    signal runInTerminal(string command)
    onRunInTerminal: (command) => terminal.run(command)

    ColumnLayout {
        anchors { fill: parent; margins: dash.gap }
        spacing: dash.gap

        TopBar { Layout.fillWidth: true; Layout.preferredHeight: dash.headerH; tall: dash.tall }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: dash.kpiH
            spacing: dash.gap
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                readonly property real pct: Stats.cpu
                title: "CPU"
                value: Math.round(pct) + "%"
                valueColor: Theme.level(pct, 70, 90)
                spark.values: [pct]
                trendValue: pct; back: 4; threshold: 5; hotAt: 80
            }
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                readonly property real pct: Stats.ramPct
                title: "RAM"
                value: Math.round(pct) + "%"
                sub: Stats.ramUsedText + " / " + Stats.ramTotalText
                valueColor: Theme.level(pct, 80, 92)
                spark.values: [pct]
                spark.colors: [Theme.green]
                trendValue: pct; back: 4; threshold: 4; hotAt: 85
            }
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                readonly property real pct: Stats.diskPct
                title: "Speicher"
                value: Math.round(pct) + "%"
                valueColor: Theme.level(pct, 85, 95)
                spark.values: [pct]
                spark.colors: [Theme.orange]
                spark.every: 10
                trendValue: pct; back: 20; threshold: 1
            }
            KpiCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                title: "Netzwerk"
                value: "↓ " + Stats.downText
                sub: "↑ " + Stats.upText
                spark.values: [Stats.down]
                spark.maximum: 0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: dash.mainH
            spacing: dash.gap
            SystemCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 125 }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 110
                spacing: dash.gap
                EventsCard { Layout.fillWidth: true; Layout.fillHeight: true }
                ShortcutsCard {
                    Layout.fillWidth: true; Layout.preferredHeight: 62
                    onRunInTerminal: (command) => dash.runInTerminal(command)
                }
            }
            WeatherCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 65
                location: Plasmoid.configuration.weatherLocation
            }
        }

        TerminalCard {
            id: terminal
            Layout.fillWidth: true
            Layout.preferredHeight: dash.termH
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: dash.bottomH
            spacing: dash.gap
            StorageCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 200 }
            ProcsCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 120 }
            NotesCard { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 80 }
        }
    }

    // Ctrl+K only while the desktop has focus (no global accelerator, by design).
    AppSearch { id: appSearch }
    Shortcut {
        sequences: ["Ctrl+K"]
        context: Qt.WindowShortcut
        onActivated: appSearch.toggle()
    }
}
