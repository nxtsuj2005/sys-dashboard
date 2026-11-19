# SASSY·DASH

Persönliches System-Dashboard. Zwei Varianten:

- **Plasmoid** (`plasmoid/`, neu, Prototyp): natives Plasma-6-Desktop-Layout mit eingebettetem Terminal. Kein Electron, keine KWin-Regeln, kein xterm-Overlay.
- **Electron** (`src/`, bisher): Vollbild-Fenster im Hintergrund, externes xterm als Terminal-Slot.

## Plasmoid (empfohlen auf KDE Plasma 6)

**Voraussetzungen:** KDE Plasma **6** (Arch, Fedora KDE, Debian 13+). Plasma 5 (Debian 12, Kubuntu 22.04) wird nicht unterstützt.

| Distro | Pakete (installiert `install.sh` automatisch) |
|---|---|
| Arch | `qmltermwidget kquickcharts libksysguard ksystemstats plasma5support procps-ng` |
| Fedora | `kf6-kquickcharts libksysguard ksystemstats plasma5support procps-ng qmltermwidget` (ab F45 Qt6; ältere Releases haben nur Qt5, dann Build-Tools `qt6-qtbase-devel qt6-qtdeclarative-devel gcc-c++ make` und das Terminal-Modul wird selbst gebaut, ~1 Min) |
| Debian 13 | `qml6-module-org-kde-quickcharts qml6-module-org-kde-ksysguard ksystemstats libplasma5support6 procps` + Build-Tools `qt6-base-dev qt6-declarative-dev qmake6 g++ make` (Terminal-Modul wird selbst gebaut) |

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

`install.sh` prüft vor der Installation die Pflicht-Abhängigkeiten (QML-Module, ksystemstats, top, lsblk, curl) und bricht bei fehlenden ab. `--force` überspringt diese Prüfung.

Dazu kommt der Plasma-Stil **SASSY·DASH** (Breeze Dark in den Dashboard-Farben, damit das Panel nahtlos auf dem Dashboard sitzt). Er wird nur bei der ersten Installation aktiviert; zurück geht es unter Systemeinstellungen → Plasma-Stil.

Außerdem ein eigener **Lockscreen** (Uhr, `$ unlock`-Prompt, Scanline, Proxmox-Gästebaum; kein Name, Avatar oder Benachrichtigungen). Er gilt nach dem nächsten Login. Der Baum liest `~/.cache/sassydash/pve.json` (`{"ts": <unix>, "guests": [{"id": 105, "up": true}]}`); fehlt die Datei oder ist sie älter als 2 Minuten, wird er grau. Zurück zum Standard-Lockscreen: `rm ~/.config/systemd/user/plasma-kwin_wayland.service.d/sassydash-lock.conf` und neu einloggen.

Gut zu wissen:
- Es ist ein Desktop-Layout (Containment), kein Widget: Desktop-Icons und andere Widgets auf diesem Bildschirm sind weg, solange es aktiv ist. Bei mehreren Monitoren pro Bildschirm wählbar.
- Zwei Ansichten: `main` (volles Dashboard mit Terminal) und `monitor` (Graphen-Wand: CPU/RAM mit allen Kernen, Netzwerk, Datenträger-I/O, GPU, Temperatur, Prozesse). Config-Key `view`, Default `auto` = Hauptbildschirm `main`, jeder weitere `monitor`.
- Werte kommen aus `ksystemstats` (gleiche Quelle wie Plasmas Systemmonitor). Alles läuft in einem gemeinsamen 1-s-Takt; Graphen scrollen dazwischen gleichmäßig weiter, Balken gleiten kurz nach (siehe `glideFps`).
- Terminal: Shell = fish → `$SHELL` → bash (überschreibbar über den Config-Key `shell`). Kopieren/Einfügen mit Ctrl+Shift+C/V, die Eingabeleiste schickt Zeilen direkt an die Shell.
- Terminal-Modul: Gibt es kein Qt6-`QMLTermWidget` im System (Fedora < 45, Debian), baut `plasmoid/build-qmltermwidget.sh` einen festen Upstream-Commit nach `~/.local/share/sassydash/qml` (nur beim ersten Mal bzw. wenn sich der Commit ändert).
- `install.sh` legt `~/.config/plasma-workspace/env/sassydash.sh` an (setzt `QML_IMPORT_PATH` auf `~/.local/share/sassydash/qml`, für Terminal-Modul und Farbschema). Zum Entfernen: `kpackagetool6 -t Plasma/Applet -r org.nxtsuj.sassydash`, dann diese Datei und `~/.local/share/sassydash` löschen.
- Plasma ändert zwischen 6.x-Versionen gelegentlich QML-APIs. Auf Arch merkst du das zuerst.
- Wetter folgt dem Laptop: ohne Einstellung ermittelt wttr.in den Ort über die öffentliche IP (bei VPN/Mobilfunk evtl. ungenau). Fester Ort: Config-Key `weatherLocation` (siehe unten).
- Graphen scrollen durchgehend mit `glideFps` Bildern/s (Default 20, max. 60), Balken/Gauges gleiten damit ~0,45 s nach. Jeder Frame zeichnet den Desktop neu: gemessen auf zwei Bildschirmen (1080p + 1440×900) ~10 % eines Kerns bei 20 (15 spart kaum: ~9 %), ~17 % bei 40, ~1,4 % bei `0` (springen, am sparsamsten, z. B. Laptop im Akkubetrieb). Der Wert gilt für alle Bildschirme gemeinsam, also überall gleich setzen.
- Effekte wie in Electron: Boot-Sequenz beim Start, alle 1–15 Min ein kurzer Kachel-Glitch, und pro Sitzung mit 60 % Chance nach 1–5 h ein Crash mit Reboot (die Shell im Terminal überlebt). Scanlines/Sweep/Logo-Glitch sind auch in Electron abgeschaltet. `reducedMotion=true` schaltet Boot, Glitch und Crash ab; `fxDebug=glitch` (alle ~25 s) bzw. `fxDebug=crash` (20 s nach dem Boot) zum Ansehen.
- Ctrl+K (App-Suche) greift, solange der Desktop den Fokus hat (einmal draufklicken). Bewusst kein globales Kürzel.
- RSS fehlt bewusst (in Electron ebenfalls ausgeblendet).

Config-Keys (`view`, `weatherLocation`, `glideFps`, `reducedMotion`, `fxDebug`, `shell`) setzen, `<id>` ist die Nummer der `[Containments][…]`-Gruppe mit `plugin=org.nxtsuj.sassydash`:

```bash
grep -B8 'plugin=org.nxtsuj.sassydash' ~/.config/plasma-org.kde.plasma.desktop-appletsrc | grep '^\[Containments\]'
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group <id> --group General --key glideFps 0
systemctl --user restart plasma-plasmashell
```

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
