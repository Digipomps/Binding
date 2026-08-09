# APNS S2 CellProtocol Producer Contract Correction Packet

Date: 2026-07-24  
Lane: S2 Lane A — CellProtocol producer contract correction  
Artifact class: static correction packet only  
Source authorization: **none**  
Independent review status: **not yet performed**

## 0. Executive verdict

This packet corrects the static CellProtocol producer contract proposed in S1.
It does not authorize source edits, Git changes, builds, tests, network access,
Apple Developer Portal access, signing changes, device work, APNS traffic,
secret access, Identity cutover, staging, or deployment.

The corrected architecture has one non-negotiable boundary:

> The HTTP transport carries exact opaque protocol bytes. It may validate only
> the outer carrier, byte limits, HTTP method/path, origin policy, and HTTP
> response framing. It MUST NOT decode, canonicalize, interpret, authorize, or
> make decisions from the inner CellProtocol operation.

The authenticated CellProtocol Resolver/Cell boundary owns all inner semantics:

- canonical operation decoding;
- route-to-operation equality;
- schema validation;
- subject and device Identity verification;
- domain, purpose, and audience verification;
- Resolver target resolution;
- Agreement and Contract verification;
- capability/access-vector enforcement;
- replay and idempotency;
- operation-specific state transition;
- durable admission and mutation receipts.

This packet also:

- freezes six protected operations rather than the five incomplete S1
  operations;
- separates `revokeDevice` from `deregisterDevice`;
- adds a privacy-preserving, subject-bound registration status selector that
  works when local `registrationID` state is lost;
- adds exact mutation correlation for ambiguous registration and token
  rotation outcomes;
- assigns registration status the exact `r--s` access vector;
- freezes a producer-owned machine-readable fixture manifest path and schema;
- closes the technically derivable parts of OD-01 through OD-07;
- leaves only genuine authority, trust-root, fixture-byte, and deployment
  evidence inputs open;
- records an explicit disposition for every S1 Lane A P1/P2 finding and for
  MBI-01, MBI-02, and MBI-03.

Nothing in this packet is a production-readiness claim. All proposed corrections
remain `STATICALLY CORRECTED / UNREVIEWED / OPERATIONALLY MISSING` until crossed
independent review and later explicitly authorized implementation and evidence
phases succeed.

## 1. Formål, mål, and non-goals

### Formål A — restore the CellProtocol authority boundary

**Why:** S1 allowed the transport/server adapter to decode an authority-bearing
inner operation. That conflicted with the protocol rule that transport is
semantically neutral and that the Resolver/target Cell is the policy enforcement
point.

**Evidence:** the S1 A independent review finding P1-A-01, the CellProtocol
transport invariants, and the S1 server/client reviews.

**Success criterion:** an implementation can replace HTTP with another carrier
without changing protocol authority, and a route mismatch cannot cause
admission or mutation.

### Formål B — make registration lifecycle recovery complete

**Why:** S1 defined revocation but not deregistration, and status recovery
required a locally retained `registrationID`.

**Evidence:** P1-A-02 and P1-A-03.

**Success criterion:** revoke and deregister have distinct state effects and
receipts, and an authenticated subject can recover its current registration
state without enumerating other subjects or knowing a local registration ID.

### Formål C — make ambiguous registration/token rotation adjudicable

**Why:** a generation floor alone cannot determine whether an ambiguous request
with specific request and protected-body bytes committed.

**Evidence:** P1-A-05 and the S1 Binding client review.

**Success criterion:** a signed status response classifies the exact
`admissionID + requestSHA256 + bodySHA256 + expected previous generation` as
current, superseded, not found, or inconsistent.

### Formål D — freeze cross-runtime proof inputs

**Why:** S1 did not name a producer-owned machine-readable fixture manifest, and
the consumer fixture plan incorrectly assigned `rw-s` to status.

**Evidence:** P2-A-01 and P2-A-02.

**Success criterion:** one producer path and manifest schema are frozen, every
consumer verifies the producer bytes and SHA-256 ledger, and status uses `r--s`
in all runtimes.

### Non-goals

This packet does not:

- implement or edit Swift;
- generate production or test signing keys;
- generate signed fixture bytes;
- select or invent a challenge-issuer trust root;
- change the immutable S0 packet or review;
- edit either S1 consumer packet or review;
- touch CellScaffold or Binding source;
- prove TLS or deployment behavior;
- provision APNS;
- perform Identity cutover;
- close staging or physical-device evidence.

## 2. Exact immutable lineage

All rows below were re-attested read-only on 2026-07-24. S0 is immutable.

| Artifact | Lines | Bytes | SHA-256 | Status in S2 |
|---|---:|---:|---|---|
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | 573 | 38,154 | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | lineage only |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | 547 | 29,346 | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | lineage only |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | 984 | 54,678 | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | immutable governing S0 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | 461 | 22,485 | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | immutable governing review |
| `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | 1,141 | 48,951 | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | corrected by this packet |
| `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md` | 691 | 27,880 | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 0 P0 / 5 P1 / 2 P2 |
| `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | 1,113 | 48,837 | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | bound consumer input |
| `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md` | 822 | 37,781 | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | bound consumer review |
| `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | 853 | 45,250 | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | bound consumer input |
| `Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md` | 471 | 21,808 | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | bound consumer review |

The six S1 artifacts are evidence inputs. This packet does not silently rewrite
their contents. Where this packet conflicts with S1 Lane A, this packet is the
S2 author proposal that must be crossed reviewed before it can govern later
implementation.

## 3. Preserved S0 constants and readiness separation

The following constants remain exact:

| Item | Exact value |
|---|---|
| macOS bundle identifier | `org.digipomps.haven` |
| APNS topic | `org.digipomps.haven` |
| production web origin | `https://haven.digipomps.org` |
| CellProtocol Identity domain | `domain:device:notification-callback` |
| purpose | `purpose://access.audit.privacy/device-notification-callback` |
| protocol audience projection | `haven.digipomps.org` |

The following separations remain exact:

- transport contract readiness is not Identity readiness;
- Identity readiness is not signing readiness;
- signing readiness is not APNS readiness;
- simulator contract evidence is not physical-device evidence;
- staging APNS evidence is not production APNS evidence;
- static correction is not source authorization.

MBI-06 remains `UNAUDITED / MISSING`. MBI-07 remains `MISSING`. Neither is
upgraded by this packet.

## 4. S1 Lane A review finding map

| Finding | S1 defect | S2 correction | Static disposition |
|---|---|---|---|
| P1-A-01 | transport/server decoded inner operation to bind route | transport handles opaque bytes only; authenticated CellProtocol boundary decodes and verifies route equality | corrected proposal; review required |
| P1-A-02 | revoke existed; deregister was absent | separate `revokeDevice` and `deregisterDevice` operations, receipts, replay, idempotency, and state effects | corrected proposal; review required |
| P1-A-03 | status required local `registrationID` | subject-bound `subject_current` selector plus retained `registration_id` selector | corrected proposal; review required |
| P1-A-04 | origin/audience/TLS/redirect policy incomplete | exact origin projection, authority, redirect, encoding, content type, and TLS responsibility table | static policy corrected; deployment proof missing |
| P1-A-05 | generation floor did not correlate ambiguous token rotation | exact mutation correlation tuple and signed correlation disposition | corrected proposal; review required |
| P2-A-01 | consumer fixture plan assigned status `rw-s` | status is exactly `r--s`; all other listed operations remain `rw-s` | corrected proposal; consumer packet still needs its own correction |
| P2-A-02 | no producer-owned machine-readable fixture manifest | exact path and deterministic manifest schema frozen | path/schema corrected; generated bytes and hashes missing |

## 5. Normative boundary model

