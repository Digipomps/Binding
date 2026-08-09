# APNS S3 Normative Composition Contract — CellScaffold Server Conformance Independent Review

Status: **REVIEW-FROZEN / LANE B CONFORMANCE NO-GO / S3 NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Review timestamp: `2026-07-25T00:38:02+02:00`  
Review role: independent CellScaffold Lane B conformance reviewer, distinct from
the S3 author  
Review scope: exact-byte static server-conformance review only  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md`

This review does not amend the S3 contract or any S0/S1/S2 artifact. It grants
no authority for source edits, Git mutation, dependency resolution, build,
test, network, portal, signing, archive, device action, APNS contact, secret
access, Identity action, staging, deployment, integration, or a next material
phase.

The review path was re-attested absent immediately before this artifact was
created. This reviewer did not author the S3 normative contract. No author
self-review receives credit.

## 1. Exact target and 16-artifact lineage

### 1.1 Reviewed S3 bytes

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 |

The review covers exactly those bytes.

### 1.2 Exact S0 chain

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

S0 remains immutable:

```text
P0/P1/P2 = 0/2/1
PLAN = NO-GO
NEXT PHASE = NO-GO
```

### 1.3 Exact S1 chain

| Lane | Artifact | SHA-256 | Lines | Bytes | Review state |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | author packet |
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md` | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | `0/5/2`, NO-GO |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | author packet |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md` | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | `0/4/1`, NO-GO |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | author packet |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md` | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | `0/3/4`, NO-GO |

### 1.4 Exact S2 chain

| Lane | Artifact | SHA-256 | Lines | Bytes | Review state |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_2026-07-24.md` | `1b750373b4cb98c71983b002b6a2ce1fd809086776bd64b92d3b27e386969854` | 1746 | 69053 | author packet |
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `0f2e813f481dcc9fade979a38dbf6e2a3814d743411dfec0fe63def525ed687a` | 759 | 32502 | `0/4/2`, NO-GO |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_2026-07-24.md` | `cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4` | 1127 | 52292 | author packet |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `f12db49ca272fcbbe5d577c401c21c64b6d6156d9633e0e49fded9796a9fc1ad` | 1400 | 57603 | `0/5/1`, NO-GO |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_2026-07-24.md` | `6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56` | 1112 | 52295 | author packet |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `9a80ac8fb42103e27cfe8c3efe5681479e8c4458f2144ebb0d42c3726f6bd365` | 601 | 32361 | `0/4/0`, NO-GO |

All 16 lineage objects were reproduced from local exact bytes. No prior packet
is promoted to canonical implementation evidence.

## 2. Review method and severity boundary

The reviewer:

1. read all 2403 S3 lines;
2. reproduced the complete S1 Lane B review and all four P1 plus one P2;
3. reproduced the complete S2 Lane B review and all five P1 plus one P2;
4. traced the S3 transport input to the first inner decode;
5. traced subject, Resolver target, target owner, Agreement, Contract, Grant,
   condition, generation, admission, target transaction, response signer, and
   replay path;
6. checked all six operations and exact `rw-s`/`r--s` values;
7. checked challenge issuance, pending expiry, restart, terminal state, and
   compaction;
8. checked admission/registration identifiers, collision, CAS, status,
   read-back, privacy, and byte maxima;
9. checked revoke, deregister, token deletion, tombstone acyclicity, legacy
   plaintext, WAL/free-page/backup boundaries, and retention separation;
10. checked producer fixture ownership and server-consumer evidence paths; and
11. preserved Identity, Apple, APNS, integrated-output, and production gates.

Severity:

- **P0** means the document itself opens or performs a critical unsafe action;
- **P1** means the normative server contract is contradictory, unsafe, or not
  implementation-bounding;
- **P2** means exact path, fixture, test, or audit ownership remains incomplete
  without independently granting authority.

No build or test was run or claimed. No raw token, private key, secret, or
protected payload was read.

## 3. Executive verdict

```text
P0: 0
P1: 7
P2: 2

LANE B SERVER CONFORMANCE: NO-GO
S3 NORMATIVE CONTRACT: NO-GO
MBI-04: PARTIAL / OPEN
MBI-PRIVACY-RETENTION-01: OWNER DECISION MISSING / NOT SOLVED HERE
MBI-TRANSPORT-FRAMING-01: TECHNICAL INPUT MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

