# APNS S6 Formal Proof Packet A — Response and Maxima

Status: **AUTHOR-FROZEN / PACKET A PARTIAL / RC1 STATIC CONTRACT CLOSED / RC5 CORE MAXIMA CLOSED / SIGNED MAXIMA FORMAL_NO_GO / S6 INTEGRATION NO-GO / SOURCE NO-GO / MATERIAL NO-GO / PRODUCTION NO-GO**

Date: 2026-07-25 (Europe/Podgorica)

Scope: one static, document-only proof packet for S5 root causes RC1 and RC5.
This is not an independent review, an S6 integrator, source authorization, or
production proof.

No source, Git, dependency resolution, build, test, network, portal, signing,
device, APNS, secret, Identity, staging, deployment, integration, or material
action was performed.

## 1. Exact immutable inputs

### 1.1 S5 contract

| Artifact | SHA-256 | Lines | Bytes | Input verdict |
|---|---|---:|---:|---|
| `Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md` | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554 | 93787 | terminal NO-GO |

### 1.2 Three terminal S5 reviews

| Lane | Artifact | SHA-256 | Lines | Bytes | Input verdict |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639` | 1038 | 36228 | terminal NO-GO |
| B | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `0c98b68d5fdd847289e026173e376ac66dc33f70c7e9d8ebcf22e84573a1c601` | 859 | 36035 | terminal NO-GO |
| C | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `36ff7ffc838f15abf99bf281c0a0f1ee584a1423d70bf26bdac3a38b2e3ebbc2` | 981 | 40219 | terminal NO-GO |

The output path for this packet was absent before authoring. None of the four
inputs was rewritten.

## 2. Scope boundary and precedence

If independently accepted by a future integrator, this packet would replace
only:

- S5 RC1 expectation/outcome clauses that conflict with sections 4–7 here;
- the five undefined non-status v3 success-result schemas; and
- S5 RC5 response/maxima clauses that conflict with sections 8–13 here.

It does not modify or claim closure for:

- RC2 U1...U4 challenge replay, expiry, terminal state, or compaction;
- RC3 authority/catalog/binding/consent;
- RC4 current-subject head/CAS or privacy retention;
- RC6 legacy discovery/inventory/disposal;
- RC7 journal/store/lock/delivery;
- RC8 vault/custody/copy/rollback/hardware continuity;
- transport framing;
- Identity cutover;
- Apple signing/profile/entitlements;
- integrated source/output evidence; or
- any material or production gate.

S5 positive invariants remain:

```text
wire operations = register, resolve, submit, status, revoke, deregister
status access = r--s
mutation access = rw-s
token rotation = register + mutationMode=token_rotation
transport = opaque, byte-preserving, semantically neutral, non-authoritative
token = opaque 1...4096 raw bytes as a HAVEN allocation bound only
raw token/token hash leakage = forbidden
server authoritative deregister commit precedes local erase
bundle/topic = org.digipomps.haven
origin = https://haven.digipomps.org
environment = production
```

RC2 is preserved byte-for-byte. This packet introduces no replay index, state,
compaction, sequence, or retention change.

## 3. Shared exact encoding rules

This packet uses S5 CJP-1 and its non-escaping scalar profile:

```text
DigestHex       = exactly 64 lowercase hexadecimal ASCII
DescriptorDigest = DigestHex
UInt64          = 0...18446744073709551615, shortest decimal
PositiveUInt64  = 1...18446744073709551615, shortest decimal
TimestampMilliseconds = UInt64 Unix milliseconds
TargetCellID    = PathTokenASCII, 1...128
TicketID        = TokenASCII, 1...128
AlgorithmToken  = TokenASCII, 1...64
KeyID           = TokenASCII, 1...128
prefixed ID     = exact prefix plus 43 unpadded Base64url characters
```

Every object:

- has the exact stated member order;
- has every member exactly once;
- rejects missing, extra, duplicate, reordered, or alternatively escaped
  members;
- uses shortest decimal integers;
- uses unpadded canonical Base64url;
- rejects invalid UTF-8 and strings outside their stated alphabet; and
- is hashed only after exact canonical encoding.

Length functions:

```text
B64(n) =
  4 * floor(n / 3)                  if n mod 3 = 0
  4 * floor(n / 3) + 2              if n mod 3 = 1
  4 * floor(n / 3) + 3              if n mod 3 = 2

StringMember(name,n) = len(name) + 5 + n
UIntMember(name,d)   = len(name) + 3 + d
NullMember(name)     = len(name) + 7
ArrayMember(name,n)  = len(name) + 3 + n

Object(members) =
  2 + max(0, memberCount - 1) + sum(member contribution)
```

All length arithmetic is checked before allocation. An allocation ceiling is
not called a semantically reachable accepted maximum.

## 4. Acyclic two-phase ResponseExpectation union

### 4.1 Construction DAG

There are two local expectation phases:

```text
body
-> signed intent
-> ChallengeOutcomeExpectationCore
-> ResponseExpectationUnionCore(kind=challenge_exchange)
-> stable-store commit/read-back
-> challenge send
-> exact challenge or pre-challenge authenticated error

