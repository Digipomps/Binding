#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Policy is JSON data, never shell input: do not source/eval it.
exec /usr/bin/python3 "$ROOT_DIR/Scripts/apple_release_m0_preflight.py" "$@"
