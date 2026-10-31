pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

Card {
    id: card
    title: "System · Änderungen & Fehler"

    property string filter: "all"
    property var events: []
    property var previous: null
    property var userFailed: []
    property var systemFailed: []
    readonly property bool spacious: Screen.height >= 950
    readonly property var visibleEvents: events.filter(event => filter === "all" || event.kind === filter)

    function parseUnits(output: string): var {
        const units = [];
        for (const line of output.split("\n")) {
            const fields = line.trim().split(/\s+/);
            if (!fields[0]) continue;
            // --plain removes the failure bullet; the first four columns are fixed.
            if (fields.length < 4 || fields[2] !== "failed"
                    || !/^(?:[A-Za-z0-9_:@.-]|\\x[0-9a-fA-F]{2})+\.(?:service|socket|device|mount|automount|swap|target|path|timer|slice|scope)$/.test(fields[0])) {
                console.warn("sassydash: unexpected failed-unit row:", line);
                continue;
            }
            units.push({ name: fields[0], desc: fields.slice(4).join(" ") });
        }
        return units;
    }

    function updateEvents(): void {
        // Electron prefers the user unit when both managers report the same name.
        const current = new Map();
        for (const unit of userFailed.concat(systemFailed)) {
            if (!current.has(unit.name)) current.set(unit.name, unit.desc);
        }
        const time = Qt.formatTime(new Date(), "HH:mm");
        const next = events.slice();
        if (previous !== null) {
            current.forEach((desc, name) => {
                if (!previous.has(name)) next.unshift({ time, name, desc, kind: "failed", label: "fehlgeschlagen" });
            });
            previous.forEach((desc, name) => {
                if (!current.has(name)) next.unshift({ time, name, desc, kind: "new", label: "wieder aktiv" });
            });
        } else {
            current.forEach((desc, name) => next.push({ time, name, desc, kind: "failed", label: "fehlgeschlagen" }));
        }
        previous = current;
        events = next.slice(0, 50);
    }

    function acceptPoll(output: string, exitCode: int): void {
        const match = /^@sassydash-user\n([\s\S]*?)^@sassydash-user-exit:(\d+)\n@sassydash-system\n([\s\S]*?)^@sassydash-system-exit:(\d+)\n?$/m.exec(output);
        if (!match) {
            console.warn("sassydash: invalid events polling response, exit", exitCode);
            return;
        }
        const userOk = Number(match[2]) === 0;
        const systemOk = Number(match[4]) === 0;
        if (!userOk) console.warn("sassydash: user failed-unit polling exited", match[2]);
        if (!systemOk) console.warn("sassydash: system failed-unit polling exited", match[4]);
        // Preserve a failed manager's last snapshot instead of reporting recoveries.
        if (userOk) userFailed = parseUnits(match[1]);
        if (systemOk) systemFailed = parseUnits(match[3]);
        if (userOk || systemOk) updateEvents();
    }

    Command {
        every: 10000
        // This source is deliberately distinct from ServicesCard's executable source.
        command: "LC_ALL=C sh -c 'printf \"@sassydash-user\\n\"; "
               + "systemctl --user list-units --state=failed --no-legend --no-pager --plain; user_rc=$?; "
               + "printf \"@sassydash-user-exit:%s\\n@sassydash-system\\n\" \"$user_rc\"; "
               + "systemctl list-units --state=failed --no-legend --no-pager --plain; system_rc=$?; "
               + "printf \"@sassydash-system-exit:%s\\n\" \"$system_rc\"; "
               + "[ \"$user_rc\" -eq 0 ] && [ \"$system_rc\" -eq 0 ]'"
        onFinished: (stdout, exitCode) => card.acceptPoll(stdout, exitCode)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Seit Dashboard-Start"
                elide: Text.ElideRight
                color: Theme.labelBlue
                font { family: Theme.mono; pixelSize: card.spacious ? 10 : 9 }
            }
            Repeater {
                model: [ { key: "all", label: "Alle" }, { key: "new", label: "Neu" }, { key: "failed", label: "Fehler" } ]
                delegate: QQC2.Button {
                    id: filterButton
                    required property var modelData
                    text: modelData.label
                    checkable: true
                    autoExclusive: true
                    checked: card.filter === modelData.key
                    padding: 3
                    leftPadding: 6
                    rightPadding: 6
                    implicitWidth: implicitContentWidth + leftPadding + rightPadding + 2
                    implicitHeight: implicitContentHeight + topPadding + bottomPadding + 2
                    onClicked: card.filter = modelData.key
                    background: Rectangle {
                        radius: 3
                        color: filterButton.checked ? "#253e5c" : "#172331"
                        border.color: filterButton.activeFocus ? "#91c3ff" : filterButton.checked ? "#567ca6" : "#35465b"
                    }
                    contentItem: Text {
                        text: filterButton.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: filterButton.checked ? "#b5d7ff" : "#97acc4"
                        font { family: Theme.mono; pixelSize: card.spacious ? 10 : 9 }
                    }
                }
            }
        }

        ListView {
            id: eventList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: card.visibleEvents
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: QQC2.ScrollBar { }

            delegate: Rectangle {
                id: eventRow
                required property var modelData
                width: eventList.width
                height: card.spacious ? 38 : 19
                radius: 2
                color: eventHover.hovered ? Theme.tileHover : Theme.tile

                HoverHandler { id: eventHover }
                QQC2.ToolTip.visible: eventHover.hovered && modelData.desc !== ""
                QQC2.ToolTip.delay: 600
                QQC2.ToolTip.text: modelData.desc

                Rectangle {
                    width: 2
                    height: parent.height
                    color: eventRow.modelData.kind === "failed" ? "#e58f8a" : "#8ac7af"
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: card.spacious ? 12 : 10
                    anchors.rightMargin: card.spacious ? 10 : 8
                    spacing: 7

                    Text {
                        Layout.preferredWidth: 40
                        text: eventRow.modelData.time
                        color: "#91a4bb"
                        font { family: Theme.mono; pixelSize: 9 }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: eventRow.modelData.name
                        elide: Text.ElideRight
                        color: "#b8c9dc"
                        font { family: Theme.mono; pixelSize: card.spacious ? 12 : 10 }
                    }
                    Text {
                        text: eventRow.modelData.label.toUpperCase()
                        color: eventRow.modelData.kind === "failed" ? "#f0a5a0" : "#8ac7af"
                        font { family: Theme.mono; pixelSize: card.spacious ? 10 : 8 }
                    }
                }
            }

            Text {
                anchors { top: parent.top; topMargin: 12; left: parent.left; right: parent.right }
                visible: card.visibleEvents.length === 0
                text: "Keine Ereignisse seit Start"
                color: "#98adc5"
                font { family: Theme.mono; pixelSize: 11 }
            }
        }
    }
}
