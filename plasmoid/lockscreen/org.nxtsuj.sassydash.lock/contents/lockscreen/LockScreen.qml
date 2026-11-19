import QtQuick
import QtQuick.Window
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// SASSY·DASH lock screen (design demo variant A): clock, a `$ unlock` prompt and the
// Proxmox guest tree, redrawn by a CRT beam that tears the slice it is drawing.
// No user name, avatar, notifications or media. The greeter provides `authenticator`.
Item {
    id: root
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()

    // These are magical properties that kscreenlocker looks for
    property bool viewVisible: false

    implicitWidth: 800
    implicitHeight: 600

    readonly property string mono: "DejaVu Sans Mono"
    readonly property color bg: "#0e1116"
    readonly property color accent: "#4f9cf9"
    readonly property color red: "#f85149"
    readonly property color green: "#3fb950"
    readonly property color text: "#e6edf3"
    readonly property color muted: "#91a0b1"
    // Plasma's "reduce animations" (animation speed slider at the far end).
    readonly property bool still: Kirigami.Units.longDuration <= 1
    property bool unlocking: false
    property bool failed: false
    property string pendingPassword    // typed while PAM was still cooling down
    property date now: new Date()

    onClearPassword: entry.text = ""

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind !== 0) return;              // fingerprint/smartcard noise, not the typed PIN
            root.failed = true;
            entry.text = "";
            failTimer.restart();
            shake.restart();
            authenticator.startAuthenticating();
        }
        function onSucceeded() {
            authenticator.stopAuthenticating();
            root.unlocking = true;
            Qt.quit();
        }
        function onErrorMessageChanged() { if (authenticator.errorMessage) console.warn("sassydash-lock:", authenticator.errorMessage); }
        function onPamTimeoutChanged() {
            if (!authenticator.pamTimeout && root.pendingPassword) {
                authenticator.respond(root.pendingPassword);
                root.pendingPassword = "";
            }
        }
    }
    Component.onCompleted: authenticator.startAuthenticating()
    Timer { // heart beat keeping the PAM conversation alive
        interval: 1000; running: !authenticator.unlocked; repeat: true
        onTriggered: authenticator.startAuthenticating()
    }
    Timer { id: failTimer; interval: 1600; onTriggered: root.failed = false }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    Rectangle { anchors.fill: parent; color: root.bg }

    // Everything the beam redraws.
    Item {
        id: scene
        anchors.fill: parent
        readonly property real padX: width * 0.05
        readonly property real padY: height * 0.05
        readonly property real small: Math.max(10, Math.min(14, height * 0.014))

        Text {
            x: scene.padX; y: scene.padY
            text: "SASSY·DASH // gesperrt"
            color: root.muted; font { family: root.mono; pixelSize: scene.small }
        }
        Text {
            anchors { right: parent.right; rightMargin: scene.padX }
            y: scene.padY
            text: Qt.locale("de_DE").toString(root.now, "ddd, dd. MMM").toUpperCase()
            color: root.muted; font { family: root.mono; pixelSize: scene.small }
        }

        Column {
            id: mid
            x: scene.padX + scene.width * 0.08
            anchors.verticalCenter: parent.verticalCenter
            spacing: scene.height * 0.022

            Row {
                Text {
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: root.text
                    font { family: root.mono; pixelSize: Math.max(40, Math.min(170, scene.height * 0.14)); weight: Font.Light }
                }
                Text {
                    text: ":" + Qt.formatTime(root.now, "ss")
                    color: "#3a4554"
                    font { family: root.mono; pixelSize: Math.max(40, Math.min(170, scene.height * 0.14)); weight: Font.Light }
                }
            }
            Row {
                id: prompt
                spacing: promptFont.pixelSize * 0.6
                property font promptFont: Qt.font({ family: root.mono, pixelSize: Math.max(12, Math.min(22, scene.height * 0.022)) })
                Text { text: "$"; color: root.accent; font: prompt.promptFont }
                Text { text: "unlock"; color: "#9aa7b4"; font: prompt.promptFont }
                Text {
                    text: "•".repeat(entry.text.length)
                    color: root.failed ? root.red : root.text
                    font: prompt.promptFont
                    visible: entry.text.length > 0
                }
                Rectangle {
                    id: cursor
                    width: prompt.promptFont.pixelSize * 0.6; height: prompt.promptFont.pixelSize * 1.1
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accent
                    Timer { interval: 500; running: true; repeat: true; onTriggered: cursor.opacity = cursor.opacity > 0 ? 0 : 1 }
                }
                NumberAnimation on x { id: shake; running: false; from: -8; to: 0; duration: 320; easing.type: Easing.OutElastic; easing.amplitude: 3 }
            }
            Text {
                text: root.unlocking ? "ok"
                    : authenticator.errorMessage ? authenticator.errorMessage     // e.g. faillock
                    : root.failed ? "falsch — nochmal"
                    : authenticator.pamTimeout ? "kurz warten …"
                    : authenticator.infoMessage ? authenticator.infoMessage
                    : "PIN eingeben · Enter"
                color: root.unlocking ? root.green : (root.failed || authenticator.errorMessage) ? root.red : root.muted
                font { family: root.mono; pixelSize: Math.max(10, Math.min(16, scene.height * 0.016)) }
            }
        }

        NodeTree {
            id: tree
            width: scene.height * 0.58; height: width
            anchors { right: parent.right; rightMargin: scene.padX; verticalCenter: parent.verticalCenter; verticalCenterOffset: -height * 0.05 }
            font: root.mono
            animate: !root.still
        }

        Text {
            x: scene.padX
            anchors { bottom: parent.bottom; bottomMargin: scene.padY }
            text: "● gesperrt"
            color: root.muted; font { family: root.mono; pixelSize: scene.small }
        }
        Text {
            anchors { right: parent.right; rightMargin: scene.padX; bottom: parent.bottom; bottomMargin: scene.padY }
            text: "Esc löscht"
            color: root.muted; font { family: root.mono; pixelSize: scene.small }
        }
    }

    // CRT beam: one sweep every 7 s. The slice just above it is a live copy of the scene,
    // nudged sideways with a red/blue split; now and then it tears much further.
    Item {
        id: beam
        anchors.fill: parent
        visible: !root.unlocking
        property real y0: 0
        property real dx: 0
        property real band: 18
        property int kick: 0
        property int dir: 1

        FrameAnimation {
            running: beam.visible
            onTriggered: {
                beam.y0 = (Date.now() % 7000) / 7000 * root.height;
                if (root.still) return;
                if (beam.kick <= 0 && Math.random() < 0.035) { beam.kick = 5 + Math.random() * 7; beam.dir = Math.random() < 0.5 ? -1 : 1; }
                const tear = beam.kick > 0 ? beam.dir * (12 + Math.random() * 18) : 0;
                beam.dx = (Math.random() < 0.5 ? -1 : 1) * (3 + Math.random() * 3) + tear;
                beam.band = beam.kick > 0 ? 32 : 18;
                beam.kick--;
                tree.tick();
            }
        }

        ShaderEffectSource {
            id: slice
            sourceItem: scene
            live: true
            hideSource: false
            visible: false
            sourceRect: Qt.rect(0, Math.max(0, beam.y0 - beam.band), root.width, Math.min(beam.band, beam.y0))
        }
        Item {
            visible: !root.still && beam.y0 > 1
            y: Math.max(0, beam.y0 - beam.band)
            width: root.width
            height: Math.min(beam.band, beam.y0)
            Rectangle { anchors.fill: parent; color: root.bg }             // hide the untorn original
            MultiEffect { source: slice; width: parent.width; height: parent.height; x: beam.dx - 3; colorization: 1; colorizationColor: root.red; opacity: 0.7 }
            MultiEffect { source: slice; width: parent.width; height: parent.height; x: beam.dx + 3; colorization: 1; colorizationColor: root.accent; opacity: 0.75 }
            MultiEffect { source: slice; width: parent.width; height: parent.height; x: beam.dx; brightness: 0.25 }
        }

        Rectangle {
            y: beam.y0
            width: root.width; height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.2; color: "#554f9cf9" }
                GradientStop { position: 0.8; color: "#554f9cf9" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // Collects the PIN/password; any characters, the mask only shows the count.
    TextInput {
        id: entry
        width: 0; height: 0; opacity: 0
        focus: true
        echoMode: TextInput.Password
        enabled: !root.unlocking
        Component.onCompleted: { Window.window?.requestActivate(); forceActiveFocus(); }
        onTextChanged: if (text.length) root.failed = false
        Keys.onEscapePressed: text = ""
        onAccepted: {
            if (!text.length) return;
            if (authenticator.pamTimeout) { root.pendingPassword = text; return; }  // sent once PAM cools down
            authenticator.respond(text);
        }
    }
    // With several screens, a click pulls the keyboard to this one.
    MouseArea { anchors.fill: parent; onPressed: { Window.window?.requestActivate(); entry.forceActiveFocus(); } }
}
