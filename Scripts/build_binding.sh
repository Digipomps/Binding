#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

xcodebuild \
  -project Binding.xcodeproj \
  -scheme Binding \
  -destination 'platform=macOS,arch=arm64' \
  build \
  "$@"
