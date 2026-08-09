# APNS S1 Binding Client Contract Packet

Status: **AUTHOR-FROZEN / LANE C PLAN ONLY / MBI-05 PARTIAL / PLAN NO-GO / NEXT PHASE NO-GO**

Packet ID:
`APNS-S1-BINDING-CLIENT-CONTRACT-PACKET/2026-07-24T23:24:43+0200/v1`

Authored at: `2026-07-24T23:24:43+0200` (`CEST`)

Owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md`

This is a static planning artifact only. It is the sole file owned by this
Lane C author. It does not amend or supersede any bound input, and it grants no
authority for source edits, Git mutation, dependency resolution, build, test,
network access, Apple portal access, signing, device action, APNS, secrets,
Identity cutover, staging mutation, deployment or any next material phase.

Author self-review has no credit. The exact frozen bytes must be reviewed by a
reviewer distinct from the author before even a successor planning decision can
be considered.

## 1. Exact bound inputs

| Input | Exact SHA-256 | Lines | Bytes | Treatment |
| --- | --- | ---: | ---: | --- |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 | Immutable |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 | Immutable |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 | Immutable; remains NO-GO |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 | Immutable |

Bound S0-review result:

```text
P0: 0
P1: 2
P2: 1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

This packet consumes the S0 review only as a planning input. It does not claim
to close either S0 P1 operationally. It addresses `MBI-05` only by freezing a
client state model, path ownership and a decision ledger. `MBI-01` through
`MBI-04`, `MBI-06` and `MBI-07` remain outside this lane and remain missing or
unaudited.

## 2. Purpose, goal and claim boundary

Purposes:

- `purpose://test.acceptance`: define what the Binding client must prove at
  each transition, and keep source, signed response, signed current status,
  deployed runtime and physical receipt as separate evidence classes.
- `purpose://access.audit.privacy`: keep the persistent
  `domain:device:notification-callback` identity in the authenticated vault,
  keep transport non-authoritative and prevent raw APNS token or protected
  evidence leakage.
- `purpose://scaffold.operations`: freeze exact future Binding paths, owners,
  no-touch rules and stop conditions without opening implementation.

Goal:

> Produce one independently reviewable Binding-only contract packet whose
> state transitions, trust boundary, exact future path allowlist, negative
> tests and unresolved owner decisions are explicit enough that no client
> author needs to invent CellProtocol or server semantics.

Root claim:

> The packet is exact enough for an independent static review of Lane C.

That claim is **author-asserted and unaudited** until a distinct reviewer
reproduces these exact bytes and checks the local immutable objects. The packet
does not claim that the client can compile, interoperate, register, receive a
notification or ship.

## 3. Reproduced immutable facts

### 3.1 CellProtocol facts, not Lane C choices

The current planning basis is CellProtocol commit
`79ce4f84666fedc446a1c80ab8adce1e7e3898e0`, tree
`92e2deff343d963f5e4d5c2d7fbe567128db3ad3`.

Its locally read source establishes:

- `DeviceIngressOperation` contains exactly `register`, `resolve` and
  `submit`;
- the canonical identity domain is
  `domain:device:notification-callback`;
- the canonical purpose constant is
  `purpose://access.audit.privacy/device-notification-callback`;
- current operations require `rw-s`;
- `DeviceIngressRequestFactory.prepare` binds canonical challenge,
  protected-body digest, requester signature, domain binding, audience,
  expected challenge issuer and a response expectation;
- `DeviceIngressOperationResponseVerifier.verify` checks the exact prepared
  expectation rather than accepting an HTTP result as success;
- a registration response can carry `active_consented` or `revoked` at the
  historical mutation point;
- exact same-admission response replay is a server/Cell contract; and
- no current-status, revoke or deregister operation exists at this commit.

The code/document `v3` versus `v2` and `rw-s` versus `-w--` inconsistency
remains a release stop owned by Lane A. Lane C must not compensate for it.

### 3.2 Binding facts, not Lane C choices

The current preferred inert Binding source basis is:

| Property | Exact value |
| --- | --- |
| Common base commit/tree | `f6536c497b0a4c0a5b32531416bb3712708cf47e` / `ac894efa9e709e788eaa1dc863db1070786fbe0b` |
| P1 commit/tree | `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c` / `e0d6c9ff4fb998fa252ab86621abfe24398d7b18` |
| P1 endpoint paths | 13 |
| P1 name-status SHA-256 | `29495a23af28ca7842836f916593f9bdcde79c0d08076422b975e9c405d69f80` |
| Apple M1 commit/tree | `2d2412090a65e101435ea91c8ea36bc060d3c768` / `34421cbabe9e801fa96da315a191ed23cd023ec8` |
| Apple M1 endpoint paths | 11 |
| Apple M1 name-status SHA-256 | `94c535870b86bcb796ff83f36dda6785db24045343f5b288499282bade13b8b0` |

At `fefcc3…`, Binding already:

- requires an authenticated persistent `CellApple.IdentityVault`;
- refuses to create a missing notification-domain identity;
- validates a vault-owned domain binding and public key descriptor;
- uses `DeviceIngressRequestFactory.prepare`;
- writes the response expectation before the first mutation-capable send;
- stores consent, pending expectation and historical verified evidence in a
  descriptor-relative, journaled store with a cross-process lock;
