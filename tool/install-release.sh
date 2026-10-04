#!/usr/bin/env bash
# Install a downloaded bundle for the current user; preserve the separate music database.
set -euo pipefail
takt_bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
takt_share="${XDG_DATA_HOME:-$HOME/.local/share}"
takt_target="$takt_share/takt"
test -x "$takt_bundle/takt"
mkdir -p "$takt_target" "$takt_share/applications"
if [[ "$takt_bundle" != "$takt_target" ]]; then
  cp -a "$takt_bundle/." "$takt_target/"
fi
python3 - "$takt_target" "$takt_share/applications/takt.desktop" <<'PY'
import pathlib, sys
target, launcher = map(pathlib.Path, sys.argv[1:])
# Desktop Entry quoting differs from shell quoting; escape reserved characters.
def quoted(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'
launcher.write_text('\n'.join([
    '[Desktop Entry]', 'Type=Application', 'Name=Takt',
    'Comment=Local music player', 'Comment[ru]=Плеер локальной музыки',
    'Exec=' + quoted(target / 'takt'), 'Icon=' + str(target / 'takt.svg'),
    'Terminal=false', 'Categories=AudioVideo;Audio;Player;',
    'StartupWMClass=com.takt.player.takt', '',
]))
PY
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$takt_share/applications" || true
fi
printf 'Takt installed: %s\n' "$takt_target"
