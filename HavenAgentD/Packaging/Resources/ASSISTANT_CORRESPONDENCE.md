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
macOS Keychain; HAVEN staging stores only the public key and a narrow grant.
Requests are signed, short-lived and nonce-protected. Enrollment invitations
are single-use and expire.

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
channel, then run:

```bash
haven-correspondence-mcp setup --invite ~/Downloads/haven-invite.json
haven-correspondence-mcp doctor --profile <profile-from-invite>
```

Delete the invite file after successful enrollment. It is never stored in the
correspondence profile.

## Add to Claude Code

```bash
claude mcp add --scope user haven-correspondence -- \
  /usr/local/bin/haven-correspondence-mcp serve --profile <profile>
```

## Add to Codex Desktop/CLI

```bash
codex mcp add haven-correspondence -- \
  /usr/local/bin/haven-correspondence-mcp serve --profile <profile>
```

Restart the client if it does not discover the newly registered server.

## Verify

Ask the client to list its `haven-correspondence` tools. There must be exactly
four, all beginning with `correspondence.`. Send a harmless project-only test
message and verify the peer can list, read and acknowledge it after the sender
Mac is offline.
