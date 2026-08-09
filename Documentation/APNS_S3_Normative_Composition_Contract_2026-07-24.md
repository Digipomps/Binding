# APNS S3 Normative Composition Contract

Status: **AUTHOR-FROZEN / VERSIONED NORMATIVE STATIC CONTRACT / INDEPENDENT REVIEW REQUIRED / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Contract ID:

`APNS-DEVICE-INGRESS-NORMATIVE-COMPOSITION/1`

Artifact date: `2026-07-24`  
Authoring execution date: `2026-07-25`

Owned output:

`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md`

This is the sole output owned by the S3 author. It is a document-only,
versioned, normative composition contract. It does not edit, supersede, or
rewrite any immutable S0/S1/S2 artifact.

Normative terms `MUST`, `MUST NOT`, `SHALL`, `SHALL NOT`, `SHOULD`, and `MAY`
are binding inside this static contract. They do not authorize source work.

No author self-review receives credit. A distinct reviewer must reproduce the
exact frozen bytes, independently test every closure claim, and return an exact
P0/P1/P2 result before any successor decision.

## 1. Executive contract

This contract freezes one acyclic composition:

```text
canonical operation-body core bytes
  -> signed intent artifact
  -> signed challenge artifact
  -> signed request artifact + unchanged body core bytes
  -> durable admission + target-Cell mutation/read
  -> signed response artifact
```

Every signed artifact is constructed in one direction:

```text
core bytes
  -> SHA-256(core bytes)
  -> signature-protected bytes
  -> signature
  -> signature envelope
  -> signed artifact bytes
```

The core bytes and core digest never depend on:

- signature bytes;
- signature-envelope bytes;
- signed-artifact bytes;
- an artifact digest that is constructed later.

The six and only six wire operations are:

```text
register
resolve
submit
status
revoke
deregister
```

Token rotation is:

```text
operation = register
mutationMode = token_rotation
recovery = status with exact mutation correlation
```

It is not a seventh operation.

The transport carries opaque canonical request/response bytes. It never decodes
the operation and never grants authority. The first inner decode and every
Identity, Resolver, Agreement, Contract, Grant, capability, purpose, audience,
generation, replay, and target-Cell decision occur at the authenticated
CellProtocol boundary.

The only genuine unresolved owner/product choice in this contract is:

`MBI-PRIVACY-RETENTION-01`

It covers deregistration-tombstone retention, compaction, restore exposure, and
legitimate purpose. It requires Kjetil's explicit decision. No other item is
delegated to Kjetil.

Trust roots, authority bytes, HTTP framing, source, runtime, deployment, Apple,
and APNS evidence remain missing inputs or closed action gates. They are not
guessed.

## 2. Exact 16-artifact lineage gate

The target path was re-attested absent before this file was created. The
following 16 exact local artifacts were rehashed and reshaped on `2026-07-25`.

### 2.1 S0 chain

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

S0 remains immutable:

```text
P0/P1/P2 = 0/2/1
PLAN = NO-GO
NEXT PHASE = NO-GO
```

### 2.2 S1 chain

| Lane | Artifact | SHA-256 | Lines | Bytes | Frozen review result |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | author packet |
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md` | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | `0/5/2`, NO-GO |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | author packet |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md` | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | `0/4/1`, NO-GO |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | author packet |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md` | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | `0/3/4`, NO-GO |

### 2.3 S2 chain

| Lane | Artifact | SHA-256 | Lines | Bytes | Frozen review result |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_2026-07-24.md` | `1b750373b4cb98c71983b002b6a2ce1fd809086776bd64b92d3b27e386969854` | 1746 | 69053 | author packet |
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `0f2e813f481dcc9fade979a38dbf6e2a3814d743411dfec0fe63def525ed687a` | 759 | 32502 | `0/4/2`, NO-GO |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_2026-07-24.md` | `cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4` | 1127 | 52292 | author packet |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `f12db49ca272fcbbe5d577c401c21c64b6d6156d9633e0e49fded9796a9fc1ad` | 1400 | 57603 | `0/5/1`, NO-GO |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_2026-07-24.md` | `6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56` | 1112 | 52295 | author packet |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `9a80ac8fb42103e27cfe8c3efe5681479e8c4458f2144ebb0d42c3726f6bd365` | 601 | 32361 | `0/4/0`, NO-GO |

No prior author packet is promoted to canonical by lineage. This S3 document is
the new author proposal and remains unreviewed.

## 3. Purpose, goal, and non-goals

### Purpose A — one constructible byte contract

Goal:

- no request/challenge cycle;
- exact canonical encoding;
- exact digest and signature inputs;
- exact six-operation surface;
- one response artifact at the CellProtocol application boundary.

### Purpose B — one authority and replay contract

Goal:

- transport has no inner semantics;
- Resolver/target Cell owns authority;
- Agreement alone grants nothing;
- admission and registration identifiers have exact namespaces;
- CAS, replay, collision, and wrong-subject behavior are deterministic.

### Purpose C — one crash/recovery/privacy contract

Goal:

- challenge lifecycle is total;
- client persists correlation before send;
- ambiguous registration/token rotation is recoverable;
- status negative meanings cannot be confused;
- deregistration deletes token/binding and retains only a minimal signed
  tombstone;
- the one non-derivable retention/purpose choice is explicit.

### Non-goals

This contract does not:

- select an Identity trust root;
- create an issuer or owner;
- create Agreement, Contract, or Grant bytes;
- choose production signature algorithms or keys;
- choose HTTP JSON/binary/Base64 framing;
- authorize source, Git, build, test, network, portal, signing, device, APNS,
  Identity, staging, deployment, or integration;
- prove production readiness;
- resolve `MBI-06` or `MBI-07`.

## 4. Normative constants

| Name | Exact value |
|---|---|
| composition version | `APNS-DEVICE-INGRESS-NORMATIVE-COMPOSITION/1` |
| identity domain | `domain:device:notification-callback` |
| purpose | `purpose://access.audit.privacy/device-notification-callback` |
| audience | `haven.digipomps.org` |
| planning origin | `https://haven.digipomps.org` |
| bundle identifier | `org.digipomps.haven` |
| APNS topic | `org.digipomps.haven` |
| APNS environment literal in register body | `production` |
| digest | SHA-256, 32 raw bytes |
| digest JSON encoding | 64 lowercase hexadecimal ASCII characters |
| binary JSON encoding | unpadded Base64url |
| timestamp unit | unsigned Unix milliseconds |
| maximum clock skew | 300000 ms |
| maximum intent lifetime | 120000 ms |
| maximum challenge lifetime | 60000 ms |

The bundle, topic, origin, audience, and APNS environment are planning
bindings. They do not prove an App ID, profile, certificate, entitlement,
codesign authority, archive, server credential, APNS acceptance, or device
delivery.

## 5. Canonical JSON Profile CJP-1

Every core, protected-signature object, signature envelope, signed artifact,
operation request, result, and tombstone in this contract MUST use CJP-1.

### 5.1 Encoding

- Bytes MUST be UTF-8 without BOM.
- No leading or trailing whitespace is permitted.
- No insignificant whitespace is permitted.
- Object members MUST appear in the exact schema order listed in this contract.
- Unknown, missing, duplicate, or out-of-order members MUST fail.
- Arrays MUST preserve the schema-defined order.
- All protocol strings MUST be printable ASCII `0x20...0x7e`.
- A protocol string MUST NOT contain an unescaped control character.
- `"` and `\` MUST be encoded as `\"` and `\\`.
- Other JSON escape spellings, including `\u` alternatives for printable ASCII,
  MUST fail.
- Human-language or arbitrary payload content MUST be carried as bounded binary
  bytes and encoded as unpadded Base64url, not as an unconstrained JSON string.
- Unsigned integers MUST use shortest decimal ASCII, with no sign and no
  leading zero except the value `0`.
- Floating-point values, exponents, negative integers, NaN, and Infinity are
  forbidden.
- Booleans are lowercase `true` or `false`.
- A nullable field MUST be present and encoded exactly as `null` when absent.

### 5.2 Binary and digest encoding

Unpadded Base64url:

- alphabet: `A-Z a-z 0-9 - _`;
- no `=` padding;
- no whitespace;
- shortest canonical encoding only.

SHA-256 JSON fields:

- exactly 64 characters;
- lowercase `0-9a-f`;
- decode to exactly 32 bytes.

### 5.3 Length framing

`LP(x)` means:

```text
UInt32 big-endian byte length of x
followed by the exact bytes of x
```

No unframed string concatenation is permitted in a digest or identifier
preimage.

## 6. Acyclic signature construction

### 6.1 Core

Each artifact kind has schema-specific canonical `coreBytes`.

```text
coreSHA256Raw = SHA256(coreBytes)
coreSHA256Hex = lowercaseHex(coreSHA256Raw)
```

The core MUST NOT contain:

- its own digest;
- its signature;
- signature-envelope bytes;
- signed-artifact bytes;
- signed-artifact digest;
- any later artifact digest.

### 6.2 SignatureProtectedCore

Schema:

`cellprotocol.device-ingress.signature-protected-core.v1`

Exact member order:

1. `algorithm`
2. `artifactKind`
3. `coreSHA256`
4. `keyID`
5. `schema`
6. `signerDescriptorSHA256`

Exact JSON shape:

```json
{"algorithm":"<authority-manifest token>","artifactKind":"<enum>","coreSHA256":"<64 lowercase hex>","keyID":"<authority-manifest ID>","schema":"cellprotocol.device-ingress.signature-protected-core.v1","signerDescriptorSHA256":"<64 lowercase hex>"}
```

Allowed `artifactKind`:

- `intent`;
- `challenge`;
- `request`;
- `response`;
- `deregistration_tombstone`.

`algorithm`, `keyID`, and `signerDescriptorSHA256` MUST match independently
verified Identity/authority material. This contract does not select their
production values.

Maximum protected-core bytes: `4096`.

### 6.3 Signature input

Domain separator:

`HAVEN-CELLPROTOCOL-DEVICE-INGRESS-SIGNATURE-V1`

Exact signature input:

```text
LP(UTF8("HAVEN-CELLPROTOCOL-DEVICE-INGRESS-SIGNATURE-V1"))
|| LP(signatureProtectedCoreBytes)
```

The selected authority-manifest algorithm signs those exact bytes. No
pre-hashing, double-hashing, context addition, or algorithm substitution is
permitted unless the reviewed algorithm descriptor itself normatively requires
it and its test vector is in the producer manifest.

Maximum raw signature bytes: `1024`.

### 6.4 SignatureEnvelope

Schema:

`cellprotocol.device-ingress.signature-envelope.v1`

Exact member order:

1. `protected`
2. `schema`
3. `signature`

```json
{"protected":"<Base64url SignatureProtectedCore bytes>","schema":"cellprotocol.device-ingress.signature-envelope.v1","signature":"<Base64url signature bytes>"}
```

Maximum envelope bytes: `8192`.

### 6.5 SignedArtifact

Schema:

`cellprotocol.device-ingress.signed-artifact.v1`

Exact member order:

1. `core`
2. `schema`
3. `signatureEnvelope`

```json
{"core":"<Base64url core bytes>","schema":"cellprotocol.device-ingress.signed-artifact.v1","signatureEnvelope":"<Base64url SignatureEnvelope bytes>"}
```

Verification MUST:

1. canonical-decode the signed artifact;
2. canonical-decode the envelope;
3. canonical-decode the protected core;
4. canonical-decode the artifact-specific core;
5. recompute `SHA256(coreBytes)`;
6. byte-compare it with protected `coreSHA256`;
7. require protected `artifactKind` to match the decoded core schema;
8. resolve and verify the exact signer descriptor, key ID, and algorithm;
9. verify the exact signature input;
10. enforce domain, purpose, audience, operation, owner, Agreement, Contract,
    Grant, conditions, generation, time, and target rules at the appropriate
    authenticated boundary.

### 6.6 Signed-artifact digest

```text
artifactSHA256Raw = SHA256(exact SignedArtifact bytes)
artifactSHA256Hex = lowercaseHex(artifactSHA256Raw)
```

An artifact may bind only an artifact that already exists:

- challenge core may bind intent artifact digest;
- request core may bind intent and challenge artifact digests;
- response core may bind request and challenge artifact digests;
- no earlier artifact binds a later artifact.

## 7. Exact construction order

### 7.1 Client body preparation

The client:

1. canonical-encodes one operation body core;
2. computes its SHA-256;
3. retains exact body/request bytes only in volatile protected memory;
4. may persist only non-secret identifiers and digests required by section 18.

### 7.2 Signed intent

The client builds and signs intent core after body core exists. Intent contains
`bodySHA256` but no request digest and no challenge digest.

### 7.3 Signed challenge

The server:

1. authenticates intent signature and subject;
2. validates tuple and times;
3. resolves the exact target Cell;
4. verifies target owner, Agreement, Contract, Grant, conditions, and
   generations;
5. builds/signs challenge core binding the already-existing intent artifact.

### 7.4 Signed request

After verifying challenge, the client:

1. derives exact `admissionID`;
2. builds request core binding the existing intent/challenge artifacts and
   unchanged body digest;
3. signs request core;
4. creates canonical operation request bytes containing signed request artifact
   and unchanged body core bytes.

### 7.5 Signed response

The authenticated Resolver/Cell boundary:

1. verifies operation request and body;
2. commits admission;
3. performs exact target read/mutation;
4. builds result core;
5. builds response core binding the prior artifacts/admission/result;
6. signs response as the verified target owner;
7. commits/read-backs the exact response artifact;
8. returns the exact bytes.

No step depends on bytes constructed later.

## 8. Exact operation set and least privilege

The wire enum has exactly six values:

- `register`;
- `resolve`;
- `submit`;
- `status`;
- `revoke`;
- `deregister`.

| Wire operation | Status kind | Resource | Cell action | Capability | Access |
|---|---|---|---|---|---|
| `register` | n/a | `cell:///DeviceRegistration` | `registerOrUpdateDevice` | `device.registration.write` | `rw-s` |
| `resolve` | n/a | `cell:///DeviceCallbackBridge` | `resolveTicket` | `device.callback.resolve` | `rw-s` |
| `submit` | n/a | `cell:///DeviceCallbackBridge` | `submitTicketResult` | `device.callback.submit` | `rw-s` |
| `status` | `registration` | `cell:///DeviceRegistration` | `readRegistrationStatus` | `device.registration.status` | `r--s` |
| `status` | `admission` | original operation target | `readAdmissionResult` | `device.ingress.admission.status` | `r--s` |
| `revoke` | n/a | `cell:///DeviceRegistration` | `revokeDevice` | `device.registration.revoke` | `rw-s` |
| `deregister` | n/a | `cell:///DeviceRegistration` | `deregisterDevice` | `device.registration.deregister` | `rw-s` |

`status/admission` MUST NOT target another `status` admission. Recursive status
read-back is forbidden.

Exact equality is required:

```text
intent.operation/action/resource/capability/access
== challenge.operation/action/resource/capability/access
== request.operation/action/resource/capability/access
== operation table row
== exact signed Grant scope/access
```

No broader, alternate, or “admin” Grant substitutes.

Token rotation:

```text
operation = register
mutationMode = token_rotation
```

It is never a route, operation, capability, or access row of its own.

## 9. IntentCore

Schema:

`cellprotocol.device-ingress.intent-core.v1`

Exact member order:

1. `action`
2. `audience`
3. `bodySchema`
4. `bodySHA256`
5. `capability`
6. `clientIntentID`
7. `clientNonce`
8. `expiresAtMilliseconds`
9. `identityDomain`
10. `issuedAtMilliseconds`
11. `minimumIssuerGeneration`
12. `operation`
13. `purpose`
14. `requesterDescriptorSHA256`
15. `requiredAccess`
16. `resource`
17. `schema`
18. `statusKind`

`statusKind` is `null`, `registration`, or `admission`.

`clientIntentID`:

```text
"int1_" + Base64url(CSPRNG(32 bytes))
```

`clientNonce` is Base64url of exactly 32 CSPRNG bytes.

The subject signature-envelope signer descriptor MUST equal
`requesterDescriptorSHA256`.

Intent lifetime:

```text
0 < expiresAtMilliseconds - issuedAtMilliseconds <= 120000
```

The intent contains no request digest. That is the normative cycle break.

Maximum IntentCore bytes: `8192`.
Maximum signed intent artifact bytes: `24576`.

## 10. ChallengeCore

Schema:

`cellprotocol.device-ingress.challenge-core.v1`

Exact member order:

1. `action`
2. `agreementSHA256`
3. `audience`
4. `authorityGeneration`
5. `bodySHA256`
6. `capability`
7. `challengeID`
8. `contractSHA256`
9. `expiresAtMilliseconds`
10. `grantSHA256`
11. `identityDomain`
12. `intentArtifactSHA256`
13. `issuedAtMilliseconds`
14. `issuerDescriptorSHA256`
15. `issuerGeneration`
16. `operation`
17. `purpose`
18. `requesterDescriptorSHA256`
19. `requiredAccess`
20. `resource`
21. `revocationGeneration`
22. `schema`
23. `serverNonce`
24. `statusKind`
25. `targetCellID`
26. `targetOwnerDescriptorSHA256`

`challengeID`:

```text
"chl1_" + Base64url(CSPRNG(32 bytes))
```

`serverNonce` is Base64url of exactly 32 CSPRNG bytes.

Challenge lifetime:

```text
0 < expiresAtMilliseconds - issuedAtMilliseconds <= 60000
```

