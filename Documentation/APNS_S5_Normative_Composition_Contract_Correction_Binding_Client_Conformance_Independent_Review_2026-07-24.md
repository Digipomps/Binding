# APNS S5 Normative Composition Contract Correction — Binding Client Conformance Independent Review

Status: **INDEPENDENT REVIEW FROZEN / LANE C STATIC NO-GO / PLAN NO-GO / SOURCE NO-GO / MATERIAL NO-GO / S6 NO-GO / PRODUCTION NO-GO**

Review date: `2026-07-25` local  
Review lane: Binding client / Lane C  
Review kind: independent exact-byte static review  
Reviewed S5 SHA-256:
`0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6`  
Reviewed S5 shape: `2554 lines / 93787 bytes`

Sole output:

`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S5_Normative_Composition_Contract_Correction_Binding_Client_Conformance_Independent_Review_2026-07-24.md`

The sole output path was re-attested absent before review authoring. The
reviewer is distinct from the S5 author. This review changes no prior
document, source, fixture, manifest, project, dependency, Git state, build,
test, network, portal, signing, device, APNS, Identity, staging, deployment,
integration, material, or production state.

## 1. Exact review boundary

The reviewed composition order is:

```text
S3 exact bytes
then S4 exact bytes
then S5 exact bytes
```

S5 replaces only clauses it explicitly names. Unnamed S3/S4 clauses remain
normative. This review did not select a permissive clause from an older stage.

### 1.1 Immutable author artifacts

| Stage | Exact path | SHA-256 | Lines | Bytes |
|---|---|---|---:|---:|
| S3 | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 |
| S4 | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md` | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` | 2377 | 79288 |
| S5 | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md` | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554 | 93787 |

### 1.2 Immutable S3 reviews

| Lane | Exact path | SHA-256 | Lines | Bytes | Terminal P0/P1/P2 |
|---|---|---|---:|---:|---:|
| A | `Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 | `0/4/2` |
| B | `Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 | `0/7/2` |
| C | `Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 | `0/3/2` |

### 1.3 Immutable S4 reviews

| Lane | Exact path | SHA-256 | Lines | Bytes | Terminal P0/P1/P2 |
|---|---|---|---:|---:|---:|
| A | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `c3a424c777907a7e9c749f2602f1f89252743c36e4f5abdb754dd4f8b98fcace` | 1006 | 34394 | `0/5/2` |
| B | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `1580b3e6206b548c8e2fa1f9ee3d134c77a8ff6b6ef1656a1126fc0598b36334` | 792 | 37012 | `0/5/2` |
| C | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `640fe35d9e2ef482c75d8093efe4eb914dd953e678ec4fd79e2b9053ab296985` | 917 | 32388 | `0/4/2` |

The S4 counts above were reproduced from each review's terminal finding
headings and reconciliation, not summed from author clusters. Historical
counts are lineage and are not copied into this review's severity result.

## 2. Method and authority boundary

The review adversarially checked:

- the total `SignedOutcomeArtifact` union and historical
  `ResponseExpectationCore`;
- challenge, status, authenticated error, current-subject head, maxima, and
  exact replay consumption;
- all six journal extension schemas and their digest binding;
- journal conflict classes, cross-process single flight, stable-media
  transaction, restart, read-back, and rollback;
- local-state gates and every authenticated error/evidence reducer family;
- resolve delivery handoff and absent-sink behavior;
- authoritative server deregister before local erase;
- vault no-create, non-exportable-key binding, copy versus rollback premises,
  and exact `EMPTY`/`UNAVAILABLE` behavior;
- exact Binding paths, project/no-touch ownership, fixture applicability, and
  negative coverage;
- preservation of opaque transport, six operations, acyclicity, token
  allocation bounds, and zero token leakage.

The following CellProtocol rules were used as the semantic boundary:

- Identity is domain-scoped operational identity, not a global entity or
  transport identity;
- Agreement, Contract, Grant, Conditions, and Resolver validation grant
  authority; route, HTTP, TLS, bearer possession, administrator status, and
  static files do not;
- transport is semantically neutral and must preserve opaque application
  bytes;
- replay, result, and status evidence never obtain authority from transport;
- absent external authority, Identity, hardware, custody, rollback, signing,
  or provider proof stays absent.

Static constructibility and external proof were scored separately. A correct
`EMPTY` set or `UNAVAILABLE` state may close a static fail-closed decision. It
cannot produce an Identity, hardware, storage, signing, APNS, or production
PASS.

## 3. Preserved positive invariants

The following S5 properties pass this static review, subject to the findings
below:

1. `SignedOutcomeArtifact` is a closed three-case union:
   `operation_success`, `authenticated_error`, and
   `admission_terminal_evidence`.
2. Protected `artifactKind` selects one exact core schema before core digest
   and signature verification.
