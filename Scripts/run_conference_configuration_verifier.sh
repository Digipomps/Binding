#!/bin/zsh
set -euo pipefail

PROJECT="/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding.xcodeproj"
SCHEME="Binding"
DESTINATION="platform=macOS"
COMMON_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -disableAutomaticPackageResolution
  CODE_SIGNING_ALLOWED=NO
  test
)

surface="${1:-all}"
layer="${2:-all}"

typeset -a tests

add_test() {
  tests+=("$1")
}

case "$surface" in
  participant)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantNearbyFollowUpContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalRenderer"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarRenderer"
    ;;
  nearby|radar)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarRenderer"
    ;;
  admin|organizer|control-tower)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerRenderer"
    ;;
  all)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && {
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantNearbyFollowUpContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerContract"
    }
    [[ "$layer" == "render" || "$layer" == "all" ]] && {
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerRenderer"
    }
    ;;
  *)
    echo "Usage: $0 [participant|nearby|admin|all] [contract|render|all]" >&2
    exit 64
    ;;
esac

if [[ "${#tests[@]}" -eq 0 ]]; then
  echo "No tests selected." >&2
  exit 64
fi

echo "Running conference configuration verifier:"
printf '  %s\n' "${tests[@]}"

for test_name in "${tests[@]}"; do
  echo
  echo "==> $test_name"
  xcodebuild "${COMMON_ARGS[@]}" -only-testing:"$test_name"
done
