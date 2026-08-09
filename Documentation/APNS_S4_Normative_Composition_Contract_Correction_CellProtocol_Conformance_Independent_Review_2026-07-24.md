# APNS S4 Normative Composition Contract Correction — CellProtocol Conformance Independent Review

Status: **REVIEW-FROZEN / LANE A NO-GO / S4 NO-GO / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Review date: `2026-07-25`  
Review role: independent S4 Lane A CellProtocol reviewer, distinct from the S4
author  
Review mode: exact-byte, local, static, document-only

Sole owned output:

`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellProtocol_Conformance_Independent_Review_2026-07-24.md`

This reviewer did not author or edit S3, any S3 review, or S4. No source, Git,
dependency resolution, build, test, network, portal, signing, device, APNS,
secret, Identity, staging, deployment, integration, or production action was
performed or authorized.

## 1. Exact review gate

The owned output path was re-attested absent before creation.

### 1.1 Exact S4 target

| Property | Reproduced value |
|---|---|
| Path | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md` |
| Required SHA-256 | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` |
| Actual SHA-256 | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` |
| Lines | 2377 |
| Bytes | 79288 |
| Result | **MATCH — REVIEW PERMITTED** |

The review covers exactly those bytes.

### 1.2 Immutable S3 lineage

| Role | Path | SHA-256 | Lines | Bytes | Result |
|---|---|---|---:|---:|---|
| S3 contract | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 | MATCH |
| S3 Lane A review | `Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 | MATCH |
| S3 Lane B review | `Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 | MATCH |
| S3 Lane C review | `Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 | MATCH |

The authoritative S3 review finding counts reproduce as:

```text
Lane A = 0/4/2
Lane B = 0/7/2
Lane C = 0/3/2
```

S4 consolidates observations into eleven P1 and three P2 author clusters.
Consolidation does not itself close a finding.

## 2. Purpose and review method

Purposes:

- `purpose://test.acceptance`: determine whether ordered `S3 exact bytes` then
  `S4 exact bytes` is deterministic enough for independent CellProtocol
  production and consumption.
- `purpose://access.audit.privacy`: reject identifier, status, consent,
  catalog, replay, or tombstone behavior that leaks another subject or invents
  authority/retention.
- `purpose://scaffold.operations`: preserve exact blockers and ownership without
  opening material work.

Method:

1. re-attested S4, S3, and all three S3 review hashes/shapes;
2. read all 2377 S4 lines;
3. reproduced schema, enum, digest, ID, sequence, status, replay, CAS, maxima,
   authority, token, path, fixture, and NO-GO claims;
4. recomputed Base64url and wrapper arithmetic independently;
5. traced whether signed artifacts have an allowed artifact kind, signer,
   authority source, and exact request correlation;
6. compared the S4 closure clusters with the actual S3 Lane A findings;
7. treated all absent trust/catalog/Identity bytes as an empty accepted set; and
8. counted the final P1/P2 headings mechanically before freeze.

Static document closure is not source/runtime/production closure.

## 3. Executive verdict

S4 preserves these important invariants:

- acyclic core → protected core → signature → envelope → artifact;
- exactly six operations;
- token rotation only as `register/token_rotation`;
- per-operation `rw-s`/`r--s`;
- opaque, semantically neutral transport;
- first inner interpretation at authenticated Resolver/Cell;
- no authority from route, TLS, host, token, ID, environment, admin, test key,
  or unsigned file;
- no-create target/vault behavior and empty accepted sets while inputs are
  missing;
- variable opaque token length as a HAVEN resource bound, not an Apple claim;
- local absence remains `UNKNOWN`; and
- every production/material gate remains closed.

It also materially improves result schemas, status vocabulary, challenge
states, CAS ordering, authorization catalog structure, fixture naming, and
consumer ledgers.

Five P1 and two P2 findings remain:

1. status/error correlation and top-level authenticated-error binding are not
   byte-total;
2. exact challenge replay after expiry/compaction falls through the stated
   unique-index precedence;
3. subject-target binding and consent/catalog authority relationships remain
   under-specified;
4. the corrected maxima are still mathematically inconsistent;
5. permanent registration-ID retention contradicts the open Kjetil privacy
   decision;
6. the exact producer fixture list omits required S3/S4 core and boundary
   fixtures; and
