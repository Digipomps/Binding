# APNS S1 CellProtocol Producer/Contract Packet

Date: 2026-07-24  
Lane: S1 Lane A — CellProtocol producer/contract  
Role: author only  
Packet state: **AUTHOR-FROZEN, UNREVIEWED, PLAN ONLY**  
S0 state: **IMMUTABLE NO-GO**  
S1 Lane A decision: **NO-GO**  
PLAN decision: **NO-GO**  
NEXT PHASE decision: **NO-GO**  
Source authorization: **NONE**

## 1. Authority, purpose and stop boundary

This packet is the sole S1 Lane A author artifact. It proposes a reviewable
CellProtocol producer/contract boundary for DeviceIngress and the shared
byte-preserving HTTP carrier. It does not implement, approve or independently
review that boundary.

The only authorized output is:

```text
Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md
```

Nothing in this packet authorizes:

- a source, fixture, package or dependency edit;
- Git index, branch, commit, merge, push or pull-request work;
- a build or test;
- dependency resolution;
- network, Apple portal, signing, archive, physical-device or APNS activity;
- Identity cutover;
- CellScaffold or Binding composition;
- staging or deployment; or
- any next material phase.

The packet uses `purpose://access.audit.privacy` for the protected authority
boundary and `purpose://test.acceptance` for deterministic contract evidence.
Both are existing purpose nodes; no purpose reference is invented.

## 2. Formål and author goals

| Goal ID | Purpose | Metric and target | Evidence | Author status |
| --- | --- | --- | --- | --- |
| `goal.s1a.exact-input` | `purpose://access.audit.privacy` | Four supplied document hashes and two immutable source objects bound exactly | Sections 3–4 | SATISFIED |
| `goal.s1a.fixture-mapping` | `purpose://test.acceptance` | Every one of challenge, request, protected body, signed Contract and response has exactly one role; no four-fixture wrapper claim remains | Section 6 | SATISFIED AS AUTHOR PACKET |
| `goal.s1a.mbi-contract` | `purpose://access.audit.privacy` | Literal author proposal for status, revoke and challenge framing, with unresolved owner choices visible | Sections 7–13 | SATISFIED AS AUTHOR PACKET; UNREVIEWED |
| `goal.s1a.production` | `purpose://test.acceptance` | Production authorization | Requires independent review, source evidence and downstream lanes | BLOCKED / OUT OF SCOPE |

The human CellProtocol contract owner, not this author, owns acceptance of the
proposed wire decisions.

## 3. Exact document input gate

The packet is bound to these immutable input bytes:

| Input | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

The S0 independent review finding count is exactly:

```text
P0: 0
P1: 2
P2: 1
```

S0 remains immutable and NO-GO. This packet does not rewrite any S0 decision.

## 4. Immutable source evidence

### 4.1 CellProtocol source object

| Property | Exact value |
| --- | --- |
| Commit | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` |
| Tree | `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` |
| Base commit | `79740304167aa4f4daadd148c5a369e919d25a6a` |
| Base tree | `71ee11a69139a1c222c2156ab1bc79dbe0115620` |
| Name-status path count | 11 |
| Name-status SHA-256 | `912ca02e45425581fca429191010002c7f756ba78e002c4b9aceca255ec68cff` |

Relevant immutable blob IDs:

| Path | Blob |
| --- | --- |
| `Sources/CellBase/DeviceIngress/DeviceIngressWire.swift` | `06138743faa6df83690a824fe6bf6d2171601749` |
| `Sources/CellBase/DeviceIngress/DeviceIngressAdmission.swift` | `093d123e6f97da0f68419980870be25f47e4dc1f` |
| `Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift` | `707b8f7cb2b580eb41c927f2f84df58b45e978aa` |
| `Tests/CellBaseTests/DeviceIngressContractTests.swift` | `52e4b54db94a662dbc4d8cd1e48058c9d2c7d648` |
| `Tests/CellBaseTests/DeviceIngressWireFixtureTests.swift` | `f870b2b5472aa0ca4be445394e3c1c27f8ed056f` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressChallenge.v3.b64` | `1cd2a2c3f88cdb9e386ce9f20f6991478d385aaf` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressRequest.v3.b64` | `e234d9536351f99d787a5c76e29af4871b0918b3` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressResponse.v3.b64` | `a3a998de1853d47e03364866392bf11b86449f86` |
| `Tests/CellBaseTests/Fixtures/DeviceIngressSignedContract.v3.b64` | `a3de633e5954200b5b6ed3fa1b8570de70ad97ca` |
| `Docs/DeviceIngressSecurityContract.md` | `6947a4265f7b97db2aa504e726a1059be0464915` |
| `Package.swift` | `2774eded87ff829240168e89f8bcb2f7610dd44c` |

### 4.2 CellScaffold carrier source object

| Property | Exact value |
| --- | --- |
| Commit | `d2d1b7191d651ad42d172e980ab94a0fd478d07c` |
| Tree | `536531541587b5229b8f325f8935ed11ef85f228` |
| Transport predecessor | `38195a233b84d09f66e5ef483800228f857fff2a` / tree `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` |
| Route-fix name-status count | 2 |
| Route-fix name-status SHA-256 | `51c3daffedd3330995a84c27fb1d23fee4ef37a7bbfb8dd561db5211d01fa442` |

Relevant immutable blob IDs:

| Path | Blob |
| --- | --- |
| `Sources/App/Controllers/DeviceCallbackCapabilityServer.swift` | `5e85f42ef816c71ff3be11ef5a17abf70ea295a8` |
| `Sources/App/Controllers/VaporDeviceCallback.swift` | `1835c26b94154ec97088f956901bbd7be62c413b` |
| `Tests/AppTests/DeviceCallbackCapabilityServerTests.swift` | `4defe2191cb20f77afb913d5dbcd6517c599b85d` |
| `Documentation/DeviceCallbackCapabilityServer.md` | `b9004c4749ea31e0994aae210a40c18f500e6b30` |
| `Package.swift` | `ab117c5337e8f8ef6f0f70ef2f79a9625d812870` |
| `Package.resolved` | `c6565bd936f6ba8a8d9154b307943ad687a2a721` |

