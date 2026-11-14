import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors

// One rolling graph of up to two ksystemstats sensors; the legend carries the
// current values. Read on the Stats tick like everything else.
Card {
    id: card
    property var sensorIds: []
    property var labels: []
    property var colors: [Theme.accent, Theme.green]
    property real maximum: 100               // <= 0 → automatic range
    property int history: 120
    property var vals: sensorIds.map(() => 0)
    property var texts: sensorIds.map(() => "—")

    Instantiator {
        id: sensors
        model: card.sensorIds
        delegate: Sensors.Sensor { required property string modelData; sensorId: modelData }
    }
    Connections {
        target: Stats
        function onTick() {
            const v = [], t = [];
            for (let i = 0; i < sensors.count; i++) {
                const s = sensors.objectAt(i);
                v.push(Stats.num(s));
                t.push(Stats.fmt(s));
            }
            card.vals = v;
            card.texts = t;
        }
    }

    headerExtras: Repeater {
        model: card.sensorIds.length
        Row {
            id: legend
            required property int index
            spacing: 5
            Rectangle { width: 7; height: 2; color: card.colors[legend.index]; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: (card.labels[legend.index] ?? "") + " " + card.texts[legend.index]
                color: Theme.muted
                font { family: Theme.mono; pixelSize: 9; letterSpacing: 1 }
            }
        }
    }

    Spark {
        anchors.fill: parent
        history: card.history
        grid: true
        maximum: card.maximum
        values: card.vals
        colors: card.colors
    }
}
