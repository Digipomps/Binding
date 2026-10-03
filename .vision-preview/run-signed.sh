#!/bin/bash
set -x
REPO="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$REPO/.vision-preview"
DD="/tmp/HavenIOS18Signed"
UDID=60A4509A-5AD0-42B9-A1D0-7CEBA044F514
cd "$REPO" || exit 1
echo "STATUS=building_signed" > "$OUT/signed-status.txt"; date >> "$OUT/signed-status.txt"
{
# Bygg MED signering slik at entitlements faktisk embeddes i simulator-appen
xcodebuild build -project Binding.xcodeproj -scheme HAVEN -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DD" 2>&1 | tail -200
RC=${PIPESTATUS[0]}
echo "BUILD_RC=$RC"
[ "$RC" -ne 0 ] && { echo "STATUS=build_failed" > "$OUT/signed-status.txt"; exit 1; }

APP="$DD/Build/Products/Debug-iphonesimulator/HAVEN.app"
echo "===== ENTITLEMENTS I BINÆREN ====="
codesign -d --entitlements :- "$APP" 2>&1 | head -40

xcrun simctl terminate "$UDID" org.digipomps.haven 2>/dev/null
xcrun simctl uninstall "$UDID" org.digipomps.haven 2>/dev/null
xcrun simctl install "$UDID" "$APP"
( xcrun simctl launch --console-pty "$UDID" org.digipomps.haven > "$OUT/app-console-signed.log" 2>&1 ) &
LP=$!
sleep 40
kill $LP 2>/dev/null
xcrun simctl io "$UDID" screenshot "$OUT/haven-signed-01.png"
sleep 25
xcrun simctl io "$UDID" screenshot "$OUT/haven-signed-02.png"
echo "STATUS=done" > "$OUT/signed-status.txt"
} > "$OUT/signed-build.log" 2>&1
date >> "$OUT/signed-status.txt"