verified challenge
-> signed request and deterministic admission ID
-> OperationOutcomeExpectationCore
-> ResponseExpectationUnionCore(kind=operation_exchange)
-> stable-store commit/read-back
-> operation send
-> success, authenticated error, or terminal evidence
```

An expectation contains no:

- digest of itself;
- later outcome digest;
- later response digest;
- future challenge digest in the challenge phase;
- future request/admission digest in the challenge phase;
- successor vault/continuity digest; or
- journal root that contains the expectation.

The operation expectation may bind the already committed challenge expectation
digest. That edge points only backwards.

Stable-store, vault, journal, rollback, and hardware integration remain RC7/RC8
work and are not invented here. Until a proven store exists, send readiness is
UNAVAILABLE.

### 4.2 ResponseExpectationUnionCore v1

Schema:

`binding.device-ingress.response-expectation-union-core.v1`

Exact member order:

1. `expectationKind`
2. `expectationPayload`
3. `expectationPayloadSHA256`
4. `expectationPayloadSchema`
5. `schema`

Types:

- `expectationKind`: exactly `challenge_exchange|operation_exchange`;
- `expectationPayload`: Base64url exact matching expectation-core bytes;
- `expectationPayloadSHA256`: digest of exact decoded payload bytes;
- `expectationPayloadSchema`: exact schema selected by `expectationKind`;
- `schema`: exact literal above.

Mapping:

| expectationKind | payload schema |
|---|---|
| `challenge_exchange` | `binding.device-ingress.challenge-outcome-expectation-core.v1` |
| `operation_exchange` | `binding.device-ingress.operation-outcome-expectation-core.v1` |

The local expectation digest is computed only after the union core exists:

```text
expectationSHA256 =
  lowercaseHex(SHA256(exact ResponseExpectationUnionCore bytes))
