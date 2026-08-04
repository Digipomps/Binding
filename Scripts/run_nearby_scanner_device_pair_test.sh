#!/usr/bin/env bash
set -euo pipefail

PHONE_DEVICE_ID="${PHONE_DEVICE_ID:-2A446771-99B8-5EB2-B384-07A156FB3107}"
IPAD_DEVICE_ID="${IPAD_DEVICE_ID:-90C8A134-0A1A-5026-8C21-0DA21DC67AA8}"
BUNDLE_ID="${BUNDLE_ID:-org.digipomps.havenplayground}"
DEEP_LINK="${DEEP_LINK:-haven://conference-automation?action=open-nearby-scanner}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"
ENABLE_CONFERENCE_AUTOMATION="${ENABLE_CONFERENCE_AUTOMATION:-1}"
CONFERENCE_AUTOMATION_DEEPLINK_ARGUMENT="${CONFERENCE_AUTOMATION_DEEPLINK_ARGUMENT:---enable-conference-automation-deeplinks}"
POST_LAUNCH_SETTLE_SECONDS="${POST_LAUNCH_SETTLE_SECONDS:-6}"

usage() {
  cat <<USAGE
Usage: $(basename "$0")

Installs HAVEN on the configured phone and iPad, then opens the nearby scanner
deep link on both devices. Devices must be unlocked before launch.

Environment:
  APP_PATH         Path to HAVEN.app. Defaults to newest Debug-iphoneos build.
  PHONE_DEVICE_ID devicectl ID for the phone.
  IPAD_DEVICE_ID  devicectl ID for the iPad.
  BUNDLE_ID        App bundle id. Default: ${BUNDLE_ID}
  DEEP_LINK        Scanner deep link. Default: ${DEEP_LINK}
  SKIP_INSTALL     Set to 1 to skip install and only launch.
  ENABLE_CONFERENCE_AUTOMATION
                   Set to 0 to omit the conference automation deep-link launch argument.
  CONFERENCE_AUTOMATION_DEEPLINK_ARGUMENT
                   Launch argument used to opt into automation deep links without verifier runtime.
  POST_LAUNCH_SETTLE_SECONDS
                   Seconds to wait before checking that HAVEN is still running. Default: ${POST_LAUNCH_SETTLE_SECONDS}
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 64
    ;;
esac

newest_haven_app() {
  local roots=(
    "/private/tmp/BindingNearbyDeviceDD"
    "${HOME}/Library/Developer/Xcode/DerivedData"
  )

  find "${roots[@]}" \
    -path "*/Build/Products/Debug-iphoneos/HAVEN.app" \
    -type d \
    -print0 |
    xargs -0 stat -f "%m %N" |
    sort -rn |
    head -n 1 |
    cut -d " " -f 2-
}

APP_PATH="${APP_PATH:-$(newest_haven_app)}"

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "No Debug-iphoneos HAVEN.app found. Build HAVEN for a physical iOS device first." >&2
  exit 1
fi

echo "Nearby scanner device-pair test"
echo "App: ${APP_PATH}"
echo "Phone: ${PHONE_DEVICE_ID}"
echo "iPad: ${IPAD_DEVICE_ID}"
echo

if [[ "${SKIP_INSTALL}" == "1" ]]; then
  echo "Skipping install because SKIP_INSTALL=1"
else
  for device in "${PHONE_DEVICE_ID}" "${IPAD_DEVICE_ID}"; do
    echo "Installing on ${device}"
    xcrun devicectl device install app --device "${device}" "${APP_PATH}"
  done
fi

for device in "${PHONE_DEVICE_ID}" "${IPAD_DEVICE_ID}"; do
  echo "Launching nearby scanner on ${device}"
  launch_args=()
  if [[ "${ENABLE_CONFERENCE_AUTOMATION}" == "1" ]]; then
    launch_args+=("${CONFERENCE_AUTOMATION_DEEPLINK_ARGUMENT}")
  fi
  if ! xcrun devicectl device process launch \
      --device "${device}" \
      --terminate-existing \
      --payload-url "${DEEP_LINK}" \
      "${BUNDLE_ID}" \
      "${launch_args[@]}"; then
    echo "Launch failed on ${device}; retrying once after CoreDevice settles" >&2
    sleep 3
    xcrun devicectl device process launch \
      --device "${device}" \
      --terminate-existing \
      --payload-url "${DEEP_LINK}" \
      "${BUNDLE_ID}" \
      "${launch_args[@]}"
  fi
done

if [[ "${POST_LAUNCH_SETTLE_SECONDS}" != "0" ]]; then
  echo "Waiting ${POST_LAUNCH_SETTLE_SECONDS}s for post-launch stability"
  sleep "${POST_LAUNCH_SETTLE_SECONDS}"
fi

process_check_failed=0
for device in "${PHONE_DEVICE_ID}" "${IPAD_DEVICE_ID}"; do
  echo "Checking HAVEN process on ${device}"
  if xcrun devicectl device info processes --device "${device}" | grep -q "HAVEN.app/HAVEN"; then
    echo "OK: HAVEN is still running on ${device}"
  else
    echo "FAIL: HAVEN is not running on ${device}" >&2
    process_check_failed=1
  fi
done

if [[ "${process_check_failed}" != "0" ]]; then
  echo "Nearby scanner launch stability check failed." >&2
  exit "${process_check_failed}"
fi

echo
echo "Manual acceptance checklist:"
echo "1. On both devices, confirm HAVEN is open on Entity Scanner / Nearby Scanner."
echo "2. Tap Start scanner on both devices."
echo "3. Accept Bluetooth, Local Network, and Nearby Interaction prompts if shown."
echo "4. Verify scanner.status is running/active on both devices."
echo "5. Verify scanner.capabilities shows the available transport mode."
echo "6. Verify scanner.found shows the other device, then create/accept contact if prompted."
echo "7. Verify scanner.connected and scanner.encounter.saved/exported/jsonExported update after pairing."
echo
echo "Known separate blocker: staging notification registration may show HTTP 401 Invalid device callback ingress capability; that is not required for local nearby scanning."
