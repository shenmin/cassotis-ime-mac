#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
case "$arch" in
arm64) sha=b678fc3c2354c771fea4fba420edeccfba205140088334df801e7fc40e83a57a;;
*) echo 'Only the pinned arm64 runtime is qualified.' >&2; exit 2;;
esac
name="onnxruntime-osx-$arch-1.20.1"
cache="$root/build/downloads"
mkdir -p "$cache"
archive="$cache/$name.tgz"
library_sha=530cdb5a0de774677d369a83ec8912b0242e9769acd12d34b61412ee6ae368ae
stage="$(mktemp -d "$cache/runtime.XXXXXX")"
target_partial=''
cleanup() {
    rm -rf "$stage"
    if [[ -n "$target_partial" ]]; then rm -f "$target_partial"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fetch() {
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
        "$1" -o "$stage/download"
}
verify() {
    local actual
    actual="$(shasum -a 256 "$1" | cut -d ' ' -f 1)"
    [[ "$actual" == "$2" ]] || { echo 'ONNX Runtime checksum mismatch' >&2; return 1; }
}
fallback=false
if [[ ! -f "$archive" ]]; then
    if fetch "https://github.com/microsoft/onnxruntime/releases/download/v1.20.1/$name.tgz"; then
        mv "$stage/download" "$archive"
    else
        fallback=true
        rm -f "$stage/download"
    fi
fi
if $fallback; then
    # Microsoft's NuGet package contains the identical arm64 native library.
    # A failed download may use this source; a checksum mismatch must fail.
    echo 'GitHub download unavailable; using the pinned Microsoft NuGet package.' >&2
    archive="$cache/microsoft.ml.onnxruntime.1.20.1.nupkg"
    if [[ ! -f "$archive" ]]; then
        fetch 'https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/1.20.1/microsoft.ml.onnxruntime.1.20.1.nupkg'
        mv "$stage/download" "$archive"
    fi
    verify "$archive" 9c32108e9a1c78b090a95c2a219f244dd5f067d4caf68fb0f967103f3f20839c
    library="$stage/libonnxruntime.1.20.1.dylib"
    python3 -B - "$archive" "$library" <<'PY'
from pathlib import Path
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    Path(sys.argv[2]).write_bytes(archive.read('runtimes/osx-arm64/native/libonnxruntime.dylib'))
PY
else
    verify "$archive" "$sha"
    tar xzf "$archive" -C "$stage"
    library="$stage/$name/lib/libonnxruntime.1.20.1.dylib"
fi
verify "$library" "$library_sha"
target="$root/third_party/onnxruntime/osx-$arch"
mkdir -p "$target"
target_partial="$(mktemp "$target/.onnxruntime.XXXXXX")"
cp "$library" "$target_partial"
chmod 755 "$target_partial"
mv -f "$target_partial" "$target/libonnxruntime.1.20.1.dylib"
target_partial=''
