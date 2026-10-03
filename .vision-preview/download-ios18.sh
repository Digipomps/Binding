#!/bin/bash
set -x
OUT="/Users/kjetil/Build/Digipomps/HAVEN/Binding/.vision-preview"
echo "STATUS=downloading" > "$OUT/ios18-status.txt"
date >> "$OUT/ios18-status.txt"
{
echo "===== INSTALLERTE RUNTIMES FØR ====="
xcrun simctl runtime list

echo "===== FORSØK NEDLASTING ====="
for V in 18.6 18.5 18.4 18.2 18.0; do
  echo "--- prøver iOS $V ---"
  if xcodebuild -downloadPlatform iOS -buildVersion "$V"; then
    echo "OK: iOS $V lastet ned"
    echo "DOWNLOADED=$V" >> "$OUT/ios18-status.txt"
    break
  else
    echo "feilet for $V"
  fi
done

echo "===== INSTALLERTE RUNTIMES ETTER ====="
xcrun simctl runtime list
xcrun simctl list devices available | grep -i -A8 "iOS 18"
} > "$OUT/ios18-download.log" 2>&1
echo "STATUS=done" >> "$OUT/ios18-status.txt"
date >> "$OUT/ios18-status.txt"
