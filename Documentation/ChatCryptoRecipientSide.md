# Chat Crypto Recipient Side

Date: 2026-03-22
Status: recipient-side envelope opening implemented, ChatCell audience strategy implemented, invitation lifecycle + requester-scoped draft-envelope cache implemented, explicit encrypted persistence policy + sent companion archive implemented, and invitation proof artifacts + acceptance flow implemented
Scope: encrypted envelope opening, sender verification, audience resolution, invitation lifecycle, invitation proof artifacts, requester-scoped draft-envelope cache, encrypted persistence policy, sent companion archive, message crypto metadata, embedded-chat usage guidance

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
  - `audience.invitations`
  - `audience.inviteIdentities`
  - `audience.acceptInvites`
  - `audience.declineInvites`
  - `audience.revokeInvites`
  - `audience.clearInvites`
- `ChatCell` now returns `senderIdentityUUID` and `senderDisplayName` from `crypto.prepareDraftEnvelope`
- `ChatCell` now exposes requester-scoped prepared-envelope cache endpoints:
  - `crypto.draftEnvelope`
  - `crypto.clearDraftEnvelope`
- `ChatCell` now exposes explicit encrypted persistence endpoints:
  - `crypto.persistencePolicy`
  - `crypto.persistenceMode`
  - `crypto.encryptedMessages`
  - `crypto.clearEncryptedMessages`
- `ChatCell` now supports a conservative default plus an explicit opt-in archive mode:
  - `draftCacheOnly`
  - `draftAndSentArchive`
- when `draftAndSentArchive` is enabled, `sendComposedMessage` archives the current prepared envelope as a local encrypted companion for the sent plaintext message
- `messages` payloads now include crypto rendering metadata:
  - `cryptoState`
  - `encryptedCompanionAvailable`
  - nested `crypto` state with `openStatus`, recipient count, persistence timestamp, and sender verification status
- `crypto.openEnvelope` can now take `messageID` to write successful/failed open status back to the archived encrypted message metadata
- `ChatCell` now stores invitation lifecycle records separately from resolved explicit invitees
  - `inviteIdentities` creates or refreshes `pending` invitation records
  - only `accepted` invitations become explicit recipients
  - `declined` and `revoked` invitations remain inspectable but do not resolve as recipients
- `ChatCell` now supports three audience modes:
  - `contextMembers`
  - `invitedIdentities`
  - `hybrid`
- `ChatInvitationProofUtility` now issues and verifies signed invitation artifacts and invitee acceptance proofs
- `ChatCell` now exposes invitation proof endpoints:
  - `audience.invitationArtifacts`
  - `audience.generateInvitationArtifacts`
  - `audience.generateInvitationAcceptance`
  - `audience.acceptInvitationArtifact`
- invitation records now keep proof-aware state:
  - generated invitation artifact
  - accepted invitation proof
  - UI-visible flags for artifact/acceptance availability

Implemented tests:

- open-envelope roundtrip in `ChatCellTests`
- invitation acceptance gates recipient resolution in `ChatCellTests`
- requester-scoped prepared-envelope cache invalidation in `ChatCellTests`
- encrypted companion archive is opt-in and policy-driven in `ChatCellTests`
- `openEnvelope(messageID: ...)` updates message/archive crypto metadata in `ChatCellTests`
- invitation artifact -> invitee acceptance -> owner acceptance roundtrip in `ChatCellTests`
- wrong-requester acceptance rejection in `ChatCellTests`

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

4. Keep invitation state richer than recipient state.
   - `pending`, `accepted`, `declined`, and `revoked` remain visible product state.
   - crypto recipient resolution only consumes the accepted subset.
   - that preserves auditability without making the envelope code stateful in the wrong place.

5. Cache prepared envelopes per requester, not globally.
   - the cache belongs to the requester-scoped composer draft
   - invalidation happens on the same state transitions that materially change the envelope
   - that keeps previews cheap without letting stale envelopes linger

6. Make AI advisory, not authoritative, in the first pass.
   - Apple Intelligence or an AIAgent can suggest audience mode and invitees.
   - The user should confirm before invites or other outward side effects happen.

7. Run `xcodebuild` serially when verifying both Apple targets.
   - parallel `macOS` + `iOS` builds can fight over the same Xcode build database
   - the reliable order was: focused `swift test`, then macOS build, then iOS build

8. Add encrypted persistence as explicit product policy before making it behavior.
   - default stayed conservative: requester-scoped draft cache only
   - archiving encrypted companions for sent messages required an explicit mode switch
   - that made it safe to add rendering metadata without silently changing what gets stored

9. Reuse canonical signing models for chat invitation artifacts.
   - artifact and acceptance payloads are plain `Codable` + `CanonicalPayloadSignable`
   - signatures exclude the `proof` block, exactly like the cross-vault identity-link models
   - that keeps proof verification deterministic and aligned with the rest of the identity work

