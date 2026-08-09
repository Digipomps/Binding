# APNS S5 Normative Composition Contract Correction — CellProtocol Conformance Independent Review

Status: **REVIEW-FROZEN / LANE A NO-GO / S5 NO-GO / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Date: 2026-07-25 (Europe/Podgorica)

Scope: one independent exact-byte, static Lane A review. The reviewer is
distinct from the S5 author. No source, Git, dependency resolution, build,
test, network, portal, signing, device, APNS, secret, Identity, staging,
deployment, integration, material, S6, or next-phase action was performed.

## 1. Exact review gate

### 1.1 S5 target

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md` | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554 | 93787 |

The target review path was absent before this review was authored.

### 1.2 Immutable S3/S4 lineage

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 |
| `Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 |
| `Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 |
| `Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 |
| `Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md` | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` | 2377 | 79288 |
| `Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `c3a424c777907a7e9c749f2602f1f89252743c36e4f5abdb754dd4f8b98fcace` | 1006 | 34394 |
| `Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `1580b3e6206b548c8e2fa1f9ee3d134c77a8ff6b6ef1656a1126fc0598b36334` | 792 | 37012 |
| `Documentation/APNS_S4_Normative_Composition_Contract_Correction_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `640fe35d9e2ef482c75d8093efe4eb914dd953e678ec4fd79e2b9053ab296985` | 917 | 32388 |

The effective reviewed order is:

```text
S3 exact bytes -> S4 exact bytes -> S5 exact bytes
```

No earlier document was rewritten. S5 can replace only conflicts it explicitly
names; otherwise the earlier exact bytes remain normative.

## 2. Review method

The review:

1. read all 2554 S5 lines;
2. reattested the exact S3/S4 contract and six review shapes;
3. reproduced the S4 Lane A terminal count directly as `0/5/2`;
4. mapped every S4 Lane A finding to S5 RC1...RC8 or a P2 class;
5. reconstructed the core/protected/signature/envelope/artifact dependency
   graph and the local expectation/journal/vault dependency graph;
6. checked the six-operation tuple, access, opaque transport, token bound, and
   rotation rule;
7. enumerated the outcome tag/core/signer/expectation relationships;
8. checked status/error correlation, privacy rows, and nested admission
   outcomes;
9. exhausted the documented U1...U4 precedence and state families;
10. checked subject-target/delegation/catalog/consent constructibility;
11. checked current-head CAS independently from historical retention;
12. independently recalculated literal, Base64url, wrapper, response, and
    nested maxima;
13. inspected the shared legacy schemas and their fail-closed premises;
14. checked all six journal extensions, digest bindings, locks, and reducer
    branches;
15. checked that vault continuity makes no unsupported hardware claim;
16. reconciled the repo/package/path/test/fixture manifest; and
17. mechanically reconciled the finding headings before freeze.

No external premise was upgraded from `EMPTY` or `UNAVAILABLE` to PASS.

## 3. Executive verdict

S5 preserves important positive invariants and closes several static schema
shapes. It does not pass Lane A conformance.

Four P1 defects remain:

1. the local response-expectation/journal/vault digest graph is cyclic;
2. the pre-challenge outcome cannot have the required persisted expectation
   before the first challenge send;
3. binding/consent/catalog current-generation and revocation namespaces remain
   incomplete; and
4. the published normal and nested maxima are not semantically reachable.

Two P2 evidence defects remain:

1. the repo-qualified path/test dictionary is internally incomplete; and
2. the required boundary-fixture inventory does not cover every declared
   limit.

```text
P0: 0
P1: 4
P2: 2

S5 LANE A CELLPROTOCOL CONFORMANCE: NO-GO
S5 ORDERED COMPOSITION: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE: NO-GO
MATERIAL: NO-GO
PRODUCTION: NO-GO
```

All current accepted external authority, provider, vault, hardware, custody,
rollback, and durable-store proof sets remain EMPTY. This prevents a current
unsafe PASS and is why the static defects are P1, not P0.

## 4. Preserved positive invariants

### 4.1 Signed artifact construction

The signed protocol artifact construction itself remains acyclic:

```text
CJP-1 core
-> SignatureProtectedCore(coreSHA256)
-> length-framed signature
-> SignatureEnvelope
-> SignedArtifact(core, envelope)
-> signed-artifact digest
```

No signed core contains its own protected-core, signature, envelope, artifact,
or final artifact digest. Body, intent, challenge, request, and outcome remain
ordered:

```text
body -> intent -> challenge -> request -> signed outcome
```

This positive result does not close the separate local persistence cycle in
`P1-S5-A-01`.

### 4.2 Operations, access, and rotation

Exactly six wire operations are preserved:

| Operation/status kind | Resource/action source | Exact access |
|---|---|---|
| register/null | S3 exact operation table | `rw-s` |
| resolve/null | S3 exact operation table | `rw-s` |
| submit/null | S3 exact operation table | `rw-s` |
| status/registration | S3 exact operation table | `r--s` |
| status/admission | S3 exact operation table | `r--s` |
| revoke/null | S3 exact operation table | `rw-s` |
| deregister/null | S3 exact operation table | `rw-s` |

`token_rotation` is not a seventh operation. It is only register with
`mutationMode=token_rotation`.

### 4.3 Opaque transport and token privacy

Transport remains byte-preserving, semantically neutral, and
non-authoritative. First inner interpretation remains at the authenticated
Resolver/Cell boundary.

The raw APNS token is:

- opaque;
- required to be non-empty;
- bounded to `1...4096` raw bytes as a HAVEN resource allocation bound only;
  and
- forbidden from documents, fixtures, manifests, evidence, logs, analytics,
  diagnostics, crash reports, exports, UI, and accessibility.

No Apple token-length claim is made. No raw token or token hash was accessed by
this review.

## 5. RC1 — outcome, status, error, and expectation

### 5.1 Closed tagged union

The outcome tag/core mapping is exact:

| Protected `artifactKind` | Core schema | Case |
|---|---|---|
| `operation_success` | `cellprotocol.device-ingress.response-core.v3` | success |
| `authenticated_error` | `cellprotocol.device-ingress.authenticated-error-core.v2` | authenticated error |
| `admission_terminal_evidence` | `cellprotocol.device-ingress.admission-terminal-evidence-core.v2` | indeterminate/unavailable |

Validation selects the tag before the core schema, recomputes the core digest,
verifies the exact expectation-selected historical signer, then verifies
attempt fields. An error/evidence case cannot satisfy a success branch.

### 5.2 Success/status result binding

ResponseCore v3 binds:

- admission, body, intent, challenge, request, requester, target, and owner;
- exact operation and status kind;
- exact result bytes, result digest, and result schema;
- target-owner sequence and commit time.

The operation/result mapping is closed for register, resolve, submit, the two
status kinds, revoke, and deregister.

StatusResultCore v3 now separates:

```text
subject_current_unknown
correlation_not_found
privacy_unknown
```

The privacy-correlation conflict is corrected by
`correlationDisposition=suppressed_privacy` with null correlation digest.
Admission result nesting binds exact SignedOutcomeArtifact bytes/digest/kind
and prohibits recursive admission status.

These status and error corrections are statically sufficient. They are not
runtime evidence.

### 5.3 Expectation remains incomplete

OutcomeExpectationVariantCore correctly binds the union case, exact core
schema, result/error/evidence sets, phase, signer descriptor/key/algorithm,
and signer role.

ResponseExpectationCore v2 also binds exact operation attempt and authority
inputs. However, two independent construction failures prevent RC1 closure:

- its vault digest participates in the cycle in `P1-S5-A-01`; and
- its mandatory later-artifact fields cannot exist before a pre-challenge
  send, as detailed in `P1-S5-A-02`.

RC1 verdict: **PARTIAL / OPEN P1**.

## 6. RC2 — U1...U4 replay, expiry, terminal state, and compaction

The documented unique indexes are:

```text
U1 = composition + issuer + issuer generation + challenge ID
U2 = composition + requester + client intent ID
U3 = composition + requester + client nonce
U4 = composition + intent artifact digest
```

The serialized precedence is total for the described stored state:

1. authenticate/canonical-decode;
2. inspect U4 before state dispatch;
3. exact U4 equality dispatches to stored state;
4. U4 mismatch is replay conflict;
5. absent U4 inspects U2 and U3 together;
6. neither permits fresh allocation;
7. a conflicting U2/U3 is replay conflict;
8. a same-intent U2/U3 without U4 is corruption and readiness unavailable;
9. U1 random collision retries internally; and
10. exact bytes/state/indexes are atomically stored and read back.

The state/terminal mapping covers:

- active and expired unused;
- active/expired admitted pending;
- success, authenticated-error, indeterminate, and unavailable terminal;
- compacted unused and every compacted terminal family.