No source claim below may be attributed to a different commit.

## 5. Fact versus proposal ledger

| ID | Statement | Classification | Audit status |
| --- | --- | --- | --- |
| `FACT-01` | `79ce4f…` has `register`, `resolve`, `submit` only | Immutable source fact | SUPPORTED |
| `FACT-02` | Current resources/actions/capabilities are operation-bound and every current operation reports `rw-s` | Immutable source fact | SUPPORTED |
| `FACT-03` | Current envelope and authority-reference schemas are v3; canonical JSON is UTF-8, sorted-key, slash-unescaped and byte-compared | Immutable source fact | SUPPORTED |
| `FACT-04` | A request binds exact challenge and protected-body bytes by SHA-256 | Immutable source fact | SUPPORTED |
| `FACT-05` | The signed Contract is returned as authority evidence by the Resolver-selected target Cell and independently byte-compared/verified | Immutable source fact | SUPPORTED |
| `FACT-06` | The signed operation response is raw canonical output and is not part of the request wrapper | Immutable source fact | SUPPORTED |
| `FACT-07` | `d2d1b…` has a three-byte-field base64 JSON wrapper and exact register/resolve/submit HTTP paths; only register reaches admission | Immutable source fact | SUPPORTED |
| `FACT-08` | Challenge issuance and production admission are unavailable at `d2d1b…` | Immutable source fact | SUPPORTED |
| `FACT-09` | `Docs/DeviceIngressSecurityContract.md` at `79ce4f…` says v2/`-w--` while code is v3/`rw-s` | Immutable source fact | SUPPORTED / RELEASE STOP |
| `PROP-01` | Add `status` and `revoke` under the existing v3 envelope shape | S1-A author proposal | OWNER DECISION + INDEPENDENT REVIEW REQUIRED |
| `PROP-02` | Add a signed canonical challenge intent and a one-field challenge HTTP carrier | S1-A author proposal | OWNER DECISION + INDEPENDENT REVIEW REQUIRED |
| `PROP-03` | Extract the shared HTTP carrier into `CellDeviceIngressTransport` | S0/S1-A author proposal | OWNER DECISION + INDEPENDENT REVIEW REQUIRED |
| `PROP-04` | Use registration generation, not a token or stable token digest, for token-binding reconciliation | S1-A author proposal | SERVER + BINDING OWNER DECISION REQUIRED |

Unaudited proposals provide no implementation or production evidence.

## 6. P1-S0-01 exact fixture-role correction

### 6.1 Immutable v3 fixture identities

| Canonical decoded bytes | Existing producer path | SHA-256 of decoded bytes | Role |
| --- | --- | --- | --- |
| Challenge | `Tests/CellBaseTests/Fixtures/DeviceIngressChallenge.v3.b64` | `ca4e510223ae548e6d482004926c7d322ec4999d8e282984401b6b08254f15de` | HTTP wrapper input field `canonicalChallenge` |
| Request | `Tests/CellBaseTests/Fixtures/DeviceIngressRequest.v3.b64` | `8c8ca1f5ec598488d2da0674291a069cd5b1169bb24196a767fe4d8770cb9877` | HTTP wrapper input field `canonicalRequest` |
| Signed Contract | `Tests/CellBaseTests/Fixtures/DeviceIngressSignedContract.v3.b64` | `5e46a6027385fd41af9b56e3870298e5b79666d59c24f0bb1656427e179ef083` | Resolver-selected authority evidence; never an HTTP wrapper field |
| Response | `Tests/CellBaseTests/Fixtures/DeviceIngressResponse.v3.b64` | `291a35775c9be3826e48a6d330ea8027d8be490b6fd1697e9c946da170eaa0b0` | Raw successful HTTP output; never an HTTP request-wrapper field |

The immutable `79ce4f…` test uses this exact protected-body byte sequence:

```text
{"participantId":"binding-participant","pushToken":"private"}
```

Properties:

```text
decoded byte count: 61
decoded SHA-256: 7ad22f5cd6c74dfdb3596782371f41ead27a70b96b2d625fecccb0a9a98bd686
standard padded base64:
eyJwYXJ0aWNpcGFudElkIjoiYmluZGluZy1wYXJ0aWNpcGFudCIsInB1c2hUb2tlbiI6InByaXZhdGUifQ==
```

The string is a public deterministic test vector, not a production token.

### 6.2 Exact three-field protected-operation wrapper

The wrapper schema remains:

```text
haven.device-callback.transport.v3
```

Its complete field set is:

```text
schema
canonicalChallenge
canonicalRequest
protectedBody
```

The three binary fields are standard padded RFC 4648 base64 JSON strings.
There is no signed-Contract field and no response field.

The proposed producer fixture:

```text
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransport.v3.json
```

must contain exactly:

- decoded `canonicalChallenge` bytes equal to
  `DeviceIngressChallenge.v3.b64`;
- decoded `canonicalRequest` bytes equal to
  `DeviceIngressRequest.v3.b64`; and
- decoded `protectedBody` bytes equal to the 61-byte vector above.

The separately copied Contract fixture is supplied to a test
`DeviceIngressAuthorityCell` as `DeviceIngressAuthorityEvidence`. The
separately copied response fixture is the byte-identical return from the
authority Cell/admission service and the expected raw HTTP success body.

This is the S1-A author disposition for `P1-S0-01`:

```text
AUTHOR-PROPOSED CLOSED, UNREVIEWED
```

