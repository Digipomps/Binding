#!/bin/zsh
set -euo pipefail

PROJECT="/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding.xcodeproj"
SCHEME="Binding"
DESTINATION="platform=macOS"

surface="${1:-all}"
layer="${2:-all}"
identity_mode_arg="${3:-${BINDING_VERIFIER_IDENTITY_MODE:-startup}}"
signing_mode_arg="${4:-${BINDING_VERIFIER_SIGNED:-unsigned}}"
local_runtime_only_flag="/tmp/binding-verifier-local-runtime.flag"

typeset -a tests
typeset -a COMMON_ARGS

case "${identity_mode_arg:l}" in
  startup|local)
    verifier_identity_mode="startup"
    ;;
  test|deterministic)
    verifier_identity_mode="test"
    ;;
  apple|signed-apple|keychain)
    verifier_identity_mode="apple"
    ;;
  *)
    echo "Unknown verifier identity mode: $identity_mode_arg" >&2
    echo "Expected one of: startup, test, apple" >&2
    exit 64
    ;;
esac

case "${signing_mode_arg:l}" in
  signed|1|yes|true)
    verifier_signed_mode=1
    ;;
  unsigned|0|no|false)
    verifier_signed_mode=0
    ;;
  *)
    echo "Unknown verifier signing mode: $signing_mode_arg" >&2
    echo "Expected one of: unsigned, signed" >&2
    exit 64
    ;;
esac

COMMON_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -disableAutomaticPackageResolution
)

if [[ "$verifier_signed_mode" -eq 0 ]]; then
  COMMON_ARGS+=(CODE_SIGNING_ALLOWED=NO)
fi

COMMON_ARGS+=(test)

cleanup() {
  rm -f "$local_runtime_only_flag"
}
trap cleanup EXIT

if [[ "$verifier_identity_mode" == "startup" || "$verifier_identity_mode" == "test" ]]; then
  touch "$local_runtime_only_flag"
else
  rm -f "$local_runtime_only_flag"
fi

add_test() {
  tests+=("$1")
}

case "$surface" in
  launcher|demo)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherCanOpenIdentityLinkSetup"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherCanOpenPublicSurfaceAndControlTower"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherCanOpenParticipantCockpitChatAndAIAssistant"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherRenderer"
    ;;
  identity|setup|identity-link)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceIdentityLinkContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceIdentityLinkImportAndReviewFlow"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceIdentityLinkRenderer"
    ;;
  ai|assistant|copilot)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceAIAssistantContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceAIAssistantButtonsUpdateDraftAndSessionKeyViaRendererExecutionPath"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceAIAssistantRenderer"
    ;;
  public)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferencePublicSurfaceContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferencePublicSurfaceRenderer"
    ;;
  sponsor)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceSponsorFollowUpContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceSponsorFollowUpRenderer"
    ;;
  participant)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantNearbyFollowUpContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalSearchGovernanceButtonUsesRendererExecutionPath"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalProxyActionsCanOpenChatWorkbench"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatWorkbenchWarmsThreadFromSelectedParticipant"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalRenderer"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatRenderer"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarRenderer"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileRenderer"
    ;;
  chat)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatRenderer"
    ;;
  nearby|radar|profile)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract"
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarRenderer"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileRenderer"
    ;;
  admin|organizer|control-tower)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerContract"
    [[ "$layer" == "render" || "$layer" == "all" ]] && add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerRenderer"
    ;;
  all)
    [[ "$layer" == "contract" || "$layer" == "all" ]] && {
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherCanOpenIdentityLinkSetup"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherCanOpenPublicSurfaceAndControlTower"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherCanOpenParticipantCockpitChatAndAIAssistant"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceIdentityLinkContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceIdentityLinkImportAndReviewFlow"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalSearchGovernanceButtonUsesRendererExecutionPath"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalProxyActionsCanOpenChatWorkbench"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatWorkbenchWarmsThreadFromSelectedParticipant"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantNearbyFollowUpContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceAIAssistantContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceAIAssistantButtonsUpdateDraftAndSessionKeyViaRendererExecutionPath"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferencePublicSurfaceContract"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceSponsorFollowUpContract"
    }
    [[ "$layer" == "render" || "$layer" == "all" ]] && {
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceDemoLauncherRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceIdentityLinkRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceAIAssistantRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferencePublicSurfaceRenderer"
      add_test "BindingTests/CellConfigurationVerifierXCTest/testConferenceSponsorFollowUpRenderer"
    }
    ;;
  *)
    echo "Usage: $0 [demo|launcher|identity|setup|ai|assistant|public|sponsor|participant|chat|nearby|profile|admin|all] [contract|render|all] [startup|test|apple] [unsigned|signed]" >&2
    exit 64
    ;;
esac

if [[ "${#tests[@]}" -eq 0 ]]; then
  echo "No tests selected." >&2
  exit 64
fi

echo "Running conference configuration verifier:"
printf '  %s\n' "${tests[@]}"
echo "Verifier identity mode: $verifier_identity_mode"
if [[ "$verifier_signed_mode" -eq 1 ]]; then
  echo "Code signing: enabled"
else
  echo "Code signing: disabled"
fi

for test_name in "${tests[@]}"; do
  echo
  echo "==> $test_name"
  BINDING_VERIFIER_IDENTITY_MODE="$verifier_identity_mode" \
    xcodebuild "${COMMON_ARGS[@]}" -only-testing:"$test_name"
done
