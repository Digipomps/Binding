# APNS S4 Normative Composition Contract Correction — Binding Client Conformance Independent Review

Date: 2026-07-25 local / 2026-07-24 UTC  
Review lane: S4 Lane C, Binding client conformance  
Reviewer role: distinct from the S4 author  
Review type: independent exact-byte static review  
Source/runtime/test credit: none

## 1. Scope, sole output, and stop conditions

The sole reviewed correction is:

```text
Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md
```

The sole output is:

```text
Documentation/APNS_S4_Normative_Composition_Contract_Correction_Binding_Client_Conformance_Independent_Review_2026-07-24.md
```

The output path was re-attested absent immediately before writing.

This review:

- evaluates only the ordered static pair `S3 exact bytes -> S4 exact bytes`;
- gives no self-review credit to the S4 author;
- gives no source, runtime, fixture-generation, build, test, deployment,
  signing, APNS, or production credit;
- does not inspect a raw APNS token, private key, bearer credential, shared
  server secret, or other secret;
- does not modify source, project, dependency, Git, portal, Identity, device,
  staging, deployment, or production state;
- authorizes no successor phase.

Identity cutover, transport framing/trust material, Apple production evidence,
integrated output, and the Kjetil-owned privacy decision remain separate.

## 2. Exact S4 target re-attestation

Re-attested at:

```text
UTC:   2026-07-24T23:06:42Z
local: 2026-07-25T01:06:42+0200 CEST
```

| Property | Exact value |
|---|---|
| Path | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md` |
| SHA-256 | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` |
| Lines | 2377 |
| Bytes | 79288 |

Required exact shape:

```text
99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa
2377 lines
79288 bytes
```

## 3. Immutable S3 lineage re-attestation

The four immutable S3 artifacts were rehashed and reshaped locally:

| Role | Path | SHA-256 | Lines | Bytes | Frozen result |
|---|---|---|---:|---:|---|
| S3 contract | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 | author proposal |
| Lane A review | `Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 | `0/4/2`, NO-GO |
| Lane B review | `Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 | `0/7/2`, NO-GO |
| Lane C review | `Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 | `0/3/2`, NO-GO |

The stale inherited `0/2/1` summary is not used. The actual immutable review
finding counts are exactly:

```text
A = 0/4/2
B = 0/7/2
C = 0/3/2
```

The fourteen P1 observations are not automatically fourteen independent
defects. S4's eleven-P1/three-P2 cluster consolidation is treated only as an
author mapping; this review independently evaluates Lane C closure.

## 4. Mechanical finding-count rule

Only headings matching these exact forms count as findings:

```text
### P0-S4-C-<NN>
### P1-S4-C-<NN>
### P2-S4-C-<NN>
```

This frozen review contains:

```text
P0: 0
P1: 4
P2: 2
```

Every later summary and final verdict repeats exactly `0/4/2`.

## 5. Static conformance that S4 materially improves

The following are independent static passes or correctly preserved boundaries.
They are not source/runtime/production proof.

### 5.1 Acyclic envelope and exact operation surface

S4 lines 49–86 preserve:

- CJP-1 canonical bytes and `LP` framing;
- core → signature envelope → signed artifact;
- body → intent → challenge → request → response;
- exactly `register`, `resolve`, `submit`, `status`, `revoke`, `deregister`;
- token rotation only as `register` with `mutationMode=token_rotation`;
- status `r--s`, mutations `rw-s`;
- opaque, byte-preserving, non-authoritative transport;
- Resolver/Cell/Agreement/Contract/Grant as the semantic authority boundary.

Verdict:

```text
ACYCLIC ENVELOPE: STATIC PASS
SIX WIRE OPERATIONS: STATIC PASS
ROTATION AS REGISTER MODE: STATIC PASS
OPAQUE TRANSPORT: STATIC PASS
```

### 5.2 Planning identifiers and evidence separation

S4 lines 88–107 preserve:

```text
identity domain = domain:device:notification-callback
purpose         = purpose://access.audit.privacy/device-notification-callback
audience        = haven.digipomps.org
origin          = https://haven.digipomps.org
bundle          = org.digipomps.haven
APNS topic      = org.digipomps.haven
environment     = production
```

The literals correctly prove no Apple profile, entitlement, signing, provider
acceptance, delivery, callback, Identity, or deployment fact.

### 5.3 Variable opaque token and zero-leakage contract

S4 lines 1346–1372 replace the fixed-length token assumption with:

```text
1...4096 raw opaque bytes
canonical unpadded Base64url
```

The `4096` value is explicitly a HAVEN resource bound, not an Apple token-size
claim. Reproduced boundary arithmetic:

```text
B64(4095) = 5460
B64(4096) = 5462
B64(4097) = 5463
```

Zero bytes and 4097 bytes reject. Generated non-token test bytes are required
for fixtures. Raw token/token hash is forbidden in documents, fixtures,
evidence, logs, diagnostics, analytics, crash reports, exports, UI, and
accessibility output.

Verdict:

```text
VARIABLE OPAQUE TOKEN: STATIC PASS
RAW TOKEN/TOKEN-HASH LEAKAGE: FORBIDDEN
APPLE LENGTH CLAIM: NONE
```

### 5.4 Status/oracle matrix

S4 lines 477–515 make absent, wrong-subject, wrong-target, and unproved
admission lookup outwardly identical as `privacy_unknown`.

S4 lines 517–632 define a closed field/nullability matrix. In particular:

```text
subject_current_unknown != correlation_not_found != privacy_unknown
```

`admission_not_found` is reserved and non-emitting in composition version 2.
Nested admission artifacts are typed as exact signed response, authenticated
error, or terminal evidence.

Verdict:

```text
STATUS FIELD MATRIX: STATIC PASS
ADMISSION ABSENT/WRONG-SUBJECT ORACLE: STATIC PASS
LOCAL ABSENCE AS SERVER NEGATIVE: FORBIDDEN
```

### 5.5 Recomputed nested maxima

The wrapper constants at S4 lines 1020–1076 reproduce:

```text
SignatureEnvelopeFixed = 92
SignedArtifactFixed    = 92
OperationRequestFixed  = 84
```

Recomputed:

```text
B64(500)    = 667
B64(1024)   = 1366
Envelope    = 92 + 667 + 1366 = 2125
B64(2125)   = 2834

