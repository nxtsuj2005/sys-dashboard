#!/usr/bin/env bash
# Build the Qt6 QMLTermWidget module into the user's QML root, for distros that
# ship no Qt6 build (Fedora: Qt5-only package; Debian: not packaged).
#   ./plasmoid/build-qmltermwidget.sh <qml-root>
# Result: <qml-root>/QMLTermWidget (pinned upstream commit, rebuilt only when the pin changes).
set -euo pipefail

REPO="https://github.com/Swordfish90/qmltermwidget"
COMMIT="8913504fa2ebd220ebe7c680c32954e1b3c035c5"

QMLROOT="${1:?usage: $0 <qml-root>}"
DEST="$QMLROOT/QMLTermWidget"
STAMP="$DEST/.sassydash-commit"
WORK="${XDG_CACHE_HOME:-$HOME/.cache}/sassydash/qmltermwidget-$COMMIT"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m!!\033[0m  %s\n' "$*" >&2; exit 1; }

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$COMMIT" ] && [ -f "$DEST/qmldir" ]; then
  say "QMLTermWidget (Qt6) schon gebaut: $DEST"
  exit 0
fi

QMAKE=""
for q in qmake6 "$(qtpaths6 --query QT_HOST_BINS 2>/dev/null || true)/qmake" /usr/lib64/qt6/bin/qmake /usr/lib/qt6/bin/qmake; do
  if command -v "$q" >/dev/null 2>&1 && "$q" -query QT_VERSION 2>/dev/null | grep -q '^6\.'; then QMAKE="$q"; break; fi
done
[ -n "$QMAKE" ] || die "qmake (Qt6) fehlt — Fedora: sudo dnf install qt6-qtbase-devel qt6-qtdeclarative-devel gcc-c++ make"
command -v make >/dev/null || die "make fehlt"
command -v c++ >/dev/null || die "C++-Compiler fehlt (Fedora: gcc-c++, Debian: g++)"

say "Lade qmltermwidget ${COMMIT:0:7}"
rm -rf "$WORK"
mkdir -p "$WORK"
curl -fsSL --proto '=https' "$REPO/archive/$COMMIT.tar.gz" | tar -xz -C "$WORK" --strip-components=1 \
  || die "Download von $REPO fehlgeschlagen"

say "Baue QMLTermWidget mit $QMAKE (dauert ~1 Min)"
( cd "$WORK" && "$QMAKE" >/dev/null && make -j"$(nproc)" >"$WORK/build.log" 2>&1 ) \
  || die "Build fehlgeschlagen — Log: $WORK/build.log"
[ -f "$WORK/QMLTermWidget/qmldir" ] || die "Build lieferte kein QMLTermWidget/qmldir — Log: $WORK/build.log"

mkdir -p "$QMLROOT"
rm -rf "$DEST"
cp -r "$WORK/QMLTermWidget" "$DEST"
echo "$COMMIT" > "$STAMP"
rm -rf "$WORK"
say "QMLTermWidget (Qt6) installiert: $DEST"