```text
HTTP/TLS carrier
  validates only method, configured path, exact outer JSON shape,
  Base64 syntax, byte limits, configured authority, response framing
        |
        | DeviceIngressOpaqueCarrier:
        | exact canonicalChallenge bytes
        | exact canonicalRequest bytes
        | exact protectedBody bytes
        | unauthoritative route label
        v
CellScaffold composition adapter
  maps configured route label to an expected CellProtocol operation
  but grants no authority and performs no inner decode
        |
        v
Authenticated CellProtocol operation boundary
  canonical decode -> route equality -> signature/Identity ->
  domain/purpose/audience -> Resolver target -> Agreement/Contract ->
  capability -> replay/admission -> target Cell operation
        |
        v
Durable admission/audit and operation-specific state/receipt
```

The route label is metadata supplied to the authenticated boundary. It is not
proof of authority. The authenticated boundary MUST reject a mismatch between
the expected operation and the operation inside the signed canonical request
before admission ledger creation or target mutation.

The transport MUST NOT:

- import or call a CellProtocol envelope/request decoder;
- inspect the inner `schema`;
- inspect the inner `operation`;
- inspect Identity, Agreement, Contract, capability, subject, purpose, audience,
  target, selector, registration ID, token, or result;
- re-encode, normalize, or reorder inner JSON;
- select a target Cell from inner bytes;
- create protocol admission records;
- classify protocol errors from inner content.

The transport MAY:

- Base64-decode the three outer carrier strings to exact byte arrays;
- reject non-canonical Base64 at the outer carrier boundary;
- enforce field and total byte limits;
- map a configured HTTP path to an unauthoritative route label;
- enforce HTTP origin, method, header, redirect, and response-size policy;
- pass exact bytes and the route label to a supplied operation executor;
- return the executor's exact response bytes inside the specified outer
  response carrier.

## 6. OD-01 — conservative v4 wire correction

OD-01 is technically resolved in this author proposal by selecting a new
CellProtocol producer contract version.

Reason:

- the operation enum expands;
- status request/result semantics change;
- deregistration is introduced;
- registration correlation is introduced;
- response result alternatives expand;
- treating those changes as silently additive under the same schema version can
  make old consumers accept a schema name whose enum and state semantics they do
  not implement.

Exact rule:

- all existing S1/current v3 fixture bytes remain immutable;
- v3 retains only its already-defined operation set and semantics;
- no new status, revoke, deregister, correlation, or response variant is encoded
  under a v3 schema;
- the corrected protected operation contract uses
  `cellprotocol.device-ingress.envelope.v4`;
- the corrected authority reference, admission record, admission receipt, and
  mutation receipt use their corresponding `.v4` schemas;
- the expanded operation response/result use
  `cellprotocol.device-ingress.operation-response.v2`;
- the corrected challenge intent uses
  `cellprotocol.device-ingress.challenge-intent.v2`;
- the corrected protected HTTP carrier uses
  `haven.device-callback.transport.v4`;
- the corrected challenge carrier uses
  `haven.device-callback.challenge-request.v2`;
- v3 and v4 replay/admission keys MUST include the exact schema version;
- a v3 signed request cannot be reinterpreted as v4;
- after a later explicitly authorized v4 cutover, v3 may be retained only for
  immutable fixture verification or an explicitly reviewed compatibility
  window. This packet does not authorize a compatibility window.

This is an author-side technical correction, not an implemented or independently
accepted compatibility decision.

## 7. OD-02 — total protected operation set

There are exactly six protected operations in the corrected v4 contract.
Challenge acquisition is a preflight exchange and is not a seventh protected
operation.

| Wire operation | Resource | Capability | Access | HTTP route | State effect |
|---|---|---|---|---|---|
| `registerOrUpdateDevice` | `cell:///DeviceRegistration` | `device.registration.write` | `rw-s` | `/conference-mvp/api/device/register` | enroll, reactivate, or rotate registration |
| `readRegistrationStatus` | `cell:///DeviceRegistration` | `device.registration.status` | `r--s` | `/conference-mvp/api/device/registration/status` | admission/audit only; no registration mutation |
| `revokeDevice` | `cell:///DeviceRegistration` | `device.registration.revoke` | `rw-s` | `/conference-mvp/api/device/registration/revoke` | disable delivery and revoke current token binding |
| `deregisterDevice` | `cell:///DeviceRegistration` | `device.registration.deregister` | `rw-s` | `/conference-mvp/api/device/registration/deregister` | erase endpoint/token material and retain minimal tombstone |
| `resolveTicket` | `cell:///DeviceCallbackBridge` | `device.callback.resolve` | `rw-s` | `/conference-mvp/api/device/callback/resolve` | callback bridge state mutation |
| `submitTicketResult` | `cell:///DeviceCallbackBridge` | `device.callback.submit` | `rw-s` | `/conference-mvp/api/device/callback/submit` | callback bridge result mutation |

All six use:

- domain `domain:device:notification-callback`;
- purpose `purpose://access.audit.privacy/device-notification-callback`;
- audience `haven.digipomps.org`;
- authenticated subject derived from the signed request and Identity material;
- an exact Resolver target match;
- a signed Agreement/Contract whose conditions authorize that exact tuple.

The `rw-s` and `r--s` strings are exact. Status is never `rw-s`.

## 8. Corrected transport contract

### 8.1 Exact outer protected carrier

Schema: `haven.device-callback.transport.v4`

Exactly four JSON members:

```json
{
  "canonicalChallenge": "<canonical Base64 of exact bytes>",
  "canonicalRequest": "<canonical Base64 of exact bytes>",
  "protectedBody": "<canonical Base64 of exact bytes>",
  "schema": "haven.device-callback.transport.v4"
}
```

Canonical JSON keys are lexicographically sorted. Unknown, missing, duplicate,
or empty members are rejected. The transport decodes Base64 but does not inspect
the decoded bytes.

### 8.2 Exact outer challenge carrier

Schema: `haven.device-callback.challenge-request.v2`

Exactly two JSON members:

```json
{
  "canonicalIntent": "<canonical Base64 of exact bytes>",
  "schema": "haven.device-callback.challenge-request.v2"
}
```

HTTP route:

`POST /conference-mvp/api/device/challenge`

The transport does not decode the intent. The authenticated challenge boundary
decodes it and verifies the requested operation tuple before issuing a
challenge.

### 8.3 Route label behavior

The transport-level route enum has exactly:

- `challenge`;
- `register`;
- `registrationStatus`;
- `registrationRevoke`;
- `registrationDeregister`;
- `callbackResolve`;
- `callbackSubmit`.

It is an HTTP routing type, not `DeviceIngressOperation`.

The composition adapter performs a fixed mapping:

| Route label | Expected CellProtocol operation |
|---|---|
| `register` | `registerOrUpdateDevice` |
| `registrationStatus` | `readRegistrationStatus` |
| `registrationRevoke` | `revokeDevice` |
| `registrationDeregister` | `deregisterDevice` |
| `callbackResolve` | `resolveTicket` |
| `callbackSubmit` | `submitTicketResult` |

`challenge` maps to the challenge-intent executor and no protected operation.
The mapping is passed into the authenticated boundary and verified against the
signed bytes. It is not used as authorization.

### 8.4 Package dependency invariant

The proposed `CellDeviceIngressTransport` target MUST NOT depend on `CellBase`,
`CellApple`, a Resolver implementation, an Identity implementation, or an
Agreement implementation.

It may depend on:

- Foundation;
- FoundationNetworking where required;
- transport-local carrier and route types.

The server composition target owns the adapter from the transport route label to
the CellProtocol authenticated boundary. This dependency rule is a static
architectural test oracle for P1-A-01.

## 9. Authenticated Resolver/Cell operation boundary

The corrected producer boundary receives:

- `expectedOperation: DeviceIngressOperation`;
- exact canonical challenge bytes;
- exact canonical request bytes;
- exact protected-body bytes;
- authenticated server clock and durable stores;
- Resolver and Identity/Agreement verification dependencies.

It returns exact canonical response bytes or a typed protocol error.

The mandatory evaluation order is:

1. Enforce producer-side raw byte bounds.
2. Strictly canonical-decode the request and challenge under the selected v4
   schemas.
3. Verify the request's signed `operation` equals `expectedOperation`.
4. Verify operation/resource/capability/access/domain/purpose/audience are the
   exact frozen tuple.
5. Verify challenge request hash/body hash bindings against the exact supplied
   bytes.
6. Verify challenge issuer descriptor, generation floor, nonce, issued time,
   expiry, and single-use semantics.
7. Verify request subject signature and device Identity.
8. Resolve the exact target Cell through the Resolver.
9. Verify the target Cell identity/owner matches the signed authority
   reference.
10. Verify Agreement and Contract signatures, hashes, parties, conditions,
    purpose, audience, validity interval, and revocation status.
11. Enforce the exact capability and access vector.
12. Classify replay by the full immutable admission key.
13. Atomically write the admission record or return the exact historical
    response for an exact replay.
14. Execute the target Cell operation and its operation-specific mutation.
15. Atomically bind the mutation receipt and exact response bytes to the
    admission record.

No target mutation occurs if steps 1 through 12 fail.

Status is a read of registration state, but step 13 still creates a durable
admission/audit record. Status MUST NOT increment registration or revocation
generations.

The exact admission key is:

```text
SHA256(
  envelopeSchema ||
  challengeIssuerID ||
  challengeGeneration ||
  challengeNonce ||
  requestSubject ||
  operation ||
  requestSHA256 ||
  bodySHA256
)
```

The length-prefixing/canonical serialization used to compute that key must be
fixed in the producer fixture bytes before source authorization. String
concatenation without length framing is forbidden.

## 10. Identity, Agreement, Contract, and Resolver invariants

An Agreement is necessary but does not itself grant access. Authorization
requires all of:

- a valid authenticated subject;
- a Resolver-selected target Cell;
- a target Cell whose identity/owner matches the signed authority reference;
- an applicable, unexpired, unrevoked Agreement;
- an applicable signed Contract or grant;
- satisfied Agreement/Contract conditions;
- an exact operation/resource/capability/access/domain/purpose/audience match.

The authenticated subject is derived from verified Identity material. It MUST
NOT be accepted from:

- an HTTP header;
- a route;
- an unsigned protected-body field;
- a registration ID;
- a client-supplied status selector subject;
- a reverse-proxy header.

For registration status recovery, the target Cell derives the lookup key from:

```text
authenticated subject
+ domain:device:notification-callback
+ cell:///DeviceRegistration
```

The client cannot supply a different subject. The status selector contains no
subject field.

Identity cutover is deliberately separate. This packet neither selects nor
installs an Identity implementation, issuer key, trust anchor, Agreement, or
grant.

## 11. Challenge intent v2

Schema:

`cellprotocol.device-ingress.challenge-intent.v2`

Required members:

- `schema`;
- `operation`;
- `resource`;
- `capability`;
- `access`;
- `domain`;
- `purpose`;
- `audience`;
- `requestSHA256`;
- `bodySHA256`;
- `clientNonce`;
- `requestedAt`.

The operation tuple must equal exactly one row in section 7.

Limits:

- canonical intent bytes: 65,536 maximum;
- `clientNonce`: 32 through 64 bytes;
- request and body SHA-256: exactly 32 bytes each;
- maximum challenge lifetime: 60,000 ms;
- one challenge may authorize one exact request/body tuple only;
- the challenge response is at most 65,536 canonical bytes.

Challenge issuance is authorized at the authenticated challenge boundary. The
HTTP carrier cannot decide whether an operation tuple is valid.

## 12. Registration mutation correlation

### 12.1 Purpose

The correlation contract determines whether the exact ambiguous register/update
attempt committed and whether it is still current. It does not authorize the
mutation and does not replace the signed request.

Schema:

`cellprotocol.device-ingress.registration-mutation-correlation.v1`

Required members:

- `schema`;
- `operation`, exactly `registerOrUpdateDevice`;
- `admissionID`;
- `requestSHA256`, exactly 32 bytes;
- `bodySHA256`, exactly 32 bytes;
- `expectedPreviousRegistrationGeneration`.

The register mutation receipt and target registration record must durably retain:

- admission ID;
- exact request SHA-256;
- exact protected-body SHA-256;
- actual previous registration generation;
- committed registration generation;
- record SHA-256;
- commit time;
- persistence semantics.

`expectedPreviousRegistrationGeneration` is:

- `0` for first enrollment;
- the last client-accepted generation for rotation, update, or reactivation.

The target serializes registration mutations per authenticated subject and
registration ID. The correlation outcome is:

| Disposition | Exact meaning |
|---|---|
| `current_exact` | all correlation fields match the currently active or revoked registration mutation and expected previous generation equals the stored actual previous generation |
| `superseded` | the exact mutation committed, but a later committed registration mutation is current |
| `not_found` | no committed mutation for the authenticated subject matches the complete tuple |
| `inconsistent_retryable` | durable evidence is incomplete or fields partially conflict; the server must not guess success or absence |

Only `current_exact` proves that the ambiguous token rotation is current.
`superseded` proves historical commit but not current token state.

The server MUST NOT return `current_exact` from generation alone.

## 13. Privacy-preserving registration status recovery

### 13.1 Request v2

Schema:

`cellprotocol.device-ingress.registration-status-request.v2`

Required members:

- `schema`;
- `selector`;
- `minimumRegistrationGeneration`;
- `minimumRevocationGeneration`.

Optional member:

- `correlation`.

The selector is a closed union:

```json
{"kind":"registration_id","registrationID":"<non-empty ID>"}
```

or:

```json
{"kind":"subject_current"}
```

No other key is allowed in either selector variant.

### 13.2 Authority and privacy rules

Both selectors require the exact status tuple:

- resource `cell:///DeviceRegistration`;
- capability `device.registration.status`;
- access `r--s`;
- exact domain, purpose, and audience from section 3.

`registration_id`:

- resolves only if the requested registration belongs to the authenticated
  subject under the exact domain and target Cell;
- a registration owned by another subject is indistinguishable from unknown;
- it never reveals another subject or whether another registration exists.

`subject_current`:

- derives the subject from authenticated Identity;
- returns at most one current registration or the most recent terminal
  deregistration tombstone;
- returns no collection, count, alternate IDs, or partial matches;
- supports recovery when local `registrationID` state has been lost;
- returns `unknown` if there is no record for the authenticated subject;
- returns `indeterminate_retryable` if the unique-current invariant cannot be
  proven.

The target Cell must enforce one current logical registration per authenticated
device subject. If historical corruption produces multiple current records, it
must not choose one nondeterministically.

### 13.3 Result v2

Result kind:

`registration_status`

Payload schema:

`cellprotocol.device-ingress.registration-status.v2`

Required members:

- `schema`;
- `selectorKind`;
- `state`;
- `revocationGeneration`;
- `observedAt`;
- `persistenceSemantics`.

Conditionally required members:

- `registrationID`, `deviceIdentityUUID`, `registrationGeneration`, and
  `registrationRecordSHA256` for `active_consented` or `revoked`;
- `registrationID`, `deviceIdentityUUID`, `registrationGeneration`, and
  `tombstoneSHA256` for `deregistered`;
- `retryAfter` for `indeterminate_retryable`;
- `correlationSHA256` and `correlationDisposition` if the request included
  correlation.

Allowed states:

- `active_consented`;
- `revoked`;
- `deregistered`;
- `unknown`;
- `indeterminate_retryable`.

