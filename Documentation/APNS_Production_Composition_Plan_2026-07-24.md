# HAVEN APNS production composition plan — frozen review input

Status: **PLAN-READY / OPERATIONAL NO-GO**

Snapshot ID:
`apns-production-composition-plan/2026-07-24T22:20:47+0200/v1`

Observed at: `2026-07-24T22:20:47+0200` (`CEST`)

Owned scope: this documentation file in the detached, documentation-only
observer worktree
`/Users/kjetil/.codex/worktrees/50d3/Binding`.

Predecessor:
`Documentation/APNS_End_to_End_Readiness_Handoff_2026-07-24.md`.

This snapshot is a static composition and review plan. It is not authority to
edit source, integrate Git branches, build, test, sign, upload, access Apple
portals, inspect credentials, register a device, contact APNS, or mutate
staging. No secret, private key, raw APNS token, or unsanitized identity
material was read or recorded while producing it.

## 1. Purpose, goal, and claims

Purposes:

- `purpose://test.acceptance`: distinguish source correctness, provider
  acceptance, physical delivery, and callback completion.
- `purpose://access.audit.privacy`: use a persistent domain-scoped device
  identity without making identifiers, transports, APNS tokens, or host
  credentials into authority.
- `purpose://scaffold.operations`: preserve exact revision, ownership, and
  fail-closed release gates without an uncontrolled deploy or staging change.

Goal of this snapshot:

> Give the development administrator and independent reviewers one exact,
> no-touch composition plan for Identity, CellProtocol DeviceIngress,
> CellScaffold, Binding, and Apple production signing.

Supported claim:

> The currently observed candidate objects and their known gaps are mapped
> precisely enough to review and assign the next implementation work.

Unsupported claim:

> The current candidates can be composed, signed, uploaded, or used for
> production APNS now.

That unsupported claim remains false because there is no exact integrated
candidate, no canonical current-status or deregistration operation, no
operational production challenge/admission root, no reviewed shared transport,
no proven production archive/profile, and no physical acceptance evidence.

## 2. Frozen candidate manifest and ancestry

`UNASSIGNED_NO_INTEGRATION_EXISTS` below is a deliberate stop value. It must be
replaced only by the SHA of an independently reviewed integration commit made
in a new, clean, development-admin-owned worktree.