```

No field inside the union contains `expectationSHA256`.

### 4.3 Expectation ID

```text
expectationID = "exp1_" + Base64url(CSPRNG(32 bytes))
```

It is exactly 48 ASCII bytes and unique in the local stable-store namespace.
It is a correlation identifier, never authority.

## 5. Challenge exchange expectation and outcome

### 5.1 ChallengeOutcomeExpectationCore v1

Schema:

`binding.device-ingress.challenge-outcome-expectation-core.v1`

Exact member order:

1. `authorityCatalogSHA256`
2. `bodySHA256`
3. `buildProvenanceSHA256`
4. `expectationID`
5. `identityDomain`
6. `intentArtifactSHA256`
7. `issuerAlgorithm`
8. `issuerDescriptorSHA256`
9. `issuerGeneration`
10. `issuerKeyID`
11. `operation`
12. `purpose`
13. `requesterDescriptorSHA256`
14. `requiredAccess`
15. `resource`
16. `schema`
17. `statusKind`
18. `validUntilMilliseconds`

Types:

- all digest fields: `DigestHex`;
- `expectationID`: exact 48-byte ID;
- `identityDomain`, `purpose`, `resource`: exact already-authorized tuple
  literals;
- issuer algorithm/key/descriptor/generation: exact historical issuer
  reference from an independently accepted authority catalog;
- `operation`: exact six-operation enum;
- `requiredAccess`: exact four-byte RWXS value for the operation;
- `statusKind`: exact `null|registration|admission`, with non-null only for
  status;
- `validUntilMilliseconds`: no later than intent expiry.

All fields are non-null except `statusKind`.

If issuer/catalog/Identity/build inputs are missing or unverifiable:

```text
ChallengeOutcomeExpectationCore = not constructible
accepted challenge outcomes = EMPTY
challenge send = FORBIDDEN
readiness = UNAVAILABLE
```

### 5.2 ChallengeExchangeOutcome

This is a verifier union, not a new wire wrapper:

| Case | Protected artifact kind | Core schema | Signer |
|---|---|---|---|
| challenge issued | `challenge` | `cellprotocol.device-ingress.challenge-core.v1` | exact expectation-pinned challenge issuer |
| authenticated rejection | `authenticated_error` | `cellprotocol.device-ingress.authenticated-error-core.v3` with `phase=pre_challenge` | exact expectation-pinned challenge issuer |

Challenge success verification requires:

- exact body/intent/requester/operation/status/access/purpose/resource equality
  with the expectation;
- exact issuer descriptor/key/algorithm/generation equality;
- valid times and nonces;
- target Cell/owner and Agreement/Contract/Grant resolution through the exact
  accepted catalog; and
- no request, admission, or response truth.

Pre-challenge authenticated error verification requires the exact field matrix
in section 7. It establishes only authenticated rejection/retry semantics.

Canonical/signature failure before requester authentication and transport
failure are outer opaque failures, not application artifacts. They establish
no success, denial, current state, or retry safety.

## 6. Operation exchange expectation and outcome

### 6.1 OperationOutcomeExpectationCore v1

Schema:

`binding.device-ingress.operation-outcome-expectation-core.v1`

Exact member order:

1. `admissionID`
2. `agreementSHA256`
3. `authorityCatalogSHA256`
4. `authorityGeneration`
5. `bodySHA256`
6. `buildProvenanceSHA256`
7. `challengeArtifactSHA256`
8. `challengeExpectationSHA256`
9. `conditionsSHA256`
10. `consentSHA256`
11. `contractSHA256`
12. `expectationID`
13. `grantSHA256`
14. `identityDomain`
15. `intentArtifactSHA256`
16. `issuerAlgorithm`
17. `issuerDescriptorSHA256`
18. `issuerGeneration`
19. `issuerKeyID`
20. `minimumRegistrationGeneration`
21. `minimumRevocationGeneration`
22. `minimumServerSequence`
23. `operation`
24. `purpose`
25. `requestArtifactSHA256`
26. `requesterDescriptorSHA256`
27. `requiredAccess`
28. `resource`
29. `schema`
30. `statusKind`
31. `subjectTargetBindingSHA256`
32. `targetCellID`
33. `targetOwnerAlgorithm`
34. `targetOwnerDescriptorSHA256`
35. `targetOwnerKeyID`
36. `validUntilMilliseconds`

Types:

- `admissionID`: exact 48-byte `adm1_...`;
- digest/descriptor members: `DigestHex`;
- generations and sequence: `UInt64` or `PositiveUInt64` as in S5;
- issuer/target-owner algorithm and key ID: exact accepted historical signer
  references;
- operation/status/access/tuple members: exact challenge/request values;
- `challengeExpectationSHA256`: digest of the already committed challenge
  ResponseExpectationUnionCore;
- `validUntilMilliseconds`: not later than challenge/request validity.

All fields are non-null except `statusKind`.

The expectation is constructed only after exact challenge and request artifact
bytes exist, but before any operation-request bytes are sent. Missing
challenge/request/admission/target/authority inputs make it unconstructible and
send forbidden.

It contains no vault proof, journal root, current/future outcome, response, or
self digest. A future integrator must bind it to an earlier continuity
checkpoint and a later successor checkpoint without adding a backward edge.

### 6.2 Operation SignedOutcome union

The S5 three-case SignedOutcome union is preserved, with this packet's exact
core versions:

| Case | Protected artifact kind | Core schema |
|---|---|---|
| success | `operation_success` | `cellprotocol.device-ingress.response-core.v3` |
| authenticated error | `authenticated_error` | `cellprotocol.device-ingress.authenticated-error-core.v3` |
| terminal evidence | `admission_terminal_evidence` | `cellprotocol.device-ingress.admission-terminal-evidence-core.v2` |

Success must use the exact result schema selected by operation/status:

| Operation/status | Exact result schema |
|---|---|
| register/null | `cellprotocol.device-ingress.register-receipt-core.v3` |
| resolve/null | `cellprotocol.device-ingress.resolve-result-core.v3` |
| submit/null | `cellprotocol.device-ingress.submit-receipt-core.v3` |
| status/registration | `cellprotocol.device-ingress.status-result-core.v3` |
| status/admission | `cellprotocol.device-ingress.status-result-core.v3` |
| revoke/null | `cellprotocol.device-ingress.revoke-receipt-core.v3` |
| deregister/null | `cellprotocol.device-ingress.deregister-receipt-core.v3` |

Terminal evidence is an allowed non-success only for the five non-status
operations after admission. Status never uses terminal evidence as a successful
status result.

An authenticated error or terminal-evidence case never establishes:

- registration active/current;
- resolve delivered;
- submit committed;
- revoke committed;
- deregister committed;
- not registered; or
- retry safety beyond its exact signed retry class.

Status success establishes only the exact StatusResultCore v3 row. Historical
success never becomes fresh current truth without the required signed status
flow.

## 7. AuthenticatedErrorCore v3

Schema:

`cellprotocol.device-ingress.authenticated-error-core.v3`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `committedAtMilliseconds`
5. `errorCode`
6. `intentArtifactSHA256`
7. `operation`
8. `phase`
9. `requestArtifactSHA256`
10. `requesterDescriptorSHA256`
11. `retryClass`
12. `schema`
13. `serverSequence`
14. `statusKind`
15. `targetCellID`
16. `targetOwnerDescriptorSHA256`
17. `terminality`

The S5 closed error-code/retry-class/terminality mapping is unchanged.
`operation_pending` remains the only nonterminal code and is valid only with
`phase=admitted`.

Exact phase matrix:

| phase | admission | body | challenge | intent | request | target/owner | signer |
|---|---|---|---|---|---|---|---|
| `pre_challenge` | null | V | null | V | null | null | expectation-pinned challenge issuer |
| `post_challenge_pre_admission` | null | V | V | V | **V** | V | expectation-pinned target owner |
| `admitted` | V | V | V | V | V | V | expectation-pinned target owner |
| `readback` | V | V | V | V | V | V | expectation-selected historical signer |

This deliberately changes S5 v2 post-challenge request nullability. Once a
signed request has been received, a post-challenge error must bind its exact
RequestArtifact digest. It cannot be replayed across two differently signed
requests that share semantic fields.

For every phase, all S5 terminal error codes are syntactically accepted if the
expectation, signer, attempt tuple, and fixed retry mapping verify.
`operation_pending` is accepted only for admitted. This conservative closed
set grants no authority because every member is non-success. Product-specific
error presentation may narrow the set later but cannot convert an error into
success.

Exact phase-invalid negatives:

- pre-challenge with challenge/request/admission/target: reject;
- post-challenge with null challenge/request/target: reject;
- admitted/readback with any null attempt field: reject;
- `operation_pending` outside admitted: reject;
- wrong signer role: reject;
- wrong request/intent/challenge/body/admission/subject/target: reject.

Maximum canonical AuthenticatedErrorCore v3 bytes remains the S5 inclusive
allocation ceiling `8192`. No fixture calls that ceiling semantically accepted
until an exact phase/code/signer instance reaches it.

## 8. Five non-status v3 success-result schemas

All five schemas carry forward the S4 v2 member semantics with only:

- the exact v3 schema literal;
- exact-replay removed as a newly produced disposition; and
- the explicit types, nullability, equations, and maxima below.

Exact request replay returns the original stored outcome bytes.

### 8.1 RegisterReceiptCore v3

Schema:

`cellprotocol.device-ingress.register-receipt-core.v3`

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

All members are non-null.

Types and relations:

```text
admissionID = exact 48-byte ID
body/record digests = DigestHex
committedAtMilliseconds = TimestampMilliseconds
all generations and tokenDeliveryEpoch = UInt64
registrationID = exact 48-byte ID
tokenObservationID = "tokobs1_" + Base64url(CSPRNG(32)), exactly 51 bytes
currentRegistrationGeneration = previousRegistrationGeneration + 1
overflow = no commit
```

Closed mode/disposition mapping:

| mutationMode | disposition |
|---|---|
| `enroll` | `enrolled` |
| `update` | `updated` |
| `reactivate` | `reactivated` |
| `token_rotation` | `token_rotated` |

No token or token hash appears.

Maximum contributions:

```text
64+79+46+52+29+31+53+67+93+43+63+41+74
+ 2 braces + 12 commas
= 749
```

The maximum is reachable at token rotation with 20-digit generation/epoch
values satisfying `current=previous+1`.

### 8.2 ResolveResultCore v3

Schema:

`cellprotocol.device-ingress.resolve-result-core.v3`

Exact member order:

1. `contentContractSHA256`
2. `disposition`
3. `payload`
4. `schema`
5. `ticketID`
6. `ticketLineageSHA256`

All members are non-null.

Types:

```text
contentContractSHA256/ticketLineageSHA256 = DigestHex
disposition = resolved
payload = Base64url of 0...48000 exact raw opaque bytes
ticketID = TicketID, 1...128
```

No “not resolved” success exists.

Maximum contributions:

```text
90+24+64012+61+141+88
+ 2 braces + 5 commas
= 64423
```

The 48000-byte raw payload encodes to exactly 64000 Base64url bytes.

### 8.3 SubmitReceiptCore v3

Schema:

`cellprotocol.device-ingress.submit-receipt-core.v3`

Exact member order:

1. `disposition`
2. `resultRecordSHA256`
3. `schema`
4. `submissionGeneration`
5. `submissionID`
6. `ticketID`
7. `ticketLineageSHA256`

All members are non-null.

Types and relations:

```text
disposition = submitted
resultRecordSHA256/ticketLineageSHA256 = DigestHex
submissionGeneration = PositiveUInt64
submissionID = "subm1_" + Base64url(CSPRNG(32)), exactly 49 bytes
ticketID = TicketID, 1...128
```

Submission uniqueness/generation remains the S4 v2 target/ticket-lineage rule.

Maximum contributions:

```text
25+87+61+43+66+141+88
+ 2 braces + 6 commas
= 519
```

### 8.4 RevokeReceiptCore v3

Schema:

`cellprotocol.device-ingress.revoke-receipt-core.v3`

Exact member order:

1. `disposition`
2. `previousRevocationGeneration`
3. `registrationGeneration`
4. `registrationID`
5. `registrationRecordSHA256`
6. `revocationGeneration`
7. `schema`
8. `state`

All members are non-null.

Types and relations:

```text
state = revoked
disposition = revoked | already_revoked
generations = UInt64
registrationID = exact 48-byte ID
registrationRecordSHA256 = DigestHex

