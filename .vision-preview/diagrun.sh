#!/bin/bash
set -x
REPO="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$REPO/.vision-preview"
DD="/tmp/HavenIOS18Signed"
UDID=60A4509A-5AD0-42B9-A1D0-7CEBA044F514
cd "$REPO" || exit 1
echo "STATUS=building" > "$OUT/diagrun-status.txt"
{
xcodebuild build -project Binding.xcodeproj -scheme HAVEN -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DD" 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -30
RC=${PIPESTATUS[0]}
echo "BUILD_RC=$RC"
[ "$RC" -ne 0 ] && { echo "STATUS=build_failed" > "$OUT/diagrun-status.txt"; exit 1; }
APP="$DD/Build/Products/Debug-iphonesimulator/HAVEN.app"
xcrun simctl terminate "$UDID" org.digipomps.haven 2>/dev/null
xcrun simctl uninstall "$UDID" org.digipomps.haven 2>/dev/null
xcrun simctl install "$UDID" "$APP"
echo "===== KJØRING 1 (ren install) ====="
( xcrun simctl launch --console-pty "$UDID" org.digipomps.haven --haven-runtime-diagnostics > "$OUT/diag-run1.log" 2>&1 ) &
P=$!; sleep 40; kill $P 2>/dev/null
echo "===== KJØRING 2 (varm, samme container) ====="
sleep 3
( xcrun simctl launch --console-pty "$UDID" org.digipomps.haven --haven-runtime-diagnostics > "$OUT/diag-run2.log" 2>&1 ) &
P=$!; sleep 40; kill $P 2>/dev/null
echo "STATUS=done" > "$OUT/diagrun-status.txt"
} > "$OUT/diagrun.log" 2>&1