| Lane | Exact source candidate | Observed ref/worktree | Merge-base facts | Current interpretation |
| --- | --- | --- | --- | --- |
| CellProtocol v2 predecessor | `79740304167aa4f4daadd148c5a369e919d25a6a` | observed local `origin/main`; commit subject previously identified as DeviceIngress v2 resolver-authority pin | merge base with v3 is the same SHA, so v3 descends from it | Historical predecessor only; do not implement a new client against v2 |
| CellProtocol canonical v3 source basis | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` | `codex/device-ingress-response-contract-20260719`; observed remote-tracking ref `origin/codex/device-ingress-response-contract-20260719` | descends from `797403…`; not observed on `main` | Canonical code/fixture basis for current planning, but not a production-complete contract |
| CellScaffold DeviceIngress transport | `38195a233b84d09f66e5ef483800228f857fff2a` | clean `codex/apns-device-ingress-v3-server-20260720` in `/private/tmp/haven-apns-device-ingress-v3-isolated/CellScaffold` | descends from shared server base `8bb7b31b13dad09734c88217cb01b9d48801ff27` | Inert register transport foundation; not an installed production admission root |
| CellScaffold callback rejection successor | `d2d1b7191d651ad42d172e980ab94a0fd478d07c` | `codex/apns-device-ingress-v3-admission-fix-20260721` and base of the push-provider WIP | merge base with `38195…` is `38195…`, so `d2d1…` descends from it | Preferred server-side APNS composition base; still inert |
| CellScaffold identity candidate | `c700dbc5699ec3a925165d80bc2ec7ad864a1218` | `codex/identity-release-candidate-v2-20260721` | merge base with `d2d1…` is `8bb7b31b13dad09734c88217cb01b9d48801ff27`; neither lane is inferred to contain the other | Separate identity prevention/recovery candidate; operational identity cutover remains its own gate |
| Binding PR #8 published register foundation | `3791a431ddb3353c33a657a7bf2cb03cb6f557ea` | `codex/binding-device-ingress-v3-register-20260721` | ancestor of local P1 successor | Historical published inert baseline |
| Binding local P1 register successor | `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c` | clean `codex/binding-device-ingress-v3-p1-fix-20260721` in `/private/tmp/haven-binding-device-ingress-v3-p1-fix-20260721/Binding` | merge base with PR #8 is `3791a431…` | Preferred Binding registration-client source basis; still intentionally inert |
| Binding Apple M1 identifiers/origin | `2d2412090a65e101435ea91c8ea36bc060d3c768` | clean `codex/binding-apple-m1-identifiers-origin-20260721` in `/Users/kjetil/.codex/worktrees/9abf/Binding` | merge base with `fefcc3…` is `f6536c497b0a4c0a5b32531416bb3712708cf47e`; neither branch contains the other | Production identifier/origin policy input, not signing proof |
| Binding APNS fail-closed UI/runtime WIP | uncommitted four-file diff on `fefcc3…` | dirty `codex/binding-v1-push-runtime-20260723` in `/private/tmp/haven-binding-v1-push-20260723` | same committed base as local P1 candidate | Useful typed blockers and honest UI copy only; not a candidate SHA |
| CellScaffold production-provider WIP | uncommitted three-file diff on `d2d1…` | dirty `codex/cellscaffold-v1-push-runtime-20260723` in `/private/tmp/haven-cellscaffold-v1-push-20260723` | same committed base as preferred server composition | Source-ready provider checks only; not a candidate SHA |
| Final CellProtocol successor | `UNASSIGNED_NO_INTEGRATION_EXISTS` | new clean protocol worktree required | must descend from reviewed v3 basis or document an explicit replacement | STOP |
| Final CellScaffold integration | `UNASSIGNED_NO_INTEGRATION_EXISTS` | new clean server integration worktree required | must deliberately integrate identity and APNS lanes from their common base | STOP |
| Final Binding integration | `UNASSIGNED_NO_INTEGRATION_EXISTS` | new clean Binding integration worktree required | must deliberately integrate P1 and Apple M1 from `f6536c…` | STOP |
| Exact App Store archive revision | `UNASSIGNED_NO_INTEGRATION_EXISTS` | must equal the final reviewed Binding integration SHA and source manifest | must be clean and immutable | STOP |

### Current worktree hazards — no touch

- The primary Binding worktree at
  `/Users/kjetil/Build/Digipomps/HAVEN/Binding` is on `7884e566…` with
  unrelated work. It is not an integration base.
- The primary CellScaffold worktree at
  `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold` is on `fc72d513…` with
  unrelated work. It is not an integration base.
- The local CellProtocol checkout is dirty at `61ffc899…`, behind the observed
  `origin/main`, and does not represent the v3 object used by the Binding
  candidate. It is not a dependency source for a release build.
- The identity candidate worktree currently has uncommitted identity/recovery
  changes on top of `c700dbc…`. The plan binds only the committed object
  `c700dbc…`; the dirty worktree must not be folded into APNS.
- The Binding APNS and catalog worktrees and the CellScaffold provider
  worktree are dirty, intentionally isolated WIPs. Do not merge their
  worktree state by directory copy.
- `Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  must not be rewritten by dependency resolution during static review. A
  future build window must attest its exact pre/post bytes.

## 3. Review ownership and file boundaries

These are proposed review owners, not filesystem ownership or authority
grants. Development admin owns ordering and final integration. Each worktree
has at most one writer.

