# APNS S5 Normative Composition Contract Correction — CellScaffold Server Conformance Independent Review

Status: **REVIEW-FROZEN / LANE B STATIC CONFORMANCE NO-GO / S3+S4+S5 NO-GO / S6 NO-GO / SOURCE NO-GO / MATERIAL NO-GO / PRODUCTION NO-GO**

Review timestamp: `2026-07-25T01:38:06+02:00`  
Review role: independent CellScaffold Lane B reviewer, distinct from the S5
author  
Review scope: exact-byte static server-conformance review only  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S5_Normative_Composition_Contract_Correction_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md`

The output path was re-attested absent immediately before this artifact was
created. This review changes no S3/S4/S5 input and grants no authority for
source, configuration, provider, procedure, fixture, manifest, project,
dependency, Git, build, test, network, portal, signing, device, APNS, secret,
Identity, staging, deployment, integration, material, S6, next-phase or
production action.

This reviewer did not author S5. Author self-review receives no credit.

## 1. Exact reviewed bytes and immutable lineage

### 1.1 Reviewed S5 bytes

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md` | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554 | 93787 |

This review covers exactly those bytes.

### 1.2 Immutable author contracts

| Stage | Artifact | SHA-256 | Lines | Bytes |
|---|---|---|---:|---:|
| S3 | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 |
| S4 | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md` | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` | 2377 | 79288 |

The effective static composition is:

```text
S3 exact bytes
then S4 exact bytes
then S5 exact bytes
```

S5 replaces only conflicts it explicitly names. Unnamed S3/S4 clauses remain
normative.

### 1.3 Six immutable independent reviews

| Stage/lane | SHA-256 | Lines | Bytes | Terminal P0/P1/P2 |
|---|---|---:|---:|---:|
| S3 A | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 | `0/4/2` |
| S3 B | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 | `0/7/2` |
| S3 C | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 | `0/3/2` |
| S4 A | `c3a424c777907a7e9c749f2602f1f89252743c36e4f5abdb754dd4f8b98fcace` | 1006 | 34394 | `0/5/2` |
| S4 B | `1580b3e6206b548c8e2fa1f9ee3d134c77a8ff6b6ef1656a1126fc0598b36334` | 792 | 37012 | `0/5/2` |
| S4 C | `640fe35d9e2ef482c75d8093efe4eb914dd953e678ec4fd79e2b9053ab296985` | 917 | 32388 | `0/4/2` |

All hashes and shapes were independently reproduced from local exact bytes.
The S4 terminal lane counts are not summed into an invented S5 severity.

## 2. Method and severity boundary

The reviewer:

1. read all 2554 S5 lines;
2. reproduced S3, S4, S5 and all six review hashes/shapes;
3. mapped every S4 B finding and all eight S5 root causes;
4. traced the signed outcome union, status, direct error and admission
   read-back paths;
5. exhausted challenge U1...U4 precedence, expiry, pending, terminal,
   compaction, restart and exact replay;
6. traced AuthorityManifest → target owner → delegation → catalog →
   subject-target binding → Agreement/Contract/Grant/Conditions/consent;
7. verified that currently missing external authority keeps every accepted set
   empty and readiness unavailable;
8. traced the current subject head across enroll, update, rotation, revoke,
   deregister, re-enroll, history deletion, status and restart;
9. independently reproduced the printed Base64url/wrapper arithmetic and then
   checked semantic reachability of every claimed maximum;
10. traced legacy database, WAL, SHM, rollback journal, free-page, backup,
    snapshot, export and restored-copy discovery through readiness;
11. checked config/provider/procedure/store/test paths and all F001...F100
    applicability rows; and
12. preserved opaque transport, no-static-root, privacy, Identity, Apple,
    integrated-output and all stop gates.

Severity:

- **P0**: the document itself performs or opens a critical unsafe action;
- **P1**: the normative server contract is contradictory, unsafe or not
  implementation-bounding;
- **P2**: exact ownership, fixture, test or audit evidence remains incomplete
  without granting source authority.

No build/test was run. The arithmetic reproduction was a read-only checked
calculation, not a product test. No raw APNS token, token hash, key, credential,
secret or protected payload was read.

## 3. Executive verdict

