# Independent exact-byte review — APNS S1 CellScaffold server contract packet

Status: **INDEPENDENT STATIC REVIEW / LANE B ONLY / P0 0 / P1 4 / P2 1 / MBI-04 NOT GREEN / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO**

Review date: `2026-07-24`

Reviewed packet:
`Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md`

Reviewed exact SHA-256:
`5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a`

Reviewed shape: `1113` lines / `48837` bytes.

Owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md`

This review is independent of the Lane B packet author. The reviewer authored
the Lane A packet, so Lane A is used here only as a literal, read-only interface
input. This document does not review, approve, amend or replace Lane A or Lane C.

This was a static review. It performed no source edit, Git mutation, dependency
resolution, build, test, network request, portal inspection, signing, device
action, APNS action, secret inspection, Identity action, staging mutation or
deployment. It authorizes none of those actions.

## 1. Executive verdict

The Lane B packet correctly preserves the most important architectural
boundaries:

- HTTP remains a byte carrier and never becomes authority.
- Resolver selection, the exact target Cell, its owner and complete signed
  Agreement/Contract remain the authority path.
- A challenge grants no operation.
- Admission must be durable before a target operation.
- Target mutation and exact signed response must commit together.
- Ambiguous, unavailable, corrupt, stale and rollback states fail closed.
- Raw APNS tokens are excluded from public state, logs, fixtures and receipts.
- Identity cutover remains a separate prerequisite.
- `MBI-06` remains unaudited/missing and `MBI-07` remains missing.
- The packet itself preserves `PLAN NO-GO`, `NEXT PHASE NO-GO` and no source
  authorization.

Those supported boundaries are not enough to make the packet green. Four P1
defects prevent it from becoming an implementation-bounding `MBI-04` plan:

1. it hard-codes `rw-s` for every operation even though the frozen Lane A
   interface proposes `status` with `r--s`;
2. its status transaction says not to mutate admission state, which conflicts
   with durable status admission/audit/replay;
3. it names two new Cells but does not freeze their Resolver registration,
   scope, persistency, identity domain, lifecycle or owner bootstrap;
4. it allows challenge issuance to retain only a digest even though exact-byte
   replay requires the stored canonical challenge bytes.

One P2 test-coverage gap remains around protected-token encryption, key
unavailability/rotation, tamper handling and legacy-row migration.

Final count:

```text
P0: 0
P1: 4
P2: 1

MBI-04: AUTHOR-PROPOSED PARTIAL / INDEPENDENT REVIEW NOT GREEN
MBI-04 OPERATIONAL: MISSING / OPEN
SOURCE AUTHORIZATION: NO
PLAN: NO-GO
NEXT PHASE: NO-GO
PRODUCTION: NO-GO
```

## 2. Exact-byte gate and immutable inputs

The review re-attested the following local bytes:

| Artifact | SHA-256 | Shape | Result |
| --- | --- | --- | --- |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | `573` lines / `38154` bytes | Match |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | `547` lines / `29346` bytes | Match |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | `984` lines / `54678` bytes | Match |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | `461` lines / `22485` bytes | Match |
| Lane A producer packet | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | `1141` lines / `48951` bytes | Read-only interface comparison |
| Lane B server packet | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | `1113` lines / `48837` bytes | Exact review target |
| Lane C client packet | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | `853` lines / `45250` bytes | Read-only interface comparison |

The owned review-output path did not exist before this review was written.

The inherited S0-review result remains:

```text
P0: 0
P1: 2
P2: 1
PLAN NO-GO
NEXT PHASE NO-GO
```

This review does not upgrade or replace that result.

## 3. Review method and decision rule

The review used:

- exact local SHA-256 and line/byte counts;
- complete line-numbered reading of the Lane B packet;
- exact `git show`, `git rev-parse` and `git ls-tree` reads at the packet's
  selected immutable objects;
- literal comparison with the author-frozen Lane A and Lane C packet bytes;
- CellProtocol rules for Resolver authority, Agreements/Contracts, `rwxs`,
  transport neutrality, durable admission, same-Cell mutation and exact replay;
- CellScaffold rules for runtime registration, persistence, restart and
  fail-closed readiness.

Priority means:

- **P0:** the plan authorizes or creates an immediate critical breach or
  irreversible unsafe action;
- **P1:** the contract is unsafe, contradictory or too incomplete to bound a
  later implementation;
- **P2:** material test, documentation or audit completeness is missing but the
  defect does not independently define authority.

No unaudited external source is counted as support.

## 4. Findings

### P0

No P0 finding.

The packet is planning-only, keeps production red and grants no material action.
Its defects therefore remain plan-blocking P1/P2 issues rather than an executed
production compromise.

### P1-01 — blanket `rw-s` contradicts the frozen per-operation access contract

**Exact Lane B locations**

- lines `341–347`: the authority catalog is required to verify
  `DeviceIngressAgreementScope.grantKeypath()` and `rw-s` “at every use”;
- lines `589–596`: section 8.1 says the exact hash-derived keypath always has
  permission `rw-s`;
- lines `884–903`, especially line `898`: the negative test treats permissions
  other than the one blanket value as mismatches.

**Contradicting interface input**

Lane A lines `243–251` freeze this author-proposed operation table:

| Operation | Access |
| --- | --- |
| `register` | `rw-s` |
| `status` | `r--s` |
| `revoke` | `rw-s` |
| `resolve` | `rw-s` |
| `submit` | `rw-s` |

Lane A lines `261–267` explain the distinction: status reads and returns a
retainable result, while revoke mutates. The author-frozen Lane C packet still
contains a generic `rw-s` negative-test assertion at line `639`; that peer
assertion does not cure Lane B because Lane C explicitly defers wire authority
to Lane A.

**Impact**

A Lane B implementation following the packet would either reject the proposed
canonical status Contract or demand an unnecessarily writable Grant for a read
operation. That violates exact operation binding and least privilege. It can
also hide an implementation bug if the current CellProtocol hard-coded
`rw-s` check is retained when status is added.

**Required correction**

Every authority, Agreement and negative-test rule must use the exact
operation-derived access:

```text
request.requiredAccess
  == request.operation.requiredAccess
  == exact signed Contract Grant access
