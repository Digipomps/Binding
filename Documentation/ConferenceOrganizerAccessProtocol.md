# Conference Organizer Access Protocol

Date: 2026-03-24
Status: Proposed protocol and implementation guide
Scope: organizer/admin access for conference shells across Binding, CellProtocol, CellScaffold, and server runtimes

## Executive Summary

Yes, organizer/admin access should use Verifiable Credentials, but in the right place.

Recommended model:

- keep live challenge-signing as the mandatory proof of possession step
- use one credential to prove that two identities may represent the same entity
- use one credential to prove that the entity has organizer/admin rights for a specific conference scope
- present both credentials inside a verifier-bound presentation when needed
- cache accepted link/role state locally so the user does not feel repeated friction

In short:

- challenge-signing proves "I control this private key right now"
- same-entity VC proves "this key may represent the same user/entity"
- role-grant VC proves "that entity has organizer/admin access here"

This keeps security high without turning every admin action into a repeated multi-step ritual.

## Implementation Status 2026-03-24

We now have a first working code pass across `CellProtocol` and `CellScaffold`:

- `CellProtocol` has shared organizer access models and verifier logic in `ConferenceOrganizerAccessModels.swift`.
- `CellScaffold` has a local compatibility layer in `ConferenceOrganizerAccessSupport.swift` so organizer access can work even when Scaffold is temporarily pinned to an older `CellProtocol` checkout.
- `ConferenceAdminShellCell` and `ConferencePublishedContentCell` now allow credential-backed organizer access through the explicit organizer decision path instead of relying only on generic owner/contract access checks.

The most important runtime bug we found during implementation was not only in organizer proof evaluation. A `BrowserClientIdentityVault` aliasing bug could silently mutate the requester's live key material when a UUID-based alias context was created. That caused:

- requester `did:key` to change during organizer state loading
- requester `publicSecureKey.compressedKey` to change during organizer state loading
- valid organizer proofs to start failing with apparent `subjectMismatch`

The concrete fix was:

- reuse an existing vault identity by UUID when adding a new context alias
- write the updated `VaultIdentity` back into `identitiesUUIDDictionary`
- stop silently generating a fresh identity record for an already known UUID just because the context key was new

This matters for security as much as UX:

- security: the verifier must not accept an identity whose key material drifted silently
- UX: the organizer must not lose access in the middle of reading the control tower because the local vault mutated the active identity

## What We Verified In Code

Focused proof-backed organizer tests now pass:

- `ConferenceShellCellsTests.testAdminShellAllowsCredentialBackedOrganizerAccessForForeignRequester`
- `ConferencePublishedContentCellTests.testPublishedContentCellAllowsCredentialBackedOrganizerRequester`
- `ConferenceOrganizerAccessModelsTests`

These tests verify:

- proof-backed organizer read on admin shell
- proof-backed organizer write on admin shell
- proof-backed organizer write on published content
- shared verifier parity in `CellProtocol`

## Methods That Worked

These methods were especially effective when debugging organizer access:

- install organizer proofs by writing the full `identity.proofs` object once at the root, instead of attempting several deep nested `identity.proofs.*` writes through `EntityAnchor`
- run one focused Scaffold test at a time with `swift test --filter ...` and capture to `/tmp/*.log`
- add before/after assertions for requester `did` and `publicSecureKey.compressedKey` when an access decision flips unexpectedly
- treat `subjectMismatch` as a possible identity mutation bug, not just a claim-format bug

## Prompt For The Next Model

If organizer access regresses again, start here:

1. Run the two focused Scaffold tests for credential-backed organizer access.
2. If organizer proof evaluation flips between read and write, compare requester `uuid`, `did()`, and `publicSecureKey.compressedKey` before and after state loading.
3. Inspect `BrowserClientIdentityVault.addIdentity(...)` and any code path that creates UUID aliases or alternate identity contexts.
4. Only after ruling out identity mutation should you assume the VC/proof verifier itself is wrong.

## Why This Document Exists

