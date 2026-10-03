#!/bin/bash
# Kompileringssjekk for visionOS uten simulator-runtime.
set -x
REPO="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$REPO/.vision-preview"
cd "$REPO" || exit 1
echo "STATUS=compiling" > "$OUT/compile-status.txt"
date >> "$OUT/compile-status.txt"
{
xcodebuild build \
  -project Binding.xcodeproj \
  -scheme HAVEN \
  -configuration Debug \
  -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath /tmp/HavenVisionCompileDD \
  CODE_SIGNING_ALLOWED=NO
echo "RC=$?"
} > "$OUT/compile.log" 2>&1
grep -c "error:" "$OUT/compile.log" > "$OUT/error-count.txt"
tail -3 "$OUT/compile.log" >> "$OUT/compile-status.txt"
echo "STATUS=done" >> "$OUT/compile-status.txt"
date >> "$OUT/compile-status.txt"
