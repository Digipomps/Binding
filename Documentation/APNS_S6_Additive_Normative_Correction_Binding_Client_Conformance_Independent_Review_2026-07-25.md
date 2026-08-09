# APNS S6 Additive Normative Correction — Binding Client Conformance Independent Review

Status: **FROZEN INDEPENDENT REVIEW / FORMAL_NO_GO / NO NEXT PHASE**

Date: 2026-07-25  
Review identifier: `haven.apns.s6.additive-normative-correction.binding-client-independent-review.v1`  
Review lane: Binding client, durability, vault, and shared-byte conformance  
Reviewer relationship: independent of the S6 author/integrator  
Output count: exactly one new documentation artifact

This review evaluates the exact S6 additive correction bytes named below. It
does not author, repair, or supersede S6. It grants no implementation,
dependency, Git, build, test, signing, portal, device, APNS, staging,
deployment, Identity, or production authority.

## 1. Exact reviewed bytes and lineage

### 1.1 Review target

| Artifact | Exact path | SHA-256 | Lines | Bytes |
|---|---|---|---:|---:|
| S6 additive correction | `Documentation/APNS_S6_Additive_Normative_Correction_2026-07-25.md` | `21aa8f69da720828dac53e952521c46fede5e8b763445ee5e7655788273c4a22` | 979 | 49901 |

The target path and these exact bytes were present at review start. This
review output path was reattested absent immediately before creation.

### 1.2 Exact immutable inputs reproduced from S6

