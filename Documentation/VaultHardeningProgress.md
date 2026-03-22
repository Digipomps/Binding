# Vault Hardening Progress

Date: 2026-03-22
Status: foundation pass, Apple signing-key storage migration pass, metadata-correction pass, chat envelope-preparation pass, and recipient-side opening pass implemented
Scope: scoped secrets, persisted cell master-key derivation, Apple vault envelope hardening, keychain-backed Apple signing keys, accurate Apple key metadata, explicit key roles, chat envelope preparation, recipient-side opening, and ChatCell audience strategy

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
  - `audience.clearInvites`
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

## What Is Still Not Done

The biggest remaining gaps are now narrower:

- legacy identities can still temporarily exist with embedded private-key material until they are loaded and successfully migrated
- `did:key` / DID document support is still lightweight and should be extended further if we want first-class multikey interoperability beyond the currently supported curves
- encrypted payloads are still not sent/stored by default in `ChatCell`
- we still need envelope persistence policy and membership-change rekey behavior
- sender signing keys and recipient key-agreement keys are now modeled separately, but actual content encryption is still a feature slice rather than a completed subsystem

## Recommended Next Code Pass

Next step should stay focused and not widen the blast radius:

1. Decide where chat envelopes live before send-by-default.
   - local draft only
   - persisted draft cache
   - sent-message payload upgrade

2. Add membership-change and rekey hooks.
   - participant join
   - participant leave
   - explicit rekey request

3. Add invitation lifecycle on top of the current audience model.
   - suggested invitee
   - pending invite
   - accepted invite
   - revoked invite

4. Keep crypto agility explicit.
   - suite id
   - version
   - envelope format
   - key role
   - migration path

## Prompt For The Next Model

Use this prompt if the next model should continue exactly from this pass:

> Continue the vault-hardening work without changing admission/auth semantics. Assume `ScopedSecretProviderProtocol`, `CellBase.defaultScopedSecretProvider`, the `CellResolver` fallback order, the Apple `ChaChaPoly` vault envelope migration, the `privateKeyApplicationTag` migration path, the Apple metadata correction pass, and explicit `IdentityKeyRoleProviderProtocol` support are already in place. Apple, Vapor and local test/runtime vaults now populate `publicKeyAgreementSecureKey`, `ChatCell` can expose `crypto.recipients`, `crypto.prepareDraftEnvelope`, `crypto.openEnvelope`, and audience strategy endpoints, and the targeted `ChatCellTests` plus `AppleIdentityVaultKeyStorageTests` are green. Next, decide where encrypted drafts/messages are persisted, add message-level verification/decrypt status for rendering, and implement invitation lifecycle plus membership-change/rekey behavior while keeping suite/version negotiation explicit and backward-compatible.