10. Keep invitation proof transport on the same `ValueType.object` surface as the rest of `CellProtocol`.
   - no side channel was introduced for invite artifacts
   - artifact generation, invitee acceptance, and owner acceptance all flow through normal `get/set`
   - this makes the flow inspectable from Binding, scaffold, tests, and future AI tooling

## Recommended ChatCell Usage

For a `ChatCell` used as a dragged component over another cell or skeleton:

- Default to `audience.mode = hybrid`
- Default to `crypto.persistenceMode = draftCacheOnly`
- Include the chat owner as a recipient by default so the sender can reopen local encrypted drafts/messages
- Treat context-derived members as inherited recipients
- Treat selected identities as explicit invitees
- Treat explicit invitees as `pending` until the user accepts or confirms them
- Do not auto-send invitations just because a chat component was inserted

Why `hybrid` is the right default:

- it keeps friction low when the chat is clearly attached to an existing context
- it still allows the user to add people deliberately
- it avoids conflating "visible in the cell" with "invited to the conversation"

Recommended product rule:

- inserting the component should configure audience resolution
- inserting the component should keep encrypted persistence conservative unless the user explicitly wants archived encrypted companions
- inviting identities should create pending invitation records as an explicit action
- acceptance should remain explicit before invitees become resolved recipients
- proof-backed acceptance should be the normal route for explicit invites that travel between runtimes or devices
- AI may suggest invitees or recommend `contextMembers` vs `hybrid`, but user confirmation should remain the default

## Security Notes

- This pass did not weaken the existing ownership/authentication model
- Sender proof is still based on signature verification
- Recipient opening still requires the recipient private key for key agreement
- Audience mode changes do not grant authorization by themselves; they only affect recipient resolution for content envelopes

## Not Done Yet

- encrypted send/store by default
- membership-change rekey
- invitation transport and acceptance flow
- durable replay protection / artifact ledger beyond current in-cell state
- AI-assisted audience suggestions in UI
- multi-device or cross-vault invite proofs tied to the same entity

## Recommended Next Pass

1. Decide how far encrypted companion persistence should go beyond the local archive.
   - keep only local archive
   - expose archived encrypted messages in richer UI state
   - upgrade sent-message payload/storage later

2. Add richer read-path verification metadata to message rendering.
   - verified sender
   - unsupported suite
   - recipient mismatch
   - decrypt failure class
   - stale companion vs current plaintext mismatch

3. Add invitation transport and acceptance ceremony on top of the in-cell lifecycle.
   - local pending record
   - outbound invitation artifact
   - accepted invite bound to actual identity proof
   - revoked/expired handling

4. Add replay and freshness enforcement beyond current signature/expiry checks.
   - invitation artifact ledger or nonce registry
   - one-time acceptance consumption
   - explicit expired vs revoked vs already-consumed UI states

5. Add AI suggestion hooks without granting autonomous side effects.
   - suggest mode
   - suggest invitees
   - explain why

## Prompt For The Next Model

Use this prompt if the next model should continue exactly from this pass:

> Continue the chat crypto work without changing admission/auth semantics or weakening private-key custody. Assume `ContentCryptoEnvelopeUtility.seal(...)` and `open(...)` exist, `ChatCell` supports `crypto.prepareDraftEnvelope`, `crypto.draftEnvelope`, `crypto.clearDraftEnvelope`, `crypto.persistencePolicy`, `crypto.persistenceMode`, `crypto.encryptedMessages`, `crypto.clearEncryptedMessages`, `crypto.openEnvelope`, audience modes `contextMembers`, `invitedIdentities`, and `hybrid`, invitation lifecycle endpoints `audience.invitations`, `audience.inviteIdentities`, `audience.acceptInvites`, `audience.declineInvites`, and `audience.revokeInvites`, and proof-backed invitation artifact endpoints `audience.invitationArtifacts`, `audience.generateInvitationArtifacts`, `audience.generateInvitationAcceptance`, and `audience.acceptInvitationArtifact`. Pending invites do not resolve as recipients; only accepted invites do. Explicit artifact acceptance stores both the artifact and invitee acceptance proof back into invitation state. Default persistence mode is conservative (`draftCacheOnly`), while `draftAndSentArchive` opt-in archives encrypted companions for `sendComposedMessage`. `openEnvelope(messageID: ...)` writes open/verify status back into message crypto metadata. The targeted `ChatCellTests` and Binding macOS/iOS builds are green when run serially. Next, add replay/consumption protection for invitation artifacts, decide how rich the encrypted archive UI/state should become, add finer decrypt failure/rendering states, and then implement membership-change/rekey behavior. Keep AI advisory: it may suggest recipient mode or invitees, but user confirmation should remain the default before outward invitation effects.
