# Key Handling and Content Crypto Assessment

Date: 2026-03-22
Status: Assessment and implementation guidance, updated after Apple metadata correction and first chat envelope-preparation pass
Scope: private-key handling, content encryption for chat-like payloads, explicit key roles, and crypto agility

## Why This Note Exists

We now have the first code artifacts for:

- cross-vault identity linking
- VC-backed same-entity claims
- crypto-agility metadata for content encryption

The next question is whether the current key handling is strong enough, and what we need before we can safely encrypt chat content and other user data.

This note answers that directly from the current codebase.

## Files Reviewed

Primary sources reviewed in this round:

- `CellProtocol/Sources/CellApple/IdentityVault.swift`
- `CellProtocol/Sources/CellVapor/VaporIdentityVault.swift`
- `CellProtocol/Sources/CellBase/Identity/IdentityVaultProtocol.swift`
- `CellProtocol/Sources/CellBase/PersistingCells/CellPersistenceCrypto.swift`
- `CellProtocol/Sources/CellBase/Cells/FileCrypto/FileCryptoUtility.swift`
- `CellProtocol/Sources/CellBase/Cells/Chat/ChatCell.swift`
- `CellProtocol/Sources/CellBase/VerifiableCredentials/SecureKey.swift`

## Executive Summary

Current state:

- challenge-signing is conceptually sound
- randomness is good
- Vapor-side vault storage is meaningfully stronger than Apple-side vault storage
- chat content is not end-to-end encrypted today
- the architecture already has some good crypto-agility patterns in `FileCryptoUtility`, but the vault abstraction still mixes concerns

Main conclusion:

- sign/auth keys should remain separate from content-encryption keys
- content encryption should be modeled through explicit suites and envelopes
- `IdentityVaultProtocol` should stop carrying generic symmetric-key duties
- Apple vault persistence has improved materially, and we now have a first explicit key-role split, but we still need decrypt/read paths and persistence semantics before we call content crypto "good enough"

## What Looks Good Today

### 1. Random challenge material

`GeneralCell.checkIdentityOrigin(_:)` uses `identityVault.randomBytes64()`, and the Apple implementation calls `SecRandomCopyBytes`.

That is the right direction:

- OS-backed entropy
- fresh random challenge
- challenge-signing rather than bearer-token auth

### 2. Local user authentication on Apple

`IdentityVault.initialize()` uses `LAContext` and tries biometrics first, then `deviceOwnerAuthentication`.

That is the correct user-presence/user-verification layer for a native vault.

### 3. Server-side vault storage

`VaporIdentityVault` is meaningfully stronger than the older Apple-side persistence path:

- 32-byte master key
- HKDF-derived scoped vault keys
- `ChaChaPoly` authenticated encryption
- migration support from legacy encryption

That is much closer to the target architecture.

### 4. Existing envelope-based content crypto patterns

`FileCryptoUtility` and `CellPersistenceCrypto` already show the right architectural pattern:

- explicit algorithm field
- explicit envelope version
- authenticated encryption
- associated data
- room for future suite changes

This is exactly the style chat/content encryption should follow.

## What Is Not Good Enough Yet

### 1. Apple vault migration is better, but not fully complete

After the latest pass, new Apple `VaultIdentity` records no longer need to persist raw signing private key bytes. They now prefer:

- `privateKeyApplicationTag` pointing at a keychain-resident private key
- empty embedded `privateKey` data for new identities
- scrubbed `privateSecureKey` records without embedded private material

Legacy identities can also migrate forward by:

- reusing an already-permanent legacy keychain key if present
- or importing the embedded private key once into a managed keychain tag and then scrubbing the vault copy

What still remains true:

- old persisted identities may still contain embedded private key material until they are loaded and successfully migrated
- legacy fallback still exists in the signing path for backward compatibility

So the posture is materially better than before, but not yet “all Apple signing keys are guaranteed keychain-only forever”.

### 2. Apple vault file encryption has improved to AEAD, with legacy read support

`IdentityVault.saveIdentities(jsonData:)` now writes a versioned `ChaChaPoly` envelope to `Identities.crypt` and keeps a legacy AES decrypt fallback for older files.

That is the right direction because it gives us:

- authenticated encryption
- explicit format boundary for future migration
- compatibility with existing persisted data

The remaining concern is therefore not the envelope itself, but legacy private-key export that can still exist in old identities until migration completes.

### 3. Key and IV handling are bundled in one opaque keychain value

`aquireKeyForTag(tag:)` stores `key + "." + iv` under one keychain record.

That works as a practical secret store, but it is not a good long-term key architecture because:

