#!/usr/bin/env bash
#
# build_pkg.sh — build, sign, and package HavenAgentD into a Developer ID
# signed component .pkg. Notarization is a separate step (notarize_pkg.sh).
#
# Output (under dist/, override with DIST_DIR):
#   dist/HAVENAgentD-<version>-<arch>.pkg   signed, ready to notarize
#   dist/SHA256SUMS                          hashes of the staged binaries
#   dist/release-manifest.json               artifact/version/arch/signing metadata
#
# Required signing identities in the login keychain:
#   "Developer ID Application: Stiftelsen Digipomps (5UT5HQTCV9)"  (binaries)
#   "Developer ID Installer: Stiftelsen Digipomps (5UT5HQTCV9)"    (.pkg)
#
# Overridable via environment:
#   VERSION        package version           (default 0.1.0)
#   DIST_DIR       output directory          (default <pkg>/dist)
#   SPROUT_BIN     path to a built sprout    (default ../../sprout/.build/release/sprout)
#   APP_IDENTITY / INSTALLER_IDENTITY  signing identity strings
#   STRIP          1 to strip binaries       (default 1)
#
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # HavenAgentD root
PACKAGING_DIR="$PKG_DIR/Packaging"

VERSION="${VERSION:-0.1.0}"
DIST_DIR="${DIST_DIR:-$PKG_DIR/dist}"
ARCH="$(uname -m)"   # arm64 on Apple Silicon
PKG_IDENTIFIER="io.digipomps.haven.agentd"
INSTALL_PREFIX="/usr/local/libexec/havenagent"
SHARE_PREFIX="/usr/local/share/havenagent"
STRIP="${STRIP:-1}"

APP_IDENTITY="${APP_IDENTITY:-Developer ID Application: Stiftelsen Digipomps (5UT5HQTCV9)}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-Developer ID Installer: Stiftelsen Digipomps (5UT5HQTCV9)}"

SPROUT_BIN="${SPROUT_BIN:-$PKG_DIR/../../sprout/.build/release/sprout}"
ENTITLEMENTS="$PACKAGING_DIR/entitlements.plist"
PLIST_TEMPLATE="$PACKAGING_DIR/io.digipomps.haven.agentd.plist.template"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- preflight ---------------------------------------------------------------
log "Preflight"
security find-identity -v -p codesigning | grep -qF "$APP_IDENTITY" \
  || die "Application signing identity not found: $APP_IDENTITY"
security find-identity -v | grep -qF "$INSTALLER_IDENTITY" \
  || die "Installer signing identity not found: $INSTALLER_IDENTITY"
[[ -f "$ENTITLEMENTS" ]]     || die "Missing entitlements: $ENTITLEMENTS"
[[ -f "$PLIST_TEMPLATE" ]]   || die "Missing plist template: $PLIST_TEMPLATE"
[[ -x "$SPROUT_BIN" ]]       || die "sprout binary not found/executable: $SPROUT_BIN
  Build it first: (cd ../../sprout && swift build -c release --product sprout)
  or set SPROUT_BIN=/path/to/sprout"

# --- build -------------------------------------------------------------------
log "Building haven-agentd (release)"
( cd "$PKG_DIR" && swift build -c release --product haven-agentd )
AGENTD_BIN="$PKG_DIR/.build/release/haven-agentd"
[[ -x "$AGENTD_BIN" ]] || die "build did not produce $AGENTD_BIN"

# --- stage payload -----------------------------------------------------------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
PAYLOAD_LIBEXEC="$STAGE/root$INSTALL_PREFIX"
PAYLOAD_SHARE="$STAGE/root$SHARE_PREFIX"
mkdir -p "$PAYLOAD_LIBEXEC" "$PAYLOAD_SHARE"

log "Staging payload under $INSTALL_PREFIX"
cp "$AGENTD_BIN" "$PAYLOAD_LIBEXEC/haven-agentd"
cp "$SPROUT_BIN" "$PAYLOAD_LIBEXEC/sprout"
chmod 755 "$PAYLOAD_LIBEXEC/haven-agentd" "$PAYLOAD_LIBEXEC/sprout"

if [[ "$STRIP" == "1" ]]; then
  log "Stripping binaries"
  strip "$PAYLOAD_LIBEXEC/haven-agentd"
  strip "$PAYLOAD_LIBEXEC/sprout"
fi

cp "$PLIST_TEMPLATE" "$PAYLOAD_SHARE/io.digipomps.haven.agentd.plist.template"
# sprout has no --version flag (it prints usage), so record the source revision
# of the sprout repo the binary came from. Falls back to "unknown".
SPROUT_SRC_DIR="$(cd "$(dirname "$SPROUT_BIN")/../.." 2>/dev/null && pwd || true)"
SPROUT_VERSION="$(git -C "$SPROUT_SRC_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

# --- sign binaries (hardened runtime + entitlements + timestamp) -------------
# Sign sprout first (inner), then haven-agentd. Each is an independent Mach-O,
# not a nested bundle, so order only matters for clarity.
for bin in sprout haven-agentd; do
  log "Signing $bin"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_IDENTITY" \
    "$PAYLOAD_LIBEXEC/$bin"
  codesign --verify --strict --verbose=2 "$PAYLOAD_LIBEXEC/$bin"
done

# --- checksums + manifest ----------------------------------------------------
mkdir -p "$DIST_DIR"
log "Writing checksums + manifest"
( cd "$PAYLOAD_LIBEXEC" && shasum -a 256 haven-agentd sprout ) > "$DIST_DIR/SHA256SUMS"

AGENTD_SHA="$(shasum -a 256 "$PAYLOAD_LIBEXEC/haven-agentd" | awk '{print $1}')"
SPROUT_SHA="$(shasum -a 256 "$PAYLOAD_LIBEXEC/sprout" | awk '{print $1}')"
cat > "$DIST_DIR/release-manifest.json" <<JSON
{
  "product": "HAVENAgentD",
  "version": "$VERSION",
  "arch": "$ARCH",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "installPrefix": "$INSTALL_PREFIX",
  "signingIdentity": "$APP_IDENTITY",
  "teamId": "5UT5HQTCV9",
  "artifacts": [
    { "name": "haven-agentd", "sha256": "$AGENTD_SHA" },
    { "name": "sprout", "sha256": "$SPROUT_SHA", "version": "$SPROUT_VERSION" }
  ]
}
JSON

# --- build component pkg, then sign with Developer ID Installer --------------
COMPONENT_PKG="$DIST_DIR/havenagent-component.pkg"
FINAL_PKG="$DIST_DIR/HAVENAgentD-$VERSION-$ARCH.pkg"

log "pkgbuild (component, unsigned)"
pkgbuild \
  --root "$STAGE/root" \
  --identifier "$PKG_IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  "$COMPONENT_PKG"

log "productbuild (signed product archive)"
productbuild \
  --package "$COMPONENT_PKG" \
  --sign "$INSTALLER_IDENTITY" \
  "$FINAL_PKG"
rm -f "$COMPONENT_PKG"

log "Verifying pkg signature"
pkgutil --check-signature "$FINAL_PKG"

echo
log "Built: $FINAL_PKG"
echo "  size:    $(du -h "$FINAL_PKG" | awk '{print $1}')"
echo "  version: $VERSION ($ARCH)"
echo "  sprout:  $SPROUT_VERSION"
echo
echo "Next: notarize and staple ->"
echo "  Packaging/notarize_pkg.sh \"$FINAL_PKG\""
