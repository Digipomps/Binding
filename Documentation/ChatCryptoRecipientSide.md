# Chat Crypto Recipient Side

Date: 2026-03-23
Status: recipient-side envelope opening implemented, ChatCell audience strategy implemented, invitation lifecycle + requester-scoped draft-envelope cache implemented, explicit encrypted persistence policy + sent companion archive implemented, invitation proof artifacts + acceptance flow implemented, replay-resistant invitation consumption implemented, invitation artifact inspection + active-issued reuse implemented, durable invitation artifact ledger inspection implemented, and explicit membership-change/rekey checkpointing implemented
Scope: encrypted envelope opening, sender verification, audience resolution, invitation lifecycle, invitation proof artifacts, replay-resistant acceptance consumption, invitation artifact inspection, active-issued artifact reuse, durable invitation artifact ledger, requester-scoped draft-envelope cache, encrypted persistence policy, sent companion archive, message crypto metadata, membership-change/rekey checkpointing, embedded-chat usage guidance

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
  - `audience.invitationLedger`
  - `audience.inspectInvitationArtifact`
  - `audience.generateInvitationArtifacts`
  - `audience.generateInvitationAcceptance`
  - `audience.acceptInvitationArtifact`
- invitation records now keep proof-aware state:
  - generated invitation artifact
  - accepted invitation proof
  - UI-visible flags for artifact/acceptance availability
- proof-backed invitation acceptance is now consumption-aware:
  - same artifact + same acceptance can be retried idempotently
  - same artifact + different acceptance is rejected after first successful consumption
  - stale/superseded artifacts are rejected against the current record state
- invitation artifact issue policy is now more explicit:
  - `audience.invitationArtifacts` returns only currently issued, transfer-ready artifacts
  - `audience.generateInvitationArtifacts` reuses an already-issued active artifact for the same invite instead of silently rotating it
  - if an invite is reissued after superseding conditions, a fresh `invitationID` is minted
  - `audience.inspectInvitationArtifact` reports whether a transferred artifact is `issued`, `expired`, `consumed`, `revoked`, `declined`, `superseded`, `notIssued`, or `notFound`
  - declined/revoked/expired artifacts are explicitly rejected at owner-side acceptance time before state mutation happens
- invitation artifact inspection is now durable across ordinary cell persistence:
  - `ChatCell` keeps a persisted invitation artifact ledger keyed by `invitationID`
  - `audience.invitationLedger` exposes that ledger for diagnostics and future UI/AI tooling
  - clearing active invites no longer destroys inspection history for already-issued artifacts
  - inspection of transferred artifacts can now survive restart and still answer `consumed`, `superseded`, or `revoked`
- `ChatCell` now exposes explicit membership/rekey surfaces:
  - `crypto.membership`
  - `crypto.rekeyStatus`
  - `crypto.requestRekey`
- `ChatCell` now persists rekey-aware membership tracking:
  - `membershipVersion`
  - current membership fingerprint derived from resolved recipients + audience mode + preferred suite + persistence mode
  - last membership-change timestamp/reason
  - last acknowledged rekey checkpoint
- rekey behavior is now explicit and advisory:
  - membership-affecting changes mark `rekeyRequired`
  - `crypto.requestRekey` acknowledges the current resolved membership as the next checkpoint
  - normal admission/auth semantics are unchanged
  - future envelope preparation already targets the resolved audience, but the rekey checkpoint makes the membership transition visible and durable

Implemented tests:

- open-envelope roundtrip in `ChatCellTests`
- invitation acceptance gates recipient resolution in `ChatCellTests`
- requester-scoped prepared-envelope cache invalidation in `ChatCellTests`
- encrypted companion archive is opt-in and policy-driven in `ChatCellTests`
- `openEnvelope(messageID: ...)` updates message/archive crypto metadata in `ChatCellTests`
- invitation artifact -> invitee acceptance -> owner acceptance roundtrip in `ChatCellTests`
- wrong-requester acceptance rejection in `ChatCellTests`
- idempotent retry for the same artifact + same acceptance in `ChatCellTests`
- replay rejection for a second acceptance against an already-consumed artifact in `ChatCellTests`
- active artifact reuse without silent rotation in `ChatCellTests`
- inspection of superseded vs current artifacts after reissue in `ChatCellTests`
- rejection of acceptance against a declined artifact in `ChatCellTests`
- filtering of `audience.invitationArtifacts` down to only currently issued artifacts in `ChatCellTests`
- inspection of a consumed artifact after encode/decode roundtrip in `ChatCellTests`
- inspection of a superseded artifact after encode/decode roundtrip in `ChatCellTests`
- revoked inspection history surviving `clearInvites` + encode/decode roundtrip in `ChatCellTests`
- membership change marking `rekeyRequired` until `crypto.requestRekey` acknowledges the new checkpoint in `ChatCellTests`
- rekey checkpoint surviving encode/decode roundtrip and flipping back to `rekeyRequired` after a later membership mutation in `ChatCellTests`

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

11. Make acceptance consumption strict but retries humane.
   - the same accepted payload pair should be idempotent, because network/UI retries are normal
   - a different acceptance for an already-consumed artifact should be rejected, because that is the replay boundary we actually care about
   - this gave us a tighter security posture without adding friction to ordinary client retry behavior

12. Separate "what artifacts exist historically" from "what artifacts are still safe to hand around right now".
   - `audience.invitations` keeps lifecycle history and UI-facing state
   - `audience.invitationArtifacts` now means only currently issued artifacts
   - `audience.inspectInvitationArtifact` lets clients validate a transferred artifact before they try to act on it
   - this keeps transfer surfaces small and makes client behavior easier to reason about