Conference organizer access is more demanding than ordinary participant access.

We need all of the following at the same time:

- low friction for the legitimate organizer using Binding or another HAVEN client
- strong proof that the caller controls the current private key
- a portable way to prove that a Binding-side identity and a server-side identity represent the same underlying entity
- a portable way to prove that the entity was granted organizer/admin rights
- a design that survives key rotation, new devices, multiple vaults, and future recovery flows

The existing challenge-signing model is already correct and should remain the foundation. The missing piece is a clean policy layer over it.

## Design Goals

### Security goals

- The verifier must always require live proof of possession of the current private key.
- Organizer/admin access must not depend on a stable device UUID alone.
- Access grants must be portable, revocable, inspectable, and audience-aware.
- Same-entity claims must not silently become a global universal identifier.
- Web custodians must remain tightly constrained and must not become broad bearer-token issuers.
- The verifier must be able to make a deterministic decision with explicit evidence.

### UX goals

- The normal organizer should not need to manually manage multiple credentials.
- The first-time cross-vault step should feel like "approve this device" rather than "import a cryptographic identity."
- Repeated organizer actions during an active session should feel immediate.
- A device that was already linked and already granted organizer rights should not have to re-run the full ceremony every time.
- If the system cannot prove organizer access, the UI should explain whether the problem is:
  - no live key proof
  - no same-entity proof
  - no role grant
  - expired/revoked proof

## Core Decision

Organizer access should be evaluated from three layers:

### Layer 1. Live proof of possession

Required on every access-relevant admission:

1. verifier emits cryptographically secure random challenge
2. requester identity signs challenge
3. verifier checks signature against the presented public key

This proves:

- the requester currently controls the private key

This does not prove:

- that the identity is the same entity as another identity
- that the identity has organizer/admin rights

### Layer 2. Same-entity proof

Required when the current requester identity is not already directly recognized as the entity that owns the organizer role state.

This proof should normally be a `SameEntityIdentityLinkCredential` presented inside a verifier-bound `VCPresentation`.

This proves:

- the presented identity may represent the same entity as a previously trusted identity or entity anchor

### Layer 3. Role grant proof

Required for organizer/admin access.

This should be a dedicated role credential, for example:

- `ConferenceRoleGrantCredential`

This proves:

- the relevant entity has been granted organizer/admin rights for a specific conference or conference-owned scope

## Recommended Credentials

### 1. `SameEntityIdentityLinkCredential`

Use:

- prove that a Binding identity and a server-side identity represent the same underlying entity
- survive new devices and key rotation without reissuing organizer access from scratch

This should follow the profile in:

- [CrossVaultIdentityEnrollment.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/CrossVaultIdentityEnrollment.md)
- [IdentityLinkVCProfile.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/IdentityLinkVCProfile.md)

Key rule:

- this is not an access grant
- it is a linking proof

### 2. `ConferenceRoleGrantCredential`

Use:

- prove that an entity may act as organizer/admin for a specific conference scope

Recommended VC type:

```json
["VerifiableCredential", "ConferenceRoleGrantCredential"]
```

Recommended claims:

```json
{
  "id": "did:key:<holder-or-entity-binding-subject>",
  "conference": {
    "conferenceId": "conference-mvp-2026",
    "scope": "conference.organizer.admin"
  },
  "grantedRole": {
    "role": "organizer_admin",
    "permissions": [
      "conference.shell.admin.read",
      "conference.shell.admin.write",
      "conference.content.publish",
      "conference.operations.inspect"
    ]
  },
  "holderBinding": {
    "mode": "entity_binding",
    "bindingId": "<pairwise-or-blinded-entity-binding>"
  },
  "issuerPolicy": {
    "issuerType": "conference_owner_or_delegate",
    "grantReason": "conference organizer delegation"
  },
  "validFrom": "2026-03-24T08:00:00Z",
  "validUntil": "2026-06-01T00:00:00Z",
  "revocationRef": "cell:///EntityAnchor/roleGrants/conference-mvp-2026/organizer_admin/<id>"
}
```

