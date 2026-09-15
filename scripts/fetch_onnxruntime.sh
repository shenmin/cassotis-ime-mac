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
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
        "https://github.com/microsoft/onnxruntime/releases/download/v1.20.1/$name.tgz" \
        -o "$archive.part"
    mv "$archive.part" "$archive"
fi
actual="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
[[ "$actual" == "$sha" ]] || { echo 'ONNX Runtime checksum mismatch' >&2; exit 1; }
tar xzf "$archive" -C "$cache"
mkdir -p "$root/third_party/onnxruntime/osx-$arch"
cp "$cache/$name/lib/libonnxruntime.1.20.1.dylib" \
    "$root/third_party/onnxruntime/osx-$arch/"
