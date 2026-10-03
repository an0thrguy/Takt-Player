#!/usr/bin/env bash
# Package executable, runtime assets, notices and docs without installing anything globally.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bundle="$project_dir/build/linux/x64/release/bundle"
takt_package="$project_dir/dist/Takt-0.1.0-linux-x86_64"
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
mkdir -p "$takt_package/docs"
cp "$project_dir/docs/linux-development-setup.md" "$takt_package/docs/"
cp "$project_dir/docs/code-guide.md" "$takt_package/docs/"
cp -a "$project_dir/docs/verification" "$takt_package/docs/"
mkdir -p "$takt_package/licenses"
cp "$project_dir/third_party/cnativeapi/LICENSE" "$takt_package/licenses/cnativeapi.txt"
cp "$project_dir/third_party/cnativeapi/cxx_impl/LICENSE" "$takt_package/licenses/nativeapi.txt"
tar -czf "$project_dir/dist/Takt-0.1.0-linux-x86_64.tar.gz" -C "$project_dir/dist" Takt-0.1.0-linux-x86_64
printf 'Package: %s\n' "$project_dir/dist/Takt-0.1.0-linux-x86_64.tar.gz"
