#!/bin/zsh
# Runs the HAVEN surface audit (RemoteSurfaceRenderAuditXCTest) on macOS and
# logs everything under _audit-skeleton-render-20260828/logs. Settings live in
# audit-settings.json next to this script; the report lands in reports/.
set -uo pipefail
ROOT="/Users/kjetil/Build/Digipomps/HAVEN/Binding"
OUT="$ROOT/_audit-skeleton-render-20260828"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$OUT/logs/xcodebuild-$STAMP.log"
mkdir -p "$OUT/logs" "$OUT/reports"
cd "$ROOT"
echo "START $STAMP pid=$$" > "$LOG"
BINDING_ENABLE_CONFERENCE_DEMO_MENUS=1 \
TEST_RUNNER_BINDING_ENABLE_CONFERENCE_DEMO_MENUS=1 \
TEST_RUNNER_BINDING_SURFACE_AUDIT_OUTPUT_DIR="$OUT/reports" \
xcodebuild \
  -project Binding.xcodeproj \
  -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -only-testing:BindingTests/RemoteSurfaceRenderAuditXCTest \
  "$@" 2>&1 | tee -a "$LOG"
STATUS=${pipestatus[1]}
echo "EXIT=$STATUS" | tee -a "$LOG"
echo "DONE $(date +%Y%m%d-%H%M%S)" | tee -a "$LOG"
exit $STATUS
