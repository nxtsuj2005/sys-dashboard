import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Card {
    id: card

    // Empty uses the public IP's location; the parent can bind a configured place.
    property string location: ""
    property var current: null
    property string city: ""
    property string status: "Lade…"
    property bool ready: false
    property bool busy: false
    property string requestedLocation: ""
    property int retryDelay: 60000
    readonly property int refreshInterval: 15 * 60 * 1000

    title: city ? "Wetter — " + city : "Wetter"
    implicitWidth: 300
    implicitHeight: 210

    function requestCommand(place: string): string {
        // Validate before trimming so control characters cannot become valid input.
        if (place.length > 64 || /[^A-Za-zÀ-ÖØ-öø-ÿ\u0100-\u024f0-9 .,'()-]/.test(place))
            throw new Error("Ungültiger Ort (max. 64 Zeichen).")
        const trimmed = place.trim()
        if (trimmed && !/[A-Za-zÀ-ÖØ-öø-ÿ\u0100-\u024f0-9]/.test(trimmed))
            throw new Error("Ungültiger Ort.")
        // Encode apostrophes too: this URL is passed through a shell, not execFile.
        const encoded = encodeURIComponent(trimmed).replace(/[!'()*]/g, function(character) {
            return "%" + character.charCodeAt(0).toString(16).toUpperCase()
        })
        return "curl -sS --fail --proto '=https' --connect-timeout 3 --max-time 5 "
                + "--max-filesize 1048576 --header 'Accept-Language: de' -- 'https://wttr.in/"
                + encoded + "?format=j1'"
    }

    function weatherIcon(code: string): string {
        const c = parseInt(code, 10)
        if (!Number.isFinite(c)) return "unknown"
        if (c === 113) return "sun"
        if (c === 116) return "partly"
        if (c === 119 || c === 122) return "cloud"
        if (c === 143 || c === 248 || c === 260) return "fog"
        if (c === 200 || (c >= 386 && c <= 395)) return "thunder"
        if ((c >= 179 && c <= 230) || (c >= 317 && c <= 377) || c === 311 || c === 314) return "snow"
        if (c === 176 || c === 263 || c === 266 || c === 293 || c === 296 || c === 353) return "shower"
        if (c === 299 || c === 302 || c === 305 || c === 308 || c === 356 || c === 359) return "rain"
        return "cloud"
    }

    function firstValue(values: var): string {
        const value = Array.isArray(values) && values[0] ? values[0].value : null
        return typeof value === "string" ? value.trim() : ""
    }

    function metric(value: var, suffix: string): string {
        if ((typeof value !== "string" && typeof value !== "number")
                || String(value).trim() === "" || !Number.isFinite(Number(value))) return "—"
        return String(value).trim() + suffix
    }

    function parseWeather(stdout: string): var {
        const data = JSON.parse(stdout)
        const conditions = data && data.current_condition
        const cur = Array.isArray(conditions) ? conditions[0] : null
        const areas = data && data.nearest_area
        const area = Array.isArray(areas) ? areas[0] : null
        const name = area ? firstValue(area.areaName) : ""
        if (!cur || typeof cur !== "object" || Array.isArray(cur)
                || metric(cur.temp_C, "") === "—" || !name)
            throw new Error("Fehlende Wetterdaten oder Ortsangabe")
        const icon = weatherIcon(String(cur.weatherCode))
        // wttr.in usually supplies lang_de for the language header; keep fallback German.
        const descriptions = {
            sun: "Klar", partly: "Leicht bewölkt", cloud: "Bewölkt", fog: "Nebel",
            rain: "Regen", shower: "Regenschauer", snow: "Schnee", thunder: "Gewitter", unknown: "Unbekannt"
        }
        return {
            city: name,
            temperature: metric(cur.temp_C, "°"),
            feels: "Gefühlt " + metric(cur.FeelsLikeC, "°"),
            humidity: metric(cur.humidity, "%"),
            wind: metric(cur.windspeedKmph, " km/h"),
            visibility: metric(cur.visibility, " km"),
            description: firstValue(cur.lang_de) || descriptions[icon],
            icon: icon
        }
    }

    function fail(message: string, detail: string): void {
        current = null
        status = message
        console.warn("sassydash: Wetter: " + detail)
        refreshTimer.interval = retryDelay
        retryDelay = Math.min(retryDelay * 2, refreshInterval)
        refreshTimer.restart()
    }

    function refresh(): void {
        if (!ready || busy) return
        refreshTimer.stop()
        let command
        try {
            command = requestCommand(location)
        } catch (error) {
            current = null
            status = "Ungültiger Ort. Bitte Einstellung prüfen."
            console.warn("sassydash: Wetter: " + error.message)
            return
        }
        requestedLocation = location
        busy = true
        fetch.command = command
        fetch.run()
    }

    onLocationChanged: {
        refreshTimer.stop()
        current = null
        city = ""
        status = "Lade…"
        retryDelay = 60000
        refresh()
    }
    Component.onCompleted: {
        ready = true
        refresh()
    }

    Timer {
        id: refreshTimer
        interval: card.refreshInterval
        repeat: false
        onTriggered: card.refresh()
    }

    Command {
        id: fetch
        onFinished: (stdout, exitCode) => {
            card.busy = false
            // A config change during curl must not publish data for the previous place.
            if (card.requestedLocation !== card.location) {
                Qt.callLater(card.refresh)
                return
            }
            if (exitCode !== 0) {
                card.fail("Wetter nicht verfügbar. Neuer Versuch folgt.", "curl beendet mit Code " + exitCode)
                return
            }
            try {
                const weather = card.parseWeather(stdout)
                card.city = weather.city
                card.current = weather
                card.status = ""
                card.retryDelay = 60000
                refreshTimer.interval = card.refreshInterval
                refreshTimer.restart()
            } catch (error) {
                card.fail("Ungültige Wetterdaten. Neuer Versuch folgt.", "JSON: " + error.message)
            }
        }
    }

    // Original 24×24 SVG paths, including their sun accents and 22% fills.
    component WeatherIcon: Item {
        id: icon
        required property string kind
        readonly property bool hasSun: kind === "sun" || kind === "partly" || kind === "shower"
        readonly property bool hasCloud: ["cloud", "partly", "rain", "shower", "snow", "thunder"].indexOf(kind) >= 0
        width: 30
        height: 30

        Shape {
            width: 24
            height: 24
            scale: 1.25
            transformOrigin: Item.TopLeft

            ShapePath {
                strokeColor: "#dfc98f"
                strokeWidth: 1.5
                capStyle: ShapePath.SquareCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "#38dfc98f"
                PathSvg {
                    path: !icon.hasSun ? "" : icon.kind === "sun"
                        ? "M16 12a4 4 0 1 0 -8 0a4 4 0 1 0 8 0z"
                        : icon.kind === "partly" ? "M11.5 8.5a3 3 0 1 0 -6 0a3 3 0 1 0 6 0z"
                        : "M11.1 6a2.6 2.6 0 1 0 -5.2 0a2.6 2.6 0 1 0 5.2 0z"
                }
            }
            ShapePath {
                strokeColor: "#dfc98f"
                strokeWidth: 1.5
                capStyle: ShapePath.SquareCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"
                PathSvg {
                    path: !icon.hasSun ? "" : icon.kind === "sun"
                        ? "M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M18.7 5.3l-1.8 1.8M7.1 16.9l-1.8 1.8"
                        : icon.kind === "partly" ? "M8.5 2.5v1.8M2.5 8.5h1.8M4.3 4.3l1.2 1.2M12.7 4.3l-1.2 1.2"
                        : "M8.5 .8v1.5M3.3 6h1.5M4.8 2.3l1 1M12.2 2.3l-1 1"
                }
            }
            ShapePath {
                strokeColor: "#91bffd"
                strokeWidth: 1.5
                capStyle: ShapePath.SquareCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "#3891bffd"
                PathSvg {
                    // Translate the cloud paths in their coordinates, as in the SVG transforms.
                    path: !icon.hasCloud ? "" : icon.kind === "partly"
                        ? "M9 20.5h9a3 3 0 0 0 .3-6A4.6 4.6 0 0 0 9.8 15.3 2.6 2.6 0 0 0 9 20.5z"
                        : icon.kind === "shower" ? "M9 15.5h8a3 3 0 0 0 .3-6A4.6 4.6 0 0 0 9.8 10.3 2.6 2.6 0 0 0 9 15.5z"
                        : icon.kind === "cloud" ? "M6 17h11a3.5 3.5 0 0 0 .4-7A5.5 5.5 0 0 0 6.8 10.5 3.2 3.2 0 0 0 6 17z"
                        : "M6 14h11a3.5 3.5 0 0 0 .4-7A5.5 5.5 0 0 0 6.8 7.5 3.2 3.2 0 0 0 6 14z"
                }
            }
            ShapePath {
                strokeColor: "#91bffd"
                strokeWidth: icon.kind === "snow" ? 2.2 : 1.5
                capStyle: ShapePath.SquareCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"
                PathSvg {
                    path: icon.kind === "fog" ? "M4 8h16M6 12h14M4 16h12M8 20h10"
                        : icon.kind === "rain" ? "M8 17.5l-1 3M12 17.5l-1 3M16 17.5l-1 3"
                        : icon.kind === "shower" ? "M10 18l-1 3M14 18l-1 3"
                        : icon.kind === "snow" ? "M8 18h.01M12 18h.01M16 18h.01M10 21h.01M14 21h.01"
                        : icon.kind === "thunder" ? "M13 14.5 10 19h3.5l-1.5 3.5" : ""
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: icon.kind === "unknown"
            text: "·"
            color: "#91bffd"
            font.pixelSize: 27
        }
    }

    ColumnLayout {
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
        spacing: 14

        Text {
            Layout.fillWidth: true
            visible: card.current === null
            text: card.status
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.muted
            font { family: Theme.mono; pixelSize: 11 }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.current !== null
            spacing: 5

            WeatherIcon {
                kind: card.current ? card.current.icon : "unknown"
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignTop
            }
            Text {
                text: card.current ? card.current.temperature : "—°"
                color: Theme.accent
                font { family: Theme.mono; pixelSize: 29; weight: Font.Bold }
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: card.current ? card.current.description : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: Theme.text2
                    font { family: Theme.sans; pixelSize: 9 }
                }
                Text {
                    Layout.fillWidth: true
                    text: card.current ? card.current.feels : ""
                    color: Theme.muted
                    font { family: Theme.sans; pixelSize: 9 }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: card.current !== null
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: [
                    { label: "Luftfeuchte", value: card.current ? card.current.humidity : "—" },
                    { label: "Wind", value: card.current ? card.current.wind : "—" },
                    { label: "Sicht", value: card.current ? card.current.visibility : "—" },
                    { label: "Quelle", value: "wttr.in" }
                ]
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: tileContent.implicitHeight + 14
                    color: Theme.tile
                    radius: Theme.radius

                    ColumnLayout {
                        id: tileContent
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7 }
                        spacing: 3
                        Text {
                            Layout.fillWidth: true
                            text: tile.modelData.label
                            elide: Text.ElideRight
                            color: Theme.muted
                            font { family: Theme.sans; pixelSize: 9; weight: Font.Medium; capitalization: Font.AllUppercase; letterSpacing: 0.5 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: tile.modelData.value
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: Theme.mono; pixelSize: 11 }
                        }
                    }
                }
            }
        }
    }
}