| Input | Exact path | SHA-256 | Lines | Bytes | Imported disposition |
|---|---|---|---:|---:|---|
| S5 | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md` | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554 | 93787 | terminal static NO-GO |
| Packet A | `Documentation/APNS_S6_Formal_Proof_Packet_A_Response_Maxima_2026-07-25.md` | `4139ad6f863c8e704357f710235dd47d77b9a949c1cb5a6a557e99bd4a19669f` | 1200 | 39346 | author packet |
| Packet A review | `Documentation/APNS_S6_Formal_Proof_Packet_A_Response_Maxima_Independent_Cross_Review_2026-07-25.md` | `9a8fae81e19d7961d91c12e4052f146a161a418fa3dd38fc91525826775710bd` | 905 | 28228 | `0/1/2`, PARTIAL |
| Packet B | `Documentation/APNS_S6_Formal_Proof_Packet_B_Authority_Head_2026-07-25.md` | `36bccdd94e183cae4aa7a26a0637ce8f71abbb7bf8f17086d175859856a0ffb8` | 1905 | 54641 | author packet |
| Packet B review | `Documentation/APNS_S6_Formal_Proof_Packet_B_Authority_Head_Independent_Cross_Review_2026-07-25.md` | `c4758f47fd86fc175efefabce235341f6c60d2aa3b40bd14d66aa1647af7efc6` | 847 | 29534 | `0/5/2`, NO-GO |
| Packet C | `Documentation/APNS_S6_Formal_Proof_Packet_C_Durability_Client_Vault_2026-07-25.md` | `f929ca08ddc8bcee1727019e9d53022ea99e9dca81d6d9f65aa608556852b225` | 1776 | 63436 | author packet |
| Packet C review | `Documentation/APNS_S6_Formal_Proof_Packet_C_Durability_Client_Vault_Independent_Cross_Review_2026-07-25.md` | `f7ff5cfc229c54c4bf81c08e02bda39dc31b8571c8fa4d553702a0469cb927b0` | 1128 | 33893 | `0/2/3`, NO-GO |

Only the S6 target and the seven exact inputs above are treated as normative
review material. Administrative messages are coordination evidence only.

## 2. Method, precedence, and limits

The review adversarially checked:

1. S6 precedence against each independent packet review;
2. accepted Binding/client claims against their exact cited packet sections;
3. RC6 inventory, enumeration, watermark, count, and durability gates;
4. RC7 journal extensions, maxima, JournalID, stable conflicts, recovery, and
   local-unknown behavior;
5. RC8 generation direction, current external anchor-head binding, rollback,
   vault, custody, and crash boundaries;
6. resolve-delivery handoff and sink-receipt semantics;
7. exact Binding project/package/source/test/fixture/docs owner and no-touch
   rows;
8. fixture applicability and every explicitly blocked row;
9. raw versus consolidated finding counts; and
10. separation of MBI, Identity cutover, Apple signing, and integrated output.

The operative precedence was correctly read as:

```text
S6 accepted/rejected ledgers
> independent review for the affected packet
> exact packet section named by an accepted row
> terminal S5 for unchanged matters
> older material only through S5
```

That precedence makes the exact packet-section locator material. This review
therefore reports an imprecise locator even when the independent review still
supports the narrowed substantive claim.

No material test was run. No source tree, Git state, package graph, project
file, fixture, provider, external store, device, entitlement, or production
system was inspected or changed under this authorization.

## 3. Executive verdict

### 3.1 S6-specific findings

```text
P0 = 0
P1 = 0
P2 = 1
```

### 3.2 Overall disposition

**S6 remains STATIC PARTIAL / FORMAL_NO_GO / NO NEXT PHASE.**

The one S6-specific P2 does not reopen any operational gate. It does require a
future additive documentation correction if exact accepted-claim provenance
is to be machine-consumable without consulting broader packet/review context.

All inherited formal blockers remain inherited. They are not downgraded,
silently repaired, or double-counted as new S6 defects.

## 4. Finding

### P2-S6-C-LC-01 — two accepted Packet C rows cite imprecise packet sections

S6 establishes that an accepted row's exact packet section is third in
precedence. Two Packet C rows do not point to the complete packet locus for
the claim they accept:

1. `S6-C-ACC-06` cites Packet C `10.1...10.2` while accepting both the
   idempotent sink capability/receipt and the
   `prepared -> sink-receipt -> finalized` ordering. Packet C section 10.3
   contains that ordering. Sections 10.1...10.2 alone do not completely
   support the row.
2. `S6-C-ACC-09` cites `12 and review 12` for the rule that a restored local
   copy must equal the provider's **current** external anchor head and that an
   old exact-generation query is insufficient. Packet C section 12 is the
   fixture-applicability section. The packet rule is in sections 8.7 and 9.3;
   Packet C review section 12 does support the narrowed review conclusion.

Impact:

- the substantive claims remain no stronger than the independent Packet C
  review;
- no runtime, authority, provider, recovery, or operational PASS follows;
- a parser following S6's exact-locus precedence cannot derive the complete
  accepted Packet C construction from the named packet sections alone.

Required future documentation-only resolution:

```text
S6-C-ACC-06 packet locus must include Packet C 10.3
S6-C-ACC-09 packet locus must cite Packet C 8.7 and 9.3,
  while retaining Packet C review 12
