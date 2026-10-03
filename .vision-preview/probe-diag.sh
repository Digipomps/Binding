#!/bin/bash
OUT="/Users/kjetil/Build/Digipomps/HAVEN/Binding/.vision-preview"
UDID=60A4509A-5AD0-42B9-A1D0-7CEBA044F514
{
echo "===== APP-CONTAINER: finnes Perspective.json? ====="
CONT=$(xcrun simctl get_app_container "$UDID" org.digipomps.haven data 2>/dev/null)
echo "CONTAINER=$CONT"
find "$CONT/Library/Application Support/Binding" -name "*.json" 2>/dev/null | head -30
echo "--- antall filer i CellsContainer ---"
find "$CONT/Library/Application Support/Binding/CellDocumentRoot" -type f 2>/dev/null | wc -l
find "$CONT/Library/Application Support/Binding/CellDocumentRoot" -type f 2>/dev/null | head -20

echo "===== LOG STREAM UNDER OPPSTART ====="
xcrun simctl terminate "$UDID" org.digipomps.haven 2>/dev/null
sleep 2
xcrun simctl spawn "$UDID" log stream --level debug --style compact \
  --predicate 'processImagePath CONTAINS "HAVEN"' > "$OUT/oslog.txt" 2>&1 &
LOGPID=$!
sleep 3
xcrun simctl launch "$UDID" org.digipomps.haven
sleep 30
kill $LOGPID 2>/dev/null
echo "--- oslog linjer: ---"
wc -l "$OUT/oslog.txt"
grep -iE "denied|timeout|perspective|security|activePurpose" "$OUT/oslog.txt" | head -40
} > "$OUT/probe-diag.log" 2>&1
echo DONE > "$OUT/probe-diag-status.txt"