There is no P0 because every material action remains explicitly closed. The
contract materially improves cross-lane composition, but seven P1 server
contracts and two P2 evidence/path contracts remain.

## 4. Supported server-conformance invariants

The following S3 claims survive this exact-byte review as static requirements:

- lines 1734–1763 make transport opaque and byte-preserving; it cannot decode
  CJP-1, inspect an operation/schema/subject/token/selector/Agreement/Contract/
  Grant/ID/result, resolve a Cell, re-encode bytes, construct inner errors, or
  mutate state;
- lines 462–505 define exactly six wire operations, with registration and
  admission status as submodes rather than extra operations;
- status is exactly `r--s`; register/resolve/submit/revoke/deregister are
  exactly `rw-s`; token rotation is only register mutation mode;
- lines 407–460 provide an acyclic body → intent → challenge → request →
  response construction order;
- lines 614–676 provide a versioned, length-framed `adm1_` namespace, exact
  collision behavior, and no authority from identifier possession;
- lines 926–1009 provide a target-issued `reg1_` namespace, subject privacy,
  uniqueness, generation CAS, and exact mutation correlation;
- lines 1538–1551 reject static/environment/admin/route/ID/topic/test-key
  admission roots;
- lines 1603–1620 require complete challenge-time and use-time Identity,
  Resolver, owner, Agreement, Contract/Grant, capability, access, condition,
  validity, generation, and time verification;
- lines 1622–1640 require the same selected target instance for authority and
  execution and reject fake cross-Cell atomicity;
- lines 1644–1656 distinguish revoke from deregistration and remove revoked
  registrations from active delivery;
- lines 1658–1682 make deregistration terminal, require endpoint and
  active/recoverable token deletion before success, create an acyclic minimal
  signed tombstone, and reject broad privacy-erasure wording;
- lines 1684–1692 provide replay/idempotency and old-ID non-resurrection rules;
- lines 1694–1730 preserve the retention decision as
  `MBI-PRIVACY-RETENTION-01` owned only by Kjetil and keep production
  deregistration unavailable;
- lines 1800–1821 leave trust/authority bytes missing and fail closed; and
- lines 2322–2363 preserve all action and production-evidence NO-GOs.

These are planning-level supports only. They are not source/runtime evidence
and do not offset the findings below.

## 5. P1 findings

### P1-S3-B-01 — `DeviceRegistration` owner, no-create bootstrap, and response
signer do not form one constructible authority path

**S3 locations**

- lines 1043–1044 require the signed response signer to be the verified current
  target owner;
- lines 1553–1560 define `cell:///DeviceRegistration` as `.identityUnique`,
  persistent, with a “Resolver-selected authenticated device subject/owner
  tuple”;
- lines 1562–1570 then forbid `makeNewIfNotFound=true`, require every Cell and
  owner to exist, and permit registration only of a concrete recovered
  instance;
- lines 1583–1601 recover global target definitions during bootstrap, not an
  exact per-subject first-enrollment instance; and
- lines 1804–1814 list target UUID/owner descriptors as later authority inputs
  without fixing the structural subject/owner/signing relation.

The contract does not choose one safe constructible model:

1. if the authenticated device subject is also the target owner, CellScaffold
   does not possess that device's private signing key and cannot sign the
   target-owner response;
2. if a pre-existing server Identity owns the target, the table's device
   subject/owner tuple is not exact and the subject-to-target binding must be
   separately specified;
3. if an `.identityUnique` target instance is created for first enrollment, the
   blanket no-create rule is violated; or
4. if every identity-unique target must pre-exist, no exact authority-owned
   provisioning/import path is defined for a previously unseen device subject.

The missing production descriptors may remain an Identity MBI, but their
structural roles cannot remain ambiguous in a normative server contract.

**Impact**

The server cannot prove which key signs challenge/response bytes, which
concrete Cell owns registration state, or how a first enrollment reaches an
existing no-create target without either importing a private device key or
inventing an owner.

**Smallest correction**

Freeze separately:

- authenticated requester subject descriptor;
- target Cell instance key and scope selector;
- target owner/server signer descriptor and no-create vault lookup;
- subject-to-target relation and its signed authority source;
- first-enrollment target provisioning/import, or a pre-existing shared target
  model;
- exact Resolver registration/read-back assertions; and
- response/tombstone signer equality.

Actual descriptors and trust roots remain missing authority inputs. No owner is
created by the correction.

