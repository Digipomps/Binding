# APNS S4 Normative Composition Contract Correction — CellScaffold Server Conformance Independent Review

Status: **REVIEW-FROZEN / LANE B CONFORMANCE NO-GO / S4 NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Review timestamp: `2026-07-25T01:03:25+02:00`  
Review role: independent CellScaffold Lane B conformance reviewer, distinct from
the S4 author  
Review scope: exact-byte static server-conformance review only  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md`

The review path was re-attested absent immediately before this artifact was
created. This review changes no S3/S4 input and grants no authority for source
edits, Git mutation, dependency resolution, build, test, network, portal,
signing, archive, device action, APNS contact, secret access, Identity action,
staging, deployment, integration, or a next material phase.

This reviewer did not author the S4 correction. Author self-review receives no
credit.

## 1. Exact reviewed bytes and immutable lineage

### 1.1 Reviewed S4 bytes

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md` | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` | 2377 | 79288 |

The review covers exactly those bytes.

### 1.2 Immutable S3 inputs

| Role | Artifact | SHA-256 | Lines | Bytes |
|---|---|---|---:|---:|
| S3 contract | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 |
| Lane A review | `Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 |
| Lane B review | `Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 |
| Lane C review | `Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 |

The immutable S3 review finding counts are:

```text
A = P0/P1/P2 0/4/2
B = P0/P1/P2 0/7/2
C = P0/P1/P2 0/3/2
```

The older inherited `0/2/1` summary is not used as the S3 finding count.

### 1.3 Effective contract

The reviewed static composition is the ordered pair:

```text
S3 exact bytes
then
S4 exact bytes
```

S4 replaces only conflicts it names. Every unaffected S3 requirement remains
normative. This review does not silently select the more permissive text.

## 2. Review method and severity

The reviewer:

1. read all 2377 S4 lines;
2. reproduced the S4 and four immutable S3 artifact hashes and shapes;
3. reproduced all seven S3 Lane B P1 and two P2 findings;
4. traced requester, target Cell, target owner, response signer and first
   enrollment through no-create resolution;
5. traced authority manifest, catalog, Agreement, Contract, Grant, Conditions,
   consent, import, use-time checks, rotation, revocation and rollback;
6. traced every challenge state, uniqueness constraint, replay branch,
   terminal artifact, restart branch and compaction branch;
7. traced current registration selection, CAS, revoke, deregister, re-enroll,
   read-back and status disclosure;
8. checked the oracle-safe status matrix and the nested-size equations;
9. checked opaque token handling and legacy database/WAL/SHM/journal/backup/
   snapshot/export quarantine;
10. checked every proposed Lane B Cell/service/store/config/test/fixture path
    and producer-consumer assertion; and
11. preserved all Identity, privacy, framing, Apple, integrated-output and
    material-action gates.

Severity:

- **P0**: the document itself opens or performs a critical unsafe action;
- **P1**: the normative server contract is contradictory, unsafe, or not
  implementation-bounding;
- **P2**: exact path, fixture, test or audit ownership remains incomplete
  without independently granting source authority.

No build or test was run or claimed. No raw APNS token, token hash, private
key, credential, protected payload or secret was read.

## 3. Executive verdict

```text
P0: 0
P1: 5
P2: 2

LANE B CELLSCAFFOLD SERVER CONFORMANCE: NO-GO
S4 STATIC CORRECTION: NO-GO
S3 B FINDINGS: PARTIAL CLOSURE
MBI-04 STATIC CONTRACT: PARTIAL / NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
MBI-PRIVACY-RETENTION-01: OPEN / KJETIL
MBI-TRANSPORT-FRAMING-01: MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

There is no P0 because every material action remains closed and every
authority-dependent accepted set is explicitly empty when its evidence is
missing. Five P1 contradictions or nonconstructible contracts and two P2
ownership/evidence gaps prevent Lane B static conformance.

## 4. Preserved and newly supported server invariants

The following S3 passes survive S4 and are not reopened by this review:

- transport remains semantically opaque, byte-preserving and
  non-authoritative;
- first inner decode and every authority decision remain at the authenticated
  Resolver/Cell boundary;
- exactly six operations remain: `register`, `resolve`, `submit`, `status`,
  `revoke`, `deregister`;
- status remains `r--s`, mutations remain `rw-s`, and token rotation remains a
  `register` mutation mode;
- body → intent → challenge → request → result/response remains acyclic;
- admission IDs, registration IDs, transport, TLS, host, origin, bundle/topic,
  static files, app administration and test keys grant no authority;
- challenge/use-time authorization checks are both required;
- target authority and target execution use the same selected instance;
- revoke and deregister remain distinct;
- deregister still requires authoritative endpoint and recoverable-token
  deletion before success, with a minimal signed tombstone and no resurrection;
- actual Identity/authority bytes remain missing and accepted requester,
  target, owner, signer and catalog sets remain empty;
- bundle/topic `org.digipomps.haven` and origin
  `https://haven.digipomps.org` remain planning bindings only; and