Expiry creates and stores one issuer-signed `challenge_expired` outcome and
consumes one issuer sequence once. Replay returns stored bytes and does not
re-sign. Compaction requires independent outcome bytes and preserves exact
read-back without reconstruction.

External trusted time, durable storage, rollback, and authority bytes are
missing. Therefore this is:

```text
STATIC STATE SHAPE: CLOSED
RUNTIME/DURABILITY/TRUSTED-TIME PASS: NONE
AFFECTED READINESS WITH CURRENT INPUTS: UNAVAILABLE
```

RC2 verdict: **CLOSED FOR STATIC STATE SHAPE / EXTERNAL PREMISES UNAVAILABLE**.

## 7. RC3 — subject-target binding, delegation, catalog, and consent

### 7.1 Positive tuple construction

S5 adds constructible signed schemas for:

- CatalogSignerDelegationCore;
- SubjectTargetBindingCore v2;
- ConsentArtifactCore v2; and
- AuthorizationCatalogEntryCore v2.

The subject-target core now binds the exact Agreement, Contract, Grant,
Conditions, consent, catalog, delegation, subject, target, owner, operation,
mode, status kind, purpose, resource, capability, access, and validity tuple.
Consent binds the exact authority/conditions/binding digests and a terms
notice. The catalog entry carries exact signed nested bytes plus their
digests.

The chain is constrained to direct target-owner signing or an exact
owner-authorized catalog delegation. Environment, repository, TLS,
administrator, test, and scaffold keys do not substitute.

### 7.2 Generation/revocation closure is still absent

The frozen bytes do not define one mechanically enforceable current namespace
for every mutable authority artifact:

- SubjectTargetBinding uniqueness includes random `bindingID`; it does not
  prevent two initially valid IDs for the same authorization tuple, and no
  current-binding head/CAS selects one.
- Consent declares monotonic replacement/withdrawal/revocation, but the core
  has no consent revocation generation or withdrawal artifact/ledger, and no
  exact current-consent key/CAS is defined.
- AuthorizationCatalogEntry has `entryID` and `entryGeneration`, but S5 does
  not define its cross-catalog generation namespace, current-entry selection,
  or replay/revocation transition.
- “generation is monotonic” and “prior generation unusable” are outcomes, not
  a byte-total rule for deciding the current row after restart, rollback, or
  concurrent signed alternatives.

The complete tuple equality cannot repair an undefined current-generation
selector. This is `P1-S5-A-03`.

All actual external authority inputs remain missing:

```text
accepted authority manifests = EMPTY
accepted target owners = EMPTY
accepted catalog signers = EMPTY
accepted subject-target bindings = EMPTY
accepted authorization entries = EMPTY
accepted outcome signers = EMPTY
affected readiness = UNAVAILABLE
```

The EMPTY rule is correctly fail-closed and receives no PASS credit.

RC3 verdict: **PARTIAL / OPEN P1 / CURRENT INPUTS UNAVAILABLE**.

## 8. RC4 — current subject head and retention independence

CurrentSubjectHeadCore supplies:

- a domain/subject/target-derived `headKey`;
- a random `headEpoch`;
- one unique current head per composition/head key;
- current registration, head, registration, and revocation generations; and
- active, revoked, or empty-after-deregister state.

The transition table is total across first enroll, re-enroll after
deregister, update/token rotation, reactivate, revoke, and deregister.
Head/registration/admission keys are locked before exact generation CAS.
Deregister clears the current pointer only after authoritative target
deletion and committed/read-back outcome. Re-enroll uses a new registration
ID.

This current-head CAS no longer depends on keeping historical IDs forever.
After permitted historical deletion, old bytes do not regain current
authority because mutation requires exact equality with the current head.

`MBI-PRIVACY-RETENTION-01` remains genuinely open for:

- tombstone/head/history duration;
- legitimate purpose;
- same-subject disclosure;
- backup/restore;
- compaction/deletion; and
- truthful user wording.

No duration is invented. Until Kjetil decides:

```text
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE/HISTORICAL COMPACTION: DISABLED
PRIVACY CLAIM: NONE
```

RC4 verdict: **CLOSED FOR STATIC CURRENT-HEAD/CAS / PRIVACY POLICY OPEN**.

## 9. RC5 — independent maxima reproduction

### 9.1 Correctly reproduced equations