revoked:
  revocationGeneration = previousRevocationGeneration + 1
  overflow = no commit

already_revoked:
  revocationGeneration = previousRevocationGeneration
  new fully authorized exact-current request only
```

Maximum contributions use `already_revoked`:

```text
31+51+45+67+93+43+61+17
+ 2 braces + 7 commas
= 417
```

### 8.5 DeregisterReceiptCore v3

Schema:

`cellprotocol.device-ingress.deregister-receipt-core.v3`

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

All members are non-null.

Exact values/types:

```text
deletedMaterialKinds = ["endpoint","token"]
deletionMode = endpoint_and_token_material
disposition = deregistered | already_deregistered
generations = UInt64
registrationID = exact 48-byte ID
state = deregistered
tombstoneArtifact = Base64url exact S3 DeregistrationTombstoneArtifact bytes
tombstoneSHA256 = DigestHex of exact decoded artifact bytes
```

The tombstone artifact must have:

```text
artifactKind = deregistration_tombstone
core schema = cellprotocol.device-ingress.deregistration-tombstone-core.v1
signer = exact expectation-pinned target owner
```

No success is valid while an authoritative active/recoverable endpoint or raw
token binding remains.

`already_deregistered` requires the same-subject retained/disclosable
tombstone condition. That condition remains blocked by
`MBI-PRIVACY-RETENTION-01`; this packet chooses no retention duration or
legitimate purpose.

## 9. SignatureEncodingProfile and exact artifact formulas

### 9.1 Typed external profile

An accepted signed-artifact maximum requires one independently accepted:

`SignatureEncodingProfile`

with:

```text
A = exact algorithm-token byte count, 1...64
K = exact key-ID byte count, 1...128
S = exact canonical raw-signature byte count for the selected algorithm,
    1...1024
