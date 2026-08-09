# APNS S6 Additive Normative Correction

Status: **FROZEN CANDIDATE / STATIC PARTIAL / FORMAL_NO_GO / NO NEXT PHASE**

Date: 2026-07-25  
Composition identifier: `haven.apns.s6.additive-normative-correction.v1`  
Integrator: Ptolemy, sole S6 final-byte owner  
Output count: exactly one new documentation artifact

This is an additive precedence contract. It is not a new monolithic
DeviceIngress contract. It incorporates only claims that survived independent
cross-review, names every rejected author claim, and leaves every unresolved
premise fail-closed.

No source, Git, dependency resolution, build, test execution, network, portal,
signing, device, APNS, secret, Identity, staging, deployment, material,
production, or S7 action is authorized or evidenced.

## 1. Exact immutable inputs

| Input | Exact path | SHA-256 | Lines | Bytes | Status |
|---|---|---|---:|---:|---|
| S5 | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md` | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554 | 93787 | terminal static NO-GO |
| Packet A | `Documentation/APNS_S6_Formal_Proof_Packet_A_Response_Maxima_2026-07-25.md` | `4139ad6f863c8e704357f710235dd47d77b9a949c1cb5a6a557e99bd4a19669f` | 1200 | 39346 | author packet |
| Packet A review | `Documentation/APNS_S6_Formal_Proof_Packet_A_Response_Maxima_Independent_Cross_Review_2026-07-25.md` | `9a8fae81e19d7961d91c12e4052f146a161a418fa3dd38fc91525826775710bd` | 905 | 28228 | `0/1/2`, PARTIAL |
| Packet B | `Documentation/APNS_S6_Formal_Proof_Packet_B_Authority_Head_2026-07-25.md` | `36bccdd94e183cae4aa7a26a0637ce8f71abbb7bf8f17086d175859856a0ffb8` | 1905 | 54641 | author packet |
| Packet B review | `Documentation/APNS_S6_Formal_Proof_Packet_B_Authority_Head_Independent_Cross_Review_2026-07-25.md` | `c4758f47fd86fc175efefabce235341f6c60d2aa3b40bd14d66aa1647af7efc6` | 847 | 29534 | `0/5/2`, NO-GO |
| Packet C | `Documentation/APNS_S6_Formal_Proof_Packet_C_Durability_Client_Vault_2026-07-25.md` | `f929ca08ddc8bcee1727019e9d53022ea99e9dca81d6d9f65aa608556852b225` | 1776 | 63436 | author packet |
| Packet C review | `Documentation/APNS_S6_Formal_Proof_Packet_C_Durability_Client_Vault_Independent_Cross_Review_2026-07-25.md` | `f7ff5cfc229c54c4bf81c08e02bda39dc31b8571c8fa4d553702a0469cb927b0` | 1128 | 33893 | `0/2/3`, NO-GO |

Only these exact bytes are normative inputs. Administrative checkpoints are
coordination evidence only and are not normative contract input.

## 2. Precedence and interpretation

The precedence order is:

1. the accepted-claim and rejected-claim ledgers in this S6 document;
2. each independent packet review for the packet it reviewed;
3. the exact packet section named by an accepted-claim row;
4. terminal S5 for every unchanged positive or unresolved rule; and
5. earlier S3/S4 inputs only through their exact S5 incorporation.

Rules:

- A packet author claim is not accepted merely because it is present.
- A review finding wins over a conflicting packet author claim.
- An accepted narrow construction does not inherit a packet's broader closure
  claim.
- `PARTIAL`, `FORMAL_NO_GO`, `EMPTY`, `UNAVAILABLE`, `BLOCKED`, and `NO-GO`
  are normative states.
- Missing bytes, signer, key, hardware, custody, durability, retention,
  Identity, Apple, or integrated-output evidence never receives a default.
- This document does not repair a review finding. A correction that would
  require new bytes or a semantic choice is a successor input, not S6.

## 3. Preserved composition invariants

These S5 positives remain unchanged:

```text
operations =
  register
  resolve
  submit
  status
  revoke
  deregister

token rotation =
  register with mutationMode=token_rotation

status access = r--s
mutation access = rw-s

transport =
  opaque
  byte-preserving
  semantically neutral
  non-authoritative

APNS token =
  opaque variable-length bytes
  raw length 1...4096 as a HAVEN allocation bound only
```

Raw APNS token bytes and token hashes remain forbidden from documents,
fixtures, manifests, evidence, logs, analytics, diagnostics, crash reports,
exports, UI, and accessibility.

The acyclic signature-envelope order remains:

```text
completed core
-> core digest
-> protected core
-> protected bytes
-> signature
-> signature envelope
-> signed artifact
-> artifact digest
```

No transport wrapper, route, Host, TLS session, process, repository path,
administrator, environment literal, bundle, topic, token possession, local
identifier, boolean, fingerprint, or MAC grants Identity, Agreement, Contract,
Grant, consent, Resolver, Cell, owner, signer, or response authority.

Authoritative server deregistration and the required fresh signed read-back
remain prerequisites to local token and active-binding erasure. Local absence
never proves server deregistration, revocation, deletion, or privacy erasure.

RC2 remains statically closed exactly as inherited:

- U1...U4 precedence;
- stored expiry outcome;
- exact replay bytes;
- no reconstruction or re-signing;
- no new replay sequence; and
- wrong-subject privacy equivalence.

## 4. Deployment literals are premises, not proof

```text
identity domain = domain:device:notification-callback
purpose = purpose://access.audit.privacy/device-notification-callback
origin = https://haven.digipomps.org
bundle = org.digipomps.haven
topic = org.digipomps.haven
environment = production
```

These literals are exact composition premises only. They prove no profile,
Team ID, App ID, signing certificate, effective entitlement, installed build,
device registration, APNS provider acceptance, device receipt, callback,
production readiness, or App Store readiness.

## 5. Accepted-claim manifest

### 5.1 Packet A — response and maxima

| Claim ID | Exact packet section | Independently accepted scope | Excluded scope |
|---|---|---|---|
| `S6-A-ACC-01` | 4.1...4.3 | two-stage challenge-expectation then operation-expectation construction DAG; payloads reference only prior completed bytes | durable store/provider proof |
| `S6-A-ACC-02` | 5.1...6.2 | challenge and operation outer expectation/outcome shapes as structural unions | total error applicability and signer selection |
| `S6-A-ACC-03` | 7 | pre-challenge nullability and post-challenge mandatory request digest | total `(operation,statusKind,phase,errorCode)` mapping |
| `S6-A-ACC-04` | 8.1 | `RegisterReceiptCore v3` exact member order, relations, and 749-byte core maximum | authority/runtime acceptance |
| `S6-A-ACC-05` | 8.2 | `ResolveResultCore v3` exact member order, relations, and 64423-byte core maximum | delivery truth |
| `S6-A-ACC-06` | 8.3 | `SubmitReceiptCore v3` exact member order, relations, and 519-byte core maximum | external receipt truth |
| `S6-A-ACC-07` | 8.4 | `RevokeReceiptCore v3` exact member order, relations, and 417-byte core maximum | authoritative revoke readiness |
| `S6-A-ACC-08` | 8.5 | `DeregisterReceiptCore v3` structural function and acyclic tombstone/result direction | accepted retained-row semantics and incorrect max-1 witness |
| `S6-A-ACC-09` | 9.2...9.3 | parameterized artifact/maxima equations as structural functions | any accepted signature profile |
| `S6-A-ACC-10` | 10.1...10.4 | per-valid-discriminator ResponseCore arithmetic and structural signed/nested equations | accepted signed semantic maxima |
| `S6-A-ACC-11` | 11.1...11.3 | mutual exclusion and forbidden-combination rules | exhaustive executable fixtures |

The accepted expectation DAG is:

```text
body
-> intent
-> ChallengeOutcomeExpectationCore
-> ResponseExpectationUnionCore(challenge_exchange)
-> durable commit/read-back [provider unavailable]
-> challenge send [not authorized]

