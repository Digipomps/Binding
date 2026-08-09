# APNS S2 Binding Client Contract Correction Packet

Status: **AUTHOR-FROZEN / STATIC CORRECTION ONLY / LANE C NO-GO / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO**

Date: `2026-07-24`  
Lane: S2 C — Binding client correction  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_2026-07-24.md`

This document corrects the author-frozen S1 Lane C plan. It does not amend,
replace or award closure to any S0 or S1 artifact. It grants no authority for
source edits, Git mutation, dependency resolution, build, test, network,
portal, signing, archive, device action, APNS contact, secret access, Identity
work, staging mutation, deployment or a next material phase.

The output path was re-attested absent immediately before this document was
created. An independent reviewer distinct from this author must reproduce the
exact bytes and adjudicate every proposed finding disposition.

## 1. Exact immutable input gate

### 1.1 Immutable S0 chain

| Input | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

The inherited S0 result remains immutable:

```text
P0/P1/P2: 0/2/1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

### 1.2 Exact six-document S1 chain

| Lane | Artifact | SHA-256 | Lines | Bytes | Frozen review result |
| --- | --- | --- | ---: | ---: | --- |
| A packet | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | Author proposal |
| A review | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md` | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | `0/5/2`, NO-GO |
| B packet | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | Author proposal |
| B review | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md` | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | `0/4/1`, NO-GO |
| C packet | `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | Author proposal |
| C review | `Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md` | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | `0/3/4`, NO-GO |

This correction consumes the reviewed facts and blocker classifications, not
the unreviewed semantics as if they were canonical. In particular:

- A's status, revoke and signed challenge-intent shapes remain proposals;
- A review keeps `MBI-01`, `MBI-02` and `MBI-03` partial/open;
- B review keeps `MBI-04` non-green and operationally missing;
- C review keeps `MBI-05` partial/open; and
- all S0/S1 NO-GOs remain operative.

## 2. Purpose, goal and claim boundary

Purposes:

- `purpose://test.acceptance`: make every client-local transition and
  ambiguous crash outcome testable without claiming runtime evidence.
- `purpose://access.audit.privacy`: keep raw APNS token, protected callback
  bytes, private keys and unredacted evidence out of logs, defaults, fixtures
  and generic diagnostics.
- `purpose://scaffold.operations`: name exact future owners and collision
  boundaries while authorizing no implementation or operational action.

Author goal:

> Correct all seven S1 C-review findings by freezing a total, fail-closed
> Binding state/recovery plan that consumes reviewed CellProtocol and server
> outputs only, never invents a trust root or server wire shape, and keeps
> production signing and integrated provenance separate.

Evidence rule:

- an immutable source object supports only what those bytes implement;
- an author packet plus its NO-GO review is an interface proposal and blocker
  input, not a canonical implementation contract;
- a complete local state graph may end in a typed unavailable/unknown state;
- local absence, historical evidence or a transport success never proves
  current server state;
- no plan-level self-disposition is independent-review credit; and
- any missing upstream semantic keeps source and production closed.

## 3. Reproduced immutable implementation facts

### 3.1 CellProtocol v3

