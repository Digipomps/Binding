# APNS S2 CellProtocol Producer Contract Correction Packet — Independent Review

Status: **REVIEW-FROZEN / S2 LANE A NO-GO / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO**

Review date: `2026-07-25`  
Review role: independent S2 Lane A reviewer, distinct from the Lane A author  
Review mode: exact-byte local static review only  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_Independent_Review_2026-07-24.md`

This reviewer authored the separate S2 Lane C correction and therefore does
not review, score, amend or rewrite Lane C. Lane B and Lane C are used only as
read-only interface witnesses.

The review performed no source edit, Git mutation, dependency resolution,
build, test, network request, portal inspection, signing, archive, device
action, APNS contact, secret access, Identity action, staging mutation or
deployment. It authorizes none of those actions or any next material phase.

## 1. Exact review gate

The owned review-output path was re-attested absent immediately before this
artifact was created.

### 1.1 Exact target

| Property | Reproduced value |
| --- | --- |
| Path | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_2026-07-24.md` |
| SHA-256 | `1b750373b4cb98c71983b002b6a2ce1fd809086776bd64b92d3b27e386969854` |
| Lines | 1746 |
| Bytes | 69053 |
| Result | **MATCH — review permitted** |

The review covers exactly those bytes.

### 1.2 Immutable S0 chain

| Input | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

The inherited S0 result remains:

```text
P0/P1/P2: 0/2/1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

S0 is immutable. This review closes no S0 finding.

### 1.3 Exact S1 packet/review chain

| Lane/input | SHA-256 | Lines | Bytes | Frozen result |
| --- | --- | ---: | ---: | --- |
| A packet | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | Author proposal |
| A review | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | `0/5/2`, NO-GO |
| B packet | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | Author proposal |
| B review | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | `0/4/1`, NO-GO |
| C packet | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | Author proposal |
| C review | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | `0/3/4`, NO-GO |

### 1.4 Peer S2 interface inputs

| Peer | SHA-256 | Lines | Bytes | Treatment |
| --- | --- | ---: | ---: | --- |
| S2 Lane B correction | `cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4` | 1127 | 52292 | Interface comparison only; not reviewed here |
| S2 Lane C correction | `6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56` | 1112 | 52295 | Interface comparison only; authored by this reviewer and not reviewed here |

No peer bytes are promoted to an approved contract by this comparison.

## 2. Review purpose, goal and method

Purposes:

- `purpose://test.acceptance`: determine whether the S2 A bytes completely and
  deterministically bound a later cross-runtime contract implementation.
- `purpose://access.audit.privacy`: challenge any lookup, route, identifier or
  carrier that could leak another subject or become authority.
- `purpose://scaffold.operations`: preserve exact blockers and ownership
  without opening source or production work.

Goal:

> Adjudicate every S1 A P1/P2 finding, `OD-01...07`, and `MBI-01...03`;
> prove that transport has no inner semantics; test status/revoke/deregister,
> admission/replay, origin/TLS, rotation and fixture composability; and return
> one exact NO-GO/GO result from immutable bytes.

Method:

1. reproduced the exact target, S0/S1 and peer S2 document hashes/shapes;
2. read all 1746 target lines;
3. compared the proposed v4 construction with immutable v3 producer objects;
4. reproduced all three literal unsigned JSON body byte counts and SHA-256
   values;
5. checked transport ownership against Resolver/Identity/Agreement rules;
6. checked request construction order, admission identity, replay and response
   framing;
7. checked subject-current and registration-ID lookup privacy/collision;
8. checked revoke/deregister state and genuine product-retention choices;
9. checked origin/audience/TLS/redirect separation;
10. checked fixture inventory and peer consumer assumptions; and
11. treated every unaudited authority or deployment premise as no support.

The three literal body vectors reproduce:

| Vector | Bytes | SHA-256 |
| --- | ---: | --- |
| Subject-current status with correlation | 507 | `144bb92b8987541bc16f83b61e89386103e70226dd867ee02c082d79bc13c0af` |
| Registration-ID status | 218 | `07afe05e58f206f155ca46f3d60d0632d99f0da65a1a86b9633219eae3edd0c0` |
| Deregister | 264 | `503be3b7f4329d08988d0ae8da8ea1bf494c335bbdfeeadaf1e0f0711bfd0db9` |

