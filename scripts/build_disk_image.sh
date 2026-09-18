#!/usr/bin/env bash
# Assemble a Finder disk image with its own Retina background and saved layout.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
[[ $# -eq 3 ]] || { echo 'Usage: scripts/build_disk_image.sh SOURCE OUTPUT.dmg VOLUME_NAME' >&2; exit 2; }
source_dir="$1"
output="$2"
volume_name="$3"
[[ -d "$source_dir/言泉输入法安装器.app" && -f "$source_dir/安装说明.txt" ]] || {
    echo 'Disk image source must contain the installer and installation guide.' >&2; exit 2;
}
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 2; }
# Finder stores the backing image's path in its alias. Use an anonymous system
# temporary directory so no developer checkout/home path enters the artifact.
work="$(mktemp -d /tmp/cassotis-dmg.XXXXXX)"
mounted=false
cleanup() {
    if $mounted; then
        # Do not remove a mounted directory if Finder or another process holds it.
        if ! hdiutil detach -quiet "$work/mount"; then
            echo "Could not detach temporary image; retained at $work" >&2
            return
        fi
    fi
    rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$source_dir/.background" "$work/mount"
cp "$root/resources/DMG-background.tiff" "$source_dir/.background/background.tiff"
hdiutil create -quiet -volname "$volume_name" -fs HFS+ -format UDRW \
    -srcfolder "$source_dir" "$work/writable.dmg"
hdiutil attach -quiet -readwrite -nobrowse -noautoopen -mountpoint "$work/mount" "$work/writable.dmg"
mounted=true
# Finder creates a volume-relative background alias on the actual image.
# A logged-in macOS desktop is required for this packaging step.
osascript "$root/scripts/layout_dmg.applescript" "$work/mount"
[[ -s "$work/mount/.DS_Store" ]] || { echo 'Finder did not save the disk image layout.' >&2; exit 1; }
sync
hdiutil detach -quiet "$work/mount"
mounted=false
hdiutil convert -quiet -format UDZO -o "$output" "$work/writable.dmg"
printf 'Disk image layout: %s\n' "$output"