- source, production signing, APNS, device and integrated provenance remain
  unavailable.

S4 also statically closes these narrow S3 Lane B defects:

- admission absent, wrong-subject and wrong-target selectors now have one
  `privacy_unknown` outward shape and a closed nullability matrix;
- nested response maxima are algebraically satisfiable:
  `120830`-byte normal signed response, `161673`-byte admission status result,
  `216610`-byte enclosing response core and `291740`-byte signed read-back;
- the APNS token is opaque and variable length `1...4096`, explicitly a HAVEN
  allocation bound rather than an Apple token-length claim;
- typed indeterminate/unavailable evidence cores and states now exist in
  principle; and
- the Lane B path plan now names the previously omitted authority catalog Cell,
  challenge issuer Cell, response store, split status services, target
  adapters, revoke service and deregister service.

These are static requirements only. The findings below limit their closure.

## 5. P1 findings

### P1-S4-B-01 — `SubjectTargetBindingArtifact` is named but has no constructible signed-artifact contract

**S4 locations**

- lines 1067–1116 define four reference cores;
- lines 1118–1137 define `SubjectTargetBindingCore` and incorrectly say “the
  three nested refs” although the member list contains four:
  `requesterSubject`, `responseSigner`, `targetCell`, `targetOwner`;
- lines 1148–1153 require the relation to be a signed binding;
- lines 1157–1165 make `resolveExistingSubjectTarget` return an exact
  `SubjectTargetBindingArtifact`;
- lines 1176–1179 require that signed artifact before first enrollment; and
- lines 1291–1297 extend the closed artifact-kind enum without adding a
  subject-target binding kind.

There is no exact `SubjectTargetBindingArtifact` construction. In particular,
the correction supplies no:

- artifact kind for this core;
- protected-core/signature/signed-artifact binding for it;
- binding-artifact digest;
- catalog-entry member that carries those exact signed bytes and digest;
- authority-manifest relation that authorizes its signer;
- exact four-ref decoding rule; or
- import-ledger field that proves the exact binding was accepted and read back.

`bindingID` being “from the signed authority catalog” is not a byte relation.
The catalog entry at lines 1228–1250 carries Agreement, Conditions, consent,
Contract and Grant artifacts, but no binding artifact or digest. A server can
therefore not derive the exact artifact returned by
`resolveExistingSubjectTarget` or prove that its target owner and response
signer were the relation accepted by the authority manifest.

The EMPTY-set/readiness-unavailable rule is safe for the current missing input,
but it does not make the future first-enrollment authority path constructible.

**Impact**

Implementations can invent different binding wrappers, signers, catalog links
or four-ref interpretations. That can substitute a target owner or response
signer while apparently satisfying the no-create lookup.

**Smallest static correction**

Define one exact signed binding artifact kind and construction; name all four
nested refs; place its exact artifact bytes and SHA-256 in the catalog entry
and import ledger; bind its signer through the independently trusted authority
manifest; and require byte-equal binding artifact read-back at challenge and
operation use time. Actual descriptors, keys, bindings and Identity cutover
remain missing.

**Verdict:** **OPEN P1 / S3 P1-S3-B-01 PARTIAL ONLY**.

### P1-S4-B-02 — the authorization catalog does not encode the complete authorization tuple or catalog-signer delegation

**S4 locations**

- lines 1196–1218 define requester-signed consent;
- lines 1220–1253 define a catalog entry;
- lines 1261–1262 say the entry becomes relevant only under an owner-signed
  catalog linked to the authority manifest;
