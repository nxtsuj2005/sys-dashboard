# SASSY·DASH

Persönliches Electron-System-Dashboard (Vollbild, läuft im Hintergrund, externes xterm als Terminal-Slot).

## Installation (Fedora / Debian / Arch, KDE Plasma empfohlen)

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
