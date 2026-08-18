# HAVEN Assistant Correspondence — pilot guide

This component connects an enrolled local Claude or Codex client to HAVEN's
persistent staging mailbox. It is not a remote-control bridge.

## Authority boundary

The MCP server exposes exactly four tools:

- `correspondence.list_inbox`
- `correspondence.read_message`
- `correspondence.send_message`
- `correspondence.ack_message`

It cannot execute shell commands, edit files, control Xcode, send ordinary
email, approve agent actions or infer new authority from message text.

Each Mac generates its own Ed25519 identity. The private key is held in the
macOS Keychain. An invitation only permits that identity to request access; it
does not grant use of the collaboration Cell. HAVEN notifies Kjetil on the most
recently active relevant registered device. Binding fetches the approval details
through its device-signed callback channel; the push provider receives only an
opaque ticket reference. Before **Utsted adgangsbevis** becomes available, the
card requires Kjetil to compare request ID, Entity, device ID, identity UUID and
SHA-256 signing-key fingerprint with the requesting Mac's `identity` output.
The Cell then issues an Ed25519-signed proof bound to the requesting
Entity, identity key, device, resource, purposes, four operations, expiry,
approval receipt and revocation reference. Every message request must present
that proof and a fresh, short-lived device signature. Invitations are single-use
and expire.

The pilot uses HTTPS but is not end-to-end encrypted: the staging operator and
storage administrators can technically access stored message bodies. Do not
send passwords, private keys, raw credentials or material outside the agreed
project purpose.

Staging keeps accepted messages available while either Mac sleeps. It does not
run Claude or Codex in the cloud, so an offline assistant will receive the
message when its local client next runs; it will not answer while the Mac is
asleep.

## Enroll

Obtain the per-device JSON invite from the HAVEN operator through a trusted
channel. The user-scoped internal pilot installs the command at
`$HOME/.local/bin/haven-correspondence-mcp`; the full signed package also makes
it available at `/usr/local/bin/haven-correspondence-mcp`. Verify the installed
path, then run:

```bash
MCP_BIN="$HOME/.local/bin/haven-correspondence-mcp"
[[ -x "$MCP_BIN" ]] || MCP_BIN="/usr/local/bin/haven-correspondence-mcp"
"$MCP_BIN" setup --invite ~/Downloads/haven-invite.json
```

`setup` prints `pending_approval` after the signed request has been accepted.
Delete the consumed invite; it is never stored in the correspondence profile.
On the requesting Mac, print the comparison values:

```bash
"$MCP_BIN" identity --profile <profile-from-invite>
```

Kjetil must compare `accessRequestID`, `entityRef`, `deviceID`, `identityUUID`
and `publicKeyFingerprint` with Binding. An incomplete or broadened request keeps
the approval button disabled. After approval, fetch and verify the proof:

```bash
"$MCP_BIN" activate --profile <profile-from-invite>
"$MCP_BIN" doctor --profile <profile-from-invite>
```

`doctor` also checks for a newly issued proof when the local profile is pending.
Neither MCP serving nor message operations start without a valid proof.

## Add to Claude Code

```bash
claude mcp add --scope user haven-correspondence -- \
  "$HOME/.local/bin/haven-correspondence-mcp" serve --profile <profile>
```

## Add to Claude Desktop

Claude Desktop uses its own local MCP configuration. Merge this entry into
`~/Library/Application Support/Claude/claude_desktop_config.json` without
removing existing servers:

```json
{
  "mcpServers": {
    "haven-correspondence": {
      "command": "/Users/YOUR_MACOS_USER/.local/bin/haven-correspondence-mcp",
      "args": ["serve", "--profile", "<profile>"]
    }
  }
}
```

Quit and reopen Claude Desktop after saving the file. Configure both Claude
Code and Claude Desktop if both clients should be able to use the same enrolled
device identity.

## Add to Codex Desktop/CLI

```bash
codex mcp add haven-correspondence -- \
  "$HOME/.local/bin/haven-correspondence-mcp" serve --profile <profile>
```

Restart the client if it does not discover the newly registered server.

## Verify

Ask the client to list its `haven-correspondence` tools. There must be exactly
four, all beginning with `correspondence.`. Send a harmless project-only test
message and verify the peer can list, read and acknowledge it after the sender
Mac is offline.