Challenge issuer signature verification uses independently supplied authority
material. HTTPS, Host, route possession, intent possession, or a numerically
higher generation is not issuer authority.

Maximum ChallengeCore bytes: `16384`.
Maximum signed challenge artifact bytes: `32768`.

## 11. AdmissionID

### 11.1 Namespace and derivation

Domain separator:

`HAVEN-DEVICE-INGRESS-ADMISSION-ID-V1`

Exact derivation:

```text
admissionDigest =
  SHA256(
    LP(UTF8("HAVEN-DEVICE-INGRESS-ADMISSION-ID-V1"))
    || LP(challengeArtifactSHA256Raw)
    || LP(requesterDescriptorSHA256Raw)
    || LP(UTF8(operation))
    || LP(bodySHA256Raw)
  )

admissionID = "adm1_" + Base64url(admissionDigest)
```

`admissionID` length is exactly `48` ASCII characters.

It is:

- deterministic;
- versioned;
- opaque;
- not a capability;
- not an Identity;
- not a trust root;
- not equivalent to `base64url(requestSHA256)`.

### 11.2 Collision and replay

The durable uniqueness key is:

```text
(compositionVersion, targetCellID, admissionID)
```

An existing admission is an exact replay only when all are byte-equal:

- authenticated subject descriptor;
- operation tuple;
- intent artifact digest;
- challenge artifact digest;
- request artifact digest;
- body digest;
- authority/Agreement/Contract/Grant generations.

Same `admissionID` with any mismatch is
`admission_id_collision_or_replay_conflict`.

Conflict behavior:

- no new admission;
- no target mutation;
- no response reconstruction;
- no cross-subject existence disclosure;
- sanitized failure only.

## 12. RequestCore and canonical operation request

### 12.1 RequestCore

Schema:

`cellprotocol.device-ingress.request-core.v1`

Exact member order:

1. `action`
2. `admissionID`
3. `audience`
4. `bodySchema`
5. `bodySHA256`
6. `capability`
7. `challengeArtifactSHA256`
8. `identityDomain`
9. `intentArtifactSHA256`
10. `operation`
11. `purpose`
12. `requesterDescriptorSHA256`
13. `requiredAccess`
14. `resource`
15. `schema`
16. `statusKind`

Maximum RequestCore bytes: `16384`.
Maximum signed request artifact bytes: `32768`.

### 12.2 CanonicalOperationRequest

Schema:

`cellprotocol.device-ingress.operation-request.v1`

Exact member order:

1. `body`
2. `request`
3. `schema`

```json
{"body":"<Base64url exact operation-body core bytes>","request":"<Base64url exact signed RequestCore artifact bytes>","schema":"cellprotocol.device-ingress.operation-request.v1"}
```

The authenticated boundary MUST recompute body digest and compare it with:

- IntentCore `bodySHA256`;
- ChallengeCore `bodySHA256`;
- RequestCore `bodySHA256`.

Any mismatch fails before admission.

Maximum canonical operation request bytes: `131072`.

## 13. Operation body cores

### 13.1 RegisterBodyCore

Schema:

`cellprotocol.device-ingress.register-body-core.v1`

Exact member order:

1. `apnsEnvironment`
2. `apnsToken`
3. `apnsTopic`
4. `bundleIdentifier`
5. `consentArtifactSHA256`
6. `expectedRegistrationGeneration`
7. `expectedRevocationGeneration`
8. `mutationMode`
9. `registrationID`
10. `schema`
11. `tokenDeliveryEpoch`
12. `tokenObservationID`

Allowed `mutationMode`:

- `enroll`;
- `update`;
- `reactivate`;
- `token_rotation`.

Rules:

| Mode | registrationID | expected registration generation | token |
|---|---|---:|---|
| `enroll` | `null` | `0` | exactly 32 raw bytes |
| `update` | existing ID | exact current | exactly 32 raw bytes |
| `reactivate` | existing revoked ID | exact current | exactly 32 raw bytes |
| `token_rotation` | existing active ID | exact current | exactly 32 raw bytes |

`expectedRevocationGeneration` MUST equal exact current state, or `0` on first
enrollment.

`tokenObservationID`:

```text
"tokobs1_" + Base64url(CSPRNG(32 bytes))
```

`tokenDeliveryEpoch` is a client-local monotonically increasing UInt64 for the
same hardened journal namespace. Neither field is authority.

`apnsToken` is Base64url of exactly 32 raw bytes.

Maximum RegisterBodyCore bytes: `4096`.

### 13.2 ResolveBodyCore

Schema:

`cellprotocol.device-ingress.resolve-body-core.v1`

Exact member order:

1. `contentContractSHA256`
2. `payload`
3. `schema`
4. `ticketID`
5. `ticketLineageSHA256`

`payload` is bounded opaque canonical content bytes encoded Base64url.

Maximum ResolveBodyCore bytes: `65536`.

### 13.3 SubmitBodyCore

Schema:

`cellprotocol.device-ingress.submit-body-core.v1`

Exact member order:

1. `contentContractSHA256`
2. `payload`
3. `resolveAdmissionID`
4. `schema`
5. `ticketID`
6. `ticketLineageSHA256`

Maximum SubmitBodyCore bytes: `65536`.

### 13.4 MutationCorrelationCore

Schema:

`cellprotocol.device-ingress.mutation-correlation-core.v1`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `expectedPreviousRegistrationGeneration`
4. `operation`
5. `requestArtifactSHA256`
6. `schema`
7. `tokenDeliveryEpoch`
8. `tokenObservationID`

`operation` is exactly `register`.

Maximum MutationCorrelationCore bytes: `4096`.

### 13.5 StatusBodyCore

Schema:

`cellprotocol.device-ingress.status-body-core.v1`

Exact member order:

1. `correlation`
2. `minimumRegistrationGeneration`
3. `minimumRevocationGeneration`
4. `registrationID`
5. `schema`
6. `selector`
7. `statusKind`
8. `targetAdmissionID`

Shapes:

| statusKind | selector | registrationID | correlation | targetAdmissionID |
|---|---|---|---|---|
| `registration` | `subject_current` | `null` | `null` or Base64url MutationCorrelationCore | `null` |
| `registration` | `registration_id` | exact `reg1_...` | `null` or Base64url MutationCorrelationCore | `null` |
| `admission` | `admission_id` | `null` | `null` | exact `adm1_...` |

Maximum StatusBodyCore bytes: `8192`.

### 13.6 RevokeBodyCore

Schema:

`cellprotocol.device-ingress.revoke-body-core.v1`

Exact member order:

1. `expectedRegistrationGeneration`
2. `expectedRevocationGeneration`
3. `reasonCode`
4. `registrationID`
5. `schema`

Allowed `reasonCode`:

- `user_disabled_notifications`;
- `token_rejected`;
- `device_replaced`;
- `security_response`;
- `owner_policy`.

Maximum RevokeBodyCore bytes: `4096`.

### 13.7 DeregisterBodyCore

Schema:

`cellprotocol.device-ingress.deregister-body-core.v1`

Exact member order:

1. `deletionMode`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `reasonCode`
5. `registrationID`
6. `schema`

`deletionMode` is exactly:

`endpoint_and_token_material`

Allowed `reasonCode`:

- `endpoint_token_erasure_requested`;
- `device_removed`;
- `owner_policy`.

The term `privacy_erasure` is forbidden because this operation does not, by
itself, prove erasure of all personal data or satisfy every privacy obligation.

Maximum DeregisterBodyCore bytes: `4096`.

## 14. RegistrationID namespace and CAS

### 14.1 Issuer ownership

Only the authenticated target `DeviceRegistration` Cell may issue a new
registration ID.

```text
registrationID = "reg1_" + Base64url(CSPRNG(32 bytes))
```

Length: exactly `48` ASCII characters.

The requester MUST NOT choose an enrollment ID.

### 14.2 Durable uniqueness

The target store MUST enforce both:

```text
UNIQUE(targetCellID, registrationID)
UNIQUE(targetCellID, identityDomain, requesterDescriptorSHA256, currentLogicalRegistration)
```

A generated collision MUST:

- commit nothing;
- reveal nothing to the requester;
- use a new 32-byte CSPRNG value;
- fail closed if allocation cannot complete.

An existing ID presented by the wrong subject is externally indistinguishable
from unknown and MUST NOT reveal timing, owner, generation, tombstone, or state.

### 14.3 Mutation-time CAS

Before register mutation, in the same serialized target transaction:

1. verify authenticated subject owns the logical registration;
2. compare exact `registrationID` mode rule;
3. compare `expectedRegistrationGeneration`;
4. compare `expectedRevocationGeneration`;
5. compare state permitted by `mutationMode`;
6. compare consent artifact and authority generations;
7. verify sealed token write/read-back;
8. commit registration state, correlation record, receipt, and exact response.

CAS mismatch creates no mutation.

Generation rules:

- successful `enroll`: registration `0 -> 1`, revocation `0`;
- successful `update`, `reactivate`, or `token_rotation`: registration `+1`;
- register modes do not decrement any generation;
- successful revoke/deregister increments revocation generation exactly once;
- status changes no registration-domain generation;
- exact replay changes no generation;
- new already-terminal idempotent request changes no generation.

### 14.4 Correlation

The registration mutation record MUST retain:

- admission ID;
- request artifact digest;
- body digest;
- token observation ID;
- token delivery epoch;
- expected and actual previous registration generation;
- committed registration generation;
- revocation generation;
- mutation mode;
- registration record digest;
- exact response artifact bytes/digest.

`current_exact` for token rotation is true only when:

```text
all correlation fields match
AND subject state = active_consented
AND correlated registration generation is current
```

A revoked or deregistered state is never current token success.

## 15. ResponseCore and exact response bytes

### 15.1 ResultCore

Each operation produces one canonical result core. Its exact schema is named in
the response.

### 15.2 ResponseCore

Schema:

`cellprotocol.device-ingress.response-core.v1`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `committedAtMilliseconds`
5. `operation`
6. `requestArtifactSHA256`
7. `requesterDescriptorSHA256`
8. `result`
9. `resultSHA256`
10. `resultSchema`
11. `schema`
12. `serverSequence`
13. `targetCellID`
14. `targetOwnerDescriptorSHA256`

`result` is Base64url of exact canonical ResultCore bytes.

The response signer MUST be the verified current target owner authorized by the
same Agreement/Contract/Grant path used for the operation.

Maximum normal ResponseCore bytes: `131072`.
Maximum admission-readback ResponseCore bytes: `393216`.
Maximum normal signed response artifact bytes: `262144`.
Maximum admission-readback signed response artifact bytes: `524288`.

### 15.3 Application-boundary response framing

The CellProtocol application response is exactly the signed ResponseCore
artifact bytes. It has no second CellProtocol response wrapper.

The transport receives and returns those bytes as one opaque value.

This does not guess HTTP framing. HTTP method/path/media type and whether the
opaque byte value is carried as binary, JSON/Base64, or another bounded carrier
remain `MBI-TRANSPORT-FRAMING-01`. Any later framing MUST preserve the bytes
exactly and MUST NOT expose inner semantics.

## 16. Result cores

### 16.1 RegisterReceiptCore

Schema:

`cellprotocol.device-ingress.register-receipt-core.v1`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `committedAtMilliseconds`
4. `currentRegistrationGeneration`
5. `disposition`
6. `mutationMode`
7. `previousRegistrationGeneration`
8. `registrationID`
9. `registrationRecordSHA256`
10. `revocationGeneration`
11. `schema`
12. `tokenDeliveryEpoch`
13. `tokenObservationID`

Allowed `disposition`:

- `enrolled`;
- `updated`;
- `reactivated`;
- `token_rotated`;
- `exact_replay`.

No token bytes or token hash appear.

### 16.2 ResolveResultCore

Schema:

`cellprotocol.device-ingress.resolve-result-core.v1`

Exact member order:

1. `contentContractSHA256`
2. `disposition`
3. `payload`
4. `schema`
5. `ticketID`
6. `ticketLineageSHA256`

### 16.3 SubmitReceiptCore

Schema:

`cellprotocol.device-ingress.submit-receipt-core.v1`

Exact member order:

1. `disposition`
2. `resultRecordSHA256`
3. `schema`
4. `submissionGeneration`
5. `submissionID`
6. `ticketID`
7. `ticketLineageSHA256`

### 16.4 RevokeReceiptCore

Schema:

`cellprotocol.device-ingress.revoke-receipt-core.v1`

Exact member order:

1. `disposition`
2. `previousRevocationGeneration`
3. `registrationGeneration`
4. `registrationID`
5. `registrationRecordSHA256`
6. `revocationGeneration`
7. `schema`
8. `state`

`state` is `revoked`.

`disposition`:

- `revoked`;
- `already_revoked`;
- `exact_replay`.

### 16.5 DeregistrationTombstoneCore

Schema:

`cellprotocol.device-ingress.deregistration-tombstone-core.v1`

Exact member order:

1. `admissionID`
2. `committedAtMilliseconds`
3. `registrationGeneration`
4. `registrationID`
5. `requestArtifactSHA256`
6. `revocationGeneration`
7. `schema`
8. `subjectDescriptorSHA256`
9. `targetCellID`
10. `targetOwnerDescriptorSHA256`

The core MUST NOT contain:

- raw token;
- token hash;
- endpoint;
- endpoint hash;
- ciphertext;
- nonce;
- authentication tag;
- key/provider identifier;
- payload;
- participant metadata;
- consent content;
- Agreement/Contract content.

The tombstone is signed with `artifactKind=deregistration_tombstone` by the
verified target owner.

It does not contain a response digest; that would introduce a cycle because the
response contains the tombstone artifact.

### 16.6 DeregisterReceiptCore

Schema:

`cellprotocol.device-ingress.deregister-receipt-core.v1`

Exact member order:

1. `deletedMaterialKinds`
2. `deletionMode`
3. `disposition`
4. `previousRevocationGeneration`
5. `registrationGeneration`
6. `registrationID`
7. `revocationGeneration`
8. `schema`
9. `state`
10. `tombstoneArtifact`
11. `tombstoneSHA256`

`deletedMaterialKinds` is exactly:

```json
["endpoint","token"]
```

`state` is `deregistered`.

`disposition`:

- `deregistered`;
- `already_deregistered`;
- `exact_replay`.

## 17. Total status contract

### 17.1 StatusResultCore

Schema:

`cellprotocol.device-ingress.status-result-core.v1`

Exact member order:

1. `correlationDisposition`
2. `correlationSHA256`
3. `freshUntilMilliseconds`
4. `observedAtMilliseconds`
5. `registrationGeneration`
6. `registrationID`
7. `registrationRecordSHA256`
8. `revocationGeneration`
9. `schema`
10. `selector`
11. `statusCode`
12. `subjectState`
13. `targetAdmissionResponse`
14. `targetAdmissionResponseSHA256`
15. `tombstoneSHA256`

Nullable fields MUST be present as `null`.

`freshUntilMilliseconds - observedAtMilliseconds` MUST be greater than zero and
at most `60000`.

### 17.2 Closed `statusCode` taxonomy

| statusCode | Exact meaning | What it does not mean |
|---|---|---|
| `subject_current_active` | fresh authenticated `subject_current` found exactly one active registration | not token-correlation success unless correlation also matches |
| `subject_current_revoked` | fresh authenticated `subject_current` found exactly one revoked registration | not active delivery |
| `subject_current_deregistered` | fresh authenticated subject lookup found the retained terminal tombstone | retention/purpose still requires MBI decision |
| `subject_current_unknown` | fresh authenticated `subject_current` found no disclosable current registration/tombstone | not derived from local absence, by-ID privacy negative, or correlation absence |
| `correlation_current_active` | exact registration mutation correlation matches the current active record | only status that proves ambiguous token rotation current |
| `correlation_superseded` | exact mutation committed but a later registration/revoke/deregister transition superseded it | not current token state |
| `correlation_not_found` | no committed mutation matches the complete correlation tuple | does not prove no current registration exists |
| `correlation_inconsistent_retryable` | partial/corrupt durable correlation evidence | not success, absence, revoke, or deregister |
| `admission_response_available` | exact prior non-status admission belongs to subject/target and stored response bytes are returned | admission ID alone grants nothing |
| `admission_pending` | exact authorized admission exists but no terminal response is durable yet | not success or failure |
| `admission_not_found` | no authorized prior admission matches the exact subject/target/ID | does not prove domain-state absence |
| `privacy_unknown` | registration/admission selector is unknown or not disclosable to this subject | deliberately does not distinguish wrong subject from absent |
| `indeterminate_retryable` | authoritative unique/current/read-back proof cannot be completed | not safe for enrollment, decline, token finalization, or erasure claim |

The three required negatives are disjoint:

```text
subject_current_unknown
  = no disclosable current subject state under fresh subject_current

correlation_not_found
  = exact mutation tuple absent

privacy_unknown
  = by-ID selector absent or not disclosable without existence leakage
```

No decoder may collapse them to generic `not_found`.

### 17.3 Correlation disposition

Allowed `correlationDisposition`:

- `not_requested`;
- `current_exact`;
- `superseded`;
- `not_found`;
- `inconsistent_retryable`.

Mapping:

- `current_exact` is valid only with `statusCode=correlation_current_active` and
  `subjectState=active_consented`;
- `not_found` maps only to `statusCode=correlation_not_found`;
- by-ID privacy negative maps only to `privacy_unknown`;
- subject absence maps only to `subject_current_unknown`.

### 17.4 Admission read-back

For `statusKind=admission`:

- the authenticated subject, original target Cell, operation, Agreement,
  Contract, Grant, and purpose/audience MUST be rechecked;
- `admissionID` is a locator, never authority;
- wrong-subject and absent are externally `privacy_unknown` or
  `admission_not_found` according to whether non-disclosure can be proven
  without an oracle;
- `targetAdmissionResponse` contains exact original signed response artifact
  bytes only for `admission_response_available`;
- the nested response digest MUST match;
- recursive status read-back is forbidden;
- exact historical response remains historical, not fresh target state.

## 18. Crash-durable client pre-send journal

### 18.1 RotationJournalCore

Schema:

`binding.device-ingress.rotation-journal-core.v1`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `expectedRegistrationGeneration`
5. `expectedRevocationGeneration`
6. `intentArtifactSHA256`
7. `journalID`
8. `mutationMode`
9. `registrationID`
10. `requestArtifactSHA256`
11. `schema`
12. `sendState`
13. `tokenDeliveryEpoch`
14. `tokenObservationID`

`journalID`:

```text
"jr1_" + Base64url(CSPRNG(32 bytes))
```

The journal MUST NOT contain:

- raw token;
- token hash;
- reversible token derivative;
- body bytes;
- request bytes;
- private key;
- unredacted callback payload.

### 18.2 Persist-before-send

Before the first network send invocation, Binding MUST:

1. build body, intent, challenge, request in volatile protected memory;
2. compute all journal fields;
3. persist `sendState=prepared_not_sent`;
4. read back and byte-compare journal fields;
5. persist `sendState=send_started_ambiguous`;
6. read back the state transition;
7. only then call transport with exact request bytes.

Crash before step 5 proves no send invocation was permitted.

Crash after step 5 is ambiguous even if the process may have died before the
actual socket write.

### 18.3 Journal states

| State | Meaning | Permitted transition |
|---|---|---|
| `prepared_not_sent` | full non-secret correlation durable; send not permitted yet | `send_started_ambiguous`, `abandoned_before_send` |
| `send_started_ambiguous` | send boundary crossed or may have been crossed | `response_verified`, `status_recovery_required` |
| `status_recovery_required` | exact response absent/ambiguous; status correlation required | `finalized_current`, `finalized_superseded`, `finalized_not_committed`, `blocked_indeterminate` |
| `response_verified` | exact response artifact verified against all fields | `finalized_current` or `finalized_superseded` according to receipt/state |
| `finalized_current` | exact observation is accepted as current active registration | terminal |
| `finalized_superseded` | attempt committed historically but is not current | terminal |
| `finalized_not_committed` | exact correlation not found; no success claim | terminal; fresh attempt requires new observation/request |
| `blocked_indeterminate` | privacy/authority/corruption/read-back ambiguity | status retry only |
| `abandoned_before_send` | no send boundary crossed | terminal; fresh callback/attempt required |

### 18.4 Recovery rules

- An in-process retry MAY resend only byte-identical volatile request bytes whose
  digests match the journal.
- After process restart, request/body bytes MUST NOT be reconstructed from
  digests.
- Restart uses `status` correlation.
- `correlation_current_active` finalizes the observation.
- `correlation_superseded` never marks the token current.
- `correlation_not_found` proves only that attempt absent; a separate fresh
  `subject_current` status decides enrollment/current truth.
- `subject_current_unknown` may open a new enrollment only while fresh and
  fully authorized.
- `privacy_unknown` and `indeterminate_retryable` remain blocked.
- Journal finalization is atomic and read back before UI/current state changes.

The same admission read-back pattern applies to ambiguous resolve/submit without
persisting unredacted payloads.

## 19. Total server challenge/replay state machine

### 19.1 Persisted states

| State | Exact meaning |
|---|---|
| `issued_active_unused` | exact intent/challenge artifacts durable, challenge active, no admission |
| `issued_expired_unused` | challenge expired without admission |
| `admitted_active_pending` | admission committed, challenge active, target terminal response pending |
| `admitted_expired_pending` | admission committed, challenge expired, target reconciliation still required |
| `admitted_active_terminal` | admission and exact terminal response durable while challenge active |
| `admitted_expired_terminal` | admission and exact terminal response durable after challenge expiry |
| `compacted_unused_tombstone` | exact challenge bytes removed after safe gate; uniqueness/expiry/issuer hashes retained |
| `compacted_admitted_tombstone` | exact challenge bytes removed; admission link and response ledger remain durable |

There is no persisted success state with only a challenge digest and no exact
challenge bytes.

### 19.2 Total transitions

```text
none
  -> issued_active_unused

issued_active_unused
  -> issued_expired_unused
  -> admitted_active_pending

admitted_active_pending
  -> admitted_expired_pending
  -> admitted_active_terminal

admitted_expired_pending
  -> admitted_expired_terminal

admitted_active_terminal
  -> admitted_expired_terminal

issued_expired_unused
  -> compacted_unused_tombstone

admitted_expired_terminal
  -> compacted_admitted_tombstone
```

No other transition is permitted.

### 19.3 Issuance

One serialized transaction:

1. validates signed intent subject/domain/tuple/time;
2. verifies Resolver target, owner, Agreement, Contract, Grant, conditions,
   generations, and issuer readiness;
3. rejects nonce/intent collision;
4. returns exact stored challenge bytes for exact active replay without signing;
5. signs only when no record exists;
6. commits exact intent/challenge artifacts and state;
7. reads back exact bytes and hashes;
8. only then releases response.

### 19.4 Consumption

Only `issued_active_unused` may be consumed.

The admission transaction atomically binds:

- challenge ID/artifact digest;
- admission ID;
- request artifact digest;
- body digest;
- subject;
- operation tuple;
- authority generations;
- state `admitted_active_pending`.

A different request/body/subject/operation is conflict, not replay.

### 19.5 Expiry while pending

Expiry prevents a new admission. It does not abandon an existing admission.

`admitted_expired_pending` MUST:

- remain restart-reconcilable;
- query the exact target idempotency record;
- commit terminal response or typed indeterminate/unavailable terminal evidence;
- never re-run a mutation whose commit is already durable;
- never compact.

This closes the S2 B `consumedActive -> expiredConsumed` contradiction.

### 19.6 Restart

Startup MUST:

- recover every non-compacted record;
- verify exact bytes/digests and unique keys;
- reconcile challenge/admission/target-response links;
- preserve pending state after expiry;
- mark the affected operation unavailable on missing/partial/corrupt evidence;
- never reconstruct or re-sign an exact response.

### 19.7 Compaction

Compaction is explicit, never pressure-triggered.

It requires:

- challenge expired;
- no pending target work;
- exact terminal response independently durable for admitted records;
- exact intent/nonce/admission uniqueness retained;
- external rollback anchor covers the durable sequence;
- one transaction writes/read-backs the compacted tombstone before deleting
  exact challenge bytes.

Normative version 1 does not delete compacted tombstones. Quota pressure fails
closed and makes issuance unavailable.

## 20. Server authority, bootstrap, and exact consumption

### 20.1 No static admission root

The following are never authority:

- HTTP route, Host, origin, TLS peer, APNS topic, bundle ID;
- admission ID, registration ID, challenge ID, intent ID;
- token or token possession;
- environment owner;
- app/scaffold administrator;
- application storage handle;
- unsigned manifest;
- static compiled Agreement;
- test key;
- readiness flag.

### 20.2 Infrastructure Cells

| Cell | Scope | Persistency | Lifecycle | Owner behavior |
|---|---|---|---|---|
| `cell:///DeviceIngressAuthorityCatalog` | `.scaffoldUnique` | `.persistant` | `nil`, no TTL | exact pre-existing owner from signed authority input; no create |
| `cell:///DeviceIngressChallengeIssuer` | `.scaffoldUnique` | `.persistant` | `nil`, no TTL | exact pre-existing issuer owner from signed authority input; no create |
| `cell:///DeviceRegistration` | `.identityUnique` | `.persistant` | persistent | Resolver-selected authenticated device subject/owner tuple |
| `cell:///DeviceCallbackBridge` | `.scaffoldUnique` | `.persistant` | persistent | exact owner from signed authority input |

For infrastructure Cells:

- `makeNewIfNotFound=true` is forbidden;
- owner refresh that creates an owner is forbidden;
- a missing Cell/owner/issuer is startup failure;
- only a concrete recovered instance is registered;
- endpoint, UUID, owner, scope, persistency, lifecycle, and instance identity are
  read back;
- no fallback instance is permitted.

### 20.3 Exact config keys

These keys name inputs but grant no authority:

- `DEVICE_INGRESS_AUTHORITY_MANIFEST_PATH`;
- `DEVICE_INGRESS_AGREEMENT_CATALOG_PATH`;
- `SQLITE_DATABASE_PATH`.

The first two paths MUST contain independently signed canonical artifacts. An
unsigned repository file or environment value is not accepted.

