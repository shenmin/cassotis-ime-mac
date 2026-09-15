#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
identity=''
profile=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity) identity="$2"; shift;;
        --notary-profile) profile="$2"; shift;;
        --help|-h) echo 'Usage: scripts/package.sh [--identity DEVELOPER_ID --notary-profile KEYCHAIN_PROFILE]'; exit 0;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
    shift
done
[[ -z "$profile" || -n "$identity" ]] || { echo 'Notarization requires a Developer ID identity.' >&2; exit 2; }
version="$(tr -d '\r\n' < "$root/VERSION")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
bundle_build="$(tr -d '\r\n' < "$root/BUILD_NUMBER")"
[[ "$bundle_build" =~ ^[1-9][0-9]*$ ]] || exit 2
app="$root/build/$arch/Cassotis.app"
codesign --verify --deep --strict "$app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" && \
   "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$bundle_build" ]] || {
    echo 'Application version/build differs; rebuild the app before packaging.' >&2; exit 1;
}
[[ "$("$app/Contents/MacOS/cassotis-engine" --version)" == "$version" ]] || { echo 'Engine version mismatch.' >&2; exit 1; }
mkdir -p "$root/dist"
stage="$(mktemp -d "$root/build/package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
name="Cassotis-$version-macos-$arch"
[[ -n "$identity" ]] || name="$name-local"
if [[ -n "$identity" && -z "$profile" ]]; then name="$name-signed"; fi
package="$stage/$name"
mkdir -p "$package/scripts" "$package/tools"
ditto "$app" "$package/Cassotis.app"
cp "$root/scripts/install.sh" "$root/scripts/uninstall.sh" "$package/scripts/"
cp "$root/build/$arch/bin/cassotis-input-source" "$package/tools/"
cp "$root/LICENSE" "$root/NOTICE.md" "$root/VERSION" "$root/BUILD_NUMBER" "$root/CONFIGURATION.md" "$package/"
cp "$root/resources/Install.command" "$package/Install.command"
cp "$root/resources/Uninstall.command" "$package/Uninstall.command"
sed "s/@VERSION@/$version/g" "$root/resources/INSTALL.txt" >"$package/INSTALL.txt"
chmod +x "$package/"*.command "$package/scripts/"*.sh
if [[ -n "$identity" ]]; then
    for binary in "$package/Cassotis.app/Contents/Frameworks/"*.dylib \
        "$package/Cassotis.app/Contents/MacOS/Cassotis" "$package/Cassotis.app/Contents/MacOS/cassotis-engine" \
        "$package/tools/cassotis-input-source"; do
        codesign --force --options runtime --timestamp --sign "$identity" "$binary"
    done
    codesign --force --options runtime --timestamp --sign "$identity" "$package/Cassotis.app"
fi
codesign --verify --deep --strict "$package/Cassotis.app"
archive="$root/dist/$name.zip"
ditto -c -k --sequesterRsrc --keepParent "$package" "$archive.partial.zip"
if [[ -n "$profile" ]]; then
    xcrun notarytool submit "$archive.partial.zip" --keychain-profile "$profile" --wait \
        --output-format json >"$root/dist/$name-notarization.json"
    python3 -B - "$root/dist/$name-notarization.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']=='Accepted', 'Notarization was not accepted'
PY
    xcrun stapler staple "$package/Cassotis.app"
    xcrun stapler validate "$package/Cassotis.app"
    spctl --assess --type execute --verbose=2 "$package/Cassotis.app"
    ditto -c -k --sequesterRsrc --keepParent "$package" "$archive.partial.zip"
fi
mv "$archive.partial.zip" "$archive"
(cd "$root/dist" && shasum -a 256 "$name.zip") >"$archive.sha256"
printf 'Package: %s\n' "$archive"

# The primary end-user download is a normal disk image with a native installer.
# The ZIP remains available for command-line deployment and regression tooling.
image_root="$stage/disk-image"
installer="$image_root/安装言泉输入法.app"
"$root/scripts/build_installer.sh" "$installer"
ditto "$package" "$installer/Contents/Resources/Payload"
if [[ -n "$identity" ]]; then
    codesign --force --options runtime --timestamp --sign "$identity" "$installer/Contents/MacOS/CassotisInstaller"
    codesign --force --options runtime --timestamp --sign "$identity" "$installer"
else
    codesign --force --sign - "$installer"
fi
codesign --verify --deep --strict "$installer"
sed "s/@VERSION@/$version/g" "$root/resources/DMG-README.txt" >"$image_root/安装说明.txt"
disk_image="$root/dist/$name.dmg"
hdiutil create -quiet -ov -volname "言泉输入法 $version" -fs HFS+ -format UDZO \
    -srcfolder "$image_root" "$stage/package.dmg"
if [[ -n "$identity" ]]; then
    codesign --force --timestamp --sign "$identity" "$stage/package.dmg"
fi
if [[ -n "$profile" ]]; then
    xcrun notarytool submit "$stage/package.dmg" --keychain-profile "$profile" --wait \
        --output-format json >"$root/dist/$name-dmg-notarization.json"
    python3 -B - "$root/dist/$name-dmg-notarization.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']=='Accepted', 'Disk image notarization was not accepted'
PY
    xcrun stapler staple "$stage/package.dmg"
    xcrun stapler validate "$stage/package.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$stage/package.dmg"
fi
mv "$stage/package.dmg" "$disk_image"
(cd "$root/dist" && shasum -a 256 "$name.dmg") >"$disk_image.sha256"
printf 'Graphical installer: %s\n' "$disk_image"