```text
P0: 0
P1: 5
P2: 2
P0/P1/P2: 0/5/2

LANE B CELLSCAFFOLD STATIC CONFORMANCE: NO-GO
S5 STATIC CORRECTION: NO-GO
S5 ROOTS: PARTIAL CLOSURE
S4 B FINDINGS: PARTIAL CLOSURE
MBI-04 STATIC CONTRACT: PARTIAL / NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
MBI-PRIVACY-RETENTION-01: OPEN / KJETIL
IDENTITY CUTOVER: SEPARATE / UNAVAILABLE / NO-GO
EXTERNAL AUTHORITY SETS: EMPTY
EXTERNAL PROVIDER/PROCEDURE SETS: EMPTY
MBI-TRANSPORT-FRAMING-01: MISSING
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PLAN: NO-GO
NEXT PHASE: NO-GO
S6: NO-GO
SOURCE AUTHORIZATION: NONE
MATERIAL AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

There is no P0 because S5 keeps all material actions closed and safely makes
missing authority/provider proof sets empty. Five P1 static contradictions or
nonconstructible contracts and two P2 ownership/evidence gaps prevent Lane B
static GO.

## 4. Preserved and independently supported invariants

These requirements remain sound as static contracts:

- exactly six operations exist and token rotation is register-only;
- status is `r--s`; mutations are `rw-s`;
- the core/protected/signature/envelope/artifact and
  body/intent/challenge/request/outcome construction orders remain acyclic
  outside the authority-cycle finding below;
- transport is opaque, byte-preserving, semantically neutral and never grants
  authority;
- first inner decode, target selection and authority remain at the
  authenticated Resolver/Cell boundary;
- route, Host, TLS, origin, bundle/topic, environment, ID, token, admin, static
  file and test key grant no authority;
- APNS token input remains opaque, non-empty and at most 4096 bytes solely as a
  HAVEN resource bound;
- raw token and token hash leakage is forbidden across documents, fixtures,
  evidence, logs, analytics, diagnostics, crash reports, exports, UI and
  accessibility;
- server deregistration remains authoritative before Binding local erasure;
- status correlation suppression and admission absent/wrong-subject behavior
  remain oracle-safe;
- missing external signer, key, manifest, Identity, provider, procedure,
  hardware, custody, rollback and durability evidence yields EMPTY accepted
  sets and UNAVAILABLE readiness; and
- bundle/topic `org.digipomps.haven` and origin
  `https://haven.digipomps.org` remain planning literals, not production proof.

S5 also closes S4 B's authenticated-error terminal-kind and expiry-replay
contradiction as a narrow static contract: `challenge_expired` is a closed
error, one exact issuer-signed expiry outcome is stored, error terminal states
are explicit, and compacted replay uses the independent exact outcome ledger.

## 5. P1 findings

### P1-S5-B-01 — the success outcome union references five undefined v3 result schemas

**S5 locations**

- lines 217–264 define `ResponseCore v3` and map every operation/status kind to
  a `*.v3` result core;
- lines 183–215 require exact artifactKind/core-schema union selection;
- lines 1205–1236 size nested successful responses; and
- lines 2153–2348 assign outcome fixtures.

The mapped schemas are:

```text
register-receipt-core.v3
resolve-result-core.v3
submit-receipt-core.v3
status-result-core.v3
revoke-receipt-core.v3
deregister-receipt-core.v3
```

`status-result-core.v3` is defined in S5. The other five schemas covering the
five non-status success operations are only named. S5 supplies no member order, field
types, closed disposition enums, nullability, head epoch/generation relation,
generation equations, ticket/submission identity relation or byte maximum for
those v3 cores.

S4 defines earlier v2 cores, but S5 explicitly replaces the success mapping
with v3 literals. A canonical decoder cannot assume byte-identical v2 members,
and several S5 semantics require new head/outcome information that v2 does not
carry. “NormalResultCoreMax = 65536” is a size ceiling, not a schema.

**Impact**

CellScaffold cannot construct or validate a successful register, resolve,
submit, revoke or deregister outcome from the frozen composition. Different
servers can sign incompatible bytes under the same v3 schema name, and
consumer fixture acceptance cannot prove one canonical result.

**Smallest static correction**

Define every v3 result core completely or explicitly map an unchanged exact v2
schema without renaming it. Bind head epoch/generation and operation-specific
identifiers/generations/dispositions; update maxima and F001...F100 mappings
from those exact bytes.