| Review owner | Owned inputs | Required output | No-touch boundary |
| --- | --- | --- | --- |
| CellProtocol contract owner | `Sources/CellBase/DeviceIngress/DeviceIngressWire.swift`, `DeviceIngressAdmission.swift`, `DeviceIngressResponse.swift`; `Tests/CellBaseTests/DeviceIngress*`; DeviceIngress fixtures; `Docs/DeviceIngressSecurityContract.md` | One immutable successor commit with reconciled schemas/docs, current-status and revocation semantics, golden bytes, negative/restart tests | No HTTP paths, APNS topics/tokens, Apple signing, or host credentials in protocol authority |
| Identity/cutover owner | committed identity candidate `c700dbc…` and its separately reviewed successors | Identity continuity and recovery/cutover evidence for the retained authoritative identity; explicit green/red gate | No APNS transport/provider edits; no device registration; no shortcut identity creation or owner auto-provision |
| CellScaffold DeviceIngress owner | `Sources/App/Controllers/DeviceCallbackCapabilityServer.swift`, `VaporDeviceCallback.swift`, `Sources/App/configure.swift`, relevant readiness store and DeviceIngress tests | Persistent challenge issuer, durable admission/replay, resolver-selected owner/Agreement/Contract authority, exact byte-preserving transport, signed status/revocation service | No client-side vault code; no bearer fallback; no authority selected by HTTP route or host admin |
| CellScaffold APNS provider owner | `Sources/App/Cells/ConferenceMVP/Notifications/PushProviderAdapter.swift`, `Tests/AppTests/NotificationPushProviderTests.swift`, server capability documentation | Reviewed provider adapter with production-only readiness, generic wake-up payload, sanitized receipts/diagnostics | No private keys or raw tokens in Git, logs, test fixtures, or review artifacts |
| Binding DeviceIngress owner | `Binding/DeviceIngressRegistrationClient.swift`, `NotificationEnrollmentManager.swift`, `NotificationConsentBanner.swift`; focused tests; capability documentation; provenance generator | Persistent device identity, prepared request/expectation, exact transport consumer, signed receipt/status/revocation verification, durable local state and token rotation reconciliation | No shared server secret, no v1 runtime, no raw APNS token in `UserDefaults`, no unsigned registration success |
| Binding Apple release owner | `Binding.xcodeproj/project.pbxproj`, iOS entitlements, Apple release policy/preflight and tests | Exact bundle/origin/topic alignment and archive/profile/codesign proof plan | No Apple portal action, signing, upload, certificate/profile mutation, or secret handling in this phase |
| AASA/origin owner | production AASA artifact and digest-bound deployment policy, if Associated Domains is included | Proof that `https://haven.digipomps.org` serves the exact required AASA for `applinks:haven.digipomps.org` and the final app identifier | Do not include Associated Domains merely because catalog WIP contains it |
| Independent security reviewer | exact diffs and frozen fixtures from all lanes | P0/P1 review covering authority, privacy, replay, rollback, provenance, and secret absence | Reviewer does not edit candidate worktrees |
| Development administrator | clean integration worktrees, exact ordered SHAs, release ledger | Final immutable integration SHAs and go/no-go ledger | No direct main push, stale-image deploy, or cross-lane worktree copy |

## 4. Canonical DeviceIngress contract composition

### 4.1 Existing v3 code basis

At `79ce4f84666fedc446a1c80ab8adce1e7e3898e0`, the canonical code basis
contains:

- operations `register`, `resolve`, and `submit`;
- resources `cell:///DeviceRegistration` and
  `cell:///DeviceCallbackBridge`;
- actions `registerOrUpdateDevice`, `resolveTicket`, and
  `submitTicketResult`;
- capabilities `device.registration.write`, `device.callback.resolve`, and
  `device.callback.submit`;
- purpose
  `purpose://access.audit.privacy/device-notification-callback`;
- identity domain `domain:device:notification-callback`;
- envelope schema `cellprotocol.device-ingress.envelope.v3`;
- authority-reference schema
  `cellprotocol.device-ingress.authority-reference.v3`;
- signed challenge/request construction and
  `DeviceIngressRequestFactory.prepare`;
- `DeviceIngressResponseExpectation`, persisted before transport send;
- v3 admission record/receipt and mutation receipt;
- signed operation response verification bound to request, challenge, body,
  target Cell, target owner key, subject, exact signed Agreement,
  authority generation, revocation ledger/generation, content policy, and
  mutation/result digests;
- durable admission-ledger and same-Cell replay/read-back contracts; and
- v3 challenge/request/response/signed-Contract golden fixtures.

The v3 registration receipt may carry a state including `revoked`, but v3
defines no operation that requests current registration status and no typed
operation that revokes or deregisters. A verified register response is
historical mutation evidence only.

### 4.2 Contract inconsistency that must be closed

The same commit's `Docs/DeviceIngressSecurityContract.md` still describes
“version 2”, v2 schemas/fixtures, and access `-w--`, while the code returns
required access `rw-s` and uses v3 envelope/authority/admission/mutation
schemas. This is a release stop. The contract owner must make code, fixtures,
documentation, and exported review metadata agree byte-for-byte before either
Binding or CellScaffold updates a dependency pin.