3. A non-success outcome cannot establish operation success, current
   registration, revoke, deregister, resolve delivery, or submit receipt
   truth.
4. Missing historical signer, owner, catalog, delegation, generation,
   request, admission, or vault input empties accepted outcomes, marks
   readiness unavailable, and forbids send.
5. Status correlation suppression, admission wrong-subject/absence
   equivalence, non-recursive nested read-back, and current-head generation
   fields are explicit.
6. Local evidence absence is distinct from invalid vault/authority:
   valid-vault absence permits only fresh signed `subject_current`
   registration status, while invalid vault/authority permits no operation.
7. Authenticated error and terminal-evidence reducer branches never publish
   positive operation truth.
8. Resolve without an independently proven durable idempotent sink is
   unavailable and makes no delivered-once claim.
9. Authoritative server deregistration and required fresh signed status
   precede local token/binding erasure.
10. Missing non-exportable-key, hardware, custody, rollback, durable-store,
    and idempotent-sink proofs produce explicit empty accepted sets and
    unavailable Binding readiness.
11. Project, dependency, and entitlement collision rows have one final-byte
    owner and distinguish input/review responsibility from write ownership.
12. APNS token bytes are opaque, non-empty, and at most 4096 bytes as a HAVEN
    allocation bound only. Raw token and token hash leakage remains forbidden.
13. Transport remains opaque, byte-preserving, and non-authoritative.
14. The wire operation set remains exactly:
    `register`, `resolve`, `submit`, `status`, `revoke`, and `deregister`.
15. Rotation remains a `register` mutation mode, never a seventh operation.

The canonical wire graph remains acyclic:

```text
body -> intent -> challenge -> request -> signed outcome
core -> protected core -> signature -> envelope -> signed artifact
```

Finding P1-S5-C-02 concerns a separate local continuity graph that S5 newly
introduces; it does not alter the positive wire-graph observation.

## 4. Independent maxima reproduction

The S5 non-escaping alphabet makes JSON escaping contribute zero value bytes
for the directly encoded protocol strings. Independent checked arithmetic
reproduced:

```text
SignatureProtectedCoreMax              = 503
SignatureEnvelopeMax                   = 2129
Artifact(8192)                         = 13854
NormalResultCoreMax                    = 65536
NormalResponseCoreMax                  = 88542
NormalOutcomeArtifactMax               = 120987
AdmissionStatusResultCoreMax           = 161999
AdmissionReadbackResponseCoreMax       = 217159
AdmissionReadbackOutcomeArtifactMax    = 292477
CanonicalOperationRequestMax           = 120502
```

The literal byte counts independently reproduced:

```text
SignatureEnvelope prefix  = 14
SignatureEnvelope middle  = 76
SignedArtifact prefix     = 9
SignedArtifact middle     = 81
```

Base64url calculations independently reproduced:

```text
B64(65536)  = 87382
B64(120987) = 161316
B64(161999) = 215999
```

The max-1/max/max+1 and token zero/4095/4096/4097 vectors are internally
consistent. Actual producer/consumer calculator implementations and test
evidence remain missing under `MBI-07`; the arithmetic PASS is static only.

## 5. P0 adjudication

No P0 finding was identified. S5 keeps source, material, Identity, signing,
device, APNS, staging, deployment, and production gates closed, so the
constructibility defects below cannot presently authorize a dangerous
operation.

## 6. P1 findings

### P1-S5-C-01 — A pre-challenge authenticated error has no constructible persisted expectation

#### Evidence

S3 fixes the construction order:

```text
body
-> signed intent
-> server challenge
-> client derives admissionID
-> signed request
-> operation journal/expectation persisted
-> operation send
```

S5 section 5.3 makes `pre_challenge` an allowed authenticated-error phase with:

```text
admissionID = null
challengeArtifactSHA256 = null
requestArtifactSHA256 = null
targetCellID/targetOwnerDescriptorSHA256 = null
signerRole = challenge_issuer
```

S5 section 5.6 defines only one `ResponseExpectationCore v2`. It contains
non-optional-by-contract attempt members for:

```text
admissionID
challengeArtifactSHA256
requestArtifactSHA256
subjectTargetBindingSHA256
targetCellID
targetOwnerDescriptorSHA256
vaultContinuityProofSHA256
```

The expectation, extension, operation journal, and vault proof are required to
be one stable-media transaction before send. The S3 operation journal is
created only after challenge verification and request construction, because
the client cannot know `admissionID`, challenge digest, request digest, target
owner, or exact allowed target-owner outcome before the challenge exists.

At the actual pre-challenge boundary, these values do not yet exist. S5 also
says missing request or admission input empties `allowedOutcomeVariants`,
makes readiness unavailable, and forbids send. Therefore the same contract:

- requires the pre-challenge error variant to be reachable and acceptable;
- requires its expectation to bind values that cannot exist at that phase;
  and