- lines 1283–1289 permit either the target owner or an “independently
  authorized catalog signer”;
- lines 1299–1300 require every nested artifact and relationship to be
  validated; and
- lines 1322–1336 require atomic import and use-time revalidation.

The prose requires a complete relationship, but the canonical entry does not
encode enough information to prove it. It omits at least:

- `identityDomain`;
- `audience`;
- exact `action` and `capability`;
- `statusKind` for the two status surfaces;
- register `mutationMode`, so enroll/update/reactivate/token-rotation consent
  cannot be distinguished;
- the exact subject-target binding artifact/digest from P1-S4-B-01;
- the authority-manifest artifact/digest and accepted manifest generation; and
- an artifact/digest delegating an alternate catalog signer.

The nested Agreement, Contract, Grant and Conditions fields are opaque signed
artifacts, but S3+S4 do not bind their exact allowed schemas, signer roles,
cross-artifact member equations, generation comparison or revocation relation.
“Verify every ... relationship” at lines 1324–1325 does not tell two
implementations which exact relationship must compare equal. Likewise,
“independently authorized catalog signer” has no typed delegation input and
could become an invented authority path.

The `state` member is also carried inside the imported catalog entry while the
importer separately computes accepted/revoked/expired/condition-unsatisfied
arrays. No equation states whether an attacker-supplied `state=accepted` must
equal, be ignored by, or is superseded by the computed state.

The current accepted set correctly remains empty; no production authority is
fabricated. The future catalog/import contract is nevertheless not
implementation-bounding.

**Impact**

A locally valid signature can be accepted for the wrong audience, domain,
action, status kind or register mutation mode, or under an undeclared catalog
signer. This leaves the exact Agreement/Contract/Grant/Conditions/consent
authority path open.

**Smallest static correction**

Freeze a closed authorization tuple and exact equality equations for every
nested artifact; bind the subject-target artifact, manifest generation and
catalog-signer delegation by exact bytes/digests; distinguish register modes
and status kinds; define computed state precedence; and require the same tuple
at import, challenge and operation use time. Actual signed artifacts and trust
remain missing.

**Verdict:** **OPEN P1 / S3 P1-S3-B-02 PARTIAL ONLY**.

### P1-S4-B-03 — challenge replay is still not total for authenticated errors and expiry

**S4 locations**

- lines 465–479 declare a closed authenticated `errorCode` enum;
- lines 481–490 require admitted authenticated errors to be durably read back;
- lines 715–732 define the closed challenge-state enum;
- lines 782–826 define the closed transition graph;
- lines 832–840 define exact input behavior;
- lines 842–867 define compacted tombstone `terminalKind`; and
- lines 872–874 require exact terminal artifacts to survive compaction.

Two direct contradictions remain:

1. lines 833 and 838 require an authenticated
   `challenge_expired` error, but `challenge_expired` is absent from the closed
   `errorCode` enum at lines 465–479;
2. admitted authenticated errors are exact durable terminal artifacts and the
   admission status matrix permits `targetAdmissionArtifactKind =
   authenticated_error`, but the challenge state machine has only generic
   “response terminal” states and compacted `terminalKind` permits only
   `response`, `indeterminate` or `unavailable`.

An authenticated error is not a `ResponseCore v2` signed response. Treating it
as `response` changes artifact kind and makes exact read-back ambiguous;
omitting it prevents admitted-error compaction and replay. For compacted unused
expiry, “from tombstone facts” also does not say whether the server returns
stored exact error bytes or constructs a new signed error with a new
`serverSequence` and timestamp.

The newly added indeterminate/unavailable states are useful, but they do not
close every terminal artifact branch.

**Impact**

Two conforming servers can disagree on valid error codes, state names,
artifact kinds, sequence consumption and exact replay after restart or
compaction. A caller cannot verify whether an authenticated error is the
original durable terminal result.

**Smallest static correction**

Add the exact expiry code or remove its use; give authenticated errors explicit
terminal/compacted representation and artifact kind; define whether expiry
errors are stored once or deterministically read from an independently durable
ledger; and specify exact bytes, sequence behavior and replay for each branch.
No rerun of an ambiguous target mutation may be authorized.

**Verdict:** **OPEN P1 / S3 P1-S3-B-03 PARTIAL ONLY**.