```

For the current Lane A proposal that is `r--s` for `status` and `rw-s` for the
four result-bearing mutation operations. Until the Lane A owner decision and
independent review are green, status remains unavailable; Lane B must not
replace the unresolved decision with blanket `rw-s`.

### P1-02 — status cannot skip durable admission/replay state

**Exact Lane B locations**

- lines `545–559` define transaction boundaries;
- line `549` says every admission record and receipt are durable before target
  mutation;
- lines `558–559` then say status signs a consistent snapshot “without
  mutating admission state”;
- lines `467–479` require identical replay but do not classify replayed status
  as historical;
- lines `561–564` correctly say ambiguous commit is unavailable.

**Contradicting interface input**

Lane A lines `665–683` require:

- durable admission before every target-Cell operation;
- status snapshot audit record and exact signed response committed atomically;
- no registration-state change;
- byte-identical replay;
- restart-preserved uniqueness, watermarks and exact response bytes.

Lane A lines `350–352` additionally distinguish a replayed status snapshot from
a fresh current-state check. Fresh status requires a new challenge and request.

**Impact**

“Do not mutate admission state” is the wrong boundary. A status operation must
not mutate registration/domain state, but it still must durably consume its
admission identity, store its status audit snapshot and exact response, and
support conflict detection and exact replay. If admission state is left
untouched, duplicate or conflicting status requests cannot be adjudicated
reliably after crash or restart.

**Required correction**

Replace the status transaction rule with all of:

1. commit and read back the status request's admission record/receipt;
2. read one target-Cell generation-consistent registration snapshot;
3. atomically commit the status audit snapshot and exact signed response;
4. do not mutate registration, token or revocation domain state;
5. return stored bytes on identical replay without re-signing;
6. treat replay as historical evidence, never as fresh status;
7. require a new challenge/request for a fresh current-state assertion.

The status service and its tests must state that distinction literally.

### P1-03 — new Resolver Cells lack an exact registration and owner bootstrap contract

**Exact Lane B locations**

- lines `298–328` name
  `cell:///DeviceIngressChallengeIssuer` and its source file;
- lines `330–355` name
  `cell:///DeviceIngressAuthorityCatalog` and its source file;
- lines `481–505` give startup sequencing;
- lines `642–659` defer Agreement provisioning;
- lines `706–816` give the future file allowlist and assign
  `Sources/App/configure.swift` to the development-admin integrator;
- `B-DEC-01` and `B-DEC-05` defer issuer manifest and Agreement import details.

**Missing exact contract**

For both proposed Cells the packet omits:

- `cellScope`;
- `.persistant` versus another persistency;
- resolver `identityDomain`;
- lifecycle policy;
- exact owner identity acquisition and proof path;
- whether owner absence is a startup failure;
- exact registration order relative to coordinator recovery;
- exact registration assertions the integrator must place in
  `Sources/App/configure.swift`;
- an explicit decision-ledger row for those registration semantics.

