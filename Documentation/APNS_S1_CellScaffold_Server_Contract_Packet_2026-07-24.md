# APNS S1 CellScaffold server contract packet — planning only

Status: **AUTHOR-FROZEN / LANE B PLAN ONLY / PLAN NO-GO / NEXT PHASE NO-GO**

Packet ID:
`APNS-S1-CELLSCAFFOLD-SERVER-CONTRACT-PACKET/2026-07-24T23:24:58+0200/v1`

Authored at: `2026-07-24T23:24:58+0200` (`CEST`)

Owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md`

Owner of this file: S1 Lane B CellScaffold server-packet author.

This is a static planning artifact. It does not modify or authorize
CellProtocol, CellScaffold, Binding, Identity, Git state, dependencies, builds,
tests, deployment configuration, secrets, devices, APNS, staging or production.
It addresses `MBI-04` only as a proposed server composition and decision packet.
It does not close `MBI-04` operationally.

Author self-review has no credit. This exact file must receive an independent
exact-byte P0/P1 review from someone other than the author before an
administrator can consider any successor scope. No source phase follows from
this packet.

## 1. Exact immutable inputs and inherited verdict

| Input | Exact SHA-256 | Shape | Treatment |
| --- | --- | --- | --- |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | `573` lines / `38154` bytes | Immutable |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | `547` lines / `29346` bytes | Immutable |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | `984` lines / `54678` bytes | Immutable |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | `461` lines / `22485` bytes | Immutable |

Inherited S0-review result:

```text
P0: 0
P1: 2
P2: 1
PLAN NO-GO
NEXT PHASE NO-GO
```

The S0 correction and its review remain immutable. This packet cannot upgrade
their verdict.

## 2. Purpose, goal and claim boundary

Purposes:

- `purpose://access.audit.privacy`: keep device identity, target-Cell
  ownership, signed Agreement/Contract, raw APNS token and private server state
  inside their explicit protection boundaries.
- `purpose://test.acceptance`: define falsifiable server tests for authority,
  admission, replay, mutation, status, revocation, restart and rollback without
  claiming that any test was run.
- `purpose://scaffold.operations`: define one exact server owner/path/no-touch
  packet while retaining fail-closed production readiness and no deployment.

Goal:

> Give the CellScaffold owner one path-exact, adversarially testable design for
> the production DeviceIngress server composition, with every non-derivable
> semantic choice recorded as an owner decision or blocker.

Supported factual claim:

> The immutable current server is a byte-preserving, register-only,
> fail-closed transport foundation; production issuer, durable admission,
> replay, target-Cell authority, status and revocation services are not
> installed.

Author proposal:

> The component, ownership and path plan below is a candidate way to implement
> the missing server composition after Lane A freezes the canonical contract
> and after the independent Identity cutover is green.

Unsupported claims:

- that this design has compiled or passed tests;
- that the proposed storage backend is crash- or rollback-safe;
- that any Agreement or issuer identity is provisioned;
- that status/revoke wire semantics exist;
- that a production APNS provider is ready;
- that signing, archive, deployment or physical delivery proof exists.

## 3. Immutable repository/object facts

### 3.1 Selected source boundaries

| Object | Commit | Tree | Meaning |
| --- | --- | --- | --- |
| CellScaffold common base | `8bb7b31b13dad09734c88217cb01b9d48801ff27` | `16ab2d81098c12975776db2b4acefb2ec75d1ff2` | Shared merge base |
| CellScaffold transport foundation | `38195a233b84d09f66e5ef483800228f857fff2a` | `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` | Inert v3 register carrier |
| CellScaffold route-operation successor | `d2d1b7191d651ad42d172e980ab94a0fd478d07c` | `536531541587b5229b8f325f8935ed11ef85f228` | Rejects unavailable callback operations |
| Selected Identity source boundary | `c700dbc5699ec3a925165d80bc2ec7ad864a1218` | `211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4` | Complete immutable tree only |
| CellProtocol current v3 basis | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` | `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` | Existing register/resolve/submit contract basis |

The final integrated server commit/tree/digest remains `MBI-07` and does not
exist.

The Identity range is the complete `c700…` tree, not a selective commit import:

- `123` commits of provenance;
- `192` endpoint-diff paths;
- `1566` tracked entries in the head tree;
- full-tree `git ls-tree -r -z` SHA-256
  `b1f11701fbdf07b91824f6a6fbe82cf8ee983be1968bde20f12e035672c33824`.

Identity continuity, recovery, owner control and cutover remain a separate
prerequisite. The tree boundary does not grant Identity GO.

### 3.2 Reproduced existing server facts

At `d2d1b719…`:

- `DeviceCallbackTransportContract` defines operations `register`, `resolve`
  and `submit`.
- The HTTP wrapper schema is `haven.device-callback.transport.v3`.
- Its fields are exactly `schema`, `canonicalChallenge`,
  `canonicalRequest` and `protectedBody`.
- `Data` is base64 encoded by Swift `Codable`; decoded bytes are passed
  unchanged.
- Wrapper maximum is `327680` bytes.
- Canonical challenge, canonical request and protected body maxima are each
  `65536` bytes.
- Register is `POST /conference-mvp/api/device/register`.
- Resolve is `POST /conference-mvp/api/device/callback/resolve`.
- Submit is `POST /conference-mvp/api/device/callback/submit`.
- Success returns raw canonical `DeviceIngressOperationResponse` bytes with no
  response wrapper.
- The exact public `Host` must match `DEVICE_CALLBACK_PUBLIC_ORIGIN`.
- Legacy `Authorization` and `X-HAVEN-Device-Callback-Token` are rejected.
- The challenge route deliberately returns unavailable.
- Only register may reach the admission seam.
- Production installs no `DeviceIngressAdmissionService`.
- `DeviceCallbackRegisterAdmissionCompositionRoot.testing` is DEBUG-only.
- Readiness remains red for
  `device_callback_register_admission_unavailable` and
  `device_callback_challenge_issuer_unavailable`.

The HTTP adapter is not authority. It does not resolve or mutate
`DeviceRegistrationCell` or `DeviceCallbackBridgeCell` directly.

### 3.3 Reproduced existing CellProtocol v3 facts

Current literal operation bindings are:

| Operation | Resource | Action | Capability | Access |
| --- | --- | --- | --- | --- |
| `register` | `cell:///DeviceRegistration` | `registerOrUpdateDevice` | `device.registration.write` | `rw-s` |
| `resolve` | `cell:///DeviceCallbackBridge` | `resolveTicket` | `device.callback.resolve` | `rw-s` |
| `submit` | `cell:///DeviceCallbackBridge` | `submitTicketResult` | `device.callback.submit` | `rw-s` |

