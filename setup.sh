#!/usr/bin/env bash
# SASSY·DASH setup — idempotent, safe to re-run.
#   git clone https://github.com/nxtsuj2005/sys-dashboard && cd sys-dashboard && ./setup.sh
# Installs system deps + npm deps, links the repo to ~/.local/share/sys-dashboard
# (path is hardcoded in src/main.js), merges the KWin window rules and adds autostart.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.local/share/sys-dashboard"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }

[ "$(id -u)" -eq 0 ] && { warn "Nicht als root ausführen (sudo wird bei Bedarf selbst genutzt)."; exit 1; }

# ── 1. System-Pakete ─────────────────────────────────────────
say "System-Pakete"
if   command -v dnf    >/dev/null; then sudo dnf install -y nodejs npm xterm xdotool fish curl glib2 systemd-udev
elif command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y nodejs npm xterm xdotool fish curl libglib2.0-bin udev
elif command -v pacman >/dev/null; then sudo pacman -S --needed --noconfirm nodejs npm xterm xdotool fish curl glib2 systemd
else warn "Kein bekannter Paketmanager — installiere manuell: node, npm, xterm, xdotool, fish, curl, gio, udevadm"; fi

# ── 2. Repo an den Pfad legen, den main.js erwartet ──────────
say "Verknüpfe $TARGET"
mkdir -p "$(dirname "$TARGET")"
if [ "$REPO" != "$TARGET" ]; then
  if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    warn "$TARGET existiert bereits und ist kein Symlink — überspringe Verknüpfung."
  else
    ln -sfn "$REPO" "$TARGET"
  fi
fi

# ── 3. npm-Abhängigkeiten (Electron) ─────────────────────────
say "npm install"
(cd "$REPO" && npm install --no-audit --no-fund)

# ── 4. KWin-Fensterregeln (nur KDE) ──────────────────────────
KW=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)
KR=$(command -v kreadconfig6  || command -v kreadconfig5  || true)
if [ -n "$KW" ] && [ -n "$KR" ]; then
  say "KWin-Regeln"
  rule() {  # rule <Description> key=value ...   (merged by Description, rest of kwinrulesrc untouched)
    local desc="$1"; shift
    local count n i
    count=$("$KR" --file kwinrulesrc --group General --key count --default 0)
    n=""
    for ((i=1; i<=count; i++)); do
      [ "$("$KR" --file kwinrulesrc --group "$i" --key Description)" = "$desc" ] && { n=$i; break; }
    done
    if [ -z "$n" ]; then
      n=$((count+1))
      "$KW" --file kwinrulesrc --group General --key count "$n"
      local rules names
      rules=$("$KR" --file kwinrulesrc --group General --key rules);          rules="${rules:+$rules,}$n"
      names=$("$KR" --file kwinrulesrc --group General --key ruleGroupNames); names="${names:+$names,}$n"
      "$KW" --file kwinrulesrc --group General --key rules "$rules"
      "$KW" --file kwinrulesrc --group General --key ruleGroupNames "$names"
    fi
    "$KW" --file kwinrulesrc --group "$n" --key Description "$desc"
    local kv
    for kv in "$@"; do "$KW" --file kwinrulesrc --group "$n" --key "${kv%%=*}" "${kv#*=}"; done
  }
  # xterm-Overlay: rahmenlos + below (liegt im selben Band wie das Dashboard, per windowraise darüber;
  # ohne below legte er sich beim Neustart über laufende Anwendungen)
  rule "SysDashboard xterm" below=true belowrule=2 noborder=true noborderrule=2 skippager=true skippagerrule=2 \
       skipswitcher=true skipswitcherrule=2 skiptaskbar=true skiptaskbarrule=2 \
       wmclass=SysDashboardXterm wmclasscomplete=false wmclassmatch=1
  # Dashboard-Fenster: immer im Hintergrund
  rule "SysDashboard window" below=true belowrule=2 skippager=true skippagerrule=2 \
       skipswitcher=true skipswitcherrule=2 skiptaskbar=true skiptaskbarrule=2 \
       title=Dashboard titlematch=1
  dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure 2>/dev/null || true
else
  warn "Kein KDE (kwriteconfig fehlt) — KWin-Regeln übersprungen. Ohne sie liegt das Dashboard nicht automatisch im Hintergrund."
fi

# ── 5. Autostart ─────────────────────────────────────────────
say "Autostart"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/sys-dashboard.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=SysDash
Comment=Persönliches System-Dashboard
Exec=/bin/bash -c "cd $TARGET && npm start"
Terminal=false
Categories=System;Monitor;
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-KDE-StartupNotify=false
Hidden=false
EOF

# ── 6. Selfcheck ────────────────────────────────────────────
say "Selfcheck"
if [ -f "$REPO/src/selfcheck.js" ]; then
  node "$REPO/src/selfcheck.js" || warn "Selfcheck fehlgeschlagen"
  say "Das Dashboard wiederholt diese Prüfung beim Start und passt sich automatisch an (Kernbalken, Batterie, Perf-Stufe, Shell, systemd)."
else
  warn "selfcheck.js nicht gefunden — übersprungen"
fi

say "Fertig. Start: cd $TARGET && npm start   (oder einmal neu einloggen)"