These hashes prove only those unsigned literal bytes, not signed canonical
requests, authority, fixture completeness or runtime behavior.

## 3. Immutable source comparison

The source comparison used:

| Object | Exact value |
| --- | --- |
| CellProtocol v3 commit/tree | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` / `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` |
| `DeviceIngressWire.swift` blob | `06138743faa6df83690a824fe6bf6d2171601749` |
| `DeviceIngressAdmission.swift` blob | `093d123e6f97da0f68419980870be25f47e4dc1f` |
| `DeviceIngressResponse.swift` blob | `707b8f7cb2b580eb41c927f2f84df58b45e978aa` |

Relevant immutable facts:

- current `DeviceIngressRequestFactory.prepare` receives canonical challenge
  bytes, then creates and signs the request;
- the request includes `challengeSHA256` of those exact challenge bytes;
- request verification binds challenge/request/body bytes;
- current `admissionID` and response expectation use
  `base64url(requestSHA256)`;
- the current operation set is register/resolve/submit with `rw-s`;
- status, revoke, deregister, challenge intent and correlation do not yet
  exist; and
- a future v4 may deliberately replace those shapes, but its new construction,
  identifiers and canonical bytes must then be specified completely rather
  than inferred from v3.

## 4. Executive verdict

The most important S2 correction is supported:

> The transport owns only the outer carrier and HTTP policy. It never decodes
> or authorizes the inner operation. The authenticated CellProtocol
> Resolver/target-Cell boundary decodes the signed request, checks route
> equality, resolves the target and enforces Agreement/Contract/Grant.

That closes the architectural substance of `P1-A-01` for a static plan.

The packet is nevertheless not an implementation-bounding contract. Four P1
defects remain:

1. challenge intent v2 is not constructible/authenticated as specified;
2. the v4 signed/admission/response byte contract is named but not completely
   frozen and contradicts peer raw-response framing;
3. register/update CAS, admission identity and registration-ID collision
   semantics are insufficient to make mutation correlation authoritative; and
4. deregister's erasure/tombstone policy is a genuine product/privacy choice
   incorrectly marked technically resolved.

Two P2 defects remain:

1. the claimed exact fixture inventory omits authority/key artifacts required
   by its own tests and manifest; and
2. the missing-input ledger mislabels Identity and APNS/device evidence as
   top-level `MBI-06` and `MBI-07`.

Exact count:

```text
P0: 0
P1: 4
P2: 2

S2 LANE A PACKET: NO-GO
MBI-01: PARTIAL / OPEN
MBI-02: PARTIAL / OPEN
MBI-03: PARTIAL / OPEN
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
```

## 5. Supported corrections and invariants

The following claims survive this review:

- transport may bound/decode outer Base64 fields but cannot import or call the
  CellProtocol request/envelope decoder;
- transport route labels are unauthoritative metadata;
- route/inner-operation mismatch is evaluated before admission by the
  authenticated CellProtocol boundary;
- Resolver selects the target Cell and route/host cannot replace that choice;
- Agreement alone grants nothing; the exact signed Contract/Grant and
  operation-derived access remain required;
- status uses `r--s`; the mutation operations proposed here use `rw-s`;
- status creates durable admission/audit/replay state without changing
  registration or revocation generation;
- `subject_current` derives its subject from authenticated Identity, exposes no
  list/count/alternate IDs and fails closed on multiple-current corruption;
- wrong-subject registration-ID lookup is required to be externally
  indistinguishable from unknown;
- exact request replay returns stored response bytes without a second mutation;
- historical status replay is not a fresh observation;
- revoke and deregister are not synonyms in the proposed state model;
- `current_exact` cannot be inferred from generation alone;
- origin is exactly `https://haven.digipomps.org`, audience is the host-only
  projection `haven.digipomps.org`, redirects are rejected, and deployed
  TLS/proxy evidence remains separate;
- the manifest path/schema is deterministic in principle and status is
  consistently assigned `r--s`;
