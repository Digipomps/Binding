#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/HavenAgentD"
RUNTIME_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/haven-agentd-smoke.XXXXXX")"
MODULE_CACHE_DIR="$PACKAGE_DIR/.tmp-clang-module-cache"

cleanup() {
  rm -rf "$RUNTIME_ROOT"
}
trap cleanup EXIT

mkdir -p "$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

cd "$PACKAGE_DIR"
swift test
swift build --product haven-agentd
"$PACKAGE_DIR/.build/debug/haven-agentd" smoke-test --root "$RUNTIME_ROOT"
