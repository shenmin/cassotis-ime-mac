#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
control="$root/build/${CASSOTIS_ARCH:-arm64}/bin/cassotis-input-source"
if [[ -d "$root/Cassotis.app" ]]; then control="$root/tools/cassotis-input-source"; fi
app="$HOME/Library/Input Methods/Cassotis.app"
[[ $# -eq 0 || ( $# -eq 1 && "$1" == --require-disabled ) ]] || { echo 'Usage: uninstall.sh [--require-disabled]' >&2; exit 2; }
[[ ! -L "$app" ]] || { echo 'Application path is a symlink.' >&2; exit 1; }
[[ -d "$app" ]] || { echo '当前用户尚未安装言泉输入法。'; exit 0; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == org.cassotis.inputmethod.Cassotis ]] || {
    echo 'Refusing to remove a different application at Cassotis.app.' >&2; exit 1;
}
if [[ "${1:-}" == --require-disabled ]]; then
    source_status="$("$control" status || true)"
    if [[ "$source_status" == *' enabled=1 '* ]]; then
        echo '请先在“系统设置 → 键盘 → 文字输入 → 编辑”中移除言泉输入法，再点击重试卸载。' >&2
        exit 3
    fi
fi
"$control" prepare-update
# User enablement belongs to System Settings. Disabling through TIS can alter
# menu ordering even when macOS refuses the protected preference write.
backup="$HOME/Library/Application Support/CassotisIME/Backups/Uninstalled-$(date +%Y%m%d-%H%M%S)-$(uuidgen).app"
mkdir -p "$(dirname "$backup")"
mv "$app" "$backup"
printf 'Uninstalled. Application backup: %s\nUser dictionary and preferences were retained.\n' "$backup"
printf '如果系统设置的输入源列表中仍有言泉输入法，请选中它并点击“-”移除该输入源。\n'
