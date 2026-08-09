# APNS S1 CellProtocol Producer/Contract Packet — Independent Review

Date: 2026-07-24  
Observed at: `2026-07-24T23:39:36+0200` (`CEST`)  
Review role: independent Lane A reviewer; distinct from the Lane A author  
Review mode: exact-byte, local, static, read-only  
Review state: **COMPLETE**  
Lane A packet decision: **NO-GO**  
PLAN decision: **NO-GO**  
NEXT PHASE decision: **NO-GO**  
SOURCE authorization: **NONE**

## 1. Independence, authority and stop boundary

This reviewer authored the separate Lane C packet and therefore did not review,
score, amend or rewrite that packet. The reviewer did not author the Lane A
packet reviewed here.

The only authorized output was:

```text
Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md
```

The review performed no source edit, Git index/branch/commit/ref mutation,
dependency resolution, build, test, network access, Apple portal access,
signing, archive, device action, APNS contact, secret access, Identity action,
staging mutation or deployment. Primary dirty repositories were treated as
hard no-touch. Only named immutable Git objects and the exact documentation
bytes were inspected.

No result in this review authorizes a source packet or any next material phase.

## 2. Exact input gate

### 2.1 Immutable upstream documents

| Input | Required SHA-256 | Reproduced lines | Reproduced bytes | Result |
| --- | --- | ---: | ---: | --- |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 | MATCH |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 | MATCH |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 | MATCH |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 | MATCH |

Bound S0 review count:

```text
P0: 0
P1: 2
P2: 1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

### 2.2 Exact review target

| Property | Reproduced value |
| --- | --- |
| Path | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` |
| Required SHA-256 | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` |
| Actual SHA-256 | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` |
| Lines | 1141 |
| Bytes | 48951 |
| Result | **MATCH — review permitted** |

The review output path was absent at the write boundary.

### 2.3 Peer packets used only for interface consistency

| Peer input | SHA-256 | Lines | Bytes | Treatment |
| --- | --- | ---: | ---: | --- |
| `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | Read-only interface comparison |
| `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | Read-only interface comparison; not reviewed |

No peer packet is asked to change by this review. Interface inconsistencies are
recorded as integration blockers only.

## 3. Review purpose, goal and evidence rule

Purposes:

- `purpose://test.acceptance`: reproduce immutable bytes and determine whether
  proposed fixtures and wire rules are sufficient for a later deterministic
  contract gate.
- `purpose://access.audit.privacy`: challenge every path that could turn
  transport, lookup hints, local state or device metadata into authority.
- `purpose://scaffold.operations`: preserve exact ownership and stop conditions
  without opening source or operational work.

Goal:

> Independently adjudicate the Lane A factual claims, P1-S0-01 correction,
> MBI-01/02/03 proposals, producer/consumer boundary and residual blockers from
> exact local evidence.

Evidence rule:

- immutable object/blob/fixture facts may be supported;
- Lane A wire choices remain proposals even when internally precise;
- an open owner decision supplies no implementation evidence;
- no source/build/runtime result is inferred from a plan; and
- one unresolved semantic choice is enough to retain every NO-GO.

## 4. Immutable object reproduction

### 4.1 CellProtocol object and range

