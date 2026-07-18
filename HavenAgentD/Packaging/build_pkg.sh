#!/usr/bin/env bash
#
# build_pkg.sh — build, sign, and package HavenAgentD into a Developer ID
# signed component .pkg. Notarization is a separate step (notarize_pkg.sh).
#
# Output (under dist/, override with DIST_DIR):
#   dist/HAVENAgentD-<version>-<arch>.pkg   signed, ready to notarize
#   dist/SHA256SUMS                          hash of the distributable pkg
#   dist/PAYLOAD_SHA256SUMS                  hashes of the staged binaries
#   dist/release-manifest.json               artifact/version/arch/signing metadata
#
# Required signing identities in the login keychain:
#   "Developer ID Application: Stiftelsen Digipomps (5UT5HQTCV9)"  (binaries)
#   "Developer ID Installer: Stiftelsen Digipomps (5UT5HQTCV9)"    (.pkg)
#
# Overridable via environment:
#   VERSION        package version           (default 0.3.1)
#   DIST_DIR       output directory          (default <pkg>/dist)
#   ARCHS          space/comma-separated architectures (default: current host)
#   BUILD_ROOT     base for toolchain-isolated SwiftPM scratch roots
#   SPROUT_SRC_DIR Sprout source checkout    (default ../../sprout)
#   AGENTD_PREBUILT / CORRESPONDENCE_PREBUILT optional prebuilt thin/universal binaries
#   SPROUT_BIN     optional prebuilt thin/universal sprout binary
#   APP_IDENTITY / INSTALLER_IDENTITY  signing identity strings
#   STRIP          1 to strip binaries       (default 1)
#
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # HavenAgentD root
PACKAGING_DIR="$PKG_DIR/Packaging"

VERSION="${VERSION:-0.3.1}"
DIST_DIR="${DIST_DIR:-$PKG_DIR/dist}"
ARCHS_RAW="${ARCHS:-$(uname -m)}"
ARCHS_RAW="${ARCHS_RAW//,/ }"
read -r -a REQUESTED_ARCHS <<< "$ARCHS_RAW"
BUILD_ROOT_BASE="${BUILD_ROOT:-$PKG_DIR/.build-package}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-13.0}"
PKG_IDENTIFIER="io.digipomps.haven.agentd"
INSTALL_PREFIX="/usr/local/libexec/havenagent"
SHARE_PREFIX="/usr/local/share/havenagent"
STRIP="${STRIP:-1}"

APP_IDENTITY="${APP_IDENTITY:-Developer ID Application: Stiftelsen Digipomps (5UT5HQTCV9)}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-Developer ID Installer: Stiftelsen Digipomps (5UT5HQTCV9)}"

SPROUT_SRC_DIR="${SPROUT_SRC_DIR:-$PKG_DIR/../../sprout}"
AGENTD_PREBUILT="${AGENTD_PREBUILT:-}"
CORRESPONDENCE_PREBUILT="${CORRESPONDENCE_PREBUILT:-}"
SPROUT_BIN="${SPROUT_BIN:-}"
ENTITLEMENTS="$PACKAGING_DIR/entitlements.plist"
PLIST_TEMPLATE="$PACKAGING_DIR/io.digipomps.haven.agentd.plist.template"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

want_arm64=0
want_x86_64=0
for requested_arch in "${REQUESTED_ARCHS[@]}"; do
  case "$requested_arch" in
    arm64) want_arm64=1 ;;
    x86_64) want_x86_64=1 ;;
    "") ;;
    *) die "Unsupported architecture: $requested_arch (expected arm64 and/or x86_64)" ;;
  esac
done

ARCH_LIST=()
[[ "$want_arm64" == "1" ]] && ARCH_LIST+=(arm64)
[[ "$want_x86_64" == "1" ]] && ARCH_LIST+=(x86_64)
[[ "${#ARCH_LIST[@]}" -gt 0 ]] || die "ARCHS did not contain a supported architecture."

if [[ "${#ARCH_LIST[@]}" == "2" ]]; then
  ARCH="universal2"
  ARCH_JSON='["arm64", "x86_64"]'
else
  ARCH="${ARCH_LIST[0]}"
  ARCH_JSON="[\"$ARCH\"]"
fi
HOST_ARCHITECTURES="$(IFS=,; printf '%s' "${ARCH_LIST[*]}")"