No one-wrapper/four-input-fixture statement survives this packet.

## 7. Literal operation proposal for MBI-01 and MBI-02

### 7.1 Version decision

The S1-A proposal is additive:

- preserve the exact v3 envelope, authority-reference, admission and response
  field shapes;
- preserve the existing v3 register fixture bytes unchanged;
- add enum operations and optional operation-result payloads;
- old consumers must reject unknown operation/result enum values rather than
  reinterpret them;
- no v1/v2 input is upgraded, normalized or re-signed; and
- a compatibility reviewer must prove that existing v3 register bytes and
  their verification result remain byte-identical.

This same-v3 additive decision is not derivable from `79ce4f…`. It is
`OD-01` and requires explicit CellProtocol contract-owner acceptance. If the
owner instead requires a v4 envelope, the source phase remains blocked until a
new packet replaces every schema and fixture path consistently.

### 7.2 Complete proposed operation map

| Wire operation | Resource | Action | Capability | Required access | State |
| --- | --- | --- | --- | --- | --- |
| `register` | `cell:///DeviceRegistration` | `registerOrUpdateDevice` | `device.registration.write` | `rw-s` | Immutable current fact |
| `status` | `cell:///DeviceRegistration` | `readRegistrationStatus` | `device.registration.status` | `r--s` | Author proposal |
| `revoke` | `cell:///DeviceRegistration` | `revokeDevice` | `device.registration.revoke` | `rw-s` | Author proposal |
| `resolve` | `cell:///DeviceCallbackBridge` | `resolveTicket` | `device.callback.resolve` | `rw-s` | Immutable current fact |
| `submit` | `cell:///DeviceCallbackBridge` | `submitTicketResult` | `device.callback.submit` | `rw-s` | Immutable current fact |

All five use:

```text
purpose: purpose://access.audit.privacy/device-notification-callback
identity domain: domain:device:notification-callback
production audience: haven.digipomps.org
```

`status` reads one subject-bound current-state snapshot. Durable audit/replay
storage performed internally by the target Cell does not grant the requester
write authority. The requester needs `r` to receive and `s` to retain the
signed result.

`revoke` mutates the registration tombstone and returns a retainable signed
receipt, so it requires `rw-s`.

### 7.3 Proposed status request body

Type:

```text
DeviceIngressRegistrationStatusRequest
schema: cellprotocol.device-ingress.registration-status-request.v1
maximum canonical encoded bytes: 4096
```

Complete fields:

| Field | Type | Rule |
| --- | --- | --- |
| `schema` | ASCII string | Exact schema above |
| `registrationID` | ASCII string | Non-empty, maximum 128 bytes |
| `minimumRegistrationGeneration` | UInt64 | `1...9007199254740991` |
| `minimumRevocationGeneration` | UInt64 | `0...9007199254740991` |

The subject identity and signing key come from the signed envelope and are not
duplicated in the body.

The proposed canonical fixture body is the following exact 171 UTF-8 bytes,
with sorted keys and no trailing newline:

```json
{"minimumRegistrationGeneration":1,"minimumRevocationGeneration":0,"registrationID":"reg_fixture_01","schema":"cellprotocol.device-ingress.registration-status-request.v1"}
```

SHA-256:

```text
6820fab5db8d68959f8fd6b2e8cb5b8581a86d1d34c503ebd0f7a82187fd6fe7
```

### 7.4 Proposed signed status result

Operation-result kind:

```text
registration_status
```

Payload:

```text
DeviceIngressRegistrationStatus
schema: cellprotocol.device-ingress.registration-status.v1
```

Complete fields:

| Field | Type | Rule |
| --- | --- | --- |
| `schema` | ASCII string | Exact schema above |
| `registrationID` | ASCII string | Echoes the requested ID |
| `deviceIdentityUUID` | UUID string | Must equal envelope subject UUID |
| `state` | enum | `active_consented`, `revoked`, `unknown`, `indeterminate_retryable` |
| `registrationGeneration` | UInt64? | Required and positive for active/revoked; absent otherwise |
| `revocationGeneration` | UInt64 | Current monotonic ledger generation |
| `registrationRecordSHA256` | 32 bytes? | Required for active/revoked; absent otherwise |
| `observedAtMilliseconds` | Int64 | Equal to the target Cell's committed snapshot time |
| `retryAfterMilliseconds` | Int64? | Only for `indeterminate_retryable`, range `1...60000` |
| `persistenceSemantics` | ASCII string | `same_cell_durable_current_registration_snapshot_and_response` |

Normative proposal:

- `active_consented` is the only state that may restore “registered”.
- `revoked` is authoritative negative state.
- `unknown` is an owner-signed authoritative absence for that registration ID
  and subject at `observedAtMilliseconds`; local absence is never promoted to
  this state.
- `indeterminate_retryable` never restores registration and requires a new
  challenge/request after the retry interval.
- `registrationGeneration` is the non-secret token-binding generation. Every
  accepted token-binding change must increment it. No raw APNS token or stable
  token digest appears in the result.
- the outer operation response must retain all existing request, challenge,
  body, Cell, owner, subject, exact Contract, authority, revocation, content
  policy and receipt bindings.

A replay of the same exact status request returns the original byte-identical
snapshot. It is historical replay, not a fresh current-state check. Fresh
current status always requires a new challenge and request.

### 7.5 Proposed revoke request body

Type:

```text
DeviceIngressRegistrationRevokeRequest
schema: cellprotocol.device-ingress.registration-revoke-request.v1
maximum canonical encoded bytes: 4096
```

Complete fields:

| Field | Type | Rule |
| --- | --- | --- |
| `schema` | ASCII string | Exact schema above |
| `registrationID` | ASCII string | Non-empty, maximum 128 bytes |
| `expectedRegistrationGeneration` | UInt64 | Positive and exact |
| `expectedRevocationGeneration` | UInt64 | Exact current generation |
| `reasonCode` | enum | `consent_withdrawn`, `device_replaced`, `token_rotated`, `owner_policy` |