- rejects the expectation because request/admission inputs are missing.

F013 accepts a standalone pre-challenge error, but no fixture constructs the
pre-challenge persisted expectation or proves an exact phase transition from
intent send to that error. A structurally valid signed error is not by itself
an expectation-bound client outcome.

#### Impact

Binding has no deterministic safe rule for a valid issuer-signed error returned
instead of a challenge. It must either:

- reject every such error and strand challenge recovery;
- verify it without a persisted historical expectation;
- fabricate later request/admission/target values; or
- weaken the missing-input empty-set rule.

All four choices diverge from the effective S3→S4→S5 bytes.

#### Smallest safe static successor

Choose exactly one acyclic phase model:

1. define a separate pre-challenge `ChallengeOutcomeExpectationCore`, persisted
   before intent send, binding only values that already exist plus the exact
   issuer/historical authority set; or
2. define a versioned expectation union with an exact pre-challenge variant
   and phase-specific nullability, then upgrade it after challenge verification
   without rewriting historical bytes.

The successor must freeze exact digest linkage, stable-media order, signer
history, missing-input behavior, and reducer transitions from pre-challenge
error to a new-byte retry or unavailable state. It must not use future
challenge/request/admission bytes in an earlier expectation.

**Closure verdict:** **OPEN P1 / S5-RC-01 PARTIAL**.

### P1-S5-C-02 — Vault continuity and the objects it protects form an unconstructible digest cycle

#### Evidence

`ResponseExpectationCore v2` contains:

```text
vaultContinuityProofSHA256
```

`OperationJournalCore v2` also contains:

```text
expectationSHA256
vaultContinuityProofSHA256
```

`VaultContinuityCore v1` then contains:

```text
journalRootSHA256
latestExpectationSHA256
```

S5 says:

- the envelope digest binds ResponseExpectationCore and
  OperationJournalCore;
- the expectation, extension, journal, and vault proof are one stable-media
  transaction; and
- continuity and journal/expectation are updated in one stable-media
  transaction.

No clause defines `journalRootSHA256` or `latestExpectationSHA256` as the
**prior** committed generation, and no clause defines a separate successor
continuity record after expectation/journal commit. Read literally as the
single current transaction:

```text
vaultProofDigest
  -> digest(VaultContinuityCore(latestExpectationDigest, journalRootDigest))

expectationDigest
  -> digest(ResponseExpectationCore(vaultProofDigest))

journalRootDigest
  -> root containing OperationJournalCore(vaultProofDigest, expectationDigest)
```

This is a cryptographic fixed-point cycle. Canonical member order and a
signature/MAC do not make the bytes constructible.

The S5 text also does not give an exact equation for
`vaultContinuityProofSHA256`, although the field is treated as a `DigestHex`
binding input.

#### Impact

A conforming Binding cannot create exact expectation, journal, and continuity
bytes before send. Implementations could silently choose:

- a prior continuity proof;
- a provisional all-zero digest;
- a post-commit successor proof;
- a mutable proof record; or
- repeated hashing until an arbitrary stop.

Those choices produce different bytes and different rollback semantics. A
fixture can fill the fields with unrelated digests and pass structural decode
without proving the construction graph.

The explicit missing hardware/custody/rollback inputs correctly keep runtime
readiness unavailable, but they do not close this static cycle. A future
provider still has no exact artifact graph to fill.

#### Smallest safe static successor

Define a versioned, directed transition, for example:

```text
verified prior VaultContinuityArtifact(N)
-> expectation/journal bind priorContinuityArtifactSHA256
-> atomic stable-media transaction commits expectation/journal
-> successor VaultContinuityArtifact(N+1) binds committed expectation/journal root
-> external rollback anchor commits successor digest
-> read-back
```

The exact successor must define:

- prior versus successor field names;
- exact digest equation over complete envelope bytes;
- journal-root construction and inclusion boundary;
- transaction and rollback-anchor ordering;
- crash behavior before and after every boundary;
- which proof controls send permission; and
- how restart verifies both generations without mutable historical bytes.

**Closure verdict:** **OPEN P1 / S5-RC-08 PARTIAL**.

### P1-S5-C-03 — Conflict locks are keyed by a continuity digest that changes with the protected journal

#### Evidence

All three S5 conflict keys include:

```text
vaultContinuityProofSHA256Raw
```

This applies to:

- `K_registration`;
- `K_ticket`; and
- `K_admission`.

The same S5 contract requires continuity generation, journal root, latest
expectation, and rollback anchor to be checked and updated with local
expectation/journal transactions. Once the continuity graph is made
constructible, its proof digest necessarily changes when those bound values or
the continuity generation change.

Therefore the lock namespace for the same logical registration, ticket, or
admission can change between:

- an ambiguous operation and its status recovery;
- register and a later revoke/deregister;
- resolve and a later submit;
- an app process and an extension reopening after a committed continuity
  update; or