```

This review does not alter S6.

## 5. Accepted Binding/client claims — conformance disposition

| S6 claim | Independent result | Boundary preserved |
|---|---|---|
| `S6-C-ACC-01` | ACCEPTED NARROWLY | RC6 provider-gated fail-red snapshot/watch/name-to-inode algorithm and crash/race failure branches only; successful finite completeness remains blocked |
| `S6-C-ACC-02` | ACCEPTED NARROWLY | six extension schemas, nullability, digest binding, and reproduced maxima only; JournalID-bearing journal totality remains blocked |
| `S6-C-ACC-03` | ACCEPTED NARROWLY | stable conflict namespace, resource-family keys, durable-lease intent, and vault-transition intent only; provider proof remains EMPTY |
| `S6-C-ACC-04` | ACCEPTED NARROWLY | predecessor/successor expectation, prepared transaction, checkpoint, anchor, marker, and finalization DAG excluding the defective JournalID spelling; constructible `OperationJournalCore` remains blocked |
| `S6-C-ACC-05` | ACCEPTED NARROWLY | conservative prepare/anchor/send ordering, append-only marker intent, and crash failure behavior only; provider PASS remains EMPTY |
| `S6-C-ACC-06` | ACCEPTED NARROWLY WITH P2 LOCATOR DEFECT | sink capability/receipt and ordering intent only; request-byte replay alternative and provider PASS remain blocked |
| `S6-C-ACC-07` | ACCEPTED NARROWLY | authoritative server deregister plus fresh signed status/read-back precedes local erase; no privacy-retention choice is inferred |
| `S6-C-ACC-08` | ACCEPTED STATICALLY | RC8 generation DAG is acyclic; external copy, rollback, hardware, custody, and durability evidence remain EMPTY |
| `S6-C-ACC-09` | ACCEPTED NARROWLY WITH P2 LOCATOR DEFECT | current external anchor-head equality is mandatory and old exact-generation proof is insufficient; provider availability remains EMPTY |

The correction does not over-promote an immutable marker. Marker ordering is
accepted only as a static, append-only construction and crash-state rule.
Neither the marker nor a local read-back is treated as an external provider
receipt, an authority grant, an APNS delivery receipt, or a production proof.

## 6. RC6 — finite inventory and durability fence

### 6.1 Preserved blocker

S6 correctly preserves the Packet C review's RC6 P1:

```text
the durable fence digest does not bind the exact EnumerationManifest core,
every accepted inventory row,
every count,
and the start/end watermark evidence as one reproducible completeness proof
```

The preserved fail-closed requirements are:

- the enumerated root set and scope must be exact;
- the start watermark must be captured and bound;
- each discovered item must have an exact, non-secret inventory row;
- per-root counts cannot be substituted for a global exact enumeration
  manifest;
- the end watermark must prove the enumerated namespace did not change;
- the durable fence must bind the exact manifest, rows, counts, and
  watermarks;
- crash, watcher overflow, name-to-inode mismatch, path replacement,
  concurrent writer, unsupported provider, or ambiguous result remains red;
- no successful finite-completeness branch exists until the exact provider
  and manifest construction are supplied and independently exercised.

Therefore:

```text
RC6 static failure branches = accepted
RC6 finite-completeness success branch = BLOCKED
RC6 provider evidence = EMPTY
RC6 verdict = PARTIAL / FORMAL_NO_GO
```

No S6 statement converts a fail-red algorithm into a complete inventory
proof.

## 7. RC7 — journal, extensions, conflict namespace, and recovery

### 7.1 Extension schemas and maxima

S6 accurately preserves the eight independently reproduced extension maxima:

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

These are structural allocation maxima for the accepted extension cores.
They are not proof of a total journal, accepted signature profile, provider
durability, application behavior, or production readiness.

The six extension schema constructions and their exact nullability/digest
relations are accepted only within the Packet C review's scope. The accepted
extension/maxima rows do not cure the enclosing journal defect.

### 7.2 JournalID blocker remains exact

The packet spells:

```text
"jr1_" + Base64url43
```

This is:

```text
4 ASCII bytes + 43 ASCII bytes = 47 bytes
```

It cannot simultaneously satisfy the packet's claimed exact 48-byte length.
S6 correctly excludes the defective spelling from `S6-C-ACC-04` and does not
claim a constructible `OperationJournalCore`.

No implicit padding, separator, prefix change, or length relaxation is
permitted. An owner decision and successor exact bytes are required.

### 7.3 Stable conflicts and local-unknown

S6 accurately preserves the stable conflict families:

| Family | Conflicting operations |
|---|---|
| `K_registration` | register, revoke, deregister, status/registration |
| `K_ticket` | resolve and submit for the same ticket family |
| `K_admission` | protected-operation recovery and status/admission |
| `K_domain_transition` | vault namespace/generation transition |

The namespace/key and lease **intent** is accepted. Cross-process locking,
stable-store behavior, and external provider evidence remain unproved.

`local_unknown` is not a successful state, a retry permission, a recreated
request, or a proof that the server did not mutate. Ambiguous pending work
must remain fail-closed until an authoritative signed status/admission
read-back adjudicates it under the accepted subject/generation rules.

### 7.4 Request-recovery P2 remains blocked

Packet C's request-byte replay recovery branch refers to stored exact request
bytes that are not represented in the accepted durability graph. S6 correctly
excludes that alternative in `S6-C-ACC-06`.

The only retained safe planning route is authoritative signed
status/admission recovery. S6 supplies neither exact recovered request bytes
nor permission to reconstruct or re-sign a request.

Therefore:

```text
RC7 extension structure = accepted narrowly
RC7 total JournalID-bearing journal = BLOCKED
RC7 request-byte replay recovery = BLOCKED
RC7 provider evidence = EMPTY
RC7 verdict = PARTIAL / FORMAL_NO_GO
```

## 8. Resolve delivery handoff

S6 does not claim that a verified resolve response proves downstream delivery.
The accepted planning sequence is bounded as:

```text
prepared local state
-> an idempotent sink capability is invoked
-> exact sink receipt is durably bound
-> local finalization
```

This is a static ordering requirement only. It does not prove:

- that a sink implementation exists;
- that a sink receipt is externally durable;
- that a notification was delivered to an iPad;
- that APNS accepted a provider request;
- that a Binding callback occurred; or
- that missing request bytes can be reconstructed.

If the exact sink receipt is absent or ambiguous, finalization remains
blocked. The P2 locator correction in section 4 is required for exact packet
section provenance, but the substantive S6 narrowing matches the independent
review.

## 9. RC8 — vault generation, external head, custody, and rollback

### 9.1 Static DAG check

The accepted graph is:

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

Adversarial edge inspection found no future-reference cycle:

- an expectation is materialized before its journal use;
- an extension precedes the journal;
- the journal precedes prepared state;
- `V_(n+1)` follows the prepared predecessor material;
- each checkpoint/marker/anchor step points only to materialized predecessor
  bytes;
- no checkpoint embeds its future anchor;
- no marker embeds its future anchor;
- no anchor embeds a future marker.

This establishes only static acyclicity for the accepted graph. The defective
JournalID still prevents total journal construction.

### 9.2 Current external anchor head is mandatory

Restore cannot mark a registration active merely because:

- local historical evidence verifies;
- an old exact generation is readable;
- a copied vault and anchor agree with each other; or
- the local marker sequence appears internally consistent.

The restored local copy must equal a fresh query of the provider's **current
external anchor head** for the relevant namespace/subject. A query that only
retrieves an old exact generation is insufficient because it does not exclude
a later admitted generation, revocation, tombstone, or rollback boundary.

Until that current-head provider and signed status/read-back exist, restored
evidence remains historical evidence and cannot become
`current activeConsented`.

### 9.3 External evidence sets

S6 correctly leaves every relevant external set empty:

```text
accepted stable-store provider set = EMPTY
accepted durable expectation-store set = EMPTY
accepted operation-journal provider set = EMPTY
accepted marker-store provider set = EMPTY
accepted external anchor-store provider set = EMPTY
accepted current external anchor-head query provider set = EMPTY
accepted sink provider/receipt set = EMPTY
accepted hardware-rooted key set = EMPTY
accepted key-custody evidence set = EMPTY
accepted rollback-resistance evidence set = EMPTY
accepted migration/disposal procedure set = EMPTY
```

Consequently:

```text
RC8 static DAG = CLOSED NARROWLY
RC8 external durability/custody/rollback = FORMAL_NO_GO
RC8 operational verdict = NO-GO
```

## 10. Binding paths, owners, and no-touch boundaries

### 10.1 Project, package, and entitlement rows

The following remain outside the Binding client source/test owner's authority:

| Exact path | Sole owner | Disposition |
|---|---|---|
| `repo://Binding/Binding.xcodeproj/project.pbxproj` | Binding development administrator | no-touch |
| `repo://Binding/Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Binding development administrator | no-touch |
| `repo://CellProtocol/Package.swift` | CellProtocol development administrator | no-touch |
| `repo://Binding/Binding/Binding-iOS.entitlements` | Apple release owner | immutable/no-touch |

