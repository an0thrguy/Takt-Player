#!/usr/bin/env bash
# Launch the project release bundle. Build it with flutter build linux --release first.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$project_dir/build/linux/x64/release/bundle/takt" "$@"
