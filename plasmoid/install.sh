#!/usr/bin/env bash
# SASSY·DASH plasmoid — install or upgrade (idempotent). Plasma 6 only.
#   ./plasmoid/install.sh            deps + install/upgrade
#   ./plasmoid/install.sh --no-deps  skip the package manager
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$HERE/org.nxtsuj.sassydash"
ID="org.nxtsuj.sassydash"
QMLROOT="$HOME/.local/share/sassydash/qml"
ENVFILE="$HOME/.config/plasma-workspace/env/sassydash.sh"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }

[ "$(id -u)" -eq 0 ] && { warn "Nicht als root ausführen."; exit 1; }
command -v kpackagetool6 >/dev/null || { warn "kpackagetool6 fehlt — Plasma 6 erforderlich (Plasma 5 wird nicht unterstützt)."; exit 1; }

if [ "${1:-}" != "--no-deps" ]; then
  say "System-Pakete"
  SUDO=$(command -v sudo || command -v doas || true)
  [ -n "$SUDO" ] || warn "Weder sudo noch doas gefunden — Pakete bitte manuell installieren."
  if   command -v pacman  >/dev/null; then
    $SUDO pacman -S --needed --noconfirm qmltermwidget kquickcharts libksysguard ksystemstats plasma5support procps-ng \
      || warn "pacman fehlgeschlagen — evtl. erst 'sudo pacman -Syu' (kein -Sy allein, Partial Upgrade)."
  elif command -v dnf     >/dev/null; then
    $SUDO dnf install -y qmltermwidget kf6-kquickcharts libksysguard ksystemstats plasma5support procps-ng \
      || warn "dnf: Paketnamen ungeprüft — fehlende Module manuell nachinstallieren."
  elif command -v apt-get >/dev/null; then
    $SUDO apt-get install -y qml6-module-org-kde-quickcharts qml6-module-org-kde-ksysguard ksystemstats libplasma5support6 procps \
      || warn "apt fehlgeschlagen."
    warn "Debian/Ubuntu: qmltermwidget (Qt6) ist dort nicht als QML-Modul paketiert — Terminal-Karte zeigt dann einen Hinweis."
  else
    warn "Unbekannter Paketmanager — benötigt: qmltermwidget (Qt6), kquickcharts, libksysguard, ksystemstats, plasma5support, procps"
  fi
fi

say "Plasmoid $ID"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
  kpackagetool6 -t Plasma/Applet -u "$PKG"
else
  kpackagetool6 -t Plasma/Applet -i "$PKG"
fi

# qmltermwidget points COLORSCHEMES_DIR at the first QML import path that has
# QMLTermWidget/color-schemes. A schemes-only dir (no qmldir, so the real module
# still loads from the system) placed first via QML_IMPORT_PATH adds ours.
say "Terminal-Farbschema"
SYSMOD=""
for d in "$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null || true)" /usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml; do
  [ -n "$d" ] && [ -f "$d/QMLTermWidget/qmldir" ] && { SYSMOD="$d/QMLTermWidget"; break; }
done
if [ -n "$SYSMOD" ]; then
  T="$QMLROOT/QMLTermWidget"
  rm -rf "$T"
  mkdir -p "$T/color-schemes" "$(dirname "$ENVFILE")"
  ln -s "$SYSMOD/kb-layouts" "$T/kb-layouts"
  ln -s "$SYSMOD"/color-schemes/*.colorscheme "$T/color-schemes/"
  cp "$HERE"/color-schemes/*.colorscheme "$T/color-schemes/"
  printf 'export QML_IMPORT_PATH=%q"${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"\n' "$QMLROOT" > "$ENVFILE"
else
  warn "QMLTermWidget-Modul nicht gefunden — Terminal-Karte zeigt einen Hinweis, Farbschema übersprungen."
fi

say "Fertig. Rechtsklick auf den Desktop → „Desktop und Hintergrundbild einrichten…“ → Layout: SASSY·DASH → Anwenden."
say "Farbschema greift nach dem nächsten Login; Updates: git pull && ./plasmoid/install.sh --no-deps && systemctl --user restart plasma-plasmashell"
