# Cross-Vault Identity Enrollment and Entity Linking

Date: 2026-03-22
Status: Proposed architecture and implementation guide
Scope: `CellProtocol`, `IdentityVault`, `EntityAnchor`, bridge admission, web-to-app linking

## Why This Exists

HAVEN already has the right core authentication model:

- the user controls a private key
- the private key stays inside an `IdentityVault`
- authentication happens by signing cryptographically secure random challenge data
- the recipient verifies the signature with the public key

That model should stay intact.

What is still missing is a secure, low-friction way for the same user to add a new `Identity` in a different `IdentityVault` and have that new identity represent the same underlying `Entity`.

Typical example:

- the user is currently active in a web client
- the web client may use a tightly constrained private-key custodian
- the user installs the native app
- the native app creates a fresh local key pair
- the user wants that new app identity to represent the same `Entity` as the web session

This document defines how to do that without exporting the private key, without weakening admission, and without collapsing the `Entity`/`Identity` distinction.

## Design Goals

### Security goals

- Keep private keys inside their vaults. Do not export them as part of enrollment.
- Preserve the current challenge-signing model for runtime authentication.
- Require proof of possession of the new private key before linking it.
- Require explicit approval from an already trusted authority for the same entity.
- Make enrollment proofs short-lived, audience-bound, replay-resistant, and single-purpose.
- Keep domain scoping explicit. Cross-vault linking must not silently become a global account.
- Keep custodian power as narrow as possible.

### UX goals

- Adding a device should feel close to passkey/device enrollment, not like raw key management.
- The normal path should be:
  1. open app
  2. choose `Add this device`
  3. scan QR or follow a deep link
  4. approve once on an already trusted client
  5. done
- The user should not need to copy long blobs or manually compare raw public keys.
- The user should be able to review and revoke linked devices later.

### Non-goals

- Do not introduce a permanent global user identifier.
- Do not authorize requests based only on email, session cookie, or account name.
- Do not replace challenge-signing with bearer tokens.
- Do not make the server a general-purpose signer on behalf of the user.
- Do not silently reinterpret every old `owner == requester` check as "same entity" without explicit policy.

## Existing Model We Must Preserve

The current model is already aligned with the desired direction.

### Identity model

From the existing identity model:

- `Entity` is conceptual and should not be blindly transmitted as a global identifier.
- `Identity` is domain-scoped and cryptographically anchored.
- `IdentityVault` owns signing and key generation.
- `Identity` already carries `entityAnchorReference`.

Relevant code and docs:

- `CellProtocolDocuments/Book/03_Identity_Model.md`
- `CellProtocol/Sources/CellBase/Identity/Identity.swift`
- `CellProtocol/Sources/CellApple/IdentityVault.swift`

### Admission model

Current admission and access checks use challenge-signing:

- `GeneralCell.checkIdentityOrigin(_:)` gets cryptographically secure random data from the active vault
- it asks the presented identity to sign that data
- it verifies the signature using the identity's public key

Relevant code:

- `CellProtocol/Sources/CellBase/Cells/GeneralCell/GeneralCell.swift`

This must remain the foundation. Cross-vault linking is not a replacement for this step. It is a way to decide which public keys are allowed to represent the same user entity in future sessions.

## Core Concepts

### 1. Entity

An `Entity` is the stable user subject within a trust context.

In practice, the best current place to anchor this is `EntityAnchor`. The anchor should be the local source of truth for:

- linked identities
- device labels
- enrollment history
- revocation state
- optional policy about which linked identities may act in which contexts

### 2. Identity

An `Identity` is a concrete key-bearing principal:

- unique UUID
- public key
- algorithm metadata
- domain and/or identity context
- optional display name and metadata

Multiple identities may represent the same entity, but they are still distinct identities.

### 3. IdentityVault

The vault remains the only component allowed to:

- generate the private key
- store the private key
- sign challenges and protocol payloads
- confirm local user presence or local user verification

### 4. Enrollment

Enrollment is a registration ceremony that links a newly generated public key to the same entity as an already trusted identity.

This is separate from ordinary request authentication.

### 5. Custodian

A custodian may temporarily hold or operate a private key in environments like web, but it must be constrained:

- only for explicit user-approved operations
- with fresh user authentication
- ideally only for issuing short-lived enrollment approvals or signing ordinary live challenges for the active session
- never as a broad substitute for device-local user-controlled keys in the long term

## Security Model

