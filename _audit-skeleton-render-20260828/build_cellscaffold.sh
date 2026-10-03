#!/bin/bash
set -u
WT=/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/_wt-bridge-identity-20260830
LOG=/Users/kjetil/Build/Digipomps/HAVEN/Binding/_audit-skeleton-render-20260828/logs/cellscaffold-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$(dirname "$LOG")"
cd "$WT" || exit 1
{
  echo "START $(date -u +%H:%M:%SZ)"
  swift build --target App 2>&1 \
    | grep -v "warning:" | grep -v "^ *[0-9]* |" | grep -v "^ *|" | grep -v "^ *\^" | tail -60
  echo "BUILD_EXIT=${PIPESTATUS[0]}"
  echo "DONE $(date -u +%H:%M:%SZ)"
} 2>&1 | tee "$LOG"
echo "LOG: $LOG"