`unknown` does not prove that no record has ever existed. It proves only that the
authorized target had no status it could disclose for this authenticated subject
at `observedAt`.

`persistenceSemantics` is exactly:

`durable_status_admission_and_signed_observation_no_registration_mutation`

### 13.4 Status freshness and replay

- An exact request replay returns the exact historical signed response bytes.
- A historical replay is not a fresh observation.
- A fresh observation requires a new client nonce, challenge, request, and
  admission.
- The client accepts a result only when its minimum generation floors are met.
- Status never repairs state implicitly.
- `indeterminate_retryable` is not success, revoke, deregister, or unknown.

### 13.5 Exact unsigned status body vectors

These vectors freeze canonical protected-body bytes only. They are not signed
contract fixtures.

Subject-current with correlation:

```json
{"correlation":{"admissionID":"admission_fixture_01","bodySHA256":"IiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI=","expectedPreviousRegistrationGeneration":7,"operation":"registerOrUpdateDevice","requestSHA256":"ERERERERERERERERERERERERERERERERERERERERERE=","schema":"cellprotocol.device-ingress.registration-mutation-correlation.v1"},"minimumRegistrationGeneration":8,"minimumRevocationGeneration":0,"schema":"cellprotocol.device-ingress.registration-status-request.v2","selector":{"kind":"subject_current"}}
```

- UTF-8 byte count: `507`;
- SHA-256:
  `144bb92b8987541bc16f83b61e89386103e70226dd867ee02c082d79bc13c0af`.

Registration-ID selector:

```json
{"minimumRegistrationGeneration":8,"minimumRevocationGeneration":0,"schema":"cellprotocol.device-ingress.registration-status-request.v2","selector":{"kind":"registration_id","registrationID":"registration_fixture_01"}}
```

- UTF-8 byte count: `218`;
- SHA-256:
  `07afe05e58f206f155ca46f3d60d0632d99f0da65a1a86b9633219eae3edd0c0`.

## 14. Revoke semantics

### 14.1 Request

Schema:

`cellprotocol.device-ingress.registration-revoke-request.v1`

Required members:

- `schema`;
- `registrationID`;
- `expectedRegistrationGeneration`;
- `expectedRevocationGeneration`;
- `reasonCode`.

Allowed reason codes:

- `user_disabled_notifications`;
- `token_rejected`;
- `device_replaced`;
- `security_response`;
- `owner_policy`.

### 14.2 Current-state effect

On an authorized active registration:

- delivery becomes disabled;
- the current token binding is removed from the active delivery index;
- active APNS token bytes are no longer available to the delivery path;
- registration ID, subject binding, generation, audit hashes, and minimal
  revocation state remain;
- `revocationGeneration` increments exactly once;
- `registrationGeneration` does not increment;
- a fresh register/update with fresh consent and a fresh token may reactivate the
  same logical registration under an exact expected generation check.

Revoke is not privacy erasure and does not represent deregistration.

### 14.3 Receipt

Result kind:

`registration_revocation_receipt`

Payload schema:

`cellprotocol.device-ingress.registration-revocation-receipt.v1`

Required members:

- `schema`;
- `registrationID`;
- `deviceIdentityUUID`;
- `registrationGeneration`;
- `previousRevocationGeneration`;
- `revocationGeneration`;
- `state`, exactly `revoked`;
- `disposition`;
- `registrationRecordSHA256`;
- `durableSequence`;
- `committedAt`;
- `persistenceSemantics`.

Allowed dispositions:

- `revoked`;
- `already_revoked`.

Persistence semantics:

`same_cell_atomic_delivery_disable_revocation_state_and_response`

### 14.4 Idempotency and replay

- exact replay returns the exact historical response bytes and creates no second
  mutation;
- a new authorized revoke against already-revoked current state, with exact
  current generations, returns `already_revoked`;
- `already_revoked` does not increment either generation;
- stale expected registration or revocation generation fails;
- revoke against a deregistered tombstone fails with
  `registrationAlreadyDeregistered`;
- unknown or wrong-subject IDs disclose no cross-subject existence information.

## 15. Deregister semantics

### 15.1 Request

Schema:

`cellprotocol.device-ingress.registration-deregister-request.v1`

Required members:

- `schema`;
- `registrationID`;
- `expectedRegistrationGeneration`;
- `expectedRevocationGeneration`;
- `reasonCode`;
- `deletionMode`, exactly `endpoint_and_token_material`.

Allowed reason codes:

- `consent_withdrawn`;
- `device_removed`;
- `privacy_erasure`;
- `owner_policy`.

### 15.2 Current-state effect

Deregister is an authorized terminal transition for the referenced logical
registration:

- erase endpoint and APNS token material from active and revoked stores;
- remove the registration from the active delivery index;
- remove mutable endpoint metadata that is not required for the minimal
  tombstone;
- retain only the minimal subject-bound tombstone needed for exact replay,
  idempotency, non-resurrection, and authorized status;
- increment `revocationGeneration` exactly once when transitioning from active
  or revoked;
- do not increment `registrationGeneration`;
- prohibit reactivation of the deregistered registration ID;
- require a new registration ID, fresh consent, and fresh admission for later
  enrollment.

The tombstone MUST NOT contain an APNS token, endpoint URL, authorization header,
device secret, or recoverable token ciphertext.

### 15.3 Receipt

Result kind:

`registration_deregistration_receipt`

Payload schema:

`cellprotocol.device-ingress.registration-deregistration-receipt.v1`

Required members:

- `schema`;
- `registrationID`;
- `deviceIdentityUUID`;
- `registrationGeneration`;
- `previousRevocationGeneration`;
- `revocationGeneration`;
- `state`, exactly `deregistered`;
- `disposition`;
- `deletionMode`, exactly `endpoint_and_token_material`;
- `deletedMaterialKinds`, exactly `["endpoint","token"]`;
- `tombstoneSHA256`;
- `durableSequence`;
- `committedAt`;
- `persistenceSemantics`.

Allowed dispositions:

- `deregistered`;
- `already_deregistered`.

Persistence semantics:

`same_cell_atomic_endpoint_token_erasure_tombstone_and_response`

No receipt field contains erased endpoint or token material.

### 15.4 Idempotency and replay

- exact replay returns the exact historical response bytes and creates no second
  mutation;
- a new authorized request against the same deregistered tombstone, with exact
  current generations, returns `already_deregistered`;
- `already_deregistered` does not increment either generation;
- deregister may transition from active or revoked;
- stale expected registration or revocation generation fails;
- a revoke after deregister fails;
- a register/update using the deregistered ID fails;
- a later new enrollment must use a new registration ID.

### 15.5 Exact unsigned deregister body vector

```json
{"deletionMode":"endpoint_and_token_material","expectedRegistrationGeneration":8,"expectedRevocationGeneration":0,"reasonCode":"consent_withdrawn","registrationID":"registration_fixture_01","schema":"cellprotocol.device-ingress.registration-deregister-request.v1"}
```

- UTF-8 byte count: `264`;
- SHA-256:
  `503be3b7f4329d08988d0ae8da8ea1bf494c335bbdfeeadaf1e0f0711bfd0db9`.

## 16. Registration state machine

| Current state | Operation | Preconditions | Next state | Generation effect |
|---|---|---|---|---|
| none | register | fresh consent; new ID; expected previous registration generation `0` | active | registration `0 -> 1`; revocation `0` |
| active | register/update | exact current ID and generations; fresh admission | active | registration `+1`; revocation unchanged |
| revoked | register/update | exact current ID and generations; fresh consent and token | active | registration `+1`; revocation unchanged |
| active | revoke | exact current generations | revoked | registration unchanged; revocation `+1` |
| revoked | revoke | exact current generations | revoked | no change; `already_revoked` |
| active | deregister | exact current generations | deregistered | registration unchanged; revocation `+1` |
| revoked | deregister | exact current generations | deregistered | registration unchanged; revocation `+1` |
| deregistered | deregister | exact current generations | deregistered | no change; `already_deregistered` |
| deregistered | revoke | any | reject | no change |
| deregistered | register/update with same ID | any | reject | no change |
| any | status | authorized selector and generation floors | same | no registration-state generation change |

