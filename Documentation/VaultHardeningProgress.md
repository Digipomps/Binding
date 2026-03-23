# Vault Hardening Progress

Date: 2026-03-23
Status: foundation pass, Apple signing-key storage migration pass, metadata-correction pass, chat envelope-preparation pass, recipient-side opening pass, invitation-lifecycle + draft-cache pass, encrypted persistence-policy + sent-companion archive pass, invitation proof-artifact pass, replay-resistant invitation consumption pass, invitation artifact inspection + active-issued reuse pass, durable invitation ledger pass, explicit membership-change/rekey checkpoint pass, and forward-only envelope-generation/context-member-removal pass implemented
Scope: scoped secrets, persisted cell master-key derivation, Apple vault envelope hardening, keychain-backed Apple signing keys, accurate Apple key metadata, explicit key roles, chat envelope preparation, recipient-side opening, invitation lifecycle, invitation proof artifacts, replay-resistant invitation consumption, invitation artifact inspection, active-issued reuse, durable invitation ledger, draft-envelope cache, encrypted persistence policy, sent companion archive, ChatCell audience strategy, explicit membership/rekey checkpointing, forward-only envelope generation, and context-member removal semantics

## What Changed

This pass deliberately avoided changing admission semantics or the ownership model.

We changed storage and key-derivation plumbing, not the challenge-signing ceremony.

Implemented:

- `ScopedSecretProviderProtocol` in `CellProtocol/Sources/CellBase/Crypto/ScopedSecretProviderProtocol.swift`
- `CellBase.defaultScopedSecretProvider`
- `CellResolver.ensurePersistedCellMasterKeyLoaded()` now prefers:
  - `CellBase.defaultScopedSecretProvider`
  - then `defaultIdentityVault as? ScopedSecretProviderProtocol`
  - then legacy `aquireKeyForTag(...)`
- `IdentityVault` on Apple now:
  - exposes `scopedSecretData(tag:minimumLength:)`
  - stores scoped raw secret material under a separate keychain tag namespace
  - encrypts `Identities.crypt` with a versioned `ChaChaPoly` envelope
  - keeps a legacy AES decrypt fallback for already-persisted vault files
  - migrates legacy vault content forward on successful load
  - no longer logs decrypted vault content or key material
  - stores new signing keys as keychain-resident private-key references instead of raw `privateKey` bytes in the vault file
  - persists `privateKeyApplicationTag` for new identities and for migrated legacy identities
  - signs by preferring keychain-backed private keys, then falling back to embedded legacy key material only if needed
  - scrubs embedded private key material from migrated identities when the keychain-backed key is available
  - normalizes Apple signing metadata to `ECDSA` + `P-256` for new identities and migrated legacy identities
- `did:key` handling now understands Apple `P-256` keys and legacy `secp256k1` labels through explicit multicodec parsing
- `VCClaim` verification now carries curve metadata instead of silently assuming `Curve25519`
- `ChatCell` now exposes a read-only `crypto` bootstrap surface:
  - `crypto`
  - `crypto.state`
  - `crypto.policy`
  - `crypto.supportedSuites`
  - plus nested `state.crypto`
- `IdentityKeyRoleProviderProtocol` now makes signing and key-agreement explicit as separate roles
- `Identity.publicKeyAgreementSecureKey` is now carried across Apple, Vapor and local test/runtime vault paths
- Apple and Vapor vault updates now write modified `VaultIdentity` values back into their dictionaries instead of mutating discarded copies
- `ChatCell` now exposes first real envelope-preparation plumbing:
  - `crypto.recipients`
  - `crypto.prepareDraftEnvelope`
  - recipient descriptors derived from key-agreement public keys
  - versioned envelope metadata using `EncryptedContentEnvelope`
  - wrapped content-key metadata for each recipient
  - sender signature over authenticated header + ciphertext
