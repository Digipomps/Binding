#!/bin/bash
set -x
REPO="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$REPO/.vision-preview"
DD="/tmp/HavenIOS18DD"
cd "$REPO" || exit 1
echo "STATUS=starting" > "$OUT/ios18-run-status.txt"; date >> "$OUT/ios18-run-status.txt"
{
echo "===== FINN iOS 18-ENHET ====="
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
best=None
for rt,devs in d.items():
    if "iOS-18" not in rt: continue
    for x in devs:
        if x.get("isAvailable") and "iPhone" in x["name"]:
            best=x["udid"]
            if "16" in x["name"] or "15" in x["name"]: 
                print(best); raise SystemExit
if best: print(best)
')
echo "UDID=$UDID"
if [ -z "$UDID" ]; then
  RT=$(xcrun simctl list runtimes -j | python3 -c '
import json,sys
for r in json.load(sys.stdin)["runtimes"]:
    if r.get("isAvailable") and "iOS-18" in r["identifier"]:
        print(r["identifier"]); raise SystemExit
')
  echo "RT=$RT"
  DT=$(xcrun simctl list devicetypes -j | python3 -c '
import json,sys
for d in json.load(sys.stdin)["devicetypes"]:
    if d["name"]=="iPhone 16 Pro": print(d["identifier"]); raise SystemExit
' )
  [ -z "$DT" ] && DT="com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
  UDID=$(xcrun simctl create "HAVEN iOS18" "$DT" "$RT")
  echo "CREATED=$UDID"
fi
[ -z "$UDID" ] && { echo "STATUS=no_device" > "$OUT/ios18-run-status.txt"; exit 1; }

echo "===== BOOT ====="
xcrun simctl bootstatus "$UDID" -b || xcrun simctl boot "$UDID" || true
open -a Simulator || true
sleep 15

echo "STATUS=building" > "$OUT/ios18-run-status.txt"
echo "===== BUILD (iOS 18, deployment target 18.0) ====="
xcodebuild build \
  -project Binding.xcodeproj -scheme HAVEN -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -400
RC=${PIPESTATUS[0]}
echo "BUILD_RC=$RC"
if [ "$RC" -ne 0 ]; then echo "STATUS=build_failed" > "$OUT/ios18-run-status.txt"; exit 1; fi

echo "===== INSTALL + LAUNCH ====="
APP=$(find "$DD/Build/Products" -maxdepth 3 -name "*.app" -type d | head -1)
echo "APP=$APP"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" org.digipomps.haven
sleep 30
xcrun simctl io "$UDID" screenshot "$OUT/haven-ios18-01.png"
sleep 20
xcrun simctl io "$UDID" screenshot "$OUT/haven-ios18-02.png"
echo "STATUS=done" > "$OUT/ios18-run-status.txt"
} > "$OUT/ios18-run.log" 2>&1
date >> "$OUT/ios18-run-status.txt"
