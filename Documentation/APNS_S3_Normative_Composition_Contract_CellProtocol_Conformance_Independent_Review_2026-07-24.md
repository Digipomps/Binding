# APNS S3 Normative Composition Contract — CellProtocol Producer Conformance Independent Review

Status: **REVIEW-FROZEN / LANE A NO-GO / S3 NO-GO / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Review date: `2026-07-25`  
Review role: independent S3 Lane A CellProtocol producer/conformance reviewer,
distinct from the S3 contract author  
Review mode: exact-byte local static review only

Sole owned output:

`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md`

This reviewer did not author, edit, or rewrite the S3 contract. The review made
no source edit, Git/index/ref mutation, dependency resolution, build, test,
network request, portal inspection, signing, archive, device action, APNS
contact, secret access, Identity action, staging mutation, integration, or
deployment. It authorizes none of those actions or any successor phase.

## 1. Exact review gate

The owned review path was re-attested absent before creation.

### 1.1 Exact S3 target

| Property | Reproduced value |
|---|---|
| Path | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` |
| Required SHA-256 | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` |
| Actual SHA-256 | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` |
| Lines | 2403 |
| Bytes | 72649 |
| Result | **MATCH — REVIEW PERMITTED** |

The review covers exactly those bytes.

### 1.2 Exact 16-artifact lineage reproduction

All shapes and hashes below were independently reproduced from the local frozen
files before this review was written.

#### S0

| Artifact | SHA-256 | Lines | Bytes | Result |
|---|---|---:|---:|---|
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 | MATCH |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 | MATCH |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 | MATCH |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 | MATCH |

Inherited S0 remains immutable:

```text
P0/P1/P2 = 0/2/1
PLAN = NO-GO
NEXT PHASE = NO-GO
```

#### S1

| Lane | Artifact | SHA-256 | Lines | Bytes | Result |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | MATCH |
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md` | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | MATCH |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | MATCH |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md` | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | MATCH |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | MATCH |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md` | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | MATCH |

#### S2

| Lane | Artifact | SHA-256 | Lines | Bytes | Result |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_2026-07-24.md` | `1b750373b4cb98c71983b002b6a2ce1fd809086776bd64b92d3b27e386969854` | 1746 | 69053 | MATCH |
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `0f2e813f481dcc9fade979a38dbf6e2a3814d743411dfec0fe63def525ed687a` | 759 | 32502 | MATCH |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_2026-07-24.md` | `cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4` | 1127 | 52292 | MATCH |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `f12db49ca272fcbbe5d577c401c21c64b6d6156d9633e0e49fded9796a9fc1ad` | 1400 | 57603 | MATCH |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_2026-07-24.md` | `6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56` | 1112 | 52295 | MATCH |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `9a80ac8fb42103e27cfe8c3efe5681479e8c4458f2144ebb0d42c3726f6bd365` | 601 | 32361 | MATCH |

No earlier author proposal or review result is silently promoted. S3 is assessed
as a new frozen static proposal.

## 2. Review purpose and evidence rule

Purposes:

- `purpose://test.acceptance`: determine whether the S3 bytes are sufficient for
  deterministic, cross-runtime CellProtocol production and consumption.
- `purpose://access.audit.privacy`: reject any identifier, status selector,
  transport field, tombstone, or lookup that becomes authority or leaks another
  subject.
- `purpose://scaffold.operations`: preserve exact ownership and stop gates
  without opening source or operational work.

Evidence rule:

- an exact static schema can close a static design finding;
- an incomplete value domain, digest rule, state transition, identifier key, or
  size relation cannot be repaired by a future fixture implementer guessing;
- an authority descriptor, Agreement, Contract, Grant, or trust root is never
  inferred from wire possession, an ID, HTTPS, origin, route, or transport;
- document conformance is not source/runtime/production conformance;
- one P1 or missing bound input retains every material NO-GO.

## 3. Executive verdict

S3 materially improves the composition:

- the body/intent/challenge/request/response graph is acyclic;
- the signature core precedes the signature envelope;
- there are exactly six operations;
- rotation is a `register` mutation mode, not a seventh operation;
- transport is opaque and semantically neutral;
- `admissionID` and `registrationID` have versioned namespaces;
- status names the three required negative meanings separately;
- deregister has a limited endpoint/token deletion meaning and a signed
  no-resurrection tombstone;
- `MBI-PRIVACY-RETENTION-01` is honestly left to Kjetil; and
- Identity, signing, integration, device, APNS, staging, and production remain
  closed.

The Lane A contract is nevertheless not implementation-bounding. Four P1 and
two P2 defects remain:

1. result/status/error byte contracts are incomplete;
2. challenge replay identity and admitted-state replay behavior are not total;
3. the registration uniqueness/CAS key contains an undefined component;
4. the admission-readback size maxima contradict the signed-artifact encoding;
5. the fixture inventory is grouped but not path-exact; and
6. the proposed SwiftPM package boundary omits the package manifest/product/
   target edits needed by its own source paths.