- `ContentCryptoEnvelopeUtility.open(...)` now supports recipient-side opening and sender verification for `haven.chat.message.v1`
- `ChatCell` now exposes `crypto.openEnvelope`
- `ChatCell` now models recipient resolution through audience strategy endpoints:
  - `audience`
  - `audience.mode`
  - `audience.inheritedRecipients`
  - `audience.invitedRecipients`
  - `audience.resolvedRecipients`
  - `audience.inviteIdentities`
  - `audience.invitations`
  - `audience.acceptInvites`
  - `audience.declineInvites`
  - `audience.revokeInvites`
  - `audience.clearInvites`
- `ChatCell` now keeps explicit invitation lifecycle state separate from resolved invite recipients
  - `pending` invitations stay visible but do not resolve as recipients
  - only `accepted` invitations feed the explicit-recipient audience set
- `ChatInvitationProofUtility` now provides a chat-specific proof layer built on the same canonical-signing pattern as the cross-vault identity-link models
  - `ChatInvitationArtifact`
  - `ChatInvitationAcceptance`
  - artifact verification
  - invitee acceptance verification
- `ChatCell` now exposes proof-backed invitation transport hooks:
  - `audience.invitationArtifacts`
  - `audience.generateInvitationArtifacts`
  - `audience.generateInvitationAcceptance`
  - `audience.acceptInvitationArtifact`
- `ChatCell` invitation records now retain:
  - last generated invitation artifact
  - accepted invitee proof
  - artifact/acceptance availability metadata for UI and diagnostics
- `ChatCell` now keeps an in-cell invitation consumption ledger keyed by `invitationID`
  - same artifact + same acceptance is idempotent
  - same artifact + different acceptance is rejected once consumed
  - superseded artifacts are rejected against the current invitation record before acceptance is applied
- `ChatCell` now exposes explicit artifact inspection and issue semantics:
  - `audience.inspectInvitationArtifact`
  - `audience.invitationArtifacts` returns only currently issued artifacts
  - `audience.generateInvitationArtifacts` reuses an already-issued active artifact for the same invite
  - reissue after superseding conditions mints a fresh `invitationID`
  - declined, revoked, and expired artifacts are rejected before owner-side acceptance mutates invitation state
- `ChatCell` now persists a durable invitation artifact ledger keyed by `invitationID`
  - `audience.invitationLedger` exposes that durable inspection state
  - encode/decode roundtrip preserves `consumed`, `superseded`, and `revoked` inspection outcomes
  - `clearInvites` no longer destroys inspection history for already-issued artifacts
- `ChatCell` now exposes explicit membership/rekey surfaces:
  - `crypto.membership`
  - `crypto.rekeyStatus`
  - `crypto.requestRekey`
- `ChatCell` now persists crypto-relevant membership state:
  - `membershipVersion`
  - current membership fingerprint over resolved recipients + audience mode + preferred suite + persistence mode
  - last membership-change timestamp/reason
  - last acknowledged rekey checkpoint
- membership-affecting changes now mark `rekeyRequired`, while `crypto.requestRekey` acknowledges the current resolved audience as the new checkpoint without changing admission/auth semantics
- `EncryptedContentEnvelopeHeader` and `OpenedContentEnvelope` now carry explicit `envelopeGeneration`
- `ChatCell` now exposes `audience.removeContextMembers`
- `crypto.requestRekey` now advances forward-only envelope generation for future envelopes/messages
  - historical archived envelopes keep their original generation
  - prepared-envelope cache is cleared when the generation/checkpoint advances
- prepared, opened, and persisted encrypted-message surfaces now expose `envelopeGeneration`
- removing context members now changes inherited recipient resolution without touching explicit invitation history
- `ChatCell` now keeps requester-scoped prepared-envelope cache state:
  - `crypto.draftEnvelope`
  - `crypto.clearDraftEnvelope`
  - automatic invalidation on compose/audience/invitation changes
- `ChatCell` now exposes explicit encrypted persistence policy and archive surfaces:
  - `crypto.persistencePolicy`
  - `crypto.persistenceMode`
  - `crypto.encryptedMessages`
  - `crypto.clearEncryptedMessages`