The linking ceremony must satisfy two separate proofs:

1. Proof that the new device actually controls the new private key.
2. Proof that an already trusted identity or tightly constrained custodian approves that this new key may represent the same entity.

If either proof is missing, the link must not be established.

### Threats we need to resist

- An attacker scans or steals the QR code or deep link.
- An attacker replays an old enrollment proof.
- A compromised session tries to enroll a device long after the user left.
- A malicious relay substitutes a different public key.
- A server tries to claim that two identities belong to the same entity without proof.
- A custodian becomes too powerful and starts acting as the user's permanent identity.
- A lost or stolen device remains linked forever.

### Required defenses

- All challenges and nonces must come from cryptographically secure random.
- All signed payloads must use canonical serialization.
- All approvals must have expiry.
- All approvals must include `jti` or equivalent one-time replay protection.
- All approvals must bind to the new public key, not just to a session.
- All approvals must bind to an audience and purpose.
- The new device must sign its own enrollment request.
- The relying party must store used `jti` values and reject replay.
- Revocation must be first-class.

## High-Level Protocol

There are two ceremonies:

### Ceremony A. Normal authentication

This is the current model and should remain:

1. Verifier generates challenge.
2. Requester signs challenge with its private key.
3. Verifier checks signature using the requester's public key.
4. Access is granted only if the requester's identity is allowed for that operation.

### Ceremony B. Cross-vault identity enrollment

This is the new ceremony:

1. New device creates a fresh identity locally.
2. New device creates and signs an enrollment request.
3. Existing trusted identity or constrained custodian verifies the request context and approves it.
4. Approval is encoded as a short-lived signed enrollment credential.
5. Relying party verifies:
   - the new-device proof
   - the approval proof
   - replay protection
   - expiry
   - audience and purpose
6. Relying party records a link between the new identity and the same entity anchor.
7. Future runtime auth uses ordinary challenge-signing with the new key.

The important point is:

- enrollment proves that a new public key may represent the same entity
- runtime admission still proves live control of that key

## Recommended Artifacts

These are logical protocol objects. They do not all need to be public Swift types on day one, but the contract should be explicit.

### 1. `IdentityEnrollmentRequest`

Created and signed by the new device.

Purpose:

- prove possession of the new private key
- declare what the new identity is asking to be linked to
- carry enough context to make approval safe

Suggested fields:

```json
{
  "version": 1,
  "requestId": "uuid",
  "purpose": "link_identity",
  "entityAnchorReference": "cell:///EntityAnchor",
  "newIdentity": {
    "uuid": "uuid",
    "displayName": "Kjetil iPhone",
    "publicKey": "<base64url>",
    "algorithm": "P256-ES256"
  },
  "requestedDomains": ["private", "scaffold"],
  "requestedIdentityContexts": ["private", "scaffold"],
  "requestedScopes": ["entity-auth", "personal-cells"],
  "audience": "staging.haven.digipomps.org",
  "origin": "haven://binding/add-device",
  "createdAt": "2026-03-22T10:15:00Z",
  "expiresAt": "2026-03-22T10:20:00Z",
  "nonce": "<base64url random>",
  "device": {
    "platform": "ios",
    "label": "Kjetil iPhone"
  },
  "proof": {
    "type": "signature",
    "byIdentityUUID": "uuid",
    "algorithm": "P256-ES256",
    "signature": "<base64url>"
  }
}
```

Rules:

- the request must be signed by the new key itself
- `nonce` must be generated with cryptographically secure randomness
- `expiresAt` should be short, typically 5 minutes
- `audience` must identify the target relying party or enrollment service

### 2. `IdentityEnrollmentApproval`

Created by an already trusted identity or constrained custodian after fresh user authentication.

Purpose:

- approve that the new key may represent the same entity
- make the scope and lifetime explicit

Suggested fields:

```json
{
  "version": 1,
  "approvalId": "uuid",
  "purpose": "approve_link_identity",
  "requestHash": "<base64url canonical hash of request>",
  "entityAnchorReference": "cell:///EntityAnchor",
  "subjectIdentityUUID": "uuid",
  "subjectPublicKey": "<base64url>",
  "approvedDomains": ["private", "scaffold"],
  "approvedIdentityContexts": ["private", "scaffold"],
  "approvedScopes": ["entity-auth", "personal-cells"],
  "issuerIdentityUUID": "uuid",
  "issuerRole": "existing_device",
  "issuerType": "identity",
  "audience": "staging.haven.digipomps.org",
  "origin": "https://staging.haven.digipomps.org",
  "createdAt": "2026-03-22T10:16:00Z",
  "expiresAt": "2026-03-22T10:21:00Z",
  "jti": "uuid",
  "freshAuth": {
    "required": true,
    "method": "biometric_or_passkey",
    "performedAt": "2026-03-22T10:16:00Z"
  },
  "proof": {
    "type": "signature",
    "algorithm": "P256-ES256",
    "signature": "<base64url>"
  }
}
```