The proposed canonical fixture body is the following exact 206 UTF-8 bytes,
with sorted keys and no trailing newline:

```json
{"expectedRegistrationGeneration":1,"expectedRevocationGeneration":0,"reasonCode":"consent_withdrawn","registrationID":"reg_fixture_01","schema":"cellprotocol.device-ingress.registration-revoke-request.v1"}
```

SHA-256:

```text
8ac820e04a24cbb84b0b2f52e5fc5420da1c90f69cc4fd415aa4d5e8494487d5
```

`token_rotated` revokes an old binding only. It does not authorize or imply a
replacement registration.

### 7.6 Proposed signed revoke result

Operation-result kind:

```text
registration_revocation_receipt
```

Payload:

```text
DeviceIngressRegistrationRevocationReceipt
schema: cellprotocol.device-ingress.registration-revocation-receipt.v1
```

Complete fields:

| Field | Type | Rule |
| --- | --- | --- |
| `schema` | ASCII string | Exact schema above |
| `registrationID` | ASCII string | Exact requested registration |
| `deviceIdentityUUID` | UUID string | Must equal envelope subject UUID |
| `registrationGeneration` | UInt64 | Must equal the request's expected registration generation |
| `previousRevocationGeneration` | UInt64 | Pre-mutation generation |
| `revocationGeneration` | UInt64 | Post-decision current generation |
| `state` | enum | Exactly `revoked` |
| `disposition` | enum | `revoked`, `already_revoked` |
| `tombstoneSHA256` | 32 bytes | Digest of the target Cell's durable tombstone record |
| `durableSequence` | UInt64 | Positive target-Cell sequence |
| `committedAtMilliseconds` | Int64 | Exact target-Cell decision time |
| `persistenceSemantics` | ASCII string | `same_cell_atomic_revoke_tombstone_and_response` |

Normative proposal:

- a fresh active registration with exact expected generations increments
  `revocationGeneration` by exactly one and returns `revoked`;
- byte-identical replay by admission ID returns the exact stored response and
  performs no second mutation;
- a new request against an already revoked registration may return
  `already_revoked` without another increment only when both expected
  generations equal current state;
- stale registration or revocation generation is a typed denial, not success;
- unknown registration is a typed denial followed by a fresh status operation;
- the target Cell commits tombstone, mutation receipt and exact signed response
  atomically; and
- a successful revoke must be followed by a new signed status request before a
  client presents current revoked state.

Pre-registration “Not now” is not `revoke` and must never synthesize a
revocation receipt.

## 8. Literal challenge framing proposal for MBI-03

### 8.1 Canonical signed challenge intent

New CellBase type:

```text
DeviceIngressChallengeIntent
schema: cellprotocol.device-ingress.challenge-intent.v1
maximum canonical encoded bytes: 65536
maximum lifetime: 60000 milliseconds
maximum clock skew: 30000 milliseconds
nonce: 32...64 bytes
```

Complete fields:

| Field | Type | Rule |
| --- | --- | --- |
| `schema` | ASCII string | Exact schema above |
| `intentID` | ASCII string | Non-empty, maximum 128 bytes |
| `nonce` | Data | Requester CSPRNG, 32...64 bytes |
| `operation` | `DeviceIngressOperation` | One of the five exact operations |
| `purpose` | string | Exact DeviceIngress purpose |
| `audience` | string | Exact `haven.digipomps.org` in production |
| `identityDomain` | string | Exact DeviceIngress identity domain |
| `subject` | identity descriptor | UUID/public signing key; display name absent |
| `authorityID` | ASCII string | Lookup hint only; grants no authority |
| `agreementID` | ASCII string | Lookup hint only; grants no authority |
| `minimumChallengeIssuerGeneration` | UInt64 | Positive rollback floor |
| `issuedAtMilliseconds` | Int64 | JSON-safe |
| `expiresAtMilliseconds` | Int64 | Within 60 seconds and clock-skew rules |
| `domainBinding` | `IdentityDomainBinding` | Exact subject/domain/key match; `grantsAuthority=false` |
| `proof` | `DeviceIngressIdentityProof` | Subject signature; omitted from signing bytes, included on wire |

Canonical encoding uses the same CellProtocol rules as the existing envelope.
The intent is not a capability. It is signed input to the authority path.

### 8.2 Challenge HTTP carrier

Method and path:

```text
POST /conference-mvp/api/device/challenge
```

Request schema:

```text
haven.device-callback.challenge-request.v1
```

Complete request fields:

```text
schema
canonicalIntent
```

`canonicalIntent` is standard padded base64 in JSON. The request wrapper is
limited to 98304 bytes; decoded intent is limited to 65536 bytes.

Successful response:

```text
HTTP 200
Content-Type: application/json
Cache-Control: no-store
body: raw canonical DeviceIngress challenge bytes
maximum body: 65536 bytes
```

The response has no outer wrapper.

### 8.3 Issuer, Resolver and Agreement path

The proposed authoritative path is:

1. the HTTP adapter bounds and decodes the one-field challenge carrier;
2. CellBase byte-compares and verifies the canonical signed intent, subject,
   domain binding, purpose, audience, lifetime and issuer-generation floor;
3. Resolver resolves `operation.resource` for the subject;
4. resolution grants no authority;
5. the exact resolved Cell and its owner provide the complete canonical signed
   Agreement/Contract and current authority/revocation generations;
6. CellBase canonical-byte-compares the full Contract, verifies the target
   owner signature, subject, domain and exact hashed
   `DeviceIngressAgreementScope`;
7. a persistent pinned challenge issuer allocates a server CSPRNG nonce,
   records intent/challenge uniqueness and signs the exact challenge;
