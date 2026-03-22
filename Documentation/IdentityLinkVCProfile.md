# Verifiable Credential Profile for Entity-Linked Identities

Date: 2026-03-22
Status: Proposed companion profile
Depends on: `Documentation/CrossVaultIdentityEnrollment.md`
Scope: Use of `VCClaim`, `VCPresentation`, `TrustedIssuerCell`, and `EntityAnchor` for same-entity linking and related attestations

## Executive Summary

Yes, Verifiable Credentials can and should be used here, but for the right job.

Recommended decision:

- use Verifiable Credentials to express portable signed claims such as:
  - "this new identity may represent the same entity in this context"
  - "this identity was approved through a fresh-auth enrollment ceremony"
  - "this device key is trusted for these scopes"
- do not use Verifiable Credentials as a replacement for live challenge-signing
- do not let a VC become a bearer token that bypasses proof of possession of the current private key

In other words:

- VC is good for proving claims
- ordinary challenge-signing is still required to prove live key control

That combination is strong and flexible.

## Why VC Fits Well Here

The codebase already has meaningful VC building blocks:

- `CellProtocol/Sources/CellBase/VerifiableCredentials/VCClaim.swift`
- `CellProtocol/Sources/CellBase/VerifiableCredentials/VCPresentation.swift`
- `CellProtocol/Sources/CellBase/VerifiableCredentials/TrustedIssuerCell.swift`
- `CellProtocol/Sources/CellBase/VerifiableCredentials/DIDIdentityVault.swift`

That means we are not inventing a parallel concept from scratch. We can use an existing pattern:

- a `VCClaim` to express a signed statement
- a `VCPresentation` to present that statement in a verifier-bound context
- `TrustedIssuerCell` to manage local trust policy for who may issue such statements

## Where VC Should Be Used

VC is a good fit for statements that are:

- portable across devices or runtimes
- inspectable later
- revocable
- policy-governed
- possibly issued by more than one kind of authority

Examples:

- same-entity linking
- verified organization membership
- verified relationship claims
- verified role or delegation claims
- verified recovery authority claims
- device trust or device enrollment state

## Where VC Should Not Be Used

VC should not replace:

- live proof of possession of the current private key
- per-request challenge-signing
- local user verification in the vault
- short, fresh anti-replay connect/admission challenges

Bad pattern:

- "present a VC and therefore you are authenticated"

Good pattern:

- "present a VC that says this key may represent the same entity, and then also prove you currently control that key by signing a fresh challenge"

## Recommended Model

The best model is a layered one:

### Layer 1. Live key control

This stays exactly as today:

- verifier sends challenge
- identity signs challenge
- verifier checks signature against the public key

### Layer 2. Portable claim about identity/entity relationship

This is where VC fits:

- a trusted issuer signs a credential stating that a target identity may represent the same entity
- that credential may be presented later in a verifier-bound presentation
- the verifier checks policy and revocation before deciding whether to trust the claim

### Layer 3. Local entity-link record

After a verifier accepts the presentation, it may persist a local `IdentityLinkRecord` under `EntityAnchor`.

This separates:

- portable attestation
- local authorization state

That is a healthy boundary.

## Recommended VC Types

### 1. `SameEntityIdentityLinkCredential`

Primary use:

- prove that a target identity may represent the same entity as an already trusted identity

Recommended VC `type`:

```json
["VerifiableCredential", "SameEntityIdentityLinkCredential"]
```

Recommended `credentialSubject` shape:

```json
{
  "id": "did:key:<target-identity-did>",
  "linkType": "same_entity",
  "entityBinding": {
    "mode": "pairwise",
    "bindingId": "<pairwise-or-blinded-entity-binding>"
  },
  "linkedIdentity": {
    "uuid": "<target-identity-uuid>",
    "publicKey": "<base64url>",
    "algorithm": "P256-ES256"
  },
  "approvedDomains": ["private", "scaffold"],
  "approvedIdentityContexts": ["private", "scaffold"],
  "approvedScopes": ["entity-auth", "personal-cells"],
  "enrollmentRequestHash": "<base64url>",
  "assurance": {
    "source": "fresh_auth_and_possession",
    "level": "high"
  },
  "validUntil": "2026-03-22T10:21:00Z",
  "revocationRef": "cell:///EntityAnchor/proofs/identityLinks/<id>"
}
```

### 2. `EntityLinkApprovalCredential`

This is a more specialized profile name if we want to make the approval step explicit rather than only the final relationship.

Recommended VC `type`:

```json
["VerifiableCredential", "EntityLinkApprovalCredential"]
```

Primary use:

- express that a trusted source approved a specific enrollment request for a specific new key

### 3. `RecoveryAuthorityCredential`

Future use:

- prove that a person, device, or organization may assist in recovery or re-linking

This is not required for v1, but the same VC pattern extends cleanly to it.

## Privacy Profile

This part matters a lot.

The identity model explicitly avoids a global identifier, so the VC profile must not reintroduce one by accident.

### Recommended privacy rule

The VC should prove:

- "these identities are linked for this trust context and audience"

not:

- "this person has one global universal identity everywhere"

### Recommended `entityBinding`

Prefer one of these:

#### Pairwise binding

- derive a pairwise `bindingId` per relying party or trust domain
- stable only where needed

#### Blinded binding

- include a digest derived from:
  - entity anchor reference
  - audience
  - salt or verifier-specific context

This lets two systems verify consistency without learning a universal entity handle.

### When raw `entityAnchorReference` is acceptable