verified challenge
-> request + deterministic admission ID
-> OperationOutcomeExpectationCore
-> ResponseExpectationUnionCore(operation_exchange)
-> durable commit/read-back [provider unavailable]
-> operation send [not authorized]
```

The five non-status v3 result-schema literals accepted structurally are:

```text
cellprotocol.device-ingress.register-receipt-core.v3
cellprotocol.device-ingress.resolve-result-core.v3
cellprotocol.device-ingress.submit-receipt-core.v3
cellprotocol.device-ingress.revoke-receipt-core.v3
cellprotocol.device-ingress.deregister-receipt-core.v3
```

The accepted valid ResponseCore rows are:

| Operation | Status kind | Result schema |
|---|---|---|
| register | null | register receipt v3 |
| resolve | null | resolve result v3 |
| submit | null | submit receipt v3 |
| status | registration | status result v3 |
| status | admission | status result v3 |
| revoke | null | revoke receipt v3 |
| deregister | null | deregister receipt v3 |

The independently reproduced unsigned/core structural maxima are:

| Row | Exact structural maximum |
|---|---:|
| register result | 749 |
| resolve result | 64423 |
| submit result | 519 |
| revoke result | 417 |
| deregister fresh result function at printed scalar ceiling | 5797 |
| deregister already-retained result function at printed scalar ceiling | 5805 |
| register response | 2103 |
| resolve response | 86999 |
| submit response | 1792 |
| registration status response | 2285 |
| revoke response | 1656 |
| deregister fresh response function | 8838 |
| deregister already-retained response function | 8848 |
| normal signed structural function at printed scalar ceiling | 118913 |
| nested admission structural function at printed scalar ceiling | 287472 |

`118913` and `287472` are conservative structural allocation ceilings under
the printed scalar bounds. They are not accepted semantic signed maxima.

### 5.2 Packet B — authority and current-subject head

Only the following narrow claims survive:

| Claim ID | Exact packet/review locus | Independently accepted scope | Excluded scope |
|---|---|---|---|
| `S6-B-ACC-01` | Packet B 3 plus review 5.1 | immutable binding/consent/catalog construction is acyclic when ordered `M,A,C,G,K -> S -> D? -> B -> N -> Q -> E -> L` | Packet B's printed non-topological order |
| `S6-B-ACC-02` | Packet B 3.3...3.9 plus review 7 | immutable tuple makes requester, target, owner, Agreement, Contract, Grant, Conditions, consent, operation, access, purpose, audience, and signer path substitution visible | current selector construction |
| `S6-B-ACC-03` | Packet B 6.3...6.6 plus review 8 | register/revoke/deregister signed mutation bodies carry exact nested head-expectation bytes and digest | total current-head transition/commit |
| `S6-B-ACC-04` | Packet B 6.4 plus review 8.1 | register binds expected head epoch/generation, lifecycle, registration/revocation generations, registration ID, head-status correlation, and mutation mode | authority/provider/readiness |
| `S6-B-ACC-05` | Packet B 8 plus review 10 | policy deletion, compaction, disclosure, and post-policy-deletion re-enroll remain disabled while privacy input is absent | any retention choice |

The accepted immutable construction DAG is exactly:

```text
M, A, C, G, K
  -> S
  -> D?                  owner signed
  -> B                   owner or exact delegate signed
  -> N                   requester signed
  -> Q
  -> E
  -> L                   owner or exact delegate signed
```

This acyclic immutable DAG does not imply a constructible current-authority
selector, accepted authority, or operational mutation.

### 5.3 Packet C — durability, client, and vault

| Claim ID | Exact packet section | Independently accepted scope | Excluded scope |
|---|---|---|---|
| `S6-C-ACC-01` | 5.2...5.6 | provider-gated fail-red snapshot/watch/name→inode algorithm and crash/race failure branches | successful finite-completeness branch |
| `S6-C-ACC-02` | 6.1...6.7 | six exact journal-extension core schemas, nullability, digest binding, and independently reproduced maxima | enclosing JournalID-bearing journal totality |
| `S6-C-ACC-03` | 7.1...7.4 | stable conflict namespace, resource-family keys, durable leases, and vault transition intent | external provider proof |
| `S6-C-ACC-04` | 8.1, 8.3...8.9 | predecessor/successor expectation, prepared transaction, checkpoint, anchor, marker, and finalization DAG excluding the defective JournalID spelling | a constructible OperationJournalCore until JournalID is fixed |
| `S6-C-ACC-05` | 9.2...9.4 | conservative prepare/anchor/send ordering, append-only markers, and crash failure behavior | stable-store/anchor provider PASS |
| `S6-C-ACC-06` | 10.1...10.2 | idempotent sink capability/receipt and prepared→sink-receipt→finalized ordering | request-byte replay alternative and provider PASS |
| `S6-C-ACC-07` | 11 | server deregister plus fresh signed status before local erase | privacy retention choice |
| `S6-C-ACC-08` | 8.8...8.9, 11.1...11.5 review | RC8 generation DAG is statically acyclic | external copy/rollback/custody proof |
| `S6-C-ACC-09` | 12 and review 12 | restored local copy must equal the provider's current external anchor head; old exact-generation query is insufficient | provider availability |

The independently reproduced journal-extension maxima are:

```text
register token rotation = 509
resolve = 455
submit = 462
status subject-current = 259
status registration-ID = 305
status admission-ID = 237
revoke = 358
deregister = 362
```

The accepted stable conflict families remain:

| Family | Conflicting operations |
|---|---|
| `K_registration` | register, revoke, deregister, status/registration |
| `K_ticket` | resolve and submit for the same ticket family |
| `K_admission` | protected-operation recovery and status/admission |
| `K_domain_transition` | vault namespace/generation transition |

The accepted RC8 edge direction is:

```text
V_0 -> A_0

