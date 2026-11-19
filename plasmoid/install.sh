#!/usr/bin/env bash
# SASSY·DASH plasmoid — install or upgrade (idempotent). Plasma 6 only.
#   ./plasmoid/install.sh            deps + install/upgrade
#   ./plasmoid/install.sh --no-deps  skip the package manager (preflight still runs)
#   ./plasmoid/install.sh --force    skip the preflight (install even if deps are missing)
# Flags can be combined. Preflight aborts BEFORE kpackagetool6 if mandatory deps are missing.
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

NO_DEPS=0; FORCE=0
for a in "$@"; do
  case "$a" in
    --no-deps) NO_DEPS=1 ;;
    --force)   FORCE=1 ;;
    *) warn "Unbekannte Option: $a (erlaubt: --no-deps, --force)"; exit 1 ;;
  esac
done

if [ "$NO_DEPS" = 0 ]; then
  say "System-Pakete"
  SUDO=$(command -v sudo || command -v doas || true)
  [ -n "$SUDO" ] || warn "Weder sudo noch doas gefunden — Pakete bitte manuell installieren."
  if   command -v pacman  >/dev/null; then
    $SUDO pacman -S --needed --noconfirm qmltermwidget kquickcharts libksysguard ksystemstats plasma5support procps-ng curl \
      || warn "pacman fehlgeschlagen — evtl. erst 'sudo pacman -Syu' (kein -Sy allein, Partial Upgrade)."
  elif command -v dnf     >/dev/null; then
    $SUDO dnf install -y kf6-kquickcharts libksysguard ksystemstats plasma5support procps-ng curl \
      || warn "dnf fehlgeschlagen — fehlende Pakete manuell nachinstallieren."
    # Fedora's qmltermwidget is Qt6 since F45; older releases ship Qt5 only (useless
    # for Plasma 6) and get build deps for our own Qt6 build instead.
    $SUDO dnf install -y qmltermwidget || true
    if [ ! -f "$(rpm -E '%{_libdir}')/qt6/qml/QMLTermWidget/qmldir" ]; then
      $SUDO dnf install -y qt6-qtbase-devel qt6-qtdeclarative-devel gcc-c++ make curl tar \
        || warn "dnf fehlgeschlagen — Build-Tools für das Terminal-Modul manuell nachinstallieren."
    fi
  elif command -v apt-get >/dev/null; then
    # Debian/Ubuntu ship no Qt6 qmltermwidget — build deps for our own build.
    $SUDO apt-get install -y qml6-module-org-kde-quickcharts qml6-module-org-kde-ksysguard ksystemstats libplasma5support6 procps \
      qt6-base-dev qt6-declarative-dev qmake6 g++ make curl \
      || warn "apt fehlgeschlagen."
  else
    warn "Unbekannter Paketmanager — benötigt: qmltermwidget (Qt6) oder Qt6-Build-Tools, kquickcharts, libksysguard, ksystemstats, plasma5support, procps"
  fi
fi

# Preflight: mandatory runtime pieces must exist before the plasmoid is installed.
# The terminal module is optional and handled further below (TERM_OK).
QMLDIRS=()
for d in "$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null || true)" /usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml; do
  [ -n "$d" ] && [ -d "$d" ] && QMLDIRS+=("$d")