**Verdict:** **OPEN P1 / SERVER AUTHORITY BOOTSTRAP NONCONSTRUCTIBLE**.

### P1-S3-B-02 — Agreement/Contract/Grant catalog provisioning and consent
evidence are not exact

**S3 locations**

- lines 748 and 969 require a `consentArtifactSHA256` and a consent comparison,
  but define no consent artifact schema, signer, exact bytes, lookup source,
  status, lifetime, revocation, or read-back rule;
- lines 1572–1581 name
  `DEVICE_INGRESS_AGREEMENT_CATALOG_PATH` and require a signed canonical
  artifact without defining that catalog's schema or signature/entry manifest;
- line 1591 says import/verify/read-back Agreement/Contract/Grant catalog but
  defines no durable accepted/revoked/expired output ledger or atomic import
  record;
- lines 1603–1620 correctly require use-time verification; and
- lines 1804–1816 correctly leave actual authority bytes missing.

Use-time checks do not make provisioning implementation-bounding. A server
cannot determine:

- which canonical catalog bytes are signed;
- whether the catalog signer is authorized to bind the target owner;
- whether every Agreement, Contract, Grant, condition and generation is
  complete;
- which exact bytes/generations were imported and read back;
- how restart/rollback revalidates them;
- how an arbitrary digest is prevented from becoming “active consent”; or
- how consent withdrawal/replacement relates to reactivation and registration
  status.

An Agreement remains necessary but insufficient. A digest in a requester-signed
body is not owner-issued consent authority by itself.

**Impact**

`active_consented` and challenge authorization can be implemented from
attacker-selected or stale bytes even while every individual cryptographic
check appears locally valid. This is the unresolved core of S1 `P1-B-03` and
S2 `P1-S2-B-03`.

**Smallest correction**

Define a producer-owned catalog/import contract with:

- exact catalog core/schema/member order and signed-artifact kind;
- entry hashes for complete Agreement, Contract, Grant, conditions, target,
  owner, subject, domain, purpose, audience, operation, access, validity and
  revocation;
- exact consent artifact type and its relationship to the Agreement/Contract;
- durable import/admission ledger schema and output path;
- accepted/revoked/expired/condition-unsatisfied state;
- atomic import and exact read-back;
- rollback/restart behavior; and
- negative fixtures for incomplete, substituted, stale and arbitrary consent
  digests.

Actual owner-signed bytes and trust remain unavailable authority inputs.

**Verdict:** **OPEN P1 / MBI-04 CATALOG PATH NOT CLOSED**.

### P1-S3-B-03 — the claimed total challenge machine has no typed
indeterminate/unavailable terminal state

**S3 locations**

- lines 1418–1429 define eight persisted states;
- lines 1434–1461 say no transition outside the listed graph is permitted;
- lines 1494–1506 require expired pending admission to commit either a terminal
  response or “typed indeterminate/unavailable terminal evidence”;
- lines 1508–1517 require corruption/missing evidence to make an operation
  unavailable and forbid response reconstruction/re-signing; and
- lines 1519–1534 require an exact terminal response before admitted
  compaction.

There is no:

- persisted `admitted_*_indeterminate` or `admitted_*_unavailable` state;
- result/error core for the promised terminal evidence;
- transition from either pending state to such evidence;
- replay rule for it;
- rule deciding whether the challenge remains permanently pending; or
- compaction rule for an admission that can never obtain an exact response.

Leaving the record pending and readiness red is safe, but it contradicts the
normative command to commit typed terminal evidence and the claim that the
machine is total. Mapping that evidence to
`admitted_expired_terminal` is also invalid because that state means an exact
terminal response is durable.

**Impact**

Crash/restart reconciliation after admission but before a readable target
response remains implementation-dependent. A future server can invent a
terminal error, retry target mutation, reconstruct a response, or strand state
without a canonical replay result.

**Smallest correction**

Either:

- define explicit active/expired indeterminate terminal states, canonical
  evidence cores, transitions, replay/read-back and non-compaction behavior; or
- normatively keep unresolved records pending forever with operation
  unavailable, remove the terminal-evidence claim, and define recovery once
  target idempotency evidence becomes readable.

No mutation may rerun when a durable target commit exists. No exact response
may be reconstructed or re-signed.

**Verdict:** **OPEN P1 / S2 `P1-S2-B-04` PARTIAL**.