The authority catalog's exact signed-Agreement import/output path is also still
deferred by `B-DEC-05`. The packet names a source type, but not the exact
runtime registration that makes it a Resolver-selected Cell rather than a
singleton service.

**Impact**

`MBI-04` explicitly requires production Resolver Cells and Agreement
source/output paths. A `cell:///` name and a Swift filename do not determine
whether a Cell is scaffold-unique, identity-unique, persistent, which domain
owns it, or how it fails when its owner is absent. Those choices materially
change authority and restart behavior. The omission also leaves the packet's
“no static admission root” rule declarative rather than mechanically bounded.

**Required correction**

A successor planning packet must, without creating any identity:

- freeze the complete resolver registration tuple for each new Cell;
- freeze owner lookup/proof and `makeNewIfNotFound=false` behavior;
- freeze persistency and lifecycle/recovery behavior;
- name the exact Agreement catalog import/provisioning artifact path and owner;
- state the exact `Sources/App/configure.swift` integration assertions while
  preserving that file as an admin-owned collision;
- add positive and negative tests for wrong scope/domain/owner, missing owner,
  duplicate registration and service-singleton substitution.

Until then, the two new Cells are proposed names, not a closed Resolver
composition.

### P1-04 — challenge replay storage is internally contradictory

**Exact Lane B locations**

- lines `307–325` define challenge-issuer responsibilities;
- lines `318–319` allow durable storage of either the issued canonical bytes
  **or** a “required canonical digest set”;
- lines `547–548` later require the issued record plus exact canonical response
  to be durable and read back;
- lines `863–882` do not include a literal identical-intent byte-replay/no
  re-sign test.

**Contradicting interface input**

Lane A lines `546–556` require:

- ledger key = SHA-256 of the complete canonical intent;
- identical unexpired intent returns exact stored challenge bytes;
- same subject/intent nonce with different bytes is rejected;
- replay never re-signs;
- issuer state and replay records survive restart.

Lane A lines `665–670` repeat the exact-byte challenge replay and uniqueness
requirements.

**Impact**

A digest is sufficient to compare bytes but is not sufficient to return the
original signed challenge. Permitting digest-only storage lets an implementer
reconstruct or re-sign a replay, which violates the exact-byte rule and creates
ambiguity across crash, key rotation and time changes. The later transaction
section requires exact bytes, so the packet gives two incompatible
implementation instructions.

**Required correction**

Delete the digest-only alternative. The issuer ledger must store and read back
the exact canonical signed challenge response bytes, keyed and constrained by
the complete canonical intent digest and all Lane A uniqueness keys. Add
explicit tests proving:

- identical unexpired intent returns byte-identical stored bytes;
- the signing function is not invoked on replay;
- same nonce with different intent bytes is rejected;
- restart returns the exact stored bytes;
- issuer rotation never rewrites historical challenge bytes.

### P2-01 — protected-token cryptographic lifecycle and migration tests are not complete

**Exact Lane B locations**

- lines `414–441` define the protected token store and identify existing raw
  `pushToken` persistence as a release blocker;
- `B-DEC-06` and `B-DEC-07`, lines `1001–1002`, defer legacy-row and key-handle
  decisions;
- lines `927–940` test raw-token leakage and transaction failure;
- lines `960–974` test restart/rollback generally;
- lines `746–759` name no dedicated protected-token-store or legacy-migration
  test path.

**Gap**

The test cases do not explicitly cover:

- key handle absent or unavailable;
- wrong or rotated key;
- ciphertext/tag tamper;
- token-vault reference substitution;
- encryption succeeds but registration transaction rolls back;
- registration commits but protected-token read-back fails;
- legacy raw-token row reject/re-enrol/migration behavior;
- proof that no plaintext survives migration failure, backup or diagnostics.

**Impact**

The packet correctly keeps `B-DEC-06` and `B-DEC-07` blocking, so this is not an
authority grant. It is nevertheless incomplete as the future negative-test
packet for a high-sensitivity store.

**Required correction**

After the owners resolve `B-DEC-06` and `B-DEC-07`, an exact successor allowlist
must name the owning test path(s) and enumerate the cases above. No filename,
secret-store API or migration semantic should be guessed before those owner
decisions.

## 5. Reproduced immutable repository facts

### 5.1 Object boundaries