- uses descriptor-relative filesystem operations and external keychain anchor
  checks to fail closed on rollback/link/path replacement;
- verifies the owner-signed register response;
- rebinds restored evidence to the currently opened vault identity and exact
  signing-key fingerprint;
- returns restored register evidence as historical evidence, never current
  active registration;
- deletes legacy raw-token `UserDefaults` values without reading or migrating
  them;
- keeps a newly supplied APNS token only in process memory; and
- leaves runtime registration, `resolve` and `submit` inert.

The historical source/test facts above are not re-tested here.

### 3.3 Existing transport facts and the S0 correction

At CellScaffold `d2d1b7191d651ad42d172e980ab94a0fd478d07c`,
the existing register/resolve/submit carrier has:

| Property | Exact existing value |
| --- | --- |
| Wrapper schema | `haven.device-callback.transport.v3` |
| Wrapper fields | `schema`, `canonicalChallenge`, `canonicalRequest`, `protectedBody` |
| Binary representation in JSON | Swift `Codable` `Data`, encoded as base64 strings |
| Maximum wrapper | 327680 bytes |
| Maximum challenge | 65536 bytes |
| Maximum request | 65536 bytes |
| Maximum protected body | 65536 bytes |
| Successful result | Raw canonical `DeviceIngressOperationResponse` bytes outside the wrapper |
| Authority | None |

The S0 review correctly found that a three-binary-field request wrapper cannot
also contain all four challenge/request/signed-Contract/response fixtures.
This Lane C packet therefore freezes the following client assertion:

> The shared transport request fixture has exactly the three request inputs.
> The signed Agreement/Contract is authority material referenced and verified
> by the canonical DeviceIngress request/admission contract, and the response
> fixture is expected raw output. Neither is an invented fourth wrapper field.

The eventual exact mapping still belongs to Lane A. Lane C consumes the
reviewed shared package and fixture manifest without redefining either.

### 3.4 Frozen production identifiers

Every future Lane C path must treat these as one alignment invariant:

| Property | Frozen intended value | What this packet proves |
| --- | --- | --- |
| App bundle identifier | `org.digipomps.haven` | Planning value only |
| APNS topic | `org.digipomps.haven` | Planning value only |
| Production origin | `https://haven.digipomps.org` | Exact client origin pin for future composition; not network proof |

`MBI-06` remains unaudited: no Team ID, App ID capability, profile,
distribution certificate, effective `aps-environment=production`, codesign
authority or signed archive was inspected.

## 4. Non-negotiable authority and privacy boundary

### 4.1 Protected resources and actions

| Action | Protected resource | Required authority path | Transport role |
| --- | --- | --- | --- |
| Challenge retrieval | Exact operation, subject, audience, target Cell/owner and Agreement context | Pinned production issuer plus canonical Lane A challenge contract | Carry bytes only |
| Register/update | Resolver-selected `DeviceRegistration` Cell | Persistent device identity + exact owner-issued Agreement/Contract + Resolver/Cell enforcement | Carry prepared request bytes only |
| Current status | Same registration record in the same authoritative Cell | Canonical signed current-status operation, target owner signature, current authority/revocation/admission generations | Carry bytes only |
| Revoke/deregister | Same registration record and authority lineage | Canonical signed mutation + durable owner-signed receipt + fresh status read-back | Carry bytes only |
| Resolve | Resolver-selected `DeviceCallbackBridge` Cell and one opaque ticket | Exact Agreement/Contract and signed request/response | Wake/ticket carrier only |
| Submit | Same callback Cell and resolved ticket lineage | Exact Agreement/Contract and durable signed submission receipt | Carry bytes only |

The requester is the persistent vault identity in
`domain:device:notification-callback`. The vault binding:

- proves the local context/key relationship;
- is signed inside the request;
- has `grantsAuthority=false`; and
- never substitutes for an Agreement, Contract, Grant, target Cell owner,
  Resolver decision or current server state.

An HTTP origin, route, status code, APNS token, bundle ID, topic, participant
ID, local device ID, push payload or possession of a ticket is never
authority. No mobile shared secret or host-admin fallback is permitted.

### 4.2 Data classification

| Data | Permitted location | Durable? | Log/diagnostic rule |
| --- | --- | --- | --- |
| Raw APNS device token | Short-lived Binding process memory, only while constructing protected registration input | No | Never |
| Canonical protected registration body containing the token | Memory for one prepared operation | No | Never |
| Vault private key | Authenticated CellApple vault only | Vault-owned | Never exported |
| Public identity descriptor/domain binding | Signed canonical request and minimal local binding record | Yes, as needed | Only sanitized fingerprint/opaque refs |
| Response expectation and canonical signed response | Hardened descriptor-relative evidence store | Yes | Hash/ref only |
| Historical register receipt | Hardened evidence store | Yes; historical only | Sanitized state/generation only |
| Fresh current-status proof | Hardened evidence store, bounded by Lane A freshness/retention contract | Yes | Sanitized state/generation only |
| Revocation/deregistration tombstone | Hardened evidence store after verified receipt/read-back | Yes | Sanitized state/reason only |
| Resolved protected callback payload | Memory by default | Only when the exact Contract grants `s` and a separate retention path is reviewed | Never raw |
| APNS notification body | Generic wake-up/ticket/correlation metadata only | OS-controlled delivery state | No protected payload |