Exact result:

```text
P0: 0
P1: 4
P2: 2

S3 LANE A CELLPROTOCOL CONFORMANCE: NO-GO
S3 SHARED CONTRACT: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

## 4. Acyclic construction proof

The following edges reproduce S3 lines 27–83, 271–407, 409–460, 1153–1191:

```text
OperationBodyCore bytes
  -> bodySHA256
  -> IntentCore
  -> SignedIntentArtifact
  -> intentArtifactSHA256
  -> ChallengeCore
  -> SignedChallengeArtifact
  -> challengeArtifactSHA256
  -> RequestCore
  -> SignedRequestArtifact
  -> requestArtifactSHA256
  -> ResultCore
  -> ResponseCore
  -> SignedResponseArtifact
```

Each signing subgraph is:

```text
coreBytes
  -> SHA256(coreBytes)
  -> SignatureProtectedCore
  -> signatureInput
  -> signature
  -> SignatureEnvelope
  -> SignedArtifact
```

No edge points from a core to its own signature/envelope/artifact digest or to a
later artifact. The deregister branch remains acyclic:

```text
DeregistrationTombstoneCore
  -> signed tombstone artifact
  -> DeregisterReceiptCore
  -> result digest
  -> ResponseCore
  -> signed response
```

The tombstone omits the response digest, as S3 lines 1187–1191 require.

Independent verdict:

```text
ACYCLIC CORE -> SIGNATURE ENVELOPE: SUPPORTED
P1-S2-A-01 CIRCULAR CONSTRUCTION: CLOSED FOR STATIC CONTRACT
```

## 5. Canonical byte and signature reproduction

### 5.1 CJP-1

S3 lines 217–269 bind:

- UTF-8 without BOM or insignificant whitespace;
- exact schema member order;
- rejection of unknown, missing, duplicate, or out-of-order members;
- printable ASCII protocol strings and only the stated JSON escapes;
- shortest unsigned decimal integers;
- no floats, exponents, negatives, NaN, or Infinity;
- explicit `null` for nullable fields;
- unpadded Base64url;
- 64-character lowercase hexadecimal SHA-256 fields; and
- `LP(x) = UInt32 big-endian length || exact x bytes`.

Those rules are sufficient for deterministic encoding only where the
artifact-specific field type/value/nullability rules are also complete. Finding
`P1-S3-A-01` identifies the places where they are not.

### 5.2 Signature structures and input

Reproduced exact field order:

| Object | Exact member order |
|---|---|
| `SignatureProtectedCore` | `algorithm`, `artifactKind`, `coreSHA256`, `keyID`, `schema`, `signerDescriptorSHA256` |
| `SignatureEnvelope` | `protected`, `schema`, `signature` |
| `SignedArtifact` | `core`, `schema`, `signatureEnvelope` |

Reproduced signature input:

```text
LP(UTF8("HAVEN-CELLPROTOCOL-DEVICE-INGRESS-SIGNATURE-V1"))
|| LP(signatureProtectedCoreBytes)
```

Reproduced allowed artifact kinds:

```text
intent
challenge
request
response
deregistration_tombstone
```

The signer descriptor, key ID, algorithm, and production trust remain external
authority inputs. The contract correctly does not invent them.

## 6. Core field-order reproduction

The field order below was independently transcribed from the frozen S3 bytes.
This reproduction does not cure missing types/value domains identified later.

| Core | Exact member order |
|---|---|
| `IntentCore` | `action`, `audience`, `bodySchema`, `bodySHA256`, `capability`, `clientIntentID`, `clientNonce`, `expiresAtMilliseconds`, `identityDomain`, `issuedAtMilliseconds`, `minimumIssuerGeneration`, `operation`, `purpose`, `requesterDescriptorSHA256`, `requiredAccess`, `resource`, `schema`, `statusKind` |
| `ChallengeCore` | `action`, `agreementSHA256`, `audience`, `authorityGeneration`, `bodySHA256`, `capability`, `challengeID`, `contractSHA256`, `expiresAtMilliseconds`, `grantSHA256`, `identityDomain`, `intentArtifactSHA256`, `issuedAtMilliseconds`, `issuerDescriptorSHA256`, `issuerGeneration`, `operation`, `purpose`, `requesterDescriptorSHA256`, `requiredAccess`, `resource`, `revocationGeneration`, `schema`, `serverNonce`, `statusKind`, `targetCellID`, `targetOwnerDescriptorSHA256` |
| `RequestCore` | `action`, `admissionID`, `audience`, `bodySchema`, `bodySHA256`, `capability`, `challengeArtifactSHA256`, `identityDomain`, `intentArtifactSHA256`, `operation`, `purpose`, `requesterDescriptorSHA256`, `requiredAccess`, `resource`, `schema`, `statusKind` |
| `CanonicalOperationRequest` | `body`, `request`, `schema` |
| `RegisterBodyCore` | `apnsEnvironment`, `apnsToken`, `apnsTopic`, `bundleIdentifier`, `consentArtifactSHA256`, `expectedRegistrationGeneration`, `expectedRevocationGeneration`, `mutationMode`, `registrationID`, `schema`, `tokenDeliveryEpoch`, `tokenObservationID` |
| `ResolveBodyCore` | `contentContractSHA256`, `payload`, `schema`, `ticketID`, `ticketLineageSHA256` |
| `SubmitBodyCore` | `contentContractSHA256`, `payload`, `resolveAdmissionID`, `schema`, `ticketID`, `ticketLineageSHA256` |
| `MutationCorrelationCore` | `admissionID`, `bodySHA256`, `expectedPreviousRegistrationGeneration`, `operation`, `requestArtifactSHA256`, `schema`, `tokenDeliveryEpoch`, `tokenObservationID` |
| `StatusBodyCore` | `correlation`, `minimumRegistrationGeneration`, `minimumRevocationGeneration`, `registrationID`, `schema`, `selector`, `statusKind`, `targetAdmissionID` |
| `RevokeBodyCore` | `expectedRegistrationGeneration`, `expectedRevocationGeneration`, `reasonCode`, `registrationID`, `schema` |
| `DeregisterBodyCore` | `deletionMode`, `expectedRegistrationGeneration`, `expectedRevocationGeneration`, `reasonCode`, `registrationID`, `schema` |
| `ResponseCore` | `admissionID`, `bodySHA256`, `challengeArtifactSHA256`, `committedAtMilliseconds`, `operation`, `requestArtifactSHA256`, `requesterDescriptorSHA256`, `result`, `resultSHA256`, `resultSchema`, `schema`, `serverSequence`, `targetCellID`, `targetOwnerDescriptorSHA256` |
| `RegisterReceiptCore` | `admissionID`, `bodySHA256`, `committedAtMilliseconds`, `currentRegistrationGeneration`, `disposition`, `mutationMode`, `previousRegistrationGeneration`, `registrationID`, `registrationRecordSHA256`, `revocationGeneration`, `schema`, `tokenDeliveryEpoch`, `tokenObservationID` |
| `ResolveResultCore` | `contentContractSHA256`, `disposition`, `payload`, `schema`, `ticketID`, `ticketLineageSHA256` |
| `SubmitReceiptCore` | `disposition`, `resultRecordSHA256`, `schema`, `submissionGeneration`, `submissionID`, `ticketID`, `ticketLineageSHA256` |
| `RevokeReceiptCore` | `disposition`, `previousRevocationGeneration`, `registrationGeneration`, `registrationID`, `registrationRecordSHA256`, `revocationGeneration`, `schema`, `state` |
| `DeregistrationTombstoneCore` | `admissionID`, `committedAtMilliseconds`, `registrationGeneration`, `registrationID`, `requestArtifactSHA256`, `revocationGeneration`, `schema`, `subjectDescriptorSHA256`, `targetCellID`, `targetOwnerDescriptorSHA256` |
| `DeregisterReceiptCore` | `deletedMaterialKinds`, `deletionMode`, `disposition`, `previousRevocationGeneration`, `registrationGeneration`, `registrationID`, `revocationGeneration`, `schema`, `state`, `tombstoneArtifact`, `tombstoneSHA256` |
| `StatusResultCore` | `correlationDisposition`, `correlationSHA256`, `freshUntilMilliseconds`, `observedAtMilliseconds`, `registrationGeneration`, `registrationID`, `registrationRecordSHA256`, `revocationGeneration`, `schema`, `selector`, `statusCode`, `subjectState`, `targetAdmissionResponse`, `targetAdmissionResponseSHA256`, `tombstoneSHA256` |
| `RotationJournalCore` | `admissionID`, `bodySHA256`, `challengeArtifactSHA256`, `expectedRegistrationGeneration`, `expectedRevocationGeneration`, `intentArtifactSHA256`, `journalID`, `mutationMode`, `registrationID`, `requestArtifactSHA256`, `schema`, `sendState`, `tokenDeliveryEpoch`, `tokenObservationID` |

## 7. Exact six-operation and access reproduction

S3 lines 58–77 and 462–505 contain exactly:

```text
register
resolve
submit
status
revoke
deregister
```

No `rotate` wire operation exists. Rotation is exactly:

```text
operation = register
mutationMode = token_rotation
recovery = status with exact mutation correlation
```

Reproduced access matrix:

| Operation/status kind | Resource | Action | Capability | Access |
|---|---|---|---|---|
| `register` | `cell:///DeviceRegistration` | `registerOrUpdateDevice` | `device.registration.write` | `rw-s` |
| `resolve` | `cell:///DeviceCallbackBridge` | `resolveTicket` | `device.callback.resolve` | `rw-s` |
| `submit` | `cell:///DeviceCallbackBridge` | `submitTicketResult` | `device.callback.submit` | `rw-s` |
| `status/registration` | `cell:///DeviceRegistration` | `readRegistrationStatus` | `device.registration.status` | `r--s` |
| `status/admission` | original operation target | `readAdmissionResult` | `device.ingress.admission.status` | `r--s` |
| `revoke` | `cell:///DeviceRegistration` | `revokeDevice` | `device.registration.revoke` | `rw-s` |
| `deregister` | `cell:///DeviceRegistration` | `deregisterDevice` | `device.registration.deregister` | `rw-s` |