```

The profile must prove that `S` is canonical and reachable for that algorithm.
No signing root, algorithm, key, key ID, or raw signature is selected here.

Without the profile:

```text
accepted signature profiles = EMPTY
accepted signed-artifact semantic maximum = UNAVAILABLE
signed boundary fixture = BLOCKED_SIGNATURE_PROFILE
```

This is a typed blocker, not an invitation to use test authority in production.

### 9.2 Parameterized formula

For artifact-kind byte length `k`:

```text
Protected(k,A,K) = 284 + A + K + k

Envelope(k,A,K,S) =
  92 + B64(Protected(k,A,K)) + B64(S)

Artifact(C,k,A,K,S) =
  92 + B64(C) + B64(Envelope(k,A,K,S))
```

Relevant kind lengths:

```text
challenge = 9
operation_success = 17
authenticated_error = 19
deregistration_tombstone = 24
admission_terminal_evidence = 27
```

The S5 scalar structural ceiling `A=64,K=128,S=1024` gives:

| kind | Protected | Envelope |
|---|---:|---:|
| operation_success | 493 | 2116 |
| authenticated_error | 495 | 2118 |
| deregistration_tombstone | 500 | 2125 |
| admission_terminal_evidence | 503 | 2129 |

These rows are allocation ceilings only until an accepted algorithm profile
witnesses the exact values.

### 9.3 Deregistration tombstone/result function

The S3 DeregistrationTombstoneCore maximum independently reproduces as:

```text
64+46+45+67+90+43+71+92+145+96
+ 2 braces + 9 commas
= 770
```

For profile `(A,K,S)`:

```text
TombstoneArtifact(A,K,S) =
  Artifact(770,24,A,K,S)

DeregisterResultAlready(A,K,S) =
  534 + B64(TombstoneArtifact(A,K,S))

DeregisterResultFresh(A,K,S) =
  526 + B64(TombstoneArtifact(A,K,S))
```

At the structural ceiling:

```text
TombstoneArtifact = 3953
DeregisterResultAlready = 5805
DeregisterResultFresh = 5797
```

`5805` is not called currently reachable because `already_deregistered`
depends on the open retention/disclosure policy. `5797` is the fresh-row
structural maximum, still conditional on an accepted signer profile and
authoritative state.

## 10. Per-operation ResponseCore v3 maxima

### 10.1 Exact fixed contributions

For empty `result`, each valid ResponseCore v3 variant has:

| operation/status | exact result schema bytes | fixed bytes |
|---|---:|---:|
| register/null | 52 | 1104 |
| resolve/null | 50 | 1101 |
| submit/null | 50 | 1100 |
| status/registration | 49 | 1109 |
| status/admission | 49 | 1106 |
| revoke/null | 50 | 1100 |
| deregister/null | 54 | 1108 |

No row combines a non-status operation with a non-null status kind. No result
schema outside the closed mapping is permitted.

### 10.2 Non-nested exact maxima

StatusResultCore v3 registration-row maximum is 882 bytes. The reachable
maximizing row is `correlation_current_active` with:

- selector `registration_id`;
- exact correlation digest;
- 43-byte head epoch;
- 20-digit timestamps/generations;
- exact current registration ID/record/revocation;
- subject state `active_consented`; and
- all admission/tombstone fields null.

Exact ResponseCore v3 maxima:

| operation/status | result-core max | equation | ResponseCore max |
|---|---:|---|---:|
| register/null | 749 | `1104+B64(749)=1104+999` | 2103 |
| resolve/null | 64423 | `1101+B64(64423)=1101+85898` | 86999 |
| submit/null | 519 | `1100+B64(519)=1100+692` | 1792 |
| status/registration | 882 | `1109+B64(882)=1109+1176` | 2285 |
| revoke/null | 417 | `1100+B64(417)=1100+556` | 1656 |
| deregister/null, structural already | `5805` | `1108+B64(5805)=1108+7740` | 8848 |
| deregister/null, fresh | `5797` | `1108+B64(5797)=1108+7730` | 8838 |

The largest non-nested ResponseCore v3 is resolve at exactly 86999 bytes.
This is a core maximum; it does not require or assert a production signing
root.

### 10.3 Signed normal outcome function

For an accepted profile:

```text
NormalOutcomeMax(A,K,S) =
  Artifact(86999,17,A,K,S)
