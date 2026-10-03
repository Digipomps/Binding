#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

xcodebuild \
  -workspace Binding.xcworkspace \
  -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' \
  build \
  "$@"

# Skriv ut hvor produktet faktisk havnet. Uten dette er det lett å starte feil
# app-bundle fra en gammel DerivedData-mappe og tro at bygget ikke virket.
xcodebuild \
  -workspace Binding.xcworkspace \
  -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print "App: " $2 "/HAVEN.app"; exit}'