`UserDefaults`, fixtures, source files, screenshots, accessibility labels,
console output, analytics, crash breadcrumbs and review artifacts must never
contain a raw APNS token, canonical protected body, private key or unredacted
resolved callback payload.

## 5. Author-proposed client-local state contract

The names in this section are **client-local planning names**, not CellProtocol
wire enums. They do not decide Lane A schemas.

### 5.1 Durable enrollment states

| Local state | Durable evidence required | UI truth | Permitted next action |
| --- | --- | --- | --- |
| `uninitialized` | None | Unknown/not registered | Open authenticated vault and evidence store |
| `identityUnavailable` | Typed local failure only | Not registered | User/operator repairs separate Identity prerequisite |
| `preRegistrationUnknown` | Valid empty/initial journal | Not registered | Accept terms or pre-registration-only decline |
| `preRegistrationDeclined` | Durable local decline tombstone; no pending/historical/current evidence | Not registered | Explicit fresh acceptance only |
| `consentedAwaitingToken` | Durable current terms acceptance | Not registered | Request iOS token |
| `readyForRegisterChallenge` | Consent + vault binding; raw token in memory only | Not registered | Fetch canonical challenge |
| `registerPreparedPending` | Crash-durable response expectation and vault/consent binding persisted before send | Not registered | Submit exact prepared bytes once |
| `registerAmbiguous` | Same pending expectation; no verified response | Not registered/indeterminate | Signed status/read-back adjudication only; no new register |
| `registerHistoricalVerified` | Verified canonical response and historical receipt | Not registered/current unknown | Fresh signed status |
| `statusPreparedPending` | Crash-durable status expectation, once Lane A defines it | Indeterminate | Submit exact status request |
| `activeConsentedCurrent` | Fresh verified current-status evidence matching the current vault identity and all authority bindings | Registered | Resolve/submit, status refresh, or controlled rotation/revocation |
| `statusUnknownOrStale` | Historical proof or expired/unavailable current proof | Not registered/indeterminate | Fresh status only |
| `revokePreparedPending` | Crash-durable canonical expectation plus retained active evidence | Not registered/transition pending | Submit exact revoke bytes once |
| `revokeAmbiguous` | Pending revoke expectation | Not registered/indeterminate | Canonical replay/read-back adjudication only |
| `revokedCurrent` | Verified revoke receipt and fresh signed status/tombstone | Not registered | Explicit new consent + canonical re-admission policy only |
| `deregisterPreparedPending` | Crash-durable canonical expectation plus retained active evidence | Not registered/transition pending | Submit exact deregister bytes once |
| `deregisterAmbiguous` | Pending deregister expectation | Not registered/indeterminate | Canonical replay/read-back adjudication only |
| `deregisteredCurrent` | Verified deregister receipt and fresh signed status/tombstone | Not registered | Explicit new enrollment only |
| `rotationNeedsReconciliation` | Current status evidence retained; new raw token exists only in memory | Not currently asserted registered | Lane A-defined rotation/register-update flow |
| `rotationPreparedPending` | Crash-durable expectation without raw token persistence | Not registered/transition pending | Submit exact bytes once |
| `rotationAmbiguous` | Pending rotation expectation | Not registered/indeterminate | Fresh signed status/read-back only |
| `blockedContractUnavailable` | Typed missing-contract/transport/authority reason | Not registered | No retry until exact dependency changes |

There is no transition from a historical register response directly to
`activeConsentedCurrent`.

### 5.2 Challenge and prepare transition

For every Lane A operation that uses a challenge:

1. Open the authenticated persistent vault.
2. Resolve exactly one existing identity for
   `domain:device:notification-callback` with
   `makeNewIfNotFound=false`.
3. Reproduce the vault domain binding and public descriptor.
4. Ask the reviewed shared transport for challenge bytes from the exact
   production origin.
5. Call the canonical CellProtocol request factory with:
   - exact challenge bytes;
   - exact protected body;
   - current persistent identity;
   - vault domain binding;
   - Lane A-frozen audience;
   - Lane A-frozen expected issuer; and
   - bounded current time.
6. Validate that the prepared expectation names the intended operation.
7. Persist the expectation and local binding before the first
   mutation-capable or result-bearing send.

Challenge bytes:

- are never authority by possession;
- are never reused across operations or subjects;
- are rejected when issuer, audience, origin, subject, operation, target,
  owner, Agreement, TTL, nonce or generation binding is wrong;
- are not silently refreshed after a mutation may have been sent; and
- use only Lane A/transport-owner framing.

`MBI-03` remains open until the exact challenge request, success response,
errors, redirect policy and framing are frozen.

### 5.3 Register transition

Preconditions:

- current terms acceptance is durably stored;
- no pre-registration decline is active;
- no pending or verified register evidence can be misrepresented as absent;
- one current persistent vault identity is bound;
- one raw APNS token is available in process memory;
- exact origin/issuer/audience configuration is available; and
- Lane A and Lane B authority dependencies are installed.

Transition:

```text
consentedAwaitingToken
  -> readyForRegisterChallenge
  -> registerPreparedPending
  -> registerAmbiguous | registerHistoricalVerified
  -> statusPreparedPending
  -> activeConsentedCurrent | statusUnknownOrStale | revokedCurrent
```

Rules:

- The protected body may contain the raw token, but the journal stores only
  the canonical response expectation and approved non-secret binding
  metadata.
- Persist-before-submit must preserve the existing descriptor-relative,
  cross-process, crash-durable store requirements.
- A transport error after send leaves `registerAmbiguous`; it never clears the
  pending expectation and never creates a new request automatically.
- A response advances state only after canonical verification against the
  persisted expectation.
- A verified `active_consented` register receipt is historical mutation
  evidence only.
- `isDeviceRegistered` becomes true only after a separate fresh signed
  current-status proof matches the current vault identity, target Cell/owner,
  exact Agreement/Contract, origin/audience/topic requirements and current
  admission/authority/revocation state.

### 5.4 Current-status/read-back transition

`MBI-01` is owned by Lane A. Lane C freezes only these consumer assertions:

- status is a typed canonical operation, never a reuse of a register receipt;
- its request expectation is persisted before send;
- its signed response is verified with the same canonical verifier family;
- it is bound to the current persistent subject identity and signing-key
  fingerprint;
- it is bound to the exact target Cell/owner and signed Agreement/Contract;
- it carries enough current admission/authority/revocation information to
  reject rollback or stale evidence;
- it carries the Lane A-selected non-secret token binding/generation needed
  for rotation adjudication;
- it distinguishes at least active-current, revoked/deregistered,
  unknown/not-found and unavailable/indeterminate without treating local
  absence as server truth; and
- freshness/expiry is explicit and fail-closed.

Until Lane A freezes the exact operation, schema, result, fixtures, freshness
and replay behavior, all status transitions end at
`blockedContractUnavailable`.

### 5.5 Pre-registration decline versus revoke/deregister

The following Binding UI/API distinction is frozen:

- **“Not now”** is permitted only before any pending, historical or current
  registration evidence exists. Its evidence check, durable decline and local
  state clear occur under the same store transaction/lock.
- **“Turn off notifications”** is never implemented by clearing local consent
  or deleting evidence. When registration may exist, it initiates the typed
  Lane A revoke/deregister flow.
- A local tombstone records an intended or ambiguous stop without claiming
  server state. Only a verified signed mutation receipt followed by fresh
  signed status can mark `revokedCurrent` or `deregisteredCurrent`.
- Uninstall, restore or absence of local evidence never proves server-side
  deregistration.

`MBI-02` remains open because Lane A must decide whether revoke and deregister
are distinct operations, states of one operation, or another exact canonical
model. Lane C does not choose that wire semantic.

### 5.6 Token-rotation transition

The client-local rotation policy is:

1. iOS supplies a token as an in-memory byte/string value.
2. Binding removes any legacy/current token defaults without reading them.
3. No raw token or reversible derivative is journaled.
4. If no current registration exists, use the register pipeline.
5. If current registration exists and a new token is observed, move to
   `rotationNeedsReconciliation` and stop asserting current registration.
6. Use only the Lane A-frozen canonical rotation mechanism. It may be a
   register-update plus status or a distinct operation; Lane C does not
   decide.
7. Persist the canonical expectation before the send.
8. After an ambiguous send or restart, obtain a fresh token from iOS and use
   signed status/read-back. Never restore a raw prior token.
9. Return to `activeConsentedCurrent` only after the signed current state
   proves the new token binding/generation.

Open owner decisions are recorded in section 10. No self-invented client token
hash becomes authority.

### 5.7 Resolve and submit transition

APNS is a wake-up carrier only:

```text
generic wake/ticket received
  -> resolve challenge/preparation
  -> resolve expectation durably recorded
  -> exact resolve send
  -> verified no-payload | verified resolved payload | ambiguous/blocked
  -> explicit user/agent decision under Contract
  -> submit challenge/preparation
  -> submit expectation durably recorded
  -> exact submit send
  -> verified durable submission receipt | ambiguous/blocked
```

Rules:

- A notification payload may identify an opaque ticket/correlation but must
  not contain the protected callback payload.
- Ticket possession is not authority.
- Resolve/submit use the same persistent subject identity, exact
  Agreement/Contract and shared byte-preserving transport.
- A resolved payload remains volatile unless the exact Contract grants
  Storage (`s`) and a separately reviewed retention path exists.
- No resolved payload, prompt, decision or result appears in logs,
  `UserDefaults`, fixtures or generic diagnostics.
- Submit success requires a verified durable signed submission receipt.
- Ambiguous resolve/submit never becomes success. Retry/replay follows only
  Lane A's exact same-admission rules.
- `resolve` and `submit` remain inert until Lane B installs the target
  `DeviceCallbackBridge` Cell and authority path.