V_n + A_n
  -> E_t
  -> extension_t
  -> J_t
  -> Prepared_t
  -> V_(n+1)
  -> A_checkpoint
  -> Marker_send
  -> A_send
  -> Marker_outcome
  -> A_outcome
  -> Marker_final
  -> A_final
```

Every accepted edge points only to materialized predecessor bytes. No
checkpoint contains its future anchor; no marker contains its future anchor;
no anchor contains a future marker.

## 6. Rejected, superseded, and non-integrated claims

### 6.1 Superseded narrow S5 defects

| Earlier defect/claim | S6 disposition |
|---|---|
| one same-generation expectation/journal/vault cycle | superseded only by accepted two-stage A expectation DAG and C predecessor/successor RC8 DAG |
| no constructible pre-challenge expectation | superseded by `S6-A-ACC-01` |
| five undefined non-status v3 result cores | superseded structurally by `S6-A-ACC-04...08` |
| maxima formed from mutually exclusive discriminator fields | superseded by per-valid-row arithmetic in `S6-A-ACC-10` |
| immutable binding/consent/catalog digest cycle | superseded only by `S6-B-ACC-01` immutable DAG |
| signed mutation body omitted expected subject-head generation/epoch | superseded narrowly by `S6-B-ACC-03...04` |
| rolling checkpoint proof used in conflict-family identity | superseded by stable namespace/key construction in `S6-C-ACC-03` |
| same-generation E/J/V digest cycle | superseded statically by `S6-C-ACC-08` |

No superseded defect grants runtime closure.

### 6.2 Packet A claims rejected or narrowed by review

```text
REJECT:
  RC1 overall CLOSED
  total result/error/evidence verifier
  every terminal error code reachable in every phase
  ambiguous "expectation-selected historical signer"
  accepted signed semantic maxima
  fixture/applicability completeness
  deregister max-1 witness that changes only outer registrationGeneration

PRESERVE:
  RC1 = PARTIAL
  RC5 = PARTIAL
  signed maxima = FORMAL_NO_GO
  SignatureEncodingProfile accepted set = EMPTY
```

The unresolved total function is:

```text
(operation, statusKind, phase, errorCode)
-> exact allowed/rejected decision
-> exact signer role/descriptor/key/algorithm
-> exact retryClass
-> exact terminality
-> exact stored-historical-vs-new-readback behavior
```

No S6 default fills this function.

### 6.3 Packet B claims rejected or narrowed by review

```text
REJECT:
  RC3 CLOSED
  RC4 CLOSED
  Packet B's printed construction order
  constructible catalog-entry current selector
  internally consistent generic authority revoke
  byte-total CurrentSubjectHead/CAS
  atomic local commit plus external rollback activation
  retryClass="terminal" for target_unavailable
  fixture/path completeness

PRESERVE:
  RC3 = PARTIAL / FORMAL_NO_GO
  RC4 = PARTIAL / FORMAL_NO_GO
  AcceptedAuthority = EMPTY
  operational readiness = UNAVAILABLE
```

Exact open defects:

1. `AuthorizationCatalogEntryCore v3` has no total artifact-ref signer,
   owner, generation, revocation, inclusion, and current-selector projection.
2. Revoke retains an old artifact ref while incrementing head and revocation
   generations, violating the packet's own equality.
3. `lastDisclosableTombstoneSHA256` has no byte-total nullability/lifecycle/CAS
   projection and cannot be populated without choosing retention.
4. Local mutation visibility and external rollback-anchor success are not one
   atomic prepared→anchored→active boundary.
5. `target_unavailable` retains S5's exact
   `retryClass=after_authority_recovery`, `terminality=terminal`; Packet B's
   `retryClass=terminal` is rejected.

### 6.4 Packet C claims rejected or narrowed by review

```text
REJECT:
  RC6 CLOSED
  RC7 CLOSED
  successful finite inventory completeness without a manifest core
  JournalID simultaneously 47 and 48 bytes
  request-byte replay after restart without a persisted request-byte object
  fixture/applicability completeness
  Packet C's S5 Lane A count 0/5/2

PRESERVE:
  RC6 = PARTIAL / FORMAL_NO_GO
  RC7 = PARTIAL / FORMAL_NO_GO
  RC8 = CLOSED FOR STATIC DAG / EXTERNAL FORMAL_NO_GO
  actual S5 Lane A count = 0/4/2
