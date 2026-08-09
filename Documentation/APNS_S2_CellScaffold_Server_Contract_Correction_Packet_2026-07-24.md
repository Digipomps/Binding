# APNS S2 CellScaffold Server Contract Correction Packet

Status: **AUTHOR-FROZEN / LANE B CORRECTION PLAN ONLY / INDEPENDENT REVIEW REQUIRED / MBI-04 PARTIAL / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO**

Packet ID:
`APNS-S2-CELLSCAFFOLD-SERVER-CONTRACT-CORRECTION/2026-07-24/v1`

Owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_2026-07-24.md`

This is the sole output owned by this S2 Lane B author. It corrects the static
Lane B planning contract only. It does not rewrite or supersede S0 or any S1
artifact, and it grants no authority for source edits, Git mutation,
dependency resolution, build, test, network, portal, signing, device action,
APNS, secrets, Identity cutover, staging, deployment or a next material phase.

Author self-review has no credit. A distinct reviewer must reproduce and
adversarially review the exact frozen bytes before any successor planning
decision.

## 1. Exact immutable input gate

### 1.1 S0 remains immutable

| Input | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

Inherited S0 result:

```text
P0: 0
P1: 2
P2: 1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

Nothing in S0 is modified or upgraded here.

### 1.2 All six S1 packet/review inputs

| Lane | Artifact | SHA-256 | Lines | Bytes | Bound treatment |
| --- | --- | --- | ---: | ---: | --- |
| A | Producer/contract packet | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | Immutable author packet |
| A | Independent review | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | `P0/P1/P2=0/5/2`; Lane A remains NO-GO |
| B | Server packet | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | Corrected by this new packet; original remains immutable |
| B | Independent review | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | `P0/P1/P2=0/4/1`; exact correction input |
| C | Binding client packet | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | Immutable interface input |
| C | Independent review | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | `P0/P1/P2=0/3/4`; Lane C remains NO-GO |

No parallel S2 artifact is an input to this author packet.

## 2. Purpose, goal and evidence boundary

Purposes:

- `purpose://access.audit.privacy`: keep Resolver-selected Cells, their
  verified owners and complete signed Agreements as the only operation
  authority; keep raw APNS tokens protected.
- `purpose://test.acceptance`: make admission, challenge, status, replay,
  restart, token lifecycle and failure behavior deterministic and separately
  provable.
- `purpose://scaffold.operations`: freeze one exact future path/owner and
  bootstrap boundary without opening implementation.

Goal:

> Correct every S1 Lane B P1/P2 as a static server plan while preserving all
> genuine missing authority/product inputs and every operational NO-GO.

Evidence classes remain separate:

| Evidence class | This packet supplies | Still required |
| --- | --- | --- |
| Static contract | Exact corrected topology, states, paths, owners, tests and blockers | Independent exact-byte review |
| Source | Named immutable observations only | Authorized source candidate and diff |
| Identity | Separate prerequisite and required runtime proofs | Green Identity cutover |
| Authority | Exact verification path | Actual issuer/owner descriptors and owner-signed Agreements |
| Persistence | Transaction/settings/test contract | Runtime crash/restart/restore proof |
| Signing | Bundle/topic/origin planning values | `MBI-06` |
| Integration | Owner/collision boundary | `MBI-07` exact commit/tree/digest |
| APNS | None | Provider acceptance and physical-device evidence |

## 3. Reproduced immutable technical facts

The source bases remain:

| Boundary | Commit | Tree |
| --- | --- | --- |
| CellScaffold route successor | `d2d1b7191d651ad42d172e980ab94a0fd478d07c` | `536531541587b5229b8f325f8935ed11ef85f228` |
| CellScaffold selected Identity source boundary | `c700dbc5699ec3a925165d80bc2ec7ad864a1218` | `211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4` |
| CellProtocol v3 basis | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` | `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` |

Read-only facts relevant to this correction:

- current CellProtocol has only `register`, `resolve` and `submit`, all with
  `rw-s`;
- Lane A proposes `status` with `r--s` and `revoke` with `rw-s`, but its
  independent review remains NO-GO;
- current CellScaffold transport is a semantically neutral three-input carrier
  and only register may reach an inert admission seam;
- current production challenge, admission, replay, status and revoke
  composition is absent;
- `CellResolver.addCellResolve` and owner refresh currently call the vault with
  `makeNewIfNotFound=true` and are forbidden for the two security
  infrastructure Cells in this packet;
- `CellResolver.registerNamedEmitCell` can register a concrete recovered
  instance and does not itself mint an owner;
- current `DeviceRegistration` resolve is `.identityUnique` and
  `.persistant`;
- current `DeviceCallbackBridge` resolve is `.scaffoldUnique` and
  `.persistant`;
- current runtime owner context can be environment-selected and therefore is
  not accepted as authority without byte equality to the green Identity
  cutover/authority manifest;
- current database is Fluent SQLite selected through
  `SQLITE_DATABASE_PATH` or `db.sqlite`;
- selected dependency pins include `fluent-sqlite-driver 4.8.1`
  (`73529a63ab11c7fe87da17b5a67a1b1f58c020f8`),
  `sqlite-kit 4.5.2`
  (`f35a863ecc2da5d563b836a9a696b148b0f4169f`) and
  `sqlite-nio 1.12.4`
  (`2152bfcecad9da55d870b342f89a78392188f430`);
- current legacy `DeviceEndpointRecord` can persist a raw `pushToken`; and
- existing callback resolve/submit crosses several Cells and does not provide
  one target-Cell atomic canonical response.

These are source observations, not runtime or production proof.

## 4. Corrected authority and transport boundary

The only permitted protected-operation path is:

```text
bounded HTTP carrier
  -> byte-preserving shared transport decode
  -> canonical read-only operation/path inspection owned by reviewed Lane A
  -> verified canonical request/challenge/body tuple
  -> Resolver resolves the exact operation resource for the signed subject
  -> selected target Cell UUID and current owner descriptor match request
  -> selected target Cell supplies complete owner-signed Agreement/Contract
  -> CellProtocol verifies subject/domain/purpose/audience/scope/Grant/time
  -> durable admission record and receipt commit/read back
  -> same selected target Cell rechecks owner/Agreement/generations
  -> same target transaction commits domain result/receipt/exact response
  -> raw canonical response bytes
