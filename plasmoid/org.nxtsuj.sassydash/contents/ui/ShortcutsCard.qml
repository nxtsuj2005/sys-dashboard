pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes

Card {
    id: card
    // The compact Electron header has its own 9 px font and 5 px body gap.
    title: ""
    padding: 0
    implicitHeight: 62
    signal runInTerminal(string command)

    readonly property var candidates: ({
        chromium: [["chromium"], ["chromium-browser"], ["chromium-freeworld"],
                   ["flatpak", "run", "org.chromium.Chromium"], ["google-chrome-stable"], ["google-chrome"]],
        // Without Electron's shell profile, xterm uses the user's default shell.
        terminal: [["konsole"], ["alacritty"], ["kitty"], ["wezterm"], ["gnome-terminal"], ["xterm"]],
        settings: [["systemsettings"], ["systemsettings5"], ["kcmshell6"], ["kcmshell5"]],
        dolphin: [["dolphin"], ["pcmanfm-qt"], ["nautilus"], ["xdg-open"]],
        discord: [["discord"], ["Discord"], ["vesktop"], ["flatpak", "run", "com.discordapp.Discord"]]
    })

    function launchCommand(key: string): string {
        if (!Object.prototype.hasOwnProperty.call(candidates, key)) {
            console.warn("sassydash: unknown shortcut key:", key);
            return "";
        }
        let script = "command -v setsid >/dev/null 2>&1 || { printf 'setsid fehlt\\n'; exit 127; }; ";
        for (const candidate of candidates[key]) {
            // Only fixed whitelist tokens are interpolated, never a caller's command.
            const args = candidate.map(token => "'" + token + "'").join(" ")
                       + (candidate[0] === "xdg-open" ? ' "$HOME"' : "");
            script += "if command -v '" + candidate[0] + "' >/dev/null 2>&1; then "
                    + "setsid -f -- " + args + " </dev/null >/dev/null 2>&1; exit \"$?\"; fi; ";
        }
        return script + "printf 'Kein passendes Programm gefunden\\n'; exit 127";
    }

    function launch(key: string): void {
        if (key === "htop") {
            runInTerminal("htop");
            return;
        }
        const script = launchCommand(key);
        if (!script) return;
        if (launcher.pending) {
            console.warn("sassydash: shortcut launcher is still busy");
            return;
        }
        launcher.command = script;
        launcher.run();
    }

    Command {
        id: launcher
        onFinished: (stdout, exitCode) => {
            if (exitCode !== 0) console.warn("sassydash: shortcut launch failed, exit", exitCode, stdout.trim());
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors { leftMargin: 10; rightMargin: 10; topMargin: 6; bottomMargin: 6 }
        spacing: 5

        Text {
            text: "SHORTCUTS"
            color: Theme.text2
            font { family: Theme.mono; pixelSize: 9; weight: Font.DemiBold; letterSpacing: 1 }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 7

            Repeater {
                // SVG rects and the Chromium circle are expressed as equivalent paths.
                model: [
                    { key: "chromium", label: "Chromium", ink: "#91bffd",
                      fill: "M12 3 20.5 7.5v9L12 21 3.5 16.5v-9z",
                      lines: "M15 12a3 3 0 1 0-6 0a3 3 0 1 0 6 0M12 3v6M20.5 16.5 15 13.5M3.5 16.5 9 13.5" },
                    { key: "terminal", label: "Terminal", ink: "#95c9b5",
                      fill: "M3 4.5h18v15H3z", lines: "M7 9.5 10.5 12 7 14.5M13 15h4.5" },
                    { key: "settings", label: "Einstellungen", ink: "#b3c2d6",
                      fill: "M13 5.5h4v5h-4zM7 13.5h4v5H7z", lines: "M4 8h9M17 8h3M4 16h3M11 16h9" },
                    { key: "dolphin", label: "Dolphin", ink: "#7fb0e8",
                      fill: "M3.5 6.5h6l2 2.5h9v9.5h-17z", lines: "M3.5 11.5h17" },
                    { key: "discord", label: "Discord", ink: "#a9b8f2",
                      fill: "M4 6h16v10h-7l-4 3.5V16H4z", lines: "M8.5 10.5v1.5M15.5 10.5v1.5" },
                    { key: "htop", label: "htop", ink: "#95c9b5",
                      fill: "M5 12h3.2v8H5zM10.4 7h3.2v13h-3.2zM15.8 4H19v16h-3.2z", lines: "M3.5 20.5h17" }
                ]
                delegate: QQC2.Button {
                    id: shortcut
                    required property var modelData
                    readonly property color ink: modelData.ink
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: 31
                    implicitWidth: 0
                    padding: 4
                    Accessible.name: modelData.label
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: 600
                    QQC2.ToolTip.text: modelData.label + " starten"
                    onClicked: card.launch(modelData.key)

                    background: Rectangle {
                        radius: 3
                        color: shortcut.hovered ? Theme.tileHover : Theme.panel
                        border.color: shortcut.activeFocus ? "#91c3ff" : shortcut.hovered ? Theme.accentDim : Theme.tileBorder
                    }
                    contentItem: Item {
                        Item {
                            anchors.centerIn: parent
                            width: 23
                            height: 23
                            Shape {
                                width: 24
                                height: 24
                                transform: Scale { xScale: 23 / 24; yScale: 23 / 24 }
                                ShapePath {
                                    strokeColor: shortcut.ink
                                    strokeWidth: 1.6
                                    capStyle: ShapePath.SquareCap
                                    joinStyle: ShapePath.MiterJoin
                                    fillColor: Qt.rgba(shortcut.ink.r, shortcut.ink.g, shortcut.ink.b, 0.22)
                                    PathSvg { path: shortcut.modelData.fill }
                                }
                                ShapePath {
                                    strokeColor: shortcut.ink
                                    strokeWidth: 1.6
                                    capStyle: ShapePath.SquareCap
                                    joinStyle: ShapePath.MiterJoin
                                    fillColor: "transparent"
                                    PathSvg { path: shortcut.modelData.lines }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