### P1-S3-B-04 — admission read-back can distinguish wrong-subject existence
and has no closed conditional-field schema

**S3 locations**

- lines 1235–1253 list 15 status-result fields and say nullable fields are
  present as `null`;
- lines 1260–1274 define status codes;
- lines 1276–1289 say `privacy_unknown` must not distinguish wrong subject from
  absence;
- lines 1301–1307 constrain only correlation disposition;
- lines 1311–1323 allow wrong-subject and absent admission lookup to return
  either `privacy_unknown` or `admission_not_found` “according to whether
  non-disclosure can be proven without an oracle.”

If a guessed absent ID returns `admission_not_found` while an existing
other-subject ID returns `privacy_unknown`, the status itself is an existence
oracle. The contract gives no proof field in `StatusBodyCore` that permits an
authenticated requester to establish ownership of an absent admission before
the server lookup. The phrase “according to” is not a deterministic privacy
rule.

The result schema also lacks an exact statusCode-to-field matrix. It does not
normatively require:

- registration IDs/generations/record digests for active or revoked status;
- tombstone digest only for permitted deregistered disclosure;
- correlation digest/disposition only when correlation was requested;
- exact nested response and digest only for
  `admission_response_available`; or
- all sensitive registration/admission fields to be null for
  `privacy_unknown`, `subject_current_unknown`, and other negative states.

**Impact**

Two conforming decoders can expose different information for the same
wrong-subject lookup. A syntactically canonical `privacy_unknown` response can
also carry an ID/digest that leaks the protected record because no closed
conditional schema rejects it.

**Smallest correction**

Freeze one outward admission-negative rule, for example:

```text
unproved admission ownership, wrong subject, or absent opaque ID
  => privacy_unknown with every protected field null
```

If `admission_not_found` is retained, require a non-oracular subject-bound
proof available before lookup and define its exact bytes. Add a complete
statusCode/selector/correlation/subjectState/nullability matrix and positive
and substitution fixtures.

**Verdict:** **OPEN P1 / STATUS PRIVACY TAXONOMY NOT CLOSED**.

### P1-S3-B-05 — admission read-back maxima are mathematically
nonconstructible for a legal normal response

**S3 locations**

- line 1041 Base64url-encodes every ResultCore inside ResponseCore;
- lines 1046–1049 permit a normal signed response artifact up to 262144 bytes,
  admission-readback ResponseCore up to 393216 bytes, and signed read-back
  artifact up to 524288 bytes;
- lines 1249–1250 place the exact original signed response plus its digest
  inside StatusResultCore;
- lines 1319–1321 require those exact nested bytes for
  `admission_response_available`; and
- lines 1823–1859 repeat the same maxima and forbid truncation.

For an allowed 262144-byte original signed response:

```text
Base64url(262144 bytes) = 349526 ASCII bytes
```

Therefore StatusResultCore is already greater than 349526 bytes before its
other 14 members. ResponseCore then Base64url-encodes that complete
StatusResultCore:

```text
Base64url(>349526 bytes) > 466034 ASCII bytes
```

That already exceeds the 393216-byte admission-readback ResponseCore maximum
before ResponseCore's other fields. Wrapping ResponseCore in SignedArtifact
again exceeds the 524288-byte signed-artifact maximum. The 65536-byte “normal
result core” maximum is also incompatible with any large nested response.

**Impact**

The exact admission read-back required for ambiguous resolve/submit cannot
return every response the same contract permits the server to persist. A legal
operation can become permanently unrecoverable solely because of the
normative size table.

**Smallest correction**

Derive every maximum from the complete nesting equation, including all CJP-1
overhead and both Base64url expansions, then either:

- lower each original operation response maximum so its exact read-back fits;
- raise every enclosing result/response/artifact/transport bound consistently;
  or
- define a different reviewed exact-byte retrieval artifact that avoids nested
  repeated encoding without weakening signature or authority checks.

Add boundary vectors at maximum minus one, exact maximum, and maximum plus one.

**Verdict:** **OPEN P1 / ADMISSION READ-BACK NOT CONSTRUCTIBLE**.

### P1-S3-B-06 — legacy plaintext-token quarantine and disposal are absent

**S3 locations**

- line 1594 recovers a token store but gives no legacy-schema detection rule;
- lines 1658–1680 define per-registration deregistration deletion and correctly
  acknowledge that SQLite/WAL/free-page/backup copies remain sensitive;