- fixed issuer transport possession does not become rotation authority;
- bundle/topic `org.digipomps.haven` are planning values only;
- Identity cutover remains separate; and
- `MBI-06` production signing evidence and `MBI-07` integrated output remain
  operationally missing despite the ledger defect below.

These are plan-level findings only. No source or runtime proof exists.

## 6. P1 findings

### P1-S2-A-01 — challenge intent v2 is neither constructible nor authenticated

**Target locations:** lines 345–347, 409–425, 496–529 and 1505–1511.

The proposed challenge intent requires `requestSHA256` and `bodySHA256` before
challenge issuance. The immutable v3 request factory constructs the signed
request only *after* it receives and verifies exact challenge bytes, and the
request binds `challengeSHA256`. S2 does not freeze a replacement v4
construction order or a challenge-independent signed request template.

Two incompatible interpretations remain:

1. retain v3-style request construction, which makes `requestSHA256` circular
   because the challenge is required to create the request; or
2. sign a v4 request before challenge issuance, which needs an exact new
   request schema and proof explaining how the final request is bound to the
   returned challenge.

The intent also omits the fields needed for its claimed authenticated
challenge boundary:

- subject public descriptor;
- subject signature/proof;
- vault domain binding;
- intent identifier;
- expiry;
- minimum challenge-issuer generation; and
- authority/Agreement lookup binding.

No separate authenticated channel is defined. Nevertheless section 9 requires
subject Identity, issuer-generation floor and challenge binding, and section 25
claims that intent v2 freezes lifetime and generation floor. Those claims do
not follow from the listed members.

**Impact:** `MBI-03` cannot reach a fixed issuer, let alone rotation. A server
cannot authenticate which device requested a challenge or construct a
non-circular request/challenge pair from these bytes.

**Required correction:**

- choose and freeze one exact construction order;
- if the intent precedes the request, bind an exact signed request template or
  body/operation commitment that is not circular;
- include exact subject descriptor, domain binding, proof, intent ID,
  issued/expiry times and issuer-generation floor;
- define authority lookup inputs as hints only;
- define the exact challenge fields that echo/bind the intent;
- add requester-proof, wrong-domain, circularity and generation-floor fixtures;
  and
- keep issuer rotation root/record as the genuine authority MBI.

**Verdict:** **OPEN P1**. The static `MBI-03` framing claim is not closed.

### P1-S2-A-02 — v4 admission and response bytes are not an exact composable contract

**Target locations:** lines 235–236, 254–276, 307–405, 439–456, 1106–1134
and 1318–1343.

The packet names:

- envelope v4;
- corresponding authority/admission/receipt v4 schemas;
- operation response v2; and
- an “exact admission key”.

It does not freeze complete field sets, canonical ordering/encoding or
validation rules for the v4 envelope, authority reference, admission record,
admission receipt, mutation receipt or operation-response envelope. The
operation table also omits an exact `action`/Agreement-scope mapping even
though capability enforcement depends on one unambiguous scope.

The admission-key serialization is explicitly deferred to later fixture bytes.
More importantly, `admissionID` is used by correlation but its derivation from
the proposed admission key is never defined. This is not compatible as written
with the immutable v3/peer C rule:

```text
admissionID = base64url(requestSHA256)
```

Response framing is contradictory:

- line 235 says exact executor bytes are returned inside a specified outer
  response carrier;
- no such response-carrier schema or field set is defined;
- section 9 says the authenticated boundary returns exact canonical response
  bytes; and
- peer S2 B explicitly consumes a raw canonical response while peer S2 C
  requires raw bytes outside the request wrapper.

The byte-limit table's “HTTP response outer carrier” reinforces the undefined
wrapper branch.

**Impact:** producer, server and client cannot generate the same admission ID,
response bytes or fixtures. Replay keys may differ across implementations, and
the consumer cannot know whether to verify raw canonical bytes or unwrap a
second carrier.

**Required correction:**

- freeze every v4/v2 field and canonical encoding, including operation action
  and Agreement-scope key;
- freeze a length-framed admission key and exact `admissionID` derivation;
- choose raw canonical successful response or one exact outer response
  carrier, not both;
- align response media type and byte limits with that choice;
- add response and admission-ID fixtures; and
- update both peer consumer interface packets before claiming composition.