13. Reuse active artifacts; rotate only when semantics change.
   - blindly minting a new artifact on every generate call makes transport/debugging noisier and weakens inspectability
   - reusing an active issued artifact gives us stable links and lower friction
   - when we truly reissue, we mint a fresh `invitationID` so replay and supersede rules stay crisp

14. Persist inspection history separately from active invitation records.
   - active invitation state and durable artifact inspection are related, but not the same thing
   - a chat can clear or supersede active invites without losing the ability to explain what happened to a transferred artifact
   - keeping a separate ledger made restart/restore behavior testable and predictable

15. Make rekey explicit before making it automatic.
   - the successful move here was to separate “membership changed” from “history or envelopes are silently rotated”
   - `crypto.rekeyStatus` tells UI, agents, and diagnostics that the resolved audience drifted from the last acknowledged checkpoint
   - `crypto.requestRekey` makes the transition intentional and inspectable without changing the underlying signing/admission ceremony

16. Tie the membership fingerprint to crypto-relevant state, not just invite rows.
   - recipient UUIDs alone were not enough
   - the stable fingerprint also includes audience mode, preferred suite, and persistence mode
   - that gives us a better base for future envelope versioning and rekey policy without overfitting this pass to one UI flow

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
- proof-backed acceptance should be treated as one-time consumption of the current issued artifact
- if a transferred artifact is old, clients should inspect it first and regenerate rather than guessing whether it is still valid
- AI may suggest invitees or recommend `contextMembers` vs `hybrid`, but user confirmation should remain the default

## Security Notes

- This pass did not weaken the existing ownership/authentication model
- Sender proof is still based on signature verification
- Recipient opening still requires the recipient private key for key agreement
- Audience mode changes do not grant authorization by themselves; they only affect recipient resolution for content envelopes

## Not Done Yet

- encrypted send/store by default
- durable replay protection / artifact ledger beyond current chat-cell-local persistence
- AI-assisted audience suggestions in UI
- multi-device or cross-vault invite proofs tied to the same entity
- actual membership-leave / history-rewrite / envelope-rotation rekey mechanics

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

3. Decide where durable invitation ledger truth should live when invites cross runtimes.
   - current chat-cell-local persistence now survives restarts
   - if invites move between runtimes, decide whether the ledger should remain local, replicate, or fold into broader membership state
   - keep inspection semantics stable even if storage placement changes later

4. Build on the new explicit rekey checkpoint instead of bypassing it.
   - participant leave/removal semantics
   - envelope-version rotation for future messages
   - optional history policy: keep old envelopes readable, do not rewrite by default
   - make sure suite/version negotiation stays backward-compatible while membership changes

5. Add AI suggestion hooks without granting autonomous side effects.
   - suggest mode
   - suggest invitees
   - suggest when a rekey checkpoint should be acknowledged
   - explain why

## Prompt For The Next Model

Use this prompt if the next model should continue exactly from this pass:

> Continue the chat crypto work without changing admission/auth semantics or weakening private-key custody. Assume `ContentCryptoEnvelopeUtility.seal(...)` and `open(...)` exist, `ChatCell` supports `crypto.prepareDraftEnvelope`, `crypto.draftEnvelope`, `crypto.clearDraftEnvelope`, `crypto.persistencePolicy`, `crypto.persistenceMode`, `crypto.encryptedMessages`, `crypto.clearEncryptedMessages`, `crypto.openEnvelope`, `crypto.membership`, `crypto.rekeyStatus`, and `crypto.requestRekey`, audience modes `contextMembers`, `invitedIdentities`, and `hybrid`, invitation lifecycle endpoints `audience.invitations`, `audience.invitationLedger`, `audience.inviteIdentities`, `audience.acceptInvites`, `audience.declineInvites`, and `audience.revokeInvites`, and proof-backed invitation artifact endpoints `audience.invitationArtifacts`, `audience.inspectInvitationArtifact`, `audience.generateInvitationArtifacts`, `audience.generateInvitationAcceptance`, and `audience.acceptInvitationArtifact`. Pending invites do not resolve as recipients; only accepted invites do. `audience.invitationArtifacts` returns only currently issued artifacts, `generateInvitationArtifacts` reuses an already-issued active artifact instead of silently rotating it, and reissue after superseding conditions mints a fresh `invitationID`. Invitation inspection is now durable across ordinary cell persistence: consumed, superseded, and revoked artifacts can still be inspected after encode/decode roundtrip, and `clearInvites` preserves inspection history in the durable ledger even though it removes active invite records. Invitation artifacts still have in-cell replay protection: the same artifact + same acceptance is idempotent, while the same artifact + different acceptance is rejected after first consumption, superseded artifacts are rejected against the current record state, and declined/revoked/expired artifacts are rejected before mutation. Membership drift is now explicit: `crypto.rekeyStatus` compares the current resolved audience fingerprint against the last acknowledged checkpoint, and `crypto.requestRekey` updates that checkpoint without silently rewriting history. Default persistence mode is conservative (`draftCacheOnly`), while `draftAndSentArchive` opt-in archives encrypted companions for `sendComposedMessage`. `openEnvelope(messageID: ...)` writes open/verify status back into message crypto metadata. The targeted `swift test --filter ChatCellTests` and Binding macOS/iOS builds are green when run serially. Next, implement the actual next rekey layer on top of this explicit checkpoint: participant-leave/removal semantics, forward-only envelope rotation for future messages, and a clear policy for whether durable invitation ledger state remains chat-local or graduates into broader runtime membership state. Keep AI advisory-only: it may suggest audience mode, invitees, or when to acknowledge a rekey checkpoint, but user confirmation should remain the default before outward invitation effects.
