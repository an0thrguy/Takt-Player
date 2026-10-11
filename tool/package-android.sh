#!/usr/bin/env bash
# Package the signed APK without copying any keystores or personal app data.
set -euo pipefail
takt_project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
takt_version="$(sed -n 's/^version: \([0-9.]*\).*/\1/p' "$takt_project/pubspec.yaml")"
takt_apk="$takt_project/build/app/outputs/flutter-apk/app-release.apk"
test -f "$takt_apk"
mkdir -p "$takt_project/dist"
cp "$takt_apk" "$takt_project/dist/Takt-$takt_version-android-arm64.apk"
cp "$takt_project/docs/install-android.md" "$takt_project/dist/INSTALL-ANDROID.md"
(cd "$takt_project/dist" && sha256sum "Takt-$takt_version-android-arm64.apk" > SHA256SUMS-ANDROID.txt)
printf 'APK: %s\n' "$takt_project/dist/Takt-$takt_version-android-arm64.apk"