8. the challenge pins target Cell UUID, target owner UUID/key, exact Contract
   SHA-256, subject, content policy, authority and revocation generations; and
9. the adapter returns those raw canonical bytes unchanged.

The requester-supplied `authorityID` and `agreementID` are lookup hints. The
requester cannot supply or replace:

- the target Cell;
- the target owner;
- the signed Contract bytes;
- an authority or revocation generation;
- the content policy;
- the challenge issuer; or
- the server nonce.

### 8.4 Challenge issuer replay and rotation

Proposed replay rules:

- ledger key is SHA-256 of the complete canonical intent;
- an identical unexpired intent returns the exact stored challenge bytes;
- reuse of the same subject/intent nonce with different bytes is rejected;
- a challenge response is never re-signed on replay;
- after intent/challenge expiry, the client creates a new intent and nonce;
- production challenge issuer private keys never leave the selected vault; and
- issuer state and replay records must survive restart.

Proposed rotation rules:

- every issuer descriptor has a monotonic
  `challengeIssuerGeneration`;
- newly issued challenges carry that generation as an additive optional
  envelope field;
- new production issuance requires the field; immutable older fixtures remain
  historical vectors;
- a client persists the highest accepted generation and sends it as
  `minimumChallengeIssuerGeneration`;
- a lower generation fails closed;
- a higher generation is accepted only when a separately reviewed,
  owner-signed rotation record binds old descriptor, new descriptor,
  generation and activation time; and
- the exact rotation-record schema and storage path remain `OD-05` because
  neither immutable input defines them.

`OD-05` is an explicit blocker. Challenge framing is author-proposed, but
production issuer-rotation semantics are not declared closed by this packet.

## 9. Exact HTTP operation table

| Operation | Method | Path | Request body | Successful body |
| --- | --- | --- | --- | --- |
| challenge | POST | `/conference-mvp/api/device/challenge` | one-field challenge carrier | raw canonical challenge |
| register | POST | `/conference-mvp/api/device/register` | three-field protected wrapper | raw canonical operation response |
| status | POST | `/conference-mvp/api/device/registration/status` | three-field protected wrapper | raw canonical operation response |
| revoke | POST | `/conference-mvp/api/device/registration/revoke` | three-field protected wrapper | raw canonical operation response |
| resolve | POST | `/conference-mvp/api/device/callback/resolve` | three-field protected wrapper | raw canonical operation response |
| submit | POST | `/conference-mvp/api/device/callback/submit` | three-field protected wrapper | raw canonical operation response |

Production constants:

```text
bundle identifier: org.digipomps.haven
APNS topic: org.digipomps.haven
origin: https://haven.digipomps.org
HTTP authority / DeviceIngress audience: haven.digipomps.org
optional associated domain: applinks:haven.digipomps.org
```

The bundle identifier and APNS topic are release/provider context only. They
do not enter CellProtocol authorization or transport success.

Every path uses exact POST routing. Method/path/inner-operation mismatch is
rejected before admission. No route, host, origin, APNS topic, bearer,
cookie, client certificate or possession of bytes grants Cell authority.

## 10. Encoding, byte order and maxima

### 10.1 Canonical signed CellProtocol bytes

The packet preserves these current rules:

- UTF-8 JSON, no BOM;
- top-level and nested object keys serialized in sorted-key order;
- slashes not escaped;
- no insignificant whitespace or trailing newline;
- Swift `Data` uses standard padded base64 on JSON;
- SHA-256 is over the exact decoded raw bytes;
- `proof` is omitted from signing bytes and included in canonical wire bytes;
- a decoder re-encodes and byte-compares;
- duplicate keys, alternate order, alternate whitespace, normalization or
  non-canonical numeric forms are rejected;
- integer timestamps/generations stay in the exact JSON 53-bit range; and
- transport never decodes then re-encodes signed inner bytes.

### 10.2 Transport JSON bytes

The producer encoder must emit deterministic UTF-8 JSON with sorted keys,
unescaped slashes, standard padded base64, no whitespace and no trailing
newline. The decoder must reject:

- unknown schema;
- unknown or duplicate top-level keys;
- missing or empty fields;
- malformed or non-standard base64;
- decoded oversize fields; and
- non-canonical producer JSON when exact fixture mode is enabled.

Only decoded inner byte equality is protocol-significant. The outer wrapper
never becomes authority and never enters an Agreement scope.

### 10.3 Exact limits

| Item | Limit |
| --- | ---: |
| Protected-operation wrapper | 327680 bytes |
| Canonical challenge | 65536 bytes |
| Canonical request | 65536 bytes |
| Protected body | 65536 bytes |
| Status/revoke typed protected body | 4096 bytes |
| Challenge-request wrapper | 98304 bytes |
| Canonical challenge intent | 65536 bytes |
| Raw canonical operation response | 65536 bytes |
| Operation result | 32768 bytes |
| Signed Agreement authority evidence | 65536 bytes |
| Challenge nonce | 32...64 bytes |
| Challenge lifetime | maximum 300000 ms |
| Protected request lifetime | maximum 120000 ms |
| Challenge-intent lifetime | maximum 60000 ms |
| Clock skew | maximum 30000 ms |

No downstream owner may silently raise a limit.

## 11. Replay, durability and current-state semantics

The proposed producer contract requires:

1. challenge intent replay returns one byte-identical stored challenge;
2. the persistent ledger uniquely constrains intent digest, challenge ID,
   server nonce, request hash and admission ID;
3. a different request cannot reuse a consumed challenge/nonce;
4. admission is durable before target-Cell operation;
5. the same resolved Cell object atomically rechecks complete signed Contract,
   authority and revocation generations;
6. register/revoke/resolve/submit mutation and exact signed response commit in
   one target-Cell transaction;