- `ChatCell` now supports an explicit persistence split:
  - default `draftCacheOnly`
  - opt-in `draftAndSentArchive`
- in `draftAndSentArchive`, `sendComposedMessage` now archives the current prepared envelope as a local encrypted companion tied to the sent plaintext message id
- `messages` payloads and message flow objects now carry crypto rendering metadata so UI can distinguish:
  - plaintext-only messages
  - messages with archived encrypted companions
  - open/verify status for archived encrypted companions
- `crypto.openEnvelope` can optionally target a `messageID` and write open/verify result back into both the encrypted archive record and the message rendering metadata
- Embedded chat now has a documented product default: `hybrid` audience resolution, where context-derived recipients and explicit invitees are both supported but invitations remain explicit user actions
- `ValueType` equality now correctly handles `.integer` and `.float`, which was required to make the new chat envelope tests trustworthy
- `VaporIdentityVault` can now derive scoped secrets directly from its master key
- `BridgeIdentityVault` and `DIDIdentityVault` explicitly report scoped-secret unavailability instead of pretending they are real secret stores
- `LocalIdentityVault` now returns stable per-tag scoped secrets for the process lifetime instead of ad hoc random tuples

## Why This Was The Right Next Cut

This pass fixes a real architectural problem without destabilizing auth:

- persisted cell crypto no longer has to abuse a legacy `(key, iv)` API
- vault storage moved toward AEAD and scoped derivation
- secret material no longer gets sprayed into logs
- legacy data remains readable
- new Apple identities no longer need raw signing key bytes in app-managed vault storage
- legacy Apple identities can migrate forward without changing the challenge-signing ceremony
- Apple signing metadata now matches the actual `SecKey` signing path closely enough to stop poisoning later VC/interoperability work
- chat cells now declare crypto intent and suite policy explicitly instead of leaving future content encryption implicit
- chat cells can now prove that recipient selection, envelope shaping and sender signing work before we turn on encrypted send-by-default
- chat cells now also make membership drift explicit before we attempt automatic rotation, which is a safer way to grow rekey behavior without hiding state transitions

That gives us a cleaner base for:

- encrypted chat/content payloads
- key-agreement keys separate from signing keys
- cross-vault linking with stronger local custody rules

## Methods That Worked

These were the useful working methods in this round:

1. Change the crypto plumbing in thin vertical slices.
   - First add a new protocol and fallback order.
   - Then move vault implementations one by one.
   - Then add one proving test around the new decision point.

2. Prefer compatibility-preserving insertion over protocol breakage.
   - We did not remove `aquireKeyForTag(...)`.
   - We wrapped it with a better path instead of forcing a large refactor.

3. Verify with targeted package tests and app builds.
   - `swift test --filter AppleIdentityVaultKeyStorageTests`
   - `swift test --filter ChatCellTests`
   - `xcodebuild -quiet -workspace Binding.xcworkspace -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution build`
   - `xcodebuild -quiet -workspace Binding.xcworkspace -scheme Binding -destination 'generic/platform=iOS' -disableAutomaticPackageResolution build`
   - run the two `xcodebuild` commands serially; parallel runs can lock Xcode's shared `build.db`

4. When a new key role is introduced, verify every vault implementation and every copy boundary.
   - The working method here was:
     - add the new role field to `Identity`
     - teach Apple/Vapor/local test vaults to populate it
     - make sure `addIdentity(...)` and `saveIdentity(...)` write updated `VaultIdentity` values back into storage
     - then test through a real consumer (`ChatCell`)

5. Fix metadata and verifier assumptions together.
   - It is not enough to rename curve metadata in one place.
   - The working method was:
     - normalize persisted metadata
     - widen verifier acceptance to the new label and the legacy label
     - update `did:key` parsing/encoding so metadata and external identifiers agree
     - update VC verification so it does not hardcode `Curve25519`

6. Migrate private keys by reference first, semantics second.
   - The successful pattern was:
     - prefer an existing keychain-resident private key
     - if a legacy identity already has a permanent key under its legacy tag, point to that
     - otherwise import the embedded private key once and then scrub it from persisted vault state
   - This preserves auth behavior while improving custody.