Current common literals:

```text
purpose = purpose://access.audit.privacy/device-notification-callback
identityDomain = domain:device:notification-callback
challenge maximum lifetime = 300000 ms
request maximum lifetime = 120000 ms
maximum clock skew = 30000 ms
nonce = 32...64 bytes
maximum authority lifetime = 2592000000 ms
```

`DeviceIngressAdmissionService` requires:

- exact expected audience;
- pinned expected challenge-issuer public descriptor;
- Resolver;
- `DeviceIngressDurableAdmissionLedger`.

Its only completion path verifies challenge/request/body, resolves the target
Cell through Resolver, verifies the exact owner-signed Agreement/Contract,
durably commits admission before mutation, invokes
`DeviceIngressAuthorityCell.commitOrReturnExistingDeviceIngressMutation`, and
verifies the exact stored response.

`DeviceIngressAuthorityCell` must:

- return complete canonical signed Agreement evidence without mutation;
- atomically recheck authority/revocation generations;
- commit mutation and exact signed response together; and
- return byte-identical stored response on replay.

Current v3 has no current-status operation and no typed revoke/deregister
operation. It has no host framing for challenge. Those are Lane A inputs, not
Lane B choices.

### 3.4 Existing CellScaffold target-state limits

Current `DeviceRegistrationCell`:

- is registered as persistent at `cell:///DeviceRegistration`;
- uses `rw--` grants for `registerOrUpdateDevice`, `revokeDevice` and
  `validateDeviceAccess`, not v3 `rw-s`;
- persists a `DeviceEndpointRecord` through the generic typed-cell utility;
- stores an optional raw `pushToken` in that record;
- reports only a filtered hash through `asObject`;
- has no `DeviceIngressAuthorityCell` conformance;
- has no same-transaction canonical-response store; and
- has no signed current-status read-back.

Current `DeviceCallbackBridgeCell`:

- is registered as persistent at `cell:///DeviceCallbackBridge`;
- uses `rw--` grants for `resolveTicket` and `submitTicketResult`;
- validates a device through the registration Cell;
- writes callback/outbox state through several Cells;
- has no `DeviceIngressAuthorityCell` conformance;
- has no same-transaction canonical-response store; and
- cannot yet satisfy v3 resolve/submit admission.

A generic successful typed-cell snapshot is not the v3 admission receipt,
atomic mutation-and-response receipt, or rollback-resistant generation proof.

## 4. Lane A interface boundary — input assumptions only

Lane A owns `MBI-01`, `MBI-02` and `MBI-03`. Lane B must not choose their wire
names, schema versions, byte order, HTTP path, result enums, error enums,
fixture names, maxima or rotation semantics.

Lane B may consume a Lane A packet only if it freezes all of:

1. canonical challenge-request bytes and canonical raw challenge-response
   bytes;
2. canonical register protected-body bytes;
3. exact signed Agreement/Contract supply and verification boundary;
4. raw canonical operation-response bytes;
5. current-status operation/resource/action/capability/access/result;
6. revoke/deregister operation/resource/action/capability/access/result;
7. token-rotation binding;
8. issuer-rotation binding;
9. replay and error semantics; and
10. exact producer/consumer fixtures and digests.

The existing three-field HTTP wrapper never contains four independent input
fixtures. Its inputs are challenge, request and protected body; the signed
Agreement/Contract is authority evidence returned by the Resolver-selected
Cell, and the canonical response is raw output. Lane B preserves that
separation and does not repeat the S0 fixture contradiction.

Until Lane A is immutable and independently green:

- challenge remains unavailable;
- current status remains unavailable;
- revoke/deregister remains unavailable;
- token rotation remains indeterminate;
- issuer rotation remains unavailable; and
- resolve/submit remain fail-closed.

## 5. Proposed server topology

The topology is an author proposal, not existing code:

```text
HTTP carrier
  -> shared CellProtocol transport decoder
  -> runtime composition coordinator
  -> persistent challenge issuer Cell/service
  -> CellProtocol DeviceIngressAdmissionService
       -> Resolver
       -> Resolver-selected DeviceRegistration or DeviceCallbackBridge Cell
       -> complete owner-signed Agreement/Contract evidence
       -> durable admission/replay ledger
       -> same target Cell atomic authority recheck + mutation + response
  -> raw canonical response bytes
```

Status and revoke/deregister use the same canonical admission path after Lane A
defines them. HTTP cannot call a status store, registration store, token store
or revocation store directly.

No static admission root is permitted:

- no global/static Cell owner;
- no compiled Agreement, Grant or issuer descriptor used as authority;
- no process-local dictionary used as durable admission/replay truth;
- no route-selected Cell, owner, subject or operation;
- no auto-created owner, issuer, subject, Agreement or credential;
- no application-admin/Scaffold-owner fallback;
- no bearer or raw token as authority.

`Application.storage` may later hold only a non-authoritative runtime service
handle after the coordinator has re-opened and verified all persistent
dependencies. Every request still executes Resolver selection and target-Cell
Agreement/revocation verification. Installing a handle alone must never mark
readiness green.

## 6. Proposed components

All names and paths in this section are proposed owner decisions. They do not
assert that implementation exists.

### 6.1 Challenge issuer Cell and service

Proposed Cell:

```text
cell:///DeviceIngressChallengeIssuer
Sources/App/Cells/DeviceIngress/DeviceIngressChallengeIssuerCell.swift
```

Responsibilities:

- load exactly one pre-existing issuer identity from the authenticated vault;
- verify its UUID, signing-key fingerprint, domain and rotation generation
  against a separately signed production composition manifest;
- refuse `makeNewIfNotFound`;
- accept only the exact Lane A challenge-request contract;
- resolve the requested target Cell through Resolver before issuance;
- require a current, owner-issued Agreement/Contract for the exact subject,
  target Cell, operation, purpose, audience and content policy;
- issue through the Lane A/CellProtocol canonical challenge factory;
- durably record the issued canonical bytes or required canonical digest set
  before returning them;
- enforce bounded TTL, clock skew, per-subject rate, global capacity and
  expiry reclamation;
- never return private key material or log subject, nonce, Agreement bytes or
  canonical payload bytes; and
- fail closed on issuer mismatch, rotation ambiguity, clock rollback,
  storage unavailability or read-back mismatch.

The Cell is an issuer and audit boundary, not an admission authority. A signed
challenge grants no operation.

### 6.2 Authority catalog Cell

Proposed Cell:

```text
cell:///DeviceIngressAuthorityCatalog
Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityCatalogCell.swift
```

Responsibilities:

- store complete immutable owner-issued canonical Agreement/Contract bytes;
- index only by target Cell, subject identity, operation and monotonic
  authority/revocation generation;
- expose evidence only to the Resolver-selected target Cell;
- verify owner signature, subject, domain, exact
  `DeviceIngressAgreementScope.grantKeypath()`, `rw-s`, purpose, audience,
  content policy, time window and generation at every use;
- never mint, auto-renew or broaden an Agreement;
- never treat a stored UUID/hash/reference as authority;
- persist revocation ledger and generation with read-after-write; and
- reject conditions while current CellProtocol reports
  `agreementConditionsUnsupported`.

This catalog is not a host-wide admission root. The selected target Cell owns
the final decision and returns the complete evidence to CellProtocol.

### 6.3 Durable admission/replay store

Proposed service:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressAdmissionLedgerStore.swift
```

It implements `DeviceIngressDurableAdmissionLedger` and must:

- commit the complete canonical admission record before target mutation;
- enforce unique challenge, nonce, request and admission identities;
- enforce monotonic authority and revocation generations;
- persist receipt sequence and timestamp;
- perform post-commit read-back and byte/hash comparison;
- return the same persisted record/receipt after process or host restart;
- return `.generationRollback` on a lower watermark;
- return `.unavailable` on any ambiguous transaction, partial record, corrupt
  row, missing read-back, database error or rollback-anchor disagreement;
- bound record size, total rows, per-subject rows and expiry cleanup; and
- store no raw APNS token.

### 6.4 Resolver-selected target-Cell authority

Proposed shared helper:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressTargetAuthority.swift
```

Proposed target adapters:

```text
Sources/App/Cells/ConferenceMVP/Notifications/DeviceRegistrationIngressAuthority.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceCallbackBridgeIngressAuthority.swift
```

The exact target objects remain:

```text
cell:///DeviceRegistration
cell:///DeviceCallbackBridge
```

The adapters may not replace those Resolver targets with a service singleton.
They provide `DeviceIngressAuthorityCell` behavior on the actual selected Cell:

- obtain complete Agreement evidence from the authority catalog;
- compare target object UUID and current owner descriptor;
- atomically CAS current authority/revocation generations;
- perform only the operation named by the admitted canonical request;
- write the mutation record, operation result, mutation receipt and exact
  signed canonical response in one transaction;
- return the stored canonical response without re-signing on replay; and
- deny any request whose legacy participant/device metadata disagrees with the
  signed device subject.

### 6.5 Registration mutation and protected token store