No package pin, project membership, build setting, entitlement, signing
identity, or dependency resolution is inferred from a planned source path.

### 10.2 Binding DeviceIngress source rows

S6 assigns exactly one sole final-byte owner, `Binding client owner`, to:

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
```

### 10.3 Binding test, support, fixture, and docs rows

The same sole owner is assigned to:

```text
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

These are proposed output paths, not evidence that files exist, are in the
Xcode project, compile, pass, or contain accepted bytes.

### 10.4 Apple release rows

S6 preserves the separate sole owner `Apple release owner` and
immutable/no-touch status for:

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

The path inventory has no duplicate final-byte owner in the reviewed Binding
rows. The independent reviewer is not a co-owner. Shared producer bytes
remain owned in CellProtocol; Binding is a byte-preserving consumer only.

## 11. Shared bytes and fixture applicability

### 11.1 Byte-preserving boundary

The Binding client may consume only the exact canonical bytes selected by the
CellProtocol producer contract. HTTP, URLSession, route paths, Host, TLS,
headers, JSON adapters, local stores, and UI state remain semantically neutral.
They cannot:

- reinterpret an accepted core;
- normalize or regenerate signed bytes;
- grant owner, Agreement, Contract, Grant, Resolver, Cell, or signer
  authority;
- promote a local marker to a server receipt; or
- infer APNS delivery.