### P1-S4-B-04 — no unique current subject head exists after repeated deregister and re-enroll cycles

**S4 locations**

- lines 519–633 require `subject_current_deregistered` and correlation
  read-back;
- lines 878–895 replace the undefined S3 current-logical-registration
  component with `subjectRegistrationKey`;
- lines 899–916 define a partial unique index only for `active` and `revoked`
  rows and explicitly exclude deregistered and historical rows;
- lines 935–946 permit enroll whenever no active/revoked row exists and reset a
  new registration to generations `1/0`; and
- lines 948–955 require index/read-back and restart reconciliation.

The key identifies a subject/target family, but no row or pointer uniquely
identifies the current generation when that family has no active/revoked row.
For this legal sequence:

```text
enroll reg-A -> deregister reg-A
enroll reg-B -> deregister reg-B
status(subject_current)
```

both tombstones share the same `subjectRegistrationKey`, neither participates
in the partial unique index, and both can have registration generation `1`.
The contract does not define a monotonically increasing subject-head
generation, a unique current-row flag/pointer, a total order tied to the atomic
transaction, or which tombstone and generations
`subject_current_deregistered` must return.

`serverSequence` is a signed-artifact sequence, not defined as the
registration-family head selector. Commit timestamp is not declared unique and
cannot safely replace a CAS head.

**Impact**

Current status, correlation supersession, old-ID disclosure, new enrollment
CAS and restart read-back can choose different historical rows. This can
publish stale deregistered truth or attach a fresh enrollment to the wrong
generation.

**Smallest static correction**

Define one durable unique subject-registration head keyed by exact
`(compositionVersion, identityDomain, requester, target)`; atomically CAS a
monotonic family generation and current registration/tombstone pointer for
every lifecycle transition; preserve old-ID uniqueness; and add repeated
deregister/re-enroll, concurrent enroll/status and restart/rollback vectors.

**Verdict:** **OPEN P1 / CURRENT-KEY/CAS CONTRACT NOT TOTAL**.

### P1-S4-B-05 — legacy quarantine is fail-closed in prose but has no crash-durable inventory/adjudication state machine

**S4 locations**

- lines 1378–1396 define metadata-only detection and red readiness;
- lines 1400–1410 permit only sealed primitive migration or fail-closed
  deactivation;
- lines 1414–1428 list sanitized inventory fields;
- lines 1433–1441 require terminal disposition/read-back evidence; and
- lines 1860–1861 assign one general token-store path.

The safe default is explicit and is an important improvement. The server
contract still does not define:

- an exact inventory/evidence schema, closed enums and canonical bytes;
- a durable uniqueness key for database, WAL, SHM, rollback journal, free-page
  risk, backup, snapshot, export and restored-copy records;
- state transitions for discovered, quarantined, migrating, deactivated,
  disposal-pending, retained-under-owner-decision and terminal;
- atomic coupling between inventory generation and both DeviceIngress and
  provider-delivery readiness;
- crash windows before/after sealed migration, clean-store recreation,
  deactivation, artifact movement, rollback-anchor advancement and read-back;
- an authoritative finite discovery scope that can make “inventory complete”
  true;
- a typed attestation from the separately reviewed storage-bound primitive; or
- a rule for conflicting concurrent inventory/migration workers.

Without those bounds, one implementation can keep the gate safely red forever,
while another can treat an incomplete in-memory scan or logical SQL change as
complete after restart. The latter violates the stated safety goal, but S4
does not supply the state/evidence contract needed to reject it mechanically.

This finding does not decide retention or disposal. Those remain with Kjetil
under `MBI-PRIVACY-RETENTION-01`.

**Impact**

Legacy plaintext-bearing database sidecars or restored copies can escape the
quarantine generation that originally made readiness red. Static source
conformance cannot prove that delivery stays disabled across crash, restore or
concurrent remediation.

**Smallest static correction**

Define one sanitized crash-durable inventory/adjudication core, exact artifact
classes and state transitions, discovery-root/config ownership, atomic
readiness generation, migration/deactivation attestation interface, restart/
rollback/concurrency rules and negative fixtures. Keep readiness red unless
all enumerated inputs have independently reviewed terminal evidence and the
owner decision permits it.

**Verdict:** **OPEN P1 / S3 P1-S3-B-06 PARTIAL ONLY**.