`status/admission` recursion is explicitly forbidden. Exact operation tuple
equality and exact signed Grant equality are required. A broader admin Grant
does not substitute.

Independent verdict:

```text
EXACTLY SIX OPERATIONS: SUPPORTED
TOKEN ROTATION IS NOT A SEVENTH OPERATION: SUPPORTED
PER-OPERATION RWXS MATRIX: SUPPORTED AS STATIC CONTRACT
AGREEMENT ALONE GRANTS AUTHORITY: REJECTED
```

## 8. Identifier, CAS, and collision reproduction

### 8.1 Admission ID

Reproduced from S3 lines 614–677:

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

`"adm1_"` is 5 bytes. Unpadded Base64url of 32 bytes is 43 bytes. The exact
length is therefore:

```text
5 + 43 = 48 ASCII bytes
```

The durable uniqueness key is:

```text
(compositionVersion, targetCellID, admissionID)
```

An exact replay additionally requires byte equality of subject, tuple, intent,
challenge, request, body, and authority generations. A mismatch is a conflict
and discloses no cross-subject state.

### 8.2 Registration ID

Reproduced from S3 lines 926–983:

```text
registrationID = "reg1_" + Base64url(CSPRNG(32 bytes))
```

It is also exactly 48 ASCII bytes, issued only by the authenticated target
`DeviceRegistration` Cell. Requester-selected enrollment IDs are forbidden.