Key rule:

- prefer binding the grant to an entity-binding, not a single device identity UUID

That matters because:

- direct identity-level role grants are fragile during device migration
- entity-level grants let the user rotate keys or add a new trusted device without manual organizer re-enrollment every time

## What The Verifier Should Accept

`ConferenceAdminShell` and related organizer/admin surfaces should accept organizer access when all of the following are true:

1. The presented identity passes live challenge-signing.
2. The verifier can resolve a trusted entity-binding for that identity, either:
   - directly from local `EntityAnchor`/link records
   - or from a verifier-bound `SameEntityIdentityLinkCredential` presentation
3. The verifier can verify an unexpired, unrecalled `ConferenceRoleGrantCredential` for the same conference scope and same resolved entity-binding.
4. Policy checks pass for audience, issuer trust, expiry, revocation, and intended usage.

## What The Verifier Should Not Accept

The organizer verifier should reject:

- a VC without live challenge-signing
- a role grant whose holder does not match the resolved entity-binding
- a same-entity VC presented outside its intended audience/domain
- a long-expired or revoked role grant
- a role grant that was issued for a different conference scope
- a server-local legacy organizer UUID match with no live signing proof

## Recommended Verification Pipeline

For organizer/admin shell admission:

1. Resolve the presented identity and public key.
2. Emit a cryptographically secure challenge.
3. Verify the challenge signature.
4. Look for a cached `EntityLinkRecord` for the current identity.
5. If none exists or policy requires re-evaluation, verify a `SameEntityIdentityLinkCredential` presentation.
6. Resolve a canonical local `entityBinding`.
7. Verify a `ConferenceRoleGrantCredential` against:
   - trusted issuer policy
   - expected conference scope
   - holder/entity binding
   - expiry
   - revocation
8. Cache the accepted result locally with clear timestamps and provenance.
9. Admit organizer/admin access for that request.

Important:

- step 8 is a UX optimization
- it must not become a bearer shortcut
- cache entries should be bounded by expiry and policy freshness

## Low-Friction UX Model

The user should experience this as two different phases.

### Phase A. First-time setup or new device

Goal:

- link the new Binding/device identity to the same entity
- ensure organizer/admin rights follow the entity

Ideal flow:

1. user signs in or connects from Binding
2. Binding sees that organizer access requires same-entity proof
3. Binding offers a guided "Approve this device for organizer access" step
4. user approves from an already trusted client, or from a tightly constrained web custodian after fresh auth
5. verifier stores accepted link state and role grant state
6. organizer UI opens

The user should see:

- one short explanation
- one approval step
- a clear success result

The user should not see:

- raw public keys
- raw VC payloads
- repeated low-level cryptographic prompts

### Phase B. Normal organizer use

Goal:

- make organizer operations feel immediate

Ideal flow:

1. Binding signs the live challenge locally
2. server checks cached entity-link + role state if still valid
3. organizer shell opens directly

The only repeated friction should be local user verification if the vault policy requires it.

## Recommended Caching Policy

Low friction depends heavily on controlled caching.

### Cache what

- accepted entity-link records
- accepted role grant records
- issuer trust evaluation results

### Do not cache as bearer state

- raw signed challenges
- verifier-bound presentations beyond their intended lifetime
- admission results with no linkage to expiry or revocation

### Recommended cache TTL behavior

- entity-link records:
  - relatively durable
  - revoked or superseded explicitly
- role grant records:
  - durable but checked against revocation and expiry
- verifier-bound presentation:
  - short-lived or one-time
- active session admission:
  - short-lived convenience cache allowed, but never without current live challenge-signing

## Privacy Model

The same-entity proof should avoid introducing a global stable identifier across all verifiers.

Recommended rule:

- use a pairwise or blinded `entityBinding`
- derive it per conference authority or per trust domain

That gives us:

- stable organizer access where needed
- less accidental cross-context correlation

## Issuer Model