7. Treat secret leakage in logs as a code bug, not just a debugging convenience.
   - Removing key/decrypted-data logging is low-risk and high-value.

8. Add persistence policy before broadening persistence behavior.
   - defaulting to `draftCacheOnly` kept the new slice conservative
   - the opt-in archive mode made it possible to prove archive/render plumbing without silently changing storage behavior for every chat
   - this was the right place to add UI-facing crypto metadata

9. Reuse the same canonical-payload signing discipline for chat invitation proofs.
   - the successful pattern was:
     - model artifact and acceptance as ordinary `Codable` structs
     - exclude `proof` from canonical payload bytes
     - sign with the inviter/invitee identity already held by the vault
     - verify using public signing descriptors
   - this kept the proof flow aligned with the identity-linking work instead of inventing a second signature convention

10. Keep proof transport on ordinary `ValueType.object` payloads.
   - that let us test the exact same shape that Binding or scaffold clients will call over `CellProtocol`
   - no extra serializer or side-band transport was needed

11. Put replay protection at the owner-side acceptance boundary first.
   - the inviter-side cell is the place that decides whether an artifact has already been consumed
   - this worked well because it avoided changing the underlying signature model
   - it also gave us a clean idempotent retry story for identical acceptance payloads

12. Add an explicit inspection surface before making artifact lifecycle more durable.
   - `audience.inspectInvitationArtifact` gives callers a stable contract for `issued`, `expired`, `consumed`, `revoked`, `declined`, `superseded`, and missing states
   - that gives UI, transport code, and future AI tooling a shared way to decide whether to retry, regenerate, or stop

13. Reuse active artifacts instead of rotating them gratuitously.
   - that lowers friction when an invite is transferred through a UI or another runtime
   - it also makes debugging and audit trails easier because "generate again" does not silently invalidate the last artifact
   - when rotation is actually needed, minting a fresh `invitationID` keeps replay and supersede semantics crisp

14. Persist inspection state where the lifecycle actually changes.
   - the working move here was to keep a dedicated artifact ledger separate from active invitation records
   - that means `clearInvites`, supersede, and acceptance can all leave durable evidence behind without keeping old active invites alive
   - it also gave us straightforward encode/decode roundtrip tests

15. Add an explicit rekey checkpoint before implementing actual rotation.
   - the successful move was to make membership drift visible without silently rewriting history
   - `crypto.rekeyStatus` gives UI, diagnostics, and future agents a stable signal that recipients changed
   - `crypto.requestRekey` lets us acknowledge the new audience intentionally before future automatic rotation work

16. Tie the checkpoint to crypto-relevant dimensions, not just invite rows.
   - the stable fingerprint includes resolved recipient UUIDs, audience mode, preferred suite, and persistence mode
   - that keeps the next rekey pass aligned with real envelope compatibility rather than only UI lifecycle
   - it also makes later suite/persistence changes visible to the crypto layer

## What Is Still Not Done

The biggest remaining gaps are now narrower:

- legacy identities can still temporarily exist with embedded private-key material until they are loaded and successfully migrated
- `did:key` / DID document support is still lightweight and should be extended further if we want first-class multikey interoperability beyond the currently supported curves
- encrypted payloads are still not sent/stored by default in `ChatCell`
- we now have explicit local persistence policy, but we still need to decide how far encrypted sent-message storage should go beyond the current local companion archive
- invitation artifacts and acceptance proofs now exist, in-cell replay/consumption policy exists, explicit inspection exists, and chat-local durable persistence now exists, but cross-runtime transport/persistence of that policy is not done yet
- sender signing keys and recipient key-agreement keys are now modeled separately, but actual content encryption is still a feature slice rather than a completed subsystem
- chat-local forward generation now exists, but cross-runtime membership/removal semantics are still unresolved
- durable invitation/rekey history is still chat-local; broader runtime placement is not decided yet

