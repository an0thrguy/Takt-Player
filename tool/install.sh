#!/usr/bin/env bash
# Copy the release bundle into user app storage and register its launcher; music data is separate.
# Optional installation into the current user's application menu; no sudo.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
takt_share="${XDG_DATA_HOME:-$HOME/.local/share}"
takt_destination="$takt_share/takt"
mkdir -p "$takt_destination" "$takt_share/applications"
cp -a "$project_dir/build/linux/x64/release/bundle/." "$takt_destination/"
cp "$project_dir/assets/takt.svg" "$takt_destination/takt.svg"
cat > "$takt_share/applications/takt.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Takt
Comment=Local music player
Comment[ru]=Плеер локальной музыки
Exec="$takt_destination/takt"
Icon=$takt_destination/takt.svg
Terminal=false
Categories=AudioVideo;Audio;Player;
StartupWMClass=Com.takt.player.takt
DESKTOP
printf 'Takt installed: %s\n' "$takt_destination"