```

RC6's missing successful-branch bytes include:

- exact `LegacyEnumerationManifestCore`;
- exact entry core and sorted/deduplicated ordering;
- root/snapshot/watermark/artifact/inventory-row binding;
- per-root and global counts;
- global count not exceeding `maximumEntriesPerScope`;
- one exact start/end watermark relation; and
- atomic manifest/rows/fence read-back equality.

RC7's `JournalID` remains impossible:

```text
len("jr1_") = 4
len(Base64url43) = 43
4 + 43 = 47
packet-declared total = 48
```

S6 selects neither a new prefix nor a new total.

## 7. Typed blocker ledger

| Blocker | Exact missing bound input | Current state | Affected roots |
|---|---|---|---|
| `S6-BLOCK-RC1-TOTAL-01` | total code×operation×phase×signer/readback selection bytes | MISSING | RC1 |
| `S6-BLOCK-SIGNATURE-PROFILE-01` | accepted exact algorithm token, key-ID encoding, raw-signature encoding/length, signer/key binding, fixture bytes | EMPTY / UNAVAILABLE | RC5 |
| `S6-BLOCK-AUTH-E-SELECTOR-01` | constructible catalog-entry current ref/selector/revocation projection | MISSING | RC3 |
| `S6-BLOCK-AUTH-REVOKE-01` | internally consistent ref/head generation transition | MISSING | RC3 |
| `S6-BLOCK-HEAD-PROJECTION-01` | retention-independent exact CurrentSubjectHead↔expectation CAS projection | MISSING | RC4 |
| `S6-BLOCK-ANCHOR-ACTIVATION-01` | prepared→externally anchored→active atomicity/recovery contract | MISSING; accepted provider sets EMPTY | RC3/RC4 |
| `S6-BLOCK-RC6-MANIFEST-01` | exact finite enumeration manifest/count/watermark/row binding | MISSING | RC6 |
| `S6-BLOCK-RC7-JOURNAL-ID-01` | one versioned JournalID spelling/length/collision rule | MISSING | RC7 |
| `S6-BLOCK-REQUEST-RECOVERY-01` | exact protected request-byte store or removal of request-replay alternative | MISSING; safe status-only path remains | RC7 P2 |
| `S6-BLOCK-IDENTITY-01` | accepted domain Identity, owner, signer, delegation, Agreement, Contract, Grant, Conditions, consent, Resolver/Cell authority bytes | EMPTY / separate cutover | RC1/RC3/RC4 |
| `S6-BLOCK-DURABILITY-01` | accepted stable-store, rollback-anchor, discovery, custody, recovery, hardware, and sink providers/proofs | all accepted sets EMPTY | RC6/RC7/RC8 |
| `MBI-PRIVACY-RETENTION-01` | Kjetil's legitimate-purpose, retention duration, disclosure, backup, compaction, deletion, and user-wording decision | OPEN / UNAVAILABLE | RC4 and retained deregister rows |
| `MBI-TRANSPORT-FRAMING-01` | exact outer framing/TLS/redirect/rotation transport proof | MISSING | transport composition |
| `MBI-06` | Apple Team/App ID/profile/certificate/effective production entitlement/archive proof | MISSING / UNAUDITED | production signing |
| `MBI-07` | exact integrated repo/dependency/compiler-input/fixture/artifact output | MISSING | integrated output |

No blocker can be filled with a guessed value, test key, local identifier,
path, route, environment variable, repository owner, administrator, or
self-signed capability.

## 8. External accepted sets

The following remain exactly empty:

```text
accepted Identity/authority catalogs and signers
accepted response signers
accepted SignatureEncodingProfiles
accepted trusted-time providers
accepted legacy discovery providers/fences/custody proofs
accepted migration/deactivation/disposal/backup procedures
accepted local durability providers
accepted non-exportable-key proofs
accepted copy-resistance proofs
accepted rollback-anchor providers/receipts
accepted custody/recovery proofs
accepted hardware attestations
accepted idempotent sink capabilities/receipts
accepted Apple production signing/profile/entitlement proofs
accepted integrated-output proofs
```

Therefore:

```text
AcceptedAuthority = EMPTY
Binding protected-operation readiness = UNAVAILABLE
CellScaffold authority/head readiness = UNAVAILABLE
legacy/provider delivery readiness = UNAVAILABLE
resolve delivery readiness = UNAVAILABLE
hardware PASS = NONE
copy-resistance PASS = NONE
rollback-resistance PASS = NONE
delivered-once PASS = NONE
production PASS = NONE
```

## 9. Repo-qualified one-owner/no-touch/collision ledger

All paths in this section are planning paths. None is created, edited, staged,
or authorized by S6.

`repo://CellProtocol`, `repo://CellScaffold`, and `repo://Binding` are distinct
repository roots.

### 9.1 Package, project, configuration, and Apple collision rows

| Exact path | Sole final-byte owner | Required input/review | S6 disposition |
|---|---|---|---|
| `repo://CellProtocol/Package.swift` | CellProtocol development admin | Packet A/C contract owner plus package reviewer | no-touch; package membership not authorized |
| `repo://Binding/Binding.xcodeproj/project.pbxproj` | Binding development admin | Binding lane plus Apple release reviewer | no-touch; project membership not authorized |
| `repo://Binding/Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Binding development admin | dependency owner and reviewer | no-touch; dependency selection absent |
| `repo://Binding/Binding/Binding-iOS.entitlements` | Apple release owner | Apple signing reviewer | immutable/no-touch |
| `repo://CellScaffold/Configuration/DeviceIngress/authority-input.v1.schema.json` | CellScaffold authority/config owner | Identity/authority owner | no-touch; authority EMPTY |
| `repo://CellScaffold/Configuration/DeviceIngress/persistence-input.v1.schema.json` | CellScaffold storage/config owner | durability/discovery owner | no-touch; providers EMPTY |
| `repo://CellScaffold/Sources/App/Configuration/DeviceIngress/DeviceIngressAuthorityInputConfiguration.swift` | CellScaffold authority/config owner | Identity/authority owner | no-touch |
| `repo://CellScaffold/Sources/App/Configuration/DeviceIngress/DeviceIngressPersistenceConfiguration.swift` | CellScaffold storage/config owner | durability/discovery owner | no-touch |
| `repo://CellScaffold/Sources/App/Configuration/DeviceIngress/DeviceIngressReadinessConfiguration.swift` | CellScaffold readiness owner | all lane readiness owners | no-touch; readiness unavailable |

No two roles may write the same final path. A required reviewer is not a
co-owner.

### 9.2 CellProtocol contract, transport, tool, test, fixture, and docs paths

Sole final-byte owner for every row below: CellProtocol producer owner.

```text
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressSignedOutcome.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressOutcomeExpectationContract.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressChallengeReplayContract.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressSubjectTargetBinding.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressAuthorizationCatalog.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressRegistrationHeadContract.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressMaximaContract.swift
repo://CellProtocol/Sources/CellDeviceIngressTransport/DeviceIngressOpaqueTransport.swift
repo://CellProtocol/Tools/DeviceIngress/device_ingress_maxima_v3.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressSignedOutcomeTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressChallengeReplayTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressSubjectTargetBindingTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressRegistrationHeadContractTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressMaximaV3Tests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressS6AResponseMaximaTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressPacketCLegacyContractTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressPacketCDurabilityContractTests.swift
repo://CellProtocol/Tests/CellDeviceIngressTransportTests/DeviceIngressOpaqueTransportTests.swift
repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/manifest.v3.json
repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/consumer-applicability.v3.json
repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/s6a-response-maxima-manifest.v1.json
repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionS6PacketC/
repo://CellProtocol/Docs/DeviceIngressNormativeCompositionV3.md
```