Every transition is serialized in the target `DeviceRegistration` Cell. The
admission and operation receipt are durably correlated. A transport retry never
creates a second mutation for the same exact admission key.

For `subject_current`, a later new registration supersedes the subject's prior
terminal tombstone as the current status result. The old tombstone remains
addressable only through an authorized exact `registration_id` selector and
retention policy.

## 17. Origin, audience, TLS, redirect, and encoding policy

### 17.1 Exact projection

| Layer | Exact value |
|---|---|
| configured origin literal | `https://haven.digipomps.org` |
| URL scheme | `https` |
| DNS authority/Host | `haven.digipomps.org` |
| protocol audience | `haven.digipomps.org` |
| explicit port | forbidden |
| URL userinfo | forbidden |
| query on fixed endpoints | forbidden |
| fragment | forbidden |

The protocol audience is the exact DNS authority projection. It contains no
scheme, port, path, query, fragment, or wildcard.

### 17.2 Client requirements

- Build requests only by appending one exact path from sections 7 and 8 to the
  exact configured origin.
- Reject any non-HTTPS URL.
- Reject userinfo, explicit port, query, or fragment.
- Disable automatic redirect following for these requests.
- Treat every 3xx response as `redirectRejected`.
- Send `Content-Type: application/json`.
- Send `Accept: application/json`.
- Send no `Authorization` header.
- Send no request `Content-Encoding` other than identity/no header.
- Accept no response content encoding other than identity/no header.
- Use platform TLS server-trust evaluation for
  `haven.digipomps.org`.
- Do not install an ad hoc CA, trust-all delegate, or certificate bypass.

### 17.3 Server requirements

- Accept only the exact configured paths and `POST`.
- Validate the effective authority as `haven.digipomps.org` after the deployment's
  explicitly trusted proxy boundary.
- Do not derive protocol audience from an untrusted `Host`,
  `Forwarded`, or `X-Forwarded-Host` value.
- Require `Content-Type: application/json` with no media-type parameters.
- Reject unsupported content encoding.
- Return `Content-Type: application/json`.
- Do not redirect protocol endpoints.
- Pass the frozen protocol audience constant to the authenticated boundary.

Trusted-proxy configuration and deployed TLS proof are Lane B/deployment
evidence, not transport authority.

### 17.4 What is and is not closed

The static projection, client redirect rule, media type, content-encoding rule,
and protocol audience are closed as author proposals.

The following remain evidence inputs:

- deployed certificate chain and hostname validation;
- deployed TLS versions/ciphers as governed by platform/server policy;
- exact reverse-proxy trust boundary;
- proof that production endpoints do not redirect;
- challenge issuer rotation authority.

No certificate pin, CA, or issuer trust root is invented here.

## 18. Total error taxonomy

### 18.1 Transport-owned carrier errors

The transport module owns only:

- `emptyBody`;
- `payloadTooLarge`;
- `malformedJSON`;
- `unknownCarrierSchema`;
- `unknownField`;
- `duplicateField`;
- `missingField`;
- `emptyField`;
- `malformedBase64`;
- `nonCanonicalBase64`;
- `fieldTooLarge`;
- `wrongHTTPMethod`;
- `wrongHTTPPath`;
- `insecureScheme`;
- `invalidOrigin`;
- `authorityMismatch`;
- `invalidContentType`;
- `invalidAccept`;
- `unsupportedContentEncoding`;
- `legacyAuthorizationPresent`;
- `redirectRejected`;
- `tlsTrustEvaluationFailed`;
- `nonSuccessHTTPStatus`;
- `responseTooLarge`.

These errors reveal no inner protocol interpretation.

### 18.2 Authenticated protocol-boundary errors

The CellProtocol producer boundary owns:

- `unsupportedEnvelopeSchema`;
- `nonCanonicalProtocolBytes`;
- `unsupportedOperation`;
- `routeOperationMismatch`;
- `operationTupleMismatch`;
- `requestHashMismatch`;
- `bodyHashMismatch`;
- `invalidChallengeIntent`;
- `challengeIntentReplayConflict`;
- `challengeExpired`;
- `challengeAlreadyConsumed`;
- `challengeIssuerGenerationRollback`;
- `challengeIssuerRotationUnavailable`;
- `invalidSubjectIdentity`;
- `identityDomainMismatch`;
- `purposeMismatch`;
- `audienceMismatch`;
- `resolverTargetMismatch`;
- `agreementMissing`;
- `agreementInvalid`;
- `agreementExpired`;
- `agreementRevoked`;
- `contractInvalid`;
- `capabilityDenied`;
- `accessVectorDenied`;
- `admissionReplayConflict`;
- `admissionPersistenceUnavailable`.

`routeOperationMismatch` is never a transport error.

### 18.3 Registration Cell errors

The target `DeviceRegistration` Cell owns:

- `registrationUnknown`;
- `registrationSubjectMismatch`;
- `registrationGenerationMismatch`;
- `revocationGenerationMismatch`;
- `registrationAlreadyDeregistered`;
- `registrationIDReuseForbidden`;
- `statusSelectorInvalid`;
- `statusMultipleCurrentRecords`;
- `registrationCorrelationInvalid`;
- `registrationCorrelationEvidenceInconsistent`;
- `invalidRegistrationStatus`;
- `invalidRegistrationRevocationReceipt`;
- `invalidRegistrationDeregistrationReceipt`;
- `registrationPersistenceUnavailable`.

Wrong-subject and unknown registration lookup must have the same externally
observable status result/error class.

### 18.4 Result validation errors

The response decoder owns strict result-kind/schema/field validation. Unknown
result kinds, extra fields, invalid state/disposition combinations, missing
conditional fields, and invalid persistence semantics are rejected before client
state changes.

## 19. Total byte limits

| Object | Maximum canonical/decoded bytes |
|---|---:|
| challenge intent v2 | 65,536 |
| challenge request outer carrier v2 | 98,304 |
| challenge response | 65,536 |
| protected request outer carrier v4 | 327,680 |
| canonical challenge within carrier | 65,536 |
| canonical signed request within carrier | 65,536 |
| protected body within carrier | 65,536 |
| status request protected body | 4,096 |
| revoke request protected body | 4,096 |
| deregister request protected body | 4,096 |
| registration mutation correlation object | 2,048 |
| signed Agreement/Contract artifact | 65,536 |
| canonical operation result payload | 32,768 |
| canonical operation response | 65,536 |
| HTTP response outer carrier | 98,304 |

Rules:

- limits are enforced before unbounded allocation;
- Base64 decoded length and encoded carrier length are independently bounded;
- compressed request or response bodies are forbidden;
- limits do not authorize truncation;
- oversized values fail closed;
- the producer boundary repeats its own decoded-byte checks and does not trust a
  transport claim that bytes were bounded.

## 20. OD-07 — producer fixture manifest

### 20.1 Exact path

The producer-owned machine-readable manifest path is:

`Tests/CellBaseTests/Fixtures/DeviceIngressFixtureManifest.v1.json`

No consumer-owned manifest may replace it as the source of truth.

### 20.2 Exact manifest schema

Schema:

`cellprotocol.device-ingress.fixture-manifest.v1`

Top-level members, in canonical key order:

- `contractSchema`, exactly `cellprotocol.device-ingress.envelope.v4`;
- `entries`;
- `schema`;
- `testKeyPolicy`, exactly `test_only_non_production`;