Proposed services:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressRegistrationMutationStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressProtectedTokenStore.swift
```

Rules:

- the signed subject identity UUID and signing-key fingerprint are the
  authoritative device key;
- `participantId` and legacy `deviceId` are non-authoritative metadata only;
- raw APNS token is accepted only inside the canonical protected body;
- raw token is encrypted at rest under an approved server-side key handle;
- no raw token enters `UserDefaults`, `ValueType` state, `FlowElement`,
  diagnostics, logs, receipts, hashes exposed to clients, fixtures or this
  documentation;
- a non-secret token digest/generation may be returned only if Lane A defines
  and signs that exact field;
- registration state, generation, token-vault reference, mutation receipt and
  canonical response commit atomically;
- an unknown legacy raw-token row never becomes active automatically; and
- migration cannot create a new device identity, consent or Agreement.

The existing `DeviceEndpointRecord.pushToken` persistence is therefore a
release blocker until a reviewed migration/rejection decision exists.

### 6.6 Callback mutation store

Proposed service:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressCallbackMutationStore.swift
```

It owns the same-Cell durable resolve/submit mutation and canonical response.
It must not delegate semantic success to `NotificationOutboxCell`,
`ContactEndpointCell`, an HTTP status or a transient bridge callback. Any
cross-Cell action required to resolve or submit must have an explicit
idempotent transaction/outbox contract and a signed final target-Cell receipt.
That cross-Cell atomicity decision is open in `B-DEC-08`.

### 6.7 Status and revocation services

Reserved proposed paths:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressStatusService.swift
Sources/App/Cells/DeviceIngress/DeviceIngressRevocationService.swift
```

No operation, schema or route is proposed here. After Lane A freezes them:

- current status must execute against the Resolver-selected registration Cell;
- it must return fresh owner-signed read-back bound to the subject, target,
  Agreement, authority generation, revocation ledger/generation and token
  rotation generation;
- historical registration response and local absence must not satisfy it;
- revoke/deregister must create a durable mutation receipt and local/server
  tombstone, increment the relevant generation, invalidate active consent,
  and be followed by fresh signed current status;
- identical replay returns byte-identical response;
- conflicting replay fails closed; and
- rollback or lower generation fails closed.

### 6.8 Composition coordinator and readiness

Proposed files:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressCompositionCoordinator.swift
Sources/App/Cells/DeviceIngress/DeviceIngressRuntimeReadiness.swift
```

The coordinator orders startup:

1. observe a separately green Identity cutover attestation;
2. verify exact executable revision and dependency artifact;
3. open the chosen durable database without memory fallback;
4. verify schema and durability settings;
5. verify rollback-resistant generation anchor;
6. load the existing issuer identity without creating it;
7. read back issuer descriptor and rotation state;
8. load and verify the owner-issued Agreement catalog;
9. resolve both target Cells and verify exact owner descriptors;
10. recover challenge, admission, mutation, response and tombstone stores;
11. verify monotonic watermarks and byte-identical response read-back;
12. construct `DeviceIngressAdmissionService`;
13. install only a non-authoritative service handle; and
14. keep every operation red until its own dependencies are green.

Shutdown must flush and close stores without converting an incomplete flush
into success. Restart repeats all checks before readiness can become green.

## 7. Persistence model and durability contract

### 7.1 Current fact and proposed starting backend

The selected `c700…` tree already depends on Fluent and
`FluentSQLiteDriver`; `Sources/App/configure.swift` selects a SQLite database
at `SQLITE_DATABASE_PATH` or `db.sqlite`.

Using that database for DeviceIngress is only a proposed starting point. The
current source does not prove the required crash or rollback guarantees.

Proposed exact model/migration files:

```text
Sources/App/Models/DeviceIngressPersistentModels.swift
Sources/App/Migrations/CreateDeviceIngressPersistence.swift
Tests/AppTests/DeviceIngressPersistenceMigrationTests.swift
```

Proposed tables/record families:

- issuer descriptor and issuer rotation watermark;
- issued challenge and challenge capacity ledger;
- authority/Agreement record and revocation watermark;
- admission record and admission receipt;
- target mutation record and mutation receipt;
- exact canonical operation response bytes;
- registration state and encrypted token-vault reference;
- current-status projection;
- deregistration tombstone;
- callback resolve/submit result and outbox state; and
- monotonic generation anchor projection.

### 7.2 Transaction boundaries

Required transaction boundaries:

1. **Challenge issue:** issued record plus exact canonical challenge response
   is durable and read back before response.
2. **Admission:** admission record plus admission receipt is durable and read
   back before target mutation.
3. **Target mutation:** authority/revocation CAS, domain mutation, operation
   result, mutation receipt and exact canonical response bytes commit in one
   target-Cell transaction.
4. **Replay:** stored response bytes are read, hash-checked and returned; they
   are never reconstructed or re-signed.
5. **Revoke/deregister:** generation increment, inactive/tombstone state,
   mutation receipt and exact response commit together.
6. **Status:** read one current consistent generation snapshot and sign the
   Lane A response without mutating admission state.

Crash after admission but before target mutation is recoverable only by replay
of the same admission into the same target Cell. Crash after target transaction
commit must return the stored response. Any state in which commit status cannot
be proved is unavailable, not success.

### 7.3 Required storage proof

Before any later source candidate can claim durability, its tests and
operations runbook must prove:

- database transaction atomicity for the selected engine/version;
- unique constraints for all replay identities;
- full synchronous durability settings or an equivalent reviewed contract;
- database file and parent-directory durability where applicable;
- post-commit read-back;
- process-kill and host-restart recovery;
- bounded cleanup that cannot delete unexpired evidence;
- backup/restore rollback detection;
- schema migration forward/rollback behavior; and
- no fallback to in-memory state.