| Boundary | Commit | Tree |
| --- | --- | --- |
| Canonical v3 candidate | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` | `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` |
| v3 base | `79740304167aa4f4daadd148c5a369e919d25a6a` | `71ee11a69139a1c222c2156ab1bc79dbe0115620` |

The immutable contract implements exactly `register`, `resolve` and `submit`.
Each currently derives `requiredAccess == "rw-s"` from the operation. It does
not implement status, revoke, deregister, signed challenge intent, admission
read-back or token-rotation correlation.

`DeviceIngressResponseExpectation` already includes:

```text
operation
admissionID = base64url(requestSHA256)
requestSHA256
challengeSHA256
bodySHA256
subject identity UUID and signing-key fingerprint
target Cell UUID
target owner identity UUID and signing-key fingerprint
signed Agreement SHA-256
authority generation
revocation ledger ID and generation
content policy
request issued/expires timestamps
```

It does not include the `registrationID` first returned by a verified register
response. The existing protected register body may contain the raw APNS token.

### 3.2 Binding candidate

| Boundary | Commit | Tree |
| --- | --- | --- |
| DeviceIngress P1 candidate | `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c` | `e0d6c9ff4fb998fa252ab86621abfe24398d7b18` |
| Common base | `f6536c497b0a4c0a5b32531416bb3712708cf47e` | `ac894efa9e709e788eaa1dc863db1070786fbe0b` |
| Apple M1 endpoint | `2d2412090a65e101435ea91c8ea36bc060d3c768` | `34421cbabe9e801fa96da315a191ed23cd023ec8` |

The P1 candidate provides an authenticated persistent CellApple identity in
`domain:device:notification-callback`, `makeNewIfNotFound=false`, canonical
request preparation, persist-before-submit expectation storage, verified
owner-signed response handling, descriptor-relative journal access,
cross-process locking, external anchoring and historical evidence rebound to
the current vault/build. It remains inert and provides no current-status proof.

Raw APNS token storage in `UserDefaults` is prohibited. Legacy/current token
keys are removed without first reading the token bytes.

### 3.3 Frozen production identifiers

```text
bundle identifier = org.digipomps.haven
APNS topic         = org.digipomps.haven
public origin      = https://haven.digipomps.org
purpose            = purpose://access.audit.privacy/device-notification-callback
identity domain    = domain:device:notification-callback
```

These are composition intentions only. They are not effective entitlements,
signing/profile evidence, TLS/origin evidence, provider readiness, APNS
acceptance or device delivery evidence.

## 4. Correction disposition map

Every disposition below is **author-proposed pending independent review**.

| S1 C finding | S2 correction | Author disposition |
| --- | --- | --- |
| `P1-C-01` empty local evidence promoted to not registered | Sections 5 and 8 make every absent/empty/restored store `localEvidenceAbsentServerUnknown`; only fresh signed subject-bound current status may establish active, revoked or authoritative not-found | PROPOSED CLOSED AS CLIENT PLAN |
| `P1-C-02` ambiguous recovery has no composable path | Sections 6–8 bind expectation/admission/registration/read-back identities into one total graph; absence of a canonical recovery operation terminates in a typed blocked/unknown state, never replay or success | PROPOSED CLOSED AS FAIL-CLOSED CLIENT PLAN; UPSTREAM INTERFACE OPEN |
| `P1-C-03` challenge omits signed intent and issuer continuity | Section 9 freezes intent preparation, nonce lifecycle, issuer watermark and rotation-proof handling; operation remains unavailable until reviewed producer/server inputs exist | PROPOSED CLOSED AS CONDITIONAL CONSUMER PLAN |
| `P2-C-01` resolve/submit are prose only | Section 12 names exact durable and volatile states, retained fields, crash boundaries and terminal outcomes | PROPOSED CLOSED |
| `P2-C-02` Apple no-touch incomplete | Section 15 enumerates the exact 11-path Apple M1 ledger | PROPOSED CLOSED |
| `P2-C-03` status asked to prove topic/origin/signing | Section 14 separates Cell status, transport and Apple/provider evidence classes | PROPOSED CLOSED |
| `P2-C-04` authority test hard-codes `rw-s` | Sections 7 and 16 derive access from each reviewed operation and test privilege substitution per operation | PROPOSED CLOSED |

No upstream A/B finding is closed here. The client can be internally total
while the missing producer/server transition remains deliberately
unreachable.

## 5. Corrected truth model

### 5.1 Truth values

Binding exposes these distinct client truths:

| Truth | Required proof | User-visible meaning |
| --- | --- | --- |
| `unknown` | Default whenever a fresh authoritative result is absent | Server registration state is not known; no positive or negative assertion |
| `activeCurrent` | Fresh verified signed current-status response for the current persistent subject, exact target/owner/Contract and non-regressed generations | DeviceIngress registration is currently active |
| `revokedCurrent` | Fresh verified signed status after a verified typed revoke receipt/tombstone | DeviceIngress registration is currently revoked |
| `deregisteredCurrent` | Only if a future canonical contract defines and proves this state | DeviceIngress registration is currently deregistered |
| `notFoundCurrent` | Fresh owner-signed subject-bound current discovery/status result with exact authoritative absence semantics | No current record was found for this subject at the signed observation time |
| `blocked` | Typed dependency, authority, storage, recovery or transport unavailability | No state assertion and no unsafe retry |

`not registered` is not a synonym for empty local storage. UI/API wording must
preserve `unknown` versus a fresh signed authoritative negative result.

### 5.2 Empty, restored and lost evidence

Each of the following enters `localEvidenceAbsentServerUnknown`:

- an initial empty evidence journal;
- app restore with no verified local DeviceIngress record;
- uninstall/reinstall evidence loss;
- rejected copied evidence;
- rejected legacy evidence;
- a vault-valid device identity with no matching local record; or
- a reset evidence store following a verified local integrity failure.

While in this state:

- `isDeviceRegistered` is false because current registration is unproved, not
  because absence is proved;
- the UI reports state unknown/unavailable, never authoritative “not
  registered”;
- acceptance, register, pre-registration decline, local clear, revoke,
  deregister, resolve and submit are disabled;
- only a fresh canonical subject-bound discovery/current-status operation may
  adjudicate state;
- an authoritative unique `active` result enters `activeCurrent`;
- an authoritative unique `revoked`/future `deregistered` result enters the
  corresponding current negative state;
- authoritative `not_found` may open first-registration or pre-registration
  decline; and
- multiple records, unavailable, stale, unsigned or indeterminate results
  remain `unknown` and fail closed.

Lane A's reviewed S1 proposal requires a `registrationID` and therefore cannot
perform this discovery. The exact subject-bound selector, privacy boundary,
multi-record result and fixtures remain an upstream `MBI-01` blocker. Binding
does not invent them.

## 6. Client-local durable evidence record

The following is a **Binding-local planning schema**, not a CellProtocol wire
schema and not authority:

```text
BindingDeviceIngressClientEvidence.v2
```

### 6.1 Common durable fields

| Field | Rule |
| --- | --- |
| `storeSchema` | Exact local schema/version |
| `journalSequence` | Strictly increasing, externally anchored |
| `stateKind` | One exact state from this packet |
| `identityDomain` | Exact notification callback domain |
| `subjectIdentityUUID` | Current persistent vault subject |
| `subjectSigningKeyFingerprint` | Must rebind to the currently opened vault |
| `domainBindingSHA256` | Digest of the verified non-authoritative vault binding |
| `clientAttemptID` | Fresh local random opaque identifier per prepared operation; grants no authority |
| `operation` | Exact operation enum consumed from the pinned protocol artifact |
| `expectationRecordID` | Local random opaque ID binding one durable expectation record |
| `responseExpectation` | Complete `DeviceIngressResponseExpectation`, not reconstructed from a response |
| `requestSHA256` | Must equal the expectation field |
| `admissionID` | Must equal `base64url(requestSHA256)` and the expectation field |
| `challengeSHA256` | Must equal the expectation field |
| `protectedBodySHA256` | Must equal `bodySHA256` in the expectation |
| `requestIssuedAt/ExpiresAt` | Exact expectation timestamps |
| `sendBoundary` | `not_sent`, `send_started`, `response_received_unverified`, or `ambiguous` |
| `verifiedResponseSHA256` | Present only after canonical verification |
| `historicalResultKind` | Sanitized operation/result discriminator only |
| `localTombstoneKind` | Intended/ambiguous stop marker; never server truth |
| `buildEvidenceDigest` | Audit/rebind input only; never authority |

The record may retain exact signed response bytes only when:

1. the exact operation-derived Grant contains Storage (`s`);
2. the response content policy permits requester retention;
3. the bytes are stored only in the hardened private evidence store; and
4. no raw token, protected request body, private key or unredacted resolved
   callback payload is thereby retained.

The record never contains:

- a raw APNS token;
- a token string or reversible token derivative;
- the canonical protected request body;
- a private signing key;
- a bearer/shared server secret;
- an unredacted resolved callback payload;
- an unreviewed server authority blob; or
- a claim that a digest proves protected-body semantics by itself.

`bodySHA256` is retained because the canonical expectation already binds it.
It is sensitive correlation evidence and must not appear in logs, analytics,
errors, UI, exports or general diagnostics.

### 6.2 Registration recovery extension

After a verified register response, and never before, the durable record may
add:

```text
registrationID
registrationGeneration
durableSequence
registrationRecordSHA256
registerResponseSHA256
registerAdmissionID
tokenObservationID
tokenDeliveryEpoch
```

`registrationID` and `registrationGeneration` come only from a response
verified against the stored expectation. `tokenObservationID` is a fresh local
random opaque identifier. `tokenDeliveryEpoch` is a local monotonic event
counter. Neither contains or derives from the token. Their mapping to
`protectedBodySHA256` and `registerAdmissionID` records which in-memory token
observation was used to construct that protected request.

### 6.3 Read-back recovery extension

Every current-status or admission-read-back attempt receives a new
`clientAttemptID`, `expectationRecordID` and, where canonical request
preparation exists, a complete response expectation. A verified read-back
record must bind:

```text
readBackKind
readBackRequestSHA256
readBackAdmissionID
recoveredOperationAdmissionID
registrationID, if known
subject UUID/key fingerprint
target Cell and target owner
signed Agreement/Contract digest
authority and revocation generations
registration generation
observed/admitted/committed timestamps
canonical verified response digest
freshness expiry
```

A future admission-result retrieval must authenticate all expectation
bindings, not accept `admissionID` as a capability. A future subject-bound
status discovery must authenticate the persistent subject and return
owner-signed unique/current/multiple/not-found semantics. Neither operation is
present in reviewed canonical source; the client remains blocked until the
producer and server independently freeze them.

## 7. Operation-specific authority and retention

Binding never hard-codes one permission string for all operations. It requires:

```text
preparedExpectation.operation == intendedOperation
request.requiredAccess == request.operation.requiredAccess
signed Contract Grant access == request.operation.requiredAccess
```

The current and proposed interface ledger is:

| Operation | Required access | Status |
| --- | --- | --- |
| `register` | `rw-s` | Immutable current v3 fact |
| `resolve` | `rw-s` | Immutable current v3 fact |
| `submit` | `rw-s` | Immutable current v3 fact |
| `status` | `r--s` | S1 A author proposal; not canonical |
| `revoke` | `rw-s` | S1 A author proposal; not canonical |
| `deregister` | none | Undefined; unavailable |
| admission/read-back | none | Undefined; unavailable |

No proposed row can be compiled into client availability until an
independently reviewed producer artifact supplies its exact operation,
resource, action, capability, access, schema and fixtures.

Storage (`s`) is necessary but not sufficient for client persistence. Binding
also requires content-policy permission and a reviewed local retention path.
For resolved callback content this packet chooses the privacy-safe default:
volatile processing only, even when `s` is present. A later product decision
may add retention through a separate reviewed packet; its absence does not
authorize generic persistence.

## 8. Total crash, restart and ambiguous-recovery graph

### 8.1 Common transaction states

Every protected operation uses these exact local phases:

```text
operationRequested
  -> challengeIntentDurable
  -> challengeRequestPending
  -> challengeVerified
  -> protectedRequestPrepared
  -> expectationDurableNotSent
  -> sendStarted
  -> responseReceivedUnverified | sendOutcomeAmbiguous
  -> verifiedHistoricalResult | verificationRejected
  -> currentStateReadBackPending | admissionReadBackPending
  -> currentVerified | historicalOnly | blockedAdjudicationUnavailable
