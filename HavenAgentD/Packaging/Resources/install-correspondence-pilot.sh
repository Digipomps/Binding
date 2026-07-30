#!/usr/bin/env bash
#
# User-scoped installation for the internal correspondence pilot.
# It does not require sudo, install a daemon, modify Claude/Codex configuration,
# enroll an identity, or contact staging.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN="$SCRIPT_DIR/bin/haven-correspondence-mcp"
INSTALL_ROOT="${HAVEN_CORRESPONDENCE_INSTALL_ROOT:-$HOME/Library/Application Support/HAVEN/AssistantCorrespondence/bin}"
LINK_DIR="${HAVEN_CORRESPONDENCE_LINK_DIR:-$HOME/.local/bin}"
INSTALL_BIN="$INSTALL_ROOT/haven-correspondence-mcp"

[[ "$(uname -s)" == "Darwin" ]] || {
  printf 'error: this pilot setup requires macOS\n' >&2
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

Binary:
  $INSTALL_BIN

Command link:
  $LINK_DIR/haven-correspondence-mcp

Next:
  1. Obtain the one-time JSON invitation for this Mac from the HAVEN operator.
  2. Run:
       "$INSTALL_BIN" setup --invite /path/to/invite.json
  3. After Kjetil issues the access proof in HAVEN, run:
       "$INSTALL_BIN" activate --profile PROFILE
       "$INSTALL_BIN" doctor --profile PROFILE
  4. Register the messages-only MCP in Claude or Codex:
       claude mcp add --scope user haven-correspondence -- \\
         "$INSTALL_BIN" serve --profile PROFILE
       codex mcp add haven-correspondence -- \\
         "$INSTALL_BIN" serve --profile PROFILE

The installer did not enroll, contact staging, or edit assistant configuration.
EOF
