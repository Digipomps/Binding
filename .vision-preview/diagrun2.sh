#!/bin/bash
OUT="/Users/kjetil/Build/Digipomps/HAVEN/Binding/.vision-preview"
UDID=60A4509A-5AD0-42B9-A1D0-7CEBA044F514
xcrun simctl terminate "$UDID" org.digipomps.haven 2>/dev/null
sleep 2
( xcrun simctl launch --console-pty "$UDID" org.digipomps.haven --haven-runtime-diagnostics > "$OUT/diag-long.log" 2>&1 ) &
P=$!
sleep 75
xcrun simctl io "$UDID" screenshot "$OUT/diag-long.png"
sleep 5
kill $P 2>/dev/null
echo DONE > "$OUT/diaglong-status.txt"
