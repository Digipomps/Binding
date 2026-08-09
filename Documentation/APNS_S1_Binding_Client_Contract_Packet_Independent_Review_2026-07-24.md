# APNS S1 Binding Client Contract Packet — Independent Exact-Byte Review

Status: **REVIEW-FROZEN / LANE C PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO**

Review date: `2026-07-24`  
Review role: independent Lane C reviewer, distinct from the Lane C author  
Review scope: static exact-byte review only  
Owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md`

This review does not amend the reviewed packet or any upstream input. It grants
no authority for source edits, Git mutation, dependency resolution, build,
test, network, portal, signing, device action, APNS, secrets, Identity
cutover, staging, deployment or a next material phase.

## 1. Exact review target and bound inputs

The target path was re-attested absent before this review artifact was
created.

### 1.1 Reviewed Lane C bytes

| Path | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 |

The review covers exactly those bytes. The Lane C packet is author-frozen,
untracked and unstaged in a detached observer worktree.

### 1.2 Unchanged upstream planning documents

| Input | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| Production composition plan | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| First independent review | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| S0 correction | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| S0 independent review | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

The inherited S0 result remains:

```text
P0: 0
P1: 2
P2: 1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

S0 remains immutable. This review does not award closure to any S0 finding.

### 1.3 Peer packet interface inputs

| Lane | Path | SHA-256 | Lines | Bytes | Treatment |
| --- | --- | --- | ---: | ---: | --- |
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | Unreviewed peer proposal; interface comparison only |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | Unreviewed peer proposal; interface comparison only |

This reviewer authored Lane B and therefore gives Lane B no independent-review
credit. Lane B was used only to identify cross-lane input/output assumptions.

## 2. Immutable source evidence reproduced read-only

| Repository/object | Commit/tree or blob |
| --- | --- |
| Binding P1 candidate | commit `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c`; tree `e0d6c9ff4fb998fa252ab86621abfe24398d7b18` |
| Binding common base | commit `f6536c497b0a4c0a5b32531416bb3712708cf47e`; tree `ac894efa9e709e788eaa1dc863db1070786fbe0b` |
| Binding registration client | `fefcc3…:Binding/DeviceIngressRegistrationClient.swift`; blob `d0debbe518e565e20d86aeab4b56c5c9f7942c50` |
| CellProtocol v3 candidate | commit `79ce4f84666fedc446a1c80ab8adce1e7e3898e0`; tree `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` |
| CellProtocol response contract | `79ce4f…:Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift`; blob `707b8f7cb2b580eb41c927f2f84df58b45e978aa` |
| CellProtocol wire contract | `79ce4f…:Sources/CellBase/DeviceIngress/DeviceIngressWire.swift`; blob `06138743faa6df83690a824fe6bf6d2171601749` |

Relevant reproduced facts:

- the current response expectation contains `admissionID`, request/challenge/
  body hashes, subject, target, Agreement and generation bindings;
- it does **not** contain the registration ID that is first returned by a
  successful registration receipt;
- the current Binding client persists only that expectation before submit,
  leaves it pending after an ambiguous send, and does not persist the protected
  registration body;
- the protected registration body contains the raw APNS token;
- the current canonical operation set has `register`, `resolve` and `submit`,
  but no status, revoke or deregister operation; and
- the P1 evidence store is descriptor-relative, journaled, externally anchored
  and cross-process locked, but it is currently shaped around one pending
  registration expectation and one historical verified registration result.

No source fact above was rebuilt or re-tested.

## 3. Review method and claim boundary

The review:

1. reproduced the target and peer packet byte identities;
2. read the entire 853-line Lane C packet;
3. compared its challenge, protected-operation wrapper, current-status,
   revoke, replay and consumer assumptions with Lane A;
4. compared its server/read-back assumptions with Lane B without reviewing
   Lane B itself;
5. inspected the immutable Binding and CellProtocol objects listed above;
6. checked the proposed Binding path owner, collision and no-touch packet;
7. checked local state, durable evidence, restart, ambiguous-pending,
   cross-process and filesystem-link attack claims; and
8. preserved Identity, signing and integrated-output gates as separate.

No test, build, dependency resolver, network, portal, signing, device, APNS,
secret, Identity, staging, deployment or Git mutation was performed.

## 4. Finding summary

```text
P0: 0
P1: 3
P2: 4

LANE C PACKET: NO-GO
MBI-05: PARTIAL / OPEN
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE PHASE: NOT AUTHORIZED
```

All seven findings are open. This review-only artifact changes no target bytes
and therefore closes none of them.

## 5. P1 findings

### P1-C-01 — Empty local evidence is incorrectly promoted to “not registered”

**Target claims**

- lines 241–250: `preRegistrationUnknown` with a valid empty/initial journal
  has UI truth “Not registered” and permits acceptance or pre-registration
  decline;
