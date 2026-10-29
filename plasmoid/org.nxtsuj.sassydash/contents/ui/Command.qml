import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Runs a shell command via Plasma's executable engine. every > 0 → repeats.
P5Support.DataSource {
    id: src
    property string command: ""
    property int every: 0
    signal finished(string stdout, int exitCode)

    engine: "executable"
    interval: every
    connectedSources: every > 0 && command !== "" ? [command] : []

    onNewData: (source, data) => {
        const code = data["exit code"] ?? -1;
        if (code !== 0 && data["stderr"]) console.warn("sassydash:", source, "→", code, data["stderr"]);
        finished(data["stdout"] ?? "", code);
        if (every <= 0) disconnectSource(source);
    }
    function run() { if (command !== "") connectSource(command); }
}