**Verdict:** **OPEN P1**. `OD-01`, `OD-02` and `OD-06` are only partial.

### P1-S2-A-03 — mutation correlation does not freeze the mutation CAS or registration-ID namespace

**Target locations:** lines 531–581, 583–700 and 919–942.

The status correlation object is precise as a post-hoc query, but the protected
register/update request that creates the mutation is not specified. There is
no exact register/update body schema containing:

- registration ID presence/absence and allocation rule;
- `expectedPreviousRegistrationGeneration`;
- expected revocation generation;
- fresh-consent assertion;
- token/endpoint content-contract binding; or
- first-enrollment versus update/reactivation discriminator.

The state table requires exact current ID/generations, while the only explicit
`expectedPreviousRegistrationGeneration` field appears later in the optional
status correlation. Comparing a client-supplied expected value after commit
does not enforce CAS at mutation time.

The target says it serializes per authenticated subject and registration ID,
but does not freeze:

- whether IDs are server-allocated or requester-selected;
- the ID namespace and entropy/length;
- whether the durable uniqueness key is
  `(target Cell, identity domain, subject, registrationID)`;
- collision handling across subjects and historical tombstones; or
- response behavior when an ID collides with another subject.

The `subject_current` selector itself is a strong recovery direction and
properly fails on multiple current records. The missing mutation/ID rules still
prevent proof that the record it returns was created without collision or
stale-update overwrite.

Finally, `current_exact` is defined for an exact mutation that is currently
active **or revoked**, while the text says only `current_exact` proves an
ambiguous token rotation is current. A revoked record has no active delivery
token. The acceptance rule must require both exact correlation and the signed
`active_consented` state.

**Impact:** `MBI-01` does not yet close ambiguous register/rotation recovery.
Concurrent authorized updates can be correlated after the fact but are not
shown to have obeyed the claimed expected-generation precondition.

**Required correction:**

- freeze one exact register/update protected-body schema and content-contract
  hash;
- bind expected registration/revocation generations into the signed mutation
  request and target CAS;
- define first-enrollment ID allocation and composite uniqueness;
- define cross-subject and tombstone collision behavior with indistinguishable
  external results;
- define `admissionID` as required by P1-S2-A-02;
- require `current_exact && state == active_consented` for current token
  rotation; and
- add concurrent update, ID collision and wrong-subject timing/byte-equivalence
  tests.

**Verdict:** **OPEN P1**. Status-by-subject is supported, but mutation
correlation and total `MBI-01` closure are not.

### P1-S2-A-04 — deregister erasure and tombstone retention are genuine product/privacy choices

**Target locations:** lines 813–917, 919–942, 1425–1429, 1483–1498 and
1525–1533.

The packet usefully distinguishes:

- revoke: stop delivery while retaining a reactivatable logical registration;
- deregister: erase endpoint/token material, retain a non-resurrection
  tombstone and require a new ID.

That distinction is technically coherent. The specific policy is not
derivable from CellProtocol invariants:

- `privacy_erasure` is an allowed reason while the operation explicitly erases
  only endpoint/token material;
- the exact tombstone fields are not defined;
- tombstone retention duration/compaction is not defined;
- audit hashes and identity linkage retained after a privacy request are not
  owner-approved;
- no rule says which non-token endpoint metadata must be retained or erased;
  and
- the later status/read-back retention exposure is not tied to an approved
  privacy purpose.

Replay/non-resurrection requires some durable evidence, but it does not decide
the exact retained fields, duration or user-facing meaning. Those are product,
privacy and authority decisions. `OD-04` therefore cannot be marked resolved
solely by a protocol author proposal.

**Impact:** `MBI-02` is not a complete typed revoke/deregister contract. Calling
the endpoint/token operation “privacy erasure” can overstate what it does and
can make an indefinite subject-linked tombstone look owner-approved.

**Required correction:**

- rename the reason to the exact limited erasure semantic or obtain explicit
  privacy-owner approval for a broader erasure contract;
- freeze the minimal tombstone schema and excluded fields;
- freeze retention/compaction/restore/rollback behavior;
- identify the exact authorized purpose for later tombstone status;
- preserve wrong-subject indistinguishability;
- retain revoke and deregister as separate only after the product/privacy
  owner accepts the distinction.