### 4.3 Required canonical successor — no invented framing

The successor contract must preserve the reviewed v3 guarantees and add
reviewed, named wire operations for the missing semantics. This plan does not
invent their final enum cases, HTTP routes, schema labels, or version number.
Those are contract-owner decisions and must be frozen in CellProtocol first.

Required semantics:

1. **Current status/read-back**
   - Signed by the resolver-selected target Cell owner.
   - Bound to the persistent device subject identity and signing key,
     target Cell/owner, exact Agreement and content policy.
   - Carries a monotonic registration/admission generation and the current
     revocation ledger/generation.
   - Distinguishes active consent, revoked/deregistered, unknown, and any
     safely retryable/indeterminate state without treating local absence as
     server truth.
   - Binds token rotation through a non-secret digest or generation; never
     returns or logs a raw APNS token.
   - Has exact canonical golden bytes and a verifier. Historical register
     evidence must never satisfy this current-state verifier.

2. **Typed revoke/deregister**
   - A signed request and signed, durable mutation receipt, not a local UI
     preference.
   - Bound to the same identity, Cell, owner, Agreement, purpose, audience,
     authority and revocation generations as registration.
   - Idempotent by admission/request identity, retry-safe after ambiguous
     transport loss, and followed by signed current read-back.
   - Produces a durable local tombstone/retry record; “Not now” remains a
     separate pre-registration-only action.

3. **Challenge**
   - Issued by one persistent, pinned production issuer for the exact
     production origin/audience and target owner/Cell/Agreement.
   - Subject-bound, non-client-chosen nonce, bounded TTL and clock skew.
   - Issuer rotation is explicit and monotonic; failure to prove the expected
     issuer fails closed.

4. **Admission**
   - Resolution chooses the target Cell for the public device requester;
     resolution grants no authority.
   - Exact signed Agreement/Contract and owner key are verified at use time.
   - Admission is durably recorded before mutation.
   - The same Cell atomically rechecks authority/revocation and commits the
     mutation plus byte-identical signed response.
   - No server host owner, route name, bearer, device identifier, or domain
     binding can substitute for this authority.

5. **Replay and restart**
   - Persistent unique constraints cover challenge, nonce, request hash and
     admission ID.
   - Admission record, monotonic authority/revocation watermarks, mutation
     result and canonical response are crash-durable.
   - Identical replay yields byte-identical stored response/read-back without
     re-signing or remutating.
   - Conflicting replay, rollback, generation regression, missing record, or
     ambiguous crash state fails closed.
   - Tests cover process restart, host restart, crash windows, concurrent
     writers and revocation races.

6. **Transport boundary**
   - A single reviewed adapter contract carries exact canonical challenge,
     request, protected body and response bytes.
   - The transport does not choose purpose, audience, identity, Cell, owner,
     Agreement, authority, operation, or success.
   - Binding and CellScaffold consume the same immutable CellProtocol artifact
     and golden fixtures. Binding must not guess server framing.
   - TLS, host binding, size/rate limits and sanitized diagnostics are host
     concerns, never alternate authority.

`resolve` and `submit` remain fail-closed until their target Cell, authority,
transport, persistence, and response verification are operational. They
cannot be silently removed from callback acceptance: actual notification
completion requires them.

## 5. Identity composition

Identity and APNS are separate proof lanes but meet at one narrow boundary:
Binding's persistent requester identity in
`domain:device:notification-callback`.

Required composition:

1. Binding opens the authenticated persistent `CellApple.IdentityVault`.
2. It obtains or restores exactly one persistent identity for the notification
   callback domain and proves the public descriptor and domain binding.
3. The domain binding is evidence of key continuity only. It grants no
   registration, callback, Cell, owner, Agreement, or server authority.
4. A separately owner-issued, time-bounded Agreement/Contract authorizes the
   exact device subject and operations against the exact target Cells.
5. CellScaffold resolves and verifies that authority; it never auto-provisions
   an owner, Agreement, Cell, or credential because a device connects.
6. Restored local evidence is rebound to the currently opened persistent vault
   identity. Evidence copied from another device/identity is rejected.

Identity release condition:

- The identity/cutover lane must independently establish continuity for the
  retained authoritative identity and close its physical-authority/recovery
  gates.
- Its final exact commit must then be deliberately integrated with the APNS
  server candidate in a clean worktree.