### 5.8 Boot, restart and ambiguous-pending adjudication

At every launch or foreground activation:

1. Open the authenticated vault and derive the exact current notification
   identity binding.
2. Open and validate the descriptor-relative evidence store, canonical lock,
   external anchor, journal chain, file metadata and current inode/name
   relationship.
3. Reject copied evidence, build-provenance mismatch, rollback, invalid
   transition, path replacement or identity mismatch.
4. Recover pending expectations before accepting new terms, token or
   operation events.
5. Never replay a mutation merely because the process restarted.
6. Request fresh status/read-back for any historical, ambiguous or stale
   registration state.
7. Preserve local revocation/deregistration tombstones until a fresh signed
   server result reconciles them.
8. Keep the UI indeterminate/not registered while reconciliation is
   unavailable.

The store must not persist a protected body merely to enable crash replay.
Where exact replay after restart would require storing a raw token or
protected callback data, Lane A/B must provide a signed read-back/idempotency
adjudication instead. This is an explicit blocker, not permission to weaken
privacy.

## 6. Byte-preserving shared transport consumption

### 6.1 Frozen dependency boundary

Lane C consumes, but does not author:

| Property | Planned value |
| --- | --- |
| Owning repository | CellProtocol |
| Product/target | `CellDeviceIngressTransport` |
| Shared implementation | `Sources/CellDeviceIngressTransport/DeviceIngressHTTPTransport.swift` |
| Shared test | `Tests/CellDeviceIngressTransportTests/DeviceIngressHTTPTransportTests.swift` |
| Shared request wrapper fixture | `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransport.v3.json` |
| Contract fixture producer | CellProtocol DeviceIngress contract owner |
| Authority | None |

Lane C's Binding adapter:

- pins the exact reviewed CellProtocol artifact revision and checksum;
- constructs only the shared transport request type;
- sends only to the exact production origin;
- rejects redirect/cross-origin downgrade unless the later transport contract
  explicitly freezes a safe rule;
- passes canonical challenge, request and protected-body bytes without
  decode/re-encode;
- returns raw canonical response bytes without decode/re-encode;
- maps HTTP/TLS/size/framing failures to typed transport failures, never
  authorization decisions;
- rejects legacy bearer/callback-token headers and shared secret inputs; and
- leaves operation, purpose, audience, identity, Cell, owner, Agreement,
  authority, result and success to CellProtocol/Resolver/Cell.

### 6.2 Fixture mapping without the S0 contradiction

The planned Binding fixture manifest must assert separate roles:

| Fixture role | Direction | Wrapper membership |
| --- | --- | --- |
| Canonical challenge | Request input | `canonicalChallenge` |
| Canonical request | Request input | `canonicalRequest` |
| Exact protected body | Request input | `protectedBody` |
| Signed Agreement/Contract | Canonical authority fixture referenced/verified by the protocol contract | Not an extra wrapper field |
| Canonical operation response | Raw expected output | Not a request-wrapper field |

The exact upstream schema labels, versioned filenames and hashes for
status/revoke/deregister/rotation remain Lane A decisions. The Binding manifest
may not be populated with guessed values.

## 7. Exact proposed future Binding output allowlist

This is a planning allowlist, not write authority. Every path has exactly one
future owner. A separately authorized clean worktree and independent review
are mandatory before source work.

### 7.1 Binding DeviceIngress client owner

Existing paths permitted to change:

```text
Binding/BindingAppNotifications.swift
Binding/BindingBuildProvenance.swift
Binding/DeviceIngressRegistrationClient.swift
Binding/NotificationCallbackClient.swift
Binding/NotificationConsentBanner.swift
Binding/NotificationEnrollmentManager.swift
BindingTests/DeviceIngressRegistrationClientTests.swift
BindingTests/NotificationCallbackClientTests.swift
BindingTests/NotificationEnrollmentManagerTests.swift
Documentation/DeviceCallbackCapabilityContract.md
Scripts/generate_binding_build_provenance.sh
```

New exact paths proposed:

```text
Binding/DeviceIngressClientStateMachine.swift
Binding/DeviceIngressHTTPTransport.swift
BindingTests/DeviceIngressClientStateMachineTests.swift
BindingTests/DeviceIngressHTTPTransportTests.swift
BindingTests/DeviceIngressPrivacyTests.swift
BindingTests/Fixtures/DeviceIngressHTTPTransport.v3.json
BindingTests/Fixtures/DeviceIngressSharedFixtureManifest.json
Documentation/DeviceIngressBindingClientStateMachine.md
Documentation/DeviceIngressBindingPrivacyAndRecovery.md
```

Path responsibilities:

- `DeviceIngressClientStateMachine.swift`: client-local states and serialized
  transition reducer; no wire schemas.
- `DeviceIngressHTTPTransport.swift`: thin adapter over the shared
  `CellDeviceIngressTransport` product; no authority decisions.
- `DeviceIngressRegistrationClient.swift`: authenticated vault context,
  canonical prepare/verify and hardened evidence store.
- `NotificationCallbackClient.swift`: resolve/submit orchestration through the
  same state/transport contract.