- a prior-proof process and a successor-proof process.

An ambiguous operation can remain under:

```text
K_registration(proof N)
```

while a second process derives:

```text
K_registration(proof N+1)
```

for the same subject head. The two keys do not collide, despite S5 claiming
that the family serializes.

The same defect is acute for status/admission recovery: the status request can
use a successor proof and fail to acquire the target admission's original
proof-scoped recovery key.

#### Impact

Cross-process single flight is not preserved across the exact continuity
updates that the journal requires. Conflicting register/revoke/deregister or
resolve/submit work can cross the local ambiguous-send boundary under distinct
keys. Server CAS can reject a mutation, but cannot reconstruct the client's
lost expectation or make local UI/evidence transitions atomic.

F083 and F084 name same-family races, but no row requires a race across proof
generation N→N+1. Thus they can pass while the lock namespace rolls over.

#### Smallest safe static successor

Derive conflict-family keys from a stable, non-secret vault/subject namespace,
not an operation-dependent continuity artifact digest. Any stable component
must itself have an exact non-copyable proof and rotation contract. A separate
global vault-continuity transition lock must serialize proof/key rotation
against every protected-operation family.

Freeze:

- exact stable namespace bytes;
- key-rotation and vault-recovery lock ordering;
- old/new generation overlap behavior;
- status recovery against prior-generation ambiguous operations;
- subprocess races spanning continuity generations; and
- restart reconciliation before any new send.

**Closure verdict:** **OPEN P1 / S5-RC-07 PARTIAL**.

### P1-S5-C-04 — The six journal extension cores lack exact types and phase-specific nullability

#### Evidence

S5 supplies six schema literals and member orders and correctly digest-binds
the exact encoded extension inside `OperationJournalCore v2`. It then says
only:

```text
Nullable members remain present.
```

It does not define which member is nullable in which operation mode/selector,
nor the exact scalar type and range for every member. Required missing
matrices include:

- first `register/enroll` versus update, reactivate, and token rotation:
  `registrationID`, head epoch, expected head/registration/revocation
  generations, token epoch, and observation ID;
- `status/registration` selectors:
  subject-current, registration ID, and optional correlation;
- `status/admission`:
  target admission ID versus registration fields and correlation;
- `submit`:
  whether `resolveAdmissionID` is mandatory and how its ID namespace is
  checked;
- `resolve` and `submit`:
  exact ticket ID, lineage, and content-contract digest requirements;
- revoke/deregister:
  exact non-null prior head/registration/revocation values.

Member order does not determine whether a missing value is JSON `null`, an
empty string, zero, absent, or invalid. In particular, “nullable members remain
present” is not an exact nullability table.

The extensions also have no independent encoded-byte maximum. Although they
contain only non-secret identifiers/digests, an unbounded or differently typed
extension makes the operation-journal bound and pre-allocation behavior
consumer-defined.

#### Impact

Two conforming implementations can serialize different extension bytes for the
same operation state, produce different extension digests, choose different
resource keys, and make different restart/reducer decisions. The “exact six
operation extension” correction is therefore not byte-total.

The six positive fixtures F076...F081 and one digest-substitution fixture F082
cannot prove all nullability/type combinations or reject invalid cross-mode
fields.

#### Smallest safe static successor

For each extension, freeze:

- exact member type;
- exact ID namespace/alphabet/length;
- exact integer range and nullability;
- operation/mutationMode/statusKind/selector field matrix;
- forbidden cross-field combinations;
- independently derived byte maximum; and
- positive and negative fixtures for every row, including first enrollment,
  rotation, subject-current, registration correlation, admission read-back,
  and stale generation values.

**Closure verdict:** **OPEN P1 / S5-RC-07 PARTIAL**.

## 7. P2 findings

### P2-S5-C-01 — The C fixture ledger does not exercise the four remaining static composition defects

#### Evidence

S5 materially improves fixture ownership by freezing F001...F100 and an exact
A/B/C applicability cell for every entry. It correctly requires Binding
consumption of normal and nested maxima and includes reducer, stable-store,
handoff, vault, and deregister negatives.

No exact entry covers:

1. persisting a pre-challenge expectation before intent send, then accepting
   or rejecting the exact issuer-signed pre-challenge error;
2. detecting the vault-proof ↔ expectation/journal digest cycle or proving an
   acyclic prior/successor continuity transition;
3. registration, ticket, and admission conflict races across continuity-proof
   generation N→N+1; or
4. the per-field type/nullability/cross-mode matrix for all six operation
   extensions.

Specific existing rows are insufficient:

- F013 checks a pre-challenge error artifact, not the earlier persisted
  expectation and reducer transaction;
- F083/F084 check conflict families without a continuity-generation rollover;
- F093 checks only vault-envelope structure;
- F076...F081 are positive extension examples, and F082 checks only digest
  substitution.