| Boundary | Commit | Tree | Review result |
| --- | --- | --- | --- |
| CellScaffold common base | `8bb7b31b13dad09734c88217cb01b9d48801ff27` | `16ab2d81098c12975776db2b4acefb2ec75d1ff2` | Reproduced upstream basis |
| CellScaffold transport foundation | `38195a233b84d09f66e5ef483800228f857fff2a` | `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` | Reproduced upstream basis |
| CellScaffold route successor | `d2d1b7191d651ad42d172e980ab94a0fd478d07c` | `536531541587b5229b8f325f8935ed11ef85f228` | Reproduced locally |
| Selected Identity source boundary | `c700dbc5699ec3a925165d80bc2ec7ad864a1218` | `211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4` | Reproduced locally; no Identity GO implied |
| CellProtocol v3 basis | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` | `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` | Reproduced locally |

The selected Identity boundary reproduces:

```text
provenance commits from 8bb7b31… to c700dbc… = 123
endpoint-diff paths                           = 192
tracked head-tree entries                     = 1566
git ls-tree -r -z SHA-256                     = b1f11701fbdf07b91824f6a6fbe82cf8ee983be1968bde20f12e035672c33824
```

Identity continuity, recovery, owner control and cutover remain separately
gated.

### 5.2 Selected exact source blobs

At CellScaffold `d2d1b719…`:

| Path | Git blob |
| --- | --- |
| `Sources/App/Controllers/DeviceCallbackCapabilityServer.swift` | `5e85f42ef816c71ff3be11ef5a17abf70ea295a8` |
| `Sources/App/Controllers/VaporDeviceCallback.swift` | `1835c26b94154ec97088f956901bbd7be62c413b` |
| `Sources/App/Support/CanonicalCellRuntimeReadinessStore.swift` | `1c7f1a2fd2fdb694c2bd5d618a803d51f88cb4be` |
| `Sources/App/Cells/ConferenceMVP/Notifications/DeviceRegistrationCell.swift` | `7efc40526f8910c906d65791dd3b20ed84046e35` |
| `Sources/App/Cells/ConferenceMVP/Notifications/DeviceCallbackBridgeCell.swift` | `e3740f47c52a2890c14ad36eebce3ee13a2e1361` |
| `Sources/App/Cells/ConferenceMVP/Notifications/NotificationModels.swift` | `53697e4713291ee90a4181a463bfacb355f546be` |
| `Sources/App/configure.swift` | `ba5973494700a6bba776020d5fbfeadb93bd86e5` |
| `Package.swift` | `ab117c5337e8f8ef6f0f70ef2f79a9625d812870` |
| `Package.resolved` | `c6565bd936f6ba8a8d9154b307943ad687a2a721` |
| `Tests/AppTests/DeviceCallbackCapabilityServerTests.swift` | `4defe2191cb20f77afb913d5dbcd6517c599b85d` |
| `Documentation/DeviceCallbackCapabilityServer.md` | `b9004c4749ea31e0994aae210a40c18f500e6b30` |

At CellProtocol `79ce4f846…`:

| Path | Git blob |
| --- | --- |
| `Sources/CellBase/DeviceIngress/DeviceIngressAdmission.swift` | `093d123e6f97da0f68419980870be25f47e4dc1f` |
| `Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift` | `707b8f7cb2b580eb41c927f2f84df58b45e978aa` |
| `Sources/CellBase/DeviceIngress/DeviceIngressWire.swift` | `06138743faa6df83690a824fe6bf6d2171601749` |
| `Tests/CellBaseTests/DeviceIngressContractTests.swift` | `52e4b54db94a662dbc4d8cd1e48058c9d2c7d648` |
| `Tests/CellBaseTests/DeviceIngressWireFixtureTests.swift` | `f870b2b5472aa0ca4be445394e3c1c27f8ed056f` |

The four v3 fixture blobs are identical in the selected CellProtocol and
CellScaffold objects:

| Fixture | Git blob |
| --- | --- |
| `DeviceIngressChallenge.v3.b64` | `1cd2a2c3f88cdb9e386ce9f20f6991478d385aaf` |
| `DeviceIngressRequest.v3.b64` | `e234d9536351f99d787a5c76e29af4871b0918b3` |
| `DeviceIngressResponse.v3.b64` | `a3a998de1853d47e03364866392bf11b86449f86` |
| `DeviceIngressSignedContract.v3.b64` | `a3de633e5954200b5b6ed3fa1b8570de70ad97ca` |

### 5.3 Current server behavior

The Lane B current-state claims are supported:

- the wrapper schema is `haven.device-callback.transport.v3`;
- fields are exactly `schema`, `canonicalChallenge`, `canonicalRequest`,
  `protectedBody`;
- wrapper maximum is `327680` bytes;
- decoded challenge, request and protected body maxima are `65536` bytes each;
- operations are currently `register`, `resolve`, `submit`;
- the current routes are the exact three Lane B names;
- only register reaches the admission seam;
- challenge, resolve and submit remain unavailable;
- success is raw canonical response bytes with no response wrapper;
- exact Host/public-origin checking and legacy authorization rejection exist;
- no production admission service or challenge issuer is installed;
- the testing composition root is DEBUG-only;
- the current HTTP adapter does not resolve or mutate target Cells directly.

The current challenge route collects only `4kb`. Lane A's author-frozen
challenge carrier proposes a `98304`-byte wrapper and `65536` decoded intent.
Lane B correctly blocks challenge on Lane A, but a later successor packet must
literally bind that route-size change and its test; current source cannot be
treated as compatible.

### 5.4 Current target Cell behavior

The Lane B target-state limits are supported:

- `DeviceRegistrationCell` is persistent and identity-unique;
- `DeviceCallbackBridgeCell` is persistent and scaffold-unique;
- both are resolved at the packet's exact `cell:///` endpoints;
- current grants are `rw--`, not DeviceIngress `rw-s`;
- registration uses `participantId::deviceId` as its local record key;
- `DeviceEndpointRecord` persists optional raw `pushToken`;
- public `asObject()` omits the raw token but exposes its hash;
- registration mutates in-memory state before generic typed-cell persistence;
- callback resolve/submit performs additional cross-Cell calls;
- neither Cell conforms to `DeviceIngressAuthorityCell`;
- neither has same-transaction domain mutation plus exact canonical response.