B64(65536)  = 87382
normal ResponseCore = 1046 + 87382 = 88428
B64(88428)  = 117904
normal signed response = 92 + 117904 + 2834 = 120830

B64(120830) = 161107
admission StatusResultCore = 566 + 161107 = 161673
B64(161673) = 215564
admission-readback ResponseCore = 1046 + 215564 = 216610
B64(216610) = 288814
admission-readback signed response =
  92 + 288814 + 2834 = 291740

B64(24772) = 33030
OperationRequest(65536,24772) =
  84 + 87382 + 33030 = 120496
```

The equations are algebraically satisfiable. Whether Binding is forced to
consume the exact boundary fixtures is addressed separately under
P2-S4-C-02.

### 5.6 Authoritative deregister/local cleanup order

S4 lines 1679–1710 correctly require:

1. verified authoritative response, tombstone, and pre-send expectation;
2. required fresh signed status;
3. `finalization_pending`;
4. local token/active-binding erasure;
5. read-back of erasure;
6. owner-permitted minimal tombstone retention;
7. tombstone transaction read-back;
8. truthful UI publication;
9. terminal local state.

Local erase before verified authoritative commit is forbidden. Revoke never
executes deregister cleanup. This statically closes the ordering defect, but
production deregister remains NO-GO until `MBI-PRIVACY-RETENTION-01` is decided
and independently reviewed.

## 6. P0 adjudication

No P0 finding was identified. Every newly identified defect remains fail-closed
because S4 preserves source, Identity, signing, APNS, deployment, and production
NO-GOs.

## 7. P1 findings

### P1-S4-C-01 — ResponseExpectationCore does not cover the complete authenticated artifact family

#### Evidence

S4 lines 227–249 state that every operation can return:

- its exact success ResultCore in a signed ResponseCore;
- a signed `authenticated-error-core.v1`; or
- a signed `admission-terminal-evidence-core.v1`.

Admission status at lines 539–546 can return any of those historical artifact
kinds.

ResponseExpectationCore at lines 1443–1492 contains exactly one:

```text
expectedResultSchema
expectedResponseSchema
responseSigner
```

The historical verifier at lines 1515–1532 describes only verification of
“nested historical response bytes.” It does not define:

- allowed alternate artifact kinds per operation/phase;
- expected signer role for pre-target issuer error versus target-owner error;
- whether an authenticated error is standalone or a ResultCore inside
  ResponseCore;
- how nullable admission/request/target fields are expectation-bound;
- how `retryClass` and `errorCode` map to a durable client state;
- how terminal evidence binds the issuer, admission, request, operation, and
  journal without being mistaken for a response;
- a rule forbidding error/evidence artifacts from satisfying success/current
  truth.

The common reducer at lines 1638–1649 has no
`authenticated_error_verified` or `terminal_evidence_verified` transition.
It moves only toward `historical_response_verified` or broad blocked states.

#### Impact

A Binding verifier cannot tell from the pre-send expectation which exact
signed artifact families are admissible after a live response or admission
read-back. Implementations can diverge by:

- rejecting valid fail-closed errors and leaving journals permanently
  ambiguous;
- treating a signed error as the expected response;
- using the wrong signer role;
- mapping `status_only`, `after_authority_recovery`, or `after_user_action`
  inconsistently;
- allowing terminal evidence to imply target success/failure or retry.

The fact that these artifacts are individually signed does not make their
client semantics self-defining.

#### Smallest safe static successor

Extend the document-only expectation/reducer contract with:

1. an exact per-operation/per-phase allowed artifact-kind table;
2. exact expectation fields or digest-bound alternate-expectation cores for
   authenticated error and terminal evidence;
3. exact issuer-versus-target-owner signer rules;
4. exact nullable-field and request/admission binding rules;
5. total reducer transitions for every `errorCode`, `retryClass`, and terminal
   evidence code;
6. explicit assertions that neither family establishes operation success or
   current registration truth.

No source action is authorized.

**Closure verdict:** **OPEN P1 / RESPONSE EXPECTATION FAMILY NOT TOTAL**.

### P1-S4-C-02 — OperationJournal extensions and cross-process single-flight are not exact or mutually serializing

#### Evidence

OperationJournalCore at S4 lines 1534–1555 has twelve exact members. It has no:

```text
extensionSchema
extensionBytes
extensionSHA256
operationResourceKey
vaultBindingSHA256
transactionSequence
```

Lines 1557–1567 say operation-specific correlation is “separately typed,
digest-bound,” but define only prose field groups. No extension schema, member
order, nullability, encoding, maximum, digest equation, or binding member in
OperationJournalCore is supplied.

The single-flight key at lines 1569–1588 includes:

```text
operation
statusKind
```

Therefore two operations against the same logical resource produce different
keys. Examples:

- `register` token rotation versus `revoke`;
- `register` versus `deregister`;
- `revoke` versus `deregister`;
- `resolve` versus `submit` for the same ticket lineage;
- registration `status` finalization versus a concurrent mutation.

The key also uses undefined `selectorOrSubjectRegistrationKeyBytes`; it does not
freeze which exact byte representation applies to resolve/submit, null
registration IDs, admission status, or first enrollment.

Finally, “one descriptor-relative file/store lock plus one durable CAS row”
does not define:

- the one canonical store shared by app and extensions;
- lock ordering across multiple affected resources;
- descriptor/name/inode binding before and after acquisition;
- durable transaction/rollback-anchor sequence;
- file and parent-directory sync or an equivalent database durability mode;
- crash boundaries between expectation, extension, journal, CAS, and
  `send_started_ambiguous`.

The exact S4 document contains no occurrence of `fsync`, `F_FULLFSYNC`,
`openat`, `renameat`, `unlinkat`, `inode`, or `nlink`.

#### Impact

The client cannot encode or verify the claimed correlation extension
byte-identically. Worse, different processes may legally acquire different
keys and cross the network boundary with conflicting register/revoke/
deregister or resolve/submit operations.

A process crash after ordinary write/read-back but before stable-media commit
can lose the expectation/journal while the request was sent. Path replacement
or two non-canonical stores can split the purported single flight.

Server CAS may reject one mutation, but it cannot reconstruct the client's
lost pre-send expectation or repair conflicting local UI/evidence transitions.

#### Smallest safe static successor

Define:

1. one exact canonical union or six exact operation-extension schemas;
2. exact extension bytes and digest members inside OperationJournalCore;
3. a conflict-class resource key that intentionally serializes all mutually
   exclusive operations, including resolve↔submit and
   register↔revoke↔deregister;
4. exact selector/resource bytes for every operation and status kind;
5. one hardened shared-store/lock/CAS transaction contract with
   descriptor-relative name binding, metadata checks, stable-media commit,
   parent/rollback anchor, and restart reconciliation;
6. crash and subprocess races at every expectation/extension/journal/
   send-boundary commit.

No implementation or test execution is authorized.

**Closure verdict:** **OPEN P1 / DURABLE JOURNAL AND SINGLE-FLIGHT CONTRACT NOT COMPOSABLE**.

### P1-S4-C-03 — The reducer has no safe `local_unknown` operation gate or crash-total resolve delivery

#### Evidence

The common graph at S4 lines 1616–1663 permits:

```text
local_unknown -> challenge_preparing
```

without an operation-specific precondition.

Vault/evidence continuity at lines 1759–1761 instead says missing, changed,
ambiguous, or rejected vault/evidence sets:

```text
local state = UNKNOWN
affected readiness = unavailable
```

Those clauses leave two incompatible interpretations:

1. `local_unknown` may prepare any operation, which permits register, revoke,
   deregister, resolve, or submit without first adjudicating server current
   state; or
2. all readiness is unavailable, including the signed subject-current status
   operation required to recover safely from empty local evidence.

The graph does not freeze the safe distinction:

```text
valid current vault + absent local evidence
  -> only fresh signed subject_current status may adjudicate

