#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
command -v python3 >/dev/null 2>&1 || { printf 'python3 is required. Install it with: sudo apt install python3\n' >&2; exit 1; }
exec python3 "$SCRIPT_DIR/app.py"