- lines 372–374: “Not now” is allowed when no pending, historical or current
  local evidence exists;
- lines 381–382: uninstall, restore or local absence never proves server-side
  deregistration; and
- lines 446–463: boot requests fresh status for historical, ambiguous or stale
  state, but not for an empty local journal.

**Adjudication**

These claims are mutually inconsistent. Reinstall, restore, local evidence
loss, or a legitimately new local evidence store can coexist with an active
server registration for the same persistent device identity. Local absence
therefore supports only “local evidence absent / server state unknown”, not
“Not registered”. Permitting the pre-registration path at that point can leave
an active server registration untouched while the UI says notifications were
not registered; a later acceptance can also attempt a second registration
without first reconciling the existing record.

The current Lane A status proposal requires a `registrationID`. An empty local
store does not have that ID. The packet therefore cannot repair this by merely
saying “fresh status”; it needs an owner-frozen subject-bound discovery/current
status operation, another authoritative lookup key, or an explicit permanent
fail-closed state.

**Impact**

This violates the packet's acceptance and privacy/consent evidence boundary.
It can misstate device status and fail to translate a user's local decision
into the required typed server-side stop flow.

**Smallest successor scope**

- add an exact client state such as `localEvidenceAbsentServerUnknown`;
- make its UI truth and actions indeterminate/fail-closed;
- require a Lane A/B canonical signed subject-bound discovery/status result
  before pre-registration decline, new register or “not registered” truth;
- define unknown/not-found, unavailable and multiple-record behavior; and
- add reinstall/restore/empty-journal negative tests.

**Closure verdict:** **OPEN P1**. `C-DEC-01`, `C-DEC-05` and `C-DEC-07` do not
currently name the missing subject-bound discovery key/operation.

### P1-C-02 — Ambiguous crash recovery has no composable protocol path

**Target claims**

- lines 249–250 and 334–335: a register expectation is durable but a
  post-send error becomes `registerAmbiguous`, with status/read-back only and
  no new register;
- lines 329–331 and 465–469: the raw-token protected body is not stored, and
  Lane A/B must provide read-back/idempotency adjudication;
- lines 439–440: ambiguous resolve/submit follows Lane A same-admission rules;
  and
- line 770: `C-DEC-05` records a generic replay/read-back decision blocker.

**Cross-object mismatch**

- current `DeviceIngressResponseExpectation` persists `admissionID` but no
  registration ID;
- Lane A's proposed status request requires `registrationID`;
- Lane A's proposed exact replay returns the stored response only for a replay
  of the exact request;
- exact request replay also requires the protected body, which Lane C
  correctly refuses to persist because it can contain the raw APNS token or
  protected callback data; and
- Lane A defines no admission-ID response-fetch operation and no durable
  submit-status/read-back operation.

Consequently, after restart the client cannot construct Lane A status for an
ambiguous first registration, cannot exact-replay the request, and cannot
retrieve the stored response by admission ID. The same contradiction applies
to ambiguous submit when the protected result is intentionally volatile.

**Impact**

The packet's ambiguous states are fail-closed, which is safe, but they are not
adjudicable. The claimed transition and future test packet cannot be
implemented from the peer contracts. A permanent pending state also prevents
controlled revoke, token rotation and subsequent enrollment.

**Smallest successor scope**

Lane A and Lane B must choose and freeze one privacy-preserving canonical path,
for example:

- owner-signed exact-response retrieval by `admissionID` plus the full
  expectation bindings;
- subject-bound current-state discovery that does not require an identifier
  available only in the lost response; or
- a reviewed encrypted/opaque crash-replay package whose retention and
  deletion rules do not expose a raw token or callback body.

The choice must define request/response schemas, authority, freshness,
same-Cell lookup, replay, not-found/unavailable behavior, retention, storage
paths and fixtures. Lane C must then name operation-specific local durable
states and tests.

**Closure verdict:** **OPEN P1**. `C-DEC-05` correctly notices the issue but is
too generic to reconcile the actual `admissionID`/`registrationID`/body-byte
deadlock.

### P1-C-03 — The client challenge state machine omits Lane A's signed intent
and issuer-generation continuity

**Target claims**

- lines 269–290: client challenge flow opens the vault, derives subject
  binding, asks transport for challenge bytes, then calls
  `DeviceIngressRequestFactory.prepare`;
- lines 301–302 and `C-DEC-03`: challenge framing remains open; and
- lines 489–501: the shared adapter is byte-preserving and
  non-authoritative.

**Peer-interface mismatch**

Lane A's unreviewed proposal requires the client to construct and sign a
canonical `DeviceIngressChallengeIntent` before fetching the challenge. That
intent includes a requester nonce, operation, purpose, audience, identity
domain, subject, domain binding, authority/agreement lookup hints, timestamps,
minimum issuer generation and proof. Lane A further requires the client to
persist the highest accepted issuer generation and validate an owner-signed
rotation record before advancing it.