**Verdict:** **OPEN P1 / S5-RC-01 NOT CLOSED**.

### P1-S5-B-02 — binding, consent and containing catalog form an impossible digest cycle

**S5 locations**

- lines 774–851 define `SubjectTargetBindingCore v2`;
- lines 853–891 define `ConsentArtifactCore v2`;
- lines 893–931 define `AuthorizationCatalogEntryCore v2`;
- lines 933–962 require complete cross-artifact equality; and
- lines 964–999 describe the signer chain and EMPTY accepted sets.

The required exact graph is cyclic:

```text
SubjectTargetBindingCore.authorityCatalogSHA256
  -> hash of the catalog that contains AuthorizationCatalogEntryCore

AuthorizationCatalogEntryCore.subjectTargetBindingArtifact
  -> exact signed SubjectTargetBindingArtifact

SubjectTargetBindingCore.consentSHA256
  -> exact ConsentArtifact

ConsentArtifactCore.subjectTargetBindingSHA256
  -> exact SubjectTargetBindingArtifact
```

No first exact byte string can be produced:

- the binding cannot be hashed until consent and catalog hashes are known;
- consent cannot be hashed until the binding hash is known; and
- the containing catalog cannot be hashed until its entry's binding bytes are
  known.

The direct-owner path also leaves
`SubjectTargetBindingCore.catalogSignerDelegationSHA256` nullability
unspecified, despite the catalog entry permitting null delegation only on the
direct path.

Separately, the prose says consent withdrawal/revocation and delegation
revocation invalidate older generations, but defines no signed consent
withdrawal/revocation artifact or exact accepted revocation-ledger input. A
numeric `revocationGeneration` inside the object being evaluated cannot prove
its own current non-revocation.

The current EMPTY-set rule is safe and prevents immediate authority. It does
not make a future non-empty catalog constructible.

**Impact**

No owner or delegated signer can produce the exact catalog/binding/consent
bytes demanded by the composition. An implementation must break a digest edge,
use a placeholder/fixpoint, or invent an external revocation rule, each
violating canonical equality.

**Smallest static correction**

Make the graph directed and acyclic, for example:

1. independently signed manifest/delegation;
2. binding intent/core that does not hash its containing catalog or future
   consent;
3. requester consent over that completed binding artifact;
4. catalog entry over completed delegation/binding/consent artifacts;
5. catalog artifact; and
6. separately typed signed revocation/withdrawal records and import ledger.

Bind the final catalog digest only in later challenge/request/expectation
objects. Define direct-path nullability exactly. Keep all actual authority sets
EMPTY until external bytes are independently supplied.

**Verdict:** **OPEN P1 / S5-RC-03 NOT CLOSED**.

### P1-S5-B-03 — current-head CAS inputs are not present in the signed server mutation bodies

**S5 locations**

- lines 1001–1085 define `CurrentSubjectHeadCore` and transitions;
- lines 1049–1085 require expected head generation comparison;
- lines 1593–1686 add `expectedHeadGeneration` and `registrationHeadEpoch` only
  to Binding-local journal extensions; and
- inherited S3 operation bodies remain the signed server inputs because S5
  defines no replacement body schemas.

The server mutation bodies still contain:

- register: registration ID plus expected registration/revocation generation;
- revoke: registration ID plus expected registration/revocation generation;
- deregister: registration ID plus expected registration/revocation
  generation.

They contain neither `headEpoch` nor `expectedHeadGeneration`.
`RegisterJournalExtensionCore`, `RevokeJournalExtensionCore` and
`DeregisterJournalExtensionCore` are Binding-local evidence and are not part of
the body digest consumed by CellScaffold. The subject-target binding also
contains no current head expectation.

The server can serialize on `headKey`, but it cannot perform the documented
caller-expectation comparison or distinguish an expected empty head epoch from
a deleted/recreated epoch using signed request bytes. The undefined v3 receipts
in P1-S5-B-01 also cannot return a normative head transition.

**Impact**

Two clients and the server can disagree on which head epoch/generation a
mutation authorized. After deletion/recreation or stale status, a request may
pass registration-generation checks without proving the claimed head CAS
precondition.

**Smallest static correction**

Define new canonical register/revoke/deregister body schemas carrying exact
nullable `expectedHeadEpoch` and `expectedHeadGeneration`, with first-enroll,
post-deregister enroll and recreated-head rules. Bind them through
intent/challenge/request and return exact new head epoch/generation in defined
result cores. Recompute maxima and fixtures.