The Binding fixture planning path remains:

```text
repo://Binding/BindingTests/Fixtures/DeviceIngressCompositionV3/client-consumption.v3.json
```

Its presence in a planning ledger is not fixture-byte evidence.

### 11.2 Fixture status

The S6 ledger correctly preserves:

```text
Packet A logical rows = 30
Packet A executable fixture bytes = 0

Packet B fixture names = 83
Packet B integrated fixture bytes = 0

Packet C planning rows = 52
Packet C executable fixture bytes = 0
```

The applicability aliases separate producer, server, and client consumers.
No server-only discovery row is silently converted into a Binding client
requirement, and no client-only durability row is treated as server evidence.

The previously challenged `S6C009` row is explicitly `BLOCKED`; S6 does not
replace its incorrect N/A rationale with invented applicability. The ledgers
also keep explicit blocked rows for:

- exact RC6 enumeration manifest/count/watermark/fence bytes;
- the corrected JournalID;
- current external anchor-head provider/query bytes;
- exact request-byte replay recovery; and
- missing producer/consumer fixture bytes and hashes.

Therefore no fixture row has executable PASS and MBI-07 remains missing.

## 12. Finding-count consolidation

### 12.1 Raw imported review counts

```text
Packet A review = 0/1/2
Packet B review = 0/5/2
Packet C review = 0/2/3
--------------------------------
raw total       = 0/8/7
```

### 12.2 Unique unresolved classes

S6 correctly consolidates the seven raw P2 findings into five non-duplicative
classes:

1. Packet A deregister maximum-minus-one witness;
2. cross-packet fixture/applicability/path completeness;
3. Packet B construction and byte-edge precision;
4. Packet C bound-review-count provenance; and
5. Packet C request-byte replay recovery.

Thus the inherited unique unresolved count remains:

```text
P0/P1/P2 = 0/8/5
```

This review adds one S6-specific P2 about exact accepted-row packet locators.
It does not alter the inherited raw or consolidated packet-review counts:

```text
S6-specific review = 0/0/1
inherited packet-review classes = 0/8/5
```

No arithmetic consolidation closes an underlying contract, provider, fixture,
Identity, signing, or integrated-output gate.

## 13. RC verdicts

| RC | S6 review verdict | Reason |
|---|---|---|
| RC1 | PARTIAL / FORMAL_NO_GO | structural response/maxima construction is narrow; total error applicability, signer selection, signature profile, and executable fixtures remain unresolved |
| RC2 | STATIC CLOSED, unchanged | U1...U4 precedence, stored expiry outcome, exact replay bytes, no reconstruction/re-signing, no new replay sequence, and wrong-subject privacy equivalence remain inherited |
| RC3 | PARTIAL / FORMAL_NO_GO | authority/head structures remain incomplete; no current authoritative construction or provider |
| RC4 | PARTIAL / FORMAL_NO_GO | mutation/CAS direction remains incomplete and non-operational |
| RC5 | PARTIAL / FORMAL_NO_GO | structural maxima accepted narrowly; accepted signature profile and executable evidence remain EMPTY |
| RC6 | PARTIAL / FORMAL_NO_GO | fail-red algorithm accepted; manifest/count/start-end-watermark/fence completeness and provider evidence remain missing |
| RC7 | PARTIAL / FORMAL_NO_GO | extensions/conflict intent accepted; 47-versus-48 JournalID and exact request-recovery remain blocked |
| RC8 | STATIC DAG CLOSED / EXTERNAL FORMAL_NO_GO | graph is acyclic; current external head query, store, sink, hardware, custody, and rollback evidence remain EMPTY |