```

Rules:

1. The intent record is durable before the challenge request.
2. The complete response expectation and local attempt binding are durable
   before the protected-operation send.
3. `expectationDurableNotSent` may be sent exactly once in the current process
   only after the store lock proves `sendStarted` was never crossed.
4. Any crash or cancellation at/after `sendStarted` reopens as
   `sendOutcomeAmbiguous`.
5. An ambiguous mutation is never reconstructed, retried with new bytes,
   declared failed or declared successful.
6. An exact replay after restart is permitted only if the exact protected body
   is safely available under a reviewed retention contract. This packet
   deliberately stores no such body; therefore automatic exact replay is
   unavailable.
7. Recovery first requests canonical admission-result read-back by the stored
   admission/expectation bindings, if such a reviewed operation exists.
8. If no admission response is found or the operation cannot prove current
   domain state, recovery requests a fresh canonical current status/discovery.
9. If either interface is absent, unavailable, stale, conflicting or cannot
   address the record, the total graph terminates at
   `blockedAdjudicationUnavailable` with truth `unknown`.
10. No blocked state clears the expectation, local tombstone or token
    observation lineage.

This is a total client graph: every crash boundary has a deterministic safe
state. It is not an operational recovery claim. The missing admission/status
wire and server paths remain blockers rather than guessed bytes.

### 8.2 Register-specific graph

```text
localEvidenceAbsentServerUnknown
  -> signedSubjectDiscoveryPending
  -> notFoundCurrent
  -> consentCurrent
  -> tokenObservedInMemory
  -> register challenge/prepare/common transaction
  -> registerVerifiedHistorical
  -> freshStatusPending
  -> activeCurrent | revokedCurrent | notFoundCurrent | unknown