The per-entry `negativeApplicability` member is named but its closed schema and
relationship to the exact C test identifier are not defined. The table
therefore cannot encode all missing negative cross-products without another
normative decision.

#### Impact

A future Binding suite can be green while implementing a future-byte
expectation, a cyclic/provisional vault digest, proof-scoped split locks, or
consumer-chosen extension nullability.

#### Smallest safe static successor

Add exact manifest entries, C test paths/IDs, expected decisions, sanitized
reasons, and byte shapes for all four defect classes. Freeze the exact
`negativeApplicability` schema or replace it with individually enumerated
negative entries. No source or test execution is authorized by this finding.

**Closure verdict:** **OPEN P2 / S5-EVIDENCE-01 PARTIAL**.

## 8. Signed outcome, status, and reducer conformance

| Requirement | Independent S5 Lane C verdict |
|---|---|
| Closed signed outcome union | **STATIC PASS** |
| Union discriminator/core mapping | **STATIC PASS** |
| Exact success result-schema mapping | **STATIC PASS** |
| Authenticated error code/retry/terminality table | **STATIC PASS FOR ARTIFACT SHAPE** |
| Terminal evidence never implies target truth | **STATIC PASS** |
| Historical signer/catalog/delegation binding | **STATIC RULE PASS; ACCEPTED EXTERNAL SETS EMPTY** |
| Missing historical input behavior | **PASS: EMPTY / UNAVAILABLE / SEND FORBIDDEN** |
| Pre-challenge expectation | **OPEN P1-S5-C-01** |
| Status correlation suppression | **STATIC PASS** |
| Admission absent/wrong-subject privacy equivalence | **STATIC PASS** |
| Recursive status read-back forbidden | **STATIC PASS** |
| Current subject head and re-enroll generation | **STATIC PASS; PRIVACY RETENTION OPEN** |
| Benign local absence versus invalid vault | **STATIC PASS** |
| `local_unknown` mutation prevention | **STATIC PASS** |
| Authenticated error/evidence reducer | **STATIC PASS** |
| Fresh signed status for current truth | **STATIC PASS** |
| Resolve sink absent | **PASS: UNAVAILABLE, NO DELIVERED-ONCE CLAIM** |
| Server deregister before local erase | **STATIC PASS** |

No row above proves runtime verification, storage durability, actual authority,
Identity cutover, APNS acceptance, delivery, or callback.

## 9. Journal, store, and vault conformance

| Requirement | Independent S5 Lane C verdict |
|---|---|
| Six named extension schemas | **PRESENT** |
| Extension member order and digest equation | **PRESENT** |
| Extension types/nullability/maxima | **OPEN P1-S5-C-04** |
| Journal binds extension, expectation, operation, and vault proof | **PRESENT BUT CYCLIC VIA P1-S5-C-02** |
| Registration conflict family | **INTENT CORRECT; KEY UNSTABLE P1-S5-C-03** |
| Ticket conflict family | **INTENT CORRECT; KEY UNSTABLE P1-S5-C-03** |
| Admission recovery family | **INTENT CORRECT; KEY UNSTABLE P1-S5-C-03** |
| Lexical multi-key ordering | **STATIC PASS FOR A FIXED KEY SET** |
| One shared descriptor-relative store | **STATIC RULE PASS** |
| No-follow/metadata/owner/mode/link checks | **STATIC RULE PASS** |
| Stable-media plus parent/equivalent DB durability | **STATIC RULE PASS; PROVIDER PROOF EMPTY** |
| Rollback-anchor advance/read-back | **STATIC RULE PASS; ANCHOR PROOF EMPTY** |
| Vault opens existing persistent domain only | **STATIC PASS** |
| Vault auto-create/ephemeral fallback | **FORBIDDEN** |
| Signature/MAC protection input | **STATIC PASS FOR CORE PROTECTION** |
| Vault↔journal/expectation digest direction | **OPEN P1-S5-C-02** |
| Copy resistance distinct from rollback | **STATIC PASS AS SEPARATE PREMISES** |
| Missing continuity/hardware/custody proof | **PASS: EMPTY / UNAVAILABLE / NO PASS CLAIM** |

The store and vault rows do not credit a platform proof. All named proof sets
remain empty exactly as S5 requires.

## 10. Path, ownership, no-touch, and fixture ledger

### 10.1 Binding paths and ownership

The S5 repo-qualified rows repair the S4 project ownership collision:

| Exact path class | Independent verdict |
|---|---|
| Lane C DeviceIngress source paths | **ONE FINAL-BYTE OWNER** |
| Lane C tests/support/fixture ledger | **ONE FINAL-BYTE OWNER** |
| `repo://Binding/Binding.xcodeproj/project.pbxproj` | **Binding development admin final-byte owner; Lane C + Apple release input/review only** |
| `repo://Binding/.../Package.resolved` | **Binding development admin final-byte owner; conditional no-touch** |
| `repo://Binding/Binding/Binding-iOS.entitlements` | **Apple release owner; immutable/no-touch** |
| Apple release M0 files | **Apple release owner; immutable/no-touch** |
| CellProtocol and CellScaffold paths | **NOT LANE C OWNED** |

`repo://Binding/Binding/DeviceIngress/DeviceIngressJournalExtensions.swift`
provides one explicit Lane C path for the six extension types. The one-owner
repair to P2-S4-C-01 is statically sufficient. It does not authorize any
source write or project membership change.

### 10.2 Fixture applicability

The F001...F100 table removes the S4 unconstrained
`consumerRequired` boolean. Every entry has one exact A/B/C disposition and
one exact C test code or closed non-applicable reason.

Binding consumption is correctly mandatory for:

- all three signed outcome kinds;
- register/resolve/submit/both status kinds/revoke/deregister success;
- authenticated error and terminal evidence;
- status privacy and nested admission outcomes;
- challenge replay and authority structure;
- current-head cycles and corruption;
- max-1/max/max+1 normal and nested artifacts;
- token zero/4095/4096/4097;
- all six journal extension positives and digest substitution;
- conflict, stable-media, reducer, handoff, vault, and deregister cases.

This is a material static improvement. P2-S5-C-01 records the remaining
negative coverage gap.

## 11. S5 root-cause disposition RC-01...RC-08

| S5 root cause | Independent Lane C verdict | Basis |
|---|---|---|
| `S5-RC-01` outcome union/expectation | **PARTIAL / OPEN** | Outcome union, signer variants, non-success semantics, and EMPTY behavior are strong; pre-challenge expectation is unconstructible under P1-S5-C-01 |
| `S5-RC-02` challenge replay | **STATIC CONTRACT CLOSED FOR LANE C CONSUMPTION** | U1...U4 precedence, stored expiry outcome, terminal replay, and no re-sign are exact; runtime durability remains external/missing |
| `S5-RC-03` binding/catalog | **STATIC SHAPE CLOSED / ACCEPTED SETS EMPTY** | Exact delegation/binding/catalog/consent tuple exists; no external authority bytes receive PASS |
| `S5-RC-04` subject head | **STATIC CONTRACT CLOSED / PRIVACY DECISION OPEN** | Atomic head/CAS, re-enroll, and deletion behavior are defined; Kjetil's retention decision remains open |
| `S5-RC-05` maxima | **STATIC CONTRACT CLOSED** | Independent arithmetic reproduced all relevant maxima; implementation/evidence remains missing |
| `S5-RC-06` legacy | **OUTSIDE LANE C / FAIL-CLOSED PRESERVED** | Provider/procedure/custody proof sets remain empty and provider delivery unavailable |
| `S5-RC-07` Binding reducer/journal | **PARTIAL / OPEN** | Local gate, outcome reducer, sink-unavailable rule, and deregister order pass; locks and extension bytes remain open under P1-S5-C-03/04 |
| `S5-RC-08` vault continuity | **PARTIAL / OPEN** | Copy/rollback inputs are correctly separated and empty, but the local proof graph is cyclic under P1-S5-C-02 |

No root-cause row grants source, runtime, Identity, hardware, or production
closure.

## 12. S4 Lane C closure ledger

| Immutable S4 Lane C finding | Independent S5 disposition | Exact basis |
|---|---|---|
| `P1-S4-C-01` incomplete outcome expectation family | **PARTIAL / OPEN P1-S5-C-01** | Three-case union, signer variants, error/evidence reducer, and non-success rule close most of the finding; pre-challenge persisted expectation remains impossible |
| `P1-S4-C-02` non-exact journal and split conflict keys | **PARTIAL / OPEN P1-S5-C-03/04** | Journal now digest-binds one of six extensions and names conflict families; proof-scoped lock rollover and extension nullability/types remain open |
| `P1-S4-C-03` unsafe local unknown and non-total resolve handoff | **STATIC CONTRACT CLOSED** | Valid-vault absence is status-only, invalid vault permits none, authenticated outcome reducer is total by family, and missing sink explicitly makes resolve unavailable |
| `P1-S4-C-04` unconstructible vault continuity | **PARTIAL / OPEN P1-S5-C-02** | S5 adds exact core/envelope and separate copy/rollback slots, but creates a digest cycle among the protected objects |
| `P2-S4-C-01` project owner and extension path collision | **STATIC CONTRACT CLOSED** | One final-byte owner is frozen for project/dependency/entitlement rows and one exact extension source path exists |
| `P2-S4-C-02` non-exhaustive client fixture assignment | **PARTIAL / OPEN P2-S5-C-01** | Per-entry C applicability and nested maxima are now exact; remaining S5 defects have no exact negative entries |