invalid/missing/locked vault or authority
  -> no operation
```

The same reducer calls resolve terminal truth “verified payload delivered once”
at lines 1670–1674 but gives no atomic handoff/outbox/acknowledgement boundary.
If it marks `finalized_resolve` after exposing the volatile payload, a crash can
redeliver it. If it marks finalized before exposure, a crash can lose it. The
contract forbids durable unredacted payload storage, so an exact-once handoff
needs a separately defined idempotent consumer boundary or a weaker truthful
delivery claim.

Operation-specific preconditions for consent, active registration, ticket
lineage, stop intent, and status freshness are also absent from the common
transition graph.

#### Impact

Binding cannot implement one deterministic fail-closed reducer:

- empty local evidence can either deadlock recovery or open a mutation gate;
- copied/rejected evidence can reach the same state as benign local absence
  with no different permitted next action;
- resolve can be duplicated or lost across a crash while claiming “delivered
  once”;
- per-operation UI truth can vary between conforming implementations.

#### Smallest safe static successor

Freeze a state/precondition matrix that separates:

- valid vault plus absent evidence;
- invalid/missing/locked/replaced vault;
- historical evidence without fresh current status;
- pending/ambiguous operation evidence;
- fresh subject-current status.

For every state, enumerate exactly which of six operations and two status kinds
may begin. Local absence must allow only the authenticated discovery/status
path until fresh truth opens another gate.

For resolve, define either:

- an idempotent, durable, sanitized handoff receipt keyed by admission/ticket
  lineage; or
- explicit at-most-once/at-least-once behavior without claiming exact-once
  delivery.

**Closure verdict:** **OPEN P1 / CLIENT REDUCER PRECONDITIONS AND RESOLVE FINALIZATION NOT TOTAL**.

### P1-S4-C-04 — Vault/evidence continuity cannot yet prove copied-device rejection or crash durability

#### Evidence

S4 lines 1712–1768 correctly require:

- exactly one existing persistent CellApple vault;
- `domain:device:notification-callback`;
- no-create and no ephemeral fallback;
- descriptor/key/build/vault/evidence rebind;
- copied/restored/legacy rejection;
- local absence as `UNKNOWN`;
- no bearer/shared server secret.

VaultBindingCore at lines 1731–1746 contains only:

```text
approvedBuildProvenanceSHA256
identityDomain
requesterDescriptorSHA256
schema
signingKeyFingerprintSHA256
vaultInstanceID
```

`vaultInstanceID` is explicitly not authority. Every listed field can be copied
with a restored vault/evidence bundle unless a separate non-exportable device
proof and rollback policy binds it.

Lines 1748–1757 require an “evidence MAC/signature” and local monotonic/
rollback anchor, but define no:

- signed/MACed evidence-envelope schema;
- signer/MAC key provenance;
- non-exportable device/vault binding;
- key rotation/recovery relation;
- anti-rollback counter/anchor schema and verification input;
- exact behavior when legitimate OS restore preserves or changes keys;
- byte binding from that proof into VaultBindingCore or
  ResponseExpectationCore.

Lines 1766–1768 acknowledge that recovery proof and cutover evidence are
missing. That correctly preserves production NO-GO, but the static consumer
interface is still not constructible: a later Identity owner has no exact
artifact slot to fill.

#### Impact

Checking a copied identifier, key fingerprint, build digest, and evidence MAC
with copied key material does not prove that evidence remained on the same
device/vault instance. Conversely, rejecting every restore without an exact
policy can strand a legitimate user while still leaving server state active.

The client must remain unavailable, which is safe, but S3 C's vault-continuity
finding is not statically closed.

#### Smallest safe static successor

The Identity/vault owner crossed with Lane C must define, document-only:

1. exact continuity-evidence artifact schema and signature/MAC input;
2. non-exportable key or approved device/vault proof source;
3. rollback/monotonic anchor schema and durability contract;
4. restore, key rotation, device replacement, and evidence-copy decisions;
5. exact digest field added to VaultBindingCore and the expectation;
6. fail-closed mapping for every missing, stale, copied, rollback, and
   legitimate recovery case.

Identity cutover itself remains separate and unauthorized.

**Closure verdict:** **OPEN P1 / VAULT CONTINUITY PROOF INPUT NOT CONSTRUCTIBLE**.

## 8. P2 findings

### P2-S4-C-01 — The path ledger assigns `project.pbxproj` two incompatible owners

#### Evidence

S4 lines 1958–1966 say only a later development-admin integration owns:

```text
Binding.xcodeproj/project.pbxproj
```

S4 lines 1971–1987 then introduce a list headed:

```text
Apple release owner, not Lane C
```

and list the same project file again.

Unlike `Package.swift`, whose collision ownership is clarified in section
17.1, the project file has no exact one-owner/final-byte rule plus separately
named mandatory reviewer relationship. The same path is simultaneously
development-admin-owned and Apple-release-owner/no-touch.

The Binding path list also has no exact named owner path for the operation-
specific journal extension schemas identified in P1-S4-C-02. They may fit in
the state-machine or evidence-store files, but the document does not assign
that responsibility.

#### Impact

A later source owner cannot determine who may produce final project membership
bytes and who only reviews/no-touches them. Two independently correct lanes can
both treat the project file as exclusively theirs or both refuse it.

#### Smallest safe static successor

Freeze one row for each collision path with:

```text
final byte owner
required input owner(s)
mandatory reviewer(s)
merge base
conditional write trigger
no-touch state before that trigger
```

Assign each operation-extension schema to one exact Lane C source/test path.

**Closure verdict:** **OPEN P2 / ONE-OWNER PATH LEDGER NOT SATISFIED**.

### P2-S4-C-02 — Binding fixture/test assignment does not force nested maxima or the unresolved reducer negatives

#### Evidence

The producer fixture inventory at S4 lines 2000–2115 includes exact response
boundary files. The consumer ledger at lines 2117–2160 requires only entries
whose producer manifest sets:

```text
consumerRequired = true
```

S4 does not freeze the value for each listed fixture. A future producer can
mark a nested maximum fixture non-required for Binding while still satisfying
the consumer-ledger schema.

`CNEG-14` at line 2182 checks manifest drift or consumer-local signing. It does
not explicitly require Binding to decode and reject:

```text
normal response:             120829 / 120830 / 120831
admission-readback response: 291739 / 291740 / 291741
```

The fourteen CNEG rows also omit exact Binding cases for:

- every authenticated `errorCode`/`retryClass` transition;
- issuer-signed terminal indeterminate/unavailable evidence;
- `local_unknown` allowing status but denying mutation;
- cross-operation register/revoke/deregister and resolve/submit subprocess
  races;
- operation-extension digest/schema substitution;
- stable-media loss after apparent read-back;
- resolve handoff crash before/after local finalization;
- copied vault evidence with copied identifiers/MAC key material.

The generic statements “all six operations” and “every operationResourceKey”
cannot test conflict pairs that S4's key derivation places in different keys.

#### Impact

The future Binding suite can be green without proving the maximum nested
artifact it must consume, and without exercising the P1 gaps above.

#### Smallest safe static successor

For every producer fixture, freeze:

```text
consumerRequired for Binding
exact Binding test path
expected accept/reject decision
decoded and encoded byte counts
sanitized reason
```

Add exact CNEG rows for the missing artifact-family, state-gate,
cross-operation, stable-media, resolve-handoff, and copied-evidence cases.

**Closure verdict:** **OPEN P2 / CLIENT MANIFEST AND NEGATIVE EVIDENCE NOT EXHAUSTIVE**.

## 9. Mechanically reconciled finding summary

The explicit finding headings in this document are:

```text
P0 headings: 0
P1 headings: 4
P2 headings: 2
```

Therefore:

```text
P0: 0
P1: 4
P2: 2
```

No author cluster count or stale inherited summary was copied into this result.

## 10. S3 Lane C closure ledger

| Immutable S3 C finding | S4 independent verdict | Exact reason |
|---|---|---|
| `P1-S3-C-01` incomplete durable response expectation | **PARTIAL / OPEN P1-S4-C-01/02/04** | S4 adds a strong authority/vault-pinned success expectation and pre-send digest binding, but alternate authenticated artifacts, exact journal extension, durable transaction, and fillable continuity proof remain incomplete |
| `P1-S3-C-02` non-total six-operation reducer/local deregister | **PARTIAL / OPEN P1-S4-C-02/03** | All six operations and deregister ordering are named, but correlation extensions, conflict serialization, UNKNOWN preconditions, error/evidence transitions, and resolve handoff are not total |
| `P1-S3-C-03` missing persistent vault/evidence continuity | **POLICY SUBSTANTIALLY CORRECT / OPEN P1-S4-C-04** | Existing persistent no-create vault, domain, rebind, local UNKNOWN, and no server secret are explicit; concrete non-copyable continuity evidence remains undefined |
| `P2-S3-C-01` incomplete path/owner/collision allowlist | **PARTIAL / OPEN P2-S4-C-01** | Existing/new/no-touch paths are far more complete, but `project.pbxproj` has two owners and extension ownership is unnamed |
| `P2-S3-C-02` non-exhaustive negative tests | **PARTIAL / OPEN P2-S4-C-02** | CNEG rows are materially improved, but nested-max consumer flags and tests for remaining P1 states are absent |

S4 closes no source/runtime finding. It supplies static correction text only.

## 11. Requested Binding conformance matrix

| Requirement | Independent S4 verdict |
|---|---|
| Byte-identical shared cores/envelopes/fixtures | **STATIC RULE PASS; BYTES/HASHES NOT GENERATED** |
| Acyclic body/intent/challenge/request/response | **PASS** |
| Exactly six operations | **PASS** |
| Rotation only as register mode | **PASS** |
| Opaque/non-authoritative transport | **PASS; framing input missing** |
| ResponseExpectationCore for all six operations | **SUCCESS PATH PARTIAL; alternate artifacts OPEN P1-S4-C-01** |
| Persist/read-back before send | **ORDER PASS; crash-durable storage OPEN P1-S4-C-02** |
| Historical signer/owner/catalog verification | **STATIC SUCCESS RULE PASS; concrete trust/continuity inputs missing** |
| Operation-specific correlation journals | **OPEN P1-S4-C-02** |
| Cross-process single-flight | **OPEN P1-S4-C-02** |
| Total six-operation reducer | **OPEN P1-S4-C-01/02/03** |
| Ambiguous admission read-back | **WIRE PASS; client artifact/state mapping partial** |
| Active registration only after fresh exact correlation status | **PASS AS RULE** |
| Revoke distinct from deregister | **PASS** |
| Verified authoritative deregister before local erase | **PASS AS STATIC ORDER** |
| Minimal tombstone and UI truth | **CONDITIONAL / MBI-PRIVACY-RETENTION-01 OPEN** |
| Persistent existing CellApple vault, no-create | **PASS AS STATIC RULE** |
| Copied/restored/legacy evidence rejection | **RULE PRESENT; PROOF INPUT OPEN P1-S4-C-04** |
| Empty local evidence | **UNKNOWN RULE PASS; permitted recovery transition OPEN P1-S4-C-03** |
| No shared/bearer server secret | **PASS AS STATIC RULE** |
| Variable opaque APNS token | **PASS** |
| Raw token/token hash leakage | **FORBIDDEN; no runtime evidence** |
| Exact status/oracle matrix | **PASS** |
| Nested maxima arithmetic | **PASS** |
| Binding nested-max consumption | **OPEN P2-S4-C-02** |
| Exact include/no-touch/collision paths | **PARTIAL / P2-S4-C-01** |
| Exact negative/crash tests | **PARTIAL / P2-S4-C-02** |

## 12. `MBI-05` adjudication

| `MBI-05` subclaim | Independent S4 verdict |
|---|---|
| Exact future Binding paths/owners | **PARTIAL / P2-S4-C-01** |
| Persistent vault identity/no-create | **STATIC RULE CLOSED / ACTUAL IDENTITY INPUT MISSING** |
| Vault/evidence rebind and copy rejection | **PARTIAL / P1-S4-C-04** |
| Empty-local/current truth | **UNKNOWN MEANING CLOSED / RECOVERY GATE OPEN P1-S4-C-03** |
| Constructible signed challenge intent | **PRESERVED STATIC PASS / TRUST INPUT OPEN** |
| Complete durable response expectation | **SUCCESS RESPONSE PARTIAL / OPEN P1-S4-C-01** |
| Total register crash/restart graph | **PARTIAL / P1-S4-C-02/03** |
| Exact resolve/submit durable states | **PARTIAL / P1-S4-C-02/03** |
| Exact status/revoke/deregister durable states | **PARTIAL; DEREGISTER ORDER PASS / P1-S4-C-02/03** |
| Token-rotation continuity | **CORRELATION FIELDS PRESENT / JOURNAL BINDING OPEN** |
| Raw-token/evidence privacy | **STRONG STATIC RULE / NO RUNTIME PROOF** |
| Operation-specific access | **STATIC PASS** |
| Status/oracle mapping | **STATIC PASS** |
| Nested-max client consumption | **OPEN P2-S4-C-02** |
| Producer fixture consumption | **BYTE-PRESERVING RULE PASS / EXACT REQUIRED ROWS OPEN** |
| Complete Apple no-touch/collision ledger | **PARTIAL / P2-S4-C-01** |
| Production signing readiness | **UNAUDITED / MISSING (`MBI-06`)** |
| Exact integrated output | **MISSING (`MBI-07`)** |

Overall:

```text
MBI-05: PARTIAL / OPEN
```

## 13. Owner decisions and missing-bound inputs

### 13.1 `MBI-PRIVACY-RETENTION-01`

```text
STATUS: OPEN
OWNER: Kjetil
REVIEWER DECISION: NONE
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
```

Still required:

- legitimate purpose;
- exact retention duration;
- same-subject disclosure duration;
- compaction/deletion;
- backup/restore exposure and destruction;
- revoke-retained ciphertext policy;
- truthful user wording.

This review does not choose or infer any answer.

### 13.2 Identity and trust

Actual requester/issuer/owner descriptors, keys, algorithms, rotation records,
subject-target bindings, authority catalog, Agreement, Contract, Grant,
Conditions, consent, revocation ledger, trusted time, rollback anchor, vault
continuity evidence, and Identity cutover remain missing.

Accepted authority sets remain empty. Identity action remains closed.

### 13.3 `MBI-TRANSPORT-FRAMING-01`

HTTPS method/path, media/carrier bytes, outer fields/order, compatible outer
limits, HTTP status mapping, effective proxy authority, and deterministic
framing fixtures remain missing. Transport remains byte-preserving and grants
no authority.

### 13.4 `MBI-06`

```text
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING
```

### 13.5 `MBI-07`

```text
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/fixture/evidence/artifact manifest
= MISSING
```

## 14. Smallest safe successor scopes

These are recommendations only and grant no authority:

1. one document-only Lane C correction for the alternate artifact expectation
   family, exact operation extensions, conflict-class single-flight,
   stable-media transaction, UNKNOWN/status gate, resolve handoff, and fillable
   vault-continuity artifact;
2. one document-only path/test correction resolving project ownership and
   binding every required fixture—including nested maxima—to exact Binding
   tests;
3. one new independent exact-byte review by a reviewer distinct from the
   correction author.

No source/material phase opens from this review.

## 15. Final independent verdict

Mechanically reconciled result:

```text
P0: 0
P1: 4
P2: 2

S4 BINDING CLIENT CONFORMANCE REVIEW: FROZEN
LANE C CONFORMANCE: NO-GO
MBI-05: PARTIAL / OPEN
MBI-PRIVACY-RETENTION-01: OPEN / KJETIL DECISION REQUIRED
MBI-TRANSPORT-FRAMING-01: MISSING
TRUST/AUTHORITY/VAULT CONTINUITY BYTES: MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
S4 PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

Preserved action/evidence gates:

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

This review stops at this exact document. It grants no source, material, Git,
build, test, network, portal, signing, device, APNS, Identity, staging,
deployment, integration, next-phase, or production authority.