| Property | Reproduced value | Result |
| --- | --- | --- |
| Base commit/tree | `79740304167aa4f4daadd148c5a369e919d25a6a` / `71ee11a69139a1c222c2156ab1bc79dbe0115620` | MATCH |
| Head commit/tree | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` / `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` | MATCH |
| Endpoint path count | 11 | MATCH |
| Null-delimited name-status SHA-256 | `912ca02e45425581fca429191010002c7f756ba78e002c4b9aceca255ec68cff` | MATCH |

Every blob listed in Lane A section 4.1 reproduced:

| Path | Reproduced blob |
| --- | --- |
| `Sources/CellBase/DeviceIngress/DeviceIngressWire.swift` | `06138743faa6df83690a824fe6bf6d2171601749` |
| `Sources/CellBase/DeviceIngress/DeviceIngressAdmission.swift` | `093d123e6f97da0f68419980870be25f47e4dc1f` |
| `Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift` | `707b8f7cb2b580eb41c927f2f84df58b45e978aa` |
| `Tests/CellBaseTests/DeviceIngressContractTests.swift` | `52e4b54db94a662dbc4d8cd1e48058c9d2c7d648` |
| `Tests/CellBaseTests/DeviceIngressWireFixtureTests.swift` | `f870b2b5472aa0ca4be445394e3c1c27f8ed056f` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressChallenge.v3.b64` | `1cd2a2c3f88cdb9e386ce9f20f6991478d385aaf` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressRequest.v3.b64` | `e234d9536351f99d787a5c76e29af4871b0918b3` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressResponse.v3.b64` | `a3a998de1853d47e03364866392bf11b86449f86` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressSignedContract.v3.b64` | `a3de633e5954200b5b6ed3fa1b8570de70ad97ca` |
| `Docs/DeviceIngressSecurityContract.md` | `6947a4265f7b97db2aa504e726a1059be0464915` |
| `Package.swift` | `2774eded87ff829240168e89f8bcb2f7610dd44c` |

The primary local CellProtocol checkout was dirty and behind its observed
remote-tracking state. None of those worktree bytes was used as evidence.

### 4.2 CellScaffold carrier object and range

| Property | Reproduced value | Result |
| --- | --- | --- |
| Predecessor commit/tree | `38195a233b84d09f66e5ef483800228f857fff2a` / `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` | MATCH |
| Head commit/tree | `d2d1b7191d651ad42d172e980ab94a0fd478d07c` / `536531541587b5229b8f325f8935ed11ef85f228` | MATCH |
| Route-fix path count | 2 | MATCH |
| Null-delimited name-status SHA-256 | `51c3daffedd3330995a84c27fb1d23fee4ef37a7bbfb8dd561db5211d01fa442` | MATCH |

Every blob listed in Lane A section 4.2 reproduced:

| Path | Reproduced blob |
| --- | --- |
| `Sources/App/Controllers/DeviceCallbackCapabilityServer.swift` | `5e85f42ef816c71ff3be11ef5a17abf70ea295a8` |
| `Sources/App/Controllers/VaporDeviceCallback.swift` | `1835c26b94154ec97088f956901bbd7be62c413b` |
| `Tests/AppTests/DeviceCallbackCapabilityServerTests.swift` | `4defe2191cb20f77afb913d5dbcd6517c599b85d` |
| `Documentation/DeviceCallbackCapabilityServer.md` | `b9004c4749ea31e0994aae210a40c18f500e6b30` |
| `Package.swift` | `ab117c5337e8f8ef6f0f70ef2f79a9625d812870` |
| `Package.resolved` | `c6565bd936f6ba8a8d9154b307943ad687a2a721` |

### 4.3 Immutable source assertions

Read-only source reproduction supports:

- current `DeviceIngressOperation` is exactly `register`, `resolve`, `submit`;
- current operation resource/action/capability bindings match Lane A;
- current `requiredAccess` is `rw-s` for all three existing operations;
- current identity domain and purpose match Lane A;
- canonical decode re-encodes and byte-compares;
- the request binds exact challenge and protected-body digests;
- the Resolver-selected target Cell returns complete canonical signed
  Agreement evidence that CellBase independently verifies;
- response success is a raw canonical operation response;
- current CellScaffold carrier has exactly three binary request fields;
- current server decodes the canonical request read-only to bind its inner
  operation to the HTTP route, without treating that decode as authority;
- only register may reach current admission; challenge/resolve/submit remain
  unavailable; and
- current security documentation remains v2/`-w--` while code is v3/`rw-s`.

These are source-level facts only.

## 5. Deterministic fixture reproduction

### 5.1 Existing decoded fixtures

| Fixture | Lane A decoded SHA-256 | Reproduced SHA-256 | Result |
| --- | --- | --- | --- |
| Challenge | `ca4e510223ae548e6d482004926c7d322ec4999d8e282984401b6b08254f15de` | same | MATCH |
| Request | `8c8ca1f5ec598488d2da0674291a069cd5b1169bb24196a767fe4d8770cb9877` | same | MATCH |
| Signed Contract | `5e46a6027385fd41af9b56e3870298e5b79666d59c24f0bb1656427e179ef083` | same | MATCH |
| Response | `291a35775c9be3826e48a6d330ea8027d8be490b6fd1697e9c946da170eaa0b0` | same | MATCH |

The current fixture test uses production-shaped but deterministic test-only
protected-body bytes. Without reproducing the raw value here, the review
confirmed:

```text
byte count: 61
SHA-256: 7ad22f5cd6c74dfdb3596782371f41ead27a70b96b2d625fecccb0a9a98bd686
```

No production token was read.

### 5.2 Proposed typed body vectors

| Proposal | Claimed bytes | Reproduced bytes | Claimed SHA-256 | Result |
| --- | ---: | ---: | --- | --- |
| Status protected body | 171 | 171 | `6820fab5db8d68959f8fd6b2e8cb5b8581a86d1d34c503ebd0f7a82187fd6fe7` | MATCH |
| Revoke protected body | 206 | 206 | `8ac820e04a24cbb84b0b2f52e5fc5420da1c90f69cc4fd415aa4d5e8494487d5` | MATCH |

Those hashes prove only that the packet's proposed literal JSON is
self-consistent. They do not prove owner acceptance, signatures, challenge
bytes, request bytes, response bytes, interoperability or runtime behavior.

## 6. P1-S0-01 adjudication

The prior contradiction was that one three-binary-field request wrapper was
said to contain four canonical fixtures. Lane A corrects that precisely:

| Role | Correct boundary |
| --- | --- |
| `canonicalChallenge` | Request-wrapper input 1 |
| `canonicalRequest` | Request-wrapper input 2 |
| `protectedBody` | Request-wrapper input 3 |
| Signed Agreement/Contract | Resolver/selected-Cell authority evidence; not a wrapper field |
| Canonical operation response | Raw successful output; not a wrapper field |

The existing four decoded fixture hashes and the protected-body test vector
reproduce. The proposed outer fixture has exactly the three request inputs.

Independent verdict:

```text
P1-S0-01: CLOSED FOR STATIC FIXTURE-ROLE PLANNING
```

This verdict does not authorize transport source. It also does not close the
separate transport-boundary defect `P1-A-01` below.

## 7. MBI-01 current-status review

### 7.1 What Lane A freezes as a proposal

Lane A gives an explicit proposed:

- `status` operation;
- resource/action/capability/access tuple;
- protected-body schema and exact deterministic body vector;
- signed result kind, schema, states and field set;
- registration/revocation generation rules;
- owner-signed `unknown` and fail-closed `indeterminate_retryable`;
- byte-identical same-request replay;
- fresh-request requirement for current status;
- paths for source, tests and fixtures; and
- rejection tests.

This is materially better than an unnamed gap and is suitable for owner
adjudication.

### 7.2 Remaining semantic blockers

The proposal requires a non-empty `registrationID` in every status request.
It defines no subject-only lookup, no optional record selector and no
identity-vault-bound durable registration-ID recovery contract.

Consequences:

- after app-data loss, restore or uninstall/reinstall, the persistent device
  identity may survive while the local registration ID does not;
- local absence still cannot prove server deregistration; but
- the proposed status operation cannot ask the authoritative Cell for the
  subject's current record without the missing local ID.

That contradicts the required recovery use of fresh signed status, not the
packet's explicit historical-evidence rule. The contract owner must choose an
exact, privacy-preserving recovery selector or explicitly declare that status
cannot recover after lost local evidence and provide another canonical
operation.

The token-generation proposal is also incomplete for ambiguous rotation.
`registrationGeneration` is declared to be token-binding generation, but the
packet does not change register/update input to carry an expected prior
generation or return a current-status correlation to the exact ambiguous
registration admission/request/body. A higher generation alone does not prove
which concurrent authorized update installed the current raw token.

Lane A records `OD-03` as open, which honestly preserves the gate. It means the
literal status proposal is not yet a closed token-rotation contract.

Independent verdict:

```text
MBI-01: PARTIAL / OPEN
```

The names and fields are explicit proposals. Restore/read-back and exact
rotation correlation remain missing semantic choices.

## 8. MBI-02 revoke/deregister review

Lane A provides a detailed proposed `revoke` operation:

- exact operation/resource/action/capability/access;
- canonical protected-body schema and literal vector;
- exact expected-generation CAS inputs;
- reason-code set;
- signed revocation receipt;
- tombstone digest, sequence and persistence semantics;
- byte-identical replay and `already_revoked`;
- stale/unknown denial; and
- mandatory fresh status after revoke.

It correctly keeps pre-registration “Not now” separate.

However, the packet never defines or rejects a `deregister` operation. The
complete operation map contains `revoke` only, while the MBI table labels the
proposal “typed revoke/deregister.” It does not decide whether deregistration:

- is exactly synonymous with revoke;
- deletes endpoint/token material while retaining a revocation tombstone;
- is a second typed operation with different retention semantics; or
- is deliberately unsupported.

Both peer packets leave this exact decision to Lane A. The omission would force
a server or client implementer to invent the distinction.

Independent verdict:

```text
MBI-02: PARTIAL / OPEN
```

The `revoke` proposal is concrete. Deregistration semantics remain missing.

## 9. MBI-03 challenge-framing review

### 9.1 What Lane A freezes as a proposal

Lane A proposes:

- signed `DeviceIngressChallengeIntent`;
- exact schema, field list, proof boundary, lifetime/skew/nonce maxima;
- one-field base64 JSON challenge request;
- `POST /conference-mvp/api/device/challenge`;
- raw canonical challenge success body;
- intent and challenge size limits;
- Resolver-selected Cell/owner/Contract authority;
- issuer replay and monotonic rotation outline;
- exact future source/test/fixture/doc paths; and
- transport/protocol error families.

The challenge intent is explicitly non-authoritative. Lookup hints cannot
replace the Resolver-selected Cell, owner or complete signed Contract.

### 9.2 Remaining semantic blockers

The packet chooses:

```text
public origin = https://haven.digipomps.org
DeviceIngress audience = haven.digipomps.org
```

but does not classify full-origin-versus-HTTP-authority projection as an owner
decision. That mapping is not derivable from the immutable production source.
The server peer packet correctly leaves it open as `B-DEC-09`.

The shared transport error list and endpoint contract also do not freeze:

- rejection of an insecure scheme;
- wrong origin or HTTP authority;
- redirect/cross-origin behavior;
- TLS/certificate failure classification;
- request `Content-Type`/`Accept` for challenge and protected operations; or
- content-encoding handling.

Lane A states that wrong origin must fail and that production uses the exact
HTTPS origin, but the exact carrier API/error contract needed to enforce those
statements is absent.

Issuer rotation remains explicitly blocked by `OD-05`; no rotation-record
schema, trusted transition root or exact storage path exists.

Independent verdict:

```text
MBI-03: PARTIAL / OPEN
```

The byte carrier is explicit. Production origin/audience enforcement and
issuer-rotation proof remain open.

## 10. Transport neutrality and producer/consumer boundary

### 10.1 Supported boundary

The packet correctly states:

- the wrapper carries exact bytes only;
- HTTP status is not Cell success;
- transport does not select Identity, Cell, owner, Agreement, Contract,
  authority generation or semantic result;
- malformed/oversize carrier failures remain transport failures;
- target-Cell authority and canonical response verification remain in
  CellProtocol; and
- no raw token, protected body or complete signed Contract belongs in logs.

### 10.2 Unresolved decode-boundary contradiction

Lane A simultaneously requires:

1. method/path/inner-operation mismatch to fail before admission; and
2. transport never to decode an authority-bearing type.

The immutable current server performs the first rule by decoding the canonical
request read-only as `DeviceIngressEnvelope`, then checking its operation.
That envelope carries subject proof and an authority reference. Without some
read-only CellProtocol decode or operation extractor, the carrier cannot know
that the inner operation mismatches its route.

The source packet must choose one exact owner:

- CellBase exposes a canonical, non-authoritative operation-inspection helper;
- the CellScaffold consumer performs the existing read-only decode and route
  binding outside the shared transport target; or
- the shared target performs a documented read-only canonical decode while
  explicitly prohibiting authority interpretation.

Until then, the transport tests in Lane A section 15.2 cannot prove both claims
at once.

## 11. Exact path and fixture-boundary review

### 11.1 Path allowlist

The proposed CellProtocol paths are explicit and non-wildcard:

- eight existing CellBase contract/doc/test paths;
- two new challenge-intent source/test paths;
- exact existing and proposed CellBase fixture files;
- exact SwiftPM product/source/test/doc paths; and
- exact shared transport fixture files.

No CellScaffold or Binding source path is authorized.

### 11.2 Missing canonical producer manifest path

Lane A requires consumers to hash-pin copied producer fixtures and records
`OD-07` for an exact fixture SHA ledger. It does not name a canonical
machine-readable producer-manifest path in the CellProtocol output allowlist.

The Binding peer packet has a consumer-side
`BindingTests/Fixtures/DeviceIngressSharedFixtureManifest.json`, but no
producer-owned artifact is named for that consumer to verify. Test-source
assertions could hardcode hashes, but that is not the explicit cross-runtime
producer/consumer manifest boundary the packet claims to freeze.

This is path/output incompleteness, not permission to invent a filename. A
future documentation-only owner decision must name the producer manifest path
before source work.

## 12. Peer interface consistency

### 12.1 Lane B

The server packet consistently:

- treats status/revoke/deregister/challenge wire semantics as Lane A-owned;
- keeps current routes unavailable;
- requires the same Resolver-selected Cell/Agreement authority;
- requires signed status and revocation read-back;
- imports a shared transport product rather than copying it;
- binds bundle/topic/origin to the expected production values; and
- leaves exact audience projection open as `B-DEC-09`.

Lane B does not conflict with Lane A's current three-input wrapper correction.
It cannot consume Lane A until the MBI and findings in this review are resolved.

### 12.2 Lane C

The client packet consistently:

- consumes a semantically neutral shared transport;
- persists expectations before send;
- never treats historical register evidence as current;
- requires fresh status and typed revoke/deregister;
- keeps raw tokens out of durable local stores; and
- leaves wire decisions to Lane A.

One access-string inconsistency exists:

- Lane A proposes `status` with `r--s`;
- Lane C's adversarial test list says wrong `rw-s` access fails without
  distinguishing status.

Because Lane A's status access is unreviewed and both packets remain NO-GO,
this is a cross-lane P2, not evidence that either implementation is unsafe.
The later reviewed interface must use `operation.requiredAccess` and must not
hardcode one permission string across all operations.

No change to Lane C is requested or performed here.

## 13. Identity, bundle/topic/origin and release separation

The packet correctly preserves:

```text
bundle identifier: org.digipomps.haven
APNS topic: org.digipomps.haven
origin: https://haven.digipomps.org
```

It also correctly says:

- bundle and topic do not grant Cell authority;
- HTTP/APNS does not participate in Agreement/Resolver proof;
- `c700dbc…` Identity source is outside Lane A;
- Identity cutover remains a separate prerequisite;
- Associated Domains remains conditional/removable;
- no Team/profile/certificate/archive/codesign proof was inspected; and
- no APNS/provider/physical callback evidence exists.

The host-only audience choice still requires the owner decision described in
`P1-A-04`. Source intention is not production origin/TLS proof.

`MBI-06` remains **UNAUDITED / MISSING**.

`MBI-07` remains **MISSING**.

## 14. Adversarial findings

### P0

No P0 defect was found in this plan-only packet. No material or production
action occurred.

### P1

#### P1-A-01 — Inner-operation route binding contradicts the stated no-decode transport boundary

Locations:

- Lane A lines 602–604;
- Lane A lines 747–763; and
- Lane A lines 927–942.

The packet requires pre-admission inner-operation checking while also
prohibiting transport from decoding authority-bearing types. The current
implementation decodes the request read-only. An exact component/API owner is
missing.

Effect: shared transport source and consumer tests remain blocked.

#### P1-A-02 — MBI-02 claims revoke/deregister coverage but defines only revoke

Locations:

- Lane A lines 243–261;
- Lane A lines 354–439; and
- Lane A lines 1075–1084.

No canonical deregister semantic or explicit decision to omit/alias it exists.

Effect: `MBI-02` remains partial and server/client stop behavior cannot be
implemented without invention.

#### P1-A-03 — Status cannot recover current state when local registration ID is lost

Locations:

- Lane A lines 269–303; and
- Lane A lines 304–352.

The status request mandates a local registration ID and defines no
subject-bound authoritative lookup after local evidence loss.

Effect: restore/uninstall/read-back acceptance remains blocked.

#### P1-A-04 — Production origin/audience and secure HTTP enforcement are not an exact owner-gated contract

Locations:

- Lane A lines 458–475;
- Lane A lines 479–513;
- Lane A lines 589–604;
- Lane A lines 698–719; and
- Lane A lines 1057–1073.

Host-only audience is chosen without an owner-decision entry; secure-scheme,
wrong-origin/authority, redirect and TLS failure behavior is not frozen.

Effect: `MBI-03` remains partial; production host binding cannot be claimed.

#### P1-A-05 — Registration generation alone does not correlate an ambiguous token update

Locations:

- Lane A lines 127–145 (`PROP-04`);
- Lane A lines 304–352; and
- Lane A lines 1057–1073 (`OD-03`).

The proposal lacks an expected-prior-generation register/update input or a
status field tied to the exact prior admission/request/body. A generation rise
alone is ambiguous under concurrent authorized update.

Effect: token rotation remains an open cross-owner semantic decision and
`MBI-01` cannot close the rotation part of read-back.

### P2

#### P2-A-01 — Peer client test text hardcodes `rw-s` while Lane A proposes status `r--s`

Locations:

- Lane A lines 243–261; and
- Lane C lines 631–643.

Effect: later interface tests must dispatch on the reviewed operation-specific
access string. No peer edit is authorized here.

#### P2-A-02 — No exact producer-owned machine-readable fixture SHA manifest path is named

Locations:

- Lane A lines 804–903;
- Lane A lines 905–975; and
- Lane A `OD-07`.

Effect: cross-runtime consumers have paths and assertions but no canonical
producer manifest artifact to hash-pin.

Finding count:

```text
P0: 0
P1: 5
P2: 2
```

## 15. Prior and current finding disposition

| Finding/input | Independent verdict | Reason |
| --- | --- | --- |
| `P1-S0-01` three-field wrapper/four-role contradiction | **CLOSED FOR STATIC FIXTURE-ROLE PLANNING** | Three request inputs, Resolver/Cell Contract evidence and raw response output are now separate and exact |
| S0 P1 production output completeness | **REMAINS OPEN** | No source successor, server authority, Binding output or integrated object exists |
| `MBI-01` current status | **PARTIAL / OPEN** | Explicit proposal, but recovery selector and rotation correlation remain missing |
| `MBI-02` revoke/deregister | **PARTIAL / OPEN** | Revoke is explicit; deregister is undefined |
| `MBI-03` challenge framing | **PARTIAL / OPEN** | Carrier is explicit; issuer rotation and origin/audience/TLS/redirect contract remain open |
| `MBI-04` server issuer/admission/replay/Cells/Agreement | **MISSING / OUTSIDE LANE A** | Lane B remains planning-only |
| `MBI-05` Binding output/rotation | **MISSING / OUTSIDE LANE A** | Lane C remains planning-only |
| `MBI-06` Apple production signing evidence | **UNAUDITED / MISSING** | Forbidden external evidence |
| `MBI-07` integrated commit/tree/digest | **MISSING** | No integration authorized |

## 16. Claim adjudication

| Lane A claim | Independent result |
| --- | --- |
| Exact document and source objects are bound | SUPPORTED |
| Blob IDs, range trees/counts/digests reproduce | SUPPORTED |
| Existing decoded fixture hashes reproduce | SUPPORTED |
| Proposed status/revoke literal body sizes and hashes reproduce | SUPPORTED AS PACKET BYTES ONLY |
| Wrapper has exactly challenge/request/protectedBody inputs | SUPPORTED |
| Signed Contract is Resolver/Cell authority evidence, not wrapper input | SUPPORTED |
| Response is raw output, not wrapper input | SUPPORTED |
| P1-S0-01 fixture-role contradiction is statically resolved | SUPPORTED |
| Status proposal is complete enough to close MBI-01 | CONTRADICTED |
| Revoke proposal closes revoke/deregister MBI-02 | CONTRADICTED |
| Challenge framing closes production MBI-03 | CONTRADICTED |
| Transport producer assertions are internally compatible | CONTRADICTED |
| Token rotation is exactly reconciled by the proposed generation | UNSUPPORTED / OPEN |
| Producer/consumer path boundary is fully closed | PARTIAL; fixture manifest path missing |
| Transport grants no Cell authority | SUPPORTED AS A REQUIRED DESIGN INVARIANT |
| Bundle/topic/origin values are production proof | CORRECTLY REJECTED BY PACKET |
| Identity cutover is completed by Lane A | CORRECTLY REJECTED BY PACKET |
| Source or next phase is authorized | CONTRADICTED |

## 17. Final decision

```text
LANE A INDEPENDENT STATIC REVIEW: COMPLETE
P0/P1/P2: 0/5/2
P1-S0-01: CLOSED FOR STATIC FIXTURE-ROLE PLANNING
MBI-01: PARTIAL / OPEN
MBI-02: PARTIAL / OPEN
MBI-03: PARTIAL / OPEN
LANE A PACKET: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
```

Any one open MBI, P1 or owner decision is sufficient to retain every NO-GO.
The packet's honest author NO-GO is therefore preserved.

No new source packet, implementation assignment, dependency pin, build/test
window, server/client composition, signing, runtime, device or APNS action is
opened by this review. The reviewer stops after this one artifact.
