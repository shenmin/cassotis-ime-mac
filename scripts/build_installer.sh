#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
app="${1:-$root/build/$arch/言泉输入法安装器.app}"
version="$(tr -d '\r\n' < "$root/VERSION")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
bundle_build="$(tr -d '\r\n' < "$root/BUILD_NUMBER")"
[[ "$bundle_build" =~ ^[1-9][0-9]*$ ]] || { echo 'BUILD_NUMBER must be a positive integer.' >&2; exit 2; }
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun clang++ -arch "$arch" -mmacosx-version-min=14.0 -std=c++20 -O2 \
    -fobjc-arc -Wall -Wextra -Werror -Wno-deprecated-declarations -framework AppKit -framework Carbon \
    "$root/src/installer/InstallerController.mm" "$root/src/installer/InputSourceRegistration.mm" "$root/src/installer/main.mm" \
    -o "$app/Contents/MacOS/CassotisInstaller"
cp "$root/resources/Installer-Info.plist" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundle_build" "$app/Contents/Info.plist"
cp "$root/resources/Cassotis.png" "$app/Contents/Resources/"
codesign --force --sign - "$app"
printf 'Installer built: %s\n' "$app"