Current SQLite configuration, a Fluent `save()`, generic Cell persistence, WAL
presence or a passing unit test alone does not prove those claims.

## 8. Agreement, capability and Resolver enforcement

### 8.1 Protected resources/actions

Existing protected actions are exactly those in section 3.3. Their required
grant is the exact hash-derived keypath from
`DeviceIngressAgreementScope(request:).grantKeypath()` with permission
`rw-s`.

Status and revoke/deregister protected resources/actions remain Lane A
decisions. Lane B must not reuse `revokeDevice`, `state` or
`validateDeviceAccess` as an unsigned shortcut.

### 8.2 Requester proof path

The requester must supply:

- persistent public identity in
  `domain:device:notification-callback`;
- requester-signed canonical request;
- vault-context domain binding with `grantsAuthority=false`;
- exact issuer-signed challenge;
- exact subject-bound authority reference; and
- protected body bound by digest.

Neither domain binding nor possession of an APNS token grants authority.

### 8.3 Authority path

The only allowed path is:

```text
request bytes
  -> CellProtocol verification
  -> Resolver resolves exact target Cell for requester
  -> target object UUID and owner descriptor match authority reference
  -> target Cell returns complete canonical owner-signed Contract
  -> CellProtocol verifies issuer/subject/domain/time/exact hashed Grant
  -> admission ledger commits
  -> same target Cell rechecks generation and commits
```

Forbidden authority substitutes:

- HTTP route or method;
- public origin or Host header;
- APNS topic;
- device ID, participant ID or token;
- app/server admin;
- Scaffold owner by default;
- issuer identity alone;
- Agreement UUID/hash without complete canonical signed bytes;
- process-local cache or readiness flag;
- static/compiled Grant;
- testing service;
- auto-provisioning.

### 8.4 Agreement provisioning

This packet does not provision an Agreement. A later owner-controlled
provisioning ceremony must:

- identify the exact existing target Cell and owner key;
- identify the exact device subject key;
- construct the exact Lane A operation scope;
- grant only its hash-derived keypath with the required permission;
- bind production audience and purpose;
- bind content policy and expiry;
- sign with the target owner;
- persist complete canonical bytes and monotonic generations;
- perform read-back; and
- produce sanitized evidence without exposing private keys or raw APNS token.

The server must refuse startup if required authority is absent. It must not
create the missing owner, subject, Cell, Agreement or credential.

## 9. Operation plan and fail-closed states

| Operation | Current immutable state | Proposed server completion | Gate |
| --- | --- | --- | --- |
| Challenge | HTTP route returns unavailable | Persistent issuer Cell, authority precheck, bounded durable issue ledger, raw canonical response | Lane A MBI-03 + issuer decisions |
| Register | Transport can call only an uninstalled service | Resolver-selected registration Cell, signed Agreement, admission commit, atomic registration/token/response commit | Storage, authority and migration decisions |
| Resolve | Route rejects before admission | Same admission service and callback target Cell; durable ticket read/result and exact response | Lane A existing contract plus cross-Cell decision |
| Submit | Route rejects before admission | Same admission service and callback target Cell; durable result/tombstone/outbox and exact response | Lane A existing contract plus cross-Cell decision |
| Current status | No operation exists | Fresh signed target-Cell read-back; no historical/local substitute | Lane A MBI-01 |
| Revoke/deregister | No operation exists | Durable generation/tombstone mutation plus signed status read-back | Lane A MBI-02 |
| Token rotation | No canonical reconciliation | Register/update plus signed current generation; raw token never returned | Lane A decision |
| Issuer rotation | No complete rotation contract | Monotonic issuer transition proof and dual-bound transition window only if Lane A defines it | Lane A decision |

Proposed stable readiness diagnostics:

```text
device_callback_contract_unavailable
device_callback_identity_cutover_unverified
device_callback_shared_transport_unavailable
device_callback_challenge_issuer_unavailable
device_callback_challenge_ledger_unavailable
device_callback_authority_catalog_unavailable
device_callback_generation_anchor_unavailable
device_callback_admission_ledger_unavailable
device_callback_target_registration_cell_unavailable
device_callback_target_callback_cell_unavailable
device_callback_register_admission_unavailable
device_callback_resolve_admission_unavailable
device_callback_submit_admission_unavailable
device_callback_status_unavailable
device_callback_revocation_unavailable
device_callback_replay_readback_unavailable
device_callback_token_store_unavailable
device_callback_exact_revision_unavailable
```

These reason strings are author proposals for sanitized readiness. They carry
no identity, UUID, path, Agreement, token, key, payload or database error.
Lane A owns operation-level canonical errors; HTTP must not convert a readiness
diagnostic into a signed protocol result.

Production readiness remains red if any required component is red. A source
file, installed route, open database, service handle or registered Cell is not
enough.

## 10. Exact future output path packet

This is a proposed future allowlist, not write authorization. Any source task
requires a separate ADMIN-GO after Lane A and this packet both pass independent
review.

### 10.1 Lane B DeviceIngress server owner

New source paths:

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

Existing source paths:

```text
Sources/App/Controllers/DeviceCallbackCapabilityServer.swift
Sources/App/Controllers/VaporDeviceCallback.swift
Sources/App/Support/CanonicalCellRuntimeReadinessStore.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceRegistrationCell.swift
Sources/App/Cells/ConferenceMVP/Notifications/DeviceCallbackBridgeCell.swift
Sources/App/Cells/ConferenceMVP/Notifications/NotificationModels.swift
```

New test paths:

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

Existing test paths:

```text
Tests/AppTests/DeviceCallbackCapabilityServerTests.swift
Tests/AppTests/DeviceRegistrationReadinessTests.swift
Tests/AppTests/NotificationRuntimeReadinessTests.swift
Tests/AppTests/Fixtures/DeviceIngressChallenge.v3.b64
Tests/AppTests/Fixtures/DeviceIngressRequest.v3.b64
Tests/AppTests/Fixtures/DeviceIngressResponse.v3.b64
Tests/AppTests/Fixtures/DeviceIngressSignedContract.v3.b64
```

The four existing fixtures are immutable current-v3 inputs. New status,
revoke, challenge-framing or rotation fixture paths are not named because Lane
A owns them. They must be added by an exact successor packet, never inferred.

Documentation:

```text
Documentation/DeviceCallbackCapabilityServer.md
Documentation/Operations/DeviceIngress_Production_Server_Runbook.md
Documentation/Operations/DeviceIngress_Durable_Admission_Recovery.md
Documentation/Operations/DeviceIngress_Authority_Provisioning.md
```

### 10.2 Development-admin integration owner

Only the development-admin integrator may reconcile these existing collision,
dependency and production-config files after every owning lane is green:

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

The integrator must:

- start from exact `c700…` full tree;
- apply/reconcile the 25-path transport range and 2-path route successor
  path-by-path;
- remove every legacy `DEVICE_CALLBACK_INGRESS_TOKEN` dependency;
- pin the exact independently reviewed Lane A/shared-transport artifact;
- preserve unrelated Identity bytes;
- record every conflict and final byte owner; and
- produce the still-missing final commit/tree/diff digest under `MBI-07`.

No package resolution, configuration edit or integration is authorized here.

### 10.3 Separate APNS provider owner — hard no-touch

The provider WIP remains excluded:

```text
Documentation/DeviceCallbackCapabilityServer.md
Sources/App/Cells/ConferenceMVP/Notifications/PushProviderAdapter.swift
Tests/AppTests/NotificationPushProviderTests.swift
```

Its tracked patch digest remains:
`a1bcc57a59f9bbcf5f545fc51a43efd13599f36451186981dbc607d0afa80963`.

`Documentation/DeviceCallbackCapabilityServer.md` is a declared collision.
Final bytes require both DeviceIngress and provider reviewers. Lane B must not
copy the WIP or inspect credentials.

### 10.4 Identity owner — immutable input/no write

The Identity owner owns the complete immutable `c700…` tree and its separate
cutover evidence. Lane B owns no Identity source path. The 11 dirty Identity
worktree paths and tracked patch
`96bd1aa0ddba65e094f0a713c5a5f95431c79bd0a0915827d1ba008b922a6feb`
remain hard excluded.

## 11. Collision and no-touch matrix

| Surface | Exact collision/path | Owner | Rule |
| --- | --- | --- | --- |
| Identity full tree × transport | `Documentation/Staging_Deployment.md`; `Package.swift`; `Sources/App/configure.swift`; `Sources/ScaffoldKit/Application+AuthSecuritySettings.swift`; `Tests/AppTests/JWTAuthRoutesTests.swift`; `Tests/AppTests/TopUpCheckoutTests.swift`; `docker-compose.yml`; `scripts/cellscaffold-container-controller.py`; `scripts/tests/test_cellscaffold_container_controller.py` | Development-admin integrator | Reconcile from `c700…`; Identity + transport reviews |
| Transport × route fix | `Sources/App/Controllers/VaporDeviceCallback.swift`; `Tests/AppTests/DeviceCallbackCapabilityServerTests.swift` | Lane B server owner after integrator supplies exact base | Route fix must remain ordered after transport |
| Transport × provider WIP | `Documentation/DeviceCallbackCapabilityServer.md`; `Tests/AppTests/NotificationPushProviderTests.swift` | Development-admin integrator for final bytes | Both reviewers; provider WIP remains excluded |
| Lane B target Cell × legacy state | `DeviceRegistrationCell.swift`; `DeviceCallbackBridgeCell.swift`; `NotificationModels.swift` | Lane B server owner | Migration/rejection decision before edits |
| Lane A shared transport × server | `Package.swift`; `Package.resolved`; controller and existing fixture paths | Development-admin integrator | Exact artifact/digest only; no local mutable package |
| Primary dirty CellScaffold | every path in S0 section 7.4 | Hard no-touch | No implementation in primary checkout; no cleanup/copy |
| Identity dirty bytes | all 11 S0 section 7.1 paths | Hard no-touch | Only committed tree is input |
| AASA candidate | all seven `M-CS-AASA-COMMIT` paths | Deferred AASA owner | Associated Domains remains removed unless separately green |
| This Lane B packet | only this documentation path | Lane B author | Sole current output; stop after freeze |

No path wildcard such as “relevant files/tests/docs” is authorized.

## 12. Adversarial and negative test plan

No test is run or claimed by this packet.

### 12.1 Challenge/issuer

