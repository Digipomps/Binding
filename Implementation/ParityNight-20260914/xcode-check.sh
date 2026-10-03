#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

set -euo pipefail

WORKSPACE="${1:-CellScaffold.xcworkspace}"
SCHEME="${2:-Run}"
CONFIGURATION="${3:-Debug}"
DESTINATION="${4:-platform=macOS}"
MODE="${5:-clean-build}"
LOG_DIR="${LOG_DIR:-.xcode-logs}"
DERIVED_DATA_PATH="${HAVEN_XCODE_DERIVED_DATA_PATH:-/private/tmp/haven-xcode-derived/CellScaffold}"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/xcode-${MODE}-latest.log"
: > "$LOG_FILE"

usage() {
  cat <<'EOF'
Usage:
  scripts/xcode-check.sh [workspace] [scheme] [configuration] [destination] [mode]

Defaults:
  workspace:     CellScaffold.xcworkspace
  scheme:        Run
  configuration: Debug
  destination:   platform=macOS
  mode:          clean-build

Modes:
  resolve      Resolve package dependencies only
  clean        Clean only
  build        Build only
  clean-build  Clean and then build
EOF
}

run_with_log() {
  echo "+ $*" | tee -a "$LOG_FILE"
  set -o pipefail
  "$@" 2>&1 | tee -a "$LOG_FILE"
}

echo "Workspace:      $WORKSPACE"
echo "Scheme:         $SCHEME"
echo "Configuration:  $CONFIGURATION"
echo "Destination:    $DESTINATION"
echo "Mode:           $MODE"
echo "DerivedData:    $DERIVED_DATA_PATH"
echo "Log:            $LOG_FILE"
echo

"$(cd "$(dirname "$0")" && pwd)/check_build_capacity.sh" .

case "$MODE" in
  resolve)
    run_with_log xcodebuild -derivedDataPath "$DERIVED_DATA_PATH" -resolvePackageDependencies -workspace "$WORKSPACE" -scheme "$SCHEME"
    ;;
  clean)
    run_with_log xcodebuild -derivedDataPath "$DERIVED_DATA_PATH" -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "$DESTINATION" clean
    ;;
  build)
    run_with_log xcodebuild -jobs 2 -derivedDataPath "$DERIVED_DATA_PATH" -project "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "$DESTINATION" \
      -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
      CONFIGURATION_BUILD_DIR=/private/tmp/haven-parity-products \
      PRODUCT_BUNDLE_IDENTIFIER=org.digipomps.haven.parity-night-test \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS= ENABLE_APP_SANDBOX=NO \
      'TOOLCHAIN_DIR=$(DT_TOOLCHAIN_DIR)' build
    ;;
  ios-build)
    run_with_log xcodebuild -jobs 2 -derivedDataPath "$DERIVED_DATA_PATH" -project "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "$DESTINATION" \
      -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
      CONFIGURATION_BUILD_DIR=/private/tmp/haven-parity-ios-products \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
      'TOOLCHAIN_DIR=$(DT_TOOLCHAIN_DIR)' build
    ;;
  ios-ui-tests)
    run_with_log xcodebuild -jobs 2 -derivedDataPath "$DERIVED_DATA_PATH" -project "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "$DESTINATION" \
      -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
      -testPlan HAVEN-Parity-UI -parallel-testing-enabled NO -only-testing:"${HAVEN_PARITY_UI_SELECTION:-BindingUITests/ParityNightUITests}" \
      -resultBundlePath "$LOG_DIR/parity-ui-tests.xcresult" \
      CONFIGURATION_BUILD_DIR=/private/tmp/haven-parity-ios-products \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
      'TOOLCHAIN_DIR=$(DT_TOOLCHAIN_DIR)' test
    ;;
  parity-tests)
    run_with_log xcodebuild -jobs 2 -derivedDataPath "$DERIVED_DATA_PATH" -project "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "$DESTINATION" \
      -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
      -parallel-testing-enabled NO \
      -only-testing:BindingTests/ParityNightRegressionTests \
      -only-testing:BindingTests/SkeletonRendererParityTests \
      -resultBundlePath "$LOG_DIR/parity-tests.xcresult" \
      CONFIGURATION_BUILD_DIR=/private/tmp/haven-parity-products \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS= ENABLE_APP_SANDBOX=NO \
      'TOOLCHAIN_DIR=$(DT_TOOLCHAIN_DIR)' test
    ;;
  clean-build)
    run_with_log xcodebuild -derivedDataPath "$DERIVED_DATA_PATH" -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "$DESTINATION" clean build
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    exit 2
    ;;
esac

echo
echo "Done. Full log: $LOG_FILE"