- `MBI-PRIVACY-RETENTION-01` lines 1694–1730 covers future tombstone,
  backup/restore, and revoke-ciphertext retention choices;
- lines 2171–2183 request later SQLite/WAL/backup evidence; and
- line 2264 claims S2 `P1-S2-B-05` technically closed.

The contract never specifies what startup does when the existing CellScaffold
database or a restored backup still contains the legacy plaintext
`pushToken` representation identified by the S1/S2 B reviews. It lacks:

- schema/column/artifact detection without reading or logging token content;
- immediate readiness quarantine;
- prohibition on legacy rows entering active delivery;
- sanitized inventory of database/WAL/free pages/backups/snapshots;
- deactivate/re-enroll versus clean-database-copy migration rule;
- migration crash/restart states;
- disposal/rotation/recreation owner and evidence; and
- a rule preventing a restored legacy backup from silently reactivating.

This is not a request to decide
`MBI-PRIVACY-RETENTION-01`. The safe technical invariant is fail-closed
quarantine until the separately reviewed storage procedure exists.

**Impact**

A server implementation can conform to the new sealed-token and deregister
paths while booting an old plaintext token row or retained backup into the
active runtime. The prior privacy finding is therefore not technically closed.

**Smallest correction**

Define a legacy-detection/quarantine state machine that:

- detects legacy representation by sanitized metadata only;
- marks every DeviceIngress/provider/delivery readiness gate red;
- never logs, exports, hashes for telemetry, or activates the raw token;
- requires re-enrollment or a reviewed clean-store recreation;
- is crash/restart/restore safe; and
- records only sanitized disposal evidence.

Physical disposal and backup retention remain under their proper privacy/
storage owners; this review does not select them.

**Verdict:** **OPEN P1 / LEGACY TOKEN READINESS UNSAFE**.

### P1-S3-B-07 — RegisterBodyCore hard-codes an unbound 32-byte APNS-token
contract

**S3 locations**

- lines 764–771 require exactly 32 raw token bytes for all four register modes;
- line 785 repeats that exact length;
- line 1926 assigns exact core/fixture ownership to Lane A; and
- lines 2334–2338 keep Apple/APNS production evidence unaudited/missing.

None of the 16 bound artifacts supplies an authoritative Apple/API input that
permits this normative server contract to treat the APNS token as a fixed
32-byte value. An APNS token is an opaque provider input; one observed device
token length is not a future wire invariant. The contract may bound size before
allocation, but it cannot derive “exactly 32” from the current lineage while
`MBI-06` and device/provider evidence remain missing.

**Impact**

A valid future or platform-specific opaque token whose length differs is
rejected before authenticated registration, making end-to-end acceptance
impossible despite otherwise correct signing, consent, and authority.

**Smallest correction**

The producer owner must bind an authoritative platform/API rule and freeze a
bounded opaque-token length contract plus positive/minus-one/plus-one vectors.
Until that input is available, the server must fail closed without claiming
that 32 bytes is universally canonical. No token bytes may enter docs or
fixtures.

**Verdict:** **OPEN P1 / REGISTER INPUT CONTRACT UNBOUND**.

## 6. P2 findings

### P2-S3-B-01 — the future Lane B path plan does not assign every required
Cell/service/store to an exact implementation owner

Section 20 normatively requires authority catalog, challenge issuer,
registration, callback, challenge/admission/response, status, revoke, and
deregister behavior. Lines 2006–2027 propose Lane B paths, but omit explicit
paths/responsibility rows for at least:

- `DeviceIngressAuthorityCatalogCell`;
- `DeviceIngressChallengeIssuerCell`;
- revoke service;
- exact response store/read-back service;
- admission-status versus registration-status service ownership; and
- target-Cell adapter/service ownership for register/resolve/submit.

The listed `ChallengeStateMachine`, `AdmissionStore`, `StatusService`, and
`CompositionCoordinator` could absorb those responsibilities, but the packet
does not say so. The path block also does not map every file to one owner and
one semantic responsibility.

This is a path/owner audit defect, not an independent authority grant.

**Smallest correction:** add a path-to-responsibility/owner matrix covering
every named Cell, service, store, adapter, test, and development-admin
collision. Preserve the source gate.

**Verdict:** **OPEN P2 / LANE B PATH PACKET PARTIAL**.

