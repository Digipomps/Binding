#!/bin/bash
OUT="/Users/kjetil/Build/Digipomps/HAVEN/Binding/.vision-preview"
UDID=60A4509A-5AD0-42B9-A1D0-7CEBA044F514
xcrun simctl terminate "$UDID" org.digipomps.haven 2>/dev/null
sleep 2
xcrun simctl launch "$UDID" org.digipomps.haven
sleep 35
xcrun simctl io "$UDID" screenshot "$OUT/haven-final-01.png"
sleep 25
xcrun simctl io "$UDID" screenshot "$OUT/haven-final-02.png"
echo DONE > "$OUT/shot-status.txt"