## 6. P2 findings

### P2-S4-B-01 — Lane B source/test owners are named, but exact configuration and storage-procedure paths are absent

S4 lines 1828–1905 materially improve the Lane B path matrix. Each listed
Cell, service, store, adapter, runbook, test and ledger has a single Lane B
responsibility. The plan still names no exact future path/owner for:

- the typed authority-manifest input configuration;
- the authorization-catalog input configuration;
- the persistent database/store location configuration;
- trusted-time and rollback-anchor providers;
- sealed-token key provider;
- legacy discovery roots and quarantine storage;
- the separately reviewed sealed-migration/deactivation primitive;
- disposal/retention evidence configuration; or
- per-operation readiness output.

S3 config-key names alone do not identify a repository/package/source/config
output path, owner, parser, schema or collision boundary. Folding these into
`DeviceIngressCompositionCoordinator.swift` or
`DeviceIngressTokenStore.swift` would be an unreviewed ownership choice.

**Smallest correction:** add exact config/provider/procedure path, owner and
single-responsibility rows, including development-admin collision/no-touch
classification. Keep all source and owner decisions closed.

**Verdict:** **OPEN P2 / S3 P2-S3-B-01 MOSTLY CLOSED, CONFIG BOUNDARY OPEN**.

### P2-S4-B-02 — the server consumer-ledger schema does not freeze actual fixture-to-test consumption

S4 lines 1998–2115 enumerate producer fixture names, and lines 2117–2160 add a
server ledger path, top-level producer manifest SHA/byte count and per-entry
schema. That closes the missing ledger shape, but not its exact server
consumption mapping:

- “each applicable ledger” and `consumerRequired` do not define which entries
  are applicable to CellScaffold;
- no exact row maps each producer fixture to a named server test method or
  assertion;
- `testPath` is an unconstrained string rather than an allowlisted exact
  server test path/test identifier;
- no role/decision enum or decoded-core-nullability matrix is frozen;
- no exact package-resource versus byte-identical-copy decision is selected;
  and
- no exact hash/shape exists yet for the future producer manifest or server
  consumer ledger.

The last hashes properly remain later evidence, but the static contract must
freeze full expected row coverage before a consumer can prove that it did not
silently omit an inconvenient fixture.

**Smallest correction:** freeze a complete per-producer-entry server
applicability table, exact test path and test identifier, role/decision enums,
decoded-core rule and resource-vs-copy policy. Later MBI-07 must bind actual
producer and consumer hashes.

**Verdict:** **OPEN P2 / S3 P2-S3-B-02 PARTIAL ONLY**.

## 7. Closure ledger for every S3 Lane B finding

| S3 finding | S4 independent verdict | Exact residual |
|---|---|---|
| `P1-S3-B-01` target owner/no-create/response signer | **PARTIAL / OPEN P1** | Typed refs, EMPTY sets and no-create first enrollment are strong, but the signed subject-target artifact/catalog relation is nonconstructible under P1-S4-B-01. |
| `P1-S3-B-02` authority catalog/consent | **PARTIAL / OPEN P1** | Catalog, consent and import ledger cores now exist, but the tuple, nested relations and alternate signer delegation remain incomplete under P1-S4-B-02. |
| `P1-S3-B-03` total challenge machine | **PARTIAL / OPEN P1** | Indeterminate/unavailable states and evidence now exist; expiry and admitted authenticated-error replay/compaction contradict the closed enums under P1-S4-B-03. |
| `P1-S3-B-04` admission oracle/field matrix | **CLOSED AS STATIC CONTRACT** | Absent/wrong-subject/wrong-target admission lookups share `privacy_unknown`; protected fields are null; complete field matrix is closed. Runtime timing/storage evidence remains missing. |
| `P1-S3-B-05` nested maxima | **CLOSED AS STATIC CONTRACT** | The full two-level Base64url nesting is bounded at `120830 -> 161673 -> 216610 -> 291740`, with boundary vectors. Outer framing remains MBI-TRANSPORT-FRAMING-01. |
| `P1-S3-B-06` legacy plaintext quarantine | **PARTIAL / OPEN P1** | Metadata-only detection and fail-closed branches are correct; crash-durable inventory/adjudication and discovery completeness remain P1-S4-B-05. Retention is separate. |
| `P1-S3-B-07` fixed APNS token length | **CLOSED AS STATIC CONTRACT** | Token is opaque `1...4096`; the limit is explicitly HAVEN allocation policy, not an Apple fact; zero/max±1 fixtures are planned. |
| `P2-S3-B-01` Lane B path ownership | **MOSTLY CLOSED / OPEN P2** | All named Cells/services/stores/adapters/tests are assigned, but exact config/provider/procedure paths remain P2-S4-B-01. |
| `P2-S3-B-02` producer fixture consumption | **PARTIAL / OPEN P2** | Ledger path and schema exist; actual applicability and fixture-to-test assertion coverage remain P2-S4-B-02. |