### P2-S3-B-02 — producer fixture consumption lacks an exact server-side
manifest-hash ledger

Lines 2047–2154 define one producer manifest path/schema/inventory and forbid
consumer regeneration. Lines 2019 and 2171–2183 name one broad server consumer
test and evidence topics. They do not define:

- whether CellScaffold references package resources or copies exact bytes;
- the exact reviewed producer manifest SHA-256 input;
- the server-consumer ledger/artifact path that records it;
- per-entry server-consumption coverage;
- failure on manifest-hash drift;
- proof that no consumer-local signed fixture was regenerated; or
- the exact output later included in MBI-07.

This substantially improves S2 `P2-S2-B-01`, but does not close exact server
consumption.

**Smallest correction:** freeze one server consumer ledger/test artifact and
assert manifest SHA, byte count, file SHA, decoded/core SHA, schema, role,
decision, test-key rejection, sorted order, and full operation/error coverage.

**Verdict:** **OPEN P2 / FIXTURE CONSUMER EVIDENCE PARTIAL**.

## 7. S1 Lane B finding disposition

| Prior finding | S3 server-conformance verdict | Exact residual |
|---|---|---|
| `P1-B-01` blanket `rw-s` | **CLOSED AS STATIC CONTRACT** | Exact operation table has status `r--s`, every mutation `rw-s`, exact Grant equality, and no token-rotation operation. Runtime evidence remains missing. |
| `P1-B-02` status skips durable admission | **NARROW DEFECT CLOSED / STATUS CONTRACT PARTIAL** | Status has durable admission/read-back/replay, but admission privacy/field mapping and nested maxima remain P1-S3-B-04/05. |
| `P1-B-03` Resolver bootstrap incomplete | **PARTIAL / OPEN P1** | Infrastructure tuple/order/no-create improved; target owner/first enrollment/signing and exact Agreement/Contract/consent catalog remain P1-S3-B-01/02. |
| `P1-B-04` challenge digest/bytes contradiction | **EXACT-BYTE DEFECT CLOSED / TOTAL MACHINE PARTIAL** | Exact intent/challenge bytes are retained and replayed without re-signing; unavailable/indeterminate terminal state is missing under P1-S3-B-03. |
| `P2-B-01` token lifecycle/migration tests | **PARTIAL** | Sealed-token, deregister and evidence tests are planned; legacy plaintext lifecycle and exact Lane B path/fixture ownership remain P1-S3-B-06 and P2-S3-B-01/02. |

## 8. S2 Lane B finding disposition

| Prior finding | S3 server-conformance verdict | Exact residual |
|---|---|---|
| `P1-S2-B-01` pre-boundary inspection | **CLOSED AS STATIC CONTRACT** | Transport is opaque; first CJP-1/operation decode is at the authenticated CellProtocol boundary. HTTP framing remains a separate MBI. |
| `P1-S2-B-02` stale v3/five-operation server | **CORE OPERATION DEFECT CLOSED / SERVER CONFORMANCE PARTIAL** | Six operations, status submodes, CAS, correlation, revoke and deregister are normative. Status read-back P1s and service-path P2 remain. |
| `P1-S2-B-03` Agreement/Grant provisioning | **PARTIAL / OPEN P1** | Complete challenge/use-time checks are exact; provisioning catalog, consent artifact and target-owner bootstrap remain P1-S3-B-01/02. |
| `P1-S2-B-04` non-total challenge | **PARTIAL / OPEN P1** | Pending-expiry state exists, but typed unavailable/indeterminate terminal evidence has no state/schema/transition. |
| `P1-S2-B-05` token/deregister deletion | **DEREGISTER TRANSACTION TECHNICALLY IMPROVED / PARTIAL** | Authoritative endpoint/recoverable-token deletion and minimal tombstone are correct; legacy plaintext quarantine is missing and retention remains owner-open. |
| `P2-S2-B-01` fixture consumption | **PARTIAL / OPEN P2** | Producer path/schema/groups exist, but exact server manifest-hash ledger and consumption mapping do not. |

## 9. `MBI-04` and B-MBI disposition

### 9.1 S0 `MBI-04`

