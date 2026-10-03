#!/bin/bash
REPO="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$REPO/.vision-preview"
DD="/tmp/HavenIOS18Signed"
UDID=60A4509A-5AD0-42B9-A1D0-7CEBA044F514
cd "$REPO" || exit 1
echo "STATUS=building" > "$OUT/fix-status.txt"
{
xcodebuild build -project Binding.xcodeproj -scheme HAVEN -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DD" 2>&1 | grep -E "error:|warning: .*Perspective|BUILD (SUCCEEDED|FAILED)" | head -30
echo "BUILD_RC=${PIPESTATUS[0]}"
} > "$OUT/fix-build.log" 2>&1
if ! grep -q "BUILD SUCCEEDED" "$OUT/fix-build.log"; then
  echo "STATUS=build_failed" > "$OUT/fix-status.txt"; exit 1
fi
APP="$DD/Build/Products/Debug-iphonesimulator/HAVEN.app"
xcrun simctl terminate "$UDID" org.digipomps.haven 2>/dev/null
xcrun simctl uninstall "$UDID" org.digipomps.haven 2>/dev/null
xcrun simctl install "$UDID" "$APP"
echo "STATUS=run1" > "$OUT/fix-status.txt"
( xcrun simctl launch --console-pty "$UDID" org.digipomps.haven --haven-runtime-diagnostics > "$OUT/fix-run1.log" 2>&1 ) &
P=$!; sleep 45; xcrun simctl io "$UDID" screenshot "$OUT/fix-run1.png"; sleep 3; kill $P 2>/dev/null
echo "STATUS=run2" > "$OUT/fix-status.txt"
sleep 3
( xcrun simctl launch --console-pty "$UDID" org.digipomps.haven --haven-runtime-diagnostics > "$OUT/fix-run2.log" 2>&1 ) &
P=$!; sleep 45; xcrun simctl io "$UDID" screenshot "$OUT/fix-run2.png"; sleep 3; kill $P 2>/dev/null
echo "STATUS=done" > "$OUT/fix-status.txt"