```

At the structural ceiling:

```text
NormalOutcomeStructuralCeiling =
  92 + B64(86999) + B64(2116)
= 92 + 115999 + 2822
= 118913
```

This replaces S5's unreachable `120987` allocation claim. `118913` remains a
structural ceiling, not an accepted signed maximum, until a profile witnesses
`A=64,K=128,S=1024`.

### 10.4 Nested status/admission function

Recursive status read-back remains forbidden.

The exact fixed StatusResultCore v3
`admission_response_available/operation_success` contribution is 683. For an
accepted signer profile:

```text
N(A,K,S)  = NormalOutcomeMax(A,K,S)
SR(A,K,S) = 683 + B64(N(A,K,S))
R(A,K,S)  = 1106 + B64(SR(A,K,S))
O(A,K,S)  = Artifact(R(A,K,S),17,A,K,S)
```

At the structural ceiling:

```text
N  = 118913
SR = 683 + B64(118913)
   = 683 + 158551
   = 159234
R  = 1106 + B64(159234)
   = 1106 + 212312
   = 213418
O  = 92 + B64(213418) + B64(2116)
   = 92 + 284558 + 2822
   = 287472
```

Those values are acyclic because `N` is a completed non-status outcome before
the status result and outer status response exist.

## 11. Reachability and boundary rules

### 11.1 Result-core vectors

Every core vector uses only sanitized repeated allowed characters and no
secret/token data.

| Core | accepted max-1 | accepted max | rejected max+1 |
|---|---:|---:|---:|
| RegisterReceipt v3 | 748: one independent UInt64 uses 19 digits | 749 | 750: tokenObservationID length 52 |
| ResolveResult v3 | 64422: ticketID length 127 | 64423 | 64424: ticketID length 129 |
| SubmitReceipt v3 | 518: ticketID length 127 | 519 | 520: ticketID length 129 |
| RevokeReceipt v3 | 416: registrationGeneration uses 19 digits | 417 | 418: registrationID length 49 |
| Deregister fresh, structural profile | 5796: registrationGeneration uses 19 digits | 5797 | 5798: registrationID length 49 |
| Deregister already, structural profile | 5804: registrationGeneration uses 19 digits | 5805, privacy-blocked | 5806: registrationID length 49 |

The deregister byte values are evaluated only under an explicit fixture
SignatureEncodingProfile. The already row remains `BLOCKED_PRIVACY_RETENTION`
and cannot be an accepted production fixture.

### 11.2 ResponseCore vectors

For each valid response maximum:

- max-1 uses a 19-digit `serverSequence` while all other maximum fields remain
  valid;
- max uses the exact valid operation/status/result row;
- max+1 uses `targetCellID` length 129 and is rejected.

This yields exact byte-count `max-1/max/max+1` around:

```text
register 2102/2103/2104
resolve  86998/86999/87000
submit   1791/1792/1793
status-registration 2284/2285/2286
revoke   1655/1656/1657
deregister-fresh structural 8837/8838/8839
```

Deregister vectors remain signature-profile conditional.

### 11.3 Forbidden combinations

Every producer and consumer rejects:

- `deregister` with `statusKind=registration`;
- `status` with null or unknown status kind;
- any non-status operation with non-null status kind;
- an arbitrary 96-byte result schema;
- result schema not exactly mapped to operation/status;
- result digest mismatch;
- decoded result schema mismatch;
- invalid result-core disposition/mode/state relation;
- extra/missing/reordered result members;
- escaped or padded alternate encodings;
- ResponseCore above the selected valid variant maximum;
- signed artifact without an accepted SignatureEncodingProfile;
- semantic-max PASS derived only from the structural ceiling; and
- nested status whose target outcome is itself a status operation.

## 12. Fixture and applicability ledger

### 12.1 Exact future test aliases

These are planning paths only. They do not authorize file creation:

| Code | Exact future test path |
|---|---|
| `A-S6A` | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressS6AResponseMaximaTests.swift` |
| `B-S6A` | `repo://CellScaffold/Tests/AppTests/DeviceIngressS6AResponseProducerTests.swift` |
| `C-S6A` | `repo://Binding/BindingTests/DeviceIngressS6AExpectationConsumerTests.swift` |

Producer fixture manifest planning path:

`repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/s6a-response-maxima-manifest.v1.json`

No listed file currently exists or receives PASS from this document.

### 12.2 Exact fixture IDs

