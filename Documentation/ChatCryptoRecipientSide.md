# Chat Crypto Recipient Side

Date: 2026-03-22
Status: recipient-side envelope opening implemented, ChatCell audience strategy implemented
Scope: encrypted envelope opening, sender verification, audience resolution, embedded-chat usage guidance

## What Was Implemented

This pass continued the chat content-crypto slice without changing admission, ownership, or the core challenge-signing ceremony.

Implemented in `CellProtocol`:

- `ContentCryptoEnvelopeUtility.open(...)`
  - unwraps a wrapped content key for a recipient
  - verifies sender signature when the suite requires it
  - authenticates ciphertext against canonicalized header AAD
  - returns a typed `OpenedContentEnvelope`
- `OpenedContentEnvelope` in `CryptoAgilityModels.swift`
- `ChatCell` now exposes:
  - `crypto.openEnvelope`
  - `audience`
  - `audience.mode`
  - `audience.inheritedRecipients`
  - `audience.invitedRecipients`
  - `audience.resolvedRecipients`
  - `audience.inviteIdentities`
  - `audience.clearInvites`
- `ChatCell` now returns `senderIdentityUUID` and `senderDisplayName` from `crypto.prepareDraftEnvelope`
- `ChatCell` now supports three audience modes:
  - `contextMembers`
  - `invitedIdentities`
  - `hybrid`

Implemented tests:

- open-envelope roundtrip in `ChatCellTests`
- explicit-invite audience preference in `ChatCellTests`

## What Worked

The reliable working pattern in this pass was:

1. Keep the crypto slice reversible and inspectable.
   - `prepareDraftEnvelope` returns preview material.
   - `openEnvelope` consumes the same envelope shape.
   - Nothing silently flips normal send/storage to encrypted-by-default.

2. Separate recipient resolution from crypto operations.
   - `ContentCryptoEnvelopeUtility` only handles envelope mechanics.
   - `ChatCell` decides who recipients are.
   - That keeps membership UX decisions out of the crypto utility.

3. Treat embedded chat membership and invitations as different concerns.
   - Context inheritance answers: "who is already relevant here?"
   - Explicit invites answer: "who do we want to add deliberately?"
   - `hybrid` combines both without forcing them into one concept.

4. Make AI advisory, not authoritative, in the first pass.
   - Apple Intelligence or an AIAgent can suggest audience mode and invitees.
   - The user should confirm before invites or other outward side effects happen.

## Recommended ChatCell Usage

For a `ChatCell` used as a dragged component over another cell or skeleton:

- Default to `audience.mode = hybrid`
- Include the chat owner as a recipient by default so the sender can reopen local encrypted drafts/messages
- Treat context-derived members as inherited recipients
- Treat selected identities as explicit invitees
- Do not auto-send invitations just because a chat component was inserted

Why `hybrid` is the right default:

- it keeps friction low when the chat is clearly attached to an existing context
- it still allows the user to add people deliberately
- it avoids conflating "visible in the cell" with "invited to the conversation"

Recommended product rule:

- inserting the component should configure audience resolution
- inviting identities should be an explicit action
- AI may suggest invitees or recommend `contextMembers` vs `hybrid`, but user confirmation should remain the default

## Security Notes

- This pass did not weaken the existing ownership/authentication model
- Sender proof is still based on signature verification
- Recipient opening still requires the recipient private key for key agreement
- Audience mode changes do not grant authorization by themselves; they only affect recipient resolution for content envelopes

## Not Done Yet

- encrypted send/store by default
- envelope persistence policy
- membership-change rekey
- invitation transport and acceptance flow
- AI-assisted audience suggestions in UI
- multi-device or cross-vault invite proofs tied to the same entity

## Recommended Next Pass

1. Decide where encrypted chat envelopes live before normal send starts using them.
   - draft only
   - draft + persisted local cache
   - persisted message history

2. Add read-path verification metadata to message rendering.
   - verified sender
   - unsupported suite
   - recipient mismatch
   - decrypt failure class

3. Add invitation lifecycle instead of just invited-identity storage.
   - proposed
   - sent
   - accepted
   - declined
   - revoked

4. Add AI suggestion hooks without granting autonomous side effects.
   - suggest mode
   - suggest invitees
   - explain why

## Prompt For The Next Model

Use this prompt if the next model should continue exactly from this pass:

> Continue the chat crypto work without changing admission/auth semantics or weakening private-key custody. Assume `ContentCryptoEnvelopeUtility.seal(...)` and `open(...)` exist, `ChatCell` supports `crypto.prepareDraftEnvelope`, `crypto.openEnvelope`, and audience modes `contextMembers`, `invitedIdentities`, and `hybrid`, and the targeted `ChatCellTests` are green. Next, decide how encrypted drafts/messages are persisted, add rendering-time verification/decrypt status for messages, and model invitation lifecycle separately from context-derived audience resolution. Keep AI advisory: it may suggest recipient mode or invitees, but user confirmation should remain the default before outward invitation effects.