```

For an ambiguous first registration:

```text
registerSendOutcomeAmbiguous
  -> admissionReadBackPending(admissionID + full expectation)
  -> registerVerifiedHistorical | admissionNotFoundAuthoritative
     | blockedAdjudicationUnavailable
  -> freshSubject/statusReadBackPending
  -> current truth or unknown
```

`registrationID` is not assumed before a verified register response. A status
request that mandates an unavailable `registrationID` cannot adjudicate this
branch.

### 8.3 Historical versus current

- A verified register response proves one historical target-Cell mutation.
- An identical replayed status response proves the historical snapshot it
  signed, not a fresh state.
- Only a new challenge/request and fresh owner-signed status/discovery response
  within its exact freshness window may establish `activeCurrent`,
  `revokedCurrent` or `notFoundCurrent`.
- Expiry, foreground refresh requirement, authority-generation regression,
  revocation-generation regression, target/owner/Contract change or vault
  rebind immediately returns truth to `unknown`.

## 9. Signed challenge-intent and issuer continuity

### 9.1 Conditional consumer contract

The S1 A proposal describes
`cellprotocol.device-ingress.challenge-intent.v1`. Binding conditionally
consumes, but does not make canonical, its exact field set:

```text
schema
intentID
requester CSPRNG nonce (32...64 bytes)
operation
purpose
audience
identityDomain
subject public descriptor
authorityID lookup hint
agreementID lookup hint
minimumChallengeIssuerGeneration
issuedAtMilliseconds
expiresAtMilliseconds
domainBinding with grantsAuthority=false
subject proof
```

The challenge-intent state record contains:

```text
intentRecordID
canonical signed intent bytes
intentSHA256
intentID
nonceSHA256
operation
subject UUID/key fingerprint
minimum issuer generation
issued/expires timestamps
send boundary
returned challenge SHA-256, after verification
```

Exact signed intent bytes are retained only in the hardened evidence store,
never logs or diagnostics, because they are required for exact challenge replay
comparison. The raw nonce exists only inside those protected canonical bytes
and volatile preparation memory; UI/telemetry exposes neither nonce nor
digest.

### 9.2 Nonce lifecycle

- Create one 32...64 byte CSPRNG nonce for one intent.
- Persist the signed intent before first challenge request.
- Identical retry before intent expiry uses the exact same intent bytes.
- Same subject/intent nonce with different canonical bytes is rejected.
- The nonce is never reused for another operation, subject, authority hint or
  expired intent.
- After expiry, close the old intent as historical and create a new intent and
  nonce; never mutate or re-sign the old bytes.
- A challenge must echo/bind the exact subject, nonce, operation, purpose,
  audience, domain, target, owner, Contract and generation inputs before
  `RequestFactory.prepare`.

### 9.3 Issuer-generation watermark

Binding maintains an externally anchored, rollback-resistant local record:

```text
highestAcceptedChallengeIssuerGeneration
acceptedIssuerDescriptorSHA256
acceptedRotationRecordSHA256
previousAnchorSequence
```

Rules:

- a lower generation fails closed;
- an equal generation must match the already accepted issuer descriptor;
- a higher generation is accepted only through a canonical owner-signed
  rotation record that binds the old descriptor, new descriptor, generation
  and activation time;
- the watermark is committed and read back before a challenge from the higher
  generation is used;
- copied, truncated or rolled-back watermark state fails closed; and
- no TLS certificate, HTTP host, app signing identity or requester-supplied
  hint becomes the issuer trust root.

The rotation-record schema, production issuer descriptor, owner proof and
rollback anchor remain genuine upstream authority decisions (`OD-05`,
`B-DEC-01`, `B-DEC-04`). Until reviewed bytes exist, Binding enters
`challengeBlockedIssuerManifestUnavailable` before network.

### 9.4 Transport preconditions

The S1 A challenge route/carrier is not production-approved because its review
keeps origin/audience, secure scheme, redirect/TLS and decode ownership open.
Binding therefore requires a later reviewed transport artifact to freeze:

- exact HTTPS origin and authority projection;
- method/path and media types;
- redirects disabled or an exact reviewed same-origin rule;
- TLS/certificate failure behavior;
- content encoding;
- challenge carrier limits;
- operation inspection owner; and
- raw canonical challenge response.

HTTP remains semantically neutral and grants no authority.

## 10. Consent, revoke and deregister

### 10.1 Pre-registration “Not now”

“Not now” is available only when all are true in one evidence-store
transaction:

1. a fresh signed subject-bound discovery/status response is
   `notFoundCurrent`;
2. no pending, ambiguous, historical or current register/stop evidence exists;
3. no local stop tombstone exists;
4. the same vault identity and evidence inode/name/lock binding remain valid;
5. no concurrent token, accept or operation event crossed the transaction.

The transaction durably records `preRegistrationDeclined` and performs any
permitted local UI/default clear before releasing the same lock. Empty local
evidence alone never opens this path.

### 10.2 Post-registration stop

When registration exists or may exist:

- local clear cannot represent server revocation;
- consent withdrawal creates a durable local `stopIntentPending` tombstone;
- the typed canonical revoke/deregister request expectation is persisted
  before send;
- ambiguous stop preserves both tombstone and expectation;
- only a verified typed receipt plus fresh signed status advances to a current
  negative state; and
- unavailable canonical stop keeps local truth unknown and suppresses active
  behavior without claiming the server changed.

S1 A defines a proposed `revoke` but does not define whether deregistration is
an alias, a separate operation or unsupported. Binding exposes no
`deregister` send until the contract owner freezes that choice. The client
API/UI may use the neutral product phrase “turn off notifications,” but it
must map to one reviewed typed operation and result, never to local deletion.

## 11. Token-rotation continuity

### 11.1 Token observation

For each iOS token callback:

1. keep the raw token in process memory only;
2. allocate a fresh non-secret `tokenObservationID`;
3. increment a local `tokenDeliveryEpoch`;
4. never compare against or restore a token from defaults/disk;
5. map the observation to the prepared expectation's body digest and
   admission ID before send; and
6. erase the raw token from client-owned memory as soon as preparation/send no
   longer needs it.

On process restart the next iOS token callback is a new observation even if
the bytes happen to be unchanged. No persistent token hash is invented.

### 11.2 Rotation state graph

```text
activeCurrent
  + tokenObservedInMemory
  -> rotationObservationPending
  -> registerOrUpdatePreparedPending | rotationContractUnavailable
  -> rotationSendAmbiguous | rotationReceiptHistorical
  -> rotationAdmissionReadBackPending
  -> rotationStatusCorrelationPending
  -> activeCurrentForObservation | blockedRotationUnknown
