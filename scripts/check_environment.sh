#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS is required.' >&2; exit 1; }
[[ "${CASSOTIS_ARCH:-arm64}" == arm64 ]] || { echo 'This release supports arm64.' >&2; exit 1; }
fpc="$(command -v "${CASSOTIS_FPC_BIN:-fpc}" || true)"
[[ -n "$fpc" && -x "$fpc" ]] || { echo 'Free Pascal 3.2.2 is required; set CASSOTIS_FPC_BIN to its executable.' >&2; exit 1; }
[[ "$("$fpc" -iV)" == 3.2.2 ]] || { echo 'Free Pascal 3.2.2 is required.' >&2; exit 1; }
xcrun --find clang++ >/dev/null
xcrun --find swift >/dev/null
python3 -B -c 'import hashlib, sys; assert sys.version_info >= (3, 11), "Python 3.11 or newer is required for build tools"; assert hasattr(hashlib, "file_digest")'
for command in codesign ditto rsync sqlite3; do command -v "$command" >/dev/null; done
printf 'Build environment ready: FPC %s, %s, arm64\n' "$("$fpc" -iV)" "$(xcodebuild -version | head -1)"