A generic typed-cell save is not a DeviceIngress admission receipt, atomic
mutation/response receipt or rollback-resistant generation proof.

### 5.5 Current CellProtocol authority path

The selected source establishes:

- `DeviceIngressAuthorityCell` is implemented by the Resolver-selected target
  Cell, never HTTP;
- the selected object reference survives later Resolver mapping replacement;
- authority resolution returns complete signed Agreement evidence without
  mutation;
- admission must commit durably before the target operation;
- the same target Cell atomically rechecks Agreement/revocation generations and
  commits or returns the existing exact response;
- replay must return stored response bytes and never reconstruct or re-sign;
- `DeviceIngressAdmissionService` requires expected audience, pinned issuer,
  Resolver and durable ledger.

Current v3 still contains only register/resolve/submit and hard-codes `rw-s`.
Status/revoke/challenge-intent remain Lane A proposals, not immutable runtime
facts.

## 6. Reproduced Lane B path and owner packet

All paths below are proposals only. The review found every proposed new path
absent from the selected `c700dbc…` tree.

### 6.1 Lane B new source paths

Owner proposed by Lane B: CellScaffold DeviceIngress server owner.

```text
Sources/App/Cells/DeviceIngress/DeviceIngressServerContracts.swift
Sources/App/Cells/DeviceIngress/DeviceIngressChallengeIssuerCell.swift
Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityCatalogCell.swift
Sources/App/Cells/DeviceIngress/DeviceIngressAdmissionLedgerStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressTargetAuthority.swift
Sources/App/Cells/DeviceIngress/DeviceIngressRegistrationMutationStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressProtectedTokenStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressCallbackMutationStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressStatusService.swift
Sources/App/Cells/DeviceIngress/DeviceIngressRevocationService.swift
Sources/App/Cells/DeviceIngress/DeviceIngressCompositionCoordinator.swift
Sources/App/Cells/DeviceIngress/DeviceIngressRuntimeReadiness.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceRegistrationIngressAuthority.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceCallbackBridgeIngressAuthority.swift
Sources/App/Models/DeviceIngressPersistentModels.swift
Sources/App/Migrations/CreateDeviceIngressPersistence.swift
```

### 6.2 Lane B existing source paths

```text
Sources/App/Controllers/DeviceCallbackCapabilityServer.swift
Sources/App/Controllers/VaporDeviceCallback.swift
Sources/App/Support/CanonicalCellRuntimeReadinessStore.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceRegistrationCell.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceCallbackBridgeCell.swift
Sources/App/Cells/ConferenceMVP/Notifications/NotificationModels.swift
```

### 6.3 Lane B tests

New proposed:

```text
Tests/AppTests/DeviceIngressChallengeIssuerCellTests.swift
Tests/AppTests/DeviceIngressAuthorityCatalogCellTests.swift
Tests/AppTests/DeviceIngressAdmissionLedgerStoreTests.swift
Tests/AppTests/DeviceIngressTargetAuthorityTests.swift
Tests/AppTests/DeviceIngressStatusRevocationTests.swift
Tests/AppTests/DeviceIngressRestartReadBackTests.swift
Tests/AppTests/DeviceIngressCompositionCoordinatorTests.swift
Tests/AppTests/DeviceIngressAdversarialTests.swift
Tests/AppTests/DeviceIngressPersistenceMigrationTests.swift
Tests/AppTests/DeviceIngressProductionReadinessTests.swift
```