Lane C has no local challenge-intent preparation state, no nonce lifecycle, no
issuer-generation watermark state, no rotation-record validation transition,
no challenge-carrier fixture consumption and no exact storage responsibility
for that rollback floor. Simply “asking transport for challenge bytes” cannot
consume the proposed producer interface.

Because Lane A remains unreviewed, Lane C must not silently adopt it. It must
instead either freeze a client-consumer branch matching reviewed Lane A bytes
or keep challenge preparation explicitly unavailable.

**Impact**

The register/status/revoke/resolve/submit state machines cannot reach canonical
request preparation, and issuer rollback protection cannot be implemented
from the claimed Lane C state/path packet.

**Smallest successor scope**

- after Lane A owner decision and independent review, add exact client-local
  challenge-intent prepared/pending/verified/expired states;
- name the issuer-generation watermark and rotation-proof durable record in
  the hardened store;
- freeze nonce generation/reuse, crash and cross-process behavior;
- add exact shared challenge-carrier/fixture manifest inputs; and
- add issuer rollback, rotation, replay, wrong-operation and path-swap tests.

**Closure verdict:** **OPEN P1**. Keeping `C-DEC-03` open is correct, but the
claim that Lane C's client-local transitions are named is only partial.

## 6. P2 findings

### P2-C-01 — Resolve/submit are prose transitions, not exact durable states

Section 5.1 is titled “Durable enrollment states” and names no resolve or
submit pending, ambiguous, historical/verified, decision-retention or
read-back state. Lines 410–442 provide only an arrow narrative. Yet lines
664–675 require the same persist-before-send/crash matrix for resolve and
submit, and lines 696–703 require serialized cross-process races.

The packet also does not state what non-secret ticket lineage and decision
metadata may be retained when the protected resolved payload remains volatile.
That omission prevents an exact reducer/store schema and weakens the section
11 claim that all client-local transitions are named.

**Smallest successor scope:** add operation-specific durable state names,
permitted retained fields, transaction boundaries, restart transitions,
terminal states and exact tests, all conditional on the P1-C-02 protocol
decision.

**Closure verdict:** **OPEN P2 / PARTIAL STATE-PACKET CLAIM**.

### P2-C-02 — Apple-release no-touch list is not path-exhaustive

Lines 592–606 label an explicit no-touch list but omit six paths from the
reproduced 11-path Apple M1 endpoint:

```text
Scripts/apple_release_m0_preflight.sh
Tests/fixtures/apple_release_m0_preflight/facts-dirty.json
Tests/fixtures/apple_release_m0_preflight/facts-pass.json
Tests/fixtures/apple_release_m0_preflight/policy-mismatch.json
Tests/fixtures/apple_release_m0_preflight/policy-pass.json
Tests/fixtures/apple_release_m0_preflight/policy-pending.json
```

The general sentence at lines 608–611 prevents Lane C from editing arbitrary
extra paths, so this is not current write authority. It nevertheless
contradicts the “explicit no-touch” and complete path-owner claim.

**Smallest successor scope:** enumerate all six paths under the Apple release
owner, retain `Binding.xcodeproj/project.pbxproj` under the development-admin
collision owner, and reproduce the exact 11-path Apple M1 ledger.

**Closure verdict:** **OPEN P2 / OWNER MATRIX PARTIAL**.

### P2-C-03 — Current-status proof is asked to prove APNS topic/origin state

Lines 340–343 say the fresh signed current-status proof must match
origin/audience/topic requirements. Lane A explicitly treats bundle ID and
APNS topic as release/provider context, not CellProtocol authorization or
transport success. Its proposed status payload has no APNS topic field.
Lane C's own authority boundary likewise says topic and origin do not grant
authority.

The intended fail-closed composition check is sound, but one signed status
proof cannot establish all of these evidence classes.

**Smallest successor scope:** split the gate into:

1. canonical signed current Cell status and authority/generation evidence;
2. byte-preserving transport origin/TLS evidence; and
3. separate signed-archive/provider bundle/topic/production-entitlement
   evidence under `MBI-06`.

**Closure verdict:** **OPEN P2 / EVIDENCE-CLASS WORDING PARTIAL**.

### P2-C-04 — The authority negative test hard-codes `rw-s`

Lines 638–639 require wrong operation/capability or “`rw-s` access” to fail.
Current v3 register/resolve/submit and Lane A's proposed revoke use `rw-s`,
while Lane A's proposed status uses `r--s`. A single hard-coded access string
does not express operation-specific exact Grant matching and is ambiguous
about whether correct `rw-s` should fail or a wrong access value should fail.

**Smallest successor scope:** make the matrix operation-specific and test both
the exact required access and every privilege-substitution case, including
status `r--s` versus mutation `rw-s`, after Lane A owner acceptance.

