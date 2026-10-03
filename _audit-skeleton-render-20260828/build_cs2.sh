#!/bin/bash
set -u
WT=/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/_wt-bridge-identity-20260830
DIR=/Users/kjetil/Build/Digipomps/HAVEN/Binding/_audit-skeleton-render-20260828/logs
mkdir -p "$DIR"
RAW="$DIR/cs-raw-$(date +%Y%m%d-%H%M%S).txt"
SUM="$DIR/cs-sum-$(date +%Y%m%d-%H%M%S).txt"
cd "$WT" || exit 1
swift build --target App > "$RAW" 2>&1
EXIT=$?
{
  echo "BUILD_EXIT=$EXIT"
  echo "== ekte kompileringsfeil =="
  grep -E "^/.*\.swift:[0-9]+:[0-9]+: error:" "$RAW" | head -30
  echo "count=$(grep -cE '^/.*\.swift:[0-9]+:[0-9]+: error:' "$RAW")"
  echo "== VaporCellBridge kompilert? =="
  grep -n "VaporCellBridge" "$RAW" | head -5
  echo "== sluttlinjer =="
  tail -6 "$RAW"
  echo "DONE $(date -u +%H:%M:%SZ)"
} | tee "$SUM"
echo "RAW: $RAW"
echo "SUM: $SUM"