Existing:

```text
Tests/AppTests/DeviceCallbackCapabilityServerTests.swift
Tests/AppTests/DeviceRegistrationReadinessTests.swift
Tests/AppTests/NotificationRuntimeReadinessTests.swift
Tests/AppTests/Fixtures/DeviceIngressChallenge.v3.b64
Tests/AppTests/Fixtures/DeviceIngressRequest.v3.b64
Tests/AppTests/Fixtures/DeviceIngressResponse.v3.b64
Tests/AppTests/Fixtures/DeviceIngressSignedContract.v3.b64
```

### 6.4 Lane B documentation

```text
Documentation/DeviceCallbackCapabilityServer.md
Documentation/Operations/DeviceIngress_Production_Server_Runbook.md
Documentation/Operations/DeviceIngress_Durable_Admission_Recovery.md
Documentation/Operations/DeviceIngress_Authority_Provisioning.md
```

`Documentation/DeviceCallbackCapabilityServer.md` is not exclusively writable
by Lane B because it collides with the excluded provider WIP.

### 6.5 Development-admin integration paths

Only a later development-admin integrator may reconcile:

```text
Package.swift
Package.resolved
Sources/App/configure.swift
Sources/ScaffoldKit/Application+AuthSecuritySettings.swift
Documentation/Staging_Deployment.md
docker-compose.yml
scripts/cellscaffold-container-controller.py
scripts/test-compose-config-with-placeholders.sh
scripts/tests/test_cellscaffold_container_controller.py
Tests/AppTests/JWTAuthRoutesTests.swift
Tests/AppTests/TopUpCheckoutTests.swift
```

No such integration is authorized.

### 6.6 Provider and Identity no-touch paths

Excluded provider WIP:

```text
Documentation/DeviceCallbackCapabilityServer.md
Sources/App/Cells/ConferenceMVP/Notifications/PushProviderAdapter.swift
Tests/AppTests/NotificationPushProviderTests.swift
```

Tracked provider WIP patch digest:
`a1bcc57a59f9bbcf5f545fc51a43efd13599f36451186981dbc607d0afa80963`.

All 11 dirty Identity paths from S0 section 7.1 remain excluded. Their tracked
patch digest remains
`96bd1aa0ddba65e094f0a713c5a5f95431c79bd0a0915827d1ba008b922a6feb`.

### 6.7 Collision adjudication

The Lane B collision matrix is consistent with S0 for:

- the exact nine Identity-full-tree × transport paths;
- the two transport × route-fix paths;
- the two transport × provider-WIP paths;
- existing target Cell/legacy-state paths;
- shared transport package/controller/fixture integration;
- primary dirty CellScaffold no-touch;
- dirty Identity no-touch;
- deferred seven-path AASA ownership.

Final collision bytes remain development-admin-owned and unavailable.

## 7. Lane A/B/C interface consistency

This table compares literal packet bytes only. It does not approve Lane A or
Lane C.

| Interface | Lane A literal | Lane B use | Lane C literal | Review |
| --- | --- | --- | --- | --- |
| Protected wrapper | `haven.device-callback.transport.v3`; challenge/request/body only | Preserved | Preserved | Consistent |
| Signed Contract | Resolver-selected target Cell evidence; not wrapper | Preserved via authority catalog/target Cell | Preserved | Consistent in principle |
| Success response | raw canonical bytes | Preserved | Preserved | Consistent |
| Status operation | `status`; `readRegistrationStatus`; `device.registration.status`; `r--s` | Blanket `rw-s` | generic test still says `rw-s` | **Contradiction; P1-01** |
| Revoke operation | `revoke`; `revokeDevice`; `device.registration.revoke`; `rw-s` | Deferred to Lane A; server path reserved | Deferred/ambiguous | Compatible while blocked |
| Challenge request | signed `DeviceIngressChallengeIntent`; one-field carrier | Defers exact schema; issuer topology proposed | Defers | Compatible only after successor binding |
| Challenge replay | store and return exact bytes; no re-sign | bytes-or-digest conflict | Client treats bytes as canonical | **Contradiction; P1-04** |
| Status replay | exact replay is historical; new request is fresh | replay stated, freshness distinction incomplete; admission mutation denied | historical/fresh separated | **Contradiction; P1-02** |
| Revoke replay | exact replay no second increment; new already-revoked request may not increment | exact replay no double increment; broader semantics deferred | ambiguous state retained | Compatible while Lane A remains unapproved |
| Audience | `haven.digipomps.org` | `B-DEC-09` keeps decision blocked; production alignment references Lane A | Lane A-frozen audience | Conservative, not contradictory |
| Origin | `https://haven.digipomps.org` | Exact | Exact | Consistent |
| Bundle/topic | `org.digipomps.haven` | Exact planning values | Exact planning values | Consistent; no signing/APNS proof |
| Issuer rotation | `OD-05` open | `B-DEC-01` open; no unproved rotation | Server-owned dependency | Consistent NO-GO |

