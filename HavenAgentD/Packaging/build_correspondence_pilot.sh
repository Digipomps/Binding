#!/usr/bin/env bash
# Build the user-scoped, messages-only correspondence pilot archive.
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.3.1-internal.2}"
DIST_DIR="${DIST_DIR:-$PACKAGE_ROOT/dist}"
BUILD_ROOT="${BUILD_ROOT:-$PACKAGE_ROOT/.build-correspondence-pilot}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-13.0}"
CORRESPONDENCE_PREBUILT="${CORRESPONDENCE_PREBUILT:-}"
ARCHS_RAW="${ARCHS:-$(uname -m)}"
ARCHS_RAW="${ARCHS_RAW//,/ }"
read -r -a REQUESTED_ARCHS <<< "$ARCHS_RAW"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

ARCH_LIST=()
want_arm64=0
want_x86_64=0
for requested_arch in "${REQUESTED_ARCHS[@]}"; do
  case "$requested_arch" in
    arm64) want_arm64=1 ;;
    x86_64) want_x86_64=1 ;;
    "") ;;
    *) die "unsupported architecture: $requested_arch" ;;
  esac
done
[[ "$want_arm64" == 1 ]] && ARCH_LIST+=(arm64)
[[ "$want_x86_64" == 1 ]] && ARCH_LIST+=(x86_64)
[[ "${#ARCH_LIST[@]}" -gt 0 ]] || die "ARCHS did not contain arm64 or x86_64"

if [[ "${#ARCH_LIST[@]}" == 2 ]]; then
  ARCH_LABEL="universal2"
  ARCH_JSON='["arm64", "x86_64"]'
else
  ARCH_LABEL="${ARCH_LIST[0]}"
  ARCH_JSON="[\"${ARCH_LIST[0]}\"]"
fi

PILOT_NAME="HAVEN-Correspondence-Pilot-${VERSION}-${ARCH_LABEL}"
PILOT_ROOT="$DIST_DIR/$PILOT_NAME"
[[ -e "$PILOT_ROOT" ]] && die "output already exists: $PILOT_ROOT"
mkdir -p "$PILOT_ROOT/bin" "$DIST_DIR"

BUILT_BINARIES=()
if [[ -n "$CORRESPONDENCE_PREBUILT" ]]; then
  [[ -x "$CORRESPONDENCE_PREBUILT" ]] \
    || die "prebuilt correspondence binary is missing or not executable"
  BUILT_BINARIES+=("$CORRESPONDENCE_PREBUILT")
else
  for build_arch in "${ARCH_LIST[@]}"; do
    triple="${build_arch}-apple-macosx${MACOS_DEPLOYMENT_TARGET}"
    scratch="$BUILD_ROOT/$build_arch"
    printf 'Building haven-correspondence-mcp (%s, release)\n' "$build_arch"
    swift build \
      --package-path "$PACKAGE_ROOT" \
      --configuration release \
      --triple "$triple" \
      --scratch-path "$scratch" \
      --product haven-correspondence-mcp
    bin_dir="$(swift build \
      --package-path "$PACKAGE_ROOT" \
      --configuration release \
      --triple "$triple" \
      --scratch-path "$scratch" \
      --show-bin-path)"
    binary="$bin_dir/haven-correspondence-mcp"
    [[ -x "$binary" ]] || die "build did not produce $binary"
    BUILT_BINARIES+=("$binary")
  done
fi

PILOT_BINARY="$PILOT_ROOT/bin/haven-correspondence-mcp"
if [[ "${#BUILT_BINARIES[@]}" == 1 ]]; then
  cp "${BUILT_BINARIES[0]}" "$PILOT_BINARY"
else
  lipo -create "${BUILT_BINARIES[@]}" -output "$PILOT_BINARY"
fi
chmod 0755 "$PILOT_BINARY"

actual_archs="$(lipo -archs "$PILOT_BINARY")"
for required_arch in "${ARCH_LIST[@]}"; do
  [[ " $actual_archs " == *" $required_arch "* ]] \
    || die "assembled binary is missing $required_arch"
done
for actual_arch in $actual_archs; do
  [[ " ${ARCH_LIST[*]} " == *" $actual_arch "* ]] \
    || die "assembled binary contains unexpected architecture $actual_arch"
done

cp "$PACKAGE_ROOT/Packaging/Resources/ASSISTANT_CORRESPONDENCE.md" \
  "$PILOT_ROOT/README.md"

cat > "$PILOT_ROOT/install.sh" <<'INSTALL_SCRIPT'
#!/usr/bin/env bash
# User-scoped install: no sudo, daemon, enrollment, network call, or config edit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN="$SCRIPT_DIR/bin/haven-correspondence-mcp"
INSTALL_ROOT="${HAVEN_CORRESPONDENCE_INSTALL_ROOT:-$HOME/Library/Application Support/HAVEN/AssistantCorrespondence/bin}"
LINK_DIR="${HAVEN_CORRESPONDENCE_LINK_DIR:-$HOME/.local/bin}"
INSTALL_BIN="$INSTALL_ROOT/haven-correspondence-mcp"

[[ "$(uname -s)" == "Darwin" ]] || {
  printf 'error: this pilot requires macOS\n' >&2
  exit 1
}
[[ -x "$SOURCE_BIN" ]] || {
  printf 'error: missing bundled binary: %s\n' "$SOURCE_BIN" >&2
  exit 1
}

mkdir -p "$INSTALL_ROOT" "$LINK_DIR"
install -m 0755 "$SOURCE_BIN" "$INSTALL_BIN"
ln -sfn "$INSTALL_BIN" "$LINK_DIR/haven-correspondence-mcp"

cat <<EOF
HAVEN Assistant Correspondence is installed for this user.

Command:
  $LINK_DIR/haven-correspondence-mcp

Next:
  "$LINK_DIR/haven-correspondence-mcp" setup --invite /path/to/haven-invite.json
  "$LINK_DIR/haven-correspondence-mcp" identity --profile PROFILE

The installer did not enroll, contact staging, start a daemon, or edit an
assistant configuration.
EOF
INSTALL_SCRIPT
chmod 0755 "$PILOT_ROOT/install.sh"

BINARY_SHA256="$(shasum -a 256 "$PILOT_BINARY" | awk '{print $1}')"
cat > "$PILOT_ROOT/release-manifest.json" <<EOF
{
  "product": "HAVEN Assistant Correspondence",
  "version": "$VERSION",
  "architectures": $ARCH_JSON,
  "authority": "messages-only",
  "distribution": "internal-test",
  "developerIdSigned": false,
  "notarized": false,
  "binarySHA256": "$BINARY_SHA256"
}
EOF

(
  cd "$PILOT_ROOT"
  shasum -a 256 \
    bin/haven-correspondence-mcp \
    install.sh \
    README.md \
    release-manifest.json > SHA256SUMS
)

ZIP_PATH="$DIST_DIR/$PILOT_NAME.zip"
(
  cd "$DIST_DIR"
  /usr/bin/zip -qry "$ZIP_PATH" "$PILOT_NAME"
)
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

printf 'Created %s\n' "$ZIP_PATH"
printf 'SHA-256 %s\n' "$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