```

HTTP, Host, origin, route, APNS topic, bundle ID, token, participant/device
metadata, issuer identity alone, UUID/hash alone, service handle, readiness
flag, static file, application admin and Scaffold owner are never operation
authority.

The shared carrier may bound, base64-decode and preserve bytes. It may not
select or create Identity, Cell, owner, Agreement, Grant, generation, result
or success. Lane A must resolve its read-only inner-operation inspection
finding before Lane B consumes the shared artifact. Until then every route is
unavailable.

## 5. Corrected per-operation RWXS least-privilege matrix

The exact canonical relation is:

```text
request.requiredAccess
  == request.operation.requiredAccess
  == exact permission on the hash-derived DeviceIngressAgreementScope Grant
```

No code or test may substitute one blanket permission.

| Operation | Resource/action/capability source | Exact requester access | Why | Server state |
| --- | --- | --- | --- | --- |
| Challenge intent | Lane A challenge contract | No DeviceIngress operation Grant is consumed by issuance; issuer must precheck that the exact target-operation Agreement exists | A challenge grants nothing | Blocked on reviewed Lane A MBI-03 and issuer authority input |
| `register` | Current CellProtocol v3 | `rw-s` | Read current registration, write token/registration mutation, retain signed receipt | Contract-known; server composition missing |
| `status` | Lane A proposal only | `r--s` | Read one authoritative snapshot and permit requester retention; no registration write | Unavailable until Lane A is green |
| `revoke` | Lane A proposal only | `rw-s` | Read/CAS active state, write tombstone/generation, retain receipt | Unavailable until Lane A is green |
| `deregister` | Undefined by Lane A | None | No alias/delete semantic may be invented | Unavailable |
| `resolve` | Current CellProtocol v3 | `rw-s` | Read/claim ticket, write durable resolve result, retain response | Contract-known; target composition missing |
| `submit` | Current CellProtocol v3 | `rw-s` | Read ticket lineage, write result/receipt, retain response | Contract-known; target composition missing |
| Token rotation | Undefined correlation semantics | None beyond later reviewed operation | Generation rise alone is insufficient | Unavailable |
| Issuer rotation | Not a DeviceIngress protected operation | No operation Grant | Requires separate owner-signed rotation proof | Unavailable |

The server's internal persistence does not create requester Storage authority.
`s` controls the requester's right to retain the signed result. `status`
therefore remains `r--s`; it never receives `w` merely because the server
stores an audit/replay record.

Negative tests must iterate this matrix and reject permission substitution in
both directions.

## 6. Corrected Resolver and Cell composition

### 6.1 Exact Cell tuples

| Endpoint/name | Type/path | Scope | Persistency | Identity domain/owner binding | Lifecycle |
| --- | --- | --- | --- | --- | --- |
| `cell:///DeviceIngressAuthorityCatalog` / `DeviceIngressAuthorityCatalog` | `DeviceIngressAuthorityCatalogCell` / `Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityCatalogCell.swift` | `.scaffoldUnique` | `.persistant` | Exact `serverOwnerIdentityDomain` and owner descriptor from the independently green signed authority manifest; vault lookup uses `makeNewIfNotFound=false` | No TTL eviction; `lifecyclePolicy=nil`; recovered before readiness |
| `cell:///DeviceIngressChallengeIssuer` / `DeviceIngressChallengeIssuer` | `DeviceIngressChallengeIssuerCell` / `Sources/App/Cells/DeviceIngress/DeviceIngressChallengeIssuerCell.swift` | `.scaffoldUnique` | `.persistant` | Exact issuer domain, Cell UUID, Cell owner and issuer signing descriptor from the independently green signed authority manifest; all vault lookups use `makeNewIfNotFound=false` | No TTL eviction; `lifecyclePolicy=nil`; recovered before readiness |
| `cell:///DeviceRegistration` / `DeviceRegistration` | Existing `DeviceRegistrationCell` plus ingress authority adapter | `.identityUnique` | `.persistant` | Resolver-selected signed device requester identity; no host-owner substitution | No DeviceIngress-specific TTL; persistent snapshot and authoritative database record must recover before operation readiness |
| `cell:///DeviceCallbackBridge` / `DeviceCallbackBridge` | Existing `DeviceCallbackBridgeCell` plus ingress authority adapter | `.scaffoldUnique` | `.persistant` | Existing exact owner context must byte-match the green authority manifest; no environment-only acceptance | No DeviceIngress-specific TTL; persistent target/outbox state must recover before operation readiness |