S4's positive static rules remain preserved:

- six operations and rotation-as-register;
- opaque non-authoritative transport;
- fresh signed status for current truth;
- revoke distinct from deregister;
- authoritative server deregister before local erase;
- persistent no-create vault;
- no shared/bearer server secret;
- opaque variable token and zero token leakage;
- status privacy matrix; and
- nested maxima.

## 13. MBI-05 disposition

| `MBI-05` Binding subclaim | Independent S5 verdict |
|---|---|
| Exact future Binding paths/owners | **STATIC CLOSED** |
| Persistent CellApple vault/no-create | **STATIC RULE CLOSED / ACTUAL IDENTITY INPUT MISSING** |
| Vault/evidence rebind | **PARTIAL / P1-S5-C-02; EXTERNAL PROOFS EMPTY** |
| Copy versus rollback distinction | **STATIC PREMISE DISTINCTION CLOSED / BOTH PROOF SETS EMPTY** |
| Empty-local/current truth | **STATIC CLOSED: STATUS-ONLY RECOVERY** |
| Invalid vault/authority gate | **STATIC CLOSED: NO OPERATION** |
| Constructible challenge intent | **STATIC PASS; TRUST INPUT EMPTY** |
| Complete response expectation | **PARTIAL / P1-S5-C-01/02** |
| Six operation extensions | **PARTIAL / P1-S5-C-04** |
| Cross-process single flight | **PARTIAL / P1-S5-C-03** |
| Stable-media expectation/journal | **STATIC ORDER PRESENT / PROVIDER PROOF EMPTY / CYCLE OPEN** |
| Register crash/restart graph | **PARTIAL / P1-S5-C-02/03/04** |
| Resolve/submit durable states | **STATIC HANDOFF RULE PASS; JOURNAL/LOCK PARTIAL** |
| Status/revoke/deregister durable states | **STATIC ORDER PASS; JOURNAL/LOCK PARTIAL** |
| Resolve idempotent sink | **MISSING SET EMPTY; RESOLVE UNAVAILABLE AS REQUIRED** |
| Token-rotation continuity | **STATIC CORRELATION PRESENT; EXTENSION/LOCK PARTIAL** |
| Raw token/evidence privacy | **STRONG STATIC PASS / NO RUNTIME PROOF** |
| Operation-specific access | **STATIC PASS / AUTHORITY SET EMPTY** |
| Status/oracle mapping | **STATIC PASS** |
| Nested-max client consumption | **STATIC CLOSED / FUTURE EVIDENCE MISSING** |
| Producer fixture consumption | **PARTIAL / P2-S5-C-01** |
| Apple project/no-touch ownership | **STATIC CLOSED** |
| Production signing readiness | **UNAUDITED / MISSING (`MBI-06`)** |
| Exact integrated output | **MISSING (`MBI-07`)** |

Overall:

```text
MBI-05 STATIC CONTRACT: PARTIAL / OPEN
MBI-05 IMPLEMENTATION/RUNTIME: MISSING / UNAUTHORIZED
```

## 14. External proof and owner-decision ledger

The following S5 classifications are correct and receive no negative finding
merely for remaining external:

```text
accepted authority manifests = EMPTY
accepted target owners = EMPTY
accepted catalog signers = EMPTY
accepted subject-target bindings = EMPTY
accepted authorization entries = EMPTY
accepted outcome signers = EMPTY

accepted non-exportable key proofs = EMPTY
accepted hardware attestations = EMPTY
accepted custody/recovery proofs = EMPTY
accepted rollback anchors = EMPTY
accepted durable store proofs = EMPTY
accepted idempotent sink proofs = EMPTY

Binding protected-operation readiness = UNAVAILABLE
hardware PASS = NONE
copy-resistance PASS = NONE
rollback-resistance PASS = NONE
```

Local IDs, booleans, fingerprints, copied MAC keys, transport possession, TLS,
Host, administrator status, repository keys, test keys, and static paths cannot
fill these sets.

### 14.1 Privacy retention

```text
MBI-PRIVACY-RETENTION-01: OPEN
OWNER: Kjetil
REVIEW DECISION CREDIT: NONE
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE/HISTORICAL COMPACTION: DISABLED
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

This review does not select retention duration, disclosure, backup/restore,
compaction, deletion, ciphertext retention, or user wording.

### 14.2 Identity

Identity cutover remains a separate prerequisite. No Identity action or
authority composition is authorized. Actual descriptor, key, manifest,
delegation, catalog, Agreement, Contract, Grant, Conditions, consent,
revocation, trusted-time, rollback, and recovery bytes remain missing.

### 14.3 Transport

`MBI-TRANSPORT-FRAMING-01` remains missing. No HTTP method/path, media type,
outer framing, overhead, proxy behavior, status mapping, or deterministic
framing fixture is selected. Opaque application-byte limits do not invent a
carrier contract.

### 14.4 Apple production and integrated output

```text
MBI-06:
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING

MBI-07:
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/fixture/evidence/artifact manifest
= MISSING
```

The exact planning literals remain:

```text
identity domain = domain:device:notification-callback
purpose         = purpose://access.audit.privacy/device-notification-callback
audience        = haven.digipomps.org
origin          = https://haven.digipomps.org
bundle          = org.digipomps.haven
APNS topic      = org.digipomps.haven
environment     = production
```

They prove no production profile, entitlement, signing identity, archive,
provider acceptance, physical delivery, callback, or readiness.

## 15. Finding count reconciliation

Only headings whose identifiers match the exact forms below count as this
review's findings:

```text
P0-S5-C-<NN>
P1-S5-C-<NN>
P2-S5-C-<NN>
```

The explicit finding headings in this document reconcile to:

```text
P0: 0
P1: 4
P2: 1
```

Historical S3/S4 headings, S5 root-cause identifiers, table rows, examples,
and prose references do not count as new findings.

## 16. Verdict and smallest safe successor scopes

### 16.1 Lane C verdict

```text
LANE C STATIC CONTRACT: NO-GO
P0/P1/P2: 0/4/1
MBI-05: PARTIAL / OPEN
```

The S5 correction is materially safer and more exact than S4. It does not yet
form one constructible Binding client contract because:

1. pre-challenge error expectation uses future bytes;
2. continuity proof and protected objects form a digest cycle;
3. conflict-family locks roll over with the continuity proof; and
4. operation extensions are not type/nullability total.

### 16.2 Smallest document-only successor scopes

No successor is authorized by this review. If development admin later opens
another document-only correction, the smallest independent scopes are:

1. **Outcome phase scope:** acyclic pre-challenge expectation variant,
   issuer-history binding, stable-media order, and reducer fixtures.
2. **Continuity transition scope:** exact prior/successor vault continuity
   artifact graph, digest equations, journal-root definition, rollback-anchor
   order, and crash transitions.
3. **Stable conflict namespace scope:** stable vault/subject family identity,
   vault-rotation lock ordering, old/new generation overlap, and subprocess
   recovery fixtures.
4. **Extension schema scope:** exact types, ranges, nullability matrices,
   maxima, forbidden combinations, and per-row fixtures for all six
   operations.
5. **Evidence scope:** exact C-negative manifest entries for all four corrected
   classes.

These scopes must remain document-only and receive new independent exact-byte
review before any source authorization.

### 16.3 Overall gates

```text
PLAN: NO-GO
NEXT PHASE: CLOSED / NO-GO
S6: CLOSED / NO-GO
SOURCE: CLOSED / NO-GO
MATERIAL: CLOSED / NO-GO
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
PRODUCTION: CLOSED / NO-GO
```

## 17. Final independent review freeze

```text
REVIEW INPUT:
  S5 SHA-256 = 0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6
  S5 SHAPE   = 2554 lines / 93787 bytes

EFFECTIVE ORDER:
  S3 -> S4 -> S5

S4 TERMINAL LANE COUNTS:
  A = 0/5/2
  B = 0/5/2
  C = 0/4/2

S5 LANE C REVIEW:
  P0/P1/P2 = 0/4/1
  STATIC VERDICT = NO-GO
  MBI-05 = PARTIAL / OPEN

WIRE GRAPH = ACYCLIC
WIRE OPERATIONS = EXACTLY SIX
ROTATION = REGISTER MUTATION ONLY
TRANSPORT = OPAQUE / BYTE-PRESERVING / NON-AUTHORITATIVE
TOKEN = OPAQUE 1...4096 HAVEN RESOURCE BOUND ONLY
TOKEN/TOKEN-HASH LEAKAGE = FORBIDDEN
SERVER DEREGISTER BEFORE LOCAL ERASE = PRESERVED

EXTERNAL AUTHORITY SETS = EMPTY
VAULT/HARDWARE/CUSTODY/ROLLBACK/STORE/SINK PROOF SETS = EMPTY
PROTECTED OPERATION READINESS = UNAVAILABLE

MBI-PRIVACY-RETENTION-01 = OPEN / KJETIL
IDENTITY CUTOVER = SEPARATE / OPEN / NO-GO
MBI-TRANSPORT-FRAMING-01 = MISSING
MBI-06 = UNAUDITED / MISSING
MBI-07 = MISSING

PLAN = NO-GO
NEXT PHASE = NO-GO
S6 = NO-GO
SOURCE AUTHORIZATION = NONE
MATERIAL AUTHORIZATION = NONE
PRODUCTION = NO-GO
```

This review authorizes no correction, source, Git, dependency, build, test,
network, portal, signing, device, APNS, Identity, staging, deployment,
integration, material, S6, next-phase, or production action.