No Lane A status/revoke schema, fixture, route or rotation semantic becomes
approved through this comparison. Lane B must consume only a later
independently green producer artifact.

## 8. Architecture adjudication

| Review question | Result | Basis |
| --- | --- | --- |
| Is challenge possession authority? | **No — supported** | Lane B lines `327–328`; Resolver/Agreement precheck |
| Is HTTP/Host/origin/topic authority? | **No — supported** | Lane B lines `144–145`, `627–640`, `1023–1032` |
| Is there a static compiled Agreement or admin fallback? | **Forbidden as design** | Lane B lines `277–291`, `627–640` |
| Is no-static-root mechanically closed? | **No — incomplete** | New Cells lack exact Resolver registration/owner tuple; P1-03 |
| Does Resolver select the target? | **Yes as proposal** | Lane B lines `394–412`, `614–625` |
| Does the exact target Cell own final authority/mutation? | **Yes as proposal** | Same locations; current code does not implement it |
| Is complete signed Agreement required? | **Yes as proposal** | Lane B lines `341–355`, `621–640` |
| Are Agreement conditions safely handled? | **Yes, fail-closed** | `agreementConditionsUnsupported` is retained |
| Is admission durable before mutation? | **Yes as proposal** | Lane B lines `365–377`, `545–564` |
| Is exact mutation/response replay required? | **Yes as proposal** | Lane B lines `404–410`, `551–555` |
| Is challenge exact replay unambiguous? | **No** | P1-04 |
| Is status admission/replay correct? | **No** | P1-02 |
| Is status least privilege correct? | **No** | P1-01 |
| Are revoke/tombstone/generation rules closed? | **No — owner-blocked** | Lane A decisions and `B-DEC-02` remain |
| Are persistence/read-back/restart requirements strong? | **Yes as requirements** | Lane B sections 7 and 12.6 |
| Is a production durable backend proven? | **No** | `B-DEC-03`, `B-DEC-04`; no test/runtime evidence |
| Is fail-closed unavailability preserved? | **Yes as plan** | Per-operation readiness and ambiguous-state rules |
| Can transport mutate Cells directly? | **No** | Explicitly forbidden and absent at selected source |
| Is raw token handling production-ready? | **No** | Existing raw row blocker plus `B-DEC-06/07`; P2-01 |

## 9. Persistence, restart and rollback verdict

The Lane B packet correctly requires:

- atomic database transactions;
- unique replay identities;
- admission durability before target operation;
- same-target mutation/result/receipt/response transaction;
- post-commit read-back;
- byte-identical replay;
- process-kill and host-restart recovery;
- bounded non-destructive cleanup;
- migration restart/rollback behavior;
- rollback-resistant external generation anchoring;
- no in-memory fallback;
- fail-closed ambiguous commit.

It correctly refuses to infer those properties from SQLite, Fluent `save()`,
generic Cell persistence, WAL presence or unit tests alone.

No operational durability claim is supported, because:

- backend/version/settings remain `B-DEC-03`;
- rollback anchor remains `B-DEC-04`;
- Agreement provisioning remains `B-DEC-05`;
- token migration/key handle remain `B-DEC-06/07`;
- cross-Cell atomicity remains `B-DEC-08`;
- time and cleanup policy remain `B-DEC-10/11`;
- no build, test, crash injection, restart or restore was run.

The status and challenge defects in P1-02/P1-04 must also be corrected before
the otherwise strong persistence requirements are internally consistent.

## 10. Owner-decision ledger adjudication

`B-DEC-01` through `B-DEC-12` are genuine unresolved inputs and must remain
open. None is silently resolved by this review.