## 14. Deployment literals, MBI, and separation gates

S6 correctly preserves these literals as premises only:

```text
identity domain = domain:device:notification-callback
purpose = purpose://access.audit.privacy/device-notification-callback
origin = https://haven.digipomps.org
bundle = org.digipomps.haven
topic = org.digipomps.haven
environment = production
```

They prove no App ID, Team ID, provisioning profile, signing certificate,
effective `aps-environment`, installed build, APNS topic acceptance, device
registration, device receipt, callback, or App Store readiness.

The following boundaries remain separate and closed:

- Identity cutover is a distinct prerequisite and receives no proof or
  authorization from S6.
- MBI-01 through MBI-05 remain bounded by their unresolved contract/provider
  inputs and Packet A/B/C findings.
- MBI-06 production profile, entitlements, Team ID, signing identity, and
  installed-build evidence remains unaudited/missing.
- MBI-07 integrated exact output, executable fixtures, cross-repository byte
  equality, and end-to-end result remains unaudited/missing.
- raw APNS tokens, token hashes, private keys, capabilities, and other secrets
  remain forbidden from documentation and evidence.

Authoritative deregistration plus fresh signed status/read-back remains
mandatory before local token/active-binding erasure. Local absence, uninstall,
restore, copied signed evidence, or historical evidence never proves
server-side deregistration or current consent.

## 15. Explicit stop table

| Proposed action | S6 review result |
|---|---|
| Documentation-only successor correcting the two exact Packet C locators | eligible only under separate administrator scope and independent review |
| Choose the JournalID correction | STOP — exact owner decision and successor contract bytes required |
| Supply RC6 manifest/count/watermark/fence construction | STOP — separate exact provider/contract scope required |
| Supply request-byte replay recovery | STOP — exact durability graph and bytes required |
| Implement Binding DeviceIngress paths | STOP |
| Modify `project.pbxproj`, `Package.resolved`, `Package.swift`, or entitlements | STOP / no-touch |
| Resolve dependencies, build, or test | STOP |
| Exercise Identity cutover | STOP / separate prerequisite |
| Inspect or change Apple portal/profile/signing state | STOP |
| Install, register, rotate token, or mutate a device | STOP |
| Contact APNS or send a notification | STOP |
| Stage, deploy, or exercise production | STOP |
| Claim App Store or production readiness | STOP |

## 16. Final conclusion

The exact S6 bytes are a conservative additive integration of the three
packet reviews. For the Binding/client lane they correctly preserve:

- the RC6 inventory-manifest/count/watermark blocker;
- the RC7 47-versus-48 JournalID blocker;
- the blocked request-byte replay recovery branch;
- the acyclic RC8 predecessor/successor generation graph;
- the mandatory current external anchor-head query;
- EMPTY external store, sink, hardware, custody, and rollback sets;
- immutable-marker and conflict/local-unknown fail-closed semantics;
- one-owner/no-touch project, package, source, test, fixture, docs, and Apple
  boundaries;
- zero executable fixture bytes and exact blocked applicability rows;
- raw `0/8/7` and unique `0/8/5` imported finding counts; and
- strict MBI, Identity, signing, and integrated-output separation.

One S6-specific P2 remains: two accepted Packet C rows do not cite the
complete exact packet sections that support their narrowed claims. The
independent review still supports those claims, so this is a provenance
locator defect rather than a semantic promotion.

Final verdict:

```text
S6-specific P0/P1/P2 = 0/0/1
RC6 = PARTIAL / FORMAL_NO_GO
RC7 = PARTIAL / FORMAL_NO_GO
RC8 = STATIC DAG CLOSED / EXTERNAL FORMAL_NO_GO
overall = STATIC PARTIAL / FORMAL_NO_GO / NO NEXT PHASE
```

No source or material phase is authorized.