7. repo/package path ownership remains ambiguous at `Package.swift`.

Exact result:

```text
P0: 0
P1: 5
P2: 2

S4 LANE A CELLPROTOCOL CONFORMANCE: NO-GO
S4 ORDERED COMPOSITION: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

## 4. Preserved acyclic envelope, six operations, and opaque transport

The ordered S3+S4 composition still has only forward edges:

```text
body core
  -> body digest
  -> signed intent
  -> intent artifact digest
  -> signed challenge
  -> challenge artifact digest
  -> signed request
  -> request artifact digest
  -> result/error/terminal-evidence core
  -> signed terminal artifact
```

For each signed artifact:

```text
core bytes
  -> SHA-256(core bytes)
  -> SignatureProtectedCore
  -> signature input
  -> signature
  -> SignatureEnvelope
  -> SignedArtifact
```

The deregistration tombstone still omits a later response digest. No signature
or envelope is included in the core it authenticates.

The exact operation enum remains:

```text
register
resolve
submit
status
revoke
deregister
```

Rotation remains:

```text
operation = register
mutationMode = token_rotation
```

Transport remains limited to opaque exact bytes and outer framing/security. It
cannot decode CJP-1, select a Cell, interpret an operation, create an error
artifact, inspect a token/selector/authority object, grant access, or mutate
state.

Independent verdict:

```text
ACYCLIC ENVELOPE: SUPPORTED
EXACT SIX OPERATIONS: SUPPORTED
TOKEN ROTATION IS NOT A SEVENTH OPERATION: SUPPORTED
OPAQUE TRANSPORT: SUPPORTED
WIRE OR TRANSPORT CREATES AUTHORITY: REJECTED
```

## 5. Reproduced scalar, digest, ID, and sequence rules

### 5.1 Scalars and digests

S4 binds `DigestHex`, exact UInt64 ranges, timestamp units, descriptor digests,
bounded target IDs, algorithm/key tokens, opaque payloads, explicit nullability,
and the exact unpadded Base64url formula.

The following equations reproduce:

```text
resultSHA256 =
  lowercaseHex(SHA256(exactResultCoreBytes))

correlationSHA256 =
  lowercaseHex(SHA256(exactMutationCorrelationCoreBytes))

terminalEvidenceSHA256 =
  lowercaseHex(SHA256(exactAdmissionTerminalEvidenceArtifactBytes))