7. status snapshot audit record and exact signed response commit atomically
   without changing registration state;
8. exact request replay after an ambiguous loss returns the stored exact
   response and never signs or mutates again;
9. committed admission without a recoverable committed response fails
   `committedResponseUnavailable` and never retries as new mutation;
10. restart preserves unique constraints, generation watermarks, tombstones
    and exact response bytes; and
11. response expiry limits online replay but does not erase locally retained
    historical evidence obtained under `s`.

Historical evidence rules:

- a register receipt is not current status;
- a replayed status response is not fresh current status;
- a revoke receipt is not a replacement registration;
- local absence is not server `unknown`;
- any `indeterminate_retryable` result is fail-closed; and
- only a fresh verified `active_consented` status may restore “registered”.

## 12. Error contract and transport neutrality

### 12.1 Transport errors

The proposed `CellDeviceIngressTransport` public error cases are:

```text
emptyBody
payloadTooLarge
malformedJSON
unknownSchema
unknownField
duplicateField
missingField
emptyField
malformedBase64
fieldTooLarge
wrongHTTPMethod
wrongHTTPPath
invalidContentType
legacyAuthorizationPresent
nonSuccessHTTPStatus
responseTooLarge
```

These errors mean the carrier failed. They never mean a capability was denied,
a registration was revoked or a Cell mutation succeeded.

### 12.2 Protocol/authority errors

Existing `DeviceIngressCanonicalWireError`,
`DeviceIngressValidationError` and
`DeviceIngressResponseValidationError` remain protocol errors. Proposed
additions are:

```text
unsupportedOperation
invalidChallengeIntent
challengeIntentReplayConflict
challengeIssuerGenerationRollback
registrationUnknown
registrationGenerationMismatch
revocationGenerationMismatch
invalidRegistrationStatus
invalidRegistrationRevocationReceipt
```

The owner must decide exact Swift enum placement in `OD-06`. Public HTTP errors
remain sanitized and non-authoritative. A non-2xx or malformed response can
never update Binding registration state.

Transport code may:

- map operation to the exact method/path;
- encode/decode the bounded outer carrier;
- preserve raw bytes;
- return status/header/body observations; and
- surface carrier failure.

Transport code must not:

- select an Identity, Cell, owner, Agreement, Contract, Grant or condition;
- validate semantic registration state;
- construct authority references or signed responses;
- retry a mutation with newly encoded inner bytes;
- turn an HTTP status into Cell success;
- log protected bodies, APNS tokens, full identities or signed Contracts; or
- mutate a Cell.

## 13. Protected resource/action and authority proof

For every operation the protected tuple is:

```text
operation
resource
action
capability
requiredAccess
purpose
audience
identityDomain
subject identity UUID + signing-key fingerprint
target Cell UUID
target owner UUID + signing-key fingerprint
exact signed Agreement SHA-256
authority generation
revocation ledger ID + generation
content-policy SHA-256
```

The exact `DeviceIngressAgreementScope` canonical hash is the only acceptable
Grant keypath. Authority requires:

1. subject signature and matching vault-context domain binding;
2. Resolver selection of the operation resource for that subject;
3. exact selected Cell UUID and owner-key match;
4. complete canonical signed Contract bytes supplied by that Cell;
5. byte equality to the challenge-pinned Contract SHA-256;
6. current target-owner signature, subject, domain, time and exact Grant;
7. current authority and revocation generations;
8. durable admission before any protected state change; and
9. same-Cell atomic status snapshot or mutation plus exact response.

Conditions remain fail-closed until condition-specific, authority-pinned,
fresh evaluation receipts exist. HTTP and APNS do not participate in this
proof.

## 14. Exact proposed CellProtocol output allowlist

This is a future source packet proposal, not source authorization.

### 14.1 Existing CellBase contract paths

```text
Sources/CellBase/DeviceIngress/DeviceIngressAdmission.swift
Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift
Sources/CellBase/DeviceIngress/DeviceIngressWire.swift
Tests/CellBaseTests/DeviceIngressContractTests.swift
Tests/CellBaseTests/DeviceIngressWireFixtureTests.swift
Tests/CellBaseTests/Fixtures/README.md
Tests/Linux/DeviceIngressCompositionRootPositive.swift
Docs/DeviceIngressSecurityContract.md
```

### 14.2 New CellBase challenge path

```text
Sources/CellBase/DeviceIngress/DeviceIngressChallengeIntent.swift
Tests/CellBaseTests/DeviceIngressChallengeIntentTests.swift
```

### 14.3 Existing and proposed canonical fixture paths

```text
Tests/CellBaseTests/Fixtures/DeviceIngressChallenge.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressRequest.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressResponse.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressSignedContract.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressProtectedBody.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentRegister.v1.b64
Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentStatus.v1.b64
Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentRevoke.v1.b64
Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentResolve.v1.b64
Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentSubmit.v1.b64
Tests/CellBaseTests/Fixtures/DeviceIngressStatusChallenge.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressStatusRequest.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressStatusProtectedBody.v1.b64
Tests/CellBaseTests/Fixtures/DeviceIngressStatusSignedContract.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressStatusResponse.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressRevokeChallenge.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressRevokeRequest.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressRevokeProtectedBody.v1.b64
Tests/CellBaseTests/Fixtures/DeviceIngressRevokeSignedContract.v3.b64
Tests/CellBaseTests/Fixtures/DeviceIngressRevokeResponse.v3.b64
```

The first four immutable v3 files may be verified but not regenerated in
place. Every new fixture must be deterministic, independently hashed and
reviewed before it can become immutable.

### 14.4 Shared transport product paths

```text
Package.swift
Sources/CellDeviceIngressTransport/DeviceIngressHTTPTransport.swift
Tests/CellDeviceIngressTransportTests/DeviceIngressHTTPTransportTests.swift
Docs/DeviceIngressHTTPTransportContract.md
```

