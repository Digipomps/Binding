#!/usr/bin/env bash
#
# notarize_pkg.sh — submit a signed .pkg to Apple notary, wait, staple, verify.
#
# Usage:
#   Packaging/notarize_pkg.sh dist/HAVENAgentD-0.1.0-arm64.pkg
#
# Requires a stored notarytool keychain profile (one-time setup):
#   xcrun notarytool store-credentials "DIGIPOMPS_NOTARY" \
#     --apple-id "kjetil.hustveit@digipomps.org" \
#     --team-id "5UT5HQTCV9" \
#     --password "<app-specific-password>"
#
# Override the profile name with NOTARY_PROFILE.
#
set -euo pipefail

PKG="${1:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-DIGIPOMPS_NOTARY}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -n "$PKG" && -f "$PKG" ]] || die "Usage: notarize_pkg.sh <signed-pkg>"

log "Submitting to Apple notary (profile: $NOTARY_PROFILE) — this uploads the pkg"
xcrun notarytool submit "$PKG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

log "Stapling notarization ticket onto the pkg"
xcrun stapler staple "$PKG"

log "Validating staple + Gatekeeper install assessment"
xcrun stapler validate "$PKG"
spctl --assess --type install -vvv "$PKG"

echo
log "Notarized + stapled: $PKG"
echo "This pkg now passes Gatekeeper on a clean Mac. Distribute via GitHub"
echo "Releases (private repo) or direct transfer; updates can later flow"
echo "through the staging scaffold + sprout-updater policy path."
