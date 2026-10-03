#!/bin/bash
set -u
WT=/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/_wt-bridge-credential-20260830
LOG=/Users/kjetil/Build/Digipomps/HAVEN/Binding/_audit-skeleton-render-20260828/logs/cp2-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$(dirname "$LOG")"
cd "$WT" || exit 1
{
  echo "== A: en test som fantes fra før (isolerer om harnessen i det hele tatt kjører) =="
  swift test --filter testBridgeCommandRoundTripStringPayload 2>&1 | grep -v "warning:" | grep -v "^ *[0-9]* |" | grep -v "^ *|" | tail -25
  echo "A_EXIT=${PIPESTATUS[0]}"
  echo
  echo "== B: mine to nye tester =="
  swift test --filter DedicatedBridgeConnectionURL 2>&1 | grep -v "warning:" | grep -v "^ *[0-9]* |" | grep -v "^ *|" | tail -30
  echo "B_EXIT=${PIPESTATUS[0]}"
  echo "DONE $(date -u +%H:%M:%SZ)"
} 2>&1 | tee "$LOG"
echo "LOG: $LOG"