done
have_qml() { # $1 = module path, e.g. org/kde/quickcharts
  local d
  for d in "${QMLDIRS[@]}"; do [ -f "$d/$1/qmldir" ] && return 0; done
  return 1
}
have_ksystemstats() {
  command -v ksystemstats >/dev/null && return 0
  [ -x /usr/libexec/ksystemstats ] || [ -x /usr/lib/ksystemstats ] || [ -x /usr/lib64/ksystemstats ] && return 0
  systemctl --user cat plasma-ksystemstats.service >/dev/null 2>&1
}
preflight() {
  local missing=()
  have_qml org/kde/quickcharts          || missing+=("QML-Modul org.kde.quickcharts (kquickcharts)")
  have_qml org/kde/ksysguard/sensors    || missing+=("QML-Modul org.kde.ksysguard.sensors (libksysguard)")
  have_qml org/kde/plasma/plasma5support || missing+=("QML-Modul org.kde.plasma.plasma5support (plasma5support)")
  have_ksystemstats                     || missing+=("ksystemstats (Binary oder User-Service)")
  command -v top   >/dev/null           || missing+=("top (procps / procps-ng)")
  command -v lsblk >/dev/null           || missing+=("lsblk (util-linux)")
  command -v curl  >/dev/null           || missing+=("curl (Wetter-Karte)")
  command -v timeout >/dev/null         || missing+=("timeout (coreutils, für alle Karten-Befehle)")
  if [ "${#missing[@]}" -gt 0 ]; then
    warn "Pflicht-Abhängigkeiten fehlen:"
    local m; for m in "${missing[@]}"; do warn "  - $m"; done
    warn "Pakete installieren (ohne --no-deps macht das install.sh) oder mit --force trotzdem installieren."
    return 1
  fi
  say "Preflight ok"
}
if [ "$FORCE" = 1 ]; then
  warn "--force: Preflight übersprungen."
else
  preflight || exit 1
fi

say "Plasmoid $ID"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
  kpackagetool6 -t Plasma/Applet -u "$PKG"
else
  kpackagetool6 -t Plasma/Applet -i "$PKG"
fi

# Plasma theme: Breeze Dark recoloured to the dashboard background, so panels show no seam.
# Applied only on its first install; switching away later in System Settings sticks.
say "Plasma-Theme SASSY·DASH"
THEMEDIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/desktoptheme/sassydash"
THEME_NEW=0
[ -d "$THEMEDIR" ] || THEME_NEW=1
mkdir -p "$THEMEDIR"
cp "$HERE"/desktoptheme/sassydash/* "$THEMEDIR/"
if [ "$THEME_NEW" = 1 ]; then
  plasma-apply-desktoptheme sassydash || warn "Theme nicht aktiviert: Systemeinstellungen → Plasma-Stil → SASSY·DASH."
fi

# Lock screen: since Plasma 6 it lives in the shell package, and the greeter picks that via
# PLASMA_DEFAULT_SHELL. Setting it only for KWin (the greeter's parent) leaves plasmashell alone.
# QML that fails to load makes the greeter fall back to its built-in locker; a runtime bug does not,
# so the emergency exit is `loginctl unlock-session` from a TTY or SSH.
# QML_XHR_ALLOW_FILE_READ applies to all of KWin (scripts and effects may then read user files via XHR).
say "Lockscreen SASSY·DASH"
LOCKID="org.nxtsuj.sassydash.lock"
if kpackagetool6 -t Plasma/Shell -l 2>/dev/null | grep -qx "$LOCKID"; then
  kpackagetool6 -t Plasma/Shell -u "$HERE/lockscreen/$LOCKID"
else
  kpackagetool6 -t Plasma/Shell -i "$HERE/lockscreen/$LOCKID"
fi
DROPIN="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-kwin_wayland.service.d/sassydash-lock.conf"
mkdir -p "$(dirname "$DROPIN")"
cat > "$DROPIN" <<EOF
# Written by sys-dashboard/plasmoid/install.sh. Delete this file and log in again for the stock lock screen.
[Service]
Environment=PLASMA_DEFAULT_SHELL=$LOCKID
# The greeter has no network; it reads the Proxmox guest status from ~/.cache/sassydash/pve.json.
Environment=QML_XHR_ALLOW_FILE_READ=1
EOF
systemctl --user daemon-reload || warn "systemctl --user daemon-reload fehlgeschlagen."

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
say "Terminal/Farbschema/Lockscreen greifen nach dem nächsten Login; Updates: git pull && ./plasmoid/install.sh --no-deps && systemctl --user restart plasma-plasmashell"