The authority manifest is a signed, sanitized pin/readiness input. It grants no
operation. It contains no private key or raw token. Its schema implementation
is planned at:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityManifest.swift
Tests/AppTests/DeviceIngressAuthorityManifestTests.swift
```

The runtime manifest location is provided by the exact config key
`DEVICE_INGRESS_AUTHORITY_MANIFEST_PATH`. Its absolute value, exact signed
bytes, signer continuity and issuer/owner descriptors remain a genuine
authority missing-bound-input. No placeholder or unsigned repository file is
accepted.

### 6.2 Exact no-auto-create registration rule

For the two infrastructure Cells:

- do not call `CellResolver.addCellResolve`;
- do not call `refreshNamedResolveOwnersFromCurrentVault`;
- do not call any vault API with `makeNewIfNotFound=true`;
- do not instantiate a new owner, issuer, Cell UUID, Agreement or credential;
- recover the exact manifest-named persisted Cell instance;
- open the exact pre-existing owner through the authenticated vault with
  `makeNewIfNotFound=false`;
- rebind stored owner to runtime identity only after UUID and signing-key
  control match;
- set/assert the exact scope, persistency, identity domain and `nil` lifecycle;
- register only that concrete instance with `registerNamedEmitCell`;
- read the Resolver mapping back and compare endpoint, UUID, owner descriptor,
  scope and instance identity; and
- fail startup on missing snapshot, duplicate mapping, different UUID,
  different owner, different scope, ephemeral state or read-back mismatch.

`Application.storage` may hold only a non-authoritative handle after this
sequence. It cannot supply a fallback instance.

### 6.3 Exact bootstrap order and ownership

The Lane B composition owner implements the reusable checks in
`DeviceIngressCompositionCoordinator.swift` and
`DeviceIngressResolverRegistration.swift`. The development-admin integrator
owns only the call site and final collision bytes in
`Sources/App/configure.swift`.

Exact order:

1. verify separate Identity cutover attestation and exact source provenance;
2. load and cryptographically verify the authority manifest without using it
   as an Agreement;
3. open the manifest-named pre-existing server/issuer identities with
   `makeNewIfNotFound=false`;
4. open the selected persistent database, verify migrations/settings and
   rollback anchor;
5. recover and owner-rebind the authority catalog Cell;
6. register/read back `cell:///DeviceIngressAuthorityCatalog`;
7. import and verify complete owner-signed Agreements and revocation
   generations;
8. recover and owner-rebind the challenge issuer Cell;
9. register/read back `cell:///DeviceIngressChallengeIssuer`;
10. verify existing `DeviceRegistration` and `DeviceCallbackBridge` Resolver
    definitions against the exact tuples above;
11. recover challenge, admission, response, registration, revocation,
    callback, token and time-watermark stores;
12. reconcile every incomplete transaction and prove exact response
    read-back;
13. construct `DeviceIngressAdmissionService` with reviewed audience,
    expected issuer, Resolver and durable ledger;
14. install a non-authoritative service handle; and
15. evaluate readiness separately for challenge/register/status/revoke/
    resolve/submit/rotation.

No route is installed as ready before step 15. Shutdown marks readiness red,
drains new requests, finishes or rolls back open transactions, flushes stores
and closes handles. Restart repeats every step.

### 6.4 Missing owner/Agreement behavior

If the verified owner identity, Cell snapshot, Agreement catalog, complete
canonical signed Agreement, current owner proof, authority generation or
revocation generation is absent or ambiguous:

- the exact operation is unavailable before challenge/admission;
- no Cell or owner is created;
- no static Agreement or environment Grant is used;
- no Scaffold/app-admin fallback exists;
- no unsigned “deny” is converted into a signed protocol result; and
- sanitized readiness reports the unavailable component only.

This closes the static-root ambiguity as a plan while preserving the actual
authority bytes as a missing-bound-input.

## 7. One total challenge/replay state machine

### 7.1 Durable record

The challenge ledger stores:

```text
canonicalIntentSHA256
subjectIdentityUUID
subjectSigningKeyFingerprint
subjectNonceSHA256
operation
purpose
audience
targetCellUUID
targetOwnerIdentityUUID
signedAgreementSHA256
authorityGeneration
revocationLedgerID
revocationGeneration
issuerIdentityUUID
issuerSigningKeyFingerprint
issuerGeneration
canonicalChallengeBytes
canonicalChallengeSHA256
issuedAtMilliseconds
expiresAtMilliseconds
state
consumedAdmissionID?
consumedRequestSHA256?
terminalAtMilliseconds?
compactionNotBeforeMilliseconds
durableSequence
```

The exact canonical intent and challenge schemas remain Lane A-owned. The
ledger never stores a private key, raw APNS token or protected body.

### 7.2 Exact states

| State | Exact meaning | Permitted transitions |
| --- | --- | --- |
| `absent` | No committed record for intent digest or subject nonce | `issuedActive` only |
| `issuedActive` | Exact signed challenge bytes committed/read back; not consumed; not expired | same-intent byte replay, `consumedActive`, or `expiredUnused` |
| `consumedActive` | Exact challenge linked atomically to one admission/request; response may still be pending | exact request/admission replay, `consumedTerminal`, or `expiredConsumed` |
| `consumedTerminal` | Exact operation response is durably linked/readable | exact challenge and operation-response replay until expiry; then `expiredConsumed` |
| `expiredUnused` | Challenge expired without admission | `compactedTombstone` only |
| `expiredConsumed` | Challenge expired after a committed admission/response lineage | exact operation response remains in operation ledger; challenge record may transition to `compactedTombstone` |
| `compactedTombstone` | Exact challenge bytes removed only after retention gate; uniqueness hashes, issuer/generation, expiry, admission link and durable sequence remain | No reissue, reuse or deletion in this S2 contract |

There is no persisted “partly issued” success state and no digest-only replay
state.

### 7.3 Issuance transaction

1. Begin one serialized transaction.
2. Reject conflicting bytes for an existing intent digest or an existing
   subject/nonce tuple.
3. If an identical unexpired record exists, read/hash-check and return its
   exact stored canonical challenge bytes without signing.
4. If an identical record is expired, return the Lane A-owned expired error;
   never re-sign the same intent/nonce.
5. For `absent`, re-verify subject proof, Resolver target, target owner,
   complete Agreement, generations, issuer and trusted time.
6. Construct/sign the canonical challenge in memory.
7. Insert the complete `issuedActive` record including exact bytes and all
   uniqueness constraints.
8. Commit, read back, byte/hash compare and only then release the response.

Crash before commit exposes no challenge bytes and leaves `absent`. Crash
after commit but before HTTP delivery leaves `issuedActive`; identical retry
returns stored bytes. A replay never calls the signing function.