### 20.4 Bootstrap order

1. verify separate Identity cutover attestation;
2. verify exact source/dependency provenance;
3. verify signed authority manifest through the independent Identity trust path;
4. open pre-existing owners/issuer with no-create;
5. open exact persistent database and settings;
6. recover/register/read-back authority catalog;
7. import/verify/read-back signed Agreement/Contract/Grant catalog;
8. recover/register/read-back challenge issuer;
9. recover/verify target Cell definitions;
10. recover challenge/admission/response/registration/token/tombstone/journal
    stores and rollback anchor;
11. reconcile incomplete transactions;
12. construct authenticated operation boundary;
13. install non-authoritative transport adapter;
14. evaluate readiness independently per operation/status kind.

Restart repeats every step.

### 20.5 Challenge-time and use-time checks

Challenge issuance and operation consumption MUST both verify:

- subject Identity and domain;
- exact target Cell and current owner;
- complete Agreement;
- complete Contract/Grant;
- exact operation/resource/action/capability/access;
- purpose and audience;
- conditions;
- validity;
- authority and revocation generation;
- issuer generation;
- trusted time.

Use-time mismatch invalidates the challenge/request even if challenge-time
verification succeeded.

### 20.6 Durable admission and target transaction

Admission is committed/read back before target execution.

The selected target instance used for authority MUST be the instance used for
the operation.

The target transaction commits:

- generation CAS;
- domain read/mutation;
- result core;
- operation receipt;
- exact response artifact;
- target-owned outbox row if later external work exists.

Cross-Cell side effects occur after canonical success through idempotent outbox
delivery. If product semantics require a remote Cell result before success, the
operation remains unavailable; no fake cross-Cell atomicity is permitted.

## 21. Revoke and deregister

### 21.1 Revoke

Revoke:

- disables delivery;
- removes active token binding from delivery lookup;
- increments revocation generation once;
- retains logical registration and signed audit/receipt;
- may permit later `reactivate` with fresh consent/token and exact CAS;
- is not privacy erasure.

Any sealed-token retention after revoke must remain inaccessible to delivery and
is subject to `MBI-PRIVACY-RETENTION-01` if it contains personal data.

### 21.2 Deregister authoritative commit

Deregister is terminal for the registration ID.

The authoritative transaction MUST:

1. verify subject, target, authority, CAS, and state;
2. remove active delivery binding;
3. delete raw APNS token material;
4. delete sealed token ciphertext, nonce, tag, key reference, and shadow/retired
   token material for that registration;
5. delete endpoint material;
6. create/sign exact minimal DeregistrationTombstoneCore;
7. commit tombstone, deregister receipt, and exact response;
8. read back and prove no active/recoverable token or endpoint record remains;
9. only then release success.

A successful deregister response MUST NOT exist if recoverable token/endpoint
material remains in the authoritative store.

Existing SQLite/WAL/free-page/backup copies remain privacy-sensitive until their
reviewed storage procedure proves disposal or approved retention. Logical row
deletion alone is not physical-erasure proof.

The registration ID MUST NOT reactivate. New enrollment receives a new ID.

### 21.3 Idempotency

- exact replay returns exact stored response bytes;
- new exact-current revoke on revoked state returns `already_revoked`;
- new exact-current deregister on tombstone returns `already_deregistered`;
- already-terminal requests do not increment generations;
- revoke after deregister fails;
- register with deregistered ID fails;
- stale generations fail.

## 22. `MBI-PRIVACY-RETENTION-01`

This is the only genuine unresolved owner/product choice in this S3 contract.

Decision owner:

`Kjetil`

Decision required:

1. legitimate purpose for retaining the signed deregistration tombstone;
2. exact retention duration;
3. whether and for how long `subject_current_deregistered` may be disclosed to
   the same authenticated subject;
4. compaction/deletion behavior after duration;
5. backup/restore exposure and destruction behavior;
6. whether revoke-retained sealed ciphertext is permitted, and for how long;
7. documentation/user-facing wording for the limited endpoint/token deletion.

Mandatory invariants regardless of choice:

- no raw token, endpoint, ciphertext, key reference, or payload in tombstone;
- wrong-subject indistinguishability;
- no old-ID resurrection;
- exact replay while evidence is retained;
- no claim of broad privacy erasure;
- no production deregister route until the choice is recorded and independently
  reviewed.

Until Kjetil decides:

```text
DEREGISTER CONTRACT: STATIC SHAPE DEFINED
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE COMPACTION: DISABLED
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

## 23. Transport boundary and unresolved framing

### 23.1 Normative opaque API

Transport inputs:

- challenge acquisition: exact signed IntentArtifact bytes;
- protected operation: exact CanonicalOperationRequest bytes.

Transport outputs:

- challenge acquisition: exact signed ChallengeArtifact bytes;
- protected operation: exact signed ResponseArtifact bytes or transport error.

Transport MAY:

- enforce outer byte count;
- enforce configured origin/authority, TLS, redirect, method, media, and content
  encoding after framing is reviewed;
- carry exact bytes.

Transport MUST NOT:

- decode CJP-1 inner bytes;
- inspect schema or operation;
- map inner operation to authority;
- resolve a Cell;
- inspect subject, token, status selector, Agreement, Contract, Grant, result,
  admission ID, or registration ID;
- canonicalize or re-encode inner bytes;
- construct protocol errors from inner content;
- mutate Cell state.

### 23.2 `MBI-TRANSPORT-FRAMING-01`

This is a missing technical interface input, not a product/retention choice and
not delegated to Kjetil.

Owner:

CellProtocol transport owner crossed with CellScaffold and Binding consumers.

Required exact artifact:

- HTTPS method/path(s);
- request/response media types;
- binary versus JSON/Base64 carrier;
- exact outer fields/order if any;
- outer byte limits compatible with section 25;
- redirect policy;
- content-encoding policy;
- status/error mapping;
- server effective-authority/proxy rule;
- deterministic fixtures.

Static security rules already fixed:

- origin is `https://haven.digipomps.org`;
- audience is `haven.digipomps.org`;
- redirects are rejected;
- insecure scheme is rejected;
- platform TLS trust failures fail closed;
- no custom trust-all behavior;
- no Host/forwarded header becomes protocol authority;
- no legacy Authorization header.

Deployed TLS/proxy evidence remains missing.

## 24. Trust and authority missing inputs

This contract does not select trust roots.

The following exact evidence inputs remain required from their authority owners:

- requester domain Identity descriptors and proof path;
- challenge issuer descriptor, key ID, algorithm, generation, and owner-signed
  rotation record;
- target Cell UUID and owner descriptors;
- authority manifest signature and signer continuity;
- complete Agreement/Contract/Grant bytes;
- condition evaluation inputs;
- revocation ledger and generations;
- external rollback anchor.

While any input is absent, the affected operation is unavailable.

No higher generation, HTTPS certificate, host, environment variable, endpoint,
ID, test key, or admin role substitutes.

Identity cutover is a separate prerequisite and remains NO-GO.

## 25. Exact maxima

| Object | Maximum bytes |
|---|---:|
| SignatureProtectedCore | 4096 |
| raw signature | 1024 |
| SignatureEnvelope | 8192 |
| IntentCore | 8192 |
| signed intent artifact | 24576 |
| ChallengeCore | 16384 |
| signed challenge artifact | 32768 |
| RequestCore | 16384 |
| signed request artifact | 32768 |
| RegisterBodyCore | 4096 |
| ResolveBodyCore | 65536 |
| SubmitBodyCore | 65536 |
| StatusBodyCore | 8192 |
| RevokeBodyCore | 4096 |
| DeregisterBodyCore | 4096 |
| MutationCorrelationCore | 4096 |
| CanonicalOperationRequest | 131072 |
| normal result core | 65536 |
| normal ResponseCore | 131072 |
| normal signed response artifact | 262144 |
| admission-readback ResponseCore | 393216 |
| admission-readback signed response artifact | 524288 |
| DeregistrationTombstoneCore | 4096 |
| RotationJournalCore | 8192 |

Rules:

- limits are enforced before unbounded allocation;
- inner boundary re-enforces limits independently of transport;
- no truncation;
- no compressed inner artifact;
- outer framing must set compatible bounded limits;
- overflow or oversize fails closed.

## 26. Error ownership

### 26.1 Transport errors

Only outer/framing failures:

- malformed outer carrier;
- outer size;
- method/path/media/encoding;
- insecure scheme/origin/authority;
- redirect;
- TLS trust;
- HTTP status;
- timeout/disconnect.

### 26.2 Canonical/signature errors

- noncanonical JSON;
- schema/member/order/encoding;
- digest mismatch;
- signature-protected mismatch;
- signer descriptor/key/algorithm mismatch;
- invalid signature;
- artifact kind mismatch;
- size.

### 26.3 Authenticated protocol errors

