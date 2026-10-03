#!/bin/bash
set -u
DIR=/Users/kjetil/Build/Digipomps/HAVEN/Binding/_audit-skeleton-render-20260828/logs
mkdir -p "$DIR"
OUT="$DIR/regression-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "=== CellProtocol: hele BridgeTests (sikrer at endringen ikke brakk noe) ==="
  cd /Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/_wt-bridge-credential-20260830 || exit 1
  swift test --filter BridgeTests 2>&1 | grep -E "^Test Suite|^Test Case.*(passed|failed)|error:|Executed [0-9]+ test" | tail -25
  echo "CP_BRIDGE_EXIT=${PIPESTATUS[0]}"
  echo
  echo "=== CellProtocol: CellRuntimeEnvironmentTests (rører samme provider) ==="
  swift test --filter CellRuntimeEnvironmentTests 2>&1 | grep -E "Executed [0-9]+ test|error:" | tail -6
  echo "CP_ENV_EXIT=${PIPESTATUS[0]}"
  echo "DONE $(date -u +%H:%M:%SZ)"
} 2>&1 | tee "$OUT"
echo "OUT: $OUT"