**Verdict:** **OPEN P1 / GENUINE OWNER INPUT**. The operation distinction is a
strong proposal, not a closed owner decision.

## 7. P2 findings

### P2-S2-A-01 — the “exact” producer fixture inventory omits its authority and key artifacts

**Target locations:** lines 1136–1257, 1259–1273 and 1569–1586.

The manifest path and deterministic schema close the path class of the S1
finding. The inventory does not contain all artifacts required by its own
claims:

- only register has a named signed Contract fixture;
- status, revoke, deregister, resolve and submit have no operation-specific
  Agreement/Contract fixture paths despite section 21 requiring status
  Contract bytes with `r--s`;
- deterministic test-only public/private signing material is required by
  `S2-A-MBI-02` but no exact key fixture path is in the inventory or source
  allowlist;
- no exact admission-key/admission-ID fixture is named;
- no response-carrier fixture exists for the unresolved branch in
  P1-S2-A-02; and
- no challenge subject-proof/domain-binding negative fixture exists for
  P1-S2-A-01.

**Impact:** consumers cannot prove complete authority, access or response
parity from the producer manifest, and a future fixture generator would need to
invent paths.

**Required correction:** add exact producer-owned paths and roles for every
operation-specific signed Contract/Agreement, test-key material, admission
identity and the final chosen response framing; then generate and independently
pin exact bytes/hashes.

**Verdict:** **OPEN P2**. `P2-A-02` and `OD-07` are partial, not closed.

### P2-S2-A-02 — the final missing-input ledger mislabels the governing release MBIs

**Target locations:** lines 146–168 and 1627–1645.

Section 3 correctly preserves:

```text
MBI-06 = Apple production signing/profile/entitlement/archive evidence
MBI-07 = exact integrated output
```

Section 27 later says:

- Identity cutover proof is “missing as MBI-06”; and
- staging APNS/device proof is “missing as MBI-07”.

Identity cutover is a separate prerequisite. Physical APNS/device evidence is
also a separate acceptance class. Neither renames the immutable Apple-signing
or integrated-output gates. The target also labels
`org.digipomps.haven` as a “macOS bundle identifier” in an iPad/production APNS
composition where the identifier is a cross-platform planning value.

**Impact:** a later handoff could report the wrong evidence against the release
gate even though the document's earlier sections preserve the correct
meanings.

**Required correction:** keep separate identifiers for Identity cutover and
physical APNS acceptance, and reserve top-level `MBI-06` and `MBI-07` for
Apple signed-archive evidence and exact integrated provenance respectively.

**Verdict:** **OPEN P2 / GATE-LABEL CORRECTION REQUIRED**.

## 8. S1 Lane A finding disposition

| S1 finding | Independent S2 verdict | Basis |
| --- | --- | --- |
| `P1-A-01` transport decodes inner operation | **CLOSED FOR STATIC ARCHITECTURE** | Opaque package dependency and authenticated-boundary route equality are exact and semantically neutral |
| `P1-A-02` deregister absent | **PARTIAL / OPEN** | Typed separate operation exists, but exact erasure/tombstone policy is a genuine owner input; P1-S2-A-04 |
| `P1-A-03` lost-registrationID status recovery | **CLOSED FOR SELECTOR ARCHITECTURE** | `subject_current` is authenticated, subject-derived, non-enumerating and fails closed on multiple-current state |
| `P1-A-04` origin/audience/TLS/redirect incomplete | **CLOSED FOR STATIC POLICY; OPERATIONAL EVIDENCE OPEN** | Exact HTTPS origin, host-only audience, no redirects and media/encoding policy are bound; deployed TLS/proxy proof remains missing |
| `P1-A-05` token rotation correlation incomplete | **OPEN** | Exact query tuple exists, but mutation CAS/ID/admission rules are incomplete; P1-S2-A-03 |
| `P2-A-01` status access mismatch | **CLOSED IN PRODUCER PLAN** | Status is consistently `r--s`; peers also plan per-operation access |
| `P2-A-02` producer manifest path absent | **PARTIAL / OPEN** | Path/schema exist; exact inventory and bytes are incomplete; P2-S2-A-01 |

