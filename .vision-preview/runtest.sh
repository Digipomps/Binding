#!/bin/bash
REPO="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$REPO/.vision-preview"
cd "$REPO" || exit 1
echo "STATUS=testing" > "$OUT/test-status.txt"
xcodebuild -project Binding.xcodeproj -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/HavenMacTestDD \
  test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testEveryOfferedCatalogConfigurationHasReadableRoots \
  > "$OUT/test-run.log" 2>&1
echo "RC=$?" >> "$OUT/test-status.txt"
echo "STATUS=done" >> "$OUT/test-status.txt"