- it mixes unrelated materials
- it is not algorithm-aware
- it is not purpose-aware
- it encourages "ask vault for arbitrary symmetric key" instead of explicit crypto roles

### 4. Algorithm metadata is materially better, but interop still needs deliberate follow-through

The latest pass corrected the most misleading part of the Apple path:

- new Apple `VaultIdentity` records now normalize to:
  - `algorithm: .ECDSA`
  - `curveType: .P256`
- migrated legacy Apple identities are normalized the same way
- verifier code now accepts both `.P256` and the legacy `.secp256k1` label where we still need backward compatibility
- `did:key` and VC verification now carry curve metadata instead of assuming everything is `Curve25519`

That removes a real correctness hazard, but it does not mean interop is finished. The remaining caution is:

- our DID/multikey support is still targeted, not comprehensive
- legacy metadata may still exist until every stored identity has been loaded and migrated
- content/key-agreement keys are still not first-class roles in the vault API

So metadata accuracy is no longer the main blocker it was before, but it still needs disciplined follow-through in future protocol work.

### 5. `IdentityVaultProtocol` mixes signing and content-key responsibilities

The current protocol still includes:

- `signMessageForIdentity(...)`
- `verifySignature(...)`
- `randomBytes64()`
- `aquireKeyForTag(tag:)`

This is too much in one protocol.

The signing/auth vault and the content-encryption key provider should not be the same abstraction.

### 6. Chat content is still not encrypted end-to-end

`ChatCell` is currently a plain application-state/message cell with:

- message history
- participants
- composer state
- flow updates

The latest pass added an explicit crypto bootstrap surface:

- `crypto`
- `crypto.state`
- `crypto.policy`
- `crypto.supportedSuites`
- `state.crypto`

That means the chat cell now declares:

- preferred suite id
- accepted suites
- forward secrecy expectation
- sender-signature requirement
- that encryption is not active yet

The newest pass goes one step further than declaration:

- `IdentityKeyRoleProviderProtocol` now separates signing and key-agreement roles
- `ChatCell` can enumerate recipient descriptors through `crypto.recipients`
- `ChatCell` can prepare a draft envelope through `crypto.prepareDraftEnvelope`
- the prepared result includes:
  - versioned suite/header metadata
  - recipient-wrapped content-key descriptors
  - authenticated ciphertext
  - sender signature

But it still does not establish the full runtime loop:

- recipient-side envelope opening
- verified decryption on receive/read
- encrypted message persistence as the default send format
- forward secrecy beyond per-envelope ephemeral wrapping
- membership-change rekey

So today we should treat chat payload confidentiality as not yet solved.

## Assessment: Are Private Keys Safe Enough Today?

Short answer:

- better than plaintext storage
- not yet strong enough for the standard we should hold for long-lived user private keys

### Apple side

I would rate it as:

- much stronger than before
- acceptable for iterative development
- still not the final posture for high-value identities

Main reasons:

- new identities are keychain-backed and legacy identities can migrate forward
- vault file encryption is now AEAD
- verifier and DID metadata are much less misleading than before
- but legacy fallback still exists
- and key roles are still not split clearly enough

### Vapor side

I would rate it as:

- materially better
- still needing clear role separation and policy hardening

Main strengths:

- proper master key management shape
- scoped derivation
- AEAD
- migration support

## What We Need For Chat and Other Content Encryption

Chat and similar content should use a separate content-crypto architecture.

One important implication from the latest pass:

- we now have a better base for content crypto because the vault layer has a cleaner secret/provider split
- chat now exposes a declared suite/policy surface we can build on
- but we should still avoid building chat encryption directly on the signing-key path or on generic `aquireKeyForTag(...)`

### Requirement 1. Separate key roles

We should distinguish at least these key roles:

- signing/authentication key
- key-agreement key
- content-encryption key
- key-wrapping key or derived shared secret

The same key should not quietly serve every role just because it exists.

The codebase is now moving in that direction:

- signing/auth keys remain on the normal signing path
- key-agreement public keys are now explicit on `Identity`
- envelope preparation consumes the key-agreement role instead of guessing from signing metadata

### Requirement 2. Explicit envelope metadata

Each encrypted content object should carry:

- version
- suite identifier
- content encryption algorithm
- key wrapping or key agreement algorithm
- sender key identifier
- recipient key descriptors
- associated-data context
- timestamp

Without that, crypto agility becomes guesswork.

### Requirement 3. Sender authenticity

Encrypted content alone is not enough. We need to know who sent it.

For chat-like payloads, we should require:

- sender signature over canonical associated metadata and ciphertext
- or an equivalent authenticated sender binding in the suite