| ID | Fixture | Expected | A | B | C |
|---|---|---|---|---|---|
| S6A-E001 | challenge expectation canonical | accept-structure | A-S6A | N/A client-local expectation | C-S6A |
| S6A-E002 | challenge success exact intent/issuer | accept-structure, authority-blocked | A-S6A | B-S6A | C-S6A |
| S6A-E003 | pre-challenge authenticated error | accept-rejection, authority-blocked | A-S6A | B-S6A | C-S6A |
| S6A-E004 | challenge expectation contains future challenge digest | reject | A-S6A | N/A client-local expectation | C-S6A |
| S6A-E005 | operation expectation canonical after request | accept-structure | A-S6A | N/A client-local expectation | C-S6A |
| S6A-E006 | operation expectation missing request/admission | reject/send-forbidden | A-S6A | N/A client-local expectation | C-S6A |
| S6A-E007 | expectation contains self/vault-successor/journal-root digest | reject | A-S6A | N/A client-local expectation | C-S6A |
| S6A-E008 | post-challenge error with exact request digest | accept-rejection, authority-blocked | A-S6A | B-S6A | C-S6A |
| S6A-E009 | post-challenge error with null request digest | reject | A-S6A | B-S6A | C-S6A |
| S6A-E010 | pre-challenge error with request/admission/target | reject | A-S6A | B-S6A | C-S6A |
| S6A-E011 | non-success promoted to current/success | reject | A-S6A | B-S6A | C-S6A |
| S6A-R001 | register receipt max-1/max/max+1 | 748 accept / 749 accept / 750 reject | A-S6A | B-S6A | C-S6A |
| S6A-R002 | resolve result max-1/max/max+1 | 64422 accept / 64423 accept / 64424 reject | A-S6A | B-S6A | C-S6A |
| S6A-R003 | submit receipt max-1/max/max+1 | 518 accept / 519 accept / 520 reject | A-S6A | B-S6A | C-S6A |
| S6A-R004 | revoke receipt max-1/max/max+1 | 416 accept / 417 accept / 418 reject | A-S6A | B-S6A | C-S6A |
| S6A-R005 | deregister fresh function boundary | structural accept / authority-profile blocked | A-S6A | B-S6A | C-S6A |
| S6A-R006 | deregister already retained row | `BLOCKED_PRIVACY_RETENTION` | A-S6A | B-S6A | C-S6A |
| S6A-R007 | result-schema substitution across operations | reject | A-S6A | B-S6A | C-S6A |
| S6A-R008 | exact replay creates new disposition | reject; return stored bytes | A-S6A | B-S6A | C-S6A |
| S6A-M001 | register response 2102/2103/2104 | accept/accept/reject | A-S6A | B-S6A | C-S6A |
| S6A-M002 | resolve response 86998/86999/87000 | accept/accept/reject | A-S6A | B-S6A | C-S6A |
| S6A-M003 | submit response 1791/1792/1793 | accept/accept/reject | A-S6A | B-S6A | C-S6A |
| S6A-M004 | registration status 2284/2285/2286 | accept/accept/reject | A-S6A | B-S6A | C-S6A |
| S6A-M005 | revoke response 1655/1656/1657 | accept/accept/reject | A-S6A | B-S6A | C-S6A |
| S6A-M006 | deregister response profile function | structural/profile-blocked | A-S6A | B-S6A | C-S6A |
| S6A-M007 | normal signed outcome formula | `BLOCKED_SIGNATURE_PROFILE` | A-S6A | B-S6A | C-S6A |
| S6A-M008 | nested admission signed outcome formula | `BLOCKED_SIGNATURE_PROFILE` | A-S6A | B-S6A | C-S6A |
| S6A-M009 | S5 mutually exclusive 1160 fixed tuple | reject | A-S6A | B-S6A | C-S6A |
| S6A-M010 | signature raw length 1025 | reject before allocation/signature verification | A-S6A | B-S6A | C-S6A |
| S6A-M011 | nested status of status outcome | reject recursion | A-S6A | B-S6A | C-S6A |

`accept-structure` never means accepted production authority. Any fixture that
needs a signer remains authority/profile blocked until the exact external
premise is independently supplied.

## 13. Decision and blocker ledger

### 13.1 Packet decisions

| ID | Decision | Basis | Classification |
|---|---|---|---|
| S6A-DEC-01 | Split response expectation into challenge and operation phases | S3 construction order and S5 C/A findings | technical; no product/authority choice |
| S6A-DEC-02 | Union payload may reference only prior exact bytes | acyclic signed-artifact invariant | technical |
| S6A-DEC-03 | AuthenticatedError v3 binds request digest post-challenge | cross-request substitution resistance | technical |
| S6A-DEC-04 | Five v3 success cores carry S4 v2 semantics forward | exact immutable v2 inputs; no new authority | technical |
| S6A-DEC-05 | Maxima are computed per valid discriminator row | S5 A/B maxima findings | technical |
| S6A-DEC-06 | Signed maxima are profile functions, not universal accepted constants | signing root/algorithm not selected | fail-closed technical |
| S6A-DEC-07 | `already_deregistered` max remains retention-blocked | Kjetil-owned privacy MBI | no decision taken |

### 13.2 Typed blockers

| ID | Missing exact input | Consequence | Owner/status |
|---|---|---|---|
| S6A-BLOCK-01 | accepted canonical SignatureEncodingProfile with reachable `A/K/S` | signed normal/nested/deregister artifact semantic maximum unavailable | external signing/authority owner; OPEN |
| S6A-BLOCK-02 | owner-approved retention/legitimate-purpose/disclosure rule | `already_deregistered` accepted max unavailable | `MBI-PRIVACY-RETENTION-01`, Kjetil; OPEN |
| S6A-BLOCK-03 | proven crash-durable local store and acyclic continuity integration | expectation persist-before-send runtime proof unavailable | RC7/RC8 successor/integrator; OPEN |
| S6A-BLOCK-04 | actual Identity/authority/catalog/signer bytes | accepted challenge/outcome signer sets EMPTY | Identity/authority prerequisite; OPEN |