```

Other artifact digests bind complete exact artifact bytes.

### 5.2 IDs

Reproduced exact lengths:

```text
adm1_  + Base64url(32 bytes) = 48 ASCII bytes
reg1_  + Base64url(32 bytes) = 48 ASCII bytes
int1_  + Base64url(32 bytes) = 48 ASCII bytes
chl1_  + Base64url(32 bytes) = 48 ASCII bytes
subm1_ + Base64url(32 bytes) = 49 ASCII bytes
sreg1_ + Base64url(32 bytes) = 49 ASCII bytes
exp1_  + Base64url(32 bytes) = 48 ASCII bytes
```

IDs remain locators/correlation values, never Identity, capability, owner, or
trust roots.

### 5.3 Server sequence

S4 lines 193–223 define:

- `PositiveUInt64`;
- a target-owner/authority-generation namespace;
- an issuer namespace for pre-target/issuer terminal artifacts;
- sequence starts at 1;
- new terminal artifact increments atomically;
- exact replay returns stored bytes without increment;
- failed transaction consumes no visible value;
- exhaustion makes the namespace unavailable;
- restart reads back;
- rollback below anchor fails closed; and
- a higher authority generation alone validates nothing.

That statically closes the missing S3 `serverSequence` semantics.

## 6. Result/status/error review

### 6.1 Success result family

S4 gives one exact success schema for each operation/status kind and closes:

- register disposition by mutation mode;
- resolve disposition/payload bound;
- submit ID namespace/generation;
- revoke/deregister new-request terminal dispositions; and
- exact replay as stored bytes rather than a newly generated
  `exact_replay` result.

`ResponseCore v2` binds exact result bytes, result digest, result schema,
operation, request, challenge, body, subject, target owner, and sequence.

### 6.2 Status matrix

The matrix explicitly distinguishes:

```text
subject_current_unknown
correlation_not_found
privacy_unknown
```

It lists active, revoked, deregistered, superseded, inconsistent, admission
pending/available, terminal indeterminate/unavailable, and generic
indeterminate combinations. Unknown combinations fail.

The matrix nevertheless contradicts its own correlation rule for a
registration-ID privacy negative; see `P1-S4-A-01`.

### 6.3 Authenticated error and terminal evidence

The new cores distinguish:

- authenticated denial/error;
- admitted terminal indeterminate evidence;
- admitted terminal unavailable evidence; and
- canonical/signature failure before requester authentication, which has no
  application artifact.

Transport constructs none of them. The accepted issuer/target-owner signer
must come from authority material. Missing material leaves the set empty.

The pre-target error shape does not bind the exact intent/request that caused
the error and the top-level artifact union is not stated with sufficient
precision; see `P1-S4-A-01`.

## 7. Oracle-safety reproduction

For an admission locator, these cases share one outward result:

- absent;
- another subject;
- another target; and
- proof insufficient before protected lookup.

The outward code is `privacy_unknown`; registration and nested-artifact fields
are null; logging uses one sanitized reason. `admission_not_found` is reserved
and non-emitting in composition version 2.

This is a sound static oracle-safety direction. Runtime timing/size/path
equivalence remains future evidence.

Wrong-subject registration ID is likewise externally `privacy_unknown`. No
alternate owner, generation, state, tombstone, or record count may escape.

## 8. Challenge/replay/compaction review

S4 improves the contract with:

- U1 challenge ID uniqueness;
- U2 requester/intent-ID uniqueness;
- U3 requester/nonce uniqueness;
- U4 exact intent-artifact digest uniqueness;
- an equality tuple;
- serialized collision precedence;
- fourteen persisted states;
- terminal indeterminate/unavailable evidence;
- per-state operation behavior;
- a compacted challenge tombstone; and
- no pressure-triggered deletion.

The exact replay path is still incomplete for an already-expired issuance
record. U4 only returns stored bytes for an active replay; the same expired
intent then passes the “different intent” U2/U3 checks and reaches an
unspecified uniqueness failure. That is `P1-S4-A-02`.

## 9. Registration lifecycle and privacy review

The undefined S3 `currentLogicalRegistration` is replaced by:

```text
subjectRegistrationDigest =
  SHA256(
    LP(UTF8("HAVEN-DEVICE-INGRESS-SUBJECT-REGISTRATION-V1"))
    || LP(UTF8(identityDomain))
    || LP(requesterDescriptorSHA256Raw)
    || LP(UTF8(targetCellID))
  )

subjectRegistrationKey =
  "sreg1_" + Base64url(subjectRegistrationDigest)