- missing issuer identity;
- issuer auto-create attempt;
- wrong UUID/fingerprint/domain;
- stale, future or expired issuer generation;
- unproved issuer rotation;
- challenge subject differs from Agreement subject;
- wrong target Cell/owner/Agreement hash;
- wrong purpose, audience or origin;
- nonce outside `32...64` bytes;
- nonce collision;
- challenge lifetime over `300000` ms;
- issued-in-future beyond `30000` ms;
- clock rollback;
- store full/quota exceeded;
- challenge persisted but response read-back fails;
- crash before commit, after commit and before response;
- restart returns an unverified/stale issuer;
- logs/readiness contain no canonical bytes or identity material.

### 12.2 Resolver/Agreement/capability

- no Resolver;
- unresolved target Cell;
- wrong target object UUID;
- wrong target owner UUID/key fingerprint;
- route-selected alternate Cell;
- target does not conform to `DeviceIngressAuthorityCell`;
- missing complete canonical Contract;
- non-canonical or signature-invalid Contract;
- wrong issuer, subject or identity domain;
- expired/not-yet-valid Contract;
- conditions present while unsupported;
- wrong hash-derived Grant keypath;
- `rw--`, `-w--`, `r---` or `rwxs` mismatch instead of exact required access;
- stale/lower authority generation;
- stale/lower revocation generation;
- Agreement UUID/hash without full bytes;
- Scaffold-owner/admin/static Agreement fallback;
- host, bundle, topic, token or device ID treated as authority.

### 12.3 Admission/replay

- malformed/non-canonical challenge or request;
- body empty, oversized or digest mismatch;
- challenge digest mismatch;
- request outside challenge or authority lifetime;
- duplicate challenge with different request;
- duplicate nonce;
- duplicate request with different admission;
- duplicate admission with different record;
- identical replay before and after process restart;
- concurrent identical writers return one byte-identical response;
- concurrent conflicting writers fail closed;
- admission commit ambiguous;
- admission record/receipt hash mismatch;
- sequence zero/regression/overflow;
- database unavailable/corrupt/read-only/full;
- partial row or missing receipt;
- rollback to older backup;
- cleanup racing live admission;
- replay never re-signs or remutates.

### 12.4 Target mutation/read-back

- admission receipt does not match target;
- Agreement revoked between admission and mutation;
- authority generation changes between admission and mutation;
- target mutation commits without response;
- response commits without mutation;
- mutation receipt/result/response digest mismatch;
- exact response absent after restart;
- historical register response used as current status;
- copied response for another device identity;
- raw token appears in response, state projection, FlowElement, log or fixture;
- target storage unavailable after admission;
- crash at every transaction boundary;
- same admission resolves to a replacement Cell object.

### 12.5 Status/revoke/rotation

- status operation absent or Lane A digest mismatch;
- local absence reported as deregistered;
- historical receipt reported as active;
- status signed by wrong owner;
- status generation lower than local/server watermark;
- revoke without active Agreement;
- revoke updates UI only;
- revoke tombstone without server mutation receipt;
- revoke receipt without fresh current read-back;
- identical revoke replay changes generation twice;
- conflicting revoke/register race;
- register/token rotation after revoke without a newly authorized generation;
- raw token returned during status/rotation;
- issuer rotation accepted without Lane A transition proof.

### 12.6 Restart, durability and rollback

- graceful process restart;
- forced process kill before/after each commit boundary;
- host restart;
- database WAL/main-file combinations from crash windows;
- database copy restored to an older generation;
- authority catalog newer than admission store and vice versa;
- registration store newer than mutation response store and vice versa;
- missing/corrupt generation anchor;
- migration interrupted and restarted;
- multiple processes against the same database;
- lock timeout/busy database;
- cleanup/expiry during restart;
- exact readiness remains red until every read-back succeeds.

### 12.7 HTTP neutrality and privacy

- wrong method/path operation rejected before admission;
- unknown wrapper schema, missing/empty field, malformed base64 and oversize;
- legacy bearer/header rejected;
- multiple Host or authorization headers rejected;
- public origin must be exactly `https://haven.digipomps.org`;
- HTTP status alone never becomes protocol success;
- error response is generic/no-store and contains no private diagnostics;
- rate limiter cannot create unbounded memory or persistent rows;
- no server secret, private key, raw token, canonical signed payload or
  unsanitized identity appears in logs or test output.

## 13. Owner decision and blocker ledger

These are exact missing decisions. They are not silently resolved by the
author.

