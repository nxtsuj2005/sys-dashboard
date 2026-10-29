import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid

Card {
    title: "Notiz"

    QQC2.ScrollView {
        anchors.fill: parent
        QQC2.TextArea {
            id: area
            text: Plasmoid.configuration.notes
            placeholderText: "Tippe einfach los…"
            placeholderTextColor: Theme.muted
            color: Theme.text
            selectionColor: "#294667"
            selectedTextColor: "#e1eeff"
            wrapMode: TextEdit.Wrap
            font { family: Theme.mono; pixelSize: 11 }
            background: null
            onTextChanged: save.restart()
        }
    }
    // Debounced: Plasma writes the applet config to disk on every change.
    Timer {
        id: save
        interval: 800
        onTriggered: if (Plasmoid.configuration.notes !== area.text) Plasmoid.configuration.notes = area.text
    }
}