```

The partial unique predicate is exact for active/revoked rows. The global
registration-ID index prevents reuse. Lock order, CAS, state transitions,
concurrent enrollment serialization, collision retry, restart read-back, and
wrong-subject privacy are explicit.

That closes the S3 undefined-key/CAS defect as a technical concurrency model.
The statement that deregistered/historical IDs remain forever contradicts the
still-open retention decision; see `P1-S4-A-05`.

## 10. Authority, catalog, consent, and EMPTY-set gate

### 10.1 Fail-closed empty sets

S4 correctly states that missing/locked/changed/ambiguous/unverifiable
Identity, target, owner, signer, binding, key, catalog, or vault input yields:

```text
accepted requester descriptors = EMPTY
accepted target cells           = EMPTY
accepted target owners          = EMPTY
accepted response signers       = EMPTY
affected readiness              = UNAVAILABLE
```

Actual Agreement, Contract, Grant, Conditions, consent, authority, key,
rotation, revocation, time, rollback, and vault bytes are missing. The
production accepted catalog remains empty.

No static route, host, TLS certificate, environment, admin, ID, or test key can
populate it.

### 10.2 Typed subject/target relationship

S4 distinguishes requester subject, target Cell, target owner, and response
signer. It explicitly rejects treating the device subject as owner of the
server-side signing key and requires a pre-existing no-create binding.

However, the referenced signed `SubjectTargetBindingArtifact` has no allowed
artifact kind, signer rule, or signature/issuer relationship. This makes the
authority binding unconstructible without invention; see `P1-S4-A-03`.

### 10.3 Consent/catalog relationship

S4 defines exact member order for consent, catalog entry, catalog, and import
ledger and requires nested signature/use-time verification. But the consent
artifact does not bind the exact Agreement, Contract, Grant, Conditions, or
terms digests that it is later paired with. A tuple-compatible substitution can
therefore not be rejected from consent bytes alone. This is also
`P1-S4-A-03`.

## 11. Opaque token and legacy quarantine

### 11.1 Token bound

`apnsToken` is corrected to:

```text
1...4096 raw opaque bytes
canonical unpadded Base64url
```

The limit is explicitly a HAVEN allocation bound, not an Apple token-length
claim. Zero and 4097 reject. Generated test bytes only are permitted in
fixtures; no token/token hash may enter docs, logs, diagnostics, analytics,
crash reports, exports, UI, or accessibility.

Independent verdict:

```text
VARIABLE OPAQUE TOKEN PROTOCOL BOUND: SUPPORTED
APPLE TOKEN-LENGTH CLAIM: NONE
S4-P1-07: CLOSED FOR STATIC CONTRACT
```

### 11.2 Legacy plaintext

The startup inventory may inspect schema/path-class/size/count/protection
metadata, never token values. Any plaintext/WAL/backup/unknown state makes
delivery and registration mutation unavailable.

Only a separately reviewed storage primitive or fail-closed deactivation is
allowed. “Read then encrypt” in application code is forbidden. Logical SQL
deletion is not secure-disposal proof.

This is a coherent static quarantine plan. Storage implementation, disposal,
backup/restore, and retention evidence remain missing.

## 12. Independent maxima reproduction

### 12.1 Correct fixed wrapper bytes

The fixed literal lengths reproduce:

```text
SignatureEnvelopeFixed = 92
SignedArtifactFixed    = 92
OperationRequestFixed  = 84
```

The Base64url function and wrapper equations are correct.

### 12.2 Protected-core maximum does not reproduce

S4 permits:

```text
algorithm                  64 bytes
artifactKind               admission_terminal_evidence
coreSHA256                 64 bytes
keyID                      128 bytes
schema                     exact protected-core schema
signerDescriptorSHA256     64 bytes
```

`admission_terminal_evidence` is 27 bytes, not 26. Exact CJP-1 serialization of
the permitted maxima is:

```text
503 bytes
```

not `500`.

Therefore:

```text
B64(503) = 671
B64(1024) = 1366
SignatureEnvelopeMax = 92 + 671 + 1366 = 2129
```

not `2125`.

### 12.3 Response maximum does not reproduce

`TargetCellID` permits 128 printable ASCII bytes. Printable ASCII includes `"`
and `\`, which CJP-1 must escape. A 128-byte valid target ID can therefore
occupy 256 encoded JSON bytes.

With all other permitted ResponseCore maxima:

```text
ResponseCore fixed/max fields with empty result = 1170 bytes
B64(65536-byte result)                         = 87382 bytes
normal ResponseCore                            = 88552 bytes
maximum envelope                               = 2129 bytes
SignedArtifact(88552,2129)                     = 121001 bytes
```

The S4 limit is only `120830`. A value allowed by the scalar/schema rules is
therefore rejected by the claimed inclusive wrapper maximum. The nested
read-back maxima and boundary vectors derived from `120830` are also not exact.

This is `P1-S4-A-04`.

## 13. Producer path, package, fixture, and consumer ledger review

S4 adds:

- `Package.swift`;
- result/error/challenge/catalog source/test paths;
- a transport product with no `CellBase` dependency;
- exact server/client consumer ledgers;
- named fixture families; and
- manifest drift/local-signing rejection.

These are material improvements. Two P2 defects remain:

- the exact filename inventory does not cover every S3/S4 core and every
  boundary vector required by the normative test plan; and
- `Package.swift` is unqualified across repositories and assigned in two
  ownership contexts.

They are recorded as `P2-S4-A-01` and `P2-S4-A-02`.

## 14. Findings

### P0

No P0 finding was found in this static document. No material action occurred.

### P1

#### P1-S4-A-01 — Status correlation and authenticated-error binding are not byte-total

Locations:

- S4 lines 225–249;
- S4 lines 428–515;
- S4 lines 517–632; and
- S4 lines 1494–1532.

Two concrete contradictions/gaps remain.

First, `StatusBodyCore` permits a registration selector with a correlation. If
the registration ID is absent or belongs to another subject, the outward result
must be `privacy_unknown`. The matrix row for registration
`privacy_unknown` fixes:

```text
correlationDisposition = not_requested
correlationSHA256 = null
```

but the additional exact rule says:

```text
correlationSHA256 is non-null iff a canonical correlation was requested
```

A canonical correlation was requested in this case. The same request therefore
requires both null and non-null. Ignoring the correlation would violate “iff”;
echoing its digest would violate the privacy row and could create a shape
oracle.

Second, `AuthenticatedErrorCore` permits a pre-target error with null
admission/request/target fields, but provides no `intentArtifactSHA256` or
challenge digest. The direct signed error can therefore not be correlated
uniquely to the exact challenge/operation attempt. S4 also does not state one
closed top-level successful-operation output union distinguishing a signed
ResponseArtifact from direct AuthenticatedErrorArtifact and
AdmissionTerminalEvidenceArtifact with exact client-expectation rules.

Impact:

- a valid status request has no unique canonical result;
- an authenticated pre-target error is replayable across attempts with the same
  broad tuple unless a consumer invents correlation;
- S4-P1-01 and the S3 Lane A result/status/error finding remain partial.

Required correction:

- define the privacy-unknown-with-correlation row and whether the digest is
  suppressed by an explicit exception or returned in an oracle-safe way;
- bind pre-target error to exact intent/challenge/request phase identifiers;
- freeze the top-level signed application-artifact union and expectation
  verification for every variant; and
- add exact wrong-ID-with-correlation and cross-attempt error replay fixtures.

Verdict: **OPEN P1**.

#### P1-S4-A-02 — Exact challenge replay after expiry falls through collision precedence

Locations:

- S4 lines 634–713;
- S4 lines 715–874; and
- S4 lines 2040–2053.

Collision precedence says:

1. U4 exact intent digest returns stored challenge only for an **active**
   replay;
2. U2 conflicts only if the same requester/intent ID has a **different** intent;
3. U3 conflicts only if the same requester/nonce has a **different** intent;
4. a fresh challenge ID is generated/inserted; and
5. other uniqueness failures commit nothing.

For byte-identical intent replay after `issued_expired_unused` or a compacted
unused tombstone:

- U4 does not take the active-replay branch;
- U2/U3 see no different intent;
- fresh insertion violates existing U2/U3/U4;
- “other uniqueness failure” gives no exact error/artifact/status.

The later state table says an exact expired request returns
`challenge_expired`, but the earlier mandatory precedence cannot reach that
result. Compacted tombstone nullability/state-to-field relationships are also
not fully tabulated.

Impact:

- restart/expiry behavior is not deterministic;
- implementations can return conflict, unavailable, expired, or retry a new
  challenge;
- S4-P1-02 remains partial.

Required correction:

- check U4 before active-state branching and map every matched state to an exact
  stored challenge/error/evidence result;
- define exact compacted tombstone nullability by terminal kind/state;
- define outward behavior for every U1/U2/U3/U4 same/different combination; and
- add issuance replay vectors for active, expired, and every compacted state.

Verdict: **OPEN P1**.

#### P1-S4-A-03 — Subject-target binding and consent/catalog authority relationships are incomplete

Locations:

- S4 lines 1063–1192;
- S4 lines 1194–1340; and
- S4 lines 2241–2247.

`resolveExistingSubjectTarget` returns a signed
`SubjectTargetBindingArtifact`, but S4 defines only
`SubjectTargetBindingCore`. The allowed artifact-kind extension omits
`subject_target_binding`, and no exact signer, issuer, signature authority,
rotation, revocation, or catalog-link rule is supplied for that artifact.
Consequently the typed no-create binding cannot be constructed or verified from
the frozen bytes.

`ConsentArtifactCore` binds subject, tuple, time, and target, but not the exact:

- Agreement artifact digest;
- Contract artifact digest;
- Grant artifact digest;
- Conditions artifact digest; or
- consent terms/notice digest.

The catalog entry later pairs the consent with all four authority artifacts.
Tuple equality alone cannot prove the subject consented to those exact bytes,
so a catalog signer could substitute a different tuple-compatible authority
package. “Verify consent relationship” does not define the missing relation.

`consentID`, consent generation, catalog `entryID`, entry generation, and
duplicate “tuple/generation” namespaces are also not closed.

The current production accepted sets remain empty, so this creates no current
authority. It prevents static closure and must not be filled by guessing.

Required correction:

- add exact subject-target binding artifact kind, signer, trust/catalog link,
  validity, rotation, and revocation rules;
- bind consent to exact authority/conditions and terms digests;
- define consent/entry ID and generation namespaces and replay/revocation;
- add substitution, stale consent, wrong owner, wrong signer, rollback, and
  missing-input fixtures.

Verdict: **OPEN P1**.

#### P1-S4-A-04 — Inclusive wrapper/maxima algebra remains inconsistent

Locations:

- S4 lines 134–191;
- S4 lines 251–296;
- S4 lines 957–1061; and
- S4 lines 2071–2079.

The independent arithmetic in section 12 proves two contradictions:

```text
maximum permitted SignatureProtectedCore = 503, not 500
maximum permitted normal SignedArtifact  = 121001, not 120830
```

The first arises from exact allowed member maxima and the 27-byte
`admission_terminal_evidence` kind. The second also accounts for mandatory JSON
escaping of a valid 128-byte printable `TargetCellID`.

The nested admission-readback values and accept/reject fixture names inherit
the wrong normal response maximum. A producer following scalar rules can
produce bytes a consumer following wrapper limits must reject.

Required correction:

- derive every core limit from exact worst-case escaped CJP-1 bytes;
- make protected/envelope/normal/nested maxima compatible;
- constrain identifier alphabets if escaping is not intended;
- regenerate all dependent formulas; and
- name boundary vectors for semantic values that can actually attain each
  accepted maximum.

Verdict: **OPEN P1**.

#### P1-S4-A-05 — Permanent registration-ID retention pre-decides Kjetil's open privacy decision

Locations:

- S4 lines 897–916;
- S4 lines 2197–2225; and
- inherited S3 deregistration/tombstone retention contract.

S4 states:

```text
The global registration-ID index includes active, revoked, deregistered,
and historical rows forever in composition version 2.
```

`MBI-PRIVACY-RETENTION-01` simultaneously leaves tombstone retention duration,
compaction/deletion, restore exposure, legitimate purpose, and disclosure to
Kjetil. A deregistered registration ID is part of the minimal subject-linked
tombstone/non-resurrection evidence. Retaining its row/index forever is an exact
retention-duration decision.

The protocol may require non-resurrection evidence while retained, but it
cannot silently choose indefinite storage while declaring the duration open.

Required correction:

- make deregistered/historical ID-index retention conditional on the reviewed
  privacy decision;
- specify a privacy-approved non-resurrection mechanism after deletion, or
  state that enrollment remains unavailable when evidence can no longer prove
  no reuse;
- distinguish namespace collision safety from subject-linked row retention; and
- add deletion/restore/non-resurrection vectors after the chosen duration.

Verdict: **OPEN P1 / GENUINE KJETIL DECISION PRESERVED**.

### P2

#### P2-S4-A-01 — Exact producer fixture inventory still omits required core and boundary files

Locations:

- S4 lines 1776–1826;
- S4 lines 1998–2115; and
- S4 lines 2297–2322.

The filename list is far better than S3, but it does not give exact paths for
all normative producer objects, including:

- IntentCore, ChallengeCore, RequestCore, ResponseCore;
- SignatureProtectedCore, SignatureEnvelope, SignedArtifact;
- each operation body core and MutationCorrelationCore;
- SubjectTargetBindingCore/Artifact and typed reference cores;
- AuthorizationCatalogEntryCore and import-ledger core;
- compacted challenge tombstone;
- every authenticated-error code/phase/retry/nullability row;
- every status field-combination boundary;
- signature 1023/1024/1025, envelope 2124/2125/2126, each core max, and
  operation-request boundary files required by section 9.3.

The listed normal/admission response boundary filenames also encode maxima that
fail `P1-S4-A-04`.

Verdict: **OPEN P2**.

#### P2-S4-A-02 — `Package.swift` repo and ownership are not path-exact

Locations:

- S4 lines 1770–1826;
- S4 lines 1958–1969; and
- S4 lines 1971–1996.

Under “CellProtocol producer,” the relative path `Package.swift` is listed as a
future path but said to be development-admin collision-owned. Under
development-admin collision paths, another unqualified `Package.swift` appears.
The document itself resides in Binding and spans CellProtocol, CellScaffold,
and Binding repositories, each of which can have a package manifest.

Without exact repository/worktree identity, the two entries cannot be proven
to name the same file or owner. The intended CellProtocol product/target graph
is clear, but the byte owner/path is not.

Verdict: **OPEN P2**.

## 15. S3 Lane A finding disposition

| S3 Lane A finding | Independent S4 verdict | Basis |
|---|---|---|
| `P1-S3-A-01` result/status/error incomplete | **PARTIAL / OPEN** | Success schemas/digests/sequence largely close; status correlation and pre-target error binding remain P1-S4-A-01 |
| `P1-S3-A-02` challenge replay non-total | **PARTIAL / OPEN** | Indexes/states/evidence improve; expired exact issuance replay falls through P1-S4-A-02 |
| `P1-S3-A-03` undefined current registration key | **CLOSED FOR STATIC CAS MODEL / PRIVACY RETENTION OPEN** | Derived key, partial predicate, locks, CAS, concurrency are exact; indefinite deregistered-ID retention is P1-S4-A-05 |
| `P1-S3-A-04` maxima inconsistent | **OPEN** | Corrected arithmetic still fails exact permitted values; P1-S4-A-04 |
| `P2-S3-A-01` fixture inventory incomplete | **PARTIAL / OPEN** | Many paths added; required cores/boundaries remain P2-S4-A-01 |
| `P2-S3-A-02` SwiftPM boundary incomplete | **PARTIAL / OPEN** | Target graph exists; repository/path owner ambiguity remains P2-S4-A-02 |

## 16. Consolidated S4 cluster disposition

### P1 clusters

| Cluster | Independent verdict |
|---|---|
| `S4-P1-01` byte-total result/status/error | **PARTIAL / OPEN** — P1-S4-A-01 |
| `S4-P1-02` total challenge indexes/replay | **PARTIAL / OPEN** — P1-S4-A-02 |
| `S4-P1-03` subject-registration key/CAS | **STATIC CONCURRENCY SHAPE CLOSED / PRIVACY PARTIAL** — P1-S4-A-05 |
| `S4-P1-04` satisfiable maxima | **OPEN** — P1-S4-A-04 |
| `S4-P1-05` typed requester/target/owner/signer | **PARTIAL / OPEN** — binding artifact missing in P1-S4-A-03 |
| `S4-P1-06` catalog/consent | **PARTIAL / OPEN** — consent substitution relationship in P1-S4-A-03 |
| `S4-P1-07` variable opaque token | **CLOSED FOR STATIC CONTRACT** |
| `S4-P1-08` legacy plaintext quarantine | **CLOSED FOR STATIC PLAN / RUNTIME-DISPOSAL EVIDENCE MISSING** |
| `S4-P1-09` durable response expectation | **CLOSED FOR STATIC CLIENT PLAN / RUNTIME EVIDENCE MISSING** |
| `S4-P1-10` total Binding reducer | **CLOSED FOR STATIC CLIENT PLAN / PRIVACY DECISION AND RUNTIME EVIDENCE MISSING** |
| `S4-P1-11` CellApple vault continuity | **CLOSED FOR STATIC NO-CREATE PLAN / IDENTITY INPUTS MISSING** |

### P2 clusters

| Cluster | Independent verdict |
|---|---|
| `S4-P2-01` producer paths/package/fixtures | **PARTIAL / OPEN** — P2-S4-A-01/02 |
| `S4-P2-02` server owners/consumer ledger | **CLOSED FOR STATIC PATH PLAN / SOURCE EVIDENCE MISSING** |
| `S4-P2-03` Binding paths/negative evidence | **CLOSED FOR STATIC PATH PLAN / SOURCE EVIDENCE MISSING** |

No static closure authorizes implementation.

## 17. Missing inputs and preserved gates

### 17.1 Privacy

```text
MBI-PRIVACY-RETENTION-01: OPEN
OWNER: Kjetil
DECISION CREDIT HERE: NONE
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

