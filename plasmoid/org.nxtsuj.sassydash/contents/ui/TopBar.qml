import QtQuick
import QtQuick.Layouts

Rectangle {
    id: bar
    color: Theme.card
    border.color: Theme.border
    radius: Theme.radius

    // Static accent line along the bottom edge.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.18; color: Theme.accent }
            GradientStop { position: 0.46; color: "transparent" }
        }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
        spacing: 16

        Text {
            text: "SASSY·DASH"
            color: Theme.accent
            font { family: Theme.display; pixelSize: 13; weight: Font.Bold; letterSpacing: 3 }
        }
        Row {
            spacing: 6
            Rectangle { width: 7; height: 7; radius: 3.5; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "ONLINE"; color: Theme.text2; font { family: Theme.mono; pixelSize: 10; letterSpacing: 1.5 } }
        }
        Item { Layout.fillWidth: true }
        Text {
            readonly property real c: Stats.temp
            visible: c > 0
            text: "≋ " + Math.round(c) + "°C"
            color: c >= 90 ? Theme.red : c >= 75 ? Theme.orange : Theme.muted
            font { family: Theme.mono; pixelSize: 11 }
        }
        Text {
            text: "load " + Stats.load1.toFixed(2)
            color: Theme.muted
            font { family: Theme.mono; pixelSize: 11 }
        }
        Text {
            text: Stats.host.toUpperCase()
            color: Theme.text2
            font { family: Theme.mono; pixelSize: 12; letterSpacing: 1 }
        }
        Text {
            id: clock
            color: Theme.text
            font { family: Theme.mono; pixelSize: 12 }
            function tick() { text = Qt.formatTime(new Date(), "HH:mm"); }
            Component.onCompleted: tick()
            // Wake once a minute on the minute instead of every second.
            Timer {
                running: true; repeat: true
                interval: 60000 - (Date.now() % 60000) + 50
                onTriggered: { clock.tick(); interval = 60000 - (Date.now() % 60000) + 50; }
            }
        }
    }
}