### 7.4 Admission consumption

Admission atomically:

- opens the exact `issuedActive` record;
- verifies unexpired trusted time and all request/challenge bindings;
- commits admission record/receipt and the challenge link to exactly one
  `admissionID`/request hash;
- returns existing admission only for an exact request replay; and
- rejects a different request, operation, body digest or admission against the
  consumed challenge.

No challenge state is changed outside the durable admission transaction.

### 7.5 Expiry, restart, rotation and read-back

- expiry prevents new consumption but does not erase an admission or response;
- restart reads every non-compacted record, validates unique constraints,
  hashes exact bytes and reconciles its admission/response link;
- corrupt, missing, partial or contradictory records make the affected
  operation unavailable;
- issuer rotation never rewrites or re-signs historical challenge bytes;
- historical verification uses the stored issuer descriptor/generation and
  the independently verified rotation chain;
- lower issuer generation fails rollback checks; and
- a newer issuer cannot issue until Lane A's rotation record and the actual
  owner-signed rotation input are independently green.

### 7.6 Tombstone and compaction

Compaction is non-destructive to uniqueness:

- exact challenge bytes may be removed only from an expired record;
- its admission/operation response must already be independently durable and
  readable when consumed;
- trusted time must exceed
  `expiresAt + requestLifetime + clockSkew + approvedRestoreWindow`;
- an external rollback anchor/checkpoint must cover the tombstone sequence;
- one transaction writes/reads the complete `compactedTombstone` before
  deleting exact challenge bytes; and
- minimal tombstones are not automatically deleted by this S2 contract.

The numeric `approvedRestoreWindow`, capacity and pressure behavior remain the
genuine operations-policy MBI. While absent, compaction is disabled and quota
pressure fails closed rather than deleting evidence.

This replaces the S1 “bytes or digest” contradiction with one total state
machine.

## 8. Corrected admission, status and operation replay

### 8.1 Common admission

Every protected operation, including status after Lane A defines it, must:

1. commit/read back its admission record and receipt;
2. retain exact request/challenge/body hashes and authority bindings;
3. select and retain the exact Resolver target instance;
4. execute against that same target instance;
5. commit exact response bytes or a typed unavailable terminal record; and
6. return stored response bytes on exact replay.

Admission is never an in-memory flag.

### 8.2 Mutation transaction

For register, revoke, resolve and submit, one target-Cell transaction commits:

```text
authority/revocation generation CAS
domain mutation
operation result
mutation receipt
exact signed canonical response
outbox record if a later external side effect is required
```

The selected target Cell rechecks the complete signed Agreement immediately
before commit. Any mismatch leaves no domain mutation.

### 8.3 Status transaction

Status does not mutate registration/token/revocation domain state, but it does
mutate durable admission/audit/replay state:

1. commit/read back status admission;
2. read one generation-consistent record directly from the authoritative
   `DeviceRegistration` transaction store;
3. bind the snapshot to subject, target owner, Agreement, registration,
   authority and revocation generations;
4. atomically commit the status audit snapshot and exact signed response;
5. read/hash-check the stored response; and
6. return it.

An identical request replay returns the exact stored snapshot response and is
historical evidence. Fresh current status requires a new challenge/request and
a new target snapshot transaction.

`current-status projection` may exist only as a disposable query/readiness
cache. It cannot sign a result, satisfy status, infer deregistration, select a
token generation or recover a missing authoritative record.

Lane A currently requires `registrationID` and cannot recover after local ID
loss. Lane B therefore provides no subject-only lookup route. Status remains
unavailable until Lane A freezes a privacy-preserving recovery selector or an
explicit fail-closed alternative.

### 8.4 Ambiguous client recovery interface

Server storage must be capable of reading an exact committed response by
`admissionID` plus its complete expectation bindings. No HTTP/API operation is
invented here. Lane A must freeze whether clients may:

- retrieve the exact response by admission ID;
- perform subject-bound current-state discovery; or
- use another privacy-preserving canonical adjudication.

Until that reviewed operation exists, an ambiguous client remains
indeterminate. The server never asks the client to persist or resend a raw
token merely to recover.

### 8.5 Cross-Cell callback decision

The DeviceIngress critical transaction ends at the selected
`DeviceCallbackBridge` target:

- canonical ticket/payload lineage required for resolve/submit is copied or
  materialized into the target's own durable mutation store before it can be
  exposed as ready;
- the target does not synchronously delegate canonical success to
  `NotificationOutboxCell`, `ContactEndpointCell` or another Cell;
- external follow-up is represented by a target-owned, uniquely keyed durable
  outbox row committed with the exact response;
- workers may deliver that outbox after commit using idempotency keys;
- worker failure cannot rewrite the already committed canonical response; and
- if product semantics require a remote Cell result before DeviceIngress
  success, resolve/submit remain unavailable until CellProtocol defines a
  cross-Cell transaction/receipt contract.

This resolves the S1 cross-Cell implementation ambiguity without pretending
that SQLite makes multiple Cells atomic.

## 9. Protected APNS token lifecycle

### 9.1 Data and authority boundary

Raw token bytes:

- enter only inside the verified canonical protected body;
- are parsed into bounded mutable memory, never a diagnostic `String`;
- are never an authority, lookup key, public hash or stable client-visible
  correlator;
- are sealed before any durable token write;
- never enter Cell `ValueType`, `FlowElement`, logs, fixtures, errors,
  receipts, analytics, backups in plaintext or `UserDefaults`; and
- are best-effort zeroized after sealing/submit, without claiming Swift
  allocator-wide proof.

### 9.2 Sealed record

The protected store persists:

```text
tokenRecordID
registrationID
deviceIdentityUUID
registrationGeneration
keyProviderID
keyVersion
algorithm
nonce
ciphertext
authenticationTag
associatedDataSHA256
state
createdAtMilliseconds
rotatedAtMilliseconds?
retiredAtMilliseconds?
durableSequence
```

