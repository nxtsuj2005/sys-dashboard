# SASSY·DASH

Persönliches System-Dashboard. Zwei Varianten:

- **Plasmoid** (`plasmoid/`, neu, Prototyp): natives Plasma-6-Desktop-Layout mit eingebettetem Terminal. Kein Electron, keine KWin-Regeln, kein xterm-Overlay.
- **Electron** (`src/`, bisher): Vollbild-Fenster im Hintergrund, externes xterm als Terminal-Slot.

## Plasmoid (empfohlen auf KDE Plasma 6)

**Voraussetzungen:** KDE Plasma **6** (Arch, Fedora KDE, Debian 13+). Plasma 5 (Debian 12, Kubuntu 22.04) wird nicht unterstützt.

| Distro | Pakete (installiert `install.sh` automatisch) |
|---|---|
| Arch | `qmltermwidget kquickcharts libksysguard ksystemstats plasma5support procps-ng` |
| Fedora | `qmltermwidget kf6-kquickcharts libksysguard ksystemstats plasma5support procps-ng` (Namen ungeprüft) |
| Debian 13 | `qml6-module-org-kde-quickcharts qml6-module-org-kde-ksysguard ksystemstats qml6-module-org-kde-plasma-plasma5support procps`, **ohne Terminal**: qmltermwidget (Qt6) ist dort nicht paketiert |

```bash
git clone https://github.com/nxtsuj2005/sys-dashboard
cd sys-dashboard
./plasmoid/install.sh
```

Danach: Rechtsklick auf den Desktop → „Desktop und Hintergrundbild einrichten…“ → **Layout: SASSY·DASH** → Anwenden. Das Dashboard füllt dann automatisch den Bildschirm (ohne Panel-Fläche), nichts zu ziehen. Zurück geht's genauso über Rechtsklick → „SASSY·DASH einrichten…“ → Layout: Ordneransicht. Das Terminal-Farbschema greift erst nach dem nächsten Login.

Update:
```bash
git pull && ./plasmoid/install.sh --no-deps && systemctl --user restart plasma-plasmashell
```

Gut zu wissen:
- Es ist ein Desktop-Layout (Containment), kein Widget: Desktop-Icons und andere Widgets auf diesem Bildschirm sind weg, solange es aktiv ist. Bei mehreren Monitoren pro Bildschirm wählbar.
- Werte kommen aus `ksystemstats` (gleiche Quelle wie Plasmas Systemmonitor). Gerendert wird einmal pro Sekunde in einem gemeinsamen Takt, und wenn ein Fenster das Widget verdeckt, zeichnet Plasma gar nicht.
- Terminal: Shell = fish → `$SHELL` → bash (überschreibbar über den Config-Key `shell`). Kopieren/Einfügen mit Ctrl+Shift+C/V, die Eingabeleiste schickt Zeilen direkt an die Shell.
- `install.sh` legt `~/.config/plasma-workspace/env/sassydash.sh` an (setzt `QML_IMPORT_PATH` auf `~/.local/share/sassydash/qml`, nur für das Terminal-Farbschema). Zum Entfernen: `kpackagetool6 -t Plasma/Applet -r org.nxtsuj.sassydash`, dann diese Datei und `~/.local/share/sassydash` löschen.
- Plasma ändert zwischen 6.x-Versionen gelegentlich QML-APIs. Auf Arch merkst du das zuerst.
- Fehlt noch gegenüber Electron: Wetter, RSS, Blockgeräte/Disk-I/O, Shortcuts, App-Suche (Ctrl+K), Boot-/Glitch-Effekte.

## Electron: Installation (Fedora / Debian / Arch, KDE Plasma empfohlen)

```bash
git clone https://github.com/nxtsuj2005/sys-dashboard
cd sys-dashboard
./setup.sh
```

`setup.sh` ist idempotent (beliebig oft ausführbar) und macht:

1. Installiert `nodejs npm xterm xdotool fish curl gio udevadm` (dnf / apt / pacman)
2. Verlinkt das Repo nach `~/.local/share/sys-dashboard` (Pfad ist in `src/main.js` fest)
3. `npm install` (Electron)
4. Merged die KWin-Fensterregeln in `~/.config/kwinrulesrc` (andere Regeln bleiben unberührt)
5. Legt `~/.config/autostart/sys-dashboard.desktop` an

Start: `cd ~/.local/share/sys-dashboard && npm start` oder neu einloggen.
Update: `git pull && npm install`.

Ohne KDE läuft es auch, aber ohne "immer im Hintergrund"-Verhalten (KWin-Regeln).

## Selfcheck / Anpassung an die Hardware

Beim Start und während `setup.sh` führt das Dashboard eine Hardware-Erkennung durch (`src/selfcheck.js`):

**Erkannt:**
- CPU-Kerne und RAM
- Batterie (Laptop)
- Temperatursensor
- systemd
- Netzwerk, Datenträger
- Session/KDE-Umgebung
- Erforderliche Tools

**Anpassungen:**
- Kernbalken werden bei > 8 Kernen gruppiert
- Batterie-Widget nur auf Laptops
- Performance-Stufe (low/mid/high) steuert Graph-FPS
- Shell-Fallback: fish → $SHELL → bash
- Service-Widget funktioniert auch ohne systemd

Manuell testen:
```bash
node src/selfcheck.js       # Deutsche Ausgabe mit ✓/✗
node src/selfcheck.js --json  # Nur JSON
```

Das Profil wird in `profile.json` gespeichert.