# Swift/Clang module caches are not portable across Xcode SDK revisions. Keep
# release scratch paths under a toolchain fingerprint so an SDK update cannot
# silently reuse incompatible Foundation PCMs or compiled Swift modules.
TOOLCHAIN_FINGERPRINT="$({
  swiftc --version 2>&1
  xcrun --sdk macosx --show-sdk-path
  xcrun --sdk macosx --show-sdk-version
} | shasum -a 256 | awk '{print substr($1, 1, 16)}')"
BUILD_ROOT="$BUILD_ROOT_BASE/$TOOLCHAIN_FINGERPRINT"

# --- preflight ---------------------------------------------------------------
log "Preflight"
log "Toolchain cache namespace: $TOOLCHAIN_FINGERPRINT"
security find-identity -v -p codesigning | grep -qF "$APP_IDENTITY" \
  || die "Application signing identity not found: $APP_IDENTITY"
security find-identity -v | grep -qF "$INSTALLER_IDENTITY" \
  || die "Installer signing identity not found: $INSTALLER_IDENTITY"
[[ -f "$ENTITLEMENTS" ]]     || die "Missing entitlements: $ENTITLEMENTS"
[[ -f "$PLIST_TEMPLATE" ]]   || die "Missing plist template: $PLIST_TEMPLATE"
if [[ -n "$AGENTD_PREBUILT" || -n "$CORRESPONDENCE_PREBUILT" ]]; then
  [[ -n "$AGENTD_PREBUILT" && -n "$CORRESPONDENCE_PREBUILT" ]] \
    || die "AGENTD_PREBUILT and CORRESPONDENCE_PREBUILT must be supplied together"
  [[ -x "$AGENTD_PREBUILT" ]] || die "prebuilt haven-agentd not found/executable: $AGENTD_PREBUILT"
  [[ -x "$CORRESPONDENCE_PREBUILT" ]] \
    || die "prebuilt haven-correspondence-mcp not found/executable: $CORRESPONDENCE_PREBUILT"
fi
if [[ -n "$SPROUT_BIN" ]]; then
  [[ -x "$SPROUT_BIN" ]] || die "sprout binary not found/executable: $SPROUT_BIN"
else
  [[ -f "$SPROUT_SRC_DIR/Package.swift" ]] \
    || die "Sprout source checkout not found: $SPROUT_SRC_DIR (or set SPROUT_BIN)"
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ASSEMBLY="$STAGE/assembly"
mkdir -p "$ASSEMBLY"

# --- build -------------------------------------------------------------------
AGENTD_BINS=()
CORRESPONDENCE_BINS=()
SPROUT_BINS=()

for build_arch in "${ARCH_LIST[@]}"; do
  triple="${build_arch}-apple-macosx${MACOS_DEPLOYMENT_TARGET}"
  agent_scratch="$BUILD_ROOT/haven-agentd-$build_arch"

  if [[ -z "$AGENTD_PREBUILT" ]]; then
    log "Building haven-agentd (release, $build_arch)"
    ( cd "$PKG_DIR" && swift build -c release --triple "$triple" \
        --scratch-path "$agent_scratch" --product haven-agentd )
    agent_bin_dir="$(cd "$PKG_DIR" && swift build -c release --triple "$triple" \
        --scratch-path "$agent_scratch" --show-bin-path)"
    AGENTD_BINS+=("$agent_bin_dir/haven-agentd")
    [[ -x "${AGENTD_BINS[${#AGENTD_BINS[@]}-1]}" ]] \
      || die "build did not produce haven-agentd for $build_arch"

    log "Building haven-correspondence-mcp (release, $build_arch)"
    ( cd "$PKG_DIR" && swift build -c release --triple "$triple" \
        --scratch-path "$agent_scratch" --product haven-correspondence-mcp )
    CORRESPONDENCE_BINS+=("$agent_bin_dir/haven-correspondence-mcp")
    [[ -x "${CORRESPONDENCE_BINS[${#CORRESPONDENCE_BINS[@]}-1]}" ]] \
      || die "build did not produce haven-correspondence-mcp for $build_arch"
  fi

  if [[ -z "$SPROUT_BIN" ]]; then
    sprout_scratch="$BUILD_ROOT/sprout-$build_arch"
    log "Building sprout (release, $build_arch)"
    ( cd "$SPROUT_SRC_DIR" && swift build -c release --triple "$triple" \
        --scratch-path "$sprout_scratch" --product sprout )
    sprout_bin_dir="$(cd "$SPROUT_SRC_DIR" && swift build -c release --triple "$triple" \
        --scratch-path "$sprout_scratch" --show-bin-path)"
    SPROUT_BINS+=("$sprout_bin_dir/sprout")
    [[ -x "${SPROUT_BINS[${#SPROUT_BINS[@]}-1]}" ]] \
      || die "build did not produce sprout for $build_arch"
  fi