For unpadded Base64url:

```text
B64(n) = 4 * floor(n / 3)
       + (n mod 3 == 0 ? 0 : (n mod 3 + 1))
```

SignatureProtectedCore contributions reproduce:

```text
78 + 44 + 79 + 138 + 66 + 91 + 2 braces + 5 commas = 503
B64(503) = 671
B64(1024) = 1366
SignatureEnvelopeMax = 14 + 671 + 76 + 1366 + 2 = 2129
B64(2129) = 2839
Artifact(C) = 92 + B64(C) + 2839
Artifact(8192) = 92 + 10923 + 2839 = 13854
Artifact(16384) = 92 + 21846 + 2839 = 24777
```

The operation request equation also reproduces:

```text
84 + B64(65536) + B64(24777)
= 84 + 87382 + 33036
= 120502
```

These reproduced arithmetic rows do not make the response maxima correct.

### 9.2 Response maximum is not semantically reachable

S5 claims the empty-result ResponseCore v3 fixed contribution is 1160. That
row simultaneously chooses:

- the longest operation string, `deregister`;
- non-null longest status kind, `registration`; and
- an arbitrary 96-byte `resultSchema`.

No closed response variant permits that tuple:

- deregister requires `statusKind=null`;
- status/registration requires `operation=status`; and
- the longest mapped result schema is 54 bytes, not an arbitrary 96-byte
  schema.

Reconstructing each valid fixed empty-result variant gives:

| Valid operation/status | Mapped result-schema bytes | Fixed bytes |
|---|---:|---:|
| register/null | 52 | 1104 |
| resolve/null | 50 | 1101 |
| submit/null | 50 | 1100 |
| status/registration | 49 | 1109 |
| status/admission | 49 | 1106 |
| revoke/null | 50 | 1100 |
| deregister/null | 54 | 1108 |

Even under the charitable, unproved assumption that every mapped result schema
can produce a semantically valid 65536-byte result core, the response is at
most:

```text
1109 + B64(65536)
= 1109 + 87382
= 88491

Artifact(88491)
= 92 + 117988 + 2839
= 120919
```

S5 instead claims `88542` and `120987`. A real exact reachable maximum could
be smaller because each result schema has its own structure; it must be
derived per result schema. The review does not invent that missing value.

### 9.3 Nested admission maximum inherits the defect

The exact empty-outcome admission StatusResultCore v3 fixed contribution
reproduces as 683. However, the outer admission response must use the exact
status/admission response fixed contribution 1106, not generic 1160.

Using the charitable upper bound above:

```text
AdmissionStatusResultCore
= 683 + B64(120919)
= 683 + 161226
= 161909

AdmissionReadbackResponseCore
= 1106 + B64(161909)
= 1106 + 215879
= 216985

AdmissionReadbackOutcomeArtifact
= 92 + B64(216985) + 2839
= 92 + 289314 + 2839
= 292245
```

S5 claims `161999`, `217159`, and `292477`. Consequently the declared
`max-1/max/max+1` acceptance fixtures at 120986...120988 and
292476...292478 cannot be semantically reachable under the frozen mapping.

RC5 verdict: **OPEN P1**.

## 10. RC6 — legacy discovery, inventory, quarantine, and readiness

The shared static schema now supplies:

- finite signed discovery-root IDs;
- descriptor-relative no-follow discovery;
- metadata-only artifact identity;
- a closed artifact-class and inventory-state set;
- serialized inventory/adjudication transitions;
- signed procedure attestations that never contain or hash a token;
- one transactional readiness generation; and
- explicit crash-before/after commit/read-back branches.

Unknown/unreadable roots, nonterminal artifacts, missing attestations,
rollback failure, restored/unseen copies, or missing provider proof keep both
readiness booleans false.

The following remain absent:

```text
durability provider
finite discovery/backup custody proof
sealed migration procedure
deactivation procedure
disposal procedure
backup/restore proof
```

Therefore:

```text
accepted provider/procedure proof sets = EMPTY
legacy/provider delivery readiness = UNAVAILABLE
runtime disposal PASS = NONE
```

The schemas do not falsely claim actual deletion or disposal.

RC6 verdict: **CLOSED FOR STATIC FAIL-RED SCHEMA / EXTERNAL PREMISES UNAVAILABLE**.

## 11. RC7 and RC8 — journal, reducer, and vault continuity

### 11.1 Six journal extension schemas