- `NotificationEnrollmentManager.swift`: UI/iOS permission/token events only;
  no server truth manufactured on `MainActor`.
- `NotificationConsentBanner.swift`: separate pre-registration “Not now” from
  typed stop/revoke/deregister UX.
- `BindingAppNotifications.swift`: token and generic wake/ticket ingress; no
  token logging/persistence.
- provenance files: include every actual compiler input and final dependency
  artifact as audit evidence, never authority.

### 7.2 Development-admin Binding integration owner

Only the future development-admin integrator owns final bytes for:

```text
Binding.xcodeproj/project.pbxproj
Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

The project path collides with Apple M1 and must be reconciled once, from the
common base, with both lane owners reviewing final bytes. `Package.resolved`
is conditional: it changes only if the independently chosen immutable package
selection requires it. Dependency resolution is forbidden in this planning
phase and its exact pre/post bytes must be attested in any later authorized
window.

### 7.3 Explicit no-touch paths

Lane C has no ownership of:

```text
Binding/Binding-iOS.entitlements
Documentation/AppleReleaseM0Policy.template.json
Documentation/AppleReleaseM0Preflight.md
Scripts/apple_release_m0_preflight.py
Tests/apple_release_m0_preflight_tests.py
```

Those remain with the Binding Apple release owner and `MBI-06`. Lane C also
has no ownership of CellProtocol, CellScaffold, Identity, provider, AASA,
deployment or staging paths.

No additional source/test/fixture/project/doc path is permitted by this
packet. If Lane A's reviewed artifact requires a different consumer file or
fixture filename, the allowlist must be amended by a new document-only
decision and independent review before source work.

## 8. Collision and no-touch matrix

| Collision | Exact paths | Single future owner | Rule |
| --- | --- | --- | --- |
| Binding P1 × Apple M1 | `Binding.xcodeproj/project.pbxproj` | Development-admin Binding integrator | Integrate from `f6536c…`; P1 and Apple reviewers approve final bytes |
| Binding P1 × excluded APNS WIP | `Binding/DeviceIngressRegistrationClient.swift`; `Binding/NotificationConsentBanner.swift`; `BindingTests/DeviceIngressRegistrationClientTests.swift`; `Documentation/DeviceCallbackCapabilityContract.md` | Binding DeviceIngress client owner in a new clean lane | Never directory-copy WIP; review an exact future diff |
| Lane C × shared transport proposal | `Binding/DeviceIngressHTTPTransport.swift`; `BindingTests/DeviceIngressHTTPTransportTests.swift`; `BindingTests/Fixtures/DeviceIngressHTTPTransport.v3.json` | Binding DeviceIngress client owner | Consumer only; shared package/fixtures stay CellProtocol-owned |
| Lane C × project/dependency membership | `Binding.xcodeproj/project.pbxproj`; conditional `Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Development-admin Binding integrator | Client owner proposes membership; integrator owns final bytes |
| Lane C × Apple entitlements/signing | none; Apple paths are explicit no-touch | Binding Apple release owner | `MBI-06` stays separate |
| Lane C × catalog/AASA WIP | none in the Lane C allowlist | Catalog/AASA owner | Associated Domains remains removed unless its separate lane is green |
| Lane C × primary dirty Binding | every dirty primary-worktree path | No one in this lane | Hard no-touch; do not clean, copy or use as release input |
| Lane C × Identity cutover | no shared source path | Identity/cutover owner | Exact identity evidence is a prerequisite, never authored here |

## 9. Required negative and adversarial test packet

No test is run or claimed by this document. These are future required tests on
exact reviewed source.

### 9.1 Identity and authority

- Missing, locked, ephemeral or unauthenticated vault fails before transport.
- Missing notification-domain identity fails; no automatic creation occurs.
- Wrong domain, UUID, signing key or fingerprint fails.
- Copied evidence from another device/vault/build fails.
- Valid domain binding with `grantsAuthority=false` cannot replace a Grant.
- Wrong subject, target Cell, target owner, Agreement/Contract bytes, purpose,
  audience, origin, operation, capability or `rw-s` access fails.
- Expired/revoked Agreement, stale authority generation, revocation rollback
  and attacker-selected issuer fail.
- HTTP route, host owner, participant/device identifier, APNS topic/token,
  bearer or shared secret never grants authority.

### 9.2 Canonical bytes and transport

- Unknown wrapper schema, missing/empty field, malformed base64 and each
  over-limit field fail before network or canonical verification.
- Wrong HTTP method/path for the canonical operation fails.
- Redirect, origin change, TLS downgrade and host mismatch fail closed.
- Challenge/request/protected body are byte-identical before and after the
  transport layer.
- Signed Agreement/Contract is not inserted as a fourth wrapper field.
- Raw canonical response remains outside the request wrapper and is not
  decode/re-encoded by transport.
- Malformed, non-canonical, oversized, wrong-operation and wrong-signer
  responses fail.
- Transport failure remains a transport error and never becomes denied,
  authorized, registered or submitted.
- Legacy Authorization, callback-token and mobile server-secret inputs fail.

### 9.3 Persist-before-send and crash windows

