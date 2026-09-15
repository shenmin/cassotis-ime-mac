#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
for arg in "$@"; do
    case "$arg" in
        --help|-h) echo 'Usage: rebuild_all.sh'; exit 0;;
        *) echo "Unknown argument: $arg" >&2; exit 2;;
    esac
done
"$root/scripts/clean.sh"
"$root/scripts/build.sh"