- APNS review must not reinterpret source commit `c700dbc…`, a healthy process,
  or a successful login as proof that device authority exists.

## 6. Server composition

Starting point: `d2d1b7191d651ad42d172e980ab94a0fd478d07c`, which contains
the route-operation rejection successor to the inert transport at `38195…`.

Required order inside a new clean server worktree:

1. Pin the reviewed immutable CellProtocol successor and its exact artifact
   checksum; remove any duplicate/mutable package identity.
2. Integrate the separately green identity candidate from merge base
   `8bb7b31…` with an explicit merge/cherry-pick ledger and conflict review.
3. Install one persistent production challenge issuer with pinned public
   descriptor and rotation policy.
4. Install a production durable admission/replay ledger.
5. Register persistent `DeviceRegistration` and `DeviceCallbackBridge` Cells
   in the Resolver under the exact owner identities and signed Agreements.
6. Implement register, current-status, revoke/deregister, resolve and submit
   through `DeviceIngressAdmissionService`; no route may call a mutation stage
   directly.
7. Keep the HTTP layer byte-preserving and reject legacy
   `Authorization`/bearer paths.
8. Integrate the production-provider WIP only after it becomes a reviewed
   commit on this exact composition.
9. Expose sanitized readiness that stays red unless challenge, admission,
   replay, target Cell authority, status/revocation, APNS provider and exact
   revision are all present.

Current static server blockers:

- production bootstrap marks
  `device_callback_register_admission_unavailable`;
- production bootstrap marks
  `device_callback_challenge_issuer_unavailable`;
- observed source installs a testing admission service only in tests;
- current route contract admits only `register`; `resolve` and `submit` are
  unavailable;
- current challenge route fails closed;
- provider worktree is uncommitted source, not runtime evidence.

## 7. Binding composition

Starting inputs:

- registration foundation `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c`;
- Apple M1 identifiers/origin
  `2d2412090a65e101435ea91c8ea36bc060d3c768`;
- merge base `f6536c497b0a4c0a5b32531416bb3712708cf47e`.

Required order inside a new clean Binding worktree:

1. Create the integration from the common merge base and integrate both
   inputs deliberately; do not make one branch appear to descend from the
   other.
2. Pin the reviewed immutable CellProtocol successor in an isolated,
   reproducible package checkout. The current `../CellProtocol` symlink to a
   dirty checkout is forbidden for release evidence.
3. Preserve the P1 client's persistent vault identity, descriptor-relative
   crash-durable evidence store, cross-process lock, persist-before-submit
   expectation and signed response verification.
4. Replace the inert transport with only the reviewed shared byte-preserving
   adapter.
5. Implement signed current-status and typed revoke/deregister consumption
   after the protocol successor exists.
6. Keep raw APNS tokens in memory only for protected registration-body
   preparation. Delete legacy/current token `UserDefaults` keys without
   reading or migrating them.
7. Reconcile token rotation through signed status and a non-secret digest or
   generation. An ambiguous rotation remains pending and never appears
   registered.
8. Keep pre-registration “Not now” atomic and distinct from revocation.
9. Show “registered” only after fresh signed current status bound to the
   current persistent vault identity; restored register receipts remain
   historical evidence.
10. Keep `resolve` and `submit` fail-closed until their full callback path is
    operational.
11. Bind provenance to the final compiler-input manifest, toolchain,
    immutable CellProtocol artifact, final Git SHA and actual running codesign
    authority. Provenance is evidence/audit input, not runtime authority.

The uncommitted Binding APNS WIP already names honest blockers:

- `persistent_challenge_and_admission_unavailable`;
- `shared_byte_preserving_transport_unavailable`;
- `signed_current_status_unavailable`;
- `signed_revocation_unavailable`; and
- `token_rotation_reconciliation_unavailable`.

These remain release stops until replaced by verified composition evidence,
not by deleting the blocker strings.

## 8. Production identifiers and Apple signing prerequisites

Frozen intended alignment:

