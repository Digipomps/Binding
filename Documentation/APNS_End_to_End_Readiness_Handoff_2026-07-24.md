# APNS end-to-end readiness handoff — 2026-07-24

Observed at: `2026-07-24T19:42:20Z` (`2026-07-24T21:42:20+02:00`)

Status: **BLOCKED / NO-GO for build, install, registration, APNS, staging, signing,
upload, or device mutation.**

This is a sanitized, read-only/static evidence snapshot. It is not a delivery
receipt and must not be cited as evidence that a device is registered, that
Apple accepted a provider request, that an iPad received a notification, or
that a Binding callback completed.

No APNS correlation ID has been assigned. The literal status is:
`NOT_ASSIGNED_NO_TEST_AUTHORIZED`.

## Formål and Goals

| purposeRef | Goal | Current status |
| --- | --- | --- |
| `purpose://test.acceptance` | Separately prove one consented physical iPad registration, one APNS provider acceptance, visible iPad receipt, signed callback/read-back, and restart continuity for one exact build and one exact server revision. | **blocked** |
| `purpose://access.audit.privacy` | Keep raw APNS tokens, private keys, private route data, and stable device identity out of handoffs/logs; admit only domain-scoped identity plus explicit owner/Agreement authority. | **satisfied for this static audit; unproved operationally** |
| `purpose://scaffold.operations` | Run no mutation until one exact reviewed client/server/protocol/identity composition has red/green readiness and a separately authorized observation window. | **satisfied for this iteration; next operational gate blocked** |

## Scope and evidence policy

- Read only Git objects, source files, documentation, source entitlements, and
  sanitized worktree metadata.
- Do not inspect runtime token stores, identity-vault contents, APNS key
  material, staging environment values, device registration records, or
  provider logs.
- Prior test counts are reported only as dated coordination evidence. No build
  or test was run for this snapshot.
- A source-level readiness guard is not proof of its runtime inputs.
- HTTP success is not APNS provider acceptance.
- APNS provider acceptance is not device delivery.
- Device delivery is not callback/read-back continuity.
- Identity continuity is a prerequisite and authority boundary, not APNS
  delivery evidence.

## Exact local source snapshot

### Binding

- Observer checkout:
  - path: `/Users/kjetil/.codex/worktrees/50d3/Binding`
  - revision before this handoff file: `6071ca11c207b537ce52ee4aafb686d9a4d955ae`
  - detached
- Most advanced committed DeviceIngress client:
  - path: `/private/tmp/haven-binding-device-ingress-v3-p1-fix-20260721/Binding`
  - branch: `codex/binding-device-ingress-v3-p1-fix-20260721`
  - revision: `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c`
  - clean at observation
  - subject: `Establish inert DeviceIngress client foundation (no transport activation)`
- Current APNS V1 client WIP:
  - path: `/private/tmp/haven-binding-v1-push-20260723`
  - branch: `codex/binding-v1-push-runtime-20260723`
  - base revision: `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c`
  - uncommitted: four files, 37 insertions and one deletion
  - the WIP adds typed operational blockers and honest UI copy; it does not
    activate transport
  - `git diff --check` passed at observation
- Apple M1 identifiers/origin:
  - revision: `2d2412090a65e101435ea91c8ea36bc060d3c768`
  - clean at observation
  - diverges from `fefcc3fc`; neither is an ancestor of the other
- Catalog/universal-link WIP:
  - path: `/private/tmp/haven-binding-v1-catalog-20260723`
  - base revision: `2d2412090a65e101435ea91c8ea36bc060d3c768`
  - uncommitted and not part of the DeviceIngress client snapshot
  - `git diff --check` passed at observation
- The DeviceIngress client project resolves CellProtocol through the local
  package path `../CellProtocol`. That path currently points to the mutable,
  dirty checkout at revision
  `61ffc8990afd34a601231e332e423b905e04535f`, which does not expose the
  DeviceIngress v3 source symbols. It is not a reproducible dependency for a
  future build.