Each `entries` item contains exactly:

- `byteCount`;
- `decodedSHA256` when the file contains Base64 of canonical bytes;
- `path`, relative to the CellProtocol repository root;
- `role`;
- `sha256`, hash of the exact fixture file bytes;
- `wireSchema`;

Entries are sorted lexicographically by `path`. SHA-256 values are lowercase
hex. Paths use `/`. No generated timestamp is permitted because it would make
the manifest nondeterministic.

The manifest itself is pinned by SHA-256 in each consumer's crossed fixture
test/evidence ledger. It cannot contain a self-hash.

### 20.3 Immutable v3 entries

The manifest must include and preserve the already accepted v3 fixture files and
their exact bytes. Existing v3 fixture hashes are read from the current producer
fixtures during the later authorized fixture-generation phase; this packet does
not fabricate them.

### 20.4 Required v4 fixture inventory

The v4 producer fixture inventory is exact:

#### Common positive fixtures

- `Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentRegister.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentStatus.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentRevoke.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentDeregister.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentResolve.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressChallengeIntentSubmit.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRegisterChallenge.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRegisterRequest.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRegisterProtectedBody.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRegisterContract.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRegisterResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusByIDChallenge.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusByIDRequest.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusByIDProtectedBody.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusByIDResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusBySubjectChallenge.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusBySubjectRequest.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusBySubjectProtectedBody.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusBySubjectResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusCorrelationCurrentResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusCorrelationSupersededResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusCorrelationNotFoundResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusCorrelationInconsistentResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRevokeChallenge.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRevokeRequest.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRevokeProtectedBody.v1.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRevokeResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressDeregisterChallenge.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressDeregisterRequest.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressDeregisterProtectedBody.v1.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressDeregisterResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressResolveChallenge.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressResolveRequest.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressResolveProtectedBody.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressResolveResponse.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressSubmitChallenge.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressSubmitRequest.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressSubmitProtectedBody.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressSubmitResponse.v2.b64`

#### Required negative fixtures

- `Tests/CellBaseTests/Fixtures/DeviceIngressRouteOperationMismatch.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressWrongAudience.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressWrongPurpose.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressWrongAccessStatus.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressWrongSubjectStatus.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressUnknownStatusSelector.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressStatusMultipleCurrentRecords.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRegistrationCorrelationPartialMismatch.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRevokeStaleGeneration.v1.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressDeregisterStaleGeneration.v1.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRevokeAfterDeregister.v1.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressRegisterReuseDeregisteredID.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressUnknownResultKind.v2.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressUnknownField.v4.b64`
- `Tests/CellBaseTests/Fixtures/DeviceIngressDuplicateField.v4.json`
- `Tests/CellBaseTests/Fixtures/DeviceIngressNonCanonicalJSON.v4.json`

### 20.5 Test-key rule

Any signature fixture key is:

- deterministic;
- explicitly test-only;
- stored only as a test vector;
- visibly unrelated to production;
- never accepted by production composition.

This packet does not generate a key or claim exact signed fixture hashes.

## 21. Reconciliation of P2-A-01

Every status fixture and every status Agreement/Contract fixture must contain:

- operation `readRegistrationStatus`;
- resource `cell:///DeviceRegistration`;
- capability `device.registration.status`;
- access `r--s`.

Any fixture containing `readRegistrationStatus` with `rw-s` is invalid and must
be a negative fixture named `DeviceIngressWrongAccessStatus.v4.b64`.

The S1 Binding packet's shared-fixture manifest row for status is therefore
superseded by this corrected author proposal. The Binding packet itself remains
unchanged and must receive its own separately authorized crossed correction.

## 22. Exact source-path proposal and ownership

These are later candidate implementation paths, not authorization to edit them.

### 22.1 CellProtocol producer paths

| Exact path | Owner | Proposed responsibility |
|---|---|---|
| `Package.swift` | CellProtocol package owner | v4 types/tests; transport target remains CellBase-independent |
| `Sources/CellBase/DeviceIngress/DeviceIngressWire.swift` | CellProtocol wire owner | v4 envelope/authority/response strict codecs |
| `Sources/CellBase/DeviceIngress/DeviceIngressAdmission.swift` | CellProtocol admission owner | authenticated operation boundary, route equality, replay/admission |
| `Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift` | CellProtocol response owner | v2 result kinds and validation |
| `Sources/CellBase/DeviceIngress/DeviceIngressChallengeIntent.swift` | CellProtocol challenge owner | challenge intent v2 strict codec/validation |
| `Sources/CellBase/DeviceIngress/DeviceIngressRegistrationStatus.swift` | DeviceRegistration Cell owner | selectors, correlation, status result |
| `Sources/CellBase/DeviceIngress/DeviceIngressRegistrationTermination.swift` | DeviceRegistration Cell owner | revoke/deregister requests and receipts |
| `Tests/CellBaseTests/DeviceIngressContractTests.swift` | CellProtocol contract-test owner | operation, authority, replay, state tests |
| `Tests/CellBaseTests/DeviceIngressWireFixtureTests.swift` | fixture owner | v3 immutability and v4 exact bytes |
| `Tests/CellBaseTests/DeviceIngressChallengeIntentTests.swift` | challenge contract-test owner | challenge tuple and replay tests |
| `Tests/CellBaseTests/DeviceIngressRegistrationStatusTests.swift` | registration contract-test owner | selector/correlation/privacy/status tests |
| `Tests/CellBaseTests/DeviceIngressRegistrationTerminationTests.swift` | registration contract-test owner | revoke/deregister state/idempotency tests |
| `Tests/CellBaseTests/Fixtures/DeviceIngressFixtureManifest.v1.json` | producer fixture owner | canonical producer fixture ledger |
| `Tests/CellBaseTests/Fixtures/README.md` | producer fixture owner | test-key and regeneration instructions |
| `Tests/Linux/DeviceIngressCompositionRootPositive.swift` | Linux composition-test owner | Resolver/Cell boundary positive composition |
| `Docs/DeviceIngressSecurityContract.md` | CellProtocol security-contract owner | authority and security rules |

### 22.2 Transport paths

| Exact path | Owner | Proposed responsibility |
|---|---|---|
| `Sources/CellDeviceIngressTransport/DeviceIngressHTTPTransport.swift` | transport owner | opaque carriers, route labels, HTTP policy only |
| `Tests/CellDeviceIngressTransportTests/DeviceIngressHTTPTransportTests.swift` | transport-test owner | exact byte preservation and HTTP policy |
| `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPChallenge.v2.json` | transport fixture owner | exact outer challenge carrier |
| `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPRegister.v4.json` | transport fixture owner | opaque register carrier |
| `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPStatus.v4.json` | transport fixture owner | opaque status carrier |
| `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPRevoke.v4.json` | transport fixture owner | opaque revoke carrier |
| `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPDeregister.v4.json` | transport fixture owner | opaque deregister carrier |
| `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPResolve.v4.json` | transport fixture owner | opaque resolve carrier |
| `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPSubmit.v4.json` | transport fixture owner | opaque submit carrier |
| `Docs/DeviceIngressHTTPTransportContract.md` | transport owner | semantic-neutrality and HTTP contract |

No Binding or CellScaffold path is in the Lane A write allowlist. Their later
adapters consume the reviewed producer contract.

## 23. Total verification plan

All tests below are planned evidence only.

### 23.1 Wire/version tests

1. Every existing v3 fixture has unchanged bytes and SHA-256.
2. No v4-only operation decodes as v3.
3. No v3 signed request is replayable as v4.
4. Every v4 type rejects unknown, missing, duplicate, and non-canonical fields.
5. Every result kind enforces its exact payload schema.
6. Manifest entries match exact file bytes, decoded bytes, byte count, role, and
   wire schema.

