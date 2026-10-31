import QtQuick
import QMLTermWidget

// Loaded through a Loader in TerminalCard: if the qmltermwidget module is
// missing only this file fails, not the whole plasmoid.
QMLTermWidget {
    id: term
    property string shell
    property var shellArgs: []
    property string home
    signal shellFinished()

    // SassyDash ships via COLORSCHEMES_DIR (see install.sh); built-in fallback otherwise.
    colorScheme: availableColorSchemes.indexOf("SassyDash") !== -1 ? "SassyDash" : "BreezeModified"
    font { family: Theme.mono; pointSize: 10 }
    blinkingCursor: false
    session: QMLTermSession {
        id: session
        shellProgram: term.shell
        shellProgramArgs: term.shellArgs
        initialWorkingDirectory: term.home
        onFinished: term.shellFinished()
    }

    function send(text) { session.sendText(text); }
    function clear() { session.clearScreen(); }
    function focusTerm() { term.forceActiveFocus(); }

    TapHandler { onTapped: term.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+Shift+C"; enabled: term.activeFocus; onActivated: term.copyClipboard() }
    Shortcut { sequence: "Ctrl+Shift+V"; enabled: term.activeFocus; onActivated: term.pasteClipboard() }

    QMLTermScrollbar {
        terminal: term
        width: 6
        Rectangle { anchors.fill: parent; radius: 3; color: Theme.border; opacity: 0.8 }
    }

    Component.onCompleted: session.startShellProgram()
}
