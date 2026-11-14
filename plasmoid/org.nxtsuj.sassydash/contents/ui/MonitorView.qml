import QtQuick
import QtQuick.Layouts

// Graph wall for a second screen: nothing but live sensors, no terminal, no
// child processes besides the process list.
Item {
    id: view
    readonly property bool tall: height >= 950
    readonly property int gap: Theme.gap
    readonly property real headerH: tall ? 46 : 32
    // Heights are computed, as in MainView.
    readonly property real lowerH: Math.round((height - headerH - 4 * gap) * 0.42)
    readonly property real upperH: height - headerH - 4 * gap - lowerH

    // What Fx.qml animates.
    readonly property Item bar: topBar
    readonly property Item term: null
    readonly property var groups: [[systemCard, netCard, diskCard], [gpuCard, tempCard, procsCard]]

    ColumnLayout {
        anchors { fill: parent; margins: view.gap }
        spacing: view.gap

        TopBar { id: topBar; Layout.fillWidth: true; Layout.preferredHeight: view.headerH; tall: view.tall }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: view.upperH
            spacing: view.gap
            SystemCard {
                id: systemCard
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 3
                maxBars: 12
                barColumns: 6
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 2
                spacing: view.gap
                GraphCard {
                    id: netCard
                    Layout.fillWidth: true; Layout.preferredHeight: (view.upperH - view.gap) / 2
                    title: "Netzwerk"
                    sensorIds: ["network/all/download", "network/all/upload"]
                    labels: ["↓", "↑"]
                    maximum: 0
                }
                GraphCard {
                    id: diskCard
                    Layout.fillWidth: true; Layout.preferredHeight: (view.upperH - view.gap) / 2
                    title: "Datenträger-I/O"
                    sensorIds: ["disk/all/read", "disk/all/write"]
                    labels: ["R", "W"]
                    colors: [Theme.green, Theme.orange]
                    maximum: 0
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: view.lowerH
            spacing: view.gap
            GraphCard {
                id: gpuCard
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                title: "GPU"
                sensorIds: ["gpu/all/usage", "gpu/all/usedPercent"]
                labels: ["Last", "VRAM"]
                colors: [Theme.accent, "#c1b5da"]
            }
            GraphCard {
                id: tempCard
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                title: "Temperatur"
                sensorIds: ["cpu/all/averageTemperature", "gpu/gpu0/temperature"]
                labels: ["CPU", "GPU"]
                colors: [Theme.orange, Theme.red]
            }
            ProcsCard { id: procsCard; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; rows: Math.max(5, Math.min(12, Math.floor((view.lowerH - 40) / 26))) }
        }
    }
}