Associated authenticated data binds record ID, registration ID, device
identity, registration generation, APNS topic `org.digipomps.haven`, key
provider/version and schema. Neither ciphertext nor its digest is returned to
the client.

The algorithm suite and provider handle must be an independently approved
AEAD/key-provider contract. No secret bytes or provider credential appear in
source, config logs or this packet.

### 9.3 Token states and transitions

| State | Meaning | Transition |
| --- | --- | --- |
| `absent` | No accepted token | `sealedPendingCommit` in transaction memory only |
| `sealedPendingCommit` | Ciphertext produced and verified in memory, not authoritative | `sealedActive` only as part of registration transaction |
| `sealedActive` | Registration points to one committed, read-back verified sealed record | `rewrapPending`, `retired` |
| `rewrapPending` | New-key sealed shadow verified; old record remains active | atomically switch to new `sealedActive`, old becomes `retired`; failure returns to old active |
| `retired` | Not usable for delivery; retained only for bounded rollback audit | `destroyed` after retention/anchor gate |
| `quarantined` | Tag/AAD/reference/key mismatch or ambiguous record | No automatic recovery or delivery |
| `destroyed` | Ciphertext/nonce/tag removed; non-secret tombstone remains | Terminal |

Registration cannot commit if seal, tag verification, database transaction or
post-commit read-back fails. Revocation/deregistration atomically removes the
active token reference and marks the sealed record `retired`; delivery stops
before later destruction. A missing/unavailable/wrong-version key fails
closed. Key rotation uses shadow rewrap and never overwrites the sole
decryptable record in place.

### 9.4 Legacy raw-token decision

Legacy raw `pushToken` rows are never migrated into active authority:

1. migration detects presence without logging or exporting the value;
2. the corresponding legacy registration is marked
   `reenrollment_required`/inactive;
3. a durable non-secret migration tombstone is committed;
4. the raw token column is cleared in the same transaction;
5. post-commit read-back proves the plaintext field is null/absent;
6. failure leaves production register/provider readiness red; and
7. only a new consented canonical registration may create `sealedActive`.

No legacy identity, consent, Agreement or token generation is carried forward.
This is the S2 technical decision for former `B-DEC-06`; no user choice is
requested.

## 10. Persistence, rollback and trusted time

### 10.1 Technical database selection

The future candidate uses the exact selected Fluent SQLite dependency pins and
the configured absolute `SQLITE_DATABASE_PATH`. Relative/default
`db.sqlite` is forbidden for production DeviceIngress readiness.

Every pool connection must attest:

```text
journal_mode = WAL
synchronous = FULL
foreign_keys = ON
trusted_schema = OFF
busy_timeout = 0
```

Writes use an explicit serialized transaction (`BEGIN IMMEDIATE` or an
equivalent reviewed SQLiteKit primitive), exact unique constraints, post-commit
read-back and no in-memory fallback. The database file, `-wal`, `-shm` and
parent directory must have approved owner/mode and reside on a filesystem whose
flush/rename/crash behavior is independently proven for the deployed
engine/library/kernel/storage combination.

This closes engine/path/settings as a technical plan. It does not claim
operational durability; unsupported PRAGMA, pooled-connection drift, network
filesystem, read-back mismatch or crash-test failure keeps readiness red.

### 10.2 Rollback anchor

A counter in the same SQLite database, a Git revision, current time, WAL file
or application readiness flag cannot detect full-store rollback.

The external monotonic anchor must bind:

```text
database identity
schema generation
highest issuer generation
highest authority/revocation generation
highest challenge/admission/response durable sequence
checkpoint digest
```

Its provider/API, persistence path, failure behavior and disaster-recovery
authority remain a genuine security/storage product missing-bound-input.
Without it, no production generation/readiness claim is green.

### 10.3 Trusted-time decision

No network time call is added. Time acceptance combines:

- process monotonic clock for elapsed-time decisions during one boot;
- OS wall time only as an observed value;
- a durable maximum accepted wall-time watermark bound into the external
  rollback anchor;
- Lane A's exact lifetime/skew bounds; and
- fail-closed startup when wall time is behind the anchored watermark beyond
  allowed skew.

Forward jumps expire evidence but never make stale evidence fresh. Backward
jumps never extend challenge/request/Agreement lifetime. Restart begins from
the anchored watermark. This is the S2 technical disposition for former
`B-DEC-11`; no separate trusted-time service or user decision is required.

## 11. Corrected owner-decision and missing-input ledger

The S1 identifiers are retained for traceability. “Technically resolved” means
only that this correction supplies one implementation-bounding plan; it does
not authorize or prove source/runtime behavior.