Collision rules:

- the two fixture roots are disjoint;
- shared `DeviceIngressCompositionV3` manifests have one producer owner;
- transport bytes remain opaque and cannot reinterpret an accepted core;
- Packet B supplied no repo-qualified producer/test/fixture path contract, so
  no new Packet-B-only path is invented here.

### 9.3 CellScaffold provider, procedure, Cell, test, fixture, and docs paths

| Exact path | Sole final-byte owner | Included responsibility | S6 disposition |
|---|---|---|---|
| `repo://CellScaffold/Sources/App/Providers/DeviceIngress/DeviceIngressTrustedTimeProvider.swift` | trusted-time provider owner | typed provider interface | no-touch; accepted set EMPTY |
| `repo://CellScaffold/Sources/App/Providers/DeviceIngress/DeviceIngressRollbackAnchorProvider.swift` | rollback-anchor provider owner | typed provider interface | no-touch; accepted set EMPTY |
| `repo://CellScaffold/Sources/App/Providers/DeviceIngress/DeviceIngressSealedTokenKeyProvider.swift` | sealed-token key-provider owner | typed provider interface | no-touch; accepted set EMPTY |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacyArtifactDiscoveryProcedure.swift` | legacy discovery owner | RC6 failure-branch consumer | no-touch; success branch blocked |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacySealedMigrationProcedure.swift` | sealed migration owner | legacy quarantine/migration | no-touch; procedure EMPTY |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacyDeactivationProcedure.swift` | deactivation owner | fail-closed deactivation | no-touch; procedure EMPTY |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacyDisposalEvidenceProcedure.swift` | disposal evidence owner | disposal evidence interface | no-touch; procedure EMPTY |
| `repo://CellScaffold/Sources/App/Cells/DeviceIngress/DeviceIngressLegacyInventoryStore.swift` | inventory/adjudication owner | RC6 inventory transaction | no-touch; manifest binding missing |
| `repo://CellScaffold/Tests/AppTests/DeviceIngressOutcomeUnionConsumerTests.swift` | server outcome-test owner | inherited S5 outcome rows | no-touch |
| `repo://CellScaffold/Tests/AppTests/DeviceIngressCurrentSubjectHeadTests.swift` | head/CAS test owner | accepted signed-body shape; open transition defects | no-touch |
| `repo://CellScaffold/Tests/AppTests/DeviceIngressS6AResponseProducerTests.swift` | Packet A server-test owner | A structural rows | no-touch |
| `repo://CellScaffold/Tests/AppTests/DeviceIngressLegacyDiscoveryFenceTests.swift` | RC6 server-test owner | C legacy rows | no-touch |
| `repo://CellScaffold/Tests/AppTests/Fixtures/DeviceIngressCompositionV3/server-consumption.v3.json` | server fixture-ledger owner | byte-identical consumer mapping | no-touch; MBI-07 |

Packet B's independently confirmed P2 path gap remains:

```text
exact authority/head producer source paths = MISSING
exact Packet B fixture producer root = MISSING
exact Packet B consumer test paths = MISSING
```

This document does not invent those paths.

### 9.4 Binding source, test, fixture, docs, and Apple no-touch paths

Sole final-byte owner for DeviceIngress source/test rows: Binding client owner.

```text
repo://Binding/Binding/DeviceIngress/DeviceIngressSignedOutcomeVerifier.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressResponseExpectation.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressOperationJournal.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressJournalExtensions.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressConflictLocks.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressStableStore.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressClientReducer.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressResolveDeliveryHandoff.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressDeregisterLocalCleanup.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressVaultContinuity.swift
repo://Binding/BindingTests/DeviceIngressSignedOutcomeVerifierTests.swift
repo://Binding/BindingTests/DeviceIngressResponseExpectationTests.swift
repo://Binding/BindingTests/DeviceIngressOperationJournalTests.swift
repo://Binding/BindingTests/DeviceIngressConflictLockSubprocessTests.swift
repo://Binding/BindingTests/DeviceIngressStableStoreCrashTests.swift
repo://Binding/BindingTests/DeviceIngressClientReducerTests.swift
repo://Binding/BindingTests/DeviceIngressResolveDeliveryHandoffTests.swift
repo://Binding/BindingTests/DeviceIngressDeregisterLocalCleanupTests.swift
repo://Binding/BindingTests/DeviceIngressVaultContinuityTests.swift
repo://Binding/BindingTests/DeviceIngressS6AExpectationConsumerTests.swift
repo://Binding/BindingTests/DeviceIngressJournalExtensionV2Tests.swift
repo://Binding/BindingTests/DeviceIngressStableConflictNamespaceTests.swift
repo://Binding/BindingTests/DeviceIngressVaultCheckpointDAGTests.swift
repo://Binding/BindingTests/DeviceIngressStableTransactionCrashTests.swift
repo://Binding/BindingTests/DeviceIngressResolveSinkHandoffTests.swift
repo://Binding/BindingTests/DeviceIngressVaultContinuityV2Tests.swift
repo://Binding/BindingTests/Support/DeviceIngressMaximaV3Independent.swift
repo://Binding/BindingTests/Fixtures/DeviceIngressCompositionV3/client-consumption.v3.json
repo://Binding/Documentation/DeviceIngress_Client_Recovery_V3.md
```

Apple-release rows have the sole final-byte owner `Apple release owner` and
are immutable/no-touch:

```text
repo://Binding/Documentation/AppleReleaseM0Policy.template.json
repo://Binding/Documentation/AppleReleaseM0Preflight.md
repo://Binding/Scripts/apple_release_m0_preflight.py
repo://Binding/Scripts/apple_release_m0_preflight.sh
repo://Binding/Tests/apple_release_m0_preflight_tests.py
repo://Binding/Tests/fixtures/apple_release_m0_preflight/facts-dirty.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/facts-pass.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/policy-mismatch.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/policy-pass.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/policy-pending.json
```