### Requirement 4. Membership-aware key management

Group or shared chat needs:

- a conversation key or per-message key strategy
- rekey when members are added
- rekey when members are removed
- clear handling of old-message access

### Requirement 5. Forward secrecy, at least for live chat

For actual live chat, the preferred direction is:

- key agreement based on ephemeral or ratcheted material
- not one static symmetric key forever

This does not need a full Signal-style ratchet on day one, but the architecture must not block it.

## Recommended Architecture For Content Encryption

### Recommended v1 shape

Use:

- explicit content-crypto suites
- explicit encrypted-content envelopes
- per-recipient wrapped content keys or derived shared secrets
- signer authenticity

This is why the new `ContentCryptoSuite`, `ContentCryptoPolicy`, and `EncryptedContentEnvelopeHeader` models were added in `CellProtocol`.

### Suggested baseline for chat

For live/private chat, a good default is:

- content algorithm: `ChaChaPoly`
- key agreement: `X25519 + HKDF-SHA256`
- explicit sender signature
- explicit suite ID
- no silent legacy fallback by default

This gives us:

- strong confidentiality
- authenticated encryption
- better room for forward secrecy than a static symmetric key

### Suggested baseline for at-rest persistence

For persisted local/server storage:

- AEAD envelope
- derived symmetric key from master key or scoped secret
- explicit version and suite

That pattern is already visible in `CellPersistenceCrypto`.

## Crypto Agility: What It Means In Practice

If we want to change crypto requirements later, the system must encode enough metadata now.

### Non-negotiable rules

- every encrypted envelope carries a suite ID and version
- every stored public key carries accurate algorithm and curve metadata
- key usage is explicit
- verifiers choose from accepted suite lists, not hardcoded implicit assumptions

### What to avoid

- "if field exists, it must be old AES"
- "if curveType is X, assume signing algorithm Y"
- "just ask the vault for a key and use it somehow"

### What to build toward

- suite negotiation or suite acceptance policy
- migration by accepting multiple suites during a transition
- re-encryption or rotation tools
- per-context crypto policy, for example:
  - persisted cells
  - chat
  - exported bundles
  - attachments

## Concrete Recommendations

### P0. Do not change auth semantics

Keep:

- challenge-signing
- private-key possession checks
- owner/member admission model

### P1. Split signing from content-key access

Refactor toward:

- `IdentityVaultProtocol` for identity/signing
- separate content-secret or content-key provider abstraction

`aquireKeyForTag(tag:)` should move out of the identity vault path.

### P2. Harden Apple private-key persistence

Preferred direction:

- stop serializing raw private key bytes where possible
- keep signing keys in secure OS-backed storage
- if export or wrapping is unavoidable, use explicit AEAD envelope and scoped master key derivation

### P3. Fix crypto metadata accuracy

Update `SecureKey` usage so stored metadata reflects the real algorithm and curve in use.

This is important before wider VC/interoperability work.

### P4. Introduce encrypted content envelopes for chat

Do not bolt encryption onto `ChatCell` via ad hoc string fields.

Instead:

- encrypt message body/content
- sign canonical envelope metadata
- keep routing metadata minimal and explicit

### P5. Add revocation and device/key rotation UX

Users should eventually be able to:

- see which device keys are active
- revoke a device
- rotate a device key
- see which crypto suite is being used for sensitive content

## Methods That Worked In This Round

These methods produced the most useful signal:

- reading `IdentityVault.swift` and `VaporIdentityVault.swift` side by side
- comparing `FileCryptoUtility` and `CellPersistenceCrypto` to the vault path
- checking `ChatCell` to confirm that content encryption is not yet present
- running targeted tests for the new identity-linking and crypto-agility models

Useful command:

```bash
swift test --filter IdentityLinkingModelsTests
```

## Prompt For The Next Language Model

Use this prompt directly if helpful:

```text
Continue from CrossVaultIdentityEnrollment.md, IdentityLinkVCProfile.md, and KeyHandlingAndContentCryptoAssessment.md. Preserve challenge-signing semantics. Prioritize splitting identity-signing responsibilities from content-key responsibilities, hardening Apple-side private-key persistence away from raw serialized private keys, fixing crypto metadata accuracy in SecureKey usage, and designing encrypted content envelopes for chat around explicit suite IDs, sender authenticity, and upgradeable crypto policy.
```

## Final Recommendation

We should treat the current signing/auth model as worth preserving, but not treat the current Apple private-key persistence and generic vault key access as the final answer.

The safest path is:

- keep auth cryptographically strict
- harden private-key custody
- separate signing keys from content-encryption architecture
- make all content crypto suite-driven and versioned from the start