The first uniqueness key is exact:

```text
UNIQUE(targetCellID, registrationID)
```

The second key is not exact because `currentLogicalRegistration` is not defined.
That defect is `P1-S3-A-03`.

### 8.3 Mutation CAS

The request binds:

- expected registration generation;
- expected revocation generation;
- registration ID mode rule;
- mutation mode;
- consent artifact digest;
- token observation ID; and
- token delivery epoch.

The target transaction is required to compare subject, ID, generations, state,
consent, authority generations, and sealed-token read-back before committing.
The static direction is sound, but total uniqueness/current-record behavior is
not fully bound because of `P1-S3-A-03`.

## 9. Transport and authority boundary

S3 lines 79–83 and 1732–1798 freeze the correct architectural boundary:

- challenge transport input is exact signed IntentArtifact bytes;
- operation transport input is exact CanonicalOperationRequest bytes;
- outputs are exact signed ChallengeArtifact or ResponseArtifact bytes;
- transport may enforce only outer framing/security policy;
- transport never decodes CJP-1 inner bytes;
- transport never selects an operation, Cell, subject, status selector,
  Agreement, Contract, Grant, admission, registration, or result;
- transport never constructs an inner protocol error or mutates Cell state;
- the authenticated Resolver/Cell boundary performs the first inner decode and
  every authority decision.

The operation/resource/action/capability/access tuple, subject Identity/domain,
target owner, purpose, audience, Agreement, Contract, Grant, conditions,
generations, revocation, and trusted time are verified at both challenge and
use time.

The following correctly grant no authority:

- transport/route/Host/origin/TLS;
- bundle/topic;
- IDs;
- token possession;
- environment/admin/storage handles;
- unsigned manifests;
- a static compiled Agreement;
- a test key; and
- readiness.

`MBI-TRANSPORT-FRAMING-01` correctly remains a technical missing input, not a
Kjetil product decision. The static origin/TLS/no-redirect policy is explicit;
HTTP carrier bytes and deployed TLS/proxy evidence remain missing.

Independent verdict:

```text
OPAQUE SEMANTICALLY NEUTRAL TRANSPORT: SUPPORTED
FIRST OPERATION INTERPRETATION AT AUTHENTICATED RESOLVER/CELL: SUPPORTED
WIRE/TRANSPORT CREATES AGREEMENT/CONTRACT/GRANT AUTHORITY: REJECTED
P1-A-01 / P1-S2-B-01 STATIC ARCHITECTURE: CLOSED
```

## 10. Challenge state-machine review

The eight persisted states and their directed transitions were reproduced from
S3 lines 1416–1461. Expiry does not abandon an admitted operation; pending
admissions remain restart-reconcilable; only expired terminal/unused records
may compact; pressure fails closed.

Those are strong state names and transition directions. They are not yet a
total replay contract because the durable request identity and admitted-state
input behavior are incomplete. See `P1-S3-A-02`.

## 11. Status, rotation, and deregister review

### 11.1 Required negative status meanings

S3 lines 1258–1289 correctly keep these meanings disjoint:

```text
subject_current_unknown
  = no disclosable current subject state under fresh subject_current

correlation_not_found
  = exact mutation tuple absent

privacy_unknown
  = by-ID selector absent or not disclosable without existence leakage
```

No consumer may collapse them to generic `not_found`.

The taxonomy also correctly distinguishes current active, revoked,
deregistered, superseded, inconsistent, admission pending/available/not-found,
and indeterminate outcomes. `correlation_current_active` is the only outcome
that may establish an ambiguous rotation as current.

The per-status-code canonical field/value/nullability matrix is missing, so the
byte contract remains incomplete under `P1-S3-A-01`.

### 11.2 Crash-durable pre-send rotation journal

The journal contains correlation digests and IDs, but forbids raw token, token
hash, body bytes, request bytes, private keys, and callback payloads.

The required order is:

```text
persist prepared_not_sent
read back
persist send_started_ambiguous
read back
invoke transport
```

Restart uses signed status rather than reconstructing request/body bytes from
digests. `correlation_not_found` does not imply no current registration; a
separate fresh `subject_current` query is required.

This is statically coherent. Crash durability and cross-process path hardening
remain Lane C runtime evidence, not Lane A document proof.

### 11.3 Deregister

The contract correctly distinguishes:

- revoke: disable delivery, retain a reactivatable logical registration and
  audit evidence;
- deregister: terminally delete active binding plus raw/sealed token and
  endpoint material, issue a new ID on future enrollment, and retain only the
  minimal signed replay tombstone.

The tombstone excludes token, token hash, endpoint, endpoint hash, ciphertext,
nonce, authentication tag, key/provider ID, payload, participant metadata,
consent content, and Agreement/Contract content.

The term `privacy_erasure` is forbidden. SQLite/WAL/free-page/backup copies are
explicitly not claimed erased without separate proof.

The exact retention duration, legitimate purpose, later subject disclosure,
compaction, backup/restore behavior, revoke-ciphertext retention, and user
wording correctly remain:

```text
MBI-PRIVACY-RETENTION-01
OWNER: Kjetil
VERDICT: OPEN / GENUINE PRODUCT-PRIVACY DECISION
```

This review does not decide it. Deregister production availability remains
NO-GO.

## 12. Maxima reproduction and arithmetic

Reproduced exact maxima:

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

The normal bounds have enough headroom for Base64 expansion. The
admission-readback pair does not:

```text
Base64url length of a 393216-byte ResponseCore
= 393216 / 3 * 4
= 524288 bytes

minimum SignedArtifact with that core and an empty signatureEnvelope
= 9-byte prefix
 + 524288-byte core encoding
 + 81-byte middle/schema
 + 0-byte envelope value
 + 2-byte suffix
= 524380 bytes
```

`524380 > 524288` even before the mandatory non-empty signature envelope. This
is the reproducible byte contradiction in `P1-S3-A-04`.

## 13. Findings

### P0

No P0 was found in this static document. No material action occurred.

### P1

#### P1-S3-A-01 — Result, status, and authenticated-error bytes are not a complete exact contract

Locations:

- S3 lines 1011–1061;
- S3 lines 1063–1225;
- S3 lines 1227–1323;
- S3 lines 1861–1912; and
- S3 lines 2053–2066.

The response field order is explicit, but several normative inputs needed for
byte-identical independent production are missing:

- no equation defines `resultSHA256` from exact ResultCore bytes;
- no operation-to-`resultSchema` mapping table is frozen;
- `serverSequence` has no namespace, initialization, monotonicity, CAS, replay,
  or rollback rule;
- `ResolveResultCore.disposition` has no closed value set;
- `SubmitReceiptCore.disposition`, `submissionID` namespace, and submission
  generation rules are absent;
- `StatusResultCore` has no exact per-`statusCode` matrix saying which nullable
  fields must be null/non-null and their required value relationships;
- `correlationSHA256` has no exact derivation;
- `subjectState` has no closed enum;
- result field types and maxima are not complete per result schema; and
- the error section classifies ownership but defines no canonical signed
  authenticated denial/error result bytes.

The CJP-1 ordering rule cannot fill those semantic gaps. Two conforming
producers can emit different valid-looking bytes or make different
success/error decisions.

Impact:

- exact cross-runtime response/status fixtures cannot be generated;
- `P1-S2-A-02`, `OD-01`, `OD-06`, and the status portion of `MBI-01` remain
  partial;
- a consumer cannot safely distinguish missing data from a malformed response.

Required static correction before source:

- freeze every result field type, enum, nullable matrix, and relation;
- define exact result/tombstone/correlation digest equations;
- freeze server-sequence namespace and replay rules;
- freeze operation-to-result-schema mapping; and
- define one canonical signed authenticated failure/result family or explicitly
  define which failures have no application artifact and how exact replay/status
  represents them.

Verdict: **OPEN P1**.

#### P1-S3-A-02 — Challenge replay identity and admitted-state request handling are not total

Locations:

- S3 lines 593–609;
- S3 lines 649–677;
- S3 lines 1416–1534; and
- S3 lines 2100–2120.

`challengeID` and `serverNonce` have entropy rules, but the challenge ledger has
no exact durable uniqueness key. Issuance says to reject a “nonce/intent
collision” and to return stored bytes for “exact active replay” without defining
whether identity is:

- requester + `clientIntentID`;
- requester + `clientNonce`;
- intent artifact digest;
- challenge ID;
- some length-framed combination; or
- multiple unique indexes with exact collision precedence.

The transition graph also does not define operation-request behavior for every
admitted state:

- exact replay while `admitted_active_pending`;
- exact replay while `admitted_expired_pending`;
- exact replay/conflict while either terminal state;
- behavior after either compacted tombstone; and
- byte/decision equivalence for wrong-subject versus absent challenge records.

“Different request/body/subject/operation is conflict” does not state the exact
same-request tuple or response behavior in each state. Compaction requires
retaining “intent/nonce/admission uniqueness” but defines no compacted record
schema or exact retained key.

Impact:

- independent servers can allocate or replay different challenges for the same
  bytes;
- restart and collision decisions are not deterministic;
- the claimed total challenge/replay state machine and `MBI-03` remain partial.

Required static correction:

- freeze exact challenge-ledger unique keys and length framing;
- freeze exact replay equality tuple and collision precedence;
- define every accepted/rejected input for all eight states;
- define exact compacted tombstone fields; and
- add deterministic same-subject/wrong-subject, nonce, intent-ID, digest,
  pending, expired, terminal, compacted, restart, and concurrent vectors.

Verdict: **OPEN P1**.

#### P1-S3-A-03 — Registration uniqueness and current-record CAS use an undefined key component

Locations:

- S3 lines 926–983;
- S3 lines 985–1009; and
- S3 lines 2091–2110.

The contract requires:

```text
UNIQUE(targetCellID, identityDomain, requesterDescriptorSHA256, currentLogicalRegistration)
```

`currentLogicalRegistration` is never defined as a type, value, derived key,
partial-index predicate, or state transition. It is unclear whether revoked
records are current, whether a deregistration tombstone participates, how a
reactivation replaces current state, and how two concurrent enrollment
transactions calculate the same uniqueness key.

The first-ID CSPRNG namespace, wrong-subject privacy rule, expected generations,
and active-state correlation are good. They do not make the second key
implementable without inventing store semantics.

Impact:

- two implementations can admit different numbers of subject-current records;
- `subject_current` may become ambiguous after enrollment/revoke/reactivate;
- mutation correlation cannot close `MBI-01`;
- `P1-S2-A-03` remains partial.

Required static correction:

- replace the placeholder with an exact partial unique key/predicate or a
  versioned derived-key algorithm;
- define participation for active, revoked, deregistered, and historical rows;
- define enrollment/reactivation/revoke/deregister transaction ordering; and
- provide concurrent enrollment/collision/restart vectors.

Verdict: **OPEN P1**.

#### P1-S3-A-04 — Admission-readback core/artifact maxima are mathematically inconsistent

Locations:

- S3 lines 1046–1049;
- S3 lines 1823–1859; and
- S3 lines 364–378.

The exact byte reproduction in section 12 shows:

```text
393216-byte core
-> 524288-byte Base64url core value
-> at least 524380-byte SignedArtifact with empty envelope
-> more with mandatory envelope/signature
```

The stated signed-artifact maximum is only `524288`. A core allowed by its own
maximum therefore cannot be encoded inside the allowed artifact.

Impact:

- producer and consumers must choose different effective maxima;
- boundary acceptance and fixtures cannot be byte-identical;
- an admission read-back near the limit can be accepted as a core but rejected
  as its required signed artifact.

Required static correction:

- derive a compatible ResponseCore maximum from the complete wrapper/envelope
  maxima with explicit formula and test vector, or raise the signed-artifact
  maximum;
- specify whether maxima are inclusive; and
- add exact boundary `max-1`, `max`, and `max+1` fixtures for decoded and encoded
  sizes.

Verdict: **OPEN P1**.

### P2

#### P2-S3-A-01 — Producer fixture inventory remains grouped, not path-exact

Locations:

- S3 lines 1985–2004;
- S3 lines 2047–2154; and
- S3 lines 2245–2254.

The producer manifest path and manifest entry schema are explicit. The required
fixture groups are not mapped to exact producer-owned relative filenames. In
particular, there are no exact listed paths for:

- canonical positive/negative bytes for every core;
- per-operation Agreement/Contract/Grant fixtures;
- deterministic test-only signer descriptors/public/private material;
- admission-ID and registration-collision vectors;
- authenticated error/status-result vectors;
- challenge replay/compaction vectors; and
- maximum-boundary vectors.

The future manifest may list them, but a source author would currently invent
the names/inventory. The S2 fixture finding is therefore only partial.

Verdict: **OPEN P2**.