| ID | S2 disposition | Exact result or remaining genuine MBI |
| --- | --- | --- |
| `B-DEC-01` issuer identity/rotation | **PARTIAL; AUTHORITY MBI REMAINS** | Manifest schema/config key, no-auto-create loading, Cell tuple and verification path are frozen. Actual signed manifest, issuer/owner descriptors and rotation chain must come from green Identity/authority owners. |
| `B-DEC-02` Lane A wire | **OPEN; CONTRACT MBI** | Lane A review is `0/5/2` NO-GO. Status recovery, deregister, token correlation, origin/audience, transport inspection and issuer rotation must be corrected upstream. No Lane B invention. |
| `B-DEC-03` database/settings | **TECHNICALLY RESOLVED FOR PLAN** | Exact selected SQLite dependency pins, absolute path, PRAGMAs, transaction/read-back and operational proof gate are section 10.1. |
| `B-DEC-04` rollback anchor | **OPEN; PRODUCT/SECURITY MBI** | Exact bound fields are frozen; independent external provider/API/recovery authority is genuinely missing. |
| `B-DEC-05` Agreement provisioning | **PARTIAL; AUTHORITY MBI REMAINS** | Import/verification/Resolver path and future source/docs are frozen. Actual complete target-owner-signed Agreement bytes and revocation state are missing. |
| `B-DEC-06` legacy raw tokens | **TECHNICALLY RESOLVED FOR PLAN** | Fail-closed deactivate, tombstone, clear, read-back and re-enroll; no token migration. |
| `B-DEC-07` encryption key handle | **OPEN; PRODUCT/SECURITY MBI** | Sealed-record lifecycle/AAD/rotation/errors/tests are frozen. Approved key provider/algorithm suite, key versions and recovery authority are missing. |
| `B-DEC-08` cross-Cell atomicity | **TECHNICALLY RESOLVED FOR PLAN** | Canonical success ends in same target transaction; target-owned durable outbox handles later effects. Semantics requiring pre-success remote result remain unavailable. |
| `B-DEC-09` audience projection | **OPEN; LANE A CONTRACT MBI** | Server accepts only the later exact canonical audience plus exact origin `https://haven.digipomps.org`; it does not derive authority from Host. |
| `B-DEC-10` quota/expiry | **OPEN; OPERATIONS PRODUCT MBI** | Cleanup order/fail-closed compaction are frozen. Exact global/per-subject capacity and restore window require approved traffic/restore policy. |
| `B-DEC-11` trusted time | **TECHNICALLY RESOLVED FOR PLAN** | Monotonic elapsed time plus anchored wall-time watermark; no network-time trust root. |
| `B-DEC-12` final integration | **OPEN; `MBI-07`** | Development-admin must later produce exact final commit/tree/diff/artifact manifest. |

No open item is delegated to Kjetil in this packet. The required owner class and
fail-closed behavior are sufficient for the planning handoff.

## 12. Exact future path and owner packet

This is a future allowlist only. No file below may be written without a new
source authorization after independent review.

### 12.1 CellScaffold DeviceIngress server owner

Existing S1 Lane B new source paths retained:

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

