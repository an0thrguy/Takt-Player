#!/usr/bin/env bash
# Package executable, runtime assets, notices and docs without installing anything globally.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bundle="$project_dir/build/linux/x64/release/bundle"
takt_version="$(sed -n 's/^version: \([0-9.]*\).*/\1/p' "$project_dir/pubspec.yaml")"
takt_name="Takt-$takt_version-linux-x86_64"
takt_package="$project_dir/dist/$takt_name"
test -x "$bundle/takt"
mkdir -p "$takt_package"
cp -a "$bundle/." "$takt_package/"
cp "$project_dir/assets/takt.svg" "$takt_package/takt.svg"
cat > "$takt_package/start.sh" <<'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$bundle_dir/takt" "$@"
LAUNCH
chmod +x "$takt_package/start.sh"
cp "$project_dir/README.md" "$takt_package/README.md"
cp "$project_dir/docs/install-linux.md" "$takt_package/INSTALL.md"
cp "$project_dir/tool/install-release.sh" "$takt_package/install.sh"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$takt_package/THIRD_PARTY_NOTICES.md"
mkdir -p "$takt_package/docs/screenshots"
cp "$project_dir/docs/screenshots/customization-dark.png" "$takt_package/docs/screenshots/"
cp "$project_dir/docs/screenshots/customization-compact.png" "$takt_package/docs/screenshots/"
cp "$project_dir/docs/linux-development-setup.md" "$takt_package/docs/"
cp "$project_dir/docs/code-guide.md" "$takt_package/docs/"
cp "$project_dir/docs/customization.md" "$takt_package/docs/"
mkdir -p "$takt_package/docs/releases"
cp "$project_dir/docs/releases/v$takt_version.md" "$takt_package/docs/releases/"
# Verification reports can contain local probe metadata; ship installation docs only.
cp "$project_dir/docs/install-linux.md" "$takt_package/docs/"
cp "$project_dir/docs/install-android.md" "$takt_package/docs/"
mkdir -p "$takt_package/licenses"
cp "$project_dir/third_party/cnativeapi/LICENSE" "$takt_package/licenses/cnativeapi.txt"
cp "$project_dir/third_party/cnativeapi/cxx_impl/LICENSE" "$takt_package/licenses/nativeapi.txt"
# Include the licenses of every resolved Dart package and Flutter itself.
python3 "$project_dir/tool/collect-licenses.py" "$takt_package/licenses"
python3 - "$takt_package/BUILD-INFO.txt" <<'BUILDINFO'
import platform,pathlib,subprocess,sys
os_info=platform.freedesktop_os_release()
libc=subprocess.run(['getconf','GNU_LIBC_VERSION'],capture_output=True,text=True).stdout.strip()
pathlib.Path(sys.argv[1]).write_text('Built on '+os_info.get('PRETTY_NAME','Linux')+' '+platform.machine()+'\n'+libc+'\nFlutter 3.47.6 / Dart 3.13.5\nSystem libraries are required; this is not a universal static bundle.\n')
BUILDINFO
tar -czf "$project_dir/dist/$takt_name.tar.gz" -C "$project_dir/dist" "$takt_name"
(cd "$project_dir/dist" && sha256sum "$takt_name.tar.gz" > SHA256SUMS.txt)
printf 'Package: %s\n' "$project_dir/dist/$takt_name.tar.gz"