S5 defines exactly one extension schema for each operation:

```text
register
resolve
submit
status
revoke
deregister
```

OperationJournalCore v2 binds exact extension bytes, extension SHA-256,
extension schema, expectation, attempt digests, status kind, resource keys,
transaction sequence, and vault proof.

The conflict keys correctly group:

- register/revoke/deregister/status-registration by registration head;
- resolve/submit by ticket lineage; and
- every protected request/status-admission by admission.

Sorted acquisition, one stable store, descriptor-relative protection, CAS,
file+directory or equivalent database durability, rollback anchor, and
read-back are mandatory. Missing platform proof makes readiness unavailable.

The reducer keeps authenticated errors/evidence out of success. Resolve
delivery requires an external durable idempotent sink. Deregister preserves
authoritative server commit and fresh status before local erasure.

### 11.2 Vault continuity is honest about missing hardware

VaultContinuityCore/Envelope distinguish:

- non-exportability;
- copy resistance;
- rollback resistance;
- custody/recovery;
- hardware attestation; and
- stable-media durability.

The schema does not call a fingerprint, boolean, copied MAC key, or
non-exportable key alone a device proof. Current accepted proof sets are EMPTY
and:

```text
Binding protected-operation readiness = UNAVAILABLE
hardware PASS = NONE
copy-resistance PASS = NONE
rollback-resistance PASS = NONE
```

This is the correct fail-closed classification, not a PASS.

### 11.3 Local digest graph is cyclic

The positive journal/vault shapes cannot be constructed as one exact
transaction because:

```text
ResponseExpectationCore.vaultContinuityProofSHA256 -> Vault envelope/core
VaultContinuityCore.latestExpectationSHA256         -> ResponseExpectationCore

OperationJournalCore.expectationSHA256              -> ResponseExpectationCore
OperationJournalCore.vaultContinuityProofSHA256     -> Vault envelope/core
VaultContinuityCore.journalRootSHA256                -> root containing OperationJournalCore
```

S5 defines no predecessor/successor generation, prior-root rule, or staged
commit digest that breaks these cycles. “One stable-media transaction” does
not solve byte construction: each final digest still depends on bytes whose
final digest depends on it.

This is `P1-S5-A-01`.

RC7 verdict: **PARTIAL / OPEN P1 / RUNTIME STORE AND SINK UNAVAILABLE**.

RC8 verdict: **PARTIAL / OPEN P1 / HARDWARE-CUSTODY-ROLLBACK SETS EMPTY**.

## 12. Repo, package, fixture, and test applicability

### 12.1 Positive path closure

S5 now distinguishes:

```text
repo://CellProtocol
repo://CellScaffold
repo://Binding
```

It assigns one final-byte owner to Package.swift, the Binding project,
Package.resolved, entitlements, each proposed source/test/doc path, and Apple
release no-touch paths. The S4 Lane A ambiguity about which repository owns
`Package.swift` is statically closed.

Paths do not prove files, source behavior, compilation, fixtures, or runtime.

### 12.2 Path/test dictionary defects

The test-code dictionary names:

```text
repo://CellScaffold/Tests/AppTests/DeviceIngressChallengeTotalStateTests.swift
repo://CellScaffold/Tests/AppTests/DeviceIngressAuthorityBootstrapTests.swift
repo://CellScaffold/Tests/Support/DeviceIngressMaximaV3Independent.swift
```

but S5 section 14.3's repo-qualified CellScaffold owner/output ledger omits
those paths. Earlier relative paths do not satisfy S5's stated
repo-qualified/one-owner correction for the new v3 evidence ledger.

`C-MAX` points at a support calculator path as if it were itself an exact test
path/identifier, while no exact XCTest owner/caller is named for that support
calculator. The future consumer cannot reproduce one test-to-entry mapping
from the ledger alone.

This is `P2-S5-A-01`.

### 12.3 Boundary inventory defects

S5 section 10.6 requires semantic `max-1/max/max+1` fixtures for every limit.
F001...F100 include those triplets only for:

- protected core;
- signature envelope;
- claimed normal outcome;
- claimed nested admission outcome; and
- the upper token boundary, plus token zero.

The exact manifest omits complete triplets for at least:

- raw signature;
- intent core and artifact;
- challenge core and artifact;
- request core and artifact;
- every mapped result-core family;
- every valid ResponseCore variant;
- operation request;
- RegisterBodyCore; and
- the token lower bound `1` (`0/1/2`).