| ID | Decision/blocker | Required owner | Required exact output | Gate |
| --- | --- | --- | --- | --- |
| `B-DEC-01` | Exact production challenge-issuer identity domain, UUID/fingerprint manifest and rotation root | Identity cutover owner + CellScaffold authority owner | Signed sanitized manifest contract and exact source/config paths | Blocks issuer |
| `B-DEC-02` | Exact Lane A challenge request/response and status/revoke/rotation semantics | Lane A CellProtocol owner | Immutable packet/artifact/fixtures/digests | Blocks all missing operations |
| `B-DEC-03` | Production durability backend and settings | CellScaffold storage owner | Engine/version, path/config, sync/journal/locking/read-back contract | Blocks ledger |
| `B-DEC-04` | Rollback-resistant monotonic anchor | CellScaffold security/storage owner | Exact authority, storage path/API and failure contract | Blocks every generation claim |
| `B-DEC-05` | Owner-controlled Agreement provisioning and revocation ceremony | Target-Cell owner + security reviewer | Exact signed Contract source, catalog import path and sanitized receipt | Blocks authority |
| `B-DEC-06` | Existing raw `pushToken` rows | Data/notification owner + privacy reviewer | Exact migrate, revoke-and-reenroll, or reject decision; never silent carry-forward | Blocks register |
| `B-DEC-07` | Encryption-at-rest key handle for raw APNS token | Security/operations owner | Approved secret-store handle and rotation/recovery contract; no secret bytes in repo | Blocks token store |
| `B-DEC-08` | Cross-Cell atomicity for resolve/submit and existing outbox/contact flows | Callback Cell owner + CellProtocol reviewer | Exact idempotent outbox/receipt/read-back contract and paths | Blocks resolve/submit |
| `B-DEC-09` | Exact production expected-audience literal projection from origin | Lane A transport/contract owner | Full-origin-versus-authority decision in canonical bytes | Blocks challenge/admission |
| `B-DEC-10` | Persistent quota/expiry policy for challenge and admission stores | Security/operations owner | Exact maxima, cleanup order and fail-closed behavior | Blocks DoS readiness |
| `B-DEC-11` | Trusted time/clock rollback policy | Security/operations owner | Exact clock source, skew and rollback behavior | Blocks freshness proof |
| `B-DEC-12` | Final integration base/conflict bytes and revision | Development administrator | Final commit/tree/diff/manifest under `MBI-07` | Blocks build/archive |

`B-DEC-03` is not answered merely because current source uses SQLite.
`B-DEC-04` is not answered by a counter stored in the same rollbackable
database. `B-DEC-05` is not answered by a host environment variable.

## 14. Production binding and lane separation

Frozen intended production alignment:

```text
bundle identifier = org.digipomps.haven
APNS topic = org.digipomps.haven
public origin = https://haven.digipomps.org
```

Server requirements:

- `DEVICE_CALLBACK_PUBLIC_ORIGIN`, if retained, must resolve to exactly
  `https://haven.digipomps.org`;
- the shared transport must not infer authority from the origin or Host;
- the APNS provider, when separately reviewed, must use topic
  `org.digipomps.haven`;
- the device challenge/request audience must equal Lane A's exact canonical
  decision derived from the production origin;
- no staging/sandbox origin or topic may satisfy production readiness.

Identity remains separate:

- this packet does not inspect, repair, migrate or cut over Identity;
- it does not make a new issuer/owner/device identity;
- `c700…` is source provenance only;
- a separately green Identity cutover is the first coordinator prerequisite.

`MBI-06` remains missing/unaudited:

- Apple Team ID;
- App ID capability;
- distribution profile/certificate;
- effective production entitlement;
- codesign authority;
- signed archive.

`MBI-07` remains missing:

- no integrated CellProtocol/Identity/CellScaffold/Binding output exists;
- no final tree, diff or composition digest exists.

Associated Domains remains removed unless the separate path-exact AASA lane
becomes green. It is not required to define the DeviceIngress server authority.

## 15. Evidence classes and acceptance boundary

| Evidence class | This packet provides | This packet does not provide |
| --- | --- | --- |
| Static plan | Exact proposed components, paths, owners, tests and blockers | Source implementation |
| Immutable source observation | Existing v3/server behavior at named objects | Integrated source |
| Contract proof | Lane A prerequisites identified | Lane A successor |
| Persistence proof | Required transaction/restart/rollback tests | Tested storage |
| Identity proof | Separate prerequisite recorded | Identity continuity/cutover |
| Production signing proof | Bundle/topic/origin intention only | `MBI-06` |
| Integrated provenance | Required owner named | `MBI-07` |
| Runtime/APNS/device proof | None | Deployment, APNS acceptance, physical receipt |

The production acceptance claim remains an `allOf` claim. A static plan cannot
substitute for any later evidence class.

## 16. Finding disposition and frozen decision

S0 `P1-S0-02` identified incomplete production output paths through
`MBI-01`–`MBI-05`. This Lane B packet:

- gives `MBI-04` a path-exact proposed server composition;
- records every current unresolved server decision as `B-DEC-01`–`B-DEC-12`;
- does not claim those decisions are approved;
- leaves Lane A `MBI-01`–`MBI-03` untouched;
- leaves Binding `MBI-05` untouched;
- leaves Apple `MBI-06` missing/unaudited;
- leaves integrated output `MBI-07` missing;
- keeps Identity cutover separate; and
- authorizes no source.

Author assessment:

```text
LANE B PACKET SHAPE: READY FOR INDEPENDENT STATIC REVIEW
MBI-04 PLAN: PROPOSED, NOT OPERATIONALLY CLOSED
SOURCE AUTHORIZATION: NO
PLAN: NO-GO
NEXT PHASE: NO-GO
PRODUCTION: NO-GO
```

Reasons:

1. author self-review has no credit;
2. Lane A inputs are not yet independently frozen for consumption here;
3. the exact issuer, persistence, rollback-anchor, Agreement-provisioning,
   legacy-token and cross-Cell decisions remain open;
4. Identity cutover remains separately gated;
5. `MBI-06` and `MBI-07` remain missing; and
6. no source, build, signing, runtime or device evidence exists.

The only permissible continuation is a separately authorized exact-byte
independent static review of this file by a reviewer distinct from the author.
That review cannot open a source, Git, build, test, deployment, signing, APNS
or device phase.
