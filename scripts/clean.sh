#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
[[ $# -eq 0 ]] || { echo 'Usage: clean_all.sh' >&2; exit 2; }
[[ "$root" != / && "$root" != "$HOME" && -f "$root/resources/Info.plist" && \
    -f "$root/scripts/build.sh" && -f "$root/src/service/cassotis_engine.lpr" ]] || exit 2
[[ ! -L "$root/build" ]] || { echo 'Refusing to clean a symlinked build directory.' >&2; exit 2; }
rm -rf "$root/build"
printf 'Removed build outputs.\n'