| Element | Static verdict | Remaining evidence/input |
|---|---|---|
| production issuer | **STRUCTURE PARTIAL** | actual trusted issuer/rotation/owner bytes missing; target owner path P1-S3-B-01 |
| durable admission/replay | **PARTIAL** | core IDs/CAS/replay are strong; pending terminal and admission read-back P1s remain; runtime durability missing |
| Resolver Cells | **PARTIAL** | infrastructure tuples/no-create/read-back exist; first-enrollment target ownership and exact service path matrix remain |
| Agreement source/output | **OPEN P1** | catalog/consent schema, signed import/output ledger and restart/rollback contract missing |

Overall:

```text
MBI-04 STATIC CONTRACT: PARTIAL / NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
```

### 9.2 B-MBI ledger

| B-MBI | Independent S3 disposition |
|---|---|
| `B-MBI-01` signed authority manifest and issuer rotation | **OPEN AUTHORITY INPUT** — no trust root/descriptor/rotation bytes are invented; target ownership structure also needs P1-S3-B-01 correction |
| `B-MBI-02` signed Agreement/Contract catalog | **OPEN P1** — config key and use-time checks exist, but exact catalog/consent/import-output contract is missing |
| `B-MBI-03` reviewed producer interface | **S3 SHARED AUTHOR CONTRACT EXISTS / SOURCE BYTES AND LANE CONFORMANCE STILL UNREVIEWED** — this server review does not generate or approve producer source/fixtures |
| `B-MBI-04` rollback anchor and trusted time | **OPEN TECHNICAL/SECURITY INPUT** — external anchor and runtime evidence missing; no network-time trust root is invented |
| `B-MBI-05` token key provider, retention, legacy disposal | **PARTIAL/OPEN** — key provider/AEAD/runtime proof missing; retention is Kjetil's separate MBI; legacy quarantine is P1-S3-B-06 |
| `B-MBI-06` database/filesystem durability | **OPEN OPERATIONAL EVIDENCE** — SQLite/WAL/SHM/fsync/crash/restart/restore evidence missing |
| `B-MBI-07` capacity, compaction and retention | **OPEN** — pressure fails closed and tombstone compaction is disabled; numeric capacity/restore and Kjetil retention decision remain missing |
| `B-MBI-08` callback submit ambiguity | **PARTIAL/OPEN** — generic admission read-back is proposed, but privacy/conditional fields and byte maxima are P1-S3-B-04/05 |
| `B-MBI-09` final integration output | **OPEN `MBI-07`** — exact final commit/tree/diff/dependency/compiler-input/fixture/evidence manifest missing |

No B-MBI is delegated to Kjetil except the explicitly scoped
`MBI-PRIVACY-RETENTION-01`.

## 10. Server-conformance matrix

| Requirement | Verdict |
|---|---|
| Opaque, byte-preserving transport | **PASS AS STATIC CONTRACT** |
| No operation decode before authenticated Resolver/Cell boundary | **PASS AS STATIC CONTRACT** |
| Exactly six operations | **PASS** |
| Per-operation least privilege | **PASS** |
| Exact canonical byte consumption | **PASS IN CORE / RUNTIME AND FRAMING MISSING** |
| Issuer/challenge/admission/replay services | **PARTIAL / P1-S3-B-03, P2-S3-B-01** |
| Status registration/correlation/admission service | **NO-GO / P1-S3-B-04/05** |
| Revoke service | **SEMANTICS PASS / EXACT PATH OWNER P2** |
| Deregister service | **CORE TRANSACTION PASS / LEGACY AND RETENTION NO-GO** |
| Agreement/Contract/Grant provisioning | **NO-GO / P1-S3-B-02** |
| Challenge- and use-time authorization | **PASS AS REQUIREMENT / AUTHORITY BYTES MISSING** |
| No static admission root | **PASS AS REQUIREMENT** |
| Resolver Cell registration/bootstrap ownership | **NO-GO / P1-S3-B-01** |
| Total challenge expiry/replay/restart/compaction | **NO-GO / P1-S3-B-03** |
| Durable admission/read-back | **PARTIAL / STATUS PRIVACY AND SIZE P1s** |
| Admission namespace/collision | **PASS AS STATIC CONTRACT** |
| Registration namespace/CAS | **PASS EXCEPT TARGET/CONSENT AUTHORITY P1s** |
| Status taxonomy | **NEGATIVE NAMES PASS / CONDITIONAL-PRIVACY CONTRACT NO-GO** |
| Authoritative deregister commit before success | **PASS AS STATIC CORE** |
| Raw-token/active-binding deletion | **PASS FOR CURRENT AUTHORITATIVE ROW / LEGACY ARTIFACT NO-GO** |
| Minimal signed replay tombstone | **PASS TECHNICALLY / RETENTION OWNER DECISION OPEN** |
| Legacy plaintext handling | **FAIL / P1-S3-B-06** |
| Producer fixture consumption | **PARTIAL / P2-S3-B-02** |
| APNS token wire acceptance | **NO-GO / P1-S3-B-07** |