done

if [[ -n "$AGENTD_PREBUILT" ]]; then
  AGENTD_BIN="$AGENTD_PREBUILT"
  CORRESPONDENCE_BIN="$CORRESPONDENCE_PREBUILT"
elif [[ "${#ARCH_LIST[@]}" == "1" ]]; then
  AGENTD_BIN="${AGENTD_BINS[0]}"
  CORRESPONDENCE_BIN="${CORRESPONDENCE_BINS[0]}"
else
  AGENTD_BIN="$ASSEMBLY/haven-agentd"
  CORRESPONDENCE_BIN="$ASSEMBLY/haven-correspondence-mcp"
  lipo -create "${AGENTD_BINS[@]}" -output "$AGENTD_BIN"
  lipo -create "${CORRESPONDENCE_BINS[@]}" -output "$CORRESPONDENCE_BIN"
fi

if [[ -n "$SPROUT_BIN" ]]; then
  SPROUT_BUILT_BIN="$SPROUT_BIN"
elif [[ "${#ARCH_LIST[@]}" == "1" ]]; then
  SPROUT_BUILT_BIN="${SPROUT_BINS[0]}"
else
  SPROUT_BUILT_BIN="$ASSEMBLY/sprout"
  lipo -create "${SPROUT_BINS[@]}" -output "$SPROUT_BUILT_BIN"
fi

for built_binary in "$AGENTD_BIN" "$CORRESPONDENCE_BIN" "$SPROUT_BUILT_BIN"; do
  actual_archs="$(lipo -archs "$built_binary")"
  for required_arch in "${ARCH_LIST[@]}"; do
    case " $actual_archs " in
      *" $required_arch "*) ;;
      *) die "$built_binary is missing required architecture $required_arch" ;;
    esac
  done
  for actual_arch in $actual_archs; do
    case " ${ARCH_LIST[*]} " in
      *" $actual_arch "*) ;;
      *) die "$built_binary contains unexpected architecture $actual_arch" ;;
    esac
  done
done

# --- stage payload -----------------------------------------------------------
PAYLOAD_LIBEXEC="$STAGE/root$INSTALL_PREFIX"
PAYLOAD_SHARE="$STAGE/root$SHARE_PREFIX"
mkdir -p "$PAYLOAD_LIBEXEC" "$PAYLOAD_SHARE"

log "Staging payload under $INSTALL_PREFIX"
cp "$AGENTD_BIN" "$PAYLOAD_LIBEXEC/haven-agentd"
cp "$CORRESPONDENCE_BIN" "$PAYLOAD_LIBEXEC/haven-correspondence-mcp"
cp "$SPROUT_BUILT_BIN" "$PAYLOAD_LIBEXEC/sprout"
chmod 755 "$PAYLOAD_LIBEXEC/haven-agentd" "$PAYLOAD_LIBEXEC/haven-correspondence-mcp" "$PAYLOAD_LIBEXEC/sprout"

if [[ "$STRIP" == "1" ]]; then
  log "Stripping binaries"
  strip "$PAYLOAD_LIBEXEC/haven-agentd"
  strip "$PAYLOAD_LIBEXEC/haven-correspondence-mcp"
  strip "$PAYLOAD_LIBEXEC/sprout"
fi

cp "$PLIST_TEMPLATE" "$PAYLOAD_SHARE/io.digipomps.haven.agentd.plist.template"
cp "$PACKAGING_DIR/Resources/QUICKSTART.md" "$PAYLOAD_SHARE/QUICKSTART.md"
cp "$PACKAGING_DIR/Resources/ASSISTANT_CORRESPONDENCE.md" "$PAYLOAD_SHARE/ASSISTANT_CORRESPONDENCE.md"
# sprout has no --version flag (it prints usage), so record the source revision
# of the sprout repo the binary came from. Falls back to "unknown".
SPROUT_VERSION="$(git -C "$SPROUT_SRC_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

# --- sign binaries (hardened runtime + entitlements + timestamp) -------------
# Sign sprout first (inner), then haven-agentd. Each is an independent Mach-O,
# not a nested bundle, so order only matters for clarity.
for bin in sprout haven-agentd haven-correspondence-mcp; do
  log "Signing $bin"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_IDENTITY" \
    "$PAYLOAD_LIBEXEC/$bin"
  codesign --verify --strict --verbose=2 "$PAYLOAD_LIBEXEC/$bin"