S4's indefinite registration-ID statement must not count as deciding this MBI.

### 17.2 Authority and Identity

Actual requester/issuer/owner descriptors, keys, algorithms, rotation records,
subject-target binding, owner-signed authority/authorization catalog,
Agreement, Contract, Grant, Conditions, consent, revocation ledger, trusted
time, rollback anchor, vault continuity, and Identity cutover evidence are
missing.

Therefore:

```text
accepted authority inputs = EMPTY
affected readiness = UNAVAILABLE
Identity cutover = SEPARATE / NO-GO
```

### 17.3 Framing, signing, and integration

```text
MBI-TRANSPORT-FRAMING-01: MISSING TECHNICAL INPUT
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
```

The bundle/topic/origin literals prove no entitlement, profile, archive,
provider acceptance, device delivery, or callback.

### 17.4 Action gates

```text
SOURCE: CLOSED / NO-GO
MATERIAL EDITS: CLOSED / NO-GO
GIT: CLOSED / NO-GO
DEPENDENCY RESOLUTION: CLOSED / NO-GO
BUILD: CLOSED / NO-GO
TEST: CLOSED / NO-GO
NETWORK: CLOSED / NO-GO
PORTAL: CLOSED / NO-GO
SIGNING: CLOSED / NO-GO
DEVICE: CLOSED / NO-GO
APNS: CLOSED / NO-GO
SECRETS: CLOSED / NO-GO
IDENTITY ACTION: CLOSED / NO-GO
STAGING: CLOSED / NO-GO
DEPLOYMENT: CLOSED / NO-GO
INTEGRATION: CLOSED / NO-GO
NEXT PHASE: CLOSED / NO-GO
PRODUCTION: CLOSED / NO-GO
```