## 11. `MBI-PRIVACY-RETENTION-01`

This review does not solve, narrow by guess, or substitute for
`MBI-PRIVACY-RETENTION-01`.

Exact owner:

`Kjetil`

Still required:

- legitimate purpose for tombstone retention;
- exact duration;
- authenticated-subject disclosure duration;
- compaction/deletion after duration;
- backup/restore exposure and destruction;
- revoke-retained sealed ciphertext permission/duration; and
- truthful user-facing wording.

Mandatory unchanged gate:

```text
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE COMPACTION: DISABLED
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

The missing decision does not authorize the server to retain more data, claim
privacy erasure, expose tombstones, or start a production deregister route.

## 12. Other missing inputs and preserved gates

### `MBI-TRANSPORT-FRAMING-01`

**OPEN / TECHNICAL INPUT MISSING.**

The opaque application bytes and no-inner-decode rule are sound. HTTPS
method/path/media/carrier/outer bounds/status mapping/effective proxy authority
and deterministic fixtures remain missing. No framing is guessed here.

### Trust and Identity

**OPEN / SEPARATE PREREQUISITE / NO-GO.**

No requester, issuer, target owner, authority manifest, rotation record,
Agreement, Contract, Grant, condition, revocation, rollback-anchor, key-provider
or trust-root bytes are created or inferred.

### `MBI-06`

```text
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING
```

The fixed bundle/topic/origin/environment strings are planning bindings only.

### `MBI-07`

```text
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/fixture/evidence/artifact manifest
= MISSING
```

### Action gates

```text
SOURCE: NO-GO
GIT: NO-GO
DEPENDENCY RESOLUTION: NO-GO
BUILD: NO-GO
TEST: NO-GO
NETWORK: NO-GO
PORTAL: NO-GO
SIGNING: NO-GO
DEVICE: NO-GO
APNS: NO-GO
SECRETS: NO-GO
IDENTITY ACTION: NO-GO
STAGING: NO-GO
DEPLOYMENT: NO-GO
INTEGRATION: NO-GO
PRODUCTION: NO-GO
```

## 13. Exact smallest successor scopes

No successor is authorized by this review. If development-admin later opens a
document-only correction, the smallest non-overlapping scopes are:

1. **Server authority/bootstrap correction:** exact requester/target-owner/
   signer/no-create/first-enrollment relation plus Agreement/Contract/Grant/
   consent catalog and import-output ledger.
2. **Server challenge/status correction:** typed pending-indeterminate
   behavior, exact admission-negative privacy rule, complete status field
   matrix, and constructible nested-response maxima.
3. **Server token/legacy correction:** opaque token length bound from an
   authoritative input plus legacy plaintext detection/quarantine/restart
   contract; no retention decision.
4. **Lane B path/fixture correction:** exact Cell/service/store owner matrix and
   producer-manifest SHA consumer ledger.
5. **New independent exact-byte server review:** by a reviewer distinct from
   every correction author.

`MBI-PRIVACY-RETENTION-01` remains a separate explicit Kjetil decision.
Identity, framing, source, build/test, Apple/APNS, integration, and production
remain separate later gates.

## 14. Final independent decision

```text
REVIEWED PATH:
Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md

REVIEWED SHA-256:
5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40

REVIEWED SHAPE:
2403 LINES / 72649 BYTES

P0: 0
P1: 7
P2: 2

LANE B CELLScaffold SERVER CONFORMANCE: NO-GO
S3 NORMATIVE CONTRACT: NO-GO
S1/S2 B FINDINGS: PARTIAL CLOSURE ONLY
MBI-04: PARTIAL / OPEN
MBI-PRIVACY-RETENTION-01: KJETIL DECISION REQUIRED / UNSOLVED
MBI-TRANSPORT-FRAMING-01: TECHNICAL INPUT MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING

PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

The review stops after freezing and re-attesting this one review artifact.