The independent closure result for the seven S3 B P1s is:

```text
CLOSED: 3
PARTIAL / OPEN: 4
```

The current-registration-head P1-S4-B-04 is newly exposed by the S4
replacement and is not double-counted as an inherited S3 finding.

## 8. Preserved S1 and S2 Lane B dispositions

### 8.1 S1

| Prior finding | S4 disposition |
|---|---|
| `P1-B-01` blanket `rw-s` | **CLOSED AS STATIC CONTRACT** — status is `r--s`, mutations are `rw-s`, token rotation is register-only. |
| `P1-B-02` status skips admission | **CLOSED AS STATIC CONTRACT** — durable admission read-back, privacy shape, matrix and satisfiable maxima are now exact. Runtime evidence remains missing. |
| `P1-B-03` Resolver bootstrap | **PARTIAL / OPEN P1** — no-create/EMPTY sets are exact; signed subject-target binding and authorization tuple remain P1-S4-B-01/02. |
| `P1-B-04` challenge digest/bytes | **EXACT BYTES CLOSED / TOTAL MACHINE PARTIAL** — original bytes are retained; error/expiry terminal branches remain P1-S4-B-03. |
| `P2-B-01` token lifecycle/migration | **PARTIAL** — opaque bound and fail-closed quarantine exist; durable legacy adjudication and exact config/fixture ownership remain open. |

### 8.2 S2

| Prior finding | S4 disposition |
|---|---|
| `P1-S2-B-01` pre-boundary inspection | **CLOSED AS STATIC CONTRACT** — transport stays opaque and authority-neutral. |
| `P1-S2-B-02` stale five-operation server | **CORE OPERATION DEFECT CLOSED / SERVER PARTIAL** — six operations are exact; current-head and path evidence findings remain. |
| `P1-S2-B-03` Agreement/Grant provisioning | **PARTIAL / OPEN P1** — catalog structures exist, but P1-S4-B-01/02 prevent exact authority consumption. |
| `P1-S2-B-04` non-total challenge | **PARTIAL / OPEN P1** — typed evidence exists; P1-S4-B-03 prevents total replay. |
| `P1-S2-B-05` token/deregister deletion | **TECHNICALLY IMPROVED / PARTIAL** — current authoritative deletion is exact; legacy adjudication and retention remain open. |
| `P2-S2-B-01` fixture consumption | **PARTIAL / OPEN P2** — server ledger schema exists; complete fixture-to-test consumption remains open. |

## 9. `MBI-04` and B-MBI disposition

### 9.1 S0 `MBI-04`

| Element | Static verdict | Remaining input/evidence |
|---|---|---|
| production issuer | **STRUCTURE PARTIAL** | EMPTY-set/no-create behavior is correct; actual trusted issuer/rotation bytes are missing and subject-target/catalog signer relations remain P1-S4-B-01/02. |
| durable admission/replay | **PARTIAL** | U1...U4, terminal evidence and exact read-back are strong; authenticated-error/expiry replay remains P1-S4-B-03; runtime durability absent. |
| Resolver Cells | **STRUCTURE PARTIAL** | Exact Cells/services are named and no-create is required; constructible binding artifact and config/provider owners remain open. |
| Agreement source/output | **PARTIAL / OPEN P1** | Catalog/import cores exist, but exact authorization tuple and signer delegation remain P1-S4-B-02; actual signed bytes remain missing. |

Overall:

```text
MBI-04 STATIC CONTRACT: PARTIAL / NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
```

S4 addresses MBI-04 only as a document plan. It does not close it.

### 9.2 B-MBI ledger