| Property | Required production value | Current source observation | Production proof required later |
| --- | --- | --- | --- |
| iOS bundle identifier | `org.digipomps.haven` | Apple M1 sets this for `iphoneos` Release, while other configurations still expose playground identifiers | Effective archived app identifier and embedded profile must match exactly |
| Production origin | `https://haven.digipomps.org` | decided in Apple M1 policy | Exact deployed origin, TLS, revision, and host-bound DeviceIngress audience proof |
| APNS topic | `org.digipomps.haven` | uncommitted server provider source expects it | Effective provider request topic and archived app bundle ID must match |
| Associated Domain, if included | `applinks:haven.digipomps.org` | present only in separate dirty catalog WIP | Effective archive entitlement plus production AASA content, app identifier, TLS, digest and read-back |
| APS environment | `production` | committed iOS entitlement currently says `development` | Effective archive codesign entitlement and embedded distribution profile must both say production |
| Apple Team ID | **UNVERIFIED** | project settings and uncommitted provider source contain values, but the handoff records conflicting project/target observations | Verify from the actual Apple account, distribution certificate/profile, effective archive entitlements and provider key metadata without exposing secrets |

Before a future sign/archive window can be authorized, all of these must be
true:

1. The exact App ID exists for `org.digipomps.haven` under the verified team
   and has Push Notifications enabled for production.
2. A non-expired, non-revoked App Store distribution provisioning profile
   covers that exact App ID and capability.
3. The selected distribution certificate/key and profile chain are valid for
   that team. Private material remains in approved secure storage and never
   enters logs or the repository.
4. Source release settings select the exact bundle ID and intended
   entitlements without a sandbox or playground override.
5. The effective signed archive, not just the source plist, proves:
   - `application-identifier` has the verified team/application prefix and
     `org.digipomps.haven`;
   - `aps-environment` is `production`;
   - keychain access groups use the correct application prefix;
   - Associated Domains are either exactly the approved production list with
     proven AASA, or absent by explicit review decision; and
   - the codesign authority/profile identity is the reviewed one.
6. The CellScaffold APNS provider uses the same verified Team ID, production
   endpoint, and topic `org.digipomps.haven`.
7. Sanitized provider readiness has none of:
   `apns_configuration_missing`, `apns_sandbox_enabled`,
   `apns_team_mismatch`, or `apns_topic_mismatch`.
8. Exact archive provenance names the final clean Binding SHA, complete
   compiler-input manifest, Xcode/Swift toolchain, dependency artifacts,
   entitlements, profile UUID/digest in sanitized form, and codesign authority.

No Apple portal/profile claim was checked in this static phase. A project
setting, entitlement source file, provider unit test, or policy JSON is not
production signing proof.

## 9. Include / remove / defer stop table

