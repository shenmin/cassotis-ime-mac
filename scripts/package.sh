#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
identity=''
profile=''
allow_unnotarized=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity) identity="$2"; shift;;
        --notary-profile) profile="$2"; shift;;
        --allow-unnotarized) allow_unnotarized=true;;
        --help|-h) echo 'Usage: scripts/package.sh [--identity DEVELOPER_ID --notary-profile KEYCHAIN_PROFILE] [--allow-unnotarized (development only)]'; exit 0;;
        *) echo "Unknown argument: $1" >&2; exit 2;;
    esac
    shift
done
[[ -z "$profile" || -n "$identity" ]] || { echo 'Notarization requires a Developer ID identity.' >&2; exit 2; }
if [[ -n "$identity" && -z "$profile" ]] && ! $allow_unnotarized; then
    echo 'Developer ID release packages require --notary-profile PROFILE.' >&2
    echo 'For signing-only development checks, explicitly pass --allow-unnotarized.' >&2
    exit 2
fi
if [[ -n "$profile" ]]; then
    # Fail before creating package copies if the account is not configured.
    xcrun notarytool history --keychain-profile "$profile" --output-format json >/dev/null
fi
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
archive_partial=''
cleanup() {
    rm -rf "$stage"
    [[ -z "$archive_partial" ]] || rm -f "$archive_partial"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
notarize() {
    local artifact="$1" result="$2" submission_id
    xcrun notarytool submit "$artifact" --keychain-profile "$profile" --wait \
        --output-format json >"$result"
    submission_id="$(python3 -B - "$result" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))['id'])
PY
)"
    # Keep Apple's diagnostic log even when the submission was rejected.
    xcrun notarytool log "$submission_id" --keychain-profile "$profile" "${result%.json}-log.json"
    python3 -B - "$result" <<'PY'
import json,sys
result = json.load(open(sys.argv[1]))
assert result['status'] == 'Accepted', f"Notarization was not accepted: {result['status']} ({result['id']})"
PY
}
ticket_action() {
    local action="$1" target="$2" output status attempt
    for attempt in 1 2 3 4 5; do
        if output="$(xcrun stapler "$action" "$target" 2>&1)"; then
            printf '%s\n' "$output"
            return 0
        else
            status=$?
            printf '%s\n' "$output" >&2
        fi
        # Retry Apple's transient network failures; never accept an invalid or
        # missing ticket, and never disable TLS certificate verification.
        if [[ "$status" -eq 68 && "$output" == *NSURLErrorDomain* && "$attempt" -lt 5 ]]; then
            echo 'Retrying Apple ticket service after a network error.' >&2
            sleep "$((1 << attempt))"
        else
            return "$status"
        fi
    done
}
suffix=''
[[ -n "$identity" ]] || suffix='-local'
if [[ -n "$identity" && -z "$profile" ]]; then suffix='-signed'; fi
name="Cassotis-$version-macos-$arch$suffix"
# Keep the release DMG name stable even when notarization is enabled.
image_suffix='-local'
[[ -z "$identity" ]] || image_suffix='-signed'
image_name="cassotis-ime-macos-$version-$arch-installer$image_suffix"
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
archive_partial="$archive.partial.zip"
ditto -c -k --sequesterRsrc --keepParent "$package" "$archive_partial"
if [[ -n "$profile" ]]; then
    notarize "$archive_partial" "$root/dist/$name-notarization.json"
    ticket_action staple "$package/Cassotis.app"
    ticket_action validate "$package/Cassotis.app"
    spctl --assess --type execute --verbose=2 "$package/Cassotis.app"
    syspolicy_check distribution "$package/Cassotis.app"
    ditto -c -k --sequesterRsrc --keepParent "$package" "$archive_partial"
fi
mv "$archive_partial" "$archive"
(cd "$root/dist" && shasum -a 256 "$name.zip") >"$archive.sha256"
printf 'Package: %s\n' "$archive"

# The primary end-user download is a normal disk image with a native installer.
# The ZIP remains available for command-line deployment and regression tooling.
image_root="$stage/disk-image"
installer="$image_root/言泉输入法安装器.app"
"$root/scripts/build_installer.sh" "$installer"
ditto "$package" "$installer/Contents/Resources/Payload"
if [[ -n "$identity" ]]; then
    codesign --force --options runtime --timestamp --sign "$identity" "$installer/Contents/MacOS/CassotisInstaller"
    codesign --force --options runtime --timestamp --sign "$identity" "$installer"
else
    codesign --force --sign - "$installer"
fi
codesign --verify --deep --strict "$installer"
if [[ -n "$profile" ]]; then
    # The installer must carry its own ticket before the final image is sealed.
    installer_archive="$stage/installer.zip"
    ditto -c -k --sequesterRsrc --keepParent "$installer" "$installer_archive"
    notarize "$installer_archive" "$root/dist/$name-installer-notarization.json"
    rm -f "$installer_archive"
    ticket_action staple "$installer"
    ticket_action validate "$installer"
    spctl --assess --type execute --verbose=2 "$installer"
    syspolicy_check distribution "$installer"
fi
sed "s/@VERSION@/$version/g" "$root/resources/DMG-README.txt" >"$image_root/安装说明.txt"
disk_image="$root/dist/$image_name.dmg"
"$root/scripts/build_disk_image.sh" "$image_root" "$stage/package.dmg" "言泉输入法安装器 $version"
if [[ -n "$identity" ]]; then
    codesign --force --timestamp --sign "$identity" "$stage/package.dmg"
fi
if [[ -n "$profile" ]]; then
    notarize "$stage/package.dmg" "$root/dist/$name-dmg-notarization.json"
    ticket_action staple "$stage/package.dmg"
    ticket_action validate "$stage/package.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$stage/package.dmg"
    spctl --assess --type execute --verbose=2 "$installer"
fi
mv "$stage/package.dmg" "$disk_image"
(cd "$root/dist" && shasum -a 256 "$image_name.dmg") >"$disk_image.sha256"
printf 'Graphical installer: %s\n' "$disk_image"