| B-MBI | Independent S4 disposition |
|---|---|
| `B-MBI-01` authority manifest/issuer rotation | **OPEN AUTHORITY INPUT** — accepted sets remain empty; binding/catalog-signer structural gaps are P1-S4-B-01/02. |
| `B-MBI-02` Agreement/Contract catalog | **PARTIAL / OPEN P1** — canonical containers exist; complete typed relation and actual signed bytes do not. |
| `B-MBI-03` reviewed producer interface | **STATIC PLAN EXISTS / SOURCE AND FIXTURES UNREVIEWED** — no implementation authority follows. |
| `B-MBI-04` rollback anchor/trusted time | **OPEN TECHNICAL AND SECURITY INPUT** — use-time failure is closed, provider/config/runtime evidence is absent. |
| `B-MBI-05` token key/retention/legacy | **PARTIAL / OPEN** — opaque token and sealed-store requirement exist; key provider, durable legacy adjudication and owner retention decision remain open. |
| `B-MBI-06` database/filesystem durability | **OPEN OPERATIONAL EVIDENCE** — no source/runtime SQLite/WAL/SHM/fsync/crash/restore evidence exists. |
| `B-MBI-07` capacity/compaction/retention | **OPEN** — quota pressure fails closed, deletion is disabled, numeric capacity and owner retention remain missing. |
| `B-MBI-08` callback ambiguity | **STATIC CORE IMPROVED** — matrix/maxima/read-back are exact; challenge error replay P1-S4-B-03 and runtime evidence remain. |
| `B-MBI-09` final integration | **OPEN MBI-07** — exact integrated commit/tree/diff/dependency/compiler-input/fixture/evidence manifest is missing. |

No B-MBI is silently delegated to Kjetil. Only
`MBI-PRIVACY-RETENTION-01` has that explicit owner.

## 10. Adversarial server-conformance matrix

| Requirement | Verdict |
|---|---|
| Opaque, byte-preserving, authority-neutral transport | **PASS AS STATIC CONTRACT** |
| First semantic/authority decision at Resolver/Cell boundary | **PASS AS STATIC CONTRACT** |
| Exactly six operations and least privilege | **PASS** |
| Typed requester/target/owner/signer | **PARTIAL / P1-S4-B-01** |
| First enrollment, no-create, EMPTY accepted sets | **SAFE FAIL-CLOSED / ARTIFACT STRUCTURE P1-S4-B-01** |
| No static admission or administrative root | **PASS** |
| Signed Agreement/Contract/Grant/Conditions/consent | **PARTIAL / P1-S4-B-02** |
| Import ledger, use-time checks, rollback reaction | **PARTIAL / ACTUAL AUTHORITY MISSING / P1-S4-B-02** |
| Challenge U1...U4 and collision order | **PASS AS STATIC CONTRACT** |
| Total challenge states and terminal evidence | **PARTIAL / P1-S4-B-03** |
| Replay/restart/compaction | **PARTIAL / P1-S4-B-03; RUNTIME MISSING** |
| Oracle-safe admission status | **PASS AS STATIC CONTRACT** |
| Closed registration/correlation/admission status matrix | **PASS EXCEPT CURRENT-HEAD P1-S4-B-04** |
| Current registration uniqueness/CAS | **NO-GO / P1-S4-B-04** |
| Nested maxima are satisfiable | **PASS AS STATIC CONTRACT** |
| Variable opaque APNS token bound | **PASS AS STATIC CONTRACT** |
| Legacy DB/WAL/SHM/journal/backup/snapshot/export quarantine | **SAFE DEFAULT PASS / DURABLE ADJUDICATION P1-S4-B-05** |
| Revoke semantics | **PASS AS STATIC CORE / RUNTIME AND RETENTION MISSING** |
| Deregister authoritative deletion/tombstone | **PASS AS STATIC CORE / RETENTION NO-GO** |
| Exact Cell/service/store path ownership | **MOSTLY PASS / CONFIG P2-S4-B-01** |
| Producer/consumer fixture evidence | **PARTIAL / P2-S4-B-02** |
| Identity cutover | **SEPARATE / NO-GO** |
| Production signing/profile/entitlement | **MBI-06 UNAUDITED / MISSING** |
| Integrated exact output | **MBI-07 MISSING** |

