import QtQuick
import QtQuick.Shapes

// Boot / welcome screen (Electron #boot): logo, tag, an "OK" feed with real system
// facts, a filling bar and SYSTEM READY. Fx.qml drives it step by step; it only
// exists on screen for those ~3 s, so its small animations may run at display rate.
Rectangle {
    id: boot
    visible: false
    color: Theme.bg

    readonly property FxState fx: FxState { h: inner.height }
    property bool logoOn: false
    property bool tagOn: false
    property bool barOn: false
    property bool readyOn: false
    property real barFill: 0
    property var lines: []           // [[key, value], ...]
    property int shown: 0            // feed lines visible
    property int burstStep: -1       // -1 off, 0..3 the band widening to the right edge

    // Feed facts: kernel, uptime, battery present. Delivered at once, not on a tick.
    property var facts: null
    readonly property Command probe: Command {
        immediate: true
        command: "sh -c 'uname -r; cut -d\" \" -f1 /proc/uptime; for b in /sys/class/power_supply/BAT*; do [ -e \"$b\" ] && echo battery && break; done'"
        onFinished: (out) => {
            const l = out.split("\n");
            boot.facts = { kernel: l[0] || "", uptime: parseFloat(l[1]) || 0, battery: l[2] === "battery" };
        }
    }

    function reset() {
        logoOn = tagOn = barOn = readyOn = false;
        barFill = 0; lines = []; shown = 0; burstStep = -1;
        fx.reset();
    }

    Shape {   // radial-gradient(ellipse at 50% 40%, #14171f 0%, bg 60%)
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: boot.width / 2; centerY: boot.height * 0.4
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(boot.width, boot.height) * 0.6
                GradientStop { position: 0; color: "#14171f" }
                GradientStop { position: 1; color: Theme.bg }
            }
            PathRectangle { width: boot.width; height: boot.height }
        }
    }

    Column {
        id: inner
        anchors.centerIn: parent
        width: Math.min(400, boot.width * 0.74)
        spacing: 16
        transform: [boot.fx.shear, boot.fx.shift]
        opacity: boot.fx.opacity

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.StyledText
            text: "SASSY<font color=\"" + Theme.accent + "\">·</font>DASH"
            color: Theme.text
            font { family: Theme.display; pixelSize: Math.max(30, Math.min(48, boot.width * 0.06)); bold: true; letterSpacing: boot.logoOn ? 7 : 2 }
            opacity: boot.logoOn ? 1 : 0
            transform: Translate { y: boot.logoOn ? 0 : 6; Behavior on y { NumberAnimation { duration: 400 } } }
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Behavior on font.letterSpacing { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SYSTEM MONITOR"
            color: Theme.muted
            font { family: Theme.sans; pixelSize: 10; weight: Font.Medium; letterSpacing: 5 }
            opacity: boot.tagOn ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        Column {
            width: parent.width
            height: 128
            topPadding: 6
            spacing: 4
            Repeater {
                model: boot.lines
                Row {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property bool on: index < boot.shown
                    spacing: 10
                    opacity: on ? 1 : 0
                    transform: Translate { y: line.on ? 0 : 3; Behavior on y { NumberAnimation { duration: 250 } } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    Text { text: "OK"; color: Theme.green; font { family: Theme.mono; pixelSize: 11; letterSpacing: 1 } }
                    Text { width: 92; text: line.modelData[0]; color: Theme.muted; font { family: Theme.mono; pixelSize: 11 } }
                    Text { text: line.modelData[1]; color: Theme.text2; font { family: Theme.mono; pixelSize: 11 } }
                }
            }
        }
        Rectangle {
            id: track
            width: parent.width
            height: 4
            radius: 2
            color: Theme.panel
            opacity: boot.barOn ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Rectangle {
                height: parent.height
                width: parent.width * boot.barFill
                radius: 2
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.green }
                }
                Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                Row {   // diagonal energy hatch, flowing while the bar is up
                    id: hatch
                    spacing: 6
                    NumberAnimation on x { from: -22; to: 0; duration: 1100; loops: Animation.Infinite; running: boot.visible && boot.barOn }
                    Repeater {
                        model: Math.ceil(track.width / 8) + 4
                        Rectangle { width: 2; height: 8; y: -2; rotation: 45; color: Qt.rgba(1, 1, 1, 0.16) }
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SYSTEM READY"
            color: Theme.green
            font { family: Theme.mono; pixelSize: 12; bold: true; letterSpacing: 6 }
            opacity: boot.readyOn ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
    }

    Rectangle {   // the bar punches out of its track towards the right edge
        readonly property point at: { boot.burstStep; return track.mapToItem(boot, 0, 0); }   // re-read when it fires
        visible: boot.burstStep >= 0
        x: at.x
        y: at.y
        height: track.height
        width: track.width + (boot.width - at.x - track.width) * Math.max(0, boot.burstStep) / 3
        color: Theme.text2
    }

    MouseArea { anchors.fill: parent }   // the dashboard under it is not usable yet
}