**Verdict:** **OPEN P1 / S5-RC-04 PARTIAL ONLY**.

### P1-S5-B-04 — printed maxima arithmetic is reproducible, but the claimed accepted maxima are semantically unreachable

**Independent arithmetic reproduction**

The printed arithmetic itself reproduces:

```text
B64(503)   = 671
B64(1024)  = 1366
Envelope   = 2129
B64(2129)  = 2839

sum listed ResponseCore contributions = 1160
1160 + B64(65536) = 88542
Artifact(88542) = 120987

sum listed admission StatusResult contributions = 683
683 + B64(120987) = 161999
1160 + B64(161999) = 217159
Artifact(217159) = 292477
```

So there is no integer-arithmetic transcription error.

**Semantic contradiction**

The `1160` ResponseCore fixed contribution combines independent maxima that
cannot occur in one valid response:

```text
operation contribution 24     => operation = deregister
statusKind contribution 27    => statusKind = registration
resultSchema contribution 113 => arbitrary 96-byte schema value
```

But S5 requires:

- `statusKind=null` for deregister;
- `statusKind=registration` only when `operation=status`; and
- `resultSchema` equal one exact mapped schema, not an arbitrary 96-byte
  string.

Using the exact mapped literals, the three-field contribution and resulting
fixed total are:

| case | operation/status/schema contribution | fixed total |
|---|---:|---:|
| register | 108 | 1104 |
| resolve | 105 | 1101 |
| submit | 104 | 1100 |
| status/registration | 113 | 1109 |
| status/admission | 110 | 1106 |
| revoke | 104 | 1100 |
| deregister | 112 | 1108 |

No legal case reaches `1160`. The same problem affects the claim that
`RequestCoreMax=16384` and its artifact maximum are semantically reachable:
RequestCore has a closed member set, not an opaque padding field that can fill
an arbitrary byte ceiling.

Section 10.6 nevertheless requires accepted `max-1` and exact-`max` fixtures
and states that accepted maximum fixtures set every semantic member to its
allowed maximum. F061/F062 and F064/F065 therefore cannot be canonical
semantically valid fixtures at the published exact sizes.

The bounds are conservative enough to avoid undersizing, but the contract
claims exact reachable boundaries and independent equality. That claim is
false and makes producer/consumer acceptance nonconstructible.

**Smallest static correction**

Compute maxima per valid discriminated union case using exact schema literals
and nullability, then take the maximum over reachable cases. Distinguish an
allocation ceiling from a semantically reachable canonical maximum. Generate
boundary fixtures only for reachable objects, and derive nested read-back from
the corrected normal-outcome maximum.

**Verdict:** **OPEN P1 / S5-RC-05 NOT CLOSED**.

### P1-S5-B-05 — finite root lists do not provide an atomic finite inventory against concurrent artifact creation

**S5 locations**

- lines 1331–1349 define finite configured roots;
- lines 1351–1387 define descriptor metadata identity;
- lines 1389–1475 define inventory states/transitions;
- lines 1513–1542 allow readiness only after complete discovery; and
- lines 1544–1589 define stable-media premises and missing provider proofs.

The metadata-only identity, red default, durable states and EMPTY provider
proof sets are sound improvements. The discovery-completeness transition is
still not bounded against the external filesystem:

- a finite array of roots does not make each mutable directory tree a finite
  snapshot;
- no maximum depth/entry count/cursor epoch is defined;
- no filesystem snapshot, directory generation, event journal or watcher
  watermark fences enumeration;
- no name→opened-inode revalidation is required at the final readiness
  transaction;
- an export/backup/snapshot may be created, renamed or restored after its
  parent was enumerated but before `discoveryComplete=true`;
- the database transaction that commits counts/readiness does not serialize
  external file creation; and
- `metadataGeneration` is used in artifact identity but has no defined,
  provider-attested source or monotonic relation to root enumeration.

Before provider evidence exists, readiness is correctly UNAVAILABLE. If a
future provider merely implements the listed per-file stable-media steps, the
static interface still permits a scan race that publishes
`providerDeliveryAllowed=true` with an unseen plaintext-bearing artifact.

**Impact**