## 11. Privacy, Identity, framing and production gates

### 11.1 `MBI-PRIVACY-RETENTION-01`

This review does not decide, narrow by guess or delegate:

- legitimate purpose for tombstone retention;
- exact duration and same-subject disclosure duration;
- compaction/deletion behavior;
- backup/restore exposure and destruction;
- revoke-retained sealed ciphertext permission/duration; or
- truthful user-facing wording.

Exact owner remains:

```text
Kjetil
```

Mandatory gate:

```text
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE COMPACTION/DELETION: DISABLED
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

### 11.2 Identity and authority

Identity cutover remains separate. Actual requester, issuer, owner, signer,
Agreement, Contract, Grant, Conditions, consent, revocation, rotation, trusted
time, rollback-anchor and vault-continuity evidence remains missing.

Therefore:

```text
accepted requester descriptors = EMPTY
accepted target cells           = EMPTY
accepted target owners          = EMPTY
accepted response signers       = EMPTY
accepted authorization entries  = EMPTY
affected readiness              = UNAVAILABLE
```

### 11.3 Framing and trust

`MBI-TRANSPORT-FRAMING-01` remains missing:

- HTTPS method/path;
- carrier/media bytes and outer field order;
- exact framing overhead and total outer maximum;
- HTTP status/error mapping;
- proxy/effective-authority rule; and
- deterministic framing fixtures.

Transport remains opaque and cannot grant authority.

### 11.4 Apple and integrated evidence

```text
MBI-06:
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING

MBI-07:
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/fixture/evidence/artifact manifest
= MISSING
```

No production entitlement, APNS provider acceptance, device delivery or
callback is inferred from the bundle/topic/origin literals.

### 11.5 Unchanged action gates

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

## 12. Exact smallest successor scopes

No successor is authorized by this review. If development-admin later opens
new document-only work, the smallest non-overlapping Lane B scopes are:

1. **Binding/authority artifact correction:** exact four-ref signed
   `SubjectTargetBindingArtifact`, catalog/manifest digest relation and
   first-enrollment read-back.
2. **Authorization tuple correction:** exact Agreement/Contract/Grant/
   Conditions/consent schemas and equality equations, register mode/status kind
   scoping, catalog-signer delegation and computed-state precedence.
3. **Challenge terminal correction:** exact expiry error, authenticated-error
   states/kinds/ledger, replay, sequence and compaction.
4. **Current registration-head correction:** durable unique family head,
   monotonic generation, CAS and repeated deregister/re-enroll vectors.
5. **Legacy adjudication correction:** exact sanitized durable inventory,
   discovery boundary, readiness generation, migration/deactivation
   attestation and restart/rollback/concurrency states.
6. **Lane B path/fixture correction:** exact config/provider/procedure paths
   and full producer-entry-to-server-test consumption table.
7. **New independent exact-byte Lane B review:** by a reviewer distinct from
   every correction author.

These scopes grant no source, Identity, framing, Apple, APNS, integration or
production authority.

## 13. Mechanical finding-count reconciliation

The authoritative finding headings in this artifact are:

```text
P0 headings: 0
P1 headings: 5
P2 headings: 2
```

The executive verdict and final decision both use:

```text
P0/P1/P2 = 0/5/2
```

Narrative references to immutable S1/S2/S3 finding IDs are closure-ledger
references, not new finding headings and are not double-counted.

## 14. Final independent decision

```text
REVIEWED PATH:
Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md

REVIEWED SHA-256:
99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa

REVIEWED SHAPE:
2377 LINES / 79288 BYTES

P0: 0
P1: 5
P2: 2
P0/P1/P2: 0/5/2

LANE B CELLSCAFFOLD SERVER CONFORMANCE: NO-GO
S4 STATIC CORRECTION: NO-GO
S3 B FINDINGS: PARTIAL CLOSURE
MBI-04 STATIC CONTRACT: PARTIAL / NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
MBI-PRIVACY-RETENTION-01: OPEN / KJETIL
MBI-TRANSPORT-FRAMING-01: MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING

PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

This review stops after freezing and re-attesting this one artifact. It
authorizes no source, Git, build, test, network, portal, signing, archive,
device, APNS, secret, Identity, staging, deployment, integration, next-phase or
production action.