```

The immutable v3 `register` action is named `registerOrUpdateDevice`, but that
name alone does not prove rotation CAS or correlation semantics. Binding may
use it for rotation only after the canonical contract and server freeze:

- expected prior registration/revocation generation or an equivalent safe
  concurrency rule;
- response binding to the exact update admission/request/body;
- current status binding to that admitted update;
- ordering under concurrent authorized updates; and
- exact stale/already-current/conflict behavior.

`registrationGeneration` increasing by itself does not prove which concurrent
token update won. `activeCurrentForObservation` therefore requires fresh
signed current status that correlates the current server record to the exact
admission/request/body digest associated with the current
`tokenObservationID`. S1 A does not yet provide that field. The state remains
`blockedRotationUnknown`; no automatic retry, token persistence or optimistic
active claim is permitted.

## 12. Exact resolve and submit state contract

### 12.1 Resolve durable states

| State | Durable fields | Permitted transition |
| --- | --- | --- |
| `resolveWakeObserved` | Opaque bounded ticket/correlation reference only | Authority/status precheck |
| `resolveChallengeIntentDurable` | Signed intent record from section 9 | Challenge fetch |
| `resolveChallengeVerified` | Intent/challenge digests and issuer watermark | Prepare |
| `resolvePreparedPending` | Full expectation, attempt ID, admission ID, ticket reference; no protected body | One send |
| `resolveSendAmbiguous` | Same pending record | Admission/read-back only |
| `resolveResponseVerifiedVolatile` | Response digest and sanitized lineage only; resolved payload in memory | Contract-governed decision |
| `resolveHistoricalNoPayload` | Response digest/lineage, no payload | Fresh canonical recovery or stop |
| `resolveDecisionPending` | Sanitized local decision ID and exact resolved-ticket lineage; decision content volatile | Prepare submit |
| `resolveBlocked` | Typed sanitized reason | No send |

The exact resolved ticket may be retained only if the operation-specific Grant,
content policy and a later independently reviewed protected retention path all
permit it. This packet supplies no such path, so the S2 default is volatile
only. Crash after verified resolve but before submit enters
`resolveHistoricalNoPayload`; it does not reconstruct the payload or invent a
decision.

### 12.2 Submit durable states

| State | Durable fields | Permitted transition |
| --- | --- | --- |
| `submitChallengeIntentDurable` | Signed intent record; sanitized decision/ticket lineage | Challenge fetch |
| `submitChallengeVerified` | Intent/challenge digests and issuer watermark | Prepare |
| `submitPreparedPending` | Full expectation, attempt/admission IDs and lineage; no unredacted result body | One send |
| `submitSendAmbiguous` | Same pending record plus local tombstone | Admission/read-back only |
| `submitReceiptHistorical` | Verified receipt digest, submission ID/generation if canonical result supplies them | Fresh submit status/read-back |
| `submitCurrentConfirmed` | Fresh signed operation-specific read-back, if later defined | Terminal success |
| `submitBlocked` | Typed sanitized reason | No send |

A verified submission receipt proves a historical durable mutation. If the
reviewed protocol defines that receipt itself as the terminal current fact,
the contract owner must say so explicitly; Binding does not infer it. An
ambiguous submit remains pending until exact admission-result/status read-back.

### 12.3 Resolve/submit transaction boundaries

- Persist intent before challenge request.
- Persist expectation before protected send.
- Bind one ticket, one decision lineage and one admission ID per attempt.
- Serialize resolve versus resolve, resolve versus submit and submit versus
  submit across actors, store instances and processes.
- Never log ticket contents, resolved payload, prompt, decision or result.
- Never store an unredacted protected body merely for replay.
- A missing `s` Grant forbids response retention.
- Presence of `s` does not override the default volatile-only S2 policy.
- Crash, disk-full, fsync failure, anchor failure or cross-process conflict
  enters a named blocked/ambiguous state.

## 13. Reconciled A/B transport and authority interface

### 13.1 Shared byte carrier

The future client may consume only the independently reviewed shared
CellProtocol transport product proposed by Lane A:

```text
repository: CellProtocol
product: CellDeviceIngressTransport
source: Sources/CellDeviceIngressTransport/DeviceIngressHTTPTransport.swift
tests: Tests/CellDeviceIngressTransportTests/DeviceIngressHTTPTransportTests.swift
```

The protected-operation request wrapper has exactly:

```text
schema
canonicalChallenge
canonicalRequest
protectedBody
```

The signed Agreement/Contract is Resolver/target-Cell authority evidence, not
a fourth wrapper input. The successful response is raw canonical operation
response bytes, not a request field or response wrapper.

Lane A review leaves the exact route-operation decode owner open
(`P1-A-01`) and the canonical producer fixture manifest path missing
(`P2-A-02`). Binding therefore cannot populate a consumer manifest or implement
route binding until those producer outputs are independently green.

### 13.2 Server dependencies

Binding requires, but does not define:

- a persistent challenge issuer Cell with exact-byte replay;
- per-operation Resolver/Agreement enforcement;
- durable admission before every target operation, including status;
- exact response storage/read-back and byte-identical replay;
- same-target atomic mutation/receipt/response;
- subject-bound current status/discovery;
- admission-result retrieval for ambiguous requests;
- typed revoke and an explicit deregister decision;
- rollback-resistant authority/revocation/issuer generations;
- protected token storage without plaintext leakage; and
- fail-closed operation-specific readiness.

Lane B review keeps its access, status-admission, Resolver Cell registration
and challenge-byte replay findings open. Binding may not code around them with
HTTP truth, static authority, a server secret, host ownership or a local
fallback.

## 14. Evidence classes and production readiness

The production gate is an AND of independent evidence classes:

| Evidence class | What it may prove | What it cannot prove |
| --- | --- | --- |
| Fresh signed DeviceIngress current status | Current target-Cell registration state for the exact subject/owner/Contract and generations | HTTPS/TLS behavior, APNS topic, profile, entitlement, provider readiness or device receipt |
| Admission/read-back | Historical exact request/response decision for one expectation/admission | Current registration unless the canonical result explicitly proves it |
| Byte-preserving transport evidence | Exact origin, TLS, method/path, no redirect/downgrade and unchanged bytes | Cell authority or operation success |
| Apple signed-archive evidence (`MBI-06`) | Bundle/topic/profile/Team/certificate/effective `aps-environment=production` and codesign provenance | Cell registration or APNS/device delivery |
| Provider acceptance | Apple accepted one sanitized provider request | Device receipt |
| Device/Binding callback evidence | Physical delivery and app callback for one correlation ID | General production readiness by itself |
| Integrated provenance (`MBI-07`) | Exact reviewed source/dependency/build composition | Runtime delivery without the other evidence |

Bundle/topic `org.digipomps.haven` and origin
`https://haven.digipomps.org` must align across the final composition, but one
evidence class never substitutes for another.