#### P2-S3-A-02 — Proposed CellProtocol paths omit the exact SwiftPM package/product/target boundary

Locations:

- S3 lines 1914–1934;
- S3 lines 1981–2004; and
- S3 lines 2047–2068.

The path plan introduces:

```text
Sources/CellDeviceIngressTransport/DeviceIngressOpaqueTransport.swift
Tests/CellDeviceIngressTransportTests/DeviceIngressOpaqueTransportTests.swift
```

but it does not name `Package.swift` as a future changed path or freeze the exact
target, product, test target, dependency direction, resource/fixture ownership,
and consumer import names. The plan also does not state whether the transport
target may import CellBase; that dependency direction matters to the
“transport cannot decode inner semantics” invariant.

Impact: the source/package boundary cannot be implemented without an unreviewed
package-graph choice.

Verdict: **OPEN P2**.

## 14. Prior Lane A finding and decision disposition

### 14.1 S1 Lane A

| Finding | Independent S3 verdict | Basis |
|---|---|---|
| `P1-A-01` transport inner decode | **CLOSED FOR STATIC ARCHITECTURE** | S3 79–83 and 1734–1763 make transport opaque and move first decode to authenticated Resolver/Cell |
| `P1-A-02` deregister absent | **PARTIAL / OWNER OPEN** | Typed operation, deletion, receipt, and minimal tombstone exist; retention/legitimate purpose remains `MBI-PRIVACY-RETENTION-01` |
| `P1-A-03` lost registration ID | **CLOSED FOR STATIC SELECTOR ARCHITECTURE** | Authenticated non-enumerating `subject_current` exists; runtime evidence absent |
| `P1-A-04` origin/audience/TLS/redirect | **CLOSED FOR STATIC SECURITY POLICY / FRAMING AND DEPLOYMENT OPEN** | Exact origin/audience/no-redirect/TLS fail-closed rules exist; `MBI-TRANSPORT-FRAMING-01` and deployed proof remain |
| `P1-A-05` token rotation correlation | **PARTIAL / OPEN** | Journal/correlation/current-active semantics exist; status bytes and subject-current uniqueness remain P1-S3-A-01/03 |
| `P2-A-01` status access mismatch | **CLOSED FOR STATIC CONTRACT** | Status is exactly `r--s`; mutations are `rw-s` |
| `P2-A-02` producer manifest | **PARTIAL / OPEN** | Manifest path/schema exist; exact inventory remains P2-S3-A-01 |

### 14.2 S2 Lane A

| Finding | Independent S3 verdict | Basis |
|---|---|---|
| `P1-S2-A-01` nonconstructible intent | **CLOSED FOR STATIC CONTRACT** | Body-first intent and forward-only artifact digests are acyclic |
| `P1-S2-A-02` incomplete admission/response bytes | **PARTIAL / OPEN** | Admission derivation/raw application response are exact; result/status/error/maxima remain P1-S3-A-01/04 |
| `P1-S2-A-03` mutation CAS/ID namespace | **PARTIAL / OPEN** | ID prefixes, entropy, expected generations, and active correlation exist; second uniqueness key is undefined |
| `P1-S2-A-04` deregister privacy policy | **TECHNICAL SHAPE CLOSED / OWNER DECISION OPEN** | Minimal tombstone and exclusions exist; `MBI-PRIVACY-RETENTION-01` remains correctly open |
| `P2-S2-A-01` fixture inventory | **PARTIAL / OPEN** | Manifest path and groups exist; exact file inventory remains P2-S3-A-01 |
| `P2-S2-A-02` MBI labels | **CLOSED** | Identity is separate; MBI-06 is Apple signing evidence; MBI-07 is integrated output |

### 14.3 OD and MBI

| Item | Independent S3 verdict |
|---|---|
| `OD-01` versioned wire | **VERSION FROZEN / CONTRACT PARTIAL** due result/error/maxima |
| `OD-02` operation set | **CLOSED FOR STATIC CONTRACT: EXACTLY SIX** |
| `OD-03` status/correlation | **PARTIAL / OPEN** due status matrix and subject-current uniqueness |
| `OD-04` revoke/deregister | **TECHNICAL SHAPE CLOSED / KJETIL PRIVACY DECISION OPEN** |
| `OD-05` issuer rotation | **CORRECTLY MISSING / AUTHORITY INPUT REQUIRED** |
| `OD-06` error ownership | **BOUNDARY SUPPORTED / CANONICAL ERROR BYTES OPEN** |
| `OD-07` producer manifest | **PARTIAL / OPEN** |
| `MBI-01` current status/rotation recovery | **PARTIAL / OPEN** |
| `MBI-02` typed revoke/deregister | **TECHNICAL SHAPE DEFINED / PRODUCTION OPEN ON PRIVACY DECISION** |
| `MBI-03` challenge/origin/issuer continuity | **PARTIAL / OPEN**; acyclic construction and static origin policy close, challenge replay keys, trust/rotation bytes, framing, and deployed proof do not |
| `MBI-PRIVACY-RETENTION-01` | **OPEN / KJETIL DECISION REQUIRED / NOT DECIDED HERE** |
| `MBI-TRANSPORT-FRAMING-01` | **OPEN TECHNICAL INPUT / NOT A KJETIL PRODUCT CHOICE** |
| `MBI-06` | **UNAUDITED / MISSING** |
| `MBI-07` | **MISSING** |