No S1 artifact is rewritten. “Closed for static architecture/policy” is not
source, runtime or production closure.

## 9. OD-01 through OD-07 adjudication

| OD | Target claim | Independent verdict | Exact residual |
| --- | --- | --- | --- |
| `OD-01` wire version | v4, v3 immutable | **VERSION CHOICE SUPPORTED / CONTRACT PARTIAL** | Complete v4 field/canonical/admission/response contract missing |
| `OD-02` operation set | Exactly six | **PARTIAL** | Six-operation proposal is explicit; deregister product acceptance and complete action/scope mapping remain open |
| `OD-03` status selector/correlation | Resolved | **PARTIAL / OPEN** | Subject selector supported; mutation CAS, ID namespace and admission derivation missing |
| `OD-04` revoke versus deregister | Resolved | **PARTIAL / GENUINE OWNER INPUT OPEN** | Distinction is coherent; erasure/tombstone semantics need privacy/product owner |
| `OD-05` issuer rotation | Open | **CORRECTLY OPEN** | Exact rotation authority/record/trust root remains MBI |
| `OD-06` error ownership | Resolved | **BOUNDARY SUPPORTED / FRAMING PARTIAL** | Transport/protocol/Cell error ownership is sound; response carrier and complete v4 errors depend on final bytes |
| `OD-07` fixture manifest | Path/schema/inventory resolved, bytes open | **PARTIAL / OPEN** | Path/schema supported; authority/key/admission/response inventory and all exact bytes/hashes missing |

## 10. MBI-01/02/03 adjudication

### MBI-01 — current status and ambiguous registration recovery

Supported:

- authenticated subject-current lookup does not require a local
  `registrationID`;
- status remains `r--s`;
- wrong-subject by-ID lookup must not reveal existence;
- multiple-current corruption is indeterminate;
- exact/historical replay is separated from fresh observation;
- the proposed query correlation includes admission, request, body and expected
  previous generation.

Open:

- canonical register/update body and mutation-time CAS;
- admission-key framing and admission-ID derivation;
- registration-ID allocation/composite uniqueness/collision behavior;
- exact active-state requirement for token-current correlation;
- signed fixtures and server/client proof.

Verdict:

```text
MBI-01: PARTIAL / OPEN
```

### MBI-02 — typed revoke and deregister

Supported:

- distinct operations, capabilities, receipts and state effects;
- exact replay/no second mutation;
- already-terminal new-request idempotency;
- deregistered-ID non-resurrection;
- endpoint/token exclusion from the proposed tombstone.

Open:

- privacy/product acceptance of the distinction;
- exact tombstone schema, retention and compaction;
- exact limited-erasure wording versus `privacy_erasure`;
- complete signed fixtures and runtime persistence proof.

Verdict:

```text
MBI-02: PARTIAL / OPEN
```

### MBI-03 — challenge framing, origin and issuer continuity

Supported:

- outer challenge carrier is a one-field opaque byte carrier;
- transport never decodes the intent;
- static origin/audience/redirect/media/encoding policy is explicit;
- issuer rotation is correctly not inferred from HTTPS or a higher number.

Open:

- constructible, signed, subject-bound challenge intent;
- exact request/challenge ordering and binding;
- issuer-generation floor in the actual signed intent;
- fixed issuer descriptor and rotation authority/record;
- complete signed fixtures;
- deployed TLS/proxy/no-redirect evidence.

Verdict:

```text
MBI-03: PARTIAL / OPEN
```

## 11. Cross-lane composability

### 11.1 Lane B interface

The S2 B peer packet at
`cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4`
supports the same core architecture:

- transport is opaque and non-authoritative;
- Resolver/Cell/Agreement owns semantics;
- raw canonical response bytes are stored/replayed;
- challenge ledger binds subject descriptor/proof, subject nonce and exact
  challenge bytes;
- status has durable admission/audit without registration mutation.

It is not composable with target A yet because:

- A intent v2 does not supply the subject/proof/generation inputs B's challenge
  state requires;
- A's response-wrapper branch conflicts with B's raw response;
- B intentionally leaves deregister unavailable pending a reviewed A contract;
  and
