#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
"$root/scripts/check_environment.sh"
python3 -B "$root/scripts/check_assets.py"
[[ "$(uname -s)" == Darwin ]] || { echo 'A macOS host is required.' >&2; exit 2; }
for arg in "$@"; do
    case "$arg" in
        --force) rm -rf "$root/build/${CASSOTIS_ARCH:-arm64}/units";;
        --help|-h) echo 'Usage: build_all.sh [--force]'; exit 0;;
        *) echo "Unknown argument: $arg" >&2; exit 2;;
    esac
done
"$root/scripts/build_native.sh"
"$root/scripts/build_fpc.sh"
python3 -B "$root/scripts/build_dictionaries.py"
"$root/scripts/build_app.sh"
"$root/scripts/build_installer.sh"