For register, status, revoke/deregister, rotation, resolve and submit:

- file synchronization failure prevents send;
- parent-directory synchronization failure prevents send;
- crash before durable expectation causes no send claim;
- crash after durable expectation but before send recovers pending without
  inventing success;
- crash during/after send before response recovers ambiguous pending;
- crash after response receipt but before verified journal commit does not
  claim success;
- crash after verified commit reopens the same valid state;
- status/revoke/submit receipt journal failure does not clear pending;
- unsupported `F_FULLFSYNC`/fallback behavior is explicit per platform;
- disk full, short write, partial rename and interrupted fsync fail closed.

### 9.4 Replay, rollback and freshness

- Identical response replay verifies only against the exact stored
  expectation.
- A new challenge/nonce/body with an old response fails.
- Conflicting request for an existing pending operation fails.
- Historical register response never satisfies current status.
- Status freshness expiry immediately removes the active-current UI claim.
- Authority, admission, registration, revocation or token-binding generation
  regression fails.
- Journal truncation, valid-prefix rollback, full rehash rollback, anchor
  rollback and response substitution fail after restart.
- Missing server record remains unknown/not-found as Lane A defines; it never
  becomes local deregistration by inference.

### 9.5 Concurrency and cross-process

- Two client actors cannot submit separate mutations for one pending state.
- Separate store instances serialize through the canonical lock.
- A separate process proves the same lock and state transition boundary.
- Lock-name replacement after acquisition, directory rename and canonical
  name-to-inode change fail closed at relevant boundaries.
- Accept-versus-decline, decline-versus-register, register-versus-status,
  status-versus-revoke, rotation-versus-register and resolve-versus-submit
  races have one legal result.
- `MainActor` reentrancy cannot cross the evidence transaction.
- Concurrent APNS token callbacks collapse to one explicit rotation decision;
  no token is persisted.

### 9.6 Filesystem/store attacks

- Symlink, hardlink, FIFO, socket/device and non-regular evidence entries fail.
- Wrong owner, wrong mode, wrong link count and unpinned parent directory fail.
- Before/after inode/stat/content mismatch and concurrent writer fail.
- Path swap before open, after open, after lock and before/after rename fails.
- Descriptor-relative `openat`/`renameat`/`unlinkat` boundaries remain intact.
- Evidence directory is owner-only `0700`; files/locks are exact approved mode
  and regular-file metadata.
- Legacy pre-journal evidence does not migrate into authority.

### 9.7 Consent, current state and rotation

- “Not now” succeeds only with no pending/historical/current evidence.
- “Not now” and pending persistence can never both cross the gate.
- Existing or ambiguous registration forces typed revoke/deregister UX.
- Clearing consent/defaults cannot imply server revocation.
- Register receipt leaves UI not registered until fresh signed status.
- Copied, stale or wrong-token-binding status cannot set active.
- New token moves state to rotation reconciliation and suppresses the current
  registration claim.
- Restart never restores a raw token; iOS must provide a fresh token.
- Stale rotation response and multiple token-generation reorderings fail.
- Verified revoke/deregister still requires fresh signed read-back before
  clearing the transition.

### 9.8 Callback and privacy

- APNS payload containing protected callback content is rejected or ignored;
  only generic wake/ticket/correlation fields are accepted.
- Ticket possession alone cannot resolve.
- Resolve response is signed, expectation-bound and size-limited.
- Protected resolved data is not persisted without exact `s` authority.
- Submit requires exact resolved-ticket lineage and a verified durable receipt.
- Duplicate/late/wrong-ticket submit and ambiguous submit remain fail-closed.
- Automated scans prove raw token/protected body/private key/resolved payload
  absence from `UserDefaults`, evidence files, logs, diagnostics, fixtures,
  errors and snapshots.
- User-facing errors use typed sanitized reason codes and never interpolate
  raw canonical payloads.

### 9.9 Provenance

- Every new source/test/resource actually used by the build appears in the
  compiler-input manifest.
- Ignored/generated/source-like files in synchronized roots are rejected when
  unattested.
- Toolchain, exact CellProtocol artifact, final Git tree and running codesign
  authority are bound as audit evidence.
- Provenance mismatch forces fresh verification but never grants or revokes
  server authority.

## 10. Exact owner-decision and blocker ledger

No answer in this table may be guessed by a Binding author.