Proposed SwiftPM declarations:

```text
product: CellDeviceIngressTransport
target: CellDeviceIngressTransport
target dependency: CellBase
test target: CellDeviceIngressTransportTests
```

### 14.5 Shared transport fixture paths

```text
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransport.v3.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransportStatus.v3.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransportRevoke.v3.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressChallengeRequestRegister.v1.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressChallengeRequestStatus.v1.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressChallengeRequestRevoke.v1.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressChallengeRequestResolve.v1.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressChallengeRequestSubmit.v1.json
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressChallenge.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressRequest.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressProtectedBody.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressSignedContract.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressResponse.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressStatusChallenge.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressStatusRequest.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressStatusProtectedBody.v1.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressStatusSignedContract.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressStatusResponse.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressRevokeChallenge.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressRevokeRequest.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressRevokeProtectedBody.v1.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressRevokeSignedContract.v3.b64
Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressRevokeResponse.v3.b64
```

No other CellProtocol output path is proposed by this packet.

## 15. Producer and consumer assertions

### 15.1 CellProtocol producer assertions

The future CellBase tests must prove:

- existing v3 register decoded hashes and full canonical bytes remain
  unchanged;
- status and revoke canonical field order, signatures, body/challenge digests
  and exact Contract bindings;
- operation-specific resource/action/capability/access binding;
- `status` accepts only its status payload/result pair;
- `revoke` accepts only its revoke payload/result pair;
- status state invariants and generation monotonicity;
- revoke tombstone, disposition and generation invariants;
- challenge-intent signature, domain, lifetime, nonce and issuer-generation
  floor;
- authority lookup hints grant nothing;
- same input/history yields the same stored response;
- every denied path reaches no unauthorized target mutation; and
- no result contains a raw APNS token or a stable token digest.

### 15.2 Transport producer assertions

The future transport tests must prove:

- outer encode/decode preserves each of the three byte arrays exactly;
- the v3 producer wrapper contains challenge/request/protectedBody only;
- copied canonical fixture decoded bytes equal their CellBase producers;
- Contract bytes are provided only to an authority-cell test double;
- response bytes are expected raw output only;
- challenge request carries one canonical intent and returns one raw challenge;
- every exact method/path mapping is correct;
- malformed, unknown, duplicate, empty and oversize carriers fail before
  protocol admission;
- method/path/inner-operation mismatch fails before admission;
- transport never decodes or constructs authority-bearing types; and
- transport errors remain transport errors.

### 15.3 CellScaffold consumer assertions

A later server lane must:

- pin an immutable reviewed CellProtocol artifact;
- import the shared transport target rather than copy its implementation;
- hash-pin all producer fixtures it copies;
- pass decoded bytes unchanged to CellProtocol;
- obtain signed Contract bytes only from the Resolver-selected Cell;
- return exact raw response bytes;
- install persistent challenge issuer, authority/revocation store and replay
  ledger;
- keep every operation unavailable until its complete authority Cell exists;
- reject legacy authorization and wrong origin/host;
- expose sanitized readiness without private data; and
- prove restart, race and fail-closed behavior.

### 15.4 Binding consumer assertions

A later Binding lane must:

- pin the same immutable transport and CellProtocol artifact;
- persist response expectation before send;
- never reconstruct signed inner bytes;
- treat non-2xx, malformed, unsigned, stale, wrong-owner or wrong-generation
  output as failure;
- never use historical register or replayed status as fresh status;
- show registered only from fresh verified `active_consented`;
- persist a revoke retry/tombstone record before sending;
- retry only exact prepared bytes after ambiguous loss;
- keep raw APNS token out of `UserDefaults`, logs and response evidence; and
- reconcile token changes through reviewed generation semantics.

## 16. Negative and adversarial test plan

No test was run in this author-only phase. A future authorized source packet
must include at least:

### 16.1 Canonical byte rejection

- empty, oversize and malformed canonical payload;
- alternate whitespace/key order/slash escaping;
- duplicate or unknown keys;
- malformed, unpadded or URL-safe outer base64;
- decoded byte mutation for challenge, request, protected body, Contract and
  response;
- wrong body/challenge/Contract/result digest;
- v1/v2 negative vectors remain rejected;
- old v3 register bytes remain unchanged; and
- transport decode never “repairs” inner bytes.

### 16.2 Identity and authority rejection

- wrong subject, key, domain binding or purpose;
- global/account identity substituted for domain-scoped identity;
- wrong audience/origin/host;
- wrong target Cell UUID;
- wrong target owner UUID/key;
- alternate cryptographically valid Contract;
- wrong Agreement subject/domain/grant/access;
- declared Condition without a pinned fresh evaluation receipt;
- stale authority or revocation generation;
- attacker-selected Resolver mapping;
- route, bearer, APNS topic or transport possession used as authority; and
- signed challenge intent with client-selected target/owner material.

### 16.3 Challenge and replay rejection

- expired/future intent;
- intent nonce outside 32...64 bytes;
- identical nonce with different intent bytes;
- challenge issuer generation rollback;
- unapproved issuer rotation;
- changed request on consumed challenge;
- concurrent duplicate request produces one target operation;
- restart returns byte-identical response;
- admitted request with missing committed response never mutates again; and
- expired replay never becomes a fresh operation.

### 16.4 Status rejection

- historical register response passed to status verifier;
- replayed status passed as fresh current status;
- wrong registration ID or subject;
- registration/revocation generation rollback;
- active/revoked with missing record hash/generation;
- unknown with a fabricated registration record;
- indeterminate without bounded retry;
- unknown/indeterminate presented as registered; and
- status read causing a registration mutation.