done

# --- checksums + manifest ----------------------------------------------------
mkdir -p "$DIST_DIR"
log "Writing payload checksums"
( cd "$PAYLOAD_LIBEXEC" && shasum -a 256 haven-agentd haven-correspondence-mcp sprout ) > "$DIST_DIR/PAYLOAD_SHA256SUMS"

AGENTD_SHA="$(shasum -a 256 "$PAYLOAD_LIBEXEC/haven-agentd" | awk '{print $1}')"
CORRESPONDENCE_SHA="$(shasum -a 256 "$PAYLOAD_LIBEXEC/haven-correspondence-mcp" | awk '{print $1}')"
SPROUT_SHA="$(shasum -a 256 "$PAYLOAD_LIBEXEC/sprout" | awk '{print $1}')"
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- build component pkg, then wrap in a signed distribution with GUI panes --
COMPONENT_PKG="$DIST_DIR/havenagent-component.pkg"
FINAL_PKG="$DIST_DIR/HAVENAgentD-$VERSION-$ARCH.pkg"
DIST_XML="$STAGE/Distribution.xml"
chmod +x "$PACKAGING_DIR/scripts/postinstall"

log "pkgbuild (component, unsigned, with postinstall script)"
pkgbuild \
  --root "$STAGE/root" \
  --identifier "$PKG_IDENTIFIER" \
  --version "$VERSION" \
  --scripts "$PACKAGING_DIR/scripts" \
  --install-location / \
  "$COMPONENT_PKG"

# Distribution wrapper: shows Welcome / ReadMe / Conclusion panes in the GUI
# installer so the user understands what was installed and what to do next.
cat > "$DIST_XML" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
  <title>HAVEN Agent (haven-agentd)</title>
  <welcome file="Welcome.html"/>
  <readme file="ReadMe.html"/>
  <conclusion file="Conclusion.html"/>
  <options customize="never" require-scripts="false" hostArchitectures="$HOST_ARCHITECTURES"/>
  <choices-outline>
    <line choice="default"/>
  </choices-outline>
  <choice id="default" title="HAVEN Agent">
    <pkg-ref id="$PKG_IDENTIFIER"/>
  </choice>
  <pkg-ref id="$PKG_IDENTIFIER" version="$VERSION">havenagent-component.pkg</pkg-ref>
</installer-gui-script>
XML

log "productbuild (signed distribution archive with GUI panes)"
productbuild \
  --distribution "$DIST_XML" \
  --package-path "$DIST_DIR" \
  --resources "$PACKAGING_DIR/Resources" \
  --sign "$INSTALLER_IDENTITY" \
  "$FINAL_PKG"
rm -f "$COMPONENT_PKG"

PACKAGE_SHA="$(shasum -a 256 "$FINAL_PKG" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" "$(basename "$FINAL_PKG")" > "$DIST_DIR/SHA256SUMS"
cat > "$DIST_DIR/release-manifest.json" <<JSON
{
  "product": "HAVENAgentD",
  "version": "$VERSION",
  "arch": "$ARCH",
  "architectures": $ARCH_JSON,
  "builtAt": "$BUILT_AT",
  "toolchainFingerprint": "$TOOLCHAIN_FINGERPRINT",
  "installPrefix": "$INSTALL_PREFIX",
  "signingIdentity": "$APP_IDENTITY",
  "teamId": "5UT5HQTCV9",
  "package": { "name": "$(basename "$FINAL_PKG")", "sha256": "$PACKAGE_SHA" },
  "artifacts": [
    { "name": "haven-agentd", "sha256": "$AGENTD_SHA" },
    { "name": "haven-correspondence-mcp", "sha256": "$CORRESPONDENCE_SHA", "authority": "messages-only" },
    { "name": "sprout", "sha256": "$SPROUT_SHA", "version": "$SPROUT_VERSION" }
  ]
}
JSON

log "Verifying pkg signature"
pkgutil --check-signature "$FINAL_PKG"

echo
log "Built: $FINAL_PKG"
echo "  size:    $(du -h "$FINAL_PKG" | awk '{print $1}')"
echo "  version: $VERSION ($ARCH: ${ARCH_LIST[*]})"
echo "  sprout:  $SPROUT_VERSION"
echo
echo "Next: notarize and staple ->"
echo "  Packaging/notarize_pkg.sh \"$FINAL_PKG\""