## 10. Canonical fixture-to-consumer applicability ledger

No fixture file exists or receives executable PASS from S6. This section
integrates planning rows only and distinguishes reviewed structure from
missing bytes.

Applicability symbols:

```text
REQ = consumer is required at the exact listed test path
N/A-SERVER = server-only legacy discovery
N/A-CLIENT = client-only local durability
N/A-PRODUCER = producer-only canonicalization
BLOCKED = exact path/bytes/applicability missing or review-invalid
```

### 10.1 Exact consumer aliases

| Alias | Exact consumer |
|---|---|
| `A-S6A` | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressS6AResponseMaximaTests.swift::fixture_<ID>` |
| `B-S6A` | `repo://CellScaffold/Tests/AppTests/DeviceIngressS6AResponseProducerTests.swift::fixture_<ID>` |
| `C-S6A` | `repo://Binding/BindingTests/DeviceIngressS6AExpectationConsumerTests.swift::fixture_<ID>` |
| `A-C6` | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressPacketCLegacyContractTests.swift::fixture_<ID>` |
| `A-C78` | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressPacketCDurabilityContractTests.swift::fixture_<ID>` |
| `B-C6` | `repo://CellScaffold/Tests/AppTests/DeviceIngressLegacyDiscoveryFenceTests.swift::fixture_<ID>` |
| `C-EXT` | `repo://Binding/BindingTests/DeviceIngressJournalExtensionV2Tests.swift::fixture_<ID>` |
| `C-LOCK` | `repo://Binding/BindingTests/DeviceIngressStableConflictNamespaceTests.swift::fixture_<ID>` |
| `C-DAG` | `repo://Binding/BindingTests/DeviceIngressVaultCheckpointDAGTests.swift::fixture_<ID>` |
| `C-STORE` | `repo://Binding/BindingTests/DeviceIngressStableTransactionCrashTests.swift::fixture_<ID>` |
| `C-RED` | `repo://Binding/BindingTests/DeviceIngressClientReducerTests.swift::fixture_<ID>` |
| `C-SINK` | `repo://Binding/BindingTests/DeviceIngressResolveSinkHandoffTests.swift::fixture_<ID>` |
| `C-VAULT` | `repo://Binding/BindingTests/DeviceIngressVaultContinuityV2Tests.swift::fixture_<ID>` |

### 10.2 Packet A logical rows

Producer manifest planning path:

`repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/s6a-response-maxima-manifest.v1.json`

Packet A gives no exact per-fixture filename, hash, line/byte shape, or
applicability-core bytes. Therefore every row below is integrated as a logical
test requirement but has `Fixture bytes = BLOCKED_MBI_07`.

| ID/group | Required behavior | Producer | A | B | C | Review disposition |
|---|---|---|---|---|---|---|
| `S6A-E001` | challenge expectation canonical | manifest row missing | A-S6A | N/A-PRODUCER | C-S6A | structural positive |
| `S6A-E002` | challenge success exact intent/issuer | manifest row missing | A-S6A | B-S6A | C-S6A | authority blocked |
| `S6A-E003` | pre-challenge authenticated error | manifest row missing | A-S6A | B-S6A | C-S6A | total code matrix blocked |
| `S6A-E004` | future challenge digest in expectation | manifest row missing | A-S6A | N/A-PRODUCER | C-S6A | negative |
| `S6A-E005` | operation expectation after request | manifest row missing | A-S6A | N/A-PRODUCER | C-S6A | structural positive |
| `S6A-E006` | missing request/admission | manifest row missing | A-S6A | N/A-PRODUCER | C-S6A | negative |
| `S6A-E007` | self/future-vault/journal digest | manifest row missing | A-S6A | N/A-PRODUCER | C-S6A | negative |
| `S6A-E008` | post-challenge error exact request digest | manifest row missing | A-S6A | B-S6A | C-S6A | structure positive, matrix blocked |
| `S6A-E009` | post-challenge error null request digest | manifest row missing | A-S6A | B-S6A | C-S6A | negative |
| `S6A-E010` | pre-challenge error has request/admission/target | manifest row missing | A-S6A | B-S6A | C-S6A | negative |
| `S6A-E011` | non-success promoted to success/current | manifest row missing | A-S6A | B-S6A | C-S6A | negative |
| `S6A-R001` | register 748/749/750 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-R002` | resolve 64422/64423/64424 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-R003` | submit 518/519/520 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-R004` | revoke 416/417/418 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-R005` | deregister fresh boundary | manifest row missing | A-S6A | B-S6A | C-S6A | BLOCKED: invalid stated max-1 witness |
| `S6A-R006` | deregister retained boundary | manifest row missing | A-S6A | B-S6A | C-S6A | BLOCKED: privacy plus invalid stated max-1 witness |
| `S6A-R007` | cross-operation result substitution | manifest row missing | A-S6A | B-S6A | C-S6A | negative |
| `S6A-R008` | replay creates new disposition | manifest row missing | A-S6A | B-S6A | C-S6A | negative |
| `S6A-M001` | register response 2102/2103/2104 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-M002` | resolve response 86998/86999/87000 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-M003` | submit response 1791/1792/1793 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-M004` | registration status 2284/2285/2286 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-M005` | revoke response 1655/1656/1657 | manifest row missing | A-S6A | B-S6A | C-S6A | arithmetic positive/boundary |
| `S6A-M006` | deregister response function | manifest row missing | A-S6A | B-S6A | C-S6A | signature/privacy blocked |
| `S6A-M007` | normal signed outcome function | manifest row missing | A-S6A | B-S6A | C-S6A | BLOCKED_SIGNATURE_PROFILE |
| `S6A-M008` | nested admission function | manifest row missing | A-S6A | B-S6A | C-S6A | BLOCKED_SIGNATURE_PROFILE |
| `S6A-M009` | impossible S5 mixed discriminator tuple | manifest row missing | A-S6A | B-S6A | C-S6A | negative |
| `S6A-M010` | raw signature length 1025 | manifest row missing | A-S6A | B-S6A | C-S6A | structural negative; profile still empty |
| `S6A-M011` | nested status-of-status | manifest row missing | A-S6A | B-S6A | C-S6A | negative |

Missing Packet A rows are explicitly `BLOCKED`, not implied:

