import QtQuick
import QtQuick.Layouts

// Flat card with an uppercase mono title; children go into the body below it.
Rectangle {
    id: card
    property string title: ""
    property alias headerExtras: extras.data
    default property alias body: content.data
    property int padding: 11

    color: Theme.card
    border.color: hover.hovered ? Theme.accentDim : Theme.border
    border.width: 1
    radius: Theme.radius
    clip: true

    HoverHandler { id: hover }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 8

        RowLayout {
            visible: card.title !== ""
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: card.title
                color: Theme.text2
                font { family: Theme.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.6; capitalization: Font.AllUppercase }
            }
            Item { Layout.fillWidth: true }
            Row { id: extras; spacing: 10 }
        }

        Item {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
