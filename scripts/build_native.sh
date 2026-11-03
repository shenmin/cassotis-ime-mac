#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
ort="$root/third_party/onnxruntime/osx-$arch"
bin="$root/build/$arch/bin"
mkdir -p "$bin"
python3 -B "$root/scripts/char_lm_model_parts.py" "$root/data/models/char_lm"
rm -f "$bin/short_context" "$bin/pinyin_transformer" "$bin/local_completion" "$bin/local_repair"
if [[ ! -f "$ort/libonnxruntime.1.20.1.dylib" ]]; then
    "$root/scripts/fetch_onnxruntime.sh"
fi
printf '[C++ %s] ONNX bridge\n' "$arch"
attention="$root/src/host/native/nc_trie_attention_arm64.cpp"
attention_flags=(-fno-fast-math)
if [[ "$arch" == x86_64 ]]; then
    attention="$root/src/host/native/nc_trie_attention_avx2.cpp"
    attention_flags=(-fno-fast-math -mavx2 -mfma)
fi
attention_object="$root/build/$arch/trie_attention.o"
xcrun clang++ -arch "$arch" -mmacosx-version-min=14.0 -std=c++20 -O2 -g \
    -Wall -Wextra -Werror -ffp-contract=off -fvisibility=hidden "${attention_flags[@]}" \
    -c "$attention" -o "$attention_object"
# Match the Windows MSVC 2022+ default: round multiply and add separately.
# Clang's default contracts expressions on arm64 even without fast-math.
xcrun clang++ -arch "$arch" -mmacosx-version-min=14.0 -std=c++20 -O2 -g \
    -Wall -Wextra -Werror -ffp-contract=off -fvisibility=hidden -dynamiclib -pthread \
    -I"$root/third_party/onnxruntime/include" \
    "$root/src/host/native/nc_char_lm_ort.cpp" "$attention_object" \
    "$ort/libonnxruntime.1.20.1.dylib" \
    -Wl,-install_name,@rpath/libcassotis_ort.dylib \
    -Wl,-rpath,@loader_path -o "$bin/libcassotis_ort.dylib"
cp "$ort/libonnxruntime.1.20.1.dylib" "$bin/"
# Apply consistent ad hoc signatures before bundle assembly. The
# linker's initial signature differs from codesign's application signature.
for library in libcassotis_ort.dylib libonnxruntime.1.20.1.dylib; do
    codesign --force --sign - "$bin/$library"
done
ln -sfn "$root/data/models/char_lm" "$bin/char_lm"