```text
every reachable AuthenticatedError phase
total code×operation×phase×signer matrix and excluded cross-products
operation_pending valid and invalid phases
both terminal-evidence codes and reason applicability
stored historical readback versus newly signed readback
AuthenticatedError max-1/max/max+1
AdmissionTerminalEvidence max-1/max/max+1
protected/envelope/artifact profile boundaries
nested admission max-1/max/max+1
nested authenticated-error and terminal-evidence outcomes
all status/admission discriminator rows
tombstone core/artifact/digest mismatch and nested equality
variable/fixed signature profile rejection
```

Packet A fixture coverage is **PARTIAL / BLOCKED**, never complete.

### 10.3 Packet B vector applicability

Packet B names 83 unique logical vectors:

```text
B-RC3 = 46
B-RC4 = 32
B-PRIV = 5
```

It supplies no canonical producer root, filename, bytes/hash/shape, expected
typed decision/reason, A/B/C applicability core, consumer test ID, or
repo-qualified producer/consumer path.

Therefore:

```text
all 83 Packet B vectors = BLOCKED_NO_FIXTURE_CONTRACT
integrated Packet B fixture count = 0
Packet B fixture completeness claim = NONE
```

No path or applicability is invented.

### 10.4 Packet C exact planning rows

Producer root:

`repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionS6PacketC/`

The packet's exact filenames and routing are preserved below. Actual fixture
bytes/hashes/shapes remain `BLOCKED_MBI_07`.

| IDs | Exact relative fixtures | Expected | A | B | C | Status |
|---|---|---|---|---|---|---|
| `S6C001...004` | `legacy/watch-before-snapshot-create.json`; `legacy/rename-between-name-and-open.json`; `legacy/replace-after-open.json`; `legacy/hardlink-and-fifo.json` | rescan/reject gate red | A-C6 | B-C6 | N/A-SERVER | structural negatives |
| `S6C005...008` | `legacy/event-journal-overflow.json`; `legacy/root-replaced-before-commit.json`; `legacy/create-after-commit-before-ack.json`; `legacy/event-after-ack.json` | unavailable/reject/abort/invalidate | A-C6 | B-C6 | N/A-SERVER | structural negatives |
| `S6C009` | `legacy/missing-provider-capability.json` | unavailable | A-C6 | B-C6 | **BLOCKED** | Packet C used wrong N/A reason; correct path remains unreviewed |
| `S6C010...015` | `extension/register-first-enroll.json`; `extension/register-enroll-after-deregister.json`; `extension/register-update.json`; `extension/register-reactivate.json`; `extension/register-token-rotation.max-509.json`; `extension/register-invalid-nullability.json` | accept except invalid-nullability reject | A-C78 | N/A-CLIENT | C-EXT | structural positive/boundary/negative |
| `S6C016...024` | `extension/resolve.max-455.json`; `extension/submit.max-462.json`; `extension/status-subject-current.max-259.json`; `extension/status-registration-id.max-305.json`; `extension/status-admission-id.max-237.json`; `extension/status-cross-selector-field.json`; `extension/revoke.max-358.json`; `extension/deregister.max-362.json`; `extension/wrong-schema-operation-digest.json` | exact maxima accepts; cross-field/schema negatives reject | A-C78 | N/A-CLIENT | C-EXT | structural positive/boundary/negative |
| `S6C025...028` | `lock/register-revoke-deregister-race.json`; `lock/resolve-submit-race.json`; `lock/status-recovery-across-checkpoint-generation.json`; `lock/vault-transition-with-pending-lease.json` | serialize/recover/reject transition | A-C78 | N/A-CLIENT | C-LOCK | structural positive/negative |
| `S6C029...034` | `dag/genesis-checkpoint-anchor.json`; `dag/predecessor-operation-successor-anchor.json`; `dag/same-generation-self-reference.json`; `dag/wrong-predecessor-root.json`; `dag/wrong-anchor-artifact-kind-or-digest.json`; `dag/generation-gap-overflow.json` | first two structure accepted/provider unavailable; rest reject | A-C78 | N/A-CLIENT | C-DAG | RC8 structure |
| `S6C035...038` | `store/crash-before-local-commit.json`; `store/crash-after-local-before-anchor.json`; `store/checkpoint-anchor-external-before-local-receipt.json`; `store/send-marker-anchored-before-transport.json` | no-send/recovery/status recovery | A-C78 | N/A-CLIENT | C-STORE | provider-blocked crash rows |
| `S6C039...040` | `reducer/local-evidence-absent-status-only.json`; `reducer/invalid-vault-no-status.json` | status-only/unavailable | A-C78 | N/A-CLIENT | C-RED | fail-closed reducer rows |
| `S6C041...044` | `sink/prepared-marker-local-not-anchored.json`; `sink/accept-before-receipt-marker-anchor.json`; `sink/wrong-delivery-or-result.json`; `sink/missing-provider.json` | no invoke/exact replay/reject/unavailable | A-C78 | N/A-CLIENT | C-SINK | provider-blocked sink rows |
| `S6C045...048` | `vault/copied-id-boolean-mac-key.json`; `vault/nonexportable-without-rollback.json`; `vault/rollback-without-copy-custody.json`; `vault/missing-hardware-custody-store-proof.json` | unavailable | A-C78 | N/A-CLIENT | C-VAULT | external proof sets EMPTY |
| `S6C049...052` | `dag/journal-rewrite-after-checkpoint.json`; `dag/finalization-marker-rewrite-after-anchor.json`; `dag/delivery-marker-rewrite-after-anchor.json`; `dag/marker-anchor-same-generation-cycle.json` | reject | A-C78 | N/A-CLIENT | C-DAG | RC8 negatives |

Missing Packet C rows are explicitly `BLOCKED`:

```text
manifest entry omitted
manifest entry extra
manifest entry duplicate
observation count differs from manifest rows
committed inventory row differs from manifest entry
cross-root total exceeds maximumEntriesPerScope
unequal scope start watermarks
JournalID 47-vs-48 contradiction and boundary spellings
restored local copy behind provider current head
old exact-generation query without current-head equality
undefined persisted resolve-request replay
```

Packet C fixture coverage is **PARTIAL / BLOCKED**, never complete.

### 10.5 Integrated fixture completeness result

