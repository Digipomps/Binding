#!/bin/zsh
set -euo pipefail

ROOT="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
MODE="${1:-all}"
OUT_DIR="${2:-/tmp/binding-skeleton-parity-$(date +%Y%m%d-%H%M%S)}"
PROJECT="$ROOT/Binding.xcodeproj"
SCHEME="Binding"
DESTINATION="platform=macOS"
REMOTE_SENTINEL="/tmp/binding-enable-remote-parity.flag"

mkdir -p "$OUT_DIR"

run_remote_contract() {
  local label="$1"
  local log_name="$2"
  shift 2

  echo "==> $label"
  touch "$REMOTE_SENTINEL"
  set +e
  BINDING_ENABLE_REMOTE_PARITY=1 \
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "$DESTINATION" \
      -disableAutomaticPackageResolution \
      CODE_SIGNING_ALLOWED=NO \
      test \
      "$@" | tee "$OUT_DIR/$log_name"
  local parity_status=${pipestatus[1]}
  set -e
  rm -f "$REMOTE_SENTINEL"
  return "$parity_status"
}

run_remote_http_contract() {
  BINDING_REMOTE_PARITY_SKIP_BRIDGE=1 \
    run_remote_contract \
      "Remote staging fixture HTTP parity" \
      "remote-http-contract.log" \
      -only-testing:BindingTests/SkeletonParityRemoteXCTest \
      -skip-testing:BindingTests/SkeletonParityRemoteXCTest/testBridgeBackedFixtureResolvesThroughBindingAndExecutesAction
}

run_remote_bridge_contract() {
  run_remote_contract \
    "Remote staging bridge parity canary" \
    "remote-bridge-contract.log" \
    -only-testing:BindingTests/SkeletonParityRemoteXCTest/testBridgeBackedFixtureResolvesThroughBindingAndExecutesAction
}

run_remote_full_contract() {
  run_remote_contract \
    "Remote staging fixture parity" \
    "remote-contract.log" \
    -only-testing:BindingTests/SkeletonParityRemoteXCTest
}

run_local() {
  echo "==> Local skeleton verifier"
  zsh "$ROOT/Scripts/run_conference_configuration_verifier.sh" all all | tee "$OUT_DIR/local-verifier.log"
}

run_remote() {
  run_remote_full_contract
  echo "==> Remote staging smoke"
  zsh "$ROOT/Scripts/run_conference_demo_smoke.sh" "$OUT_DIR/remote-smoke" | tee "$OUT_DIR/remote-smoke.log"
}

case "$MODE" in
  local)
    run_local
    ;;
  remote)
    run_remote
    ;;
  remote-http)
    run_remote_http_contract
    ;;
  remote-bridge)
    run_remote_bridge_contract
    ;;
  remote-contract)
    run_remote_full_contract
    ;;
  all)
    run_local
    run_remote
    ;;
  *)
    echo "Usage: $0 [local|remote-http|remote-bridge|remote-contract|remote|all] [output-dir]" >&2
    exit 64
    ;;
esac

echo
echo "Skeleton parity suite complete."
echo "Output: $OUT_DIR"