A newly created WAL sidecar, backup, export or restored copy can fall between
enumeration and readiness commit. It is absent from
`nonterminalArtifactCount` even though legacy material exists.

**Smallest static correction**

Require one reviewed discovery consistency primitive: immutable snapshot
generation, filesystem event-journal watermark plus rescan, or equivalent
provider proof. Bind every root and opened name/inode to that generation,
define bounded traversal/cursors, revalidate name→inode and root generation at
the readiness commit, and make any gap/overflow/change atomically red. Add
create/rename/restore races at every scan/commit boundary.

**Verdict:** **OPEN P1 / S5-RC-06 PARTIAL ONLY**.

## 6. P2 findings

### P2-S5-B-01 — the repo-qualified Lane B ledger omits retained core server paths and some named consumers

S5 section 14 declares that relative paths are never used without one repo
root and presents a one-owner ledger. Section 14.3 names new
config/provider/procedure paths, one legacy store, three tests and one consumer
ledger. It does not repeat or repo-qualify the still-required S4 Lane B paths
for:

- authority manifest/catalog/Agreement adapters;
- challenge issuer and challenge state machine;
- Resolver registration;
- admission, response, registration and sealed-token stores;
- registration/callback target adapters;
- registration/admission status services;
- revoke/deregister services;
- composition coordinator and operations runbook; and
- most S4 server tests.

S5 itself also names:

```text
repo://CellScaffold/Tests/AppTests/DeviceIngressChallengeTotalStateTests.swift
repo://CellScaffold/Tests/AppTests/DeviceIngressAuthorityBootstrapTests.swift
repo://CellScaffold/Tests/Support/DeviceIngressMaximaV3Independent.swift
```

in the test-code/calculator dictionaries without assigning them a row in the
section 14.3 final-byte owner ledger.

Because S5 says relative paths are never used, it cannot rely silently on S4's
relative path block while simultaneously claiming one complete repo-qualified
ledger.

**Smallest correction:** provide one complete repo-qualified Lane B
Cell/service/store/config/provider/procedure/test/fixture/docs table, including
all retained S4 paths and every S5 dictionary path, with one final-byte owner,
required input owners, reviewers and no-touch/collision disposition.

**Verdict:** **OPEN P2 / S5-PATH-01 PARTIAL ONLY**.

### P2-S5-B-02 — fixture applicability rows are enumerated, but their canonical manifest representation is underdefined

S5 materially improves fixture coverage by naming exactly F001...F100 and a
test code for each A/B/C decision. The producer manifest's canonical schema is
still incomplete:

- `consumerApplicability` is described as
  `required(testPath,testID,expectedDecision)` or
  `not_applicable(closedReason)` without a JSON schema, member order, tag,
  nullability or exact path/ID encoding;
- the per-entry member `negativeApplicability` is listed but never typed or
  mapped in F001...F100;
- role, expected-decision and sanitized-reason closed enums are not frozen;
- server consumer-ledger top-level/per-entry schemas and member order are
  described only in prose; and
- actual manifest/consumer hashes correctly remain future MBI-07 evidence, but
  no exact schema currently lets independent producers and consumers compute
  the same bytes.

The tabular applicability decisions are useful planning evidence. They do not
yet define the exact canonical manifest and server-consumption bytes claimed by
section 15.

**Smallest correction:** define exact tagged cores/member order for required
and not-applicable variants, remove or type `negativeApplicability`, close all
enums, and define the server consumer-ledger schema/member order. Preserve the
F001...F100 table and later bind actual hashes in MBI-07.

**Verdict:** **OPEN P2 / S5-EVIDENCE-01 PARTIAL ONLY**.

## 7. Eight-root disposition