### 23.2 Transport neutrality tests

1. The transport target has no CellBase/Identity/Resolver dependency.
2. Arbitrary bounded inner bytes round-trip byte-for-byte.
3. Inner malformed JSON reaches the authenticated executor unchanged.
4. The transport never emits a protocol operation/schema error.
5. Each route produces only its configured unauthoritative label.
6. A route/inner-operation mismatch is rejected by the authenticated boundary.
7. No mismatch creates admission or mutation state.
8. Reordering outer JSON keys is rejected when canonical carrier bytes are
   required.
9. Base64 decode preserves exact byte arrays.

### 23.3 Authority tests

1. Exact operation/resource/capability/access tuple succeeds.
2. Status with `rw-s` fails.
3. A valid Agreement without a matching Contract/grant fails.
4. A matching Contract with wrong subject fails.
5. Wrong domain, purpose, audience, Resolver target, target owner, or validity
   interval fails.
6. Revoked Agreement/Contract fails.
7. HTTP Host or route never substitutes for signed audience/operation.

### 23.4 Status privacy and recovery tests

1. `registration_id` returns only the authenticated subject's registration.
2. Wrong-subject ID is externally indistinguishable from unknown.
3. `subject_current` recovers an active registration after local ID loss.
4. `subject_current` returns revoked state.
5. `subject_current` returns the most recent deregistered tombstone when no newer
   registration exists.
6. A later new enrollment becomes subject current.
7. Multiple-current corruption returns `indeterminate_retryable`.
8. No selector returns a list, count, or alternate IDs.
9. Status creates durable admission/audit but does not mutate registration
   generations.
10. Historical replay does not masquerade as a fresh observation.

### 23.5 Mutation correlation tests

1. Exact current tuple returns `current_exact`.
2. Exact older committed tuple returns `superseded`.
3. Entirely absent tuple returns `not_found`.
4. Partial durable mismatch returns `inconsistent_retryable`.
5. Same generation with different request hash never returns `current_exact`.
6. Same request hash with different protected-body hash never returns
   `current_exact`.
7. Expected previous generation mismatch never returns `current_exact`.
8. A concurrent later rotation deterministically supersedes the earlier commit.

### 23.6 Revoke tests

1. Active to revoked increments only revocation generation.
2. Token is removed from active delivery lookup.
3. Exact replay returns exact historical bytes with one mutation.
4. New request against revoked current state returns `already_revoked`.
5. Stale generations fail.
6. Revoke after deregister fails.
7. Fresh consent/token may reactivate revoked state through register/update.

### 23.7 Deregister tests

1. Active to deregistered erases endpoint/token material.
2. Revoked to deregistered erases retained endpoint/token material.
3. Tombstone contains no token, endpoint, secret, or recoverable ciphertext.
4. Exact replay returns exact historical bytes with one mutation.
5. New request returns `already_deregistered` without generation increment.
6. Register/update with the old ID fails.
7. A fresh enrollment requires a new ID.
8. Receipt lists exactly endpoint and token material as deleted.

### 23.8 Origin/TLS/HTTP tests

1. HTTP scheme fails.
2. Wrong host, userinfo, explicit port, query, and fragment fail.
3. Every 3xx fails without redirect following.
4. Wrong content type, content-type parameters, and compressed content fail.
5. Legacy Authorization header fails.
6. Response size is bounded before decode.
7. Platform TLS trust failure maps to the transport error.
8. Deployed TLS/no-redirect proof is collected separately; a unit test is not
   production evidence.

## 24. Explicit S1 Lane A P1/P2 disposition

### P1-A-01 — transport authority leakage

**Disposition:** `STATICALLY CORRECTED / UNREVIEWED`.

Correction is sections 5, 8, 9, and 23.2. The transport cannot depend on or call
the protocol decoder. The authenticated boundary performs all semantic checks.

### P1-A-02 — deregistration absent

**Disposition:** `STATICALLY CORRECTED / UNREVIEWED`.

Correction is sections 7, 15, 16, 18, 20, and 23.7.

### P1-A-03 — status impossible after local ID loss

**Disposition:** `STATICALLY CORRECTED / UNREVIEWED`.

Correction is the authenticated `subject_current` selector in section 13. It is
subject-bound and authority-checked and does not enumerate registrations.

### P1-A-04 — incomplete origin/audience/TLS/redirect policy

**Disposition:** `STATIC POLICY CORRECTED / DEPLOYMENT EVIDENCE MISSING`.

The exact static policy is section 17. Trust roots and deployment proof are not
invented. See S2-A-MBI-03.

### P1-A-05 — ambiguous token rotation correlation

**Disposition:** `STATICALLY CORRECTED / UNREVIEWED`.

Correction is sections 12 and 13. The server cannot assert current success from
generation alone.

### P2-A-01 — status fixture access mismatch

**Disposition:** `STATICALLY CORRECTED / CONSUMER PACKET CORRECTION PENDING`.

The exact status access vector is `r--s`; see sections 7 and 21.

### P2-A-02 — producer manifest absent

**Disposition:** `PATH AND SCHEMA CORRECTED / FIXTURE BYTES MISSING`.

The exact path/schema/inventory is section 20. Signed bytes and SHA-256 ledger
remain S2-A-MBI-02.

## 25. Explicit original MBI-01/02/03 disposition

### MBI-01 — registration status and ambiguous commit recovery

**S2 disposition:** `AUTHOR-PROPOSED STATIC CONTRACT COMPLETE /
INDEPENDENT REVIEW MISSING / SOURCE AND RUNTIME EVIDENCE MISSING`.

The static closure now includes:

- status by known registration ID;
- privacy-preserving status by authenticated current subject;
- registration generation floors;
- exact admission/request/body/previous-generation correlation;
- current, superseded, not-found, and inconsistent outcomes;
- fresh-observation versus replay semantics.

This does not claim production closure.

### MBI-02 — revoke and deregister

**S2 disposition:** `AUTHOR-PROPOSED STATIC CONTRACT COMPLETE /
INDEPENDENT REVIEW MISSING / SOURCE AND RUNTIME EVIDENCE MISSING`.

The static closure now includes:

- separate operations;
- separate capabilities;
- exact state transitions;
- separate receipts;
- endpoint/token erasure only for deregister;
- replay and new-request idempotency;
- terminal ID non-resurrection.

This does not claim production closure.

### MBI-03 — challenge framing and production authority

**S2 disposition:** `STATIC FRAMING/POLICY CORRECTED FOR A FIXED ISSUER /
ISSUER ROTATION AUTHORITY AND DEPLOYMENT EVIDENCE MISSING`.

Bound in this packet:

- challenge intent v2;
- exact request/body hash binding;
- operation tuple;
- lifetime, nonce, generation floor, replay;
- exact origin/audience projection;
- redirect/content-type/content-encoding policy.

Not bound:

- who authoritatively signs issuer rotation;
- the actual issuer rotation record bytes;
- the production trust anchor;
- deployed TLS/proxy/no-redirect proof.

These missing inputs are explicit below and are not questions to Kjetil.

## 26. OD-01 through OD-07 disposition

| Open decision | S2 disposition | Reason |
|---|---|---|
| OD-01 wire version | `RESOLVED, AUTHOR PROPOSAL` | use v4; preserve v3 bytes and semantics |
| OD-02 final operation set | `RESOLVED, AUTHOR PROPOSAL` | exactly six protected operations |
| OD-03 status selector/correlation | `RESOLVED, AUTHOR PROPOSAL` | subject-bound selector and exact mutation tuple |
| OD-04 revoke versus deregister | `RESOLVED, AUTHOR PROPOSAL` | separate capabilities, state effects, receipts |
| OD-05 issuer rotation | `GENUINE AUTHORITY INPUT OPEN` | cannot derive or invent trust authority |
| OD-06 error ownership | `RESOLVED, AUTHOR PROPOSAL` | transport, authenticated boundary, and target Cell sets separated |
| OD-07 fixture manifest | `PATH/SCHEMA/INVENTORY RESOLVED; BYTES OPEN` | signed deterministic bytes/hashes require authorized generation and review |