- The observed Xcode `Package.resolved` file is unchanged and has SHA-256
  `5be9c01ddcc0c6885144b04a16b3a8e99bdc0729c67e88a31f181fc88d7b5283`,
  but CellProtocol is an Xcode local-package reference and is therefore not
  proven by that hash.

### CellProtocol

- Canonical DeviceIngress v3 source commit:
  `79ce4f84666fedc446a1c80ab8adce1e7e3898e0`
- Local branch:
  `codex/device-ingress-response-contract-20260719`
- It is not contained in the observed local `main` or `origin/main`.
- The v3 contract has `register`, `resolve`, and `submit`; it does not supply a
  canonical signed current-status/read-back operation or typed signed
  revoke/deregister operation.

### CellScaffold

- Inert DeviceIngress server transport:
  - revision: `38195a233b84d09f66e5ef483800228f857fff2a`
  - prior draft branch: `codex/apns-device-ingress-v3-server-20260720`
- Follow-up callback rejection commit:
  - revision: `d2d1b7191d651ad42d172e980ab94a0fd478d07c`
  - parent: `38195a233b84d09f66e5ef483800228f857fff2a`
- Current APNS-provider WIP:
  - path: `/private/tmp/haven-cellscaffold-v1-push-20260723`
  - branch: `codex/cellscaffold-v1-push-runtime-20260723`
  - base revision: `d2d1b7191d651ad42d172e980ab94a0fd478d07c`
  - uncommitted: three files, 283 insertions and 16 deletions
  - source intent: generic opaque wakeup body and typed production-provider
    readiness without key/private-material diagnostics
  - `git diff --check` passed at observation
- The server pins CellProtocol v3 revision
  `79ce4f84666fedc446a1c80ab8adce1e7e3898e0`.
- Production bootstrap marks both register admission and challenge issuance
  unavailable. Source search found no production installation of the
  `DeviceCallbackRegisterAdmissionCompositionRoot`; only tests install a
  testing root.

### Identity lane

- The observed identity candidate tip is
  `c700dbc5699ec3a925165d80bc2ec7ad864a1218`.
- It is neither an ancestor nor a descendant of APNS server revision
  `d2d1b7191d651ad42d172e980ab94a0fd478d07c`; their merge base is
  `8bb7b31b13dad09734c88217cb01b9d48801ff27`.
- Therefore identity continuity/recovery evidence cannot be inferred from the
  APNS server branch, and APNS readiness cannot be inferred from the identity
  branch.
- This audit did not inspect a live identity vault or decide which identity
  record is authoritative.

## Static evidence adjudication

### Proven by inspected source

- The committed Binding foundation requires an existing persistent
  `CellApple.IdentityVault` identity in
  `domain:device:notification-callback`; it does not auto-provision one.
- It prepares the canonical signed register request through
  `DeviceIngressRequestFactory.prepare`.
- It persists consent and the response expectation before any
  mutation-capable transport call, and verifies a signed response before
  persisting historical registration evidence.
- Historical evidence is rebound to the current persistent vault identity and
  is not projected as current active registration.
- Raw APNS tokens are intended to remain in memory only; legacy UserDefaults
  token keys are deleted without being read.
- Runtime register composition, resolve, and submit remain fail-closed before
  network access.
- The server HTTP layer is byte-preserving and rejects legacy bearer
  authorization. Challenge issuance and production admission remain
  unavailable.
- The APNS provider WIP separates provider acceptance from ticket/callback
  semantics and restricts the payload to an opaque ticket reference plus a
  generic wakeup message.

### Prior coordinated evidence, not rerun here

- Initial Binding register-only foundation: previously reported focused tests
  green on revision `3791a431ddb3353c33a657a7bf2cb03cb6f557ea`.