The two included outcome triplets are also invalidated by `P1-S5-A-04`.

This is `P2-S5-A-02`.

## 13. Findings

### P0

No P0 was found. No material implementation exists in this review scope, all
external authority/vault/provider sets remain EMPTY, and every material gate
remains closed.

### P1

#### P1-S5-A-01 — Response expectation, operation journal, and vault continuity form a digest cycle

Locations:

- S5 section 5.6, ResponseExpectationCore v2 member 34;
- S5 section 12.2, OperationJournalCore v2 members 5 and 18;
- S5 section 13.1, VaultContinuityCore members 6 and 7; and
- S5 sections 12.2/13.3, same-transaction requirements.

Exact cycle:

```text
E contains SHA(V)
V contains SHA(E)

J contains SHA(E) and SHA(V)
V contains root(J)
```

There is no final byte assignment for `E`, `J`, and `V` under those equations.
The signed protocol envelope graph is acyclic; this separate local persistence
graph is not.

Required static correction:

- define versioned predecessor and successor objects;
- bind an expectation/journal to the immediately prior verified vault
  checkpoint;
- let a new vault checkpoint bind the committed expectation/journal root;
- define exact generations and CAS/read-back ordering; and
- add cross-generation, self-reference, wrong-root, rollback, and crash-window
  fixtures.

External EMPTY sets prevent current operation but do not close the schema.

Verdict: **OPEN P1**.

#### P1-S5-A-02 — Pre-challenge authenticated error has no constructible pre-send expectation

Locations:

- S3 section 7.3, challenge is obtained before request/admission;
- S5 section 5.3, `phase=pre_challenge` has null challenge/request/admission/
  target fields;
- S5 section 5.6, ResponseExpectationCore v2 requires non-null admission,
  challenge, request, target, and authority attempt fields; and
- S5 section 5.6, “before any send” requires every reachable authenticated
  error phase.

The first challenge request can produce the defined issuer-signed
pre-challenge error. Before that send, challenge artifact, request artifact,
admission ID, and target-bound request do not yet exist. ResponseExpectationCore
v2 cannot be canonicalized with its required fields, and a post-challenge
expectation cannot authenticate an error already received.

Required static correction:

- define a separate intent/challenge-response expectation persisted before
  challenge acquisition, with only already-existing intent/body/requester and
  issuer-policy inputs; or
- narrow ResponseExpectationCore explicitly to post-challenge operation send
  and define the complete earlier expectation schema separately.

The error must remain fail-closed when no earlier expectation exists.

Verdict: **OPEN P1**.

#### P1-S5-A-03 — Mutable authority artifacts lack byte-total current-generation and revocation selectors

Locations:

- S5 sections 8.2–8.5; and
- S4 Lane A required correction for consent/entry ID, generation, replay, and
  revocation namespaces.

Random IDs plus monotonic prose do not identify one current signed artifact
after concurrency, restart, rollback, withdrawal, or multiple initially signed
alternatives. The binding uniqueness tuple includes its random ID; consent has
no withdrawal/revocation generation or current head; catalog entry has no
cross-catalog current-generation selector/CAS.

Required static correction:

- define stable tuple-derived current-head keys for binding, consent, and
  catalog entry;
- define unique generation/revocation namespaces and CAS transitions;
- define withdrawal/revocation artifacts or exact durable ledger rows;
- define rollback/restart selection; and
- add concurrent alternate-ID, same-generation, stale-revocation,
  cross-catalog, and replay fixtures.

Current external accepted sets remain EMPTY and readiness UNAVAILABLE.

Verdict: **OPEN P1**.

#### P1-S5-A-04 — Published response and nested maxima combine mutually exclusive fields

Locations:

- S5 sections 5.2, 6, and 10.2–10.6; and
- fixture entries F061...F066.

The claimed 1160-byte fixed ResponseCore combines deregister, registration
status, and an unmapped 96-byte result schema. The closed mapping permits no
such row. Valid fixed variants top out at 1109 before adding result bytes under
the most generous structural assumption. The claimed normal and nested
outcome limits therefore do not reproduce.

Required static correction:

- derive exact maxima per valid operation/status/result schema;
- prove each result-core maximum from its own schema;
- select the largest reachable variant only after those proofs;
- recompute both outer status layers using their exact fixed variants; and
- produce byte-exact reachable max-1/max/max+1 fixtures from independent
  calculators.