Correction additions:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityManifest.swift
Sources/App/Cells/DeviceIngress/DeviceIngressResolverRegistration.swift
Sources/App/Cells/DeviceIngress/DeviceIngressChallengeReplayStateMachine.swift
Sources/App/Cells/DeviceIngress/DeviceIngressTrustedTime.swift
```

Existing source paths permitted to change:

```text
Sources/App/Controllers/DeviceCallbackCapabilityServer.swift
Sources/App/Controllers/VaporDeviceCallback.swift
Sources/App/Support/CanonicalCellRuntimeReadinessStore.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceRegistrationCell.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceCallbackBridgeCell.swift
Sources/App/Cells/ConferenceMVP/Notifications/NotificationModels.swift
```

New tests retained:

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

Correction test additions:

```text
Tests/AppTests/DeviceIngressAuthorityManifestTests.swift
Tests/AppTests/DeviceIngressResolverRegistrationTests.swift
Tests/AppTests/DeviceIngressChallengeReplayStateMachineTests.swift
Tests/AppTests/DeviceIngressProtectedTokenStoreTests.swift
Tests/AppTests/DeviceIngressLegacyTokenMigrationTests.swift
Tests/AppTests/DeviceIngressTrustedTimeTests.swift
Tests/AppTests/DeviceIngressStatusAdmissionReplayTests.swift
```

Existing tests/fixtures permitted:

```text
Tests/AppTests/DeviceCallbackCapabilityServerTests.swift
Tests/AppTests/DeviceRegistrationReadinessTests.swift
Tests/AppTests/NotificationRuntimeReadinessTests.swift
Tests/AppTests/Fixtures/DeviceIngressChallenge.v3.b64
Tests/AppTests/Fixtures/DeviceIngressRequest.v3.b64
Tests/AppTests/Fixtures/DeviceIngressResponse.v3.b64
Tests/AppTests/Fixtures/DeviceIngressSignedContract.v3.b64
```

The four current fixtures remain immutable. New Lane A fixtures are copied or
referenced only after a green producer manifest names exact paths and hashes.

Documentation paths:

```text
Documentation/DeviceCallbackCapabilityServer.md
Documentation/Operations/DeviceIngress_Production_Server_Runbook.md
Documentation/Operations/DeviceIngress_Durable_Admission_Recovery.md
Documentation/Operations/DeviceIngress_Authority_Provisioning.md
Documentation/Operations/DeviceIngress_Protected_Token_Lifecycle.md
```

### 12.2 Development-admin integration owner

Only development-admin owns final bytes for:

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

`Sources/App/configure.swift` may call only the reviewed coordinator. It must
not contain issuer/owner UUIDs, signing fingerprints, Agreements, Grants,
private keys, tokens or fallback authority.

### 12.3 Hard no-touch and collision ownership

- provider owner retains
  `Sources/App/Cells/ConferenceMVP/Notifications/PushProviderAdapter.swift` and
  `Tests/AppTests/NotificationPushProviderTests.swift`;
- `Documentation/DeviceCallbackCapabilityServer.md` remains a server/provider
  collision requiring both reviewers;
- all S0 Identity dirty paths remain no-touch;
- all Identity source and cutover artifacts remain Identity-owner only;
- CellProtocol producer/transport source and fixtures remain Lane A-owner only;
- Binding source/test/project/docs remain Lane C/development-admin only;
- AASA paths remain with their conditional owner; and
- primary dirty worktrees remain hard no-touch.

No wildcard or unnamed “related file” is authorized.

## 13. Required errors and fail-closed readiness

Internal typed server errors are not wire protocol errors:

```text
authorityManifestUnavailable
authorityManifestSignatureInvalid
identityCutoverUnverified
resolverOwnerUnavailable
resolverOwnerMismatch
resolverRegistrationConflict
resolverReadBackMismatch
agreementCatalogUnavailable
agreementMissing
agreementRevoked
challengeLedgerUnavailable
challengeReplayConflict
challengeExpired
challengeReadBackMismatch
admissionLedgerUnavailable
admissionReplayConflict
statusSnapshotUnavailable
statusReplayUnavailable
rollbackAnchorUnavailable
rollbackDetected
trustedTimeUnavailable
tokenKeyUnavailable
tokenAuthenticationFailed
tokenReferenceMismatch
legacyTokenReenrollmentRequired
callbackAtomicityUnavailable
exactResponseUnavailable
```

Public readiness uses stable sanitized reason codes and never interpolates
identity, Cell UUID, Agreement, token, key, payload, database path or canonical
bytes. HTTP non-success remains a carrier failure and never becomes signed
Cell denial/success.

Operation readiness is independent. For example, token-key unavailability may
keep register/provider delivery red while a non-secret authoritative status
read can remain available only if its complete Lane A/Agreement/storage path
is otherwise green.

## 14. Corrected adversarial test packet

No test is run or claimed here.

### 14.1 Per-operation authority

- exact operation/resource/action/capability/access matrix positive tests;
- status `r--s` rejects `rw-s`, `rw--`, `r---` and every other string;
- each `rw-s` mutation rejects `r--s`, `rw--` and broader/substitute Grants;
- correct keypath with wrong permission fails;
- correct permission with wrong keypath fails;
- host, route, topic, token, issuer, catalog or app admin never grants access;
- complete cryptographically valid alternate Agreement fails byte binding;
- absent/revoked/expired/conditional Agreement fails before target mutation.

### 14.2 Resolver/bootstrap/no-static-root

- `addCellResolve`, owner refresh and `makeNewIfNotFound=true` are unreachable
  in production DeviceIngress bootstrap;
- missing/locked/wrong-domain/wrong-key owner fails;
- missing persisted infrastructure Cell fails without creation;
- wrong scope, persistency, lifecycle, UUID, owner or endpoint fails;
- duplicate name/UUID and name-to-different-instance replacement fail;
- environment owner context differing from signed manifest fails;
- service handle without Resolver read-back never marks ready;
- app/Scaffold owner fallback and static Agreement injection fail.

### 14.3 Challenge total-state tests

- first issuance commits/read-backs exact bytes before response;
- crash before commit leaves no externally visible challenge;
- crash after commit returns exact bytes on retry;
- identical active intent returns exact bytes without signer invocation;
- same subject/nonce with different intent fails;
- exact challenge can be consumed by one request/admission only;
- conflicting second request fails;
- expiry blocks consumption and re-sign;
- restart reproduces state/admission/response links;
- issuer rotation never rewrites historical bytes;
- digest-only record is rejected as corrupt;
- compaction before the complete retention/anchor gate fails;
- compacted tombstone preserves intent/nonce uniqueness;
- quota pressure never deletes live evidence.

### 14.4 Admission/status/replay

- every operation persists admission before target work;
- status admission/audit/response commits while registration state is
  byte-identical before/after;
- identical status replay returns exact stored historical bytes;
- a fresh status request reads a new consistent authoritative snapshot;
- volatile projection mutation cannot change signed status;
- missing `registrationID` does not trigger invented subject lookup;
- exact response read-back by internal admission ID succeeds, but no
  unauthorized HTTP route exists;
- committed admission with unavailable response never re-mutates.

### 14.5 Persistence, rollback and trusted time

- every connection attests exact PRAGMAs;
- relative database path, in-memory fallback and unsupported filesystem fail;
- process kill at every transaction boundary;
- host restart and backup/restore rollback;
- WAL/database/parent durability and read-back mismatch;
- external anchor unavailable/lower/different database/digest;
- wall-clock rollback, forward jump and monotonic reset;
- expired evidence never becomes fresh after restart.

### 14.6 Protected-token lifecycle and legacy migration

- key handle absent, locked, unavailable and wrong version;
- wrong algorithm/provider/key metadata;
- ciphertext, nonce, tag and AAD tamper;
- token-record/reference/registration substitution;
- seal succeeds but database transaction rolls back;
- registration commits but sealed-token read-back fails;
- rotation shadow seal fails and old active record remains unchanged;
- successful rewrap switches once and retires old record;
- revoke removes delivery reference before later destruction;
- quarantined record is never delivered;
- no raw token in logs, errors, fixtures, Cell state, backups or snapshots;
- legacy detection never logs/exports token;
- legacy row becomes inactive, tombstone commits and plaintext clears
  atomically;
- migration crash at every boundary is restart-safe;
- migration failure keeps readiness red and never creates authority.

### 14.7 Callback same-target/outbox

- resolve/submit canonical result commits only in target store;
- cross-Cell service failure before target commit yields no success;
- post-commit outbox failure does not rewrite response;
- duplicate worker execution is idempotent;
- response replay never repeats external side effect;
- product path needing synchronous remote result stays unavailable.

## 15. S1 Lane B finding disposition

| Review finding | S2 author disposition | Residual gate |
| --- | --- | --- |
| `P1-01` blanket `rw-s` | **AUTHOR-PROPOSED CLOSED FOR STATIC PLAN** | Section 5 exact operation matrix; Lane A must become green |
| `P1-02` status skips admission state | **AUTHOR-PROPOSED CLOSED FOR STATIC PLAN** | Section 8 commits status admission/audit/response without domain mutation |
| `P1-03` Resolver Cells/bootstrap incomplete | **AUTHOR-PROPOSED CLOSED FOR STATIC PLAN** | Section 6 freezes tuple/order/no-auto-create; actual signed authority inputs remain missing |
| `P1-04` challenge bytes-or-digest contradiction | **AUTHOR-PROPOSED CLOSED FOR STATIC PLAN** | Section 7 has one exact-byte total state machine |
| `P2-01` protected-token lifecycle/tests | **AUTHOR-PROPOSED CLOSED FOR STATIC PLAN** | Sections 9 and 14.6; actual approved key provider remains missing |

All closures are author claims only and require crossed independent review.
They do not close S0, Lane A, Lane C or operational evidence.

## 16. S1 A/C interface reconciliation

### 16.1 Lane A

Consumed without invention:

- three-field protected wrapper and raw canonical response;
- Resolver-selected target/owner/complete signed Agreement;
- current register/resolve/submit `rw-s`;
- proposed status `r--s` and revoke `rw-s`;
- signed challenge-intent/exact-byte replay outline;
- historical replay versus fresh status; and
- bundle/topic/origin planning values.

Still blocked on Lane A review:

- read-only inner-operation inspection ownership;
- status recovery after lost registration ID;
- explicit deregister decision;
- exact origin/audience/TLS/redirect contract;
- ambiguous token-update correlation;
- issuer rotation proof; and
- producer-owned fixture manifest.

No S1 A proposal is promoted to an approved runtime contract here.

### 16.2 Lane C

Lane B supports but does not invent:

- exact response storage keyed by admission ID;
- subject/owner/Agreement/generation-bound status;
- no raw-token client replay requirement;
- challenge-intent/issuer-generation server verification;
- typed post-registration revoke path; and
- neutral byte transport.

Lane C remains blocked because:

- empty local evidence lacks a canonical server discovery selector;
- ambiguous register/submit lacks a reviewed client-accessible response
  read-back operation;
- its challenge-intent/issuer-generation client state is incomplete; and
- its resolve/submit durable states are incomplete.

The server remains capable but does not expose guessed routes or schemas.

## 17. MBI-04 and production disposition

| MBI-04 element | S2 author status |
| --- | --- |
| Exact server topology and no-static-root rule | **CORRECTED STATIC PLAN / REVIEW REQUIRED** |
| Per-operation RWXS | **CORRECTED STATIC PLAN / REVIEW REQUIRED** |
| Resolver Cell tuples/bootstrap | **CORRECTED STATIC PLAN / REVIEW REQUIRED; ACTUAL AUTHORITY INPUT MISSING** |
| Challenge issuance/replay/restart/compaction | **CORRECTED STATIC PLAN / REVIEW REQUIRED** |
| Admission/response replay | **CORRECTED STATIC PLAN / REVIEW REQUIRED** |
| Status durable admission/current snapshot/replay | **CORRECTED STATIC PLAN / BLOCKED ON LANE A RECOVERY SEMANTIC** |
| Revoke/deregister | **BLOCKED ON LANE A; NO INVENTED DEREGISTER** |
| Callback same-target/outbox | **CORRECTED STATIC PLAN / REVIEW REQUIRED** |
| Protected-token lifecycle | **CORRECTED STATIC PLAN / KEY-PROVIDER MBI MISSING** |
| Database settings | **CORRECTED STATIC PLAN / OPERATIONAL PROOF MISSING** |
| Rollback anchor | **PRODUCT/SECURITY MBI MISSING** |
| Capacity/restore window | **OPERATIONS PRODUCT MBI MISSING** |
| Owner/issuer/Agreement bytes | **AUTHORITY MBI MISSING** |

Overall:

```text
MBI-04 STATIC PLAN: AUTHOR-CORRECTED / PARTIAL / INDEPENDENT REVIEW REQUIRED
MBI-04 OPERATIONAL: MISSING / OPEN
```

Production alignment remains:

```text
bundle identifier = org.digipomps.haven
APNS topic         = org.digipomps.haven
public origin      = https://haven.digipomps.org
```

These values grant no authority and prove no production signing or APNS
delivery.

Identity remains separate:

- `c700dbc…` is source provenance only;
- no Identity byte is changed or approved;
- no issuer, owner, device identity or Agreement is created;
- root/owner/recovery continuity remains a prerequisite; and
- the coordinator stays red until an independently green cutover attestation
  and matching owner proofs exist.

`MBI-06` remains **UNAUDITED / MISSING**:

- Team ID;
- App ID capability;
- production profile/certificate;
- effective `aps-environment=production`;
- codesign authority; and
- signed archive.

`MBI-07` remains **MISSING**:

- no final CellProtocol/Identity/CellScaffold/Binding commit/tree;
- no exact final diff/fixture/dependency/provenance manifest.

Associated Domains remains removed unless its separate exact AASA lane is
green.

## 18. Final author decision and review handoff

Author claim adjudication:

| Claim | Author result |
| --- | --- |
| All immutable S0 and six S1 inputs are byte-bound | Supported locally; independent reproduction required |
| S1 B P1/P2 are corrected as one static contract | Author-proposed; independent adversarial review required |
| Every operation uses one blanket Grant | Contradicted |
| Status may skip durable admission/audit | Contradicted |
| Digest-only challenge storage can provide exact replay | Contradicted |
| Resolver may auto-create issuer/owner/Cell | Contradicted |
| Authority manifest or service handle grants an operation | Contradicted |
| Current projection is authoritative status | Contradicted |
| Legacy raw token may be carried forward | Contradicted |
| All owner/product inputs now exist | Contradicted |
| Source or a next material phase is authorized | Contradicted |

Final author decision:

```text
S2 LANE B CORRECTION PACKET: AUTHOR-FROZEN
INDEPENDENT EXACT-BYTE REVIEW REQUIRED: YES
S1 B P0/P1/P2 INPUT: 0/4/1
S1 B FINDING CLOSURES: AUTHOR-PROPOSED ONLY
MBI-04 STATIC PLAN: PARTIAL / REVIEW REQUIRED
MBI-04 OPERATIONAL: MISSING / OPEN
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

The only permissible successor is a separately coordinated independent
exact-byte static review of this one correction packet by a reviewer distinct
from the author. This author stops after freezing and re-attesting the file.