- Later P1 client foundation: previously reported 37/37 focused
  `DeviceIngressRegistrationClientTests` and
  `NotificationEnrollmentManagerTests` green on the frozen P1 snapshot.
- Server transport revision `38195a23`: previously reported focused tests
  green and independent review without P0/P1 for the inert foundation.

These results do not cover the current uncommitted V1 client/provider WIP, an
integrated identity+APNS composition, a production-signed app, or a live
service.

### Not proven

| Evidence layer | Status |
| --- | --- |
| One authoritative, consented physical iPad identity/registration | **unverified; not inspected** |
| Persistent production challenge issuer | **blocked by source readiness** |
| Durable production admission/replay/authority root | **blocked; not installed** |
| Current signed registration status/read-back | **contract missing** |
| Signed revoke/deregister and token-rotation reconciliation | **contract missing** |
| Shared reviewed byte-preserving Binding transport | **missing** |
| Integrated identity + server + client release revision | **missing** |
| Production-signed Binding entitlement | **unproved** |
| Provider configuration readiness | **unverified; environment not inspected** |
| APNS provider acceptance | **not attempted** |
| Physical iPad receipt | **not attempted** |
| Device callback/ack/read-back | **not attempted and resolve/submit blocked** |
| Restart continuity | **not attempted** |

## Production entitlement/environment gate

The APNS client and provider environments must match exactly, but source
configuration is not runtime proof.

Current source observations:

- The DeviceIngress P1 client branch uses bundle identifier
  `org.digipomps.havenplayground`.
- The Apple M1 branch separately selects iOS release bundle identifier
  `org.digipomps.haven`.
- Both observed iOS entitlement source files still declare
  `aps-environment = development`.
- The uncommitted provider WIP is designed to accept only production mode and
  production topic `org.digipomps.haven`.

These snapshots cannot compose. Before any APNS contact, a separately
authorized distribution archive must prove, from the exact signed artifact:

1. exact Binding Git revision and clean compiler-input provenance;
2. bundle identifier `org.digipomps.haven`;
3. effective signed entitlement `aps-environment = production`;
4. a provisioning profile for the same App ID and Apple team;
5. server-side sanitized readiness with no production-readiness blocker;
6. exact equality between signed app topic and provider topic.

Do not infer production entitlement from the entitlement source file, project
setting, development install, or provider configuration.

## Exact existing blocker/reason codes

Binding WIP exposes:

- `persistent_challenge_and_admission_unavailable`
- `shared_byte_preserving_transport_unavailable`
- `signed_current_status_unavailable`
- `signed_revocation_unavailable`
- `token_rotation_reconciliation_unavailable`

CellScaffold exposes:

- `device_callback_challenge_issuer_unavailable`
- `device_callback_register_admission_unavailable`
- HTTP error `device-callback-admission-unavailable`
- HTTP error `device-callback-operation-unavailable`

The APNS provider WIP defines possible sanitized readiness blockers:

- `apns_configuration_missing`
- `apns_sandbox_enabled`
- `apns_team_mismatch`
- `apns_topic_mismatch`

No provider blocker was observed at runtime because the environment was
deliberately not inspected. The current primary static blocker is
`persistent_challenge_and_admission_unavailable`, with all four remaining
Binding blockers also open.

## Next safe gate

The next safe gate is **not** an iPad registration retry or an APNS send.

Development administration must first produce one exact, clean, independently
reviewed composition plan and revision set that:

1. integrates, rather than merely juxtaposes, the approved identity continuity
   release and the APNS server foundation;
2. pins an immutable CellProtocol revision containing every operation the
   client requires, including signed current status/read-back and signed
   revoke/deregister, or records an explicit protocol revision that supplies
   equivalent typed operations;
3. installs a persistent challenge issuer plus durable admission/replay and
   resolver-selected owner/Agreement authority;
4. supplies one shared byte-preserving client/server transport contract;
5. integrates Binding DeviceIngress hardening with the M1 bundle/origin and
   production Apple settings;
