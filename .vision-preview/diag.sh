#!/bin/bash
OUT="/Users/kjetil/Build/Digipomps/HAVEN/Binding/.vision-preview"
UDID=60A4509A-5AD0-42B9-A1D0-7CEBA044F514
xcrun simctl terminate "$UDID" org.digipomps.haven 2>/dev/null
sleep 2
( xcrun simctl launch --console-pty "$UDID" org.digipomps.haven > "$OUT/app-console.log" 2>&1 ) &
LP=$!
sleep 45
kill $LP 2>/dev/null
xcrun simctl io "$UDID" screenshot "$OUT/haven-ios18-03.png"
echo DONE > "$OUT/diag-status.txt"
