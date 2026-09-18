#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
arch="${CASSOTIS_ARCH:-arm64}"
source_app="$root/build/$arch/Cassotis.app"
destination="$HOME/Library/Input Methods/Cassotis.app"
control="$root/build/$arch/bin/cassotis-input-source"
if [[ -d "$root/Cassotis.app" ]]; then
    source_app="$root/Cassotis.app"
    control="$root/tools/cassotis-input-source"
fi
[[ -d "$source_app" ]] || "$root/scripts/build.sh"
codesign --verify --deep --strict "$source_app"
[[ ! -L "$destination" ]] || { echo 'Installed application path is a symlink.' >&2; exit 1; }
if [[ -d "$destination" ]]; then
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")" == org.cassotis.inputmethod.Cassotis ]] || {
        echo 'Refusing to replace a different application at Cassotis.app.' >&2; exit 1;
    }
fi
mkdir -p "$HOME/Library/Input Methods"
staging="$(mktemp -d "$HOME/Library/Input Methods/.cassotis-install.XXXXXX")"
backup=''
installed=0
previous_source="$("$control" current)"
cleanup() {
    local status=$?
    if [[ $status -ne 0 ]]; then
        if [[ $installed -ne 0 ]]; then
            # Registration-only did not enable or disable any input source.
            # Preserve the user's state and menu order when restoring the app.
            "$control" prepare-update >/dev/null || true
            mv "$destination" "$staging/failed.app"
        fi
        if [[ -n "$backup" && -d "$backup" ]]; then
            mv "$backup" "$destination"
            "$control" register-only "$destination" >/dev/null || true
            "$control" launch >/dev/null || true
        fi
    fi
    if [[ -n "$previous_source" ]]; then "$control" select-id "$previous_source" >/dev/null || true; fi
    rm -rf "$staging"
    return "$status"
}
trap cleanup EXIT
# Deploy the verified files without inheriting the download's extended
# attributes. --noqtn alone still copies an explicit quarantine xattr on macOS.
# Inheriting it would translocate the input method away from its registered path.
ditto --noextattr --noqtn "$source_app" "$staging/Cassotis.app"
codesign --verify --deep --strict "$staging/Cassotis.app"
"$control" prepare-update
if [[ -d "$destination" ]]; then
    backup="$HOME/Library/Application Support/CassotisIME/Backups/Cassotis-$(date +%Y%m%d-%H%M%S)-$(uuidgen).app"
    mkdir -p "$(dirname "$backup")"
    mv "$destination" "$backup"
    printf 'Previous application backed up to %s\n' "$backup"
fi
mv "$staging/Cassotis.app" "$destination"
installed=1
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$destination"
"$control" register-only "$destination"
# Finish LaunchServices verification of the new executable before restoring
# the input source. macOS can discard a first key while launching a replacement
# input method; the frontend can buffer keys once its IMK server is running.
"$control" launch
printf 'Installed: %s\n' "$destination"
cat <<'INSTRUCTIONS'
应用文件已安装。请完成 macOS 的输入法启用确认：
打开“系统设置 → 键盘 → 文字输入 → 编辑”。
若输入源列表中没有言泉输入法，点击“+”，在“中文（简体）”中添加。
按 macOS 的提示确认允许使用言泉输入法。
若列表中已有言泉输入法，但输入菜单中没有，请在系统设置中移除该输入源后重新添加。
完成系统确认后，从菜单栏的输入菜单选择言泉输入法；选中时显示彩色言泉 logo。
Installed files alone do not complete macOS input-source approval.
INSTRUCTIONS