### 16.5 Revoke rejection

- wrong operation/body/result pairing;
- missing or stale expected generations;
- unknown registration reported as successful revoke;
- second mutation on exact request replay;
- generation increments more than once;
- new stale request silently treated as replay;
- revoke receipt without durable tombstone;
- revoke followed by local “registered” state without fresh status; and
- pre-registration “Not now” invoking revoke.

### 16.6 Privacy and carrier rejection

- raw APNS token in result, error, log or diagnostic;
- push token, device ID, signed Contract or protected body in transport error;
- Authorization or `X-HAVEN-Device-Callback-Token`;
- wrong HTTP method/path/content type;
- response larger than 65536 bytes;
- non-2xx treated as protocol success; and
- outer wrapper interpreted as a capability.

## 17. Owner-decision and blocker ledger

| ID | Exact decision/blocker | Owner | Current state | Blocks |
| --- | --- | --- | --- | --- |
| `OD-01` | Accept additive `status`/`revoke` under v3, or require a full v4 migration | CellProtocol contract owner + compatibility reviewer | OPEN | Source packet |
| `OD-02` | Accept exact operation/resource/action/capability/access table | CellProtocol contract/security owner | OPEN | MBI-01/02 closure |
| `OD-03` | Accept status body/result fields, states and registration-generation token binding | CellProtocol + server + Binding owners | OPEN | MBI-01 and MBI-05 |
| `OD-04` | Accept revoke CAS, already-revoked and tombstone semantics | CellProtocol + server authority owner | OPEN | MBI-02 |
| `OD-05` | Freeze issuer-rotation record schema, storage path and owner proof | Identity/challenge issuer owner | OPEN | MBI-03 production closure |
| `OD-06` | Place exact new Swift error cases and public sanitized mapping | CellProtocol + CellScaffold owners | OPEN | Error compatibility |
| `OD-07` | Approve exact new fixture bytes, keys and SHA ledger | Contract/security + cross-runtime reviewers | OPEN | Immutable artifact |
| `OD-08` | Name production issuer, durable ledger, authority/revocation store, Cells and Agreement output paths | CellScaffold authority/storage owner | MISSING-BOUND-INPUT | MBI-04 |
| `OD-09` | Name Binding status/revoke/token-generation output paths | Binding owner | MISSING-BOUND-INPUT | MBI-05 |
| `OD-10` | Supply sanitized Apple Team/profile/certificate/codesign/archive evidence | Apple account holder | UNAUDITED / MISSING | MBI-06 |
| `OD-11` | Produce exact integrated commit/tree/digest | Development admin after all lanes independently green | MISSING | MBI-07 |

No open decision may be silently filled by an implementer.

## 18. MBI disposition

| MBI | S1-A author disposition | Operative state |
| --- | --- | --- |
| `MBI-01` canonical current status | Literal author proposal in section 7 | **AUTHOR-PROPOSED BOUND, UNREVIEWED; NOT CLOSED** |
| `MBI-02` typed revoke/deregister | Literal author proposal in section 7 | **AUTHOR-PROPOSED BOUND, UNREVIEWED; NOT CLOSED** |
| `MBI-03` challenge framing | Literal author proposal in section 8 | **PARTIAL; OD-05 REMAINS OPEN** |
| `MBI-04` production issuer/admission/replay/Cells/Agreement outputs | Outside Lane A | **MISSING** |
| `MBI-05` Binding outputs and token-rotation consumption | Outside Lane A; generation proposal only | **MISSING** |
| `MBI-06` Apple signing material | Forbidden external evidence | **UNAUDITED / MISSING** |
| `MBI-07` integrated output object | No integration authorized | **MISSING** |

## 19. Identity and release separation

The exact `c700dbc…` full tree selected by S0 is not an input to this Lane A
source proposal and is not modified or validated here.

Identity cutover remains a separate prerequisite covering:

- root and owner continuity;
- duplicate/recovery repair;
- vault and physical-authority continuity;
- Agreement and Resolver ownership;
- migration rollback; and
- production authority.

Likewise:

- `org.digipomps.haven` bundle/topic alignment is not signing proof;
- `https://haven.digipomps.org` is an intended production origin, not TLS or
  deployed-byte proof;
- Associated Domains remains removable unless its separate lane becomes
  green;
- no production profile, certificate, archive entitlement or codesign
  authority was inspected; and
- no APNS provider acceptance or physical callback occurred.

## 20. Claim and decision log

| Root claim | Author evaluation | Basis |
| --- | --- | --- |
| One three-field wrapper can carry challenge, request and protected body exactly | SUPPORTED AS DESIGN/FROM CURRENT SOURCE | `d2d1b…` wrapper and `79ce4f…` digest checks |
| The same wrapper also contains the signed Contract and response | CONTRADICTED | Contract comes from Resolver-selected authority Cell; response is raw output |
| Status/revoke names and schemas are immutable facts | CONTRADICTED | They are absent at `79ce4f…` |
| The literal status/revoke proposal is ready for owner review | AUTHOR ASSERTION, UNREVIEWED | Sections 7 and 17 |
| Challenge transport can remain semantically neutral | SUPPORTED AS PROPOSAL, CONDITIONAL | One-field byte carrier plus Resolver/Agreement path; OD-05 open |
| This packet authorizes source work | CONTRADICTED | Explicit scope boundary |
| This packet makes APNS production-ready | CONTRADICTED | MBI-01...07 and downstream evidence remain |

Author decision:

```text
S1 LANE A PACKET: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
```

Reasons:

1. author self-review has no credit;
2. `OD-01` through `OD-07` require owner and independent review;
3. `MBI-04` through `MBI-07` remain missing or unaudited;
4. no immutable successor artifact exists;
5. no source phase is authorized; and
6. no integration, signing, runtime or device evidence exists.

The author stops after this file.