## 15. Producer/source/test/fixture/consumer ownership verdict

### Producer-owned and supported as a plan

- CJP-1 and signature structures;
- operation/body/request/response type family;
- six-operation access matrix;
- ID derivations;
- status vocabulary;
- transport opaque API;
- producer manifest path;
- proposed `Sources/CellBase/DeviceIngress/...` and
  `Tests/CellBaseTests/...` paths.

### Producer-owned but incomplete

- result/status/error exact schemas;
- challenge replay unique keys and compacted record schema;
- subject-current unique-key predicate;
- compatible admission-readback maxima;
- exact fixture filenames/inventory;
- exact SwiftPM target/product/dependency graph.

### Consumer assertions preserved

- CellScaffold must consume, never regenerate, producer bytes;
- Binding must consume, never regenerate, producer bytes;
- transport must not import or invoke an inner semantic decoder;
- Agreement/Contract/Grant authority is Resolver/Cell-owned;
- no consumer may invent a trust root, route, ID semantic, status collapse, or
  broader Grant;
- runtime and cross-runtime fixtures remain required before implementation
  conformance can be claimed.

## 16. Security and privacy boundary

Protected resources/actions:

- device registration write/status/revoke/deregister;
- callback resolve/submit;
- admission read-back;
- retained status/receipt evidence.

Requester identity path:

```text
persistent domain:device:notification-callback Identity
-> signed intent/request
-> independently verified descriptor/domain proof
-> authenticated Resolver
-> exact target Cell
-> complete Agreement + Contract/Grant + conditions
-> exact operation capability/access
```

Residual security assumptions:

- actual requester/issuer/owner descriptors and trust continuity are missing;
- actual Agreement/Contract/Grant bytes are missing;
- external rollback anchor and trusted time evidence are missing;
- no source/runtime persistence or denial tests exist;
- tombstone legitimate purpose/retention remains Kjetil-owned;
- no production Apple/APNS evidence exists.

No raw APNS token, private key, secret, unredacted callback payload, or complete
production identity material was read, displayed, or stored by this review.

## 17. Exact action and evidence gates

```text
IDENTITY CUTOVER: SEPARATE PREREQUISITE / NO-GO
MBI-06 APPLE SIGNING/PROFILE/ENTITLEMENT/ARCHIVE: UNAUDITED / MISSING
MBI-07 INTEGRATED OUTPUT: MISSING
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

No static review evidence substitutes for production signing, provider
acceptance, physical iPad delivery, callback, or integrated provenance.

## 18. Smallest successor scopes

No successor is authorized by this review. If development admin later opens
document-only correction work, the smallest Lane A scopes are:

1. exact result/status/error schema matrix and digest/sequence rules;
2. exact challenge-ledger keys, per-state replay inputs, and compacted record;
3. exact current-registration partial uniqueness/state predicate;
4. mathematically compatible nested response/artifact maxima;
5. exact fixture file inventory and SwiftPM package graph; then
6. one new independent exact-byte review by a reviewer distinct from the
   correction author.

`MBI-PRIVACY-RETENTION-01` remains a separate Kjetil decision. Identity,
MBI-06, MBI-07, source, build, network, Apple, device, APNS, staging, and
deployment remain outside every listed static scope.

## 19. Final decision

```text
S3 LANE A INDEPENDENT EXACT-BYTE REVIEW: COMPLETE
REVIEWED SHA-256: 5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40
REVIEWED SHAPE: 2403 lines / 72649 bytes

P0: 0
P1: 4
P2: 2

ACYCLIC CORE/ENVELOPE: SUPPORTED
EXACT SIX OPERATIONS: SUPPORTED
ROTATION AS REGISTER MODE: SUPPORTED
OPAQUE TRANSPORT: SUPPORTED
AGREEMENT/CONTRACT/GRANT AUTHORITY IN WIRE/TRANSPORT: REJECTED
RESULT/STATUS/ERROR BYTES: NO-GO
CHALLENGE TOTAL REPLAY: NO-GO
REGISTRATION UNIQUE/CAS: NO-GO
MAXIMA: NO-GO
FIXTURE/PACKAGE PLAN: PARTIAL / NO-GO

MBI-PRIVACY-RETENTION-01: OPEN / KJETIL DECISION REQUIRED
MBI-TRANSPORT-FRAMING-01: OPEN TECHNICAL INPUT
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO

S3 LANE A CELLPROTOCOL CONFORMANCE: NO-GO
S3 SHARED CONTRACT: NO-GO
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

The review stops after freezing and re-attesting this one owned artifact.