## 18. Exact smallest static successor scopes

No successor is authorized by this review. If development admin later opens a
document-only correction, the smallest independent scopes are:

1. status privacy/correlation row plus exact signed terminal-artifact union and
   pre-target request binding;
2. U1...U4 expired/compacted replay precedence and compacted nullability;
3. signed SubjectTargetBindingArtifact plus consent-to-exact-authority/terms
   digests and ID/generation rules;
4. escape-aware scalar/core/envelope/normal/nested maxima and reachable boundary
   vectors;
5. privacy-owner decision for deregistered/historical ID retention;
6. complete exact producer fixture filenames and repository-qualified package
   path ownership; then
7. a new independent exact-byte review by a reviewer distinct from the
   correction author.

Identity, framing, Apple, source, build, network, device, APNS, staging,
integration, and production remain outside those scopes.

## 19. Mechanical finding-count reconciliation

Mechanical heading rules for this artifact:

```text
P1 heading regex: ^#### P1-S4-A-
P2 heading regex: ^#### P2-S4-A-
```

Frozen count:

```text
P0: 0
P1: 5
P2: 2
```

Every executive, findings, and final count in this review uses `0/5/2`.

## 20. Final decision

```text
S4 LANE A INDEPENDENT EXACT-BYTE REVIEW: COMPLETE
REVIEWED S4 SHA-256:
  99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa
REVIEWED S4 SHAPE:
  2377 lines / 79288 bytes

P0: 0
P1: 5
P2: 2

ACYCLIC ENVELOPE: SUPPORTED
WIRE OPERATIONS: EXACTLY SIX
TOKEN ROTATION: REGISTER MUTATION ONLY
TRANSPORT: OPAQUE / NON-AUTHORITATIVE
VARIABLE TOKEN BOUND: HAVEN RESOURCE BOUND / NOT APPLE CLAIM
MISSING AUTHORITY INPUTS: ACCEPTED SET EMPTY

RESULT/STATUS/ERROR: PARTIAL / NO-GO
CHALLENGE REPLAY: PARTIAL / NO-GO
REGISTRATION CAS: STATIC SHAPE CLOSED / PRIVACY RETENTION OPEN
AUTHORITY CATALOG/CONSENT: PARTIAL / NO-GO
MAXIMA: NO-GO
FIXTURE/PACKAGE PATHS: PARTIAL / NO-GO

MBI-PRIVACY-RETENTION-01: OPEN / KJETIL
MBI-TRANSPORT-FRAMING-01: MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING

S4 LANE A CELLPROTOCOL CONFORMANCE: NO-GO
S4 ORDERED COMPOSITION: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

No raw token, token hash, private key, secret, unredacted payload, or production
Identity material was read, displayed, or stored. The review stops after
freezing this one owned artifact.
