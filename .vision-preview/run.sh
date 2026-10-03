#!/bin/bash
# HAVEN visionOS preview runner. Skrevet av Claude 2026-08-19.
# Bygger HAVEN for visionOS Simulator, installerer, starter og tar skjermbilder.
set -x
REPO="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$REPO/.vision-preview"
DD="/tmp/HavenVisionDerivedData"
cd "$REPO" || exit 1

echo "STATUS=starting" > "$OUT/status.txt"
date >> "$OUT/status.txt"

{
echo "===== SCHEMES ====="
xcodebuild -project Binding.xcodeproj -list

echo "===== SIM RUNTIMES ====="
xcrun simctl list runtimes | grep -i vision

echo "===== SIM DEVICES ====="
xcrun simctl list devices available | grep -i -B2 -A6 vision

echo "===== RESOLVE DEVICE ====="
UDID=$(xcrun simctl list devices available -j \
  | python3 -c 'import json,sys
d=json.load(sys.stdin)["devices"]
for rt,devs in d.items():
    if "xrOS" in rt or "visionOS" in rt:
        for x in devs:
            if x.get("isAvailable"):
                print(x["udid"]); raise SystemExit
')
echo "UDID=$UDID"
if [ -z "$UDID" ]; then
  echo "Ingen visionOS-simulator funnet. Prøver å opprette."
  RT=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys
for r in json.load(sys.stdin)["runtimes"]:
    if r.get("isAvailable") and ("xrOS" in r["identifier"] or "visionOS" in r["identifier"]):
        print(r["identifier"]); raise SystemExit
')
  echo "RT=$RT"
  UDID=$(xcrun simctl create "HAVEN Vision Preview" "Apple Vision Pro" "$RT")
  echo "CREATED UDID=$UDID"
fi

echo "===== BOOT ====="
xcrun simctl boot "$UDID" || true
open -a Simulator || true
sleep 20

echo "STATUS=building" > "$OUT/status.txt"
echo "===== BUILD ====="
xcodebuild build \
  -project Binding.xcodeproj \
  -scheme HAVEN \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO \
  -parallelizeTargets
BUILD_RC=$?
echo "BUILD_RC=$BUILD_RC"

if [ "$BUILD_RC" -ne 0 ]; then
  echo "STATUS=build_failed" > "$OUT/status.txt"
  exit 1
fi

echo "===== INSTALL ====="
APP=$(find "$DD/Build/Products" -maxdepth 3 -name "*.app" -type d | head -1)
echo "APP=$APP"
xcrun simctl install "$UDID" "$APP"

echo "===== LAUNCH ====="
xcrun simctl launch "$UDID" org.digipomps.haven
sleep 25
xcrun simctl io "$UDID" screenshot "$OUT/haven-vision-01.png"
sleep 15
xcrun simctl io "$UDID" screenshot "$OUT/haven-vision-02.png"
echo "STATUS=done" > "$OUT/status.txt"
} > "$OUT/build.log" 2>&1
date >> "$OUT/status.txt"