Rules:

- approval must be bound to the exact request via `requestHash`
- approval must be short-lived
- approval must be one-time use through `jti`
- fresh authentication should be required on the approving side

### 3. `IdentityLinkRecord`

Persisted after successful verification.

Purpose:

- make the relationship durable
- enable future admission and revocation workflows

Suggested fields:

```json
{
  "linkId": "uuid",
  "entityAnchorReference": "cell:///EntityAnchor",
  "linkedIdentityUUID": "uuid",
  "linkedPublicKey": "<base64url>",
  "algorithm": "P256-ES256",
  "displayLabel": "Kjetil iPhone",
  "domains": ["private", "scaffold"],
  "identityContexts": ["private", "scaffold"],
  "status": "active",
  "linkedAt": "2026-03-22T10:16:05Z",
  "issuerIdentityUUID": "uuid",
  "issuerType": "identity",
  "revokedAt": null,
  "lastUsedAt": null
}
```

### 4. `IdentityLinkRevocation`

Used to disable a linked identity without disturbing others.

Suggested fields:

- `linkId`
- `entityAnchorReference`
- `reason`
- `revokedAt`
- `proof`

This can mirror the style already used in `AgentEntityLinkContract`.

## Recommended Verification Rules

The relying party should accept an enrollment only if all checks pass.

### Request checks

- request purpose is `link_identity`
- request has not expired
- request signature is valid for the declared new public key
- request nonce is present and well-formed
- request hash is computed over canonical bytes

### Approval checks

- approval purpose is `approve_link_identity`
- approval has not expired
- `requestHash` matches the exact request bytes
- approval signature is valid
- `jti` has not been seen before
- `audience` matches the current relying party
- `subjectPublicKey` matches the request
- `entityAnchorReference` matches the expected target

### Policy checks

- issuer is allowed to approve linking for this entity
- requested domains/contexts are allowed
- requested scope is not broader than approval scope
- device status is not revoked

### Final activation checks

After approval verification, the relying party should preferably do one more live challenge against the new identity before final activation. This makes the final state depend on fresh proof of possession, not only on the original request signature.

## Canonical Serialization and Algorithms

### Canonical serialization

All signed enrollment objects should use deterministic canonical bytes.

Recommended approach:

- reuse the same JSON canonicalization strategy already used by `AgentEntityLinkContract`
- exclude `proof` or `signatures` from the canonical payload before signing

### Algorithm agility

The system should be algorithm-aware, not algorithm-assumptive.

Requirements:

- each identity carries its own algorithm metadata
- signatures are verified with the algorithm declared for that identity
- the protocol objects must include `algorithm`
- do not silently change algorithm during enrollment

This matters because the codebase already contains more than one signing environment.

## UX Flows

The target is "secure enough for real ownership" while still feeling easy.

### Flow 1. App adds itself from an already trusted web session

Recommended default flow:

1. User opens app and taps `Add this device`.
2. App generates fresh identity locally and starts an enrollment session.
3. App shows a QR code or short code.
4. User, already signed in on web, opens `Add device`.
5. Web session scans the QR or enters the short code.
6. Web shows:
   - target device label
   - requested scopes
   - expiry
   - clear approval button
7. User approves with fresh auth:
   - passkey
   - platform biometric
   - or equivalent strong re-auth
8. Web issues enrollment approval.
9. App receives confirmation and does final activation challenge.
10. App shows success and the new device appears in a linked-devices list.

This is low friction because the user never handles raw key material.

### Flow 2. App adds itself from another trusted app/device

This should be almost identical to passkey device linking:

1. New app shows QR.
2. Existing trusted device scans it.
3. Existing trusted device shows clear approval UI.
4. User approves with device-local biometric.
5. New app completes enrollment.

### Flow 3. Same-device web-to-app handoff

Useful when the user is on one device only.

Recommended flow:

1. App initiates enrollment and displays a one-time code.
2. Web session on the same device opens a universal link or app link.
3. Approval remains bound to the app-generated request.
4. Web requires fresh auth before approval.
5. App receives approval and finalizes.

Important:

- the handoff token should be opaque and short-lived
- it must not itself be sufficient for authorization

## Custodian Policy

The web custodian case is important but dangerous.

### What a custodian may do

- participate in live challenge-signing for the active web session
- issue short-lived enrollment approval for a new device after fresh user auth
- issue only within explicitly allowed scopes and audiences

### What a custodian should not do

- become the permanent source of truth for the user's identity
- issue broad standing delegation tokens
- silently register devices without a visible user action
- issue approvals without fresh re-authentication

### Recommended restrictions

- approval TTL should be very short
- approvals should be single-use
- approvals should be scoped only to linking a specific new public key
- the custodian should not be able to turn one approval into many devices
- long-lived authority should move to user-controlled device keys as soon as possible

## Entity, Ownership, and Backward Compatibility

This is the area where we must be the most careful.

Today many checks are still identity-specific:

- owner comparison often means `requester.uuid == owner.uuid`
- member checks often compare exact identity UUIDs

That is safe, but it means a newly linked identity does not automatically become equal to an old one.

### Recommended compatibility rule

Do not globally reinterpret all owner checks overnight.

Instead:

1. Keep ordinary admission proof identity-specific and signature-based.
2. Record explicit entity links in `EntityAnchor`.
3. For cells that need same-user continuity across devices, add explicit entity-aware authorization policy.
4. Where a broad auth change would be risky, mirror membership/signatory state deliberately instead of silently changing semantics.

### Recommended phased approach

#### Phase 1

- keep `checkIdentityOrigin(_:)` unchanged
- keep request signing unchanged
- add cross-vault linking registry and approval flow
- allow selected cells and resolver flows to consult the link registry explicitly

#### Phase 2

- add a first-class concept such as `OwnerSubject`
- support:
  - `ownerIdentity`
  - `ownerEntity`
- migrate only where continuity is clearly desired

This protects the current system while making progress.

## Proposed Integration Points in `CellProtocol`

### Keep unchanged

- `GeneralCell.checkIdentityOrigin(_:)`
- ordinary bridge challenge-signing
- `IdentityVault` ownership of private keys

### Extend

#### `EntityAnchorCell`

Add explicit storage and APIs for:

- linked identities
- enrollment sessions
- approval history
- revocation history
- linked-device labels and metadata

Suggested API areas:

- `GET entity.identityLinks`
- `GET entity.identityLinks.current`
- `SET entity.identityLinks.beginEnrollment`
- `SET entity.identityLinks.approveEnrollment`
- `SET entity.identityLinks.completeEnrollment`
- `SET entity.identityLinks.revoke`

#### `IdentityVault`

Add helpers for:

- creating an enrollment request from a fresh local identity
- signing canonical enrollment payloads
- confirming final activation challenge

#### `TrustedIssuerCell`

Optional but useful for later:

- validate externally issued enrollment approvals
- support recovery or organization-backed enrollment policies

For v1, this can remain optional if the issuer is always a directly trusted identity or local custodian.

#### `ConnectChallengeDescriptor`

Use it for low-friction UI remediation:

- `fresh_auth_required`
- `enrollment_approval_required`
- `enrollment_expired`
- `linked_identity_revoked`
- `device_not_yet_linked`

This is a good fit with the existing condition/remediation direction.

## Recommended Supporting Tooling

This work is security-sensitive. We should give ourselves better tools.

### 1. Enrollment validator

High-value debug tool:

- validate request signature
- validate approval signature
- confirm request/approval hash match
- confirm `audience`, `origin`, `expiry`, `jti`
- show which check failed

This can be:

- a local Swift validator utility
- a debug panel inside Binding for developers
- or both

### 2. Link state inspector

Useful user and developer features:

- list linked devices
- show when each device was added
- show last used time
- revoke device
- show whether the source was:
  - trusted device
  - web custodian
  - recovery flow

### 3. Admission diagnostics

We should add precise reason codes instead of generic auth failure:

- `identity_signature_missing`
- `identity_signature_invalid`
- `enrollment_request_expired`
- `enrollment_approval_expired`
- `enrollment_replayed`
- `entity_link_not_found`
- `linked_identity_revoked`
- `fresh_auth_missing`

This helps both UX and debugging.