## Recommended Next Code Pass

Next step should stay focused and not widen the blast radius:

1. Decide whether the encrypted companion archive stays sidecar-only or becomes part of a first-class encrypted message model.
   - local sidecar archive only
   - richer archive UI/query surfaces
   - sent-message payload upgrade later

2. Decide how chat-local membership/removal should project across runtimes.
   - `audience.removeContextMembers` now works locally
   - the next question is whether that remains chat-local, replicates, or folds into broader runtime membership state
   - preserve enough state to explain why a recipient stopped belonging to future generations

3. Decide where the durable invitation/rekey ledger belongs when invites cross runtimes.
   - current chat-local persistence now survives restarts
   - next question is whether that ledger remains local, replicates, or is absorbed into broader membership state
   - preserve enough state to answer `inspectInvitationArtifact` consistently if storage placement changes later

4. Decide whether encrypted send/storage should remain sidecar-first or graduate into a first-class encrypted message model.
   - forward envelope generation is now explicit
   - old companions remain readable without rewrite
   - the next decision is about primary message storage semantics, not about inventing a second rotation model

5. Keep crypto agility explicit.
   - suite id
   - version
   - envelope format
   - key role
   - migration path

## Prompt For The Next Model

Use this prompt if the next model should continue exactly from this pass:

> Continue the vault-hardening work without changing admission/auth semantics. Assume `ScopedSecretProviderProtocol`, `CellBase.defaultScopedSecretProvider`, the `CellResolver` fallback order, the Apple `ChaChaPoly` vault envelope migration, the `privateKeyApplicationTag` migration path, the Apple metadata correction pass, and explicit `IdentityKeyRoleProviderProtocol` support are already in place. Apple, Vapor and local test/runtime vaults now populate `publicKeyAgreementSecureKey`, `EncryptedContentEnvelopeHeader` now carries explicit `envelopeGeneration`, and `ChatCell` can expose `crypto.recipients`, `crypto.prepareDraftEnvelope`, `crypto.draftEnvelope`, `crypto.clearDraftEnvelope`, `crypto.persistencePolicy`, `crypto.persistenceMode`, `crypto.encryptedMessages`, `crypto.clearEncryptedMessages`, `crypto.openEnvelope`, `crypto.membership`, `crypto.rekeyStatus`, and `crypto.requestRekey`, plus `audience.removeContextMembers`, audience strategy/invitation lifecycle endpoints and proof-backed invite endpoints `audience.invitationArtifacts`, `audience.invitationLedger`, `audience.inspectInvitationArtifact`, `audience.generateInvitationArtifacts`, `audience.generateInvitationAcceptance`, and `audience.acceptInvitationArtifact`. Accepted invites resolve as recipients; pending/declined/revoked invites remain product state only. Artifact acceptance now has in-cell replay protection: identical retries are idempotent, a second distinct acceptance for the same consumed artifact is rejected, superseded artifacts are rejected against the current record state, and declined/revoked/expired artifacts are rejected before mutation. `audience.invitationArtifacts` returns only currently issued artifacts, while `generateInvitationArtifacts` reuses already-issued active artifacts and mints a fresh `invitationID` only on real reissue. Chat-local durable inspection now exists through the persisted invitation ledger: encode/decode roundtrip preserves `consumed`, `superseded`, and `revoked` inspection outcomes, and `clearInvites` preserves artifact history while removing active invite records. Membership drift is now explicit and checkpointed: `crypto.rekeyStatus` compares the current resolved audience fingerprint against the last acknowledged checkpoint, and `crypto.requestRekey` advances forward-only envelope generation for future messages without rewriting historical encrypted companions. Verify with focused `swift test` and serial `xcodebuild` runs. Next, decide whether chat-local membership/removal and durable invitation/rekey history should remain local or fold into broader runtime/membership state when invites cross runtimes, then evaluate whether encrypted send/storage should graduate from sidecar/archive-first behavior into a first-class encrypted message model while keeping suite/version negotiation explicit and backward-compatible.