| ID | Missing decision/input | Required owner | Binding behavior while missing |
| --- | --- | --- | --- |
| `C-DEC-01` | Exact current-status operation, request/result schemas, states, freshness and fixtures | Lane A CellProtocol contract owner | `status` unavailable; historical evidence never active |
| `C-DEC-02` | Whether revoke and deregister are distinct operations or one canonical semantic; exact receipts/status mapping | Lane A CellProtocol contract owner | Pre-registration decline only; post-registration stop unavailable |
| `C-DEC-03` | Exact challenge request/response framing, errors, redirect policy and operation binding | Lane A transport + contract owners | Challenge fetch unavailable |
| `C-DEC-04` | Exact token-rotation operation/update semantics and non-secret comparison generation | Lane A contract owner with server owner | Rotation remains pending/indeterminate |
| `C-DEC-05` | Same-admission replay/read-back adjudication after a client crash without persisted protected body | Lane A contract + Lane B server owners | No automatic retry after ambiguous send |
| `C-DEC-06` | Production issuer descriptor/rotation proof, target Cells/owners and exact signed Agreement/Contract | Lane B CellScaffold authority owner | Every operation fails closed before send |
| `C-DEC-07` | Durable server status/revoke/submit read-back and unavailable/not-found semantics | Lane B server owner constrained by Lane A | Client preserves pending/tombstone and reports indeterminate |
| `C-DEC-08` | Whether participant/device identifiers remain protected-body metadata and their minimization/retention policy | Lane B registration Cell owner + privacy reviewer | No new body schema is invented |
| `C-DEC-09` | Exact upstream fixture filenames, SHA-256 manifest and immutable shared package revision | Lane A producer and cross-runtime reviewer | Binding fixture manifest remains unpopulated; no source phase |
| `C-DEC-10` | Retention policy for resolved callback data when a Contract contains `s` | Agreement owner + Binding privacy owner | Volatile processing only |
| `C-DEC-11` | Exact clean Binding integration commit/tree, dependency pin and compiler-input manifest | Development administrator | `MBI-07` remains missing |
| `C-DEC-12` | Team/profile/certificate/effective production entitlement/archive evidence | Apple release owner | `MBI-06` remains unaudited |

## 11. `MBI-05` disposition

| Subclaim | Author disposition | Reason |
| --- | --- | --- |
| Binding future source/test/project/doc paths are named | **AUTHOR-PROPOSED CLOSED, UNREVIEWED** | Section 7 is path-exact and gives one owner per path |
| Binding client-local state transitions are named | **AUTHOR-PROPOSED CLOSED, UNREVIEWED** | Section 5 separates durable historical, ambiguous and current states |
| Binding can implement canonical status/revoke/deregister/rotation now | **OPEN / BLOCKED** | `MBI-01` through `MBI-03` and `C-DEC-01` through `C-DEC-05` are unresolved |
| Binding can reach production server authority now | **OPEN / BLOCKED** | `MBI-04` and `C-DEC-06` through `C-DEC-08` remain |
| Shared fixture/transport consumption is implementable now | **OPEN / BLOCKED** | Producer artifact/revision and exact fixture manifest do not exist |
| Binding package is production signable/uploadable | **OPEN / UNAUDITED** | `MBI-06` remains |
| Exact integrated output exists | **OPEN / MISSING** | `MBI-07` remains |

Overall:

```text
MBI-05: PARTIAL — STATIC PATH/STATE PLAN ONLY
SOURCE AUTHORIZATION: NO
PLAN: NO-GO
NEXT PHASE: NO-GO
```

## 12. Preserved operative stops

- S0 remains immutable and NO-GO.
- Lane A must reconcile current v3 code/docs/fixtures and define
  status/revoke/challenge/rotation without host framing.
- Lane B must define and later implement the production issuer,
  admission/replay/status/revocation Cells/services and exact
  Agreement/Resolver authority.
- Transport is semantically neutral and grants no authority.
- Identity cutover is a separate prerequisite. This packet neither modifies
  nor approves it.
- No raw APNS token is persisted or exposed.
- No local/historical evidence establishes current registration.
- `resolve` and `submit` remain fail-closed until their full server and
  Contract paths exist.
- Bundle/topic `org.digipomps.haven` and origin
  `https://haven.digipomps.org` are planning invariants, not production proof.
- `MBI-06` signing/profile/entitlement/archive evidence remains unaudited.
- `MBI-07` exact integrated commit/tree/digest remains missing.
- Associated Domains remains removed unless its separate exact AASA and
  signed-archive lane becomes green.
- No source, Git, build, test, network, signing, device, APNS, staging or
  deployment action follows from this packet.

## 13. Author decision and review handoff

Author claim adjudication:

| Claim | Author result |
| --- | --- |
| Four immutable input documents are byte-identified | Supported by local hash re-attestation; independent reproduction required |
| Current CellProtocol/Binding/transport facts are distinguished from choices | Author-asserted; independent review required |
| One complete future Binding path allowlist is proposed | Supported by section 7; no implementation authority |
| State transitions prevent historical/ambiguous evidence from becoming current | Author-proposed; independent adversarial review required |
| Raw token persistence is needed for crash recovery | Contradicted; status/read-back must adjudicate without it |
| Lane C can choose missing Lane A/B wire or authority semantics | Contradicted |
| MBI-05 is operationally closed | Contradicted |
| Any source or next material phase is authorized | Contradicted |

Final author decision:

```text
LANE C PACKET: AUTHOR-FROZEN
INDEPENDENT EXACT-BYTE REVIEW REQUIRED: YES
MBI-05: PARTIAL / OPEN
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE PHASE: NOT AUTHORIZED
```

The only permitted successor is the separately coordinated exact-byte static
review of this one packet by a reviewer distinct from its author. That review
must report P0/P1/P2, adjudicate the path/state/decision claims, preserve all
missing-bound-inputs and stop without opening source or any material phase.