| Decision | Item | Required condition or reason | Stop behavior |
| --- | --- | --- | --- |
| INCLUDE | Persistent CellApple identity in `domain:device:notification-callback` | Rebound to current vault and exact public descriptor | Stop if prompt-free/ephemeral vault or copied evidence is used |
| INCLUDE | Canonical DeviceIngress signed challenge/request/response, durable admission and replay contracts | From one reviewed immutable successor with matching docs and fixtures | Stop on schema/doc/fixture mismatch |
| INCLUDE | Signed current-status/read-back and typed revoke/deregister | Must be defined canonically before host/client implementation | Stop while absent |
| INCLUDE | Resolver-selected target Cell owner and exact signed Agreement/Contract | Verified at use time with monotonic authority/revocation generations | Stop on label-, route-, host-, UUID-only, or admin-owner substitution |
| INCLUDE | Binding P1 evidence-store and persist-before-submit design | Must remain crash-durable, cross-process safe and identity/provenance bound | Stop on pending ambiguity or rollback |
| INCLUDE | Production bundle/origin/topic alignment | `org.digipomps.haven`, `https://haven.digipomps.org`, `org.digipomps.haven` | Stop on playground/staging/sandbox mix |
| INCLUDE | Generic APNS wake-up/ticket payload | No sensitive content; ticket resolved through authorized callback path | Stop if APNS payload becomes the protected data path |
| INCLUDE CONDITIONALLY | `applinks:haven.digipomps.org` | Only with exact production AASA and signed-archive entitlement proof | Remove Associated Domains from this release if proof is not ready |
| REMOVE | Local DeviceIngress v1 runtime and shared bearer/capability | Superseded and unsafe | Any fallback is P0/NO-GO |
| REMOVE | Shared server secret in mobile app | Client cannot safely hold server authority | Any occurrence is P0/NO-GO |
| REMOVE | Raw APNS token persistence in `UserDefaults`, logs, fixtures, receipts or review artifacts | Token is transient protected input only | Any occurrence is P0/NO-GO |
| REMOVE | Auto-provisioned owner identity, Agreement, Contract, Cell or credential on device request | Authority must pre-exist and be owner-issued | Any occurrence is P0/NO-GO |
| REMOVE | Sandbox APNS provider or `aps-environment=development` from App Store archive | Production release only | Any effective mismatch is P0/NO-GO |
| REMOVE | Unsigned/local “registered” success and restore-as-current | Historical evidence is not current server state | UI/API remains fail-closed |
| REMOVE | Sensitive notification body from APNS | APNS is wake-up transport, not authority/protected payload store | Any sensitive content is privacy stop |
| REMOVE | Broad host-admin/Scaffold-owner fallback | Transport/host identity grants no Cell authority | Any fallback is P0/NO-GO |
| DEFER | Catalog/UI/portable-surface WIP unrelated to APNS | Separate product lane | Keep out of APNS integration unless independently selected |
| DEFER | Primary Binding icon/UI/HavenAgentD changes | Unrelated dirty work | Keep out |
| DEFER | Unrelated primary CellScaffold changes | Unrelated dirty work | Keep out |
| DEFER | App Store marketing/review metadata | Separate from technical composition proof | Does not relax technical gates |
| STOP | No exact integrated Identity+CellProtocol+server+Binding SHA set | Current state | No build/sign/upload |
| STOP | Identity continuity/cutover lane is red or indeterminate | Identity is first and separately proven | No APNS/device mutation |
| STOP | CellProtocol lacks current status or typed revoke/deregister | Current v3 gap | No operational registration claim |
| STOP | CellProtocol v3 code/docs/access/fixture description disagree | Current `79ce4f…` observation | No dependency promotion |
| STOP | Server challenge issuer/admission/replay/target Cells are not persistent and production-installed | Current server gap | No registration attempt |
| STOP | `resolve`/`submit` callback path unavailable | Current server/client gap | No end-to-end acceptance claim |
| STOP | Mutable/dirty local CellProtocol path participates in build | Current Binding dependency hazard | No reproducible build claim |
| STOP | Effective archive/profile lacks production APNS entitlement or exact bundle/team | Not proven | No upload |
| STOP | Associated Domains included without AASA proof | Conditional release capability | Remove entitlement or prove it |
| STOP | Source/prototype readiness is reported as production proof | Claim/evidence mismatch | Review fails |
| STOP | Device identity or active consented iPad registration is ambiguous | Physical gate prerequisite | No push |
| STOP | Any secret/raw token would need to be revealed to proceed | Privacy boundary | Request a secure operator action instead |

## 10. Composition and review order

No later phase starts until the preceding phase has an exact immutable commit,
review result, and sanitized evidence record.

1. **Protocol freeze**
   - Reconcile v3 docs/code/fixtures.
   - Add canonical status and revocation semantics without inventing host
     framing.
   - Obtain contract/security review and publish one immutable successor.

2. **Identity gate**
   - Complete the separate identity continuity/cutover plan.
   - Record the exact green candidate SHA and authority evidence class.
   - Do not perform APNS or device action.

3. **Server composition**
   - New clean worktree from the declared base.
   - Deliberately integrate identity and `d2d1…`.
   - Pin protocol successor.
   - Install persistent issuer, admission/replay, Cells, Agreements,
     status/revocation, callback operations and production-provider source.
   - Independent P0/P1 review.

4. **Binding composition**
   - New clean worktree from `f6536c…`.
   - Deliberately integrate `fefcc3…` and `2d2412…`.
   - Pin the same protocol successor and reviewed transport.
   - Add status/revocation/rotation, final production settings and provenance.
   - Independent P0/P1 review.

5. **Exact composition review**
   - Freeze final protocol, identity, server and Binding SHAs plus their merge
     bases, dependency hashes, file lists and owners.
   - Prove unrelated work is absent.
   - Only then request a bounded build/test window.

6. **Source/build readiness** — future, separately authorized
   - Contract, negative, restart, replay and cross-repository golden-byte
     tests.
   - Exact clean archive candidate and complete compiler-input provenance.
   - Still no production claim.

7. **Production signing proof** — future, separately authorized
   - Verify Apple account/App ID/profile/certificate and effective archive
     entitlements.
   - Validate and upload only after explicit authority.