| Root | Independent Lane B verdict | Exact basis |
|---|---|---|
| `S5-RC-01` outcome union/status/error read-back | **PARTIAL / OPEN P1** | Union discriminator, errors, correlation privacy and admission read-back are strong; successful v3 result schemas are undefined under P1-S5-B-01. |
| `S5-RC-02` challenge replay/expiry/terminal/compaction | **CLOSED AS STATIC DESIGN** | U4-first dispatch, stored expiry bytes, explicit success/error/evidence kinds, exact compacted-ledger replay and no reconstruction/re-signing are total. Runtime durability/rollback proof remains unavailable. |
| `S5-RC-03` binding/delegation/catalog/consent | **NO-GO / OPEN P1** | Typed artifacts and complete tuple are attempted, but binding↔consent↔catalog hashes are cyclic and revocation inputs are incomplete under P1-S5-B-02. Actual authority sets remain EMPTY. |
| `S5-RC-04` current subject head | **PARTIAL / OPEN P1** | Unique durable head and retention-independent behavior are good; signed server mutation bodies cannot carry the required head CAS under P1-S5-B-03. |
| `S5-RC-05` maxima | **NO-GO / OPEN P1** | Arithmetic reproduces, but the accepted maxima combine invalid discriminator values and are not semantically reachable under P1-S5-B-04. |
| `S5-RC-06` legacy inventory/quarantine | **PARTIAL / OPEN P1** | States, readiness and crash defaults are fail-closed; discovery has no atomic snapshot/watch fence under P1-S5-B-05. All provider/procedure proofs remain EMPTY. |
| `S5-RC-07` Binding journal/reducer | **SERVER INTERFACE PARTIAL / CLIENT CLOSURE NOT CREDITED HERE** | Outcome/error gates and server-before-local-erasure contract are preserved. Binding stable-store/sink proofs remain EMPTY; a Lane B review does not grant Lane C closure. |
| `S5-RC-08` vault continuity | **EXACT FAIL-CLOSED SLOTS / OPERATIONAL UNAVAILABLE, NOT PASS** | Copy, rollback, custody, hardware and durability are correctly separated and all accepted proof sets are EMPTY. This closes no external premise or Identity gate. |

Root summary:

```text
STATIC CLOSED IN LANE B: RC-02 only
PARTIAL / OPEN P1: RC-01, RC-03, RC-04, RC-05, RC-06
CLIENT-SCOPE / EXTERNAL UNAVAILABLE: RC-07, RC-08
```

No external signer/key/hardware/Identity/provider premise is labelled PASS.

## 8. S4 Lane B finding closure ledger

| S4 B finding | S5 independent verdict | Exact residual |
|---|---|---|
| `P1-S4-B-01` SubjectTargetBinding artifact | **PARTIAL / OPEN P1** | S5 supplies an artifact kind/signer/delegation, but its consent/catalog hash graph is cyclic under P1-S5-B-02. |
| `P1-S4-B-02` authorization catalog tuple | **PARTIAL / OPEN P1** | Tuple fields and delegation improve; cycle plus missing typed withdrawal/revocation input remain P1-S5-B-02. |
| `P1-S4-B-03` challenge error/expiry replay | **CLOSED AS STATIC DESIGN** | Expiry is a closed stored outcome; authenticated errors have exact terminal kinds; compacted replay uses exact independent ledger bytes. |
| `P1-S4-B-04` current subject head | **PARTIAL / OPEN P1** | Durable head solves repeated-row ambiguity, but expected epoch/generation do not cross the signed server request under P1-S5-B-03. |
| `P1-S4-B-05` legacy durable adjudication | **PARTIAL / OPEN P1** | Exact states/readiness/stable-media premises exist; complete discovery can race external artifact creation under P1-S5-B-05. |
| `P2-S4-B-01` config/provider/procedure paths | **PARTIAL / OPEN P2** | New paths are named, but the asserted complete repo-qualified ledger omits retained server Cells/services/stores/tests under P2-S5-B-01. |
| `P2-S4-B-02` producer fixture consumption | **PARTIAL / OPEN P2** | F001...F100 applicability is tabulated; exact canonical applicability/consumer schemas remain P2-S5-B-02. |

S4 B P1 closure count:

```text
CLOSED AS STATIC DESIGN: 1
PARTIAL / OPEN: 4
```

P1-S5-B-01 and P1-S5-B-04 are cross-root defects independently exposed while
reviewing S5; they are not duplicate S4 B headings.

## 9. `MBI-04` disposition