```text
Packet A logical rows routed = 30
Packet A exact fixture bytes = 0
Packet A missing/invalidated coverage families = OPEN

Packet B logical vector names = 83
Packet B integrated fixture rows = 0
Packet B producer/consumer applicability = MISSING

Packet C planning rows routed = 52
Packet C actual fixture bytes = 0
Packet C row S6C009 = BLOCKED
Packet C missing adversarial rows = OPEN

fixture bytes with SHA/shape = 0
executable PASS = 0
fixture ledger completeness = NO
MBI-07 = MISSING
```

## 11. Consolidated root and finding tally

### 11.1 RC1...RC8

| Root | S6 result | Exact residual |
|---|---|---|
| RC1 | **PARTIAL** | expectation DAG and five result cores accepted; total error/outcome/signer/readback function missing |
| RC2 | **CLOSED STATIC / unchanged** | no runtime evidence |
| RC3 | **PARTIAL / FORMAL_NO_GO** | E selector, revoke ref/head consistency, activation atomicity, authority EMPTY |
| RC4 | **PARTIAL / FORMAL_NO_GO** | current-head projection, retention parameter, activation atomicity, RC1 result/status dependency |
| RC5 | **PARTIAL / FORMAL_NO_GO** | core arithmetic closed; accepted signature profile EMPTY; fixtures partial |
| RC6 | **PARTIAL / FORMAL_NO_GO** | failure branches strong; canonical finite manifest/count/watermark/row binding missing; provider EMPTY |
| RC7 | **PARTIAL / FORMAL_NO_GO** | extensions/conflict/marker structure strong; JournalID impossible; request recovery imprecise; providers EMPTY |
| RC8 | **CLOSED FOR STATIC DAG / EXTERNAL FORMAL_NO_GO** | current external head mandatory; hardware/key/copy/rollback/custody/store/sink sets EMPTY |

### 11.2 Review-heading counts and consolidation

Exact inherited independent review headings:

```text
Packet A = P0/P1/P2 0/1/2
Packet B = P0/P1/P2 0/5/2
Packet C = P0/P1/P2 0/2/3

raw inherited headings = 0/8/7
new S6 integrator findings = 0/0/0
```

Consolidated unique P1 root causes:

1. incomplete RC1 code×operation×phase×signer/readback selection;
2. unconstructible catalog-entry current selector;
3. authority revoke ref/head generation mismatch;
4. retention-dependent current-head field outside signed CAS projection;
5. non-atomic local mutation/external anchor activation;
6. frozen error retry mapping violation;
7. missing RC6 manifest/count/watermark/inventory binding; and
8. impossible 47-vs-48 JournalID.

Consolidated unique P2 root causes:

1. Packet A deregister boundary witness precision;
2. cross-packet fixture/applicability/path completeness;
3. Packet B construction-order/explicit-byte-edge precision;
4. Packet C bound-review count provenance; and
5. Packet C undefined persisted resolve-request replay alternative.

Thus:

```text
consolidated unique P0/P1/P2 root causes = 0/8/5
```

This consolidation does not erase any of the seven exact P2 review headings.

## 12. Privacy, Identity, Apple, and integrated-output boundaries

`MBI-PRIVACY-RETENTION-01` remains a human owner decision for Kjetil.
S6 selects no:

- retention duration;
- permanent registration ID or tombstone;
- disclosure window;
- legitimate purpose;
- backup/restore policy;
- compaction or deletion period;
- revoke-retained ciphertext rule; or
- user-facing wording.

Until that input exists:

```text
policy deletion = DISABLED
policy deletion proof accepted set = EMPTY
post-policy-deletion re-enroll = UNAVAILABLE
tombstone/history compaction = DISABLED
privacy-erasure claim = NONE
```

Identity cutover remains separate, open, and NO-GO. S6 does not mutate or
compose Identity.

`MBI-06` remains missing/unaudited. No Apple profile, Team ID, App ID,
certificate, effective `aps-environment=production` entitlement, archive,
export, notarization, upload, or App Store proof exists here.

`MBI-07` remains missing. No source tree, dependency graph, compiler-input
manifest, generated/ignored source ledger, codesign authority, fixture bytes,
binary artifact, or integrated output is attested.

## 13. Operative stop table

| Gate | State |
|---|---|
| S6 static composition | **PARTIAL / FORMAL_NO_GO** |
| S6 independent lane review | required next, not self-awarded |
| S7 | **NOT AUTHORIZED** |
| source | **NO-GO** |
| Git/stage/commit/push/merge | **NO-GO** |
| dependency resolution | **NO-GO** |
| build | **NO-GO** |
| test execution | **NO-GO** |
| network | **NO-GO** |
| portal | **NO-GO** |
| signing/archive/upload | **NO-GO** |
| device/install/registration mutation | **NO-GO** |
| APNS/provider contact/push | **NO-GO** |
| secrets/raw tokens/private keys | **NO ACCESS / NO-GO** |
| Identity mutation/cutover | **NO-GO** |
| staging | **NO-GO** |
| deployment | **NO-GO** |
| material phase | **NO-GO** |
| production/App Store readiness | **NO-GO** |

## 14. Integrator freeze

```text
ARTIFACT =
  APNS S6 Additive Normative Correction

INPUTS =
  exact S5 plus exact Packet A/B/C and their exact independent reviews

INTEGRATION RULE =
  only independently reviewed closures

RC2 =
  preserved static closure

RC1/RC3/RC4/RC5/RC6/RC7 =
  PARTIAL and/or FORMAL_NO_GO as recorded above

RC8 =
  CLOSED FOR STATIC DAG / EXTERNAL FORMAL_NO_GO

P0/P1/P2 REVIEW HEADINGS =
  0/8/7 inherited

CONSOLIDATED UNIQUE P0/P1/P2 ROOT CAUSES =
  0/8/5

EXTERNAL AUTHORITY/PROVIDER/HARDWARE/KEY/CUSTODY/STORE/SINK SETS =
  EMPTY

MBI-PRIVACY-RETENTION-01 =
  OPEN / KJETIL / NO VALUE CHOSEN

IDENTITY / MBI-06 / MBI-07 =
  OPEN / SEPARATE / NO-GO

S6 =
  STATIC PARTIAL / FORMAL_NO_GO

NEXT MATERIAL PHASE =
  NOT AUTHORIZED
```

The only authorized successor to these bytes is the separately ordered set of
three independent exact-byte static lane-conformance reviews against one exact
S6 SHA. This author receives no self-review credit.