Within one tightly bounded local scaffold or server context, using the raw `entityAnchorReference` may be acceptable for implementation simplicity.

But for anything broader or portable, prefer a pairwise or blinded binding.

## Recommended Issuers

The issuer of a same-entity link VC should be one of:

- an already trusted device identity for that entity
- a tightly constrained web custodian after fresh user auth
- a trusted recovery authority, later

The relying party should not accept arbitrary issuers by default.

This is where `TrustedIssuerCell` becomes useful:

- trust policy can be explicit and local
- issuer classes can differ by context
- revocation and weighting can later become more sophisticated

## Presentation Requirements

The VC alone is not enough. It should usually be presented inside a `VCPresentation`.

Recommended presentation rule:

- bind the presentation to a verifier challenge and domain
- require the presenter to be the holder of the target identity

This aligns with the existing `TrustedIssuerCell` proposal language around:

- challenge
- domain
- holder binding
- anti-replay

### Recommended VP use here

The target device should present:

- the VC or VCs
- a presentation proof bound to the verifier challenge and domain
- a live signature from the target key if the verifier needs one separately

This creates a strong chain:

1. issuer attests the relationship
2. holder presents the credential in a verifier-bound presentation
3. holder proves live possession of the same key

## How This Maps To Existing `CellProtocol`

### `VCClaim`

Good current fit for:

- `SameEntityIdentityLinkCredential`
- `EntityLinkApprovalCredential`
- future recovery or delegation claims

### `VCPresentation`

Good current fit for:

- presenting one or more link credentials to a verifier
- binding presentation to a live verifier context

### `TrustedIssuerCell`

Good fit for:

- issuer allowlists
- local trust policy
- later revocation and evaluation logic

### `EntityAnchorCell`

Best fit for:

- storing local accepted link records
- storing revocation state
- exposing current linked identities to the owner

## Recommended Verification Flow

When a relying party receives a same-entity link claim, it should do the following.

### Step 1. Verify the VC itself

- check signature
- check issuer trust
- check time validity
- check revocation if policy requires it

### Step 2. Verify the VP

- check holder proof
- check challenge/domain binding
- reject replay

### Step 3. Verify target-key continuity

- ensure the target public key in the VC matches the key used by the target identity
- ensure the target device can sign a fresh verifier challenge if this is an activation flow

### Step 4. Enforce local policy

- ensure the requested domains and scopes are acceptable
- ensure the issuer is allowed for this entity-link context

### Step 5. Persist local link record

- record the result in `EntityAnchor`
- mark issuer, scope, revocation reference, and timestamps

## Concrete Recommendation For Same-Entity Linking

The cleanest v1 design is:

1. New device generates a new local identity.
2. New device signs an `IdentityEnrollmentRequest`.
3. Existing trusted identity or custodian issues a VC of type `SameEntityIdentityLinkCredential`.
4. New device presents that VC in a verifier-bound `VCPresentation`.
5. Verifier also requires live challenge-signing from the new key.
6. Verifier persists an `IdentityLinkRecord` in `EntityAnchor`.

This gives us both:

- portable attestations
- live proof of possession

## General Use Of VC For Claims

Yes, we should think of VC more generally than identity linking.

Recommended general uses:

- "I am the same entity behind these two identities"
- "I am a member of organization X"
- "I have been delegated limited authority by entity Y"
- "This device is approved for secure operation"
- "This identity is allowed to recover entity access"
- "This issuer is trusted for context Z"

The same pattern works:

- a signed claim says something portable
- a live presentation and/or challenge proves current control
- local policy decides whether to trust and act on the claim

## What Not To Encode In The VC

Avoid putting these things directly into the VC unless strictly necessary:

- raw reusable session tokens
- private device secrets
- long-lived relay tokens
- globally correlatable user identifiers
- authority broader than the intended audience and scope

## Recommended Next Implementation Step

Without changing core auth semantics, the next concrete protocol step should be:

1. define a local profile for `SameEntityIdentityLinkCredential`
2. add deterministic canonical payload rules for it
3. define how `VCPresentation` binds to verifier challenge and domain
4. decide whether `TrustedIssuerCell` is mandatory or optional for v1
5. only then implement local acceptance into `EntityAnchor`

Example artifacts for implementation and tests live in:

- `Documentation/TestData/IdentityLinking/IdentityEnrollmentRequest.example.json`
- `Documentation/TestData/IdentityLinking/SameEntityIdentityLinkCredential.example.json`
- `Documentation/TestData/IdentityLinking/SameEntityIdentityLinkPresentation.example.json`

## Prompt For The Next Language Model

Use this prompt directly if helpful:

```text
Continue from CrossVaultIdentityEnrollment.md and IdentityLinkVCProfile.md. Keep live challenge-signing as the actual authentication mechanism. Use VC only as a portable attestation layer for same-entity claims. Define a local VC profile named SameEntityIdentityLinkCredential, map it onto VCClaim/VCPresentation, require holder binding plus verifier challenge/domain, and persist accepted links into EntityAnchor as local IdentityLinkRecords. Avoid introducing a global identifier, and prefer pairwise or blinded entity binding over raw universal entity references.
```

## Final Recommendation

Yes, VC is the right general mechanism for portable claims, including "these two identities belong to the same entity".

But the safe pattern is:

- VC for the claim
- live signature for the present key
- local policy for acceptance

That keeps the model strong, composable, and aligned with both the existing identity architecture and the intended WebAuthn-like security posture.