| MBI-04 element | Static verdict | Missing or contradictory input |
|---|---|---|
| production issuer | **FAIL-CLOSED STRUCTURE / UNAVAILABLE** | Signer/delegation slots exist, but actual manifest/key/rotation/revocation bytes are EMPTY; authority graph cycle P1-S5-B-02 prevents non-empty construction. |
| durable challenge/admission/replay | **STATIC DESIGN CLOSED / OPERATIONAL OPEN** | State/replay bytes are total; database/rollback runtime proof is missing. |
| Resolver target Cells | **PARTIAL / NO-GO** | No-create/EMPTY behavior is correct; binding/catalog cycle and incomplete repo-qualified Cell path ledger remain. |
| Agreement/Contract/Grant/Conditions/consent source/output | **PARTIAL / OPEN P1** | Exact tuple is attempted, but the signed artifact graph and revocation path remain nonconstructible. |
| current registration status/CAS | **PARTIAL / OPEN P1** | Head row is exact; signed request does not carry its CAS expectation. |
| legacy storage readiness | **PARTIAL / OPERATIONAL UNAVAILABLE** | Provider sets are EMPTY and scan consistency remains P1-S5-B-05. |

Overall:

```text
MBI-04 STATIC CONTRACT: PARTIAL / NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
```

S5 remains a document-only correction and does not close MBI-04.

## 10. Adversarial server-conformance matrix

| Requirement | Verdict |
|---|---|
| Opaque, byte-preserving transport | **PASS AS STATIC INVARIANT** |
| No authority or semantic decision in transport | **PASS AS STATIC INVARIANT** |
| No static/admin/route/TLS/topic admission root | **PASS** |
| Exactly six operations and register-only rotation | **PASS** |
| Outcome discriminator and non-success separation | **PASS IN UNION / SUCCESS RESULT SCHEMAS P1-S5-B-01** |
| Status/error/admission read-back privacy | **PASS AS STATIC DESIGN** |
| Challenge replay/expiry/terminal/compaction | **PASS AS STATIC DESIGN / RUNTIME UNAVAILABLE** |
| Subject-target/delegation/catalog/consent | **NO-GO / P1-S5-B-02** |
| Missing authority produces EMPTY sets | **PASS AS FAIL-CLOSED INTERFACE, NOT AUTHORITY PASS** |
| Current-head uniqueness/re-enroll/deregister | **PARTIAL / P1-S5-B-03** |
| No permanent-retention assumption | **PASS AS STATIC REQUIREMENT / KJETIL DECISION OPEN** |
| Independent maxima arithmetic | **NUMBERS REPRODUCED / SEMANTIC MAXIMA NO-GO P1-S5-B-04** |
| Variable opaque token 1...4096 | **PASS AS HAVEN RESOURCE BOUND** |
| Token/token-hash non-leakage | **PASS AS STATIC REQUIREMENT** |
| Legacy finite inventory and stable identity | **PARTIAL / SCAN RACE P1-S5-B-05** |
| Provider/procedure/durability proofs | **EMPTY / UNAVAILABLE, NOT PASS** |
| Server config/provider/procedure/store path ledger | **PARTIAL / P2-S5-B-01** |
| Fixture applicability/consumer evidence | **PARTIAL / P2-S5-B-02** |
| Server deregister before local erase | **PASS AS STATIC ORDER** |
| Privacy retention decision | **OPEN / KJETIL / NO CREDIT** |
| Identity cutover | **SEPARATE / UNAVAILABLE / NO-GO** |
| Apple signing/profile/entitlement | **MBI-06 UNAUDITED / MISSING** |
| Integrated exact output | **MBI-07 MISSING** |

## 11. External premises and mandatory EMPTY/UNAVAILABLE states

### 11.1 Identity and authority

No frozen input supplies actual manifest, target-owner key, delegation,
catalog, Agreement, Contract, Grant, Conditions, consent, revocation,
trusted-time, rollback or Identity cutover bytes.

Mandatory current state:

```text
accepted authority manifests = EMPTY
accepted target owners = EMPTY
accepted catalog signers = EMPTY
accepted subject-target bindings = EMPTY
accepted authorization entries = EMPTY
accepted outcome signers = EMPTY
affected readiness = UNAVAILABLE
```

This is a correct fail-closed interface. It is not a PASS for external
authority, signer control or Identity.

### 11.2 Legacy providers and procedures

No frozen input supplies the durability, discovery custody, sealed migration,
deactivation, disposal or backup/restore proofs named by S5.

Mandatory current state:

```text
accepted durability providers = EMPTY
accepted discovery-custody proofs = EMPTY
accepted migration procedures = EMPTY
accepted deactivation procedures = EMPTY
accepted disposal procedures = EMPTY
accepted backup/restore proofs = EMPTY
legacy/provider delivery readiness = UNAVAILABLE
provider delivery allowed = false
register mutation allowed = false
```

