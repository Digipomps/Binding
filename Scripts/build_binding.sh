#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"
python3 scripts/prepare_binding_provenance_inputs.py

xcodebuild \
  -project Binding.xcodeproj \
  -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' \
  build \
  "$@"