- operation tuple mismatch;
- route-label mismatch if later framing supplies one;
- intent/challenge/request binding mismatch;
- Identity/domain/purpose/audience mismatch;
- Resolver target/owner mismatch;
- Agreement/Contract/Grant missing/invalid/revoked/expired;
- condition denied;
- generation rollback;
- admission collision/replay conflict;
- trusted time unavailable.

### 26.4 Target Cell errors

- registration/admission privacy unknown;
- CAS mismatch;
- invalid mode/state;
- registration ID reuse;
- multiple current records;
- correlation inconsistent;
- token seal/read-back unavailable;
- revoke/deregister terminal conflict;
- exact response unavailable.

Transport never classifies an inner error.

## 27. Lane ownership and producer/consumer assertions

### Lane A — CellProtocol producer

MUST own:

- CJP-1;
- signature structures;
- all core/result schemas;
- operation table;
- ID derivations;
- error taxonomy;
- central fixture manifest and exact bytes;
- transport opaque API contract.

MUST NOT own:

- production Identity root;
- server owner/issuer bytes;
- Binding journal storage implementation;
- deployment/TLS proof.

### Lane B — CellScaffold server

MUST consume exact reviewed Lane A bytes and:

- implement opaque transport adapter;
- implement authenticated boundary;
- recover/register Resolver Cells with no-create;
- provision signed Agreement/Contract/Grant catalog fail-closed;
- implement total challenge/admission/response stores;
- implement ID uniqueness/CAS/status taxonomy;
- seal tokens;
- implement deregister deletion/tombstone subject to privacy MBI;
- provide restart/read-back/rollback evidence.

MUST NOT regenerate producer fixtures or invent schemas/trust.

### Lane C — Binding client

MUST consume exact reviewed producer bytes and:

- build acyclic body/intent/challenge/request;
- verify exact responses;
- persist RotationJournalCore before send;
- map exact status taxonomy without collapsing negatives;
- retain response only under exact Storage/content policy;
- keep raw token/request/body bytes volatile;
- remain fail-closed on unknown/indeterminate/authority gaps.

MUST NOT impose v3 admission ID or invent server routes/trust.

### Identity/authority owner

Supplies actual trusted descriptors, manifests, rotation records,
Agreement/Contract/Grant bytes, revocation, and cutover evidence. This is
separate from A/B/C source ownership.

### Development admin

Only after every lane and prerequisite is green, owns final collision bytes,
dependency lock, integrated commit/tree/diff, and MBI-07 artifact.

### Kjetil

Owns only `MBI-PRIVACY-RETENTION-01`.

## 28. Proposed future path plan

This is a document-only allowlist proposal. No path is authorized for editing.

### 28.1 CellProtocol

```text
Sources/CellBase/DeviceIngress/DeviceIngressCanonicalJSON.swift
Sources/CellBase/DeviceIngress/DeviceIngressSignatureEnvelope.swift
Sources/CellBase/DeviceIngress/DeviceIngressCompositionCore.swift
Sources/CellBase/DeviceIngress/DeviceIngressIdentifiers.swift
Sources/CellBase/DeviceIngress/DeviceIngressOperationBodies.swift
Sources/CellBase/DeviceIngress/DeviceIngressStatusContract.swift
Sources/CellBase/DeviceIngress/DeviceIngressRegistrationLifecycle.swift
Sources/CellBase/DeviceIngress/DeviceIngressAuthenticatedBoundary.swift
Sources/CellDeviceIngressTransport/DeviceIngressOpaqueTransport.swift
Tests/CellBaseTests/DeviceIngressCanonicalCompositionTests.swift
Tests/CellBaseTests/DeviceIngressIdentifierCASTests.swift
Tests/CellBaseTests/DeviceIngressStatusTaxonomyTests.swift
Tests/CellBaseTests/DeviceIngressRegistrationLifecycleTests.swift
Tests/CellDeviceIngressTransportTests/DeviceIngressOpaqueTransportTests.swift
Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV1/manifest.json
Docs/DeviceIngressNormativeCompositionV1.md
```

### 28.2 CellScaffold

```text
Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityManifest.swift
Sources/App/Cells/DeviceIngress/DeviceIngressAgreementCatalog.swift
Sources/App/Cells/DeviceIngress/DeviceIngressResolverRegistration.swift
Sources/App/Cells/DeviceIngress/DeviceIngressChallengeStateMachine.swift
Sources/App/Cells/DeviceIngress/DeviceIngressAdmissionStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressRegistrationStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressTokenStore.swift
Sources/App/Cells/DeviceIngress/DeviceIngressStatusService.swift
Sources/App/Cells/DeviceIngress/DeviceIngressDeregisterService.swift
Sources/App/Cells/DeviceIngress/DeviceIngressCompositionCoordinator.swift
Tests/AppTests/DeviceIngressNormativeCompositionConsumerTests.swift
Tests/AppTests/DeviceIngressChallengeTotalStateTests.swift
Tests/AppTests/DeviceIngressAdmissionRestartTests.swift
Tests/AppTests/DeviceIngressRegistrationCASTests.swift
Tests/AppTests/DeviceIngressStatusTaxonomyTests.swift
Tests/AppTests/DeviceIngressDeregisterDeletionTests.swift
Tests/AppTests/DeviceIngressAuthorityProvisioningTests.swift
Documentation/Operations/DeviceIngress_Normative_Composition_Runbook.md
```

### 28.3 Binding

```text
Binding/DeviceIngress/DeviceIngressCanonicalComposition.swift
Binding/DeviceIngress/DeviceIngressRotationJournal.swift
Binding/DeviceIngress/DeviceIngressStatusMapping.swift
Binding/DeviceIngress/DeviceIngressRecoveryCoordinator.swift
Binding/DeviceIngress/DeviceIngressResponseVerifier.swift
BindingTests/DeviceIngressCanonicalCompositionConsumerTests.swift
BindingTests/DeviceIngressRotationJournalCrashTests.swift
BindingTests/DeviceIngressStatusMappingTests.swift
BindingTests/DeviceIngressAdmissionReadBackTests.swift
BindingTests/DeviceIngressPrivacyTests.swift
Documentation/DeviceIngress_Client_Recovery_V1.md
```

Integration/collision paths remain development-admin-owned and excluded.

## 29. Proposed fixture manifest

Producer path:

`Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV1/manifest.json`

Schema:

`cellprotocol.device-ingress.composition-fixture-manifest.v1`

Each entry MUST contain:

- byte count;
- exact relative path;
- role;
- file SHA-256;
- decoded/core SHA-256 where applicable;
- schema;
- expected decision;
- test-key policy.

Entries are lexicographically sorted by path. No timestamp is included.

Required groups:

### Canonical/signature

- every core type canonical positive;
- out-of-order/duplicate/unknown/missing fields;
- Base64url padding/noncanonical cases;
- digest mismatch;
- protected algorithm/key/signer substitution;
- signature/artifact-kind substitution;
- test-only signer material and production rejection.

### Acyclic construction

- body → intent → challenge → request → response positive;
- intent containing request digest negative;
- core depending on envelope/signature negative;
- challenge binding wrong intent;
- request binding wrong challenge/body;
- response binding wrong request.

### Operations/access

- all six operation tuples;
- status registration/admission submodes;
- status `r--s`;
- all mutation operations `rw-s`;
- every substitution negative;
- token rotation only as register mode.

### IDs/CAS

- admission derivation vector;
- registration allocation namespace;
- cross-version/cross-operation substitution;
- exact replay;
- admission collision conflict;
- wrong-subject privacy equivalence;
- enroll/update/reactivate/token-rotation CAS;
- concurrent updates;
- tombstone ID reuse rejection.

### Challenge

- all persisted states/transitions;
- expiry while pending;
- crash before/after issuance/admission/target/response;
- restart reconciliation;
- exact replay/no re-sign;
- compaction gates;
- quota fail-closed.

### Status

- every status code;
- explicit
  `subject_current_unknown`/`correlation_not_found`/`privacy_unknown`;
- fresh/historical;
- active exact token correlation;
- revoked/deregistered not token-current;
- admission response available/pending/not-found/privacy;
- recursive status rejection.

### Journal

- persist/read-back before send;
- crash at every transition;
- token observation/epoch retained;
- no raw token/hash/body/request bytes;
- restart status recovery;
- correlation not-found plus separate subject-current;
- cross-process lock/race/path hardening.

### Deregister

- active/revoked to tombstone;
- token/endpoint deletion and read-back;
- no recoverable ciphertext;
- exact replay/already deregistered;
- old-ID rejection;
- wrong-subject privacy;
- `MBI-PRIVACY-RETENTION-01` absent keeps production route unavailable.

Consumers MUST use exact producer fixture bytes. They MUST NOT regenerate signed
expected artifacts independently.

## 30. Required test/evidence plan

No test is run or claimed here.

### 30.1 Producer