Schema and future paths do not fill those sets.

### 11.3 Vault/hardware/custody

The vault continuity slots correctly distinguish copy resistance, rollback
resistance, hardware/custody proof and platform durability. None is supplied.

```text
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

Lane B does not promote these client/external premises.

## 12. Privacy, framing, Apple and integrated-output gates

### 12.1 `MBI-PRIVACY-RETENTION-01`

Exact owner:

```text
Kjetil
```

Still undecided:

- legitimate purpose;
- tombstone/head/historical-record duration;
- same-subject disclosure duration;
- compaction/deletion;
- backup/restore exposure and destruction;
- revoke-retained ciphertext permission/duration; and
- truthful user-facing wording.

Mandatory unchanged gate:

```text
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE/HISTORICAL COMPACTION: DISABLED
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

S5's before/after-deletion state machine does not authorize deletion.

### 12.2 Framing

`MBI-TRANSPORT-FRAMING-01` remains missing:

- HTTPS method/path;
- carrier/media bytes;
- outer fields/order;
- exact framing overhead;
- status/error mapping;
- proxy/effective-authority rule; and
- deterministic framing fixtures.

Transport remains semantically neutral and cannot grant authority.

### 12.3 Apple and integrated output

```text
MBI-06:
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING

MBI-07:
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/fixture/evidence/artifact manifest
= MISSING
```

No APNS provider acceptance, physical device delivery or callback is claimed.

## 13. Exact smallest successor scopes

No successor is authorized by this review. If development-admin later opens a
new document-only correction, the smallest non-overlapping scopes are:

1. **Outcome result correction:** define every successful v3 result core,
   dispositions, generations, IDs and head relation.
2. **Acyclic authority correction:** reorder binding/consent/catalog digests,
   define direct delegation nullability and typed revocation/withdrawal
   records.
3. **Head-CAS wire correction:** add head epoch/generation expectations to
   signed server mutation bodies and exact results.
4. **Reachable-maxima correction:** compute per-valid-union-case maxima and
   distinguish allocation ceilings from reachable canonical boundaries.
5. **Legacy discovery consistency correction:** bind snapshot/event-watermark
   generation, traversal bounds, name→inode revalidation and readiness commit.
6. **Lane B path/evidence correction:** complete the repo-qualified
   Cell/service/store/config/provider/procedure/test ledger and canonical
   F001...F100 applicability/consumer schemas.
7. **New independent exact-byte Lane B review:** reviewer distinct from every
   correction author.

No scope authorizes S6, source or any material phase.

## 14. Preserved stop gates

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

## 15. Mechanical finding-count reconciliation

The authoritative explicit finding headings in this artifact are:

```text
P0 headings: 0
P1 headings: 5
P2 headings: 2
P0/P1/P2: 0/5/2
```

The executive verdict and final decision use exactly the same current-review
count. S3/S4 IDs in closure ledgers are lineage references, not new headings.

## 16. Final independent decision

```text
REVIEWED PATH:
Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md

REVIEWED SHA-256:
0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6

REVIEWED SHAPE:
2554 LINES / 93787 BYTES

P0: 0
P1: 5
P2: 2
P0/P1/P2: 0/5/2

LANE B CELLSCAFFOLD STATIC CONFORMANCE: NO-GO
S5 STATIC CORRECTION: NO-GO
S5 ROOTS: PARTIAL CLOSURE
S4 B FINDINGS: PARTIAL CLOSURE
MBI-04 STATIC CONTRACT: PARTIAL / NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
MBI-PRIVACY-RETENTION-01: OPEN / KJETIL
IDENTITY CUTOVER: SEPARATE / UNAVAILABLE / NO-GO
EXTERNAL AUTHORITY SETS: EMPTY
EXTERNAL PROVIDER/PROCEDURE SETS: EMPTY
MBI-TRANSPORT-FRAMING-01: MISSING
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING

PLAN: NO-GO
NEXT PHASE: NO-GO
S6: NO-GO
SOURCE AUTHORIZATION: NONE
MATERIAL AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

This review stops after freezing and re-attesting this one artifact. It grants
no source, Git, dependency, build, test, network, portal, signing, archive,
device, APNS, secret, Identity, staging, deployment, integration, material,
S6, next-phase or production authority.
