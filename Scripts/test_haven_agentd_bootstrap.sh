#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/HavenAgentD"
CONFIG_PATH="${1:-$HOME/Library/Application Support/HAVENAgent/config.json}"
MODULE_CACHE_DIR="$PACKAGE_DIR/.tmp-clang-module-cache"

shift $(( $# > 0 ? 1 : 0 ))
EXTRA_ARGS=("$@")

mkdir -p "$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

cd "$PACKAGE_DIR"
swift build --product haven-agentd
"$PACKAGE_DIR/.build/debug/haven-agentd" bootstrap-probe --config "$CONFIG_PATH" --run-bootstrap "${EXTRA_ARGS[@]}"
