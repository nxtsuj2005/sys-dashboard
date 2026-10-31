import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore
import org.kde.plasma.plasmoid

Rectangle {
    id: card
    color: Theme.termBg
    border.color: "#507aae"
    radius: Theme.radius
    clip: true
    readonly property FxState fx: FxState { h: card.height }
    transform: [fx.shear, fx.shift]
    opacity: fx.opacity
    enabled: !fx.hidden            // a hidden tile takes no clicks or keys
    FxCut { fx: card.fx }

    property string shell: ""
    property int quickExits: 0
    property double startedAt: 0
    readonly property string home: decodeURIComponent(
        StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, ""))

    // fish: short "❯ " prompt + dim cwd, only for this terminal (-C runs after config.fish).
    function initArgs(sh) {
        if (!/\/fish$/.test(sh)) return [];
        return ["-C", "function fish_prompt; set_color 8abafe; echo -n '❯ '; set_color normal; end; "
                    + "function fish_right_prompt; set_color 6f87a1; echo -n (prompt_pwd); set_color normal; end"];
    }

    property bool stopped: false
    // Lines typed in the input bar, newest last (Electron keeps 100).
    property var history: []
    property int histPos: -1

    // Entry point for other cards (shortcut htop, event → systemctl status).
    function run(command) {
        if (!loader.item || !command) return;
        loader.item.send(command + "\r");
        loader.item.focusTerm();
    }
    // Initial properties so the shell is known before Terminal.qml starts it.
    function restart() {
        loader.source = "";
        if (!shell) return;
        stopped = false;
        loader.setSource("Terminal.qml", { shell: shell, shellArgs: initArgs(shell), home: home });
    }
    onShellChanged: restart()

    Command {
        id: detect
        command: "sh -c 'for s in fish \"$SHELL\" bash sh; do p=$(command -v \"$s\" 2>/dev/null) && [ -n \"$p\" ] && { echo \"$p\"; exit 0; }; done'"
        onFinished: (out) => { card.shell = out.trim() || "/bin/sh"; }
        Component.onCompleted: {
            if (Plasmoid.configuration.shell) card.shell = Plasmoid.configuration.shell;
            else run();
        }
    }

    // Backoff restart; stop after 5 exits within 2 s of starting (broken shell).
    Timer {
        id: respawn
        onTriggered: card.restart()
    }

    Rectangle {   // accent top edge
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 2
        color: "#75aaf0"
    }

    ColumnLayout {
        anchors { fill: parent; topMargin: 2 }
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 31
            color: "#151f2c"
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
                spacing: 8
                Text {
                    text: card.shell ? card.shell.split("/").pop() + " — " + card.shell + " (nativ)" : "Terminal"
                    color: "#a9cfff"
                    font { family: Theme.mono; pixelSize: 11 }
                }
                Text {
                    text: "Ctrl K · Apps"
                    color: "#8eabc9"
                    font { family: Theme.mono; pixelSize: 9 }
                }
                component Act: Text {
                    signal clicked()
                    color: area.containsMouse ? "#e1eeff" : "#b1c5de"
                    font { family: Theme.mono; pixelSize: 10 }
                    MouseArea { id: area; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: parent.clicked() }
                }
                Act { text: "Leeren"; onClicked: if (loader.item) loader.item.clear() }
                Act { text: "Neu"; onClicked: { card.quickExits = 0; card.restart(); } }
                Item { Layout.fillWidth: true }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: "#2b3b4f" }
        }

        Loader {
            id: loader
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 6
            onLoaded: {
                card.startedAt = Date.now();
                item.shellFinished.connect(() => {
                    card.quickExits = Date.now() - card.startedAt < 2000 ? card.quickExits + 1 : 0;
                    if (card.quickExits >= 5) {
                        console.warn("sassydash: shell keeps exiting:", card.shell);
                        loader.source = "";
                        card.stopped = true;
                        return;
                    }
                    respawn.interval = Math.min(30000, 800 * Math.pow(2, card.quickExits));
                    respawn.restart();
                });
            }
            onStatusChanged: if (status === Loader.Error) console.warn("sassydash: QMLTermWidget (Qt6) not available — rerun plasmoid/install.sh")
        }
        Text {
            visible: loader.status === Loader.Error || card.stopped
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            color: Theme.muted
            font { family: Theme.mono; pixelSize: 11 }
            text: loader.status === Loader.Error
                ? "Terminal-Modul fehlt (QMLTermWidget für Qt6) — ./plasmoid/install.sh erneut ausführen, danach neu einloggen"
                : "Shell " + card.shell + " beendet sich sofort wieder — „Neu“ zum erneuten Versuch"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            Layout.margins: 10
            Layout.topMargin: 4
            color: "#142133"
            border.color: input.activeFocus ? "#8abafe" : "#3a5679"
            radius: 4
            RowLayout {
                anchors { fill: parent; leftMargin: 9; rightMargin: 5 }
                spacing: 12
                Text { text: "❯"; color: "#8abafe"; font { family: Theme.mono; pixelSize: 12; bold: true } }
                QQC2.TextField {
                    id: input
                    Layout.fillWidth: true
                    placeholderText: "Befehl an das Terminal senden …"
                    placeholderTextColor: "#6f87a1"
                    color: "#e1eeff"
                    font { family: Theme.mono; pixelSize: 11 }
                    background: null
                    onAccepted: send()
                    Keys.onUpPressed: browse(-1)
                    Keys.onDownPressed: browse(1)
                    function browse(step) {
                        const h = card.history;
                        if (!h.length) return;
                        let p = card.histPos < 0 ? h.length : card.histPos;
                        p = Math.max(0, Math.min(h.length, p + step));
                        card.histPos = p === h.length ? -1 : p;
                        text = p === h.length ? "" : h[p];
                    }
                    function send() {
                        if (!loader.item) return;
                        const line = text.replace(/[\r\n]+/g, " ");
                        loader.item.send(line + "\r");
                        if (line.trim() && card.history[card.history.length - 1] !== line)
                            card.history = card.history.concat([line]).slice(-100);
                        card.histPos = -1;
                        text = "";
                    }
                }
                Rectangle {
                    implicitWidth: enterLabel.implicitWidth + 20
                    implicitHeight: 22
                    radius: 3
                    color: enterArea.containsMouse ? "#35587f" : "#294667"
                    Text { id: enterLabel; anchors.centerIn: parent; text: "Enter ↵"; color: "#d8eaff"; font { family: Theme.mono; pixelSize: 10 } }
                    MouseArea { id: enterArea; anchors.fill: parent; hoverEnabled: true; onClicked: input.send() }
                }
            }
        }
    }
}