Verdict: **OPEN P1**.

### P2

#### P2-S5-A-01 — Repo-qualified test dictionary and one-owner path ledger disagree

Locations:

- S5 sections 14.3, 15.2, and 15.3.

The B-REP, B-AUTH, and B-MAX dictionary paths are not all in the S5
repo-qualified owner/output ledger. C-MAX names support code as the test path
without an exact test caller/owner.

Required correction:

- add every dictionary path to the one-owner repo-qualified ledger;
- distinguish support calculator path from executable test path/identifier;
  and
- recheck F001...F100 against the corrected dictionary.

Verdict: **OPEN P2**.

#### P2-S5-A-02 — Boundary-fixture inventory is not complete for every declared limit

Locations:

- S5 sections 10.6 and 15.3.

The manifest promises every limit but omits the enumerated core/artifact,
signature, operation-request, body, result-family, response-variant, and token
lower-bound triplets.

Required correction:

- enumerate one exact max-1/max/max+1 entry for every independently declared
  limit and valid variant;
- name A/B/C applicability and exact tests for each; and
- regenerate the two outcome families only after `P1-S5-A-04` is closed.

Verdict: **OPEN P2**.

## 14. RC1...RC8 disposition

| Root | S5 static disposition after this review | External/material disposition |
|---|---|---|
| RC1 outcome/status/expectation | **PARTIAL / OPEN** — union and status rows close; E/J/V cycle and pre-challenge expectation are P1-S5-A-01/02 | authority/vault sets EMPTY; UNAVAILABLE |
| RC2 replay/expiry/compaction | **CLOSED FOR STATIC STATE SHAPE** | trusted-time/durability/rollback runtime PASS absent |
| RC3 binding/catalog/consent | **PARTIAL / OPEN** — tuple hashes close; current generation/revocation selector is P1-S5-A-03 | accepted authority sets EMPTY; UNAVAILABLE |
| RC4 current head/retention | **CLOSED FOR STATIC CAS** | privacy duration/purpose remains Kjetil-open; deregister production NO-GO |
| RC5 maxima | **OPEN** — P1-S5-A-04 | calculators/tests missing |
| RC6 legacy inventory/readiness | **CLOSED FOR STATIC FAIL-RED SCHEMA** | provider/procedure/custody proofs EMPTY; UNAVAILABLE |
| RC7 journal/reducer | **PARTIAL / OPEN** — six extensions/locks/reducer close; digest cycle is P1-S5-A-01 | store/sink proofs EMPTY; UNAVAILABLE |
| RC8 vault continuity | **PARTIAL / OPEN** — proof slots/no-false-hardware close; digest cycle is P1-S5-A-01 | hardware/custody/rollback/store proofs EMPTY; no PASS |

## 15. S4 Lane A finding disposition

The S4 Lane A review terminal count independently reproduces as:

```text
P0/P1/P2 = 0/5/2
```

| S4 Lane A finding | S5 review disposition |
|---|---|
| P1-S4-A-01 result/status/error byte-total | **PARTIAL / OPEN** — status/correlation and union improve; pre-challenge expectation remains P1-S5-A-02 and the local cycle P1-S5-A-01 |
| P1-S4-A-02 challenge replay after expiry | **CLOSED FOR STATIC STATE SHAPE** — U4-before-state, stored expiry bytes, compacted ledger, and exact replay are defined; runtime premises unavailable |
| P1-S4-A-03 subject-target/consent/catalog | **PARTIAL / OPEN** — exact digests/artifacts added; current generation/revocation namespaces remain P1-S5-A-03 |
| P1-S4-A-04 maxima algebra | **OPEN** — P1-S5-A-04 |
| P1-S4-A-05 permanent ID retention | **STATIC CURRENT-HEAD/CAS CLOSED / PRIVACY OPEN** — no duration chosen; Kjetil decision preserved |
| P2-S4-A-01 fixture inventory | **PARTIAL / OPEN** — F001...F100 is a major improvement; P2-S5-A-02 remains |
| P2-S4-A-02 Package.swift repo/owner | **CLOSED FOR STATIC PATH PLAN** — repo-qualified Package.swift row and owner are exact; source evidence absent |

## 16. P2 class disposition

