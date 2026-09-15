#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
app="$root/build/$arch/Cassotis.app"
bin="$root/build/$arch/bin"
version="$(tr -d '\r\n' < "$root/VERSION")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
bundle_build="$(tr -d '\r\n' < "$root/BUILD_NUMBER")"
[[ "$bundle_build" =~ ^[1-9][0-9]*$ ]] || { echo 'BUILD_NUMBER must be a positive integer.' >&2; exit 2; }
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks" \
    "$app/Contents/Resources/dictionaries" "$app/Contents/Resources/licenses" "$root/build/$arch/symbols"
printf '[AppKit %s] Cassotis\n' "$arch"
xcrun clang++ -arch "$arch" -mmacosx-version-min=14.0 -std=c++20 -O2 -g \
    -fobjc-arc -Wall -Wextra -Werror -Wno-deprecated-declarations \
    -framework AppKit -framework InputMethodKit -framework Carbon \
    "$root/src/macos/EngineClient.cpp" "$root/src/macos/CandidatePanel.mm" \
    "$root/src/macos/InputSession.mm" "$root/src/macos/SettingsController.mm" \
    "$root/src/macos/CandidateAppearance.mm" "$root/src/macos/ShortcutRecorder.mm" \
    "$root/src/macos/main.mm" -o "$app/Contents/MacOS/Cassotis"
if [[ -d "$app/Contents/MacOS/Cassotis.dSYM" ]]; then
    rm -rf "$root/build/$arch/symbols/Cassotis.dSYM"
    mv "$app/Contents/MacOS/Cassotis.dSYM" "$root/build/$arch/symbols/"
fi
cp "$bin/cassotis-engine" "$app/Contents/MacOS/"
cp "$bin/libcassotis_ort.dylib" "$bin/libonnxruntime.1.20.1.dylib" "$app/Contents/Frameworks/"
rsync -a --delete "$root/data/models/" "$app/Contents/Resources/models/"
cp "$root/build/dictionaries/dict_sc.db" "$root/build/dictionaries/dict_tc.db" "$app/Contents/Resources/dictionaries/"
cp "$root/resources/Info.plist" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundle_build" "$app/Contents/Info.plist"
rm -f "$app/Contents/Resources/CassotisInputSource.pdf"
cp "$root/resources/Cassotis.png" "$root/resources/CassotisInputSource.tiff" "$app/Contents/Resources/"
rsync -a "$root/third_party/lexicon/" "$app/Contents/Resources/licenses/lexicon/"
rsync -a "$root/third_party/macbert/" "$app/Contents/Resources/licenses/macbert/"
rsync -a "$root/third_party/freepascal/" "$app/Contents/Resources/licenses/freepascal/"
cp "$root/LICENSE" "$app/Contents/Resources/licenses/Cassotis.txt"
cp "$root/third_party/onnxruntime/LICENSE" "$app/Contents/Resources/licenses/ONNXRuntime.txt"
cp "$root/third_party/onnxruntime/ThirdPartyNotices.txt" "$app/Contents/Resources/licenses/ONNXRuntime-ThirdPartyNotices.txt"
for binary in "$app/Contents/Frameworks/"*.dylib "$app/Contents/MacOS/Cassotis" "$app/Contents/MacOS/cassotis-engine"; do
    codesign --force --sign - "$binary"
done
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
cmp "$bin/cassotis-engine" "$app/Contents/MacOS/cassotis-engine"
for library in libcassotis_ort.dylib libonnxruntime.1.20.1.dylib; do
    cmp "$bin/$library" "$app/Contents/Frameworks/$library"
done
printf 'Application built: %s\n' "$app"

xcrun clang++ -arch "$arch" -mmacosx-version-min=14.0 -std=c++20 -O2 -g \
    -fobjc-arc -Wall -Wextra -Werror -framework AppKit -framework Carbon \
    "$root/tools/control/input_source.mm" -o "$bin/cassotis-input-source"
