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
    # Fedora's qmltermwidget is Qt5-only (useless for Plasma 6) — build deps for our own Qt6 build instead.
    $SUDO dnf install -y kf6-kquickcharts libksysguard ksystemstats plasma5support procps-ng \
      qt6-qtbase-devel qt6-qtdeclarative-devel gcc-c++ make curl tar \
      || warn "dnf fehlgeschlagen — fehlende Pakete manuell nachinstallieren."
  elif command -v apt-get >/dev/null; then
    # Debian/Ubuntu ship no Qt6 qmltermwidget — build deps for our own build.
    $SUDO apt-get install -y qml6-module-org-kde-quickcharts qml6-module-org-kde-ksysguard ksystemstats libplasma5support6 procps \
      qt6-base-dev qt6-declarative-dev qmake6 g++ make curl \
      || warn "apt fehlgeschlagen."
  else
    warn "Unbekannter Paketmanager — benötigt: qmltermwidget (Qt6) oder Qt6-Build-Tools, kquickcharts, libksysguard, ksystemstats, plasma5support, procps"
  fi
fi

say "Plasmoid $ID"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
  kpackagetool6 -t Plasma/Applet -u "$PKG"
else
  kpackagetool6 -t Plasma/Applet -i "$PKG"
fi

# Terminal module: use a system Qt6 build if present (Arch), else build our own into QMLROOT.
# qmltermwidget points COLORSCHEMES_DIR at the first QML import path that has
# QMLTermWidget/color-schemes, so QMLROOT goes first on QML_IMPORT_PATH either way.
say "Terminal-Modul (QMLTermWidget, Qt6)"
SYSMOD=""
for d in "$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null || true)" /usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml; do
  [ -n "$d" ] && [ -f "$d/QMLTermWidget/qmldir" ] && { SYSMOD="$d/QMLTermWidget"; break; }
done
T="$QMLROOT/QMLTermWidget"
TERM_OK=1
if [ -n "$SYSMOD" ]; then
  # Schemes-only overlay (no qmldir, so the real module still loads from the system).
  rm -rf "$T"
  mkdir -p "$T/color-schemes"
  ln -s "$SYSMOD/kb-layouts" "$T/kb-layouts"
  ln -s "$SYSMOD"/color-schemes/*.colorscheme "$T/color-schemes/"
else
  # A schemes-only overlay from an earlier install would shadow the build check.
  [ -f "$T/qmldir" ] || rm -rf "$T"
  "$HERE/build-qmltermwidget.sh" "$QMLROOT" || { TERM_OK=0; warn "Terminal-Karte bleibt ohne Modul (zeigt einen Hinweis)."; }
fi
if [ "$TERM_OK" = 1 ]; then
  cp "$HERE"/color-schemes/*.colorscheme "$T/color-schemes/"
  mkdir -p "$(dirname "$ENVFILE")"
  printf 'export QML_IMPORT_PATH=%q"${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"\n' "$QMLROOT" > "$ENVFILE"
fi

say "Fertig. Rechtsklick auf den Desktop → „Desktop und Hintergrundbild einrichten…“ → Layout: SASSY·DASH → Anwenden."
say "Terminal/Farbschema greifen nach dem nächsten Login; Updates: git pull && ./plasmoid/install.sh --no-deps && systemctl --user restart plasma-plasmashell"