| S5 P2 class | Verdict |
|---|---|
| `S5-PATH-01` repo-qualified paths/owners | **PARTIAL / OPEN** — major path closure, but P2-S5-A-01 |
| `S5-EVIDENCE-01` fixture/applicability ledger | **PARTIAL / OPEN** — exact F001...F100 shape, but missing limits in P2-S5-A-02 and invalid maxima in P1-S5-A-04 |

## 17. Missing inputs and preserved gates

### 17.1 Expected unavailable inputs are not PASS

The following remain missing or EMPTY:

```text
Identity cutover
authority manifest and target-owner material
catalog signer/delegation/catalog
Agreement/Contract/Grant/Conditions/consent/revocation
trusted time and rollback anchor
legacy providers/procedures/custody
vault non-exportability/copy/rollback/custody/hardware proofs
durable local store and idempotent resolve sink
transport framing
MBI-06 Apple production signing/profile/entitlements evidence
MBI-07 integrated source/dependency/compiler-input/fixture/artifact evidence
```

Classification:

```text
accepted external sets = EMPTY
affected readiness = UNAVAILABLE
hardware PASS = NONE
production entitlement/profile/signing PASS = NONE
```

### 17.2 Frozen planning literals

```text
identity domain = domain:device:notification-callback
purpose         = purpose://access.audit.privacy/device-notification-callback
audience        = haven.digipomps.org
origin          = https://haven.digipomps.org
bundle          = org.digipomps.haven
APNS topic      = org.digipomps.haven
environment     = production
```

These literals are planning inputs, not proof of Apple, signing, APNS, device,
or production readiness.

### 17.3 Stop gates

```text
PLAN: NO-GO
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
NEXT PHASE: CLOSED / NO-GO
S6: CLOSED / NO-GO
PRODUCTION: CLOSED / NO-GO
```

`MBI-PRIVACY-RETENTION-01` remains open and owned by Kjetil. No privacy
duration, legitimate purpose, deletion, or disclosure policy is inferred.

## 18. Exact smallest successor scopes

No successor is authorized by this review. If admin later opens a new static
document-only correction, the smallest independent scopes are:

1. an acyclic local checkpoint protocol with prior-vault/current-operation/
   successor-vault generations and crash/CAS fixtures;
2. an intent/challenge expectation schema that exists before challenge send;
3. tuple-derived current heads and revocation transitions for binding,
   consent, and catalog entry;
4. per-result-schema reachable maxima and regenerated nested equations;
5. a corrected repo-qualified test/support owner dictionary; and
6. a complete per-limit semantic boundary manifest.

These are static successor descriptions only. They do not authorize S6,
source, material, build, test, network, Apple, Identity, device, APNS, staging,
or deployment work.

## 19. Mechanical finding-count reconciliation

Required heading patterns:

```text
^#### P1-S5-A-
^#### P2-S5-A-
```

Expected exact heading counts:

```text
P1 headings: 4
P2 headings: 2
```

Summary reconciliation:

```text
Executive verdict: 0/4/2
Findings section:   0/4/2
Final decision:     0/4/2
```

No P0 heading exists because no P0 finding exists.

## 20. Final decision

```text
REVIEW: FROZEN
REVIEWER: DISTINCT FROM S5 AUTHOR
TARGET SHA-256: 0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6
TARGET SHAPE: 2554 lines / 93787 bytes

P0: 0
P1: 4
P2: 2

SIGNED PROTOCOL ARTIFACT GRAPH: ACYCLIC
LOCAL EXPECTATION/JOURNAL/VAULT GRAPH: CYCLIC / NO-GO
SIX OPERATIONS: PRESERVED
TRANSPORT: OPAQUE / NON-AUTHORITATIVE
TOKEN: OPAQUE 1...4096 HAVEN-ONLY BOUND
RAW TOKEN OR TOKEN HASH EXPOSURE: NONE

RC1: PARTIAL / OPEN
RC2: STATIC SHAPE CLOSED / EXTERNAL UNAVAILABLE
RC3: PARTIAL / OPEN
RC4: STATIC CAS CLOSED / PRIVACY OPEN
RC5: OPEN
RC6: STATIC FAIL-RED CLOSED / EXTERNAL UNAVAILABLE
RC7: PARTIAL / OPEN
RC8: PARTIAL / OPEN / NO HARDWARE PASS

S5 LANE A CELLPROTOCOL CONFORMANCE: NO-GO
S5 ORDERED COMPOSITION: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
S6: NO-GO
SOURCE AUTHORIZATION: NONE
MATERIAL AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

This review grants no next-phase authority.