8. **Deployed runtime proof** — future, separately authorized
   - Exact server revision, TLS/origin, issuer, admission/replay, resolver
     Cells/Agreements, provider readiness, restart continuity.

9. **Physical acceptance** — future, separately authorized
   - Exactly one unambiguous active/consented iPad registration.
   - Exactly one harmless correlated production test.
   - Separate evidence for registration, APNS provider acceptance, physical
     receipt, `resolve`, `submit`/callback acknowledgment, and restart
     continuity.

## 11. Prototype/source readiness versus production proof

| Evidence class | What it can prove | What it cannot prove | Current state |
| --- | --- | --- | --- |
| Protocol source + fixtures | Intended canonical bytes, invariants and negative cases | Host wiring, persistence, deployed authority, APNS or delivery | v3 source basis exists; docs/schema description mismatch and missing operations block promotion |
| Server transport/provider source | Fail-closed adapter behavior in reviewed code/tests | Production issuer, ledger, Agreements, keys/config, deployed revision or APNS access | Inert committed transport plus uncommitted provider WIP |
| Binding source/tests | Local identity/evidence-store and response-verifier behavior | Real profile/entitlement, server interoperability, token registration or physical delivery | Inert P1 candidate plus uncommitted blocker/UI WIP |
| Successful build/test | Exact source compiles and selected tests pass in a recorded environment | Correct signing, deployment, credentials, live state or device receipt | Not run in this phase; historical counts are not re-attested here |
| Signed archive inspection | Effective bundle ID, entitlements, profile and codesign authority | Server readiness, APNS acceptance or device delivery | Unproved |
| Deployed runtime attestation | Exact server revision/config/readiness and persistent restart state | APNS provider acceptance or physical display/callback | Unproved |
| APNS provider response | Apple accepted/rejected a request for a topic/token | Physical iPad receipt or callback completion | Unproved |
| Physical device + callback evidence | Actual receipt and Binding resolve/submit acknowledgement for one correlation ID | General reliability beyond the bounded test | Unproved and not authorized |

The only production acceptance claim is an `allOf` claim across the last
three operational classes plus exact signed archive provenance. Source
readiness cannot substitute for any of them.

## 12. Exact review packet required before implementation starts

The development administrator should hand each owner only:

1. this snapshot ID and file;
2. the exact candidate SHAs and merge-base facts in section 2;
3. the exact owned file list in section 3;
4. the contract requirements and stop table;
5. a prohibition on secrets, device/network action, staging mutation and
   unrelated worktree edits; and
6. a required response containing:
   - repository, clean worktree, branch and exact pre/post SHA;
   - exact files read/changed;
   - dependency/pin changes and compiler-input manifest;
   - tests with exact counts and result, when a later test window is
     authorized;
   - P0/P1 findings and residual P2;
   - collision/no-touch attestation;
   - sanitized evidence only; and
   - explicit GO/NO-GO for the next gate, never for production by implication.

Reviewer questions that must be answered before any material build:

- Which exact CellProtocol successor contains canonical status and
  revocation, and do code/docs/fixtures agree?
- Which exact persistent issuer, Resolver Cells, owners and signed Agreements
  are installed by the server composition root?
- Where is the crash-durable admission/replay ledger and how is byte-identical
  replay proven?
- Which shared adapter defines transport framing without owning authority?
- How does Binding prove the current persistent device identity, persist
  expectation before send, and distinguish historical receipt from current
  status?
- How are token rotation and deregistration resolved without raw token
  persistence?
- Which exact final Binding SHA and complete compiler-input manifest produce
  the archive?
- What actual profile/account evidence proves Team ID, production APNS,
  `org.digipomps.haven`, and any Associated Domains?
- Which evidence is source-only, which is archive-level, which is deployed
  runtime, and which is physical acceptance?

## 13. Frozen decision

Plan/review-input: **GO**.

Material implementation, Git integration, build/test, Apple portal access,
signing, upload, device registration, APNS contact and staging mutation:
**NO-GO**.

Next safe gate: independent static review of this exact snapshot and assignment
of the **CellProtocol contract successor** owner. The first implementation
change, if later authorized, belongs in a new isolated CellProtocol worktree.
Identity cutover remains an independent prerequisite and must not be folded
into that protocol task.
