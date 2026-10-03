#!/bin/bash
# Verifiserer CellProtocol-endringen (query-credential på dedikert bro).
set -u
WT=/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/_wt-bridge-credential-20260830
LOG=/Users/kjetil/Build/Digipomps/HAVEN/Binding/_audit-skeleton-render-20260828/logs/cellprotocol-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$(dirname "$LOG")"
cd "$WT" || exit 1
{
  echo "START $(date -u +%H:%M:%SZ)  worktree=$WT"
  echo "== swift build (CellBase) =="
  swift build --target CellBase 2>&1 | tail -40
  echo "BUILD_EXIT=${PIPESTATUS[0]}"
  echo "== swift test --filter DedicatedBridgeConnectionURL =="
  swift test --filter DedicatedBridgeConnectionURL 2>&1 | tail -40
  echo "TEST_EXIT=${PIPESTATUS[0]}"
  echo "DONE $(date -u +%H:%M:%SZ)"
} | tee "$LOG"
echo "LOG: $LOG"
