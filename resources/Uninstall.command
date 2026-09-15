#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd -P)"
exec "$root/scripts/uninstall.sh"