- B has no implemented v4 route/manifest/output.

No Lane B defect is adjudicated here.

### 11.2 Lane C interface

The S2 C peer packet at
`6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56`
correctly remains conditional and NO-GO. It expects:

- a signed intent containing subject proof/domain binding and minimum issuer
  generation;
- raw canonical response bytes;
- `admissionID = base64url(requestSHA256)`;
- per-operation access;
- subject-bound status and mutation correlation;
- typed revoke/deregister only after canonical owner choice.

Target A changes the intent to an incomplete v2 shape, does not define the v4
admission ID and leaves response framing ambiguous. A later separately
authorized consumer correction must bind one reviewed producer artifact. This
review grants no peer edit.

### 11.3 Composition verdict

```text
TRANSPORT AUTHORITY TOPOLOGY: COMPOSABLE IN PRINCIPLE
EXACT V4 BYTES/CHALLENGE/ADMISSION/RESPONSE: NOT COMPOSABLE
SERVER/CLIENT IMPLEMENTATION AUTHORITY: NONE
```

## 12. Production and evidence separation

The reviewed packet consistently carries the planning values:

```text
bundle/topic = org.digipomps.haven
origin       = https://haven.digipomps.org
audience     = haven.digipomps.org
domain       = domain:device:notification-callback
purpose      = purpose://access.audit.privacy/device-notification-callback
```

They grant no Cell authority and prove no Apple production state.

The governing evidence classes remain:

- Identity cutover: separate prerequisite, not approved here;
- `MBI-06`: Apple Team/App ID/profile/certificate/effective
  `aps-environment=production`/codesign/archive evidence — **UNAUDITED /
  MISSING**;
- `MBI-07`: exact integrated CellProtocol/Identity/CellScaffold/Binding
  commit/tree/diff/dependency/compiler-input manifest — **MISSING**;
- deployed TLS/proxy evidence — **MISSING**;
- APNS provider acceptance — **NOT TESTED**;
- physical iPad delivery and Binding callback — **NOT TESTED**.

One evidence class cannot substitute for another.

## 13. Exact smallest successor scopes

No successor is authorized by this review. If development-admin later opens
document-only work, the smallest scopes are:

1. **Challenge construction correction:** freeze one non-circular signed
   subject-bound intent/request construction, full fields, issuer floor,
   challenge echo/binding and fixtures.
2. **v4 canonical byte packet:** freeze complete envelope/authority/admission/
   receipt/response schemas, action/Agreement scope, admission ID, raw response
   framing and length-prefixed key vectors.
3. **Registration mutation/ID packet:** freeze register/update body, generation
   CAS, first-ID allocation/composite uniqueness/collision, correlation and
   concurrent mutation tests.
4. **Deregister privacy decision:** product/privacy owner chooses exact limited
   erasure meaning, tombstone schema, retention and read-back purpose.
5. **Fixture inventory correction:** add all operation Contracts, test-key
   paths, admission/response vectors and exact manifest inputs.
6. **Independent exact-byte re-review:** a reviewer distinct from the
   correction author reproduces all bytes and closures.

These scopes remain planning-only unless separately authorized. None may be
combined silently with Identity, Apple signing, integration, deployment or
device/APNS evidence.

## 14. Final decision

```text
S2 LANE A EXACT-BYTE REVIEW: COMPLETE
P0: 0
P1: 4
P2: 2

P1-A-01: CLOSED FOR STATIC ARCHITECTURE
P1-A-02: PARTIAL / OPEN
P1-A-03: CLOSED FOR SELECTOR ARCHITECTURE
P1-A-04: CLOSED FOR STATIC POLICY; DEPLOYMENT EVIDENCE OPEN
P1-A-05: OPEN
P2-A-01: CLOSED IN PRODUCER PLAN
P2-A-02: PARTIAL / OPEN

MBI-01: PARTIAL / OPEN
MBI-02: PARTIAL / OPEN
MBI-03: PARTIAL / OPEN

S2 LANE A PACKET: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PRODUCTION: NO-GO
```

No raw APNS token, secret, private key or unredacted protected payload was read,
displayed or stored. The review stops after freezing and re-attesting this one
review artifact.
