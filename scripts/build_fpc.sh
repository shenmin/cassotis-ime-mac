#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
case "$arch" in arm64) cpu=aarch64;; x86_64) cpu=x86_64;; *) exit 2;; esac
fpc="${CASSOTIS_FPC_BIN:-fpc}"
bin="$root/build/$arch/bin"
units="$root/build/$arch/units"
logs="$root/build/$arch/logs"
mkdir -p "$bin" "$units" "$logs"
args=("-P$cpu" -Mdelphiunicode -FcUTF8 -vm2091 -vm4110 -O2 -g -gl -Si -vewnhibq "-FE$bin" "-FU$units")
for dir in common engine dictionary ipc service host; do args+=("-Fu$root/src/$dir"); done
compile() {
    local source="$1" name="$2"
    printf '[FPC %s] %s\n' "$arch" "$name"
    if ! "$fpc" "${args[@]}" "-o$name" "$root/$source" >"$logs/$name.log" 2>&1; then
        cat "$logs/$name.log" >&2
        exit 1
    fi
}
compile tools/dictionary/cassotis_dict_init.lpr cassotis-dict-init
compile src/service/cassotis_engine.lpr cassotis-engine
# Sign the helper before embedding it in the application.
codesign --force --sign - "$bin/cassotis-engine"
