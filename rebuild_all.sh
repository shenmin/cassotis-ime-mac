#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd -P)"
exec "$root/scripts/rebuild_all.sh" "$@"