6. retains fail-closed readiness for every missing dependency.

After independent static review, a separate authorization may open **one
focused compile/test window** on an isolated, immutable CellProtocol checkout.
No build is authorized by this handoff.

## Prepared future test plan

Every phase is a hard gate. Failure or ambiguity stops the run; later phases
must not be attempted.

### Phase A — static composition and provenance

1. Record exact clean SHAs for Binding, CellProtocol, CellScaffold, and the
   identity release.
2. Prove dependency ancestry/pins and reject local-package symlinks to mutable
   or dirty checkouts.
3. Prove the client and server share canonical challenge/request/response bytes
   and route-operation mapping.
4. Prove negative tests for wrong identity domain, wrong target Cell, wrong
   owner/Agreement, expired challenge, replay, body tamper, wrong authority,
   rollback, missing status, revoked status, and token rotation.
5. Record exact focused and full test counts.

### Phase B — signed production artifact

1. Build/archive only after separate authorization and disk/machine readiness.
2. Inspect the archive, not source settings, for bundle ID, production APNS
   entitlement, provisioning profile, code-sign authority, build revision, and
   compiler-input provenance.
3. Verify the server's sanitized production-provider readiness and matching
   topic without exposing key IDs or private material.
4. Stop if any value is missing, development/sandbox, mismatched, or inferred.

### Phase C — consented device registration

1. Open a coordinated physical iPad window with no deploy/restart overlap.
2. Identify exactly one target iPad using only a sanitized, session-scoped
   fingerprint/hash.
3. Verify an already-provisioned persistent
   `domain:device:notification-callback` identity and explicit notification
   consent. Do not create or replace identity implicitly.
4. Generate a fresh bounded challenge and persist the client response
   expectation before submit.
5. Submit exactly one signed register operation.
6. Require the owner-signed register receipt and a separate fresh signed
   current-status/read-back showing active consent for the same device identity,
   authority, admission, and revocation generations.
7. Stop before APNS if registration or current status is ambiguous.

### Phase D — one APNS ticket

1. At send time, generate one correlation ID:
   `haven-apns-e2e-<UTC basic timestamp>-<8 random hex>`.
2. Record the correlation ID and UTC timestamps in the sanitized evidence
   ledger before send.
3. Submit exactly one harmless message:
   `HAVEN APNS test – ingen handling nødvendig`.
4. Record provider HTTP result, sanitized provider-message-ID hash, topic,
   environment, and timestamps. Never record a raw token or provider secret.
5. Treat provider acceptance only as provider acceptance.

### Phase E — physical receipt and callback

1. Obtain explicit physical confirmation that the target iPad displayed the
   message bearing the same correlation ID/time window.
2. Resolve the opaque ticket through authenticated DeviceIngress.
3. Submit exactly one signed callback/ack.
4. Verify the owner-signed callback receipt/read-back and ensure the server
   ticket reaches exactly one terminal state.
5. Restart the relevant client/server component in a separately coordinated
   window and prove registration/status/callback continuity without duplicate
   delivery or replay.

### Phase F — final evidence statement

Report each layer independently:

- identity/consent;
- signed registration and current status;
- APNS provider acceptance;
- physical iPad receipt;
- callback/ack;
- restart continuity;
- exact build and server provenance.

Any missing layer remains **not proven**. Do not summarize partial success as
“APNS end-to-end works.”

## Decision log

- 2026-07-24: resumed the lane as static/read-only only.
- 2026-07-24: did not inspect secrets, token stores, identity vaults, staging
  environment, device state, or provider logs.
- 2026-07-24: did not run build/tests, sign, upload, deploy, install, register,
  contact APNS, or assign a correlation ID.
- 2026-07-24: adjudicated the physical APNS run as blocked until one exact
  identity+protocol+server+client+production-signing composition exists.

