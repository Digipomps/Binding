#!/usr/bin/env bash
#
# Build a user-scoped, internal-test ZIP containing only the messages-only
# HAVEN correspondence MCP. This is deliberately separate from build_pkg.sh:
# the ZIP is ad-hoc signed and is not a Developer ID/notarized distribution.
#
# The final external pilot artifact must still be built with build_pkg.sh and
# notarized before broad distribution.
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGING_DIR="$PKG_DIR/Packaging"
VERSION="${VERSION:-0.3.1-internal.1}"
DIST_DIR="${DIST_DIR:-$PKG_DIR/dist}"
CORRESPONDENCE_BIN="${CORRESPONDENCE_BIN:-$PKG_DIR/.build/release/haven-correspondence-mcp}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This pilot bundle is for macOS."
[[ -x "$CORRESPONDENCE_BIN" ]] || die "Missing release binary: $CORRESPONDENCE_BIN"
[[ -f "$PACKAGING_DIR/Resources/ASSISTANT_CORRESPONDENCE.md" ]] \
  || die "Missing correspondence guide."
[[ -f "$PACKAGING_DIR/Resources/install-correspondence-pilot.sh" ]] \
  || die "Missing pilot installer."

ARCHS="$(lipo -archs "$CORRESPONDENCE_BIN")"
ARCH_LABEL="${ARCHS// /-}"
STAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$STAGE_ROOT"' EXIT
PAYLOAD="$STAGE_ROOT/HAVEN-Correspondence-Pilot-$VERSION-$ARCH_LABEL"

mkdir -p "$PAYLOAD/bin" "$DIST_DIR"
cp "$CORRESPONDENCE_BIN" "$PAYLOAD/bin/haven-correspondence-mcp"
cp "$PACKAGING_DIR/Resources/install-correspondence-pilot.sh" "$PAYLOAD/install.sh"
cp "$PACKAGING_DIR/Resources/ASSISTANT_CORRESPONDENCE.md" "$PAYLOAD/README.md"
chmod 0755 "$PAYLOAD/bin/haven-correspondence-mcp" "$PAYLOAD/install.sh"

log "Applying an ad-hoc signature for the internal test bundle"
codesign --force --sign - "$PAYLOAD/bin/haven-correspondence-mcp"
codesign --verify --strict --verbose=2 "$PAYLOAD/bin/haven-correspondence-mcp"

BINARY_SHA="$(shasum -a 256 "$PAYLOAD/bin/haven-correspondence-mcp" | awk '{print $1}')"
cat > "$PAYLOAD/release-manifest.json" <<JSON
{
  "product": "HAVEN Assistant Correspondence",
  "version": "$VERSION",
  "architectures": "$(printf '%s' "$ARCHS")",
  "authority": "messages-only",
  "distribution": "internal-test",
  "developerIdSigned": false,
  "notarized": false,
  "binarySHA256": "$BINARY_SHA"
}
JSON
(cd "$PAYLOAD" && shasum -a 256 bin/haven-correspondence-mcp install.sh README.md release-manifest.json) \
  > "$PAYLOAD/SHA256SUMS"

OUTPUT="$DIST_DIR/$(basename "$PAYLOAD").zip"
rm -f "$OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$PAYLOAD" "$OUTPUT"
ZIP_SHA="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
printf '%s  %s\n' "$ZIP_SHA" "$(basename "$OUTPUT")" \
  > "$DIST_DIR/$(basename "$OUTPUT").sha256"

log "Built internal pilot bundle: $OUTPUT"
log "Architectures: $ARCHS"
log "This ZIP is not Developer ID signed or notarized; use build_pkg.sh for external distribution."
