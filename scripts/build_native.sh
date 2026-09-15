#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
ort="$root/third_party/onnxruntime/osx-$arch"
bin="$root/build/$arch/bin"
mkdir -p "$bin"
if [[ ! -f "$ort/libonnxruntime.1.20.1.dylib" ]]; then
    "$root/scripts/fetch_onnxruntime.sh"
fi
printf '[C++ %s] ONNX bridge\n' "$arch"
# Match the Windows MSVC 2022+ default: round multiply and add separately.
# Clang's default contracts expressions on arm64 even without fast-math.
xcrun clang++ -arch "$arch" -mmacosx-version-min=14.0 -std=c++20 -O2 -g \
    -Wall -Wextra -Werror -ffp-contract=off -fvisibility=hidden -dynamiclib -pthread \
    -I"$root/third_party/onnxruntime/include" \
    "$root/src/host/native/nc_pinyin_transformer_ort.cpp" \
    "$ort/libonnxruntime.1.20.1.dylib" \
    -Wl,-install_name,@rpath/libcassotis_ort.dylib \
    -Wl,-rpath,@loader_path -o "$bin/libcassotis_ort.dylib"
cp "$ort/libonnxruntime.1.20.1.dylib" "$bin/"
# Sign both libraries before bundle assembly; the linker's initial signature
# differs from codesign's application signature.
for library in libcassotis_ort.dylib libonnxruntime.1.20.1.dylib; do
    codesign --force --sign - "$bin/$library"
done
for name in pinyin_transformer local_completion local_repair; do
    ln -sfn "$root/data/models/$name" "$bin/$name"
done