### Issuers for same-entity credentials

Allowed issuers:

- an already trusted device identity for the entity
- a tightly constrained web custodian after fresh user auth
- a recovery authority, later

### Issuers for organizer role grants

Allowed issuers:

- conference owner authority
- organizer authority
- another explicitly delegated trusted issuer

The server should not accept arbitrary self-issued role grants.

## How This Maps To Current HAVEN Concepts

### `EntityAnchor`

Should become the local durable source for:

- accepted identity links
- role grant records
- revocation pointers
- device labels and audit trail

### `TrustedIssuerCell`

Should own:

- which issuers may issue same-entity credentials
- which issuers may issue organizer role grants
- trust weighting and future policy evolution

### `ConferenceAdminShell`

Should stop treating organizer access as a raw UUID equality shortcut.

Instead it should evaluate:

- current requester live signature
- resolved entity-binding
- organizer role grant for the conference scope

### `GeneralCell` / bridge admission

Should keep existing challenge-signing semantics intact.

The new organizer logic should sit above admission, not replace it.

## Suggested Swift-Level Artifacts

These can start as protocol/data types before full runtime wiring.

Suggested types:

- `ConferenceRoleGrantCredentialSubject`
- `ConferenceRoleGrantRecord`
- `OrganizerAccessDecision`
- `OrganizerAccessPresentationBundle`
- `EntityBindingResolution`
- `RoleGrantVerificationResult`

Suggested high-level API:

```swift
struct OrganizerAccessDecision {
    let requesterIdentityUUID: String
    let entityBindingID: String
    let conferenceID: String
    let grantedRole: String
    let source: String
    let validUntil: Date?
    let evidence: [String]
}
```

And conceptually:

```swift
func verifyOrganizerAccess(
    requester: Identity,
    conferenceID: String,
    challengeSignature: Data,
    sameEntityPresentation: VCPresentation?,
    roleGrantPresentation: VCPresentation?
) async throws -> OrganizerAccessDecision
```

## Implementation Phases

### P1. Protocol and model types

- add `ConferenceRoleGrantCredentialSubject`
- add local verification model types
- add verifier-side decision/result types

### P2. Verification and local persistence

- teach server-side conference shells to resolve entity-binding
- verify role grants
- persist accepted link/role records under `EntityAnchor`

### P3. Binding UX

- organizer access prompt with one-step approval wording
- clear error states:
  - not linked
  - no organizer grant
  - expired proof
  - revoked proof

### P4. Operational hardening

- revocation endpoint/policy
- issuer rotation
- audit trail
- recovery flows

## Recommended Product Defaults

- default organizer access should be entity-bound, not device-bound
- first organizer access on a fresh device may require explicit approval
- repeated organizer access on the same valid linked device should be near-frictionless
- role grants should be longer-lived than verifier-bound presentations
- verifier-bound presentations should be short-lived
- live challenge-signing remains mandatory

## Concrete Recommendation For The Current Conference Work

For the conference organizer/admin path we are debugging now, the right target is:

1. keep current challenge-signing admission
2. move organizer authorization from raw requester UUID equality toward entity-bound role verification
3. use same-entity VC to bridge Binding/device identity to the organizer entity
4. use a separate role-grant VC to prove organizer/admin rights for the conference
5. cache accepted link/role state locally to keep the user experience fast after first approval

This gives us a path that is both:

- stronger than current ad hoc organizer identity matching
- less brittle than tying organizer access to one exact device identity forever

## Notes For The Next Language Model

If the next step is code, do not replace challenge-signing. Implement organizer authorization as an additional layer above it.

Priority order for the next code pass:

1. add `ConferenceRoleGrantCredentialSubject` and verifier result types to `CellProtocol`
2. define verifier-side entity-binding resolution using existing same-entity VC profile
3. make `ConferenceAdminShell` consume organizer access decisions instead of raw requester UUID matching
4. keep decision caching explicit, bounded, and revocation-aware
5. only after that, add Binding UX for first-time organizer approval
