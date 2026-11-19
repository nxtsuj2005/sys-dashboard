import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_view
    property string cfg_viewDefault
    property alias cfg_weatherLocation: weatherField.text
    property string cfg_weatherLocationDefault
    property alias cfg_glideFps: fpsSpin.value
    property int cfg_glideFpsDefault
    property alias cfg_glideFpsBattery: fpsBatterySpin.value
    property int cfg_glideFpsBatteryDefault
    property alias cfg_reducedMotion: reducedBox.checked
    property bool cfg_reducedMotionDefault
    property alias cfg_shell: shellField.text
    property string cfg_shellDefault
    property string cfg_fxDebug
    property string cfg_fxDebugDefault
    // Unused by this page, declared so the config system does not warn.
    property string cfg_notes
    property string cfg_notesDefault

    // Same allowed characters and length limit as WeatherCard.requestCommand.
    readonly property bool weatherValid: weatherField.text.length <= 64
        && !/[^A-Za-zÀ-ÖØ-öø-ÿĀ-ɏ0-9 .,'()-]/.test(weatherField.text)

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: viewBox
            Kirigami.FormData.label: "Ansicht:"
            textRole: "text"
            valueRole: "value"
            model: [
                { text: "Automatisch (Hauptbildschirm voll, weitere Monitor)", value: "auto" },
                { text: "Dashboard", value: "main" },
                { text: "Monitor (Graphen)", value: "monitor" }
            ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_view))
            onActivated: page.cfg_view = currentValue
        }

        QQC2.TextField {
            id: weatherField
            Kirigami.FormData.label: "Wetter-Ort:"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            maximumLength: 64
            placeholderText: "leer = automatisch per IP"
        }
        QQC2.Label {
            visible: !page.weatherValid
            text: "Ungültiger Ort (erlaubt: Buchstaben, Ziffern, Leerzeichen und . , ' ( ) -)."
            color: Kirigami.Theme.negativeTextColor
            font: Kirigami.Theme.smallFont
        }

        QQC2.SpinBox {
            id: fpsSpin
            Kirigami.FormData.label: "Animations-FPS:"
            from: 0
            to: 60
            stepSize: 5
            editable: true
        }
        QQC2.Label {
            text: "0 = sparsam (kein Gleiten). Gilt für alle Bildschirme."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        QQC2.SpinBox {
            id: fpsBatterySpin
            Kirigami.FormData.label: "FPS auf Akku:"
            from: -1
            to: 60
            stepSize: 1
            editable: true
            textFromValue: (value) => value < 0 ? "wie oben" : String(value)
            valueFromText: (text) => text === "wie oben" ? -1 : parseInt(text, 10)
        }

        QQC2.CheckBox {
            id: reducedBox
            Kirigami.FormData.label: "Effekte:"
            text: "Reduzierte Bewegung (kein Boot, Glitches, Crash)"
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: shellField
            Kirigami.FormData.label: "Shell:"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            placeholderText: "leer = fish → $SHELL → bash"
        }
        QQC2.Label {
            text: "Gilt nach Neustart von plasmashell."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Debug"
        }

        QQC2.ComboBox {
            id: fxBox
            Kirigami.FormData.label: "Effekt-Vorschau:"
            textRole: "text"
            valueRole: "value"
            model: [
                { text: "aus", value: "" },
                { text: "glitch (alle ~25 s)", value: "glitch" },
                { text: "crash (20 s nach Boot)", value: "crash" }
            ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_fxDebug))
            onActivated: page.cfg_fxDebug = currentValue
        }
    }
}