## Verifiable Credentials

We should explicitly support Verifiable Credentials in this space, but use them carefully.

Recommended position:

- use a VC to express the portable statement that a target identity may represent the same entity
- use a VP to present that statement in a verifier-bound context
- still require ordinary live challenge-signing from the current identity for actual authentication

This means:

- VC is for the claim
- challenge-signing is for live proof of possession

That split preserves the current security model and gives us a reusable way to prove many other claims later.

See the companion profile note:

- `Documentation/IdentityLinkVCProfile.md`

## Recovery and Backup

This document does not fully solve recovery, but it should leave room for it.

### Recommended future direction

- support multiple linked device identities per entity
- support explicit recovery credentials or recovery contacts
- support encrypted vault backup only as a separate, clearly explained feature

The safest default is still:

- create a new device-local key
- prove the entity link through a trusted existing key

That is better than making private-key export the normal path.

## Privacy Considerations

We must not accidentally turn entity linking into global tracking.

### Requirements

- linking must be explicit
- linking must be scoped to a trust boundary
- `EntityAnchor` should remain local/contextual, not a universal public account identifier
- approvals should contain only what is necessary
- logs should never contain private keys, raw secret tokens, or reusable enrollment artifacts

### Good privacy default

The protocol should prove:

- "this new public key may represent the same entity in this trust context"

not:

- "this person has the same global identity everywhere"

## What We Should Explicitly Avoid

- exporting raw private keys to add a device
- treating session cookies as proof of identity ownership
- using long-lived bearer tokens as stand-ins for signatures
- auto-linking devices just because they share email or username
- silently granting the new identity full owner rights everywhere without explicit policy
- embedding global identifiers into every credential

## Concrete Implementation Plan

### P0. Document and align terminology

- Use this document as the reference for cross-vault linking.
- Keep runtime auth unchanged.
- Treat cross-vault linking as a registration ceremony.

### P1. Add protocol objects and canonical signing

- add Swift models for request, approval, link record, revocation
- canonicalize payload bytes before signing
- write deterministic tests for replay, expiry, mismatched key, mismatched audience

### P2. Add `EntityAnchor` link registry

- persist active linked identities
- add read/revoke APIs
- add explicit enrollment completion flow

### P3. Add user flow

- Binding or another client gets a dedicated `Add device` flow
- QR or short-code handoff
- approval UI with clear scope review
- linked device management surface

### P4. Add diagnostics and validator tooling

- enrollment validator
- better reason codes
- debug panel integration

### P5. Add careful entity-aware continuity

- start with explicit membership/signatory propagation where needed
- add first-class entity-backed owner policy only after the behavior is well tested

## Validation Methods That Have Worked Well

These are the methods that have proven useful in this codebase and should continue to be used.

### Code-level validation

- unit tests for canonical signing and verification
- replay and expiry tests
- key-substitution tests
- audience mismatch tests
- fresh-auth requirement tests

### Runtime validation

- compare successful and failing bridge admission flows
- inspect precise auth logs rather than only GUI symptoms
- verify that the new identity can:
  - complete enrollment
  - survive app relaunch
  - authenticate with ordinary challenge-signing afterwards

### GUI validation

- use reproducible AX inspection for approval and linked-device flows
- use screenshots only after AX confirms expected UI state
- show user-visible pending/progress states during enrollment

## Prompt For The Next Language Model

Use this prompt directly if helpful:

```text
Continue from CrossVaultIdentityEnrollment.md. Keep ordinary challenge-signing and owner proof intact. Implement cross-vault identity enrollment as a separate registration ceremony, not as a bearer-token shortcut. Start by adding explicit protocol types for enrollment request, enrollment approval, link record, and revocation; use canonical payload signing; and add deterministic tests for expiry, replay, mismatched audience, and key substitution. Extend EntityAnchor with a linked-identity registry and low-friction APIs for begin/approve/complete/revoke. Use ConnectChallengeDescriptor for user-facing remediation. Do not change private key ownership semantics, and do not globally reinterpret owner equality until there is explicit entity-backed ownership policy.
```

## Final Recommendation

The right long-term model is:

- many identities may represent one entity
- each identity proves itself through ordinary challenge-signing
- linking a new identity to the same entity is an explicit, signed registration ceremony
- the private key stays in the vault that owns it

That gives us both of the things we need most:

- strong cryptographic ownership semantics
- low-friction user onboarding across app, web, and future clients