**Closure verdict:** **OPEN P2 / NEGATIVE-TEST MATRIX PARTIAL**.

## 7. Supported Lane C claims

The following Lane C planning claims survived this static review:

- bundle/topic `org.digipomps.haven` and origin
  `https://haven.digipomps.org` are consistently treated as intended planning
  values, not production proof;
- the persistent requester is the existing authenticated vault identity in
  `domain:device:notification-callback`; missing identity fails closed and no
  server secret or automatic owner authority is invented;
- transport is semantically neutral and preserves canonical challenge,
  request, protected-body and raw response bytes;
- the three-field protected-operation wrapper does not falsely add the signed
  Agreement/Contract or response as request fields;
- raw APNS token storage in `UserDefaults`, evidence and logs is prohibited;
- a historical registration receipt is not current registration;
- persist-before-send, descriptor-relative storage, external anchoring,
  cross-process locking and filesystem-link/path-swap negatives are explicitly
  required;
- pre-registration decline is distinguished from typed server revocation in
  the case where prior server state is authoritatively known;
- Lane C does not invent status/revoke/deregister/rotation wire enums;
- Identity cutover remains a separate prerequisite;
- `MBI-06` profile, signing, entitlements and archive evidence remains
  unaudited;
- `MBI-07` exact integrated output remains missing; and
- no operational or source authorization is claimed.

These are planning-quality positives only. They do not offset the open P1
composition gaps.

## 8. MBI-05 adjudication

| MBI-05 subclaim | Review verdict |
| --- | --- |
| Exact future Binding source/test/project/doc allowlist | **PARTIAL** — main consumer paths are named, but the Apple no-touch ledger is incomplete and challenge-consumer inputs remain conditional |
| Exact client-local registration state model | **PARTIAL** — historical/current separation is sound, but empty-local continuity and ambiguous recovery are unresolved |
| Exact challenge state model | **OPEN** — signed intent and issuer-generation continuity are absent |
| Exact resolve/submit durable state model | **OPEN** — prose only, with no complete crash/read-back contract |
| Byte-preserving neutral transport consumption | **SUPPORTED AS PLAN, BLOCKED ON REVIEWED PRODUCER ARTIFACT** |
| Persistent identity/vault binding | **SUPPORTED AS PLAN, IDENTITY CUTOVER STILL SEPARATE** |
| No raw-token/evidence leakage | **SUPPORTED AS REQUIREMENT, NOT RUNTIME PROOF** |
| Status/revoke/deregister/rotation implementation readiness | **OPEN / BLOCKED ON MBI-01...04 AND P1-C-01...03** |
| Production signing/upload readiness | **OPEN / UNAUDITED (`MBI-06`)** |
| Exact integrated output | **OPEN / MISSING (`MBI-07`)** |

Overall:

```text
MBI-05: PARTIAL — NOT CLOSED
```

## 9. Exact smallest successor planning scopes

No successor is authorized by this review. If development-admin later opens
document-only correction work, the smallest non-overlapping scopes are:

1. **Lane A/B discovery and ambiguous-response decision:** freeze
   subject-bound discovery/current status and/or admission-ID exact-response
   retrieval, including register and submit crash adjudication without raw
   body persistence.
2. **Lane A challenge owner decision:** accept or replace the signed
   challenge-intent and issuer-rotation proposal, then freeze exact fixture
   bytes and hashes.
3. **Lane C correction:** consume only reviewed outputs from scopes 1–2; add
   empty-local-server-unknown, challenge-intent, issuer-generation,
   operation-specific resolve/submit and ambiguous states; correct the
   path/no-touch and evidence-class matrices.
4. **Independent exact-byte re-review:** a reviewer distinct from the
   correction author reproduces all bytes, objects, paths and closures.

Each scope remains planning-only unless separately authorized. None may be
silently combined with Identity cutover, Apple signing or integrated output.

## 10. Preserved stops and final verdict

- S0 remains immutable and NO-GO.
- Lane A and Lane B are peer author packets, not reviewed implementation
  contracts.
- Identity cutover remains a separate prerequisite and was not inspected.
- `MBI-06` production profile, Team, certificate, effective
  `aps-environment=production`, codesign and archive evidence remains missing.
- `MBI-07` integrated CellProtocol/Identity/CellScaffold/Binding output remains
  missing.
- No raw token, secret or private key was read, displayed or stored.
- No source, Git, build, test, network, portal, signing, device, APNS,
  Identity, staging or deployment action is authorized.

Final independent review decision:

```text
P0: 0
P1: 3
P2: 4

LANE C EXACT-BYTE REVIEW: COMPLETE
LANE C PACKET: NO-GO
MBI-05: PARTIAL / OPEN
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
```

The review stops after freezing and re-attesting this one review artifact.