No blocker is filled by a test key, static owner, environment variable, TLS,
route possession, token possession, repository identity, or administrator.

## 14. Root classification

### 14.1 RC1

Static formal result:

- challenge and operation expectations are separate and constructible in
  temporal order;
- neither includes future/self/successor digests;
- pre-challenge success/error and post-challenge success/error/evidence are
  total verifier unions;
- post-challenge error binds exact request bytes;
- status remains a typed signed success result or non-success;
- non-success never establishes success/current truth; and
- missing expectation/authority/store fails closed.

Classification:

```text
RC1 STATIC FORMAL CONTRACT: CLOSED BY AUTHOR PACKET
RC1 INDEPENDENT REVIEW CREDIT: NONE
RC1 RUNTIME/DURABILITY/AUTHORITY: UNAVAILABLE
RC1 MATERIAL IMPLEMENTATION: NO-GO
```

### 14.2 RC5

Static formal result:

- five missing non-status result schemas are byte-total;
- each valid ResponseCore discriminator has an exact fixed contribution;
- result-core and unsigned ResponseCore maxima are mechanically reachable;
- mutually exclusive fields are never combined;
- normal and nested signed maxima are exact profile functions; and
- structural ceilings are not mislabeled as accepted semantic maxima.

Residual:

- no exact production SignatureEncodingProfile exists in the inputs;
- deregister-already reachability depends on open privacy retention.

Classification:

```text
RC5 RESULT/RESPONSE CORE MAXIMA: CLOSED BY AUTHOR PACKET
RC5 SIGNED-ARTIFACT ACCEPTED MAXIMA: FORMAL_NO_GO / S6A-BLOCK-01
RC5 DEREGISTER-ALREADY ACCEPTED MAX: FORMAL_NO_GO / S6A-BLOCK-02
RC5 OVERALL: PARTIAL
RC5 INDEPENDENT REVIEW CREDIT: NONE
```

### 14.3 Author finding count

This is an author packet, not a review. Within its declared RC1/RC5 scope:

```text
author-identified P0: 0
author-identified P1: 0
author-identified P2: 0
typed blockers: 4
independent closure findings: none
```

The zero finding count is not a GO. Typed blockers and all material gates
remain operative, and only a distinct exact-byte reviewer may assess this
packet.

## 15. Preserved external and stop gates

```text
accepted authority manifests = EMPTY
accepted target owners = EMPTY
accepted challenge issuers = EMPTY
accepted outcome signers = EMPTY
accepted signature profiles = EMPTY
accepted durable-store proofs = EMPTY
accepted vault/custody/rollback/hardware proofs = EMPTY

MBI-PRIVACY-RETENTION-01 = OPEN / KJETIL
IDENTITY CUTOVER = SEPARATE / NO-GO
MBI-TRANSPORT-FRAMING-01 = MISSING
MBI-06 APPLE SIGNING/PROFILE/ENTITLEMENTS = MISSING
MBI-07 INTEGRATED OUTPUT = MISSING

PLAN: NO-GO
SOURCE: CLOSED / NO-GO
MATERIAL: CLOSED / NO-GO
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
NEXT MATERIAL PHASE: CLOSED / NO-GO
S6 INTEGRATOR: NOT AUTHORIZED
PRODUCTION: CLOSED / NO-GO
```

## 16. Final author freeze

```text
PACKET: S6 FORMAL PROOF PACKET A / RESPONSE AND MAXIMA
OUTPUT OWNER: PACKET A AUTHOR ONLY
OUTPUT COUNT: EXACTLY ONE NEW DOCUMENT

BOUND S5:
  0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6
  2554 lines / 93787 bytes

BOUND S5 REVIEWS:
  A dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639
    1038 lines / 36228 bytes
  B 0c98b68d5fdd847289e026173e376ac66dc33f70c7e9d8ebcf22e84573a1c601
    859 lines / 36035 bytes
  C 36ff7ffc838f15abf99bf281c0a0f1ee584a1423d70bf26bdac3a38b2e3ebbc2
    981 lines / 40219 bytes

RC2 AND OUT-OF-SCOPE POSITIVE CONTRACTS: PRESERVED
RC1 STATIC FORMAL CONTRACT: AUTHOR-CLOSED / REVIEW REQUIRED
RC5 CORE MAXIMA: AUTHOR-CLOSED / REVIEW REQUIRED
RC5 SIGNED MAXIMA: FORMAL_NO_GO / SIGNATURE PROFILE MISSING
RC5 PRIVACY-CONDITIONAL MAX: FORMAL_NO_GO / RETENTION DECISION OPEN

AUTHOR P0/P1/P2: 0/0/0
TYPED BLOCKERS: 4
INDEPENDENT REVIEW CREDIT: NONE

S6 PACKET A: PARTIAL
S6 INTEGRATION: NO-GO
SOURCE/MATERIAL AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

This packet stops after freeze. It does not authorize its own review, another
packet, an S6 integrator, source, test, signing, device, APNS, or production
work.