| Decision set | Review |
| --- | --- |
| Issuer identity/rotation manifest (`01`) | Properly blocked; no issuer or rotation proof exists |
| Lane A wire contract (`02`, `09`) | Properly blocked; author-frozen A is not independently green |
| Storage/rollback anchor (`03`, `04`) | Properly blocked; SQLite is not proof |
| Agreement provisioning (`05`) | Properly blocked; exact import/output path still missing |
| Legacy token/key handle (`06`, `07`) | Properly blocked; test coverage needs P2-01 correction |
| Cross-Cell callback atomicity (`08`) | Properly blocked; current target calls several Cells |
| Capacity/time (`10`, `11`) | Properly blocked |
| Final integration object (`12`) | Properly blocked under `MBI-07` |

One additional decision class is missing from the ledger: exact Resolver
registration/scope/persistency/domain/lifecycle and owner bootstrap for the two
new Cells. That omission is P1-03 and must be added rather than inferred.

## 11. Claim adjudication

| Claim | Review result |
| --- | --- |
| The exact Lane B packet bytes were reviewed | **SUPPORTED** |
| Current server is byte-preserving, register-only and fail-closed | **SUPPORTED at `d2d1b…`** |
| Current production issuer/admission/replay/status/revoke services are absent | **SUPPORTED** |
| HTTP remains semantically neutral | **SUPPORTED as plan and current adapter boundary** |
| Resolver/target Cell/owner/Agreement remain authoritative | **SUPPORTED as required topology; unimplemented** |
| No static admission authority is permitted | **SUPPORTED as rule; not closed as configuration because of P1-03** |
| The proposed access contract is per-operation exact | **CONTRADICTED by P1-01** |
| Status has a durable exact-replay transaction | **CONTRADICTED/AMBIGUOUS by P1-02** |
| Challenge exact-byte replay is unambiguous | **CONTRADICTED by P1-04** |
| Persistence/restart/rollback is proven | **UNSUPPORTED; requirements only** |
| The exact future path packet closes all MBI-04 outputs | **CONTRADICTED; Resolver registration and Agreement/config artifacts remain missing** |
| Lane B invents no approved Lane A semantic | **SUPPORTED in intent; interface contradictions must be corrected before consumption** |
| Identity is approved by this packet | **CONTRADICTED** |
| `MBI-06` is available | **CONTRADICTED; unaudited/missing** |
| `MBI-07` exists | **CONTRADICTED; missing** |
| Any source or material next phase is authorized | **CONTRADICTED** |

## 12. MBI and release disposition

| Item | Independent disposition |
| --- | --- |
| `MBI-01` status | Lane A author proposal only; not approved; Lane B conflicts on access and admission semantics |
| `MBI-02` revoke/deregister | Lane A author proposal only; not approved; Lane B remains blocked |
| `MBI-03` challenge framing/rotation | Partial author proposal; issuer rotation open; Lane B challenge replay ambiguous |
| `MBI-04` issuer/admission/replay/Cells/Agreement outputs | **PARTIAL STATIC PROPOSAL / NOT GREEN / OPERATIONALLY MISSING** |
| `MBI-05` Binding outputs | Outside this review; Lane C remains author-frozen partial |
| `MBI-06` Apple signing material | **UNAUDITED / MISSING** |
| `MBI-07` integrated commit/tree/digest | **MISSING** |

Identity remains separate:

- `c700dbc…` is source provenance only;
- this review does not inspect or alter Identity worktree bytes;
- no issuer, target owner or device identity is created;
- no Identity continuity, recovery or cutover claim is upgraded;
- a separately green Identity cutover remains a prerequisite.

Production identifiers remain planning alignment only:

```text
bundle identifier = org.digipomps.haven
APNS topic         = org.digipomps.haven
public origin      = https://haven.digipomps.org
audience proposal  = haven.digipomps.org
```

They do not prove Team ID, App ID capability, profile, certificate, effective
entitlement, codesign authority, archive, APNS acceptance or device receipt.

## 13. Final independent decision

```text
LANE B EXACT-BYTE REVIEW: COMPLETE
P0: 0
P1: 4
P2: 1

LANE B PACKET: NOT GREEN
MBI-04 PLAN: PARTIAL / CORRECTION REQUIRED
MBI-04 OPERATIONAL: MISSING / OPEN
IDENTITY CUTOVER: SEPARATE / NOT APPROVED HERE
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING

SOURCE AUTHORIZATION: NO
PLAN: NO-GO
NEXT PHASE: NO-GO
PRODUCTION: NO-GO
```

The only permissible continuation is a separately authorized correction of the
Lane B planning packet, followed by a new independent exact-byte review. This
review does not open source, Git, dependency, build, test, network, Identity,
signing, portal, device, APNS, staging or deployment work.