- canonical byte equality and hashes;
- acyclic graph;
- signature input;
- all schema and limit negatives;
- operation/access matrix;
- ID/CAS/replay;
- status taxonomy;
- deregister tombstone.

### 30.2 Server

- no transport inner decode;
- full challenge- and use-time authorization;
- no static/no-create owner path;
- Agreement/Contract/Grant import/read-back;
- total challenge state across crash/restart/expiry;
- admission/response exact replay;
- status current/correlation/admission;
- token sealed lifecycle;
- deregister deletion;
- SQLite/WAL/backup privacy evidence;
- rollback anchor and trusted time.

### 30.3 Client

- exact producer byte consumption;
- pre-send journal persistence;
- crash/race/process restart;
- no token/request/body retention;
- exact negative status mapping;
- admission read-back;
- response retention policy;
- issuer rollback;
- no local/static trust fallback.

### 30.4 Cross-runtime

- one producer manifest;
- byte-identical artifacts;
- same digest/ID decisions;
- same allowed/denied authority decisions;
- same state transitions;
- test keys rejected in production composition.

## 31. Prior P1/P2 disposition ledger

Every row is an S3 author disposition only. Independent review decides whether
it is actually closed.

### 31.1 S1 Lane A

| Finding | S3 author disposition |
|---|---|
| P1-A-01 transport inner decode | proposed closed by opaque transport and authenticated first decode |
| P1-A-02 deregister absent | operation/receipt/deletion/tombstone shape defined; production remains blocked on privacy retention MBI |
| P1-A-03 lost registration ID | proposed closed by authenticated `subject_current` |
| P1-A-04 origin/audience/TLS/redirect | static policy proposed closed; framing and deployed proof missing |
| P1-A-05 token correlation | proposed closed by mutation-time CAS, IDs, journal, and exact status correlation |
| P2-A-01 status access | proposed closed; status is exactly `r--s` |
| P2-A-02 producer manifest | path/schema/plan proposed closed; generated bytes/hashes missing |

### 31.2 S1 Lane B

| Finding | S3 author disposition |
|---|---|
| P1-B-01 blanket `rw-s` | proposed closed by exact operation/action/access table |
| P1-B-02 status skips admission | proposed closed by durable status admission/replay |
| P1-B-03 Resolver bootstrap | static tuple/order/no-create/catalog path proposed closed; authority bytes missing |
| P1-B-04 challenge digest/bytes | proposed closed by exact bytes and total state machine |
| P2-B-01 token tests | proposed closed as path/fixture/test plan; runtime key/storage proof missing |

### 31.3 S1 Lane C

| Finding | S3 author disposition |
|---|---|
| P1-C-01 local absence means not registered | proposed closed by exact status negatives |
| P1-C-02 ambiguous recovery | proposed closed for registration and generic admission read-back; runtime proof missing |
| P1-C-03 challenge intent/issuer continuity | construction cycle proposed closed; trust/rotation bytes missing |
| P2-C-01 resolve/submit state | proposed closed by exact admission read-back and existing client state ownership |
| P2-C-02 Apple no-touch | preserved; no Apple path opened |
| P2-C-03 status proves Apple/origin | proposed closed by evidence separation |
| P2-C-04 blanket access test | proposed closed by operation-derived matrix |

### 31.4 S2 Lane A review

| Finding | S3 author disposition |
|---|---|
| P1-S2-A-01 nonconstructible intent | proposed closed by body-first intent without request digest |
| P1-S2-A-02 incomplete bytes/admission/response | proposed closed by CJP-1, signature envelope, exact cores, IDs, raw application response |
| P1-S2-A-03 CAS/ID namespace | proposed closed by sections 11 and 14 |
| P1-S2-A-04 privacy policy | technical shape closed; only MBI-PRIVACY-RETENTION-01 remains owner-open |
| P2-S2-A-01 fixture inventory | proposed closed as complete plan; bytes not generated |
| P2-S2-A-02 MBI labels | corrected: Identity separate; MBI-06 signing; MBI-07 integration |

### 31.5 S2 Lane B review

| Finding | S3 author disposition |
|---|---|
| P1-S2-B-01 pre-boundary inspection | proposed closed by opaque API |
| P1-S2-B-02 stale v3/five-op server | proposed closed by one six-operation v1 composition |
| P1-S2-B-03 Agreement/Grant provisioning | static path/use-time contract proposed closed; actual authority bytes missing |
| P1-S2-B-04 non-total challenge | proposed closed by eight-state total machine |
| P1-S2-B-05 token/deregister deletion | proposed closed technically; retention/purpose MBI remains |
| P2-S2-B-01 fixture consumption | proposed closed by producer/consumer manifest assertions |

### 31.6 S2 Lane C review

| Finding | S3 author disposition |
|---|---|
| P1-S2-C-01 stale/nonconstructible challenge | proposed closed by versioned acyclic order |
| P1-S2-C-02 missing pre-send correlation | proposed closed by RotationJournalCore |
| P1-S2-C-03 v3 admission ID promoted | proposed closed by `adm1_` derivation |
| P1-S2-C-04 negative status ambiguity | proposed closed by disjoint total taxonomy |

No prior finding is source/runtime closed by this document.

## 32. Reviewer gates

The independent S3 reviewer MUST:

1. re-attest this exact path, SHA-256, line count, and byte count;
2. re-attest all 16 input hashes/shapes;
3. confirm no self-review credit;
4. prove the construction graph is acyclic;
5. reproduce every field order and maximum;
6. reproduce signature/digest/LP inputs;
7. reproduce admission ID length and derivation;
8. adversarially test registration ID collision/privacy/CAS rules;
9. verify exactly six operations and no token-rotation operation;
10. verify status `r--s` and mutation `rw-s`;
11. verify transport cannot decode inner semantics;
12. verify Resolver/Cell/Agreement/Contract/Grant is the only authority path;
13. verify no static root/no-create bootstrap;
14. prove the challenge state machine is total under expiry/crash/restart;
15. prove pre-send journal fields exist before send and contain no token/body;
16. prove status negatives are disjoint;
17. test admission read-back privacy and recursion prohibition;
18. test deregister acyclicity, deletion, tombstone minimality, and idempotency;
19. verify `MBI-PRIVACY-RETENTION-01` is the only Kjetil choice;
20. verify trust roots and HTTP framing are not guessed;
21. adjudicate every prior P1/P2 row;
22. return exact P0/P1/P2;
23. preserve all action/evidence NO-GOs.

Required review result fields:

```text
reviewed path
reviewed SHA-256
lines
bytes
P0/P1/P2
finding line citations
prior-finding closure table
MBI-PRIVACY-RETENTION-01 verdict
trust/framing MBI verdict
MBI-06/07 verdict
PLAN/NEXT/SOURCE/PRODUCTION verdict
```

## 33. Preserved action and evidence gates

Identity cutover:

`SEPARATE PREREQUISITE / NO-GO`

`MBI-06`:

```text
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING
```

`MBI-07`:

```text
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/artifact manifest = MISSING
```

Action gates:

```text
SOURCE: CLOSED / NO-GO
GIT: CLOSED / NO-GO
DEPENDENCY RESOLUTION: CLOSED / NO-GO
BUILD: CLOSED / NO-GO
TEST: CLOSED / NO-GO
NETWORK: CLOSED / NO-GO
PORTAL: CLOSED / NO-GO
SIGNING: CLOSED / NO-GO
DEVICE: CLOSED / NO-GO
APNS: CLOSED / NO-GO
SECRETS: CLOSED / NO-GO
IDENTITY ACTION: CLOSED / NO-GO
STAGING: CLOSED / NO-GO
DEPLOYMENT: CLOSED / NO-GO
INTEGRATION: CLOSED / NO-GO
PRODUCTION: CLOSED / NO-GO
```

One evidence class never substitutes for another.

## 34. Final author freeze

Author claims:

- one versioned normative contract is defined;
- byte/signature construction is acyclic;
- six operations are exact;
- token rotation is not a seventh operation;
- transport is opaque;
- admission/registration IDs and CAS are exact;
- authority provisioning is fail-closed;
- challenge, journal, status, and deregistration states are total as a static
  proposal;
- the sole owner/product choice is explicit;
- no trust root or HTTP framing is guessed;
- no source or production action is authorized.

These claims have no independent-review credit.

Final author status:

```text
S3 NORMATIVE COMPOSITION CONTRACT: AUTHOR-FROZEN
INDEPENDENT EXACT-BYTE REVIEW REQUIRED: YES
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-PRIVACY-RETENTION-01: KJETIL DECISION REQUIRED
MBI-TRANSPORT-FRAMING-01: TECHNICAL INPUT MISSING
TRUST/AUTHORITY BYTES: MISSING
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PRODUCTION: NO-GO
```

The only permissible successor is an independent exact-byte static review of
this frozen file by a reviewer distinct from the author. No other action is
opened.
