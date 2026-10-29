import QtQuick
import QtQuick.Layouts

Card {
    title: "Netzwerk"

    component Stat: Column {
        property string value
        property string dir
        spacing: 3
        Text { text: parent.value; color: Theme.text; font { family: Theme.display; pixelSize: 18; weight: Font.Bold } }
        Text { text: parent.dir; color: Theme.muted; font { family: Theme.mono; pixelSize: 9; letterSpacing: 1 } }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        RowLayout {
            spacing: 24
            Stat { value: Stats.downText; dir: "↓ DOWN" }
            Stat { value: Stats.upText; dir: "↑ UP" }
        }
        Spark {
            Layout.fillWidth: true
            Layout.fillHeight: true
            maximum: 0
            history: 90
            values: [Stats.down, Stats.up]
            colors: [Theme.accent, Theme.green]
        }
    }
}