No unresolved row is delegated to Kjetil. Each has a technical owner and exact
required input.

## 27. Exact missing-bound-input ledger

### S2-A-MBI-01 — challenge issuer rotation authority

**Owner:** CellProtocol Identity/challenge-issuer authority owner, crossed with
the CellScaffold security/composition owner.

**Required exact artifact:**

- canonical issuer-rotation record schema and bytes;
- previous issuer identifier and public-key hash;
- new issuer identifier and public-key hash;
- monotonically increasing issuer generation;
- activation and expiry instants;
- exact domain, purpose, and audience constraints;
- revocation behavior;
- authority signature bytes;
- signature algorithm identifier;
- canonical record SHA-256;
- durable storage/reload behavior;
- positive, stale-generation, wrong-authority, wrong-audience, expired, and
  revoked test-only fixtures.

**Acceptance rule:** a higher generation is accepted only when the authenticated
Identity authority validates the exact rotation record. Until this artifact
exists, fixed-issuer operation may be tested, but rotation returns
`challengeIssuerRotationUnavailable`.

**Forbidden shortcut:** trusting a key because it arrived over HTTPS or because
its generation is numerically higher.

### S2-A-MBI-02 — deterministic signed fixture bytes and manifest hashes

**Owner:** CellProtocol producer fixture owner, crossed by independent
CellProtocol, CellScaffold, and Binding reviewers.

**Required exact artifact:**

- every file in section 20.4;
- deterministic test-only signing public/private fixture material;
- exact file byte counts;
- exact file SHA-256 values;
- decoded canonical-byte SHA-256 values;
- canonical producer manifest bytes;
- producer manifest SHA-256 pinned by each consumer;
- proof that production composition rejects the test-only keys.

**Acceptance rule:** all three runtimes consume byte-identical producer vectors;
no consumer regenerates authority-bearing expected bytes independently.

### S2-A-MBI-03 — deployed origin/TLS/proxy evidence

**Owner:** CellScaffold deployment/security owner.

**Required exact artifact:**

- deployed endpoint URL and effective authority;
- certificate-chain/hostname validation evidence;
- no-redirect evidence for all seven HTTP routes;
- reverse-proxy trust-boundary configuration;
- proof that untrusted forwarded-host headers cannot select protocol audience;
- request/response content-type and content-encoding evidence;
- evidence timestamp and environment identifier.

**Acceptance rule:** evidence must come from the deployed environment. Unit tests
or a plan are insufficient.

### S2-A-MBI-04 — callback submit ambiguity recovery

**Owner:** DeviceCallbackBridge protocol owner, then CellScaffold and Binding
consumer owners.

**Required exact artifact:**

- a subject-bound callback-result status or receipt lookup operation;
- exact resource/capability/access tuple;
- selector;
- response states;
- request/result schemas;
- replay and freshness semantics;
- fixture bytes and hashes;
- server and client state transition plan.

**Reason open:** the S1 Binding review correctly found that ambiguous
`submitTicketResult` outcomes remain under-specified. Adding an unreviewed
seventh protected operation to this registration-focused correction would
invent scope. The six-operation contract therefore does not claim to close
MBI-05.

### S2-A-MBI-05 — Identity cutover proof

**Owner:** Identity/Resolver/security owners.

**Required exact artifact:** the identity ownership, grants, Agreements,
Contracts, persistence, revocation, and restart evidence required by immutable
S0.

**Status:** `UNAUDITED / MISSING` as MBI-06. This packet does not change it.

### S2-A-MBI-06 — staging APNS/device proof

**Owner:** signing/APNS/staging/device evidence owners.

**Required exact artifact:** the APNS environment, entitlement/topic, server
credential, token lifecycle, physical-device, receipt, foreground/background,
restart, and negative evidence required by immutable S0.

**Status:** `MISSING` as MBI-07. This packet does not change it.

## 28. Cross-lane correction inputs

This packet is not a correction of Lane B or Lane C, but it supplies exact inputs
for their future separately authorized corrections.

### Lane B — CellScaffold

Lane B must later:

- replace any inner operation decode in the transport/server adapter with opaque
  byte forwarding;
- map route labels only as expected-operation metadata;
- call the authenticated CellProtocol boundary;
- preserve exact challenge/request/body bytes;
- create durable status admission/audit without registration mutation;
- implement all six operation routes including deregister;
- prove the effective authority/proxy boundary;
- register the concrete DeviceRegistration and DeviceCallbackBridge Cells and
  Resolver/Identity dependencies;
- consume the producer manifest and exact fixture hashes.

The S1 Lane B review findings remain open until Lane B receives its own
correction and review.

### Lane C — Binding

Lane C must later:

- use `r--s` for status;
- use `subject_current` when local registration ID is unavailable;
- retain the exact mutation correlation tuple before sending register/update;
- distinguish `current_exact`, `superseded`, `not_found`, and
  `inconsistent_retryable`;
- treat revoke and deregister as distinct user/state operations;
- disable redirect following and enforce the exact origin;
- consume the producer manifest and exact fixture hashes;
- retain separate local challenge lifecycle evidence;
- avoid claiming submit ambiguity closure until S2-A-MBI-04 is supplied.

The S1 Lane C review findings remain open until Lane C receives its own
correction and review.

## 29. Security and privacy abuse cases

The crossed review must try to falsify at least:

- route says status while signed request says revoke;
- transport parses inner bytes despite the dependency rule;
- a valid Agreement is treated as sufficient without a grant;
- a wrong-subject registration ID reveals existence;
- `subject_current` enumerates multiple registrations;
- multiple-current corruption chooses nondeterministically;
- status claims token rotation success from generation alone;
- request hash matches but body hash differs;
- revoke is misrepresented as privacy erasure;
- deregister retains recoverable token or endpoint material;
- an exact replay mutates twice;
- a new already-revoked/deregistered request increments generations;
- a deregistered ID is resurrected;
- HTTP Host or forwarded headers choose protocol audience;
- a redirect crosses authority;
- an untrusted higher issuer generation rotates the key;
- a test fixture key is accepted in production composition;
- a consumer regenerates expected signed bytes instead of pinning producer
  bytes.

## 30. Completion and stop gate

S2 Lane A authoring is complete only when:

- this file exists at its exact requested path;
- no other file was changed by the authoring lane;
- the target shape is reported;
- the SHA-256 is reported;
- crossed independent review has not been pre-claimed;
- no source authorization is inferred.

The next permitted action is a crossed independent review of this packet by an
agent that did not author it.

That review must report:

- exact reviewed path, line count, byte count, and SHA-256;
- P0/P1/P2 counts;
- finding-to-line citations;
- every S1 P1/P2 disposition;
- OD-01 through OD-07 disposition;
- MBI-01/02/03 disposition;
- whether the transport is truly byte-preserving and semantically neutral;
- whether authority resides exclusively at the authenticated Resolver/Cell
  boundary;
- whether status selector privacy and mutation correlation invariants close;
- whether revoke/deregister state, receipts, replay, and idempotency close;
- whether manifest/path/owner/test plans are internally consistent;
- any new exact missing-bound-input ledger.

Until that review passes and a later phase explicitly authorizes source work,
the required status is:

`S2 LANE A STATIC CORRECTION AUTHORED; CROSSED REVIEW REQUIRED; NO SOURCE AUTHORIZATION`