## 15. Exact future Binding path and ownership packet

This is a planning allowlist only. It is not write authority.

### 15.1 Binding DeviceIngress client owner

Existing paths:

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

New exact paths:

```text
Binding/DeviceIngressClientStateMachine.swift
Binding/DeviceIngressClientEvidenceStore.swift
Binding/DeviceIngressChallengeIntentState.swift
Binding/DeviceIngressOperationRecovery.swift
Binding/DeviceIngressTokenObservation.swift
Binding/DeviceIngressHTTPTransport.swift
BindingTests/DeviceIngressClientStateMachineTests.swift
BindingTests/DeviceIngressClientEvidenceStoreTests.swift
BindingTests/DeviceIngressChallengeIntentStateTests.swift
BindingTests/DeviceIngressOperationRecoveryTests.swift
BindingTests/DeviceIngressTokenRotationTests.swift
BindingTests/DeviceIngressHTTPTransportTests.swift
BindingTests/DeviceIngressPrivacyTests.swift
BindingTests/Fixtures/DeviceIngressHTTPTransport.v3.json
BindingTests/Fixtures/DeviceIngressSharedFixtureManifest.json
Documentation/DeviceIngressBindingClientStateMachine.md
Documentation/DeviceIngressBindingPrivacyAndRecovery.md
```

Responsibilities:

- `DeviceIngressClientStateMachine.swift`: total reducer and truth model; no
  wire schema.
- `DeviceIngressClientEvidenceStore.swift`: hardened journal/anchor,
  attempt/expectation/read-back records and atomic consent gate.
- `DeviceIngressChallengeIntentState.swift`: conditional signed-intent,
  nonce and issuer-watermark consumer.
- `DeviceIngressOperationRecovery.swift`: admission/status adjudication
  interfaces; unavailable until reviewed producer artifacts.
- `DeviceIngressTokenObservation.swift`: in-memory token lifecycle and
  non-secret observation lineage.
- `DeviceIngressHTTPTransport.swift`: thin byte-preserving shared-product
  adapter; no authority.
- registration/callback/enrollment/app files: orchestration and UI events only.
- test/fixture/doc paths: exact state, recovery, privacy and producer-manifest
  consumption evidence.

### 15.2 Development-admin integrator

Only the later development-admin integrator owns final bytes for:

```text
Binding.xcodeproj/project.pbxproj
Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

The project file collides with Apple M1. Final membership must be composed
once from the common base and independently reviewed by both owners.
`Package.resolved` changes only if a later authorized, independently selected
artifact requires it. No dependency resolution is authorized here.

### 15.3 Exact Apple M1 no-touch ledger

All 11 paths in the immutable
`f6536c497b0a4c0a5b32531416bb3712708cf47e..2d2412090a65e101435ea91c8ea36bc060d3c768`
endpoint remain outside the Binding DeviceIngress client owner:

```text
Binding.xcodeproj/project.pbxproj
Documentation/AppleReleaseM0Policy.template.json
Documentation/AppleReleaseM0Preflight.md
Scripts/apple_release_m0_preflight.py
Scripts/apple_release_m0_preflight.sh
Tests/apple_release_m0_preflight_tests.py
Tests/fixtures/apple_release_m0_preflight/facts-dirty.json
Tests/fixtures/apple_release_m0_preflight/facts-pass.json
Tests/fixtures/apple_release_m0_preflight/policy-mismatch.json
Tests/fixtures/apple_release_m0_preflight/policy-pass.json
Tests/fixtures/apple_release_m0_preflight/policy-pending.json
```

`Binding.xcodeproj/project.pbxproj` is a development-admin collision path, not
a client-owned path. The other ten remain solely with the Apple release owner.

### 15.4 Other no-touch boundaries

The production entitlement path remains separately owned and no-touch:

```text
Binding/Binding-iOS.entitlements
```

Lane C owns no CellProtocol, CellScaffold, Identity, APNS provider, AASA,
deployment, staging, portal, secret or signing path. Primary dirty worktree
bytes remain no-touch and may not be cleaned, copied or treated as release
input.

No path not explicitly listed in sections 15.1–15.2 is authorized by this
packet. A producer-required path change requires a new document-only owner
decision and independent review.

## 16. Required exact negative-test packet

No test is run or claimed here. Each future test must use reviewed canonical
fixtures and exact sanitized reason codes.

### 16.1 Empty-local and current truth

- Empty initial journal enters `localEvidenceAbsentServerUnknown`.
- Restore, uninstall/reinstall and rejected copied evidence enter the same
  state.
- Empty local state never renders authoritative “not registered.”
- Accept, decline and register remain disabled until fresh signed subject-bound
  discovery returns one authoritative result.
- Multiple records, missing selector, unavailable, stale, unsigned and
  indeterminate discovery remain unknown.
- Historical register/status/revoke evidence never becomes current after
  restart.
- Current-status expiry immediately removes the active claim.

### 16.2 Expectation/admission/registration recovery

- Every operation persists `clientAttemptID`, expectation ID, full expectation,
  request digest, admission ID and protected-body digest before send.
- Admission ID must equal `base64url(requestSHA256)`.
- Registration ID is absent until a verified register receipt.
- Crash at every common transaction boundary recovers the exact named state.
- Ambiguous first register with no registration ID uses admission read-back or
  subject discovery only.
- Missing read-back interface terminates in
  `blockedAdjudicationUnavailable`.
- Admission ID possession alone cannot retrieve evidence or grant authority.
- Wrong expectation, subject, target, owner, Contract, generation or response
  substitution fails.
- No automatic replay occurs without exact retained protected bytes.

### 16.3 Challenge intent and issuer rollback

- Intent is durable before challenge request.
- Identical unexpired retry uses byte-identical intent and nonce.
- Same nonce with different bytes, operation or subject fails.
- Expired intent creates a new nonce and never rewrites old bytes.
- Wrong issuer, generation regression, equal-generation descriptor change and
  unproved higher generation fail.
- Watermark journal/anchor rollback, copied watermark and rotation-record
  substitution fail.
- Transport issuer, TLS peer, host or lookup hint cannot replace the owner
  rotation proof.
- Raw nonce/intents never appear in logs, UI, analytics or diagnostics.

### 16.4 Per-operation authority

For each reviewed operation:

- exact resource/action/capability/access succeeds only with the exact signed
  Contract Grant;
- substitute any other operation's access and reject;
- adding privileges rejects when it changes the exact Grant;
- removing `r`, `w` or `s` rejects where the operation requires it;
- status `r--s` versus mutation `rw-s` is tested only after status becomes
  canonical;
- undefined deregister/admission operations remain unavailable; and
- HTTP, APNS, topic, bundle, origin, ticket, bearer, secret or valid domain
  binding alone never grants authority.

### 16.5 Consent and stop races

- Empty local evidence does not open “Not now.”
- Fresh authoritative not-found plus no local evidence opens it.
- Decline versus accept/token/register under actors and processes has one
  transaction winner.
- Stop intent never clears evidence or claims server mutation.
- Revoke/deregister ambiguous state retains expectation and tombstone.
- Only typed verified receipt plus fresh current status establishes the stop.

### 16.6 Token rotation and privacy

- No raw token or token hash appears in `UserDefaults`, journal, evidence,
  logs, analytics, error strings, fixtures, snapshots or backups.
- Restart requires a new iOS token callback and new observation ID.
- Observation ID/delivery epoch do not derive from token bytes.
- Receipt verification binds the observation to the exact expectation/body
  digest/admission.
- Generation rise without exact update correlation remains unknown.
- Concurrent callbacks serialize to one active observation and preserve all
  ambiguous evidence.
- Crash at every rotation boundary never restores a raw token or retries.

### 16.7 Resolve/submit durability and privacy

- Each exact durable state round-trips and rejects illegal transitions.
- Resolved payload is volatile even with `s` until a reviewed retention path
  exists.
- Missing `s` forbids response retention.
- Crash after resolve response but before submit enters
  `resolveHistoricalNoPayload`.
- Ambiguous submit never becomes success.
- Wrong ticket/decision/admission lineage and response substitution fail.
- Protected payload, prompt, decision and result never enter generic durable
  storage or diagnostics.
- Actor/store/process races serialize resolve and submit correctly.

### 16.8 Store and transport attacks

- File and parent-directory synchronization failure prevents send.
- Symlink, hardlink, FIFO, socket/device, wrong owner/mode/link count and
  unpinned parent fail.
- Before/after inode/stat/content mismatch and path swap before/after lock or
  rename fail.
- Store rollback, valid-prefix rollback, anchor rollback and concurrent writer
  fail.
- Redirect, wrong origin, insecure scheme, TLS failure, host mismatch,
  malformed base64, wrong method/path, oversized field and re-encoding fail
  closed.
- Transport failure never becomes authorization, registration, revoke,
  resolve or submit success.

### 16.9 Production-evidence separation

- Signed status fixture cannot satisfy origin/TLS checks.
- Transport fixture cannot satisfy Cell authority.
- Bundle/topic strings cannot satisfy effective entitlement/profile/codesign.
- Provider acceptance cannot satisfy physical receipt.
- Historical device receipt cannot satisfy a new candidate revision.

## 17. Corrected `C-DEC-01...12` ledger

No question is delegated to Kjetil where protocol, Identity or privacy
invariants already determine the fail-closed client behavior.

| ID | S2 technical disposition | Remaining genuine owner input | State while missing |
| --- | --- | --- | --- |
| `C-DEC-01` | Client truth is closed: local absence is unknown; only fresh signed subject-bound current status/discovery proves current or not-found | Canonical selector/schema/freshness/multi-record fixtures from CellProtocol owner | `localEvidenceAbsentServerUnknown` |
| `C-DEC-02` | Client stop UX is closed: pre-registration decline requires signed not-found; possible/active registration uses typed stop and tombstone | Canonical choice: revoke only, deregister alias, separate deregister, or unsupported | Post-registration stop unavailable |
| `C-DEC-03` | Conditional signed-intent/nonce/issuer-watermark consumer is frozen | Reviewed origin/audience/TLS/redirect, decode owner, intent/rotation schemas and fixtures | Challenge unavailable before network |
| `C-DEC-04` | Client rotation lineage is closed: observation → body digest/admission → receipt → correlated fresh status; no token hash | Canonical update CAS and exact status correlation for concurrent token changes | `blockedRotationUnknown` |
| `C-DEC-05` | Client ambiguity behavior is closed: admission/status adjudication only; no body retention or invented replay | Canonical admission-result retrieval and/or subject status plus durable server implementation | `blockedAdjudicationUnavailable` |
| `C-DEC-06` | No client fallback or static trust root is permitted | Production issuer descriptor/rotation proof, target Cells/owners and signed Contract provisioned by authority owners | Every protected operation unavailable |
| `C-DEC-07` | Client retains pending/tombstone and unknown truth | Durable server admission/status/revoke/submit read-back, freshness and unavailable/not-found semantics | Indeterminate |
| `C-DEC-08` | Client invents no participant/device body fields and logs none | Registration Cell owner/privacy decision for exact protected-body metadata and retention | Register body unavailable |
| `C-DEC-09` | Consumer must hash-pin one producer-owned machine-readable manifest and reviewed shared package | Exact producer manifest path/bytes/SHA and immutable artifact revision | Fixture manifest unpopulated |
| `C-DEC-10` | S2 resolves the safe default: resolved data is volatile even with `s`; no persistence path exists | Optional future product/Agreement decision only if retention is desired | Volatile processing |
| `C-DEC-11` | No local provenance can substitute | Exact clean integrated commit/tree/dependency/compiler-input manifest from development admin | `MBI-07` missing |
| `C-DEC-12` | DeviceIngress status is separated from Apple evidence | Team/profile/certificate/effective production entitlement/codesign/archive from Apple release owner | `MBI-06` unaudited/missing |

The following are genuine authority/product choices and remain open:

- subject-bound discovery/status and admission read-back wire semantics;
- revoke/deregister semantic;
- challenge issuer root and signed rotation record;
- secure origin/audience projection and transport behavior;
- register/update concurrency and token-rotation correlation;
- server durability, Agreement provisioning and rollback anchor;
- protected registration-body metadata;
- producer manifest/artifact;
- final integrated output; and
- Apple production signing evidence.

## 18. `MBI-05` disposition

| MBI-05 subclaim | S2 author disposition |
| --- | --- |
| Exact future Binding paths and owners | **CORRECTED STATIC PROPOSAL; independent review required** |
| Empty-local/current truth model | **CORRECTED STATIC PROPOSAL** |
| Total register crash/restart graph | **CORRECTED STATIC PROPOSAL; operational adjudication blocked upstream** |
| Signed challenge-intent/nonce/issuer continuity | **CORRECTED CONDITIONAL CONSUMER PROPOSAL; producer/issuer inputs open** |
| Exact resolve/submit durable states | **CORRECTED STATIC PROPOSAL; server/read-back open** |
| Token-rotation continuity | **CORRECTED FAIL-CLOSED CLIENT PROPOSAL; canonical correlation open** |
| Raw-token/evidence privacy | **EXACT REQUIREMENT; no runtime proof** |
| Operation-specific access tests | **CORRECTED STATIC PROPOSAL** |
| Complete Apple no-touch ledger | **CORRECTED STATIC PROPOSAL** |
| Production signing readiness | **UNAUDITED / MISSING (`MBI-06`)** |
| Exact integrated output | **MISSING (`MBI-07`)** |

Overall author decision:

```text
S1 C REVIEW FINDINGS: 0/3/4 RECEIVED
S2 CORRECTIONS: AUTHOR-PROPOSED FOR ALL SEVEN
INDEPENDENT S2 REVIEW: REQUIRED
MBI-05: PARTIAL / OPEN
LANE C: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
```

## 19. Preserved stops and review handoff

- S0 remains immutable and NO-GO.
- All six S1 packet/review artifacts remain immutable inputs.
- S1 A review findings `0/5/2` remain open; no status, deregister,
  challenge-rotation, production origin or token-correlation bytes are made
  canonical here.
- S1 B review findings `0/4/1` remain open; no issuer, Resolver Cell,
  admission, replay, authority or token-store service is made operational.
- Identity cutover remains a separate prerequisite and is neither inspected
  nor approved.
- Bundle/topic `org.digipomps.haven` and origin
  `https://haven.digipomps.org` remain planning values only.
- `MBI-06` remains unaudited/missing.
- `MBI-07` remains missing.
- No raw APNS token, secret, private key or unredacted protected payload was
  read, displayed or stored.
- No source, Git, build, test, network, portal, signing, device, APNS,
  Identity, staging or deployment action is authorized.

The next permissible action is one independent exact-byte static review of
this correction by a reviewer distinct from the author, if separately
authorized. That review must reproduce all S0/S1 inputs, immutable source
objects, all 11 Apple M1 paths, the total recovery graph, every C-review
finding disposition and every retained blocker. It must not open source or a
next material phase.

This author stops after freezing and re-attesting this one documentation
artifact.
