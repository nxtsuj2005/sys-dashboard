import QtQuick
import QtQuick.Layouts

Card {
    id: kpi
    property string value: "—"
    property string sub: ""
    property color valueColor: Theme.text
    property alias spark: spark

    padding: 10

    ColumnLayout {
        anchors.fill: parent
        spacing: 3
        Text {
            text: kpi.value
            color: kpi.valueColor
            font { family: Theme.display; pixelSize: 26; weight: Font.Bold; letterSpacing: 0.5 }
            Behavior on color { ColorAnimation { duration: 350 } }
        }
        Text {
            visible: kpi.sub !== ""
            text: kpi.sub
            color: Theme.muted
            font { family: Theme.mono; pixelSize: 10 }
        }
        Spark {
            id: spark
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 16
        }
    }
}
