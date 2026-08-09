# APNS S4 Normative Composition Contract Correction

Status: **AUTHOR-FROZEN / INDEPENDENT REVIEW REQUIRED / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Date lineage: `2026-07-24`  
Authoring date: `2026-07-25` local  
Scope: additive document-only correction of the immutable S3 contract  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md`

The sole output path was re-attested absent immediately before this file was
created. This document changes no prior document, source, fixture, project,
dependency, Git, build, test, network, portal, signing, device, APNS, Identity,
staging, deployment, integration, or production state.

## 1. Exact immutable inputs

This correction is bound to exactly these four immutable artifacts:

| Role | Artifact | SHA-256 | Lines | Bytes |
|---|---|---|---:|---:|
| S3 contract | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 |
| Lane A review | `Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 |
| Lane B review | `Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 |
| Lane C review | `Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 |

The inherited `P0/P1/P2 = 0/2/1` top-summary text reproduced in the review
lineage is stale for S3 adjudication. It is not rewritten. The authoritative
finding sections and final decisions in the three immutable reviews are:

| Review | P0 | P1 | P2 |
|---|---:|---:|---:|
| A | 0 | 4 | 2 |
| B | 0 | 7 | 2 |
| C | 0 | 3 | 2 |

Those are fourteen P1 observations, not fourteen independent defects. Shared
causes are consolidated below. No finding is erased by consolidation, and no
review receives an invented closure verdict.

## 2. Additive precedence and preserved S3 contract

S3 remains immutable. The normative contract for a future implementation is
the ordered pair:

```text
S3 exact bytes
then
S4 exact bytes
```

For a clause, schema rule, enum, state transition, maximum, path, or evidence
rule named in S4, S4 replaces the conflicting S3 text. Every S3 clause not
named here remains unchanged. No implementation may select whichever version
is more permissive.

The corrected composition identifier is:

```text
APNS-DEVICE-INGRESS-NORMATIVE-COMPOSITION/2
```

The `adm1_`, `reg1_`, `int1_`, `chl1_`, `tokobs1_`, and `jr1_` prefixes name
their already frozen derivation families, not the composition number. Their S3
derivations remain unchanged unless this correction explicitly supplies a
replacement.

The following S3 invariants are preserved:

- CJP-1 exact UTF-8, member ordering, integer, digest, Base64url, and `LP`
  rules;
- acyclic body → intent → challenge → request → response construction;
- one core before one signature envelope before one signed artifact;
- exactly six wire operations: `register`, `resolve`, `submit`, `status`,
  `revoke`, and `deregister`;
- token rotation only as `register` with `mutationMode=token_rotation`;
- status access exactly `r--s` and mutation access exactly `rw-s`;
- admission and registration identifiers grant no authority;
- semantically opaque, byte-preserving transport;
- first inner decode and every authority decision at the authenticated
  Resolver/Cell boundary;
- revoke and deregister are distinct;
- deregistration tombstone construction remains acyclic and minimal;
- no trust root, owner, issuer, Agreement, Contract, Grant, or consent is
  inferred from route, host, TLS, environment, ID, token, test key, static
  file, or administrator role.

Planning bindings remain exactly:

```text
identity domain = domain:device:notification-callback
purpose         = purpose://access.audit.privacy/device-notification-callback
audience        = haven.digipomps.org
origin          = https://haven.digipomps.org
bundle          = org.digipomps.haven
APNS topic      = org.digipomps.haven
environment     = production
```

These literals prove no Apple, Identity, transport, server, device, or APNS
readiness.

## 3. Consolidated review ledger

### 3.1 Eleven P1 closure clusters

| Cluster | Immutable observations | Corrected here |
|---|---|---|
| `S4-P1-01` | A-01, B-04 | byte-total result/response/status/authenticated-error family, exact digests, enums, identifiers, sequence, field matrix, oracle-safe negatives |
| `S4-P1-02` | A-02, B-03 | total challenge unique indexes, replay equality, collision order, compacted records, explicit indeterminate/unavailable terminal evidence |
| `S4-P1-03` | A-03 | exact subject-registration derived key, partial unique predicate, atomic CAS/order |
| `S4-P1-04` | A-04, B-05 | algebraically satisfiable inclusive nested maxima and boundary vectors |
| `S4-P1-05` | B-01 | typed requester, target Cell, target owner, signer, subject-target relation, no-create first enrollment |
| `S4-P1-06` | B-02 | signed Agreement/Contract/Grant/Conditions/consent catalog and atomic import/use ledger |
| `S4-P1-07` | B-07 | variable-length opaque APNS token with a conservative protocol/resource bound |
| `S4-P1-08` | B-06 | legacy plaintext database/WAL/backup quarantine, sealed migration or fail-closed deactivation |
| `S4-P1-09` | C-01 | crash-durable, authority- and vault-pinned response expectation for every operation |
| `S4-P1-10` | C-02 | total six-operation Binding reducer and authoritative deregister/local-erasure order |
| `S4-P1-11` | C-03 | existing persistent CellApple vault continuity, no-create, evidence rebind, local `UNKNOWN` |

This author asserts only that the static text below addresses those clusters.
Only a new independent exact-byte review may decide closure.

### 3.2 Three P2 closure clusters

| Cluster | Immutable observations | Corrected here |
|---|---|---|
| `S4-P2-01` | A-01, A-02 | exact producer paths, SwiftPM boundary, fixture filenames, manifest ownership |
| `S4-P2-02` | B-01, B-02 | exact server Cell/service/store owners and producer-manifest consumption ledger |
| `S4-P2-03` | C-01, C-02 | exact Binding include/collision/no-touch paths and transition-negative evidence rows |

No source or test action is authorized by these path plans.

## 4. Shared exact types and equations

### 4.1 Scalar types

| Type | Exact rule |
|---|---|
| `DigestHex` | 64 lowercase hexadecimal ASCII; decodes to 32 bytes |
| `UInt64` | integer `0...18446744073709551615`, shortest decimal CJP-1 |
| `PositiveUInt64` | integer `1...18446744073709551615` |
| `TimestampMilliseconds` | `UInt64` Unix milliseconds |
| `DescriptorDigest` | `DigestHex` of exact canonical descriptor bytes |
| `TargetCellID` | 1...128 printable ASCII bytes; authority-catalog exact value |
| `AlgorithmToken` | 1...64 characters from `A-Z a-z 0-9 . _ -` |
| `KeyID` | 1...128 characters from `A-Z a-z 0-9 . _ : -` |
| `OpaquePayload` | bounded raw bytes encoded as canonical unpadded Base64url |
| `Nullable<T>` | member is always present; exact `null` or exact `T` encoding |

No arbitrary printable string substitutes for a closed enum or typed ID.

### 4.2 Base64url length

For `n >= 0` raw bytes:

```text
B64(n) =
  4 * floor(n / 3)                  when n mod 3 = 0
  4 * floor(n / 3) + 2              when n mod 3 = 1
  4 * floor(n / 3) + 3              when n mod 3 = 2
```

There is no `=` padding.

### 4.3 Digest equations

For exact CJP-1 `ResultCore` bytes:

```text
resultSHA256Raw = SHA256(exactResultCoreBytes)
resultSHA256    = lowercaseHex(resultSHA256Raw)
```

For exact `MutationCorrelationCore` bytes:

```text
correlationSHA256Raw = SHA256(exactMutationCorrelationCoreBytes)
correlationSHA256    = lowercaseHex(correlationSHA256Raw)
```

For exact terminal-evidence bytes:

```text
terminalEvidenceSHA256 =
  lowercaseHex(SHA256(exactAdmissionTerminalEvidenceArtifactBytes))
```

For exact response, tombstone, consent, catalog, and imported authority
artifacts, every `...SHA256` member is lowercase hexadecimal SHA-256 of the
complete exact artifact bytes, never of decoded or reconstructed content.

### 4.4 Server sequence

`serverSequence` is `PositiveUInt64`. Its namespace is:

```text
LP(UTF8(compositionVersion))
|| LP(UTF8(targetCellID))
|| LP(targetOwnerDescriptorSHA256Raw)
|| LP(UInt64BE(authorityGeneration))
```

For a pre-target authenticated error or issuer terminal evidence, the namespace
replaces target Cell/owner with:

```text
LP(issuerDescriptorSHA256Raw)
|| LP(UInt64BE(issuerGeneration))
```

Rules:

1. first committed artifact in a new namespace has sequence `1`;
2. a new result/error/evidence commits `previous + 1` atomically with its exact
   artifact;
3. exact replay returns stored bytes and does not increment;
4. a failed transaction consumes no visible sequence;
5. sequence exhaustion makes the namespace unavailable;
6. restart reads back the last committed value;
7. restore below the external rollback anchor fails readiness closed;
8. a new authority generation creates a new namespace but never validates an
   older generation by numeric comparison alone.

## 5. Byte-total result, response, and authenticated-error family

### 5.1 Exact operation-to-success-result mapping

| Operation/status kind | Exact success result schema |
|---|---|
| `register` | `cellprotocol.device-ingress.register-receipt-core.v2` |
| `resolve` | `cellprotocol.device-ingress.resolve-result-core.v2` |
| `submit` | `cellprotocol.device-ingress.submit-receipt-core.v2` |
| `status/registration` | `cellprotocol.device-ingress.status-result-core.v2` |
| `status/admission` | `cellprotocol.device-ingress.status-result-core.v2` |
| `revoke` | `cellprotocol.device-ingress.revoke-receipt-core.v2` |
| `deregister` | `cellprotocol.device-ingress.deregister-receipt-core.v2` |

Any operation may instead return:

- `cellprotocol.device-ingress.authenticated-error-core.v1` after the requester
  is authenticated; or
- an exact stored
  `cellprotocol.device-ingress.admission-terminal-evidence-core.v1` for an
  admitted operation whose target outcome cannot safely be recovered.

Canonical/signature failures before requester authentication have no
application artifact. They are outer opaque failure only. Transport never
constructs one of these cores.

### 5.2 ResponseCore v2

Schema:

`cellprotocol.device-ingress.response-core.v2`

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

Types:

- `admissionID`: exact 48-byte `adm1_...`;
- three digest members and requester/owner descriptors: `DigestHex`;
- `committedAtMilliseconds`: `TimestampMilliseconds`;
- `operation`: exact six-operation enum;
- `result`: Base64url of exact result core bytes;
- `resultSchema`: exact mapping in section 5.1, maximum 96 ASCII bytes;
- `serverSequence`: `PositiveUInt64`;
- `targetCellID`: `TargetCellID`.

Required equations:

```text
Base64urlDecode(result) == exactResultCoreBytes
resultSHA256 == lowercaseHex(SHA256(exactResultCoreBytes))
decoded result schema == resultSchema
ResponseCore.operation == request operation == result operation semantics
```

A normal exact replay returns the original signed response artifact bytes.
It does not create a new result whose disposition says `exact_replay`.

### 5.3 RegisterReceiptCore v2

Schema:

`cellprotocol.device-ingress.register-receipt-core.v2`

Member order remains the S3 order:

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

Closed `disposition` mapping:

| mutationMode | disposition |
|---|---|
| `enroll` | `enrolled` |
| `update` | `updated` |
| `reactivate` | `reactivated` |
| `token_rotation` | `token_rotated` |

All IDs and digests use their exact types. Generations and delivery epoch are
`UInt64`. `currentRegistrationGeneration =
previousRegistrationGeneration + 1`; overflow fails without commit.
`exact_replay` is not a newly produced disposition.

### 5.4 ResolveResultCore v2

Schema:

`cellprotocol.device-ingress.resolve-result-core.v2`

Exact member order:

1. `contentContractSHA256`
2. `disposition`
3. `payload`
4. `schema`
5. `ticketID`
6. `ticketLineageSHA256`

Types and enum:

- `contentContractSHA256`, `ticketLineageSHA256`: `DigestHex`;
- `disposition`: exactly `resolved`;
- `payload`: 0...48000 raw opaque bytes, canonical Base64url;
- `ticketID`: 1...128 printable ASCII bytes under the signed content contract.

No “not resolved” success exists. A denial is an authenticated error. Exact
replay returns exact stored bytes.

### 5.5 SubmitReceiptCore v2

Schema:

`cellprotocol.device-ingress.submit-receipt-core.v2`

Exact member order:

1. `disposition`
2. `resultRecordSHA256`
3. `schema`
4. `submissionGeneration`
5. `submissionID`
6. `ticketID`
7. `ticketLineageSHA256`

Rules:

```text
disposition = submitted
submissionID = "subm1_" + Base64url(CSPRNG(32 bytes))
```

`submissionID` is exactly 49 ASCII bytes and unique under:

```text
UNIQUE(targetCellID, submissionID)
```

`submissionGeneration` is `PositiveUInt64`, starts at `1`, and increments
atomically for:

```text
(targetCellID, requesterDescriptorSHA256, ticketLineageSHA256, ticketID)
```

`resultRecordSHA256` and `ticketLineageSHA256` are `DigestHex`; `ticketID` is
1...128 ASCII. Allocation collision commits nothing and retries internally.
Exact replay returns exact stored response bytes with no new ID or generation.

### 5.6 RevokeReceiptCore v2

Member order remains the S3 order. Closed values:

```text
state = revoked
disposition = revoked | already_revoked
```

`revoked` increments revocation generation once.
`already_revoked` is permitted only for a new, fully authorized, exact-current
request against an already revoked logical registration and increments no
generation. Exact request replay returns its stored bytes.

### 5.7 DeregisterReceiptCore v2

Member order remains the S3 order. Closed values:

```text
deletedMaterialKinds = ["endpoint","token"]
deletionMode = endpoint_and_token_material
state = deregistered
disposition = deregistered | already_deregistered
```

`already_deregistered` is permitted only for a new, fully authorized request
whose old ID and retained tombstone are disclosable to the same subject.
Exact replay returns stored bytes. No response is success while an
authoritative active/recoverable endpoint or token record remains.

### 5.8 AuthenticatedErrorCore

Schema:

`cellprotocol.device-ingress.authenticated-error-core.v1`

Exact member order:

1. `admissionID`
2. `committedAtMilliseconds`
3. `errorCode`
4. `operation`
5. `phase`
6. `requestArtifactSHA256`
7. `requesterDescriptorSHA256`
8. `retryClass`
9. `schema`
10. `serverSequence`
11. `targetCellID`
12. `targetOwnerDescriptorSHA256`

Nullable fields are present as `null`.

Closed `phase`:

- `authenticated_pre_target`;
- `authenticated_pre_admission`;
- `admitted_target`;
- `readback`.

Closed `retryClass`:

- `never_same_bytes`;
- `status_only`;
- `after_authority_recovery`;
- `after_user_action`.

Closed `errorCode`:

- `authority_unavailable`;
- `authorization_denied`;
- `condition_unsatisfied`;
- `generation_conflict`;
- `invalid_operation_state`;
- `legacy_store_quarantined`;
- `operation_pending`;
- `oversize`;
- `privacy_unknown`;
- `replay_conflict`;
- `target_unavailable`;
- `trusted_time_unavailable`;
- `unsupported_token_length`.

For `authenticated_pre_target`, `admissionID`, request digest, target Cell, and
target owner may be null; signer is the exact challenge issuer authorized by
the accepted authority catalog. After target resolution, target Cell and owner
are non-null and signer is that exact target owner. After admission,
`admissionID` and request digest are non-null, and exact error bytes are
durable/read back before release.

The signed artifact uses `artifactKind=authenticated_error`. Signature
protection, core-before-envelope construction, artifact hashing, and acyclic
rules are exactly the S3 rules.

### 5.9 Oracle-safe negative admission

For an `admission_id` selector, each of the following outward cases is exactly:

```text
statusCode = privacy_unknown
all registration fields = null
targetAdmissionArtifact = null
targetAdmissionArtifactKind = null
targetAdmissionArtifactSHA256 = null
```

Cases:

- opaque ID absent;
- opaque ID exists for another subject;
- opaque ID exists for another target;
- proof cannot establish disclosure before protected lookup.

`admission_not_found` is reserved and MUST NOT be emitted in composition
version 2. The server uses the same indexed lookup shape, outer status, body
schema, field nullability, size class, signing path, and bounded response timing
policy for absent and wrong-subject records. Logs and metrics use the single
sanitized reason `admission_privacy_unknown`.

## 6. StatusResultCore v2 and complete matrix

### 6.1 Schema

Schema:

`cellprotocol.device-ingress.status-result-core.v2`

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
13. `targetAdmissionArtifact`
14. `targetAdmissionArtifactKind`
15. `targetAdmissionArtifactSHA256`
16. `tombstoneSHA256`

`targetAdmissionArtifact` is Base64url of exact stored signed
`response`, `authenticated_error`, or `admission_terminal_evidence` artifact.
The kind field is the matching enum or null.

Closed `subjectState`:

- `active_consented`;
- `revoked`;
- `deregistered`;
- `unknown`;
- `indeterminate`;
- null only for admission status.

Closed `correlationDisposition`:

- `not_requested`;
- `current_exact`;
- `superseded`;
- `not_found`;
- `inconsistent_retryable`.

The S3 status-code set is preserved except that `admission_not_found` is
reserved/non-emitting. These terminal codes are added:

- `admission_terminal_indeterminate`;
- `admission_terminal_unavailable`.

Freshness is always:

```text
0 < freshUntilMilliseconds - observedAtMilliseconds <= 60000
```

### 6.2 Matrix notation

```text
N = exact null
V = exact non-null value of the field type
M = one value constrained by the row text
```

`O` and `F` are observed/fresh timestamps and are `V` in every row.

| statusCode | selector | C | H | RG | RID | RR | VG | SS | AA | AK | AH | TS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `subject_current_active` | `subject_current` or owned `registration_id` | `not_requested` | N | V | V | V | V | `active_consented` | N | N | N | N |
| `subject_current_revoked` | `subject_current` or owned `registration_id` | `not_requested` | N | V | V | V | V | `revoked` | N | N | N | N |
| `subject_current_deregistered` | `subject_current` or owned `registration_id` | `not_requested` | N | V | V | N | V | `deregistered` | N | N | N | V |
| `subject_current_unknown` | `subject_current` | `not_requested` | N | N | N | N | N | `unknown` | N | N | N | N |
| `correlation_current_active` | registration selector with correlation | `current_exact` | V | V | V | V | V | `active_consented` | N | N | N | N |
| `correlation_superseded` | registration selector with correlation | `superseded` | V | V | V | M | V | M | N | N | N | M |
| `correlation_not_found` | registration selector with correlation | `not_found` | V | N | N | N | N | `unknown` | N | N | N | N |
| `correlation_inconsistent_retryable` | registration selector with correlation | `inconsistent_retryable` | V | N | N | N | N | `indeterminate` | N | N | N | N |
| `admission_response_available` | `admission_id` | `not_requested` | N | N | N | N | N | N | V | `response` or `authenticated_error` | V | N |
| `admission_pending` | `admission_id` | `not_requested` | N | N | N | N | N | N | N | N | N | N |
| `admission_terminal_indeterminate` | `admission_id` | `not_requested` | N | N | N | N | N | N | V | `admission_terminal_evidence` | V | N |
| `admission_terminal_unavailable` | `admission_id` | `not_requested` | N | N | N | N | N | N | V | `admission_terminal_evidence` | V | N |
| `privacy_unknown` | `registration_id` | `not_requested` | N | N | N | N | N | `unknown` | N | N | N | N |
| `privacy_unknown` | `admission_id` | `not_requested` | N | N | N | N | N | N | N | N | N | N |
| `indeterminate_retryable` | registration selector | `not_requested` or `inconsistent_retryable` | M | N | N | N | N | `indeterminate` | N | N | N | N |
| `indeterminate_retryable` | `admission_id` | `not_requested` | N | N | N | N | N | N | N | N | N | N |

Column names:

```text
C  correlationDisposition
H  correlationSHA256
RG registrationGeneration
RID registrationID
RR registrationRecordSHA256
VG revocationGeneration
SS subjectState
AA targetAdmissionArtifact
AK targetAdmissionArtifactKind
AH targetAdmissionArtifactSHA256
TS tombstoneSHA256
```

Additional exact relations:

- `correlationSHA256` is `V` iff a canonical correlation was requested;
- a superseded row has `SS=active_consented|revoked|deregistered`; `TS=V` iff
  `SS=deregistered`; `RR=V` otherwise;
- every returned admission artifact digest equals SHA-256 of the exact decoded
  artifact bytes;
- `admission_response_available` is forbidden for an original `status`
  operation;
- status never makes a historical response fresh current state;
- a field combination not listed in the matrix is invalid, not an extension.

## 7. Total challenge, admission, replay, and compaction contract

### 7.1 Durable unique indexes

Every challenge ledger row and compacted tombstone participates in:

```text
U1 UNIQUE(
  compositionVersion,
  issuerDescriptorSHA256,
  issuerGeneration,
  challengeID
)

U2 UNIQUE(
  compositionVersion,
  requesterDescriptorSHA256,
  clientIntentID
)

U3 UNIQUE(
  compositionVersion,
  requesterDescriptorSHA256,
  clientNonce
)

U4 UNIQUE(
  compositionVersion,
  intentArtifactSHA256
)
```

All index components are exact canonical bytes or their exact 32-byte digest;
no unframed concatenation is used.

### 7.2 Exact replay equality tuple

An issuance or operation replay is exact only when all applicable values are
byte-equal:

```text
requesterDescriptorSHA256
identityDomain
clientIntentID
clientNonce
exact IntentArtifact bytes
intentArtifactSHA256
challengeID
exact ChallengeArtifact bytes
challengeArtifactSHA256
operation/resource/action/capability/access/statusKind
bodySchema/bodySHA256
admissionID
exact RequestArtifact bytes
requestArtifactSHA256
authority/issuer/revocation generations
agreement/contract/grant/conditions/consent digests
targetCellID/targetOwnerDescriptorSHA256
```

Fields that do not yet exist at issuance are absent from that phase's tuple.

### 7.3 Collision precedence

Inside one serialized transaction:

1. canonical/authentication/authority checks occur;
2. U4 exact intent digest is checked; byte-equal active replay returns exact
   stored challenge bytes;
3. U2 is checked; same requester/intent ID with a different intent is
   `replay_conflict`;
4. U3 is checked; same requester/nonce with a different intent is
   `replay_conflict`;
5. a fresh `challengeID` is generated and U1 inserted;
6. an internal U1 random collision retries with new randomness and exposes no
   record;
7. any other uniqueness failure commits nothing.

Wrong-subject and absent lookup remain `privacy_unknown` with the same outward
shape. Collision errors reveal no colliding field or record state.

### 7.4 Persisted states

Closed state enum:

- `issued_active_unused`;
- `issued_expired_unused`;
- `admitted_active_pending`;
- `admitted_expired_pending`;
- `admitted_active_terminal`;
- `admitted_expired_terminal`;
- `admitted_active_terminal_indeterminate`;
- `admitted_expired_terminal_indeterminate`;
- `admitted_active_terminal_unavailable`;
- `admitted_expired_terminal_unavailable`;
- `compacted_unused_tombstone`;
- `compacted_admitted_tombstone`;
- `compacted_indeterminate_tombstone`;
- `compacted_unavailable_tombstone`.

### 7.5 AdmissionTerminalEvidenceCore

Schema:

`cellprotocol.device-ingress.admission-terminal-evidence-core.v1`

Exact member order:

1. `admissionID`
2. `committedAtMilliseconds`
3. `evidenceCode`
4. `operation`
5. `reasonCode`
6. `requestArtifactSHA256`
7. `requesterDescriptorSHA256`
8. `schema`
9. `serverSequence`
10. `targetCellID`
11. `targetOwnerDescriptorSHA256`

Closed `evidenceCode`:

- `indeterminate`;
- `unavailable`.

Closed sanitized `reasonCode`:

- `authority_history_unavailable`;
- `response_bytes_corrupt`;
- `response_bytes_missing`;
- `rollback_anchor_failed`;
- `target_idempotency_unreadable`;
- `trusted_time_unavailable`.

The artifact kind is `admission_terminal_evidence`. It is signed by the pinned
challenge issuer from the accepted authority catalog, not by transport. It
does not claim target success, target failure, absence, or permission to rerun.
The server may create it only when:

1. admission and exact request identity are durable;
2. no exact target response can be safely read;
3. target idempotency cannot prove that rerun is safe;
4. the issuer authority and rollback anchor remain verifiable;
5. the exact evidence artifact is committed/read back.

If those conditions cannot be met, the admission stays pending and the
operation is unavailable; no unsigned substitute exists.

### 7.6 Total transitions

```text
none
  -> issued_active_unused

issued_active_unused
  -> issued_expired_unused
  -> admitted_active_pending

admitted_active_pending
  -> admitted_expired_pending
  -> admitted_active_terminal
  -> admitted_active_terminal_indeterminate
  -> admitted_active_terminal_unavailable

admitted_expired_pending
  -> admitted_expired_terminal
  -> admitted_expired_terminal_indeterminate
  -> admitted_expired_terminal_unavailable

admitted_active_terminal
  -> admitted_expired_terminal

admitted_active_terminal_indeterminate
  -> admitted_expired_terminal_indeterminate

admitted_active_terminal_unavailable
  -> admitted_expired_terminal_unavailable

issued_expired_unused
  -> compacted_unused_tombstone

admitted_expired_terminal
  -> compacted_admitted_tombstone

admitted_expired_terminal_indeterminate
  -> compacted_indeterminate_tombstone

admitted_expired_terminal_unavailable
  -> compacted_unavailable_tombstone
```

No other transition is permitted. In particular, terminal evidence never
transitions to success/failure response and never authorizes mutation retry.

### 7.7 Input behavior in every state

| State family | Exact same request | Different same-subject request | Wrong subject / unproved locator |
|---|---|---|---|
| `issued_active_unused` | consume once and atomically enter pending | `replay_conflict` | `privacy_unknown` |
| `issued_expired_unused` | `challenge_expired` authenticated error | `replay_conflict` | `privacy_unknown` |
| admitted pending | exact `operation_pending`; status returns `admission_pending` | `replay_conflict` | `privacy_unknown` |
| admitted response terminal | exact stored response bytes | `replay_conflict` | `privacy_unknown` |
| admitted indeterminate terminal | exact stored terminal evidence; status typed indeterminate | `replay_conflict` | `privacy_unknown` |
| admitted unavailable terminal | exact stored terminal evidence; status typed unavailable | `replay_conflict` | `privacy_unknown` |
| compacted unused | exact `challenge_expired` from tombstone facts | `replay_conflict` | `privacy_unknown` |
| compacted admitted | exact response from independent response ledger | `replay_conflict` | `privacy_unknown` |
| compacted indeterminate/unavailable | exact evidence from independent evidence ledger | `replay_conflict` | `privacy_unknown` |

### 7.8 CompactedChallengeTombstoneCore

Schema:

`cellprotocol.device-ingress.compacted-challenge-tombstone-core.v1`

Exact member order:

1. `admissionID`
2. `challengeID`
3. `challengeArtifactSHA256`
4. `clientIntentID`
5. `clientNonce`
6. `expiresAtMilliseconds`
7. `intentArtifactSHA256`
8. `issuerDescriptorSHA256`
9. `issuerGeneration`
10. `operation`
11. `requestArtifactSHA256`
12. `requesterDescriptorSHA256`
13. `schema`
14. `terminalArtifactSHA256`
15. `terminalKind`

Nullable fields are exact null. `terminalKind` is null, `response`,
`indeterminate`, or `unavailable`.

The tombstone retains U1...U4 inputs and exact ledger links. It contains no
body, payload, token, token hash, signature private material, Agreement
content, Contract content, Grant content, or participant metadata.
Compaction is permitted only after expiry, no pending work, exact terminal
artifact independently durable/readable, and rollback-anchor coverage.
Version 2 does not delete compacted tombstones; quota pressure fails closed.

## 8. Exact current logical registration and atomic lifecycle

### 8.1 Derived subject registration key

The undefined S3 `currentLogicalRegistration` component is removed.

```text
subjectRegistrationDigest =
  SHA256(
    LP(UTF8("HAVEN-DEVICE-INGRESS-SUBJECT-REGISTRATION-V1"))
    || LP(UTF8(identityDomain))
    || LP(requesterDescriptorSHA256Raw)
    || LP(UTF8(targetCellID))
  )

subjectRegistrationKey =
  "sreg1_" + Base64url(subjectRegistrationDigest)
```

The key is exactly 49 ASCII bytes.

### 8.2 Unique indexes

```text
UNIQUE(targetCellID, registrationID)

UNIQUE(targetCellID, subjectRegistrationKey)
WHERE lifecycleState IN ('active','revoked')
```

Participation:

| lifecycleState | Partial unique index |
|---|---|
| `active` | yes |
| `revoked` | yes |
| `deregistered` tombstone | no |
| historical/superseded audit row | no |

The global registration-ID index includes active, revoked, deregistered, and
historical rows forever in composition version 2. An old ID is never reused.

### 8.3 Atomic lock/CAS order

Every lifecycle transaction locks in this order:

```text
1 targetCellID
2 subjectRegistrationKey
3 registrationID when non-null
4 admissionID
```

Then it verifies subject, authority catalog generation, Agreement/Contract/
Grant/conditions/consent, exact expected generations, lifecycle state, and
request replay before mutation.

Operations:

- `enroll`: require no active/revoked row under the partial index, allocate a
  new `reg1_` ID, insert `active`, generations `1/0`;
- `update` or `token_rotation`: require the indexed row and ID both identify
  the same active subject row; increment registration generation once;
- `reactivate`: require the indexed row and ID identify the same revoked row,
  fresh consent/token, and exact CAS; change to active and increment
  registration generation once;
- `revoke`: require active row; remove it from delivery lookup, retain it in
  the partial unique index as revoked, increment revocation generation once;
- `deregister`: require active or revoked row; delete active/recoverable
  endpoint/token material, write terminal tombstone, change lifecycle to
  deregistered, and thereby leave the partial index in the same transaction.

Read-back of row, indexes, generations, receipt, and exact response occurs
before commit is released.

Two concurrent enrollments for the same key serialize; at most one succeeds.
A random registration-ID collision retries internally without releasing a
response. Restart replays the committed transaction log and rechecks both
indexes before readiness. Wrong-subject ID and absent ID have identical
outward `privacy_unknown`.

## 9. Algebraically satisfiable maxima

All maxima are inclusive decoded byte counts. Decoders reject before unbounded
allocation. No truncation or inner compression is allowed.

### 9.1 Wrapper equations

The exact fixed CJP-1 literal overhead is:

```text
SignatureEnvelopeFixed = 14 + 76 + 2 = 92
SignedArtifactFixed    =  9 + 81 + 2 = 92
OperationRequestFixed  =  9 + 13 + 62 = 84
```

Therefore:

```text
Envelope(P,S) = 92 + B64(P) + B64(S)
Artifact(C,E) = 92 + B64(C) + B64(E)
OperationRequest(B,R) = 84 + B64(B) + B64(R)
```

Where `P` is protected-core bytes, `S` raw signature bytes, `C` core bytes,
`E` envelope bytes, `B` body bytes, and `R` signed request artifact bytes.

Exact limits:

```text
SignatureProtectedCoreMax = 500
RawSignatureMax           = 1024
SignatureEnvelopeMax      = Envelope(500,1024) = 2125
```

The protected-core maximum is derived from:

- algorithm 64;
- longest allowed artifact kind 26;
- core digest 64;
- key ID 128;
- exact schema literal;
- signer descriptor 64;
- exact field-name/quote/comma/bracket bytes.

### 9.2 Core and wrapper maxima

| Object | Inclusive maximum | Derived signed/wrapper maximum |
|---|---:|---:|
| IntentCore | 8192 | `Artifact(8192,2125) = 13849` |
| ChallengeCore | 16384 | `Artifact(16384,2125) = 24772` |
| RequestCore | 16384 | `Artifact(16384,2125) = 24772` |
| RegisterBodyCore | 6065 | n/a |
| ResolveBodyCore | 65536 | n/a |
| SubmitBodyCore | 65536 | n/a |
| StatusBodyCore | 8192 | n/a |
| RevokeBodyCore | 4096 | n/a |
| DeregisterBodyCore | 4096 | n/a |
| normal ResultCore | 65536 | n/a |
| normal ResponseCore | `1046 + B64(65536) = 88428` | `Artifact(88428,2125) = 120830` |
| admission StatusResultCore | `566 + B64(120830) = 161673` | n/a |
| admission-readback ResponseCore | `1046 + B64(161673) = 216610` | `Artifact(216610,2125) = 291740` |

`1046` is the complete maximum ResponseCore v2 byte count with an empty
`result`, using every exact fixed member, a 96-byte result-schema value, a
128-byte target Cell ID, the longest operation, and maximum UInt64 decimals.

`566` is the complete `admission_response_available` StatusResultCore v2 byte
count with an empty target artifact and the exact matrix nullability. It
includes every field name, quote, comma, bracket, schema, selector, status
code, digest, and maximum timestamp decimal.

The largest canonical operation request is:

```text
OperationRequest(65536,24772) = 120496
```

The register request bound is:

```text
OperationRequest(6065,24772) = 41201
```

An outer transport carrier must accept at least `291740` opaque application
bytes plus its exact reviewed framing overhead. This requirement does not
select that framing.

### 9.3 Boundary vectors

The producer manifest must contain exact acceptance vectors for each of:

```text
protected core: 499 / 500 / 501
signature: 1023 / 1024 / 1025
envelope: 2124 / 2125 / 2126
each core maximum: max-1 / max / max+1
each signed artifact maximum: max-1 / max / max+1
operation request: 120495 / 120496 / 120497
normal response artifact: 120829 / 120830 / 120831
admission response artifact: 291739 / 291740 / 291741
```

The first two are accepted only when the configured test algorithm makes those
semantic lengths valid. `max+1` always fails before signature/authority use.
Decoded and encoded lengths are asserted separately.

## 10. Typed requester, target, owner, signer, and first enrollment

### 10.1 Typed reference cores

`RequesterSubjectRefCore`

Schema:
`cellprotocol.device-ingress.requester-subject-ref-core.v1`

Member order:

1. `identityDomain`
2. `requesterDescriptorSHA256`
3. `schema`

`TargetCellRefCore`

Schema:
`cellprotocol.device-ingress.target-cell-ref-core.v1`

Member order:

1. `resource`
2. `schema`
3. `scope`
4. `targetCellID`

`scope` is exactly `identity_unique` or `scaffold_unique`.

`TargetOwnerRefCore`

Schema:
`cellprotocol.device-ingress.target-owner-ref-core.v1`

Member order:

1. `ownerDescriptorSHA256`
2. `schema`
3. `targetCellID`

`ResponseSignerRefCore`

Schema:
`cellprotocol.device-ingress.response-signer-ref-core.v1`

Member order:

1. `algorithm`
2. `keyID`
3. `role`
4. `schema`
5. `signerDescriptorSHA256`

`role` is `target_owner` or `challenge_issuer`.

### 10.2 SubjectTargetBindingCore

Schema:

`cellprotocol.device-ingress.subject-target-binding-core.v1`

Exact member order:

1. `authorityGeneration`
2. `bindingID`
3. `notAfterMilliseconds`
4. `notBeforeMilliseconds`
5. `requesterSubject`
6. `responseSigner`
7. `schema`
8. `targetCell`
9. `targetOwner`

The three nested refs are Base64url exact canonical core bytes. `bindingID` is
1...128 ASCII from the signed authority catalog.

The relation is:

```text
requester subject
  -> exact pre-existing target Cell
  -> exact target owner
  -> exact response signer owned by that target owner
```

For `cell:///DeviceRegistration`, target scope is `identity_unique`; the
authenticated device subject does not imply ownership of the server-side
Cell signing key. The signed binding maps the device subject to a pre-existing
server-owned target instance. For `cell:///DeviceCallbackBridge`, scope is
`scaffold_unique` and the catalog binds authorized subjects to the one
pre-existing target.

### 10.3 No-create lookup and first enrollment interface

Normative server interface:

```text
resolveExistingSubjectTarget(
  requesterSubjectRefBytes,
  resource,
  acceptedAuthorityCatalogGeneration
) -> exact SubjectTargetBindingArtifact | unavailable
```

It:

- performs no Cell, owner, key, descriptor, vault, or binding creation;
- registers only an exact recovered persistent Cell instance;
- reads back Cell ID, resource, scope, persistency, lifecycle, owner, signer,
  and authority generation;
- requires response/tombstone signer equality with the binding;
- returns unavailable on zero or multiple exact bindings.

First enrollment means no registration row exists. It does not mean the target
Cell/owner may be created. A first enrollment proceeds only when a separately
provisioned and signed subject-target binding already exists. Provisioning and
Identity cutover are separate authority work and remain closed.

If Identity, authority, owner, key, target, binding, or no-create vault input
is missing, locked, changed, ambiguous, or unverifiable:

```text
accepted requester descriptors = EMPTY
accepted target cells           = EMPTY
accepted target owners          = EMPTY
accepted response signers       = EMPTY
affected readiness              = UNAVAILABLE
```

There is never auto-provisioning.

## 11. Exact authorization and consent catalog

### 11.1 ConsentArtifactCore

Schema:

`cellprotocol.device-ingress.consent-artifact-core.v1`

Exact member order:

1. `audience`
2. `consentGeneration`
3. `consentID`
4. `expiresAtMilliseconds`
5. `identityDomain`
6. `issuedAtMilliseconds`
7. `operation`
8. `purpose`
9. `requesterDescriptorSHA256`
10. `resource`
11. `schema`
12. `targetCellID`

The artifact is signed by the exact requester subject and uses
`artifactKind=consent`. It is not an Agreement, owner authorization, or Grant.

### 11.2 AuthorizationCatalogEntryCore

Schema:

`cellprotocol.device-ingress.authorization-catalog-entry-core.v1`

Exact member order:

1. `agreementArtifact`
2. `agreementSHA256`
3. `conditionsArtifact`
4. `conditionsSHA256`
5. `consentArtifact`
6. `consentSHA256`
7. `contractArtifact`
8. `contractSHA256`
9. `entryGeneration`
10. `entryID`
11. `grantArtifact`
12. `grantSHA256`
13. `notAfterMilliseconds`
14. `notBeforeMilliseconds`
15. `operation`
16. `purpose`
17. `requesterDescriptorSHA256`
18. `requiredAccess`
19. `resource`
20. `schema`
21. `state`
22. `targetCellID`
23. `targetOwnerDescriptorSHA256`

Artifact members are Base64url exact complete signed artifact bytes.
Every paired digest is SHA-256 of those exact bytes.

Closed `state`:

- `accepted`;
- `revoked`;
- `expired`.

The catalog entry is itself not authority until its containing catalog is
owner-signed and independently linked to the accepted authority manifest.

### 11.3 AuthorizationCatalogCore and envelope

Schema:

`cellprotocol.device-ingress.authorization-catalog-core.v1`

Exact member order:

1. `authorityGeneration`
2. `catalogGeneration`
3. `entries`
4. `issuedAtMilliseconds`
5. `schema`
6. `targetOwnerDescriptorSHA256`

`entries` is an array of Base64url exact
`AuthorizationCatalogEntryCore` bytes, sorted lexicographically by `entryID`
raw ASCII. Duplicate entry IDs, tuples, or generations fail.

The catalog uses the S3 core → protected core → signature envelope → signed
artifact construction with:

```text
artifactKind = authorization_catalog
signer = exact target owner or independently authorized catalog signer
```

The protected core member order remains S3. The allowed artifact-kind enum is
extended exactly with:

- `authenticated_error`;
- `admission_terminal_evidence`;
- `authorization_catalog`;
- `consent`.

The catalog signature is not a substitute for validating every nested
Agreement, Contract, Grant, Conditions, or consent signature and relationship.

### 11.4 AuthorizationImportLedgerCore

Schema:

`cellscaffold.device-ingress.authorization-import-ledger-core.v1`

Exact member order:

1. `acceptedEntryIDs`
2. `authorityGeneration`
3. `catalogArtifactSHA256`
4. `catalogGeneration`
5. `conditionUnsatisfiedEntryIDs`
6. `expiredEntryIDs`
7. `importSequence`
8. `importedAtMilliseconds`
9. `revokedEntryIDs`
10. `schema`
11. `targetOwnerDescriptorSHA256`

Arrays are sorted ASCII and disjoint. Import is one atomic transaction:

1. verify manifest, owner/catalog signer, catalog envelope, every nested
   artifact, tuple, generation, validity, revocation, and consent relationship;
2. compute all state arrays;
3. commit exact catalog bytes plus ledger;
4. read back bytes, digests, sequence, and indexes;
5. advance rollback anchor;
6. only then expose accepted entries.

Restart repeats exact read-back and use-time verification. Restore or rollback
below the anchor empties the accepted set. At challenge and operation use time,
the exact entry must still be `accepted`; all nested bytes/digests, conditions,
trusted time, revocation, target owner, subject, operation tuple, purpose,
audience, and access are rechecked.

Actual owner-signed catalog, Agreement, Contract, Grant, Conditions, and
requester consent bytes are missing. Therefore the production accepted set is
currently empty and all affected readiness is unavailable.

## 12. Opaque variable-length APNS token

`RegisterBodyCore` is corrected to schema:

`cellprotocol.device-ingress.register-body-core.v2`

Its member order remains S3. `apnsToken` is:

```text
1...4096 raw opaque bytes
encoded as canonical unpadded Base64url
```

This `4096` limit is a conservative HAVEN protocol/resource allocation bound.
It is not a claim about Apple's current or future token length. If an
authoritative platform contract later requires a larger value, a new reviewed
composition version is required.

Exact relationships:

```text
raw 4095 -> Base64url 5460 -> maximum-field RegisterBodyCore 6063
raw 4096 -> Base64url 5462 -> maximum-field RegisterBodyCore 6065
raw 4097 -> Base64url 5463 -> reject before allocation beyond bound
raw 0    -> reject
```

Boundary fixtures contain only generated non-token opaque test bytes and
sanitized length metadata. No raw APNS token or token hash may appear in a
document, fixture manifest, evidence ledger, log, diagnostic, analytics,
crash report, export, UI, or accessibility output.

## 13. Legacy plaintext quarantine and disposal evidence

### 13.1 Detection without plaintext access

Startup inventory may inspect only:

- database schema/table/column metadata;
- migration version;
- row counts using predicates that do not select token values;
- presence, path, size, ownership, and protection class of database, WAL, SHM,
  rollback journal, backup, snapshot, and export artifacts;
- sealed-store format/version metadata.

Application code MUST NOT select, display, log, export, hash for telemetry, or
otherwise read a legacy plaintext token column. A legacy column, row, WAL,
journal, free-page risk, backup, snapshot, or unknown migration state sets:

```text
DeviceIngress readiness = RED
provider delivery readiness = RED
register/update/reactivate/token_rotation = UNAVAILABLE
legacy rows eligible for delivery = false
```

### 13.2 Only two allowed remediation branches

1. **Attested sealed-store migration:** a separately reviewed storage-bound
   primitive consumes the legacy value internally and writes/read-backs the
   sealed record without returning plaintext to application code, logs,
   telemetry, fixtures, or evidence. It is crash-restart idempotent and
   quarantines all source artifacts until disposal evidence is complete.
2. **Fail-closed deactivation:** mark affected registrations inactive without
   reading token values, remove them from delivery lookup, require fresh
   re-enrollment, recreate a clean sealed store under reviewed storage
   procedure, and quarantine the legacy artifacts.

There is no application-level “read then encrypt” migration.

### 13.3 Artifact inventory and disposal evidence plan

Sanitized inventory records:

```text
artifact class
opaque inventory ID unrelated to content
path class, not user path content
byte count
protection class
quarantine state
backup/snapshot scope
procedure version
owner
started/completed timestamps
verification decision
```

It records no token, token hash, ciphertext, nonce, tag, key reference,
registration ID, subject descriptor, or payload.

The storage/privacy owner must later supply a reviewed secure-disposal or
approved-retention procedure covering database, WAL, SHM, rollback journal,
free pages, backups, snapshots, exports, restored copies, and key destruction.
Logical SQL deletion alone is not secure-disposal proof. A restored legacy
artifact re-enters quarantine and can never reactivate delivery.

Readiness remains red until inventory is complete, every artifact has an
approved terminal disposition and read-back evidence, rollback/restore tests
pass, and the separate retention decision permits the result.

## 14. Crash-durable ResponseExpectationCore for every operation

### 14.1 Schema

Schema:

`binding.device-ingress.response-expectation-core.v1`

Exact member order:

1. `admissionID`
2. `agreementSHA256`
3. `authorityCatalogSHA256`
4. `authorityGeneration`
5. `bodySHA256`
6. `buildProvenanceSHA256`
7. `challengeArtifactSHA256`
8. `conditionsSHA256`
9. `contractSHA256`
10. `expectedResultSchema`
11. `expectedResponseSchema`
12. `expectationID`
13. `grantSHA256`
14. `identityDomain`
15. `intentArtifactSHA256`
16. `issuerDescriptorSHA256`
17. `issuerGeneration`
18. `minimumRegistrationGeneration`
19. `minimumRevocationGeneration`
20. `minimumServerSequence`
21. `operation`
22. `purpose`
23. `requestArtifactSHA256`
24. `requesterDescriptorSHA256`
25. `requiredAccess`
26. `resource`
27. `responseSigner`
28. `schema`
29. `statusKind`
30. `targetCellID`
31. `targetOwnerDescriptorSHA256`
32. `validUntilMilliseconds`
33. `vaultBindingSHA256`

```text
expectationID = "exp1_" + Base64url(CSPRNG(32 bytes))
```

It is exactly 48 ASCII bytes. `responseSigner` is Base64url exact
`ResponseSignerRefCore` bytes. Nullable `statusKind` is present.

### 14.2 Digest and journal binding

```text
expectationSHA256 =
  lowercaseHex(SHA256(exact ResponseExpectationCore bytes))
```

Every operation journal contains `expectationID` and
`expectationSHA256`. The expectation and journal are committed/read back in
the same local transaction before `send_started_ambiguous`, for all six
operations including both status kinds.

It excludes:

- raw token or token hash;
- body, request, response, or unredacted payload bytes;
- private key;
- bearer credential;
- shared server secret;
- reversible secret derivative.

### 14.3 Historical verification

A live/current descriptor does not redefine a historical expectation.
Historical response verification requires:

1. exact expectation digest and current-vault rebind;
2. exact stored authority catalog and rotation/revocation proof covering the
   expectation time;
3. exact historical signer descriptor/key/algorithm from `responseSigner`;
4. exact target, owner, Agreement, Contract, Grant, Conditions, operation
   tuple, result schema, generations, sequence floor, validity, and artifact
   digests;
5. verification of exact nested historical response bytes;
6. fresh signed status separately when current truth is required.

Missing historical authority material yields `blocked_authority_history`; it
never accepts the current key as a substitute and never reconstructs or
re-signs a response.

## 15. Total Binding local reducer

### 15.1 Durable OperationJournalCore

Schema:

`binding.device-ingress.operation-journal-core.v1`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `expectationID`
5. `expectationSHA256`
6. `intentArtifactSHA256`
7. `journalID`
8. `operation`
9. `requestArtifactSHA256`
10. `schema`
11. `sendState`
12. `statusKind`

Operation-specific non-secret correlation is stored in a separately typed,
digest-bound extension:

- register: registration ID/generations, mutation mode, observation ID, epoch;
- resolve: ticket ID/lineage/content-contract digests;
- submit: ticket ID/lineage/resolve admission ID;
- status: selector and selector/correlation digest;
- revoke/deregister: registration ID and expected generations.

No extension contains token, token hash, body/request/payload/private bytes, or
shared secret.

### 15.2 Cross-process single flight

```text
operationResourceKey =
  lowercaseHex(
    SHA256(
      LP(UTF8(compositionVersion))
      || LP(vaultBindingSHA256Raw)
      || LP(UTF8(operation))
      || LP(UTF8(statusKind or "none"))
      || LP(UTF8(targetCellID))
      || LP(selectorOrSubjectRegistrationKeyBytes)
    )
  )
```

One descriptor-relative file/store lock plus one durable CAS row serializes
each key across actors, processes, relaunch, and extensions. A second process
observes the durable state and may request status read-back; it never sends a
different request through an ambiguous boundary.

### 15.3 Closed reducer states

- `local_unknown`;
- `challenge_preparing`;
- `challenge_verified`;
- `request_prepared_expectation_durable`;
- `send_started_ambiguous`;
- `response_verification_pending`;
- `admission_readback_pending`;
- `historical_response_verified`;
- `fresh_status_pending`;
- `finalization_pending`;
- `finalized_register_current`;
- `finalized_resolve`;
- `finalized_submit`;
- `finalized_status`;
- `finalized_revoked`;
- `finalized_deregistered`;
- `finalized_superseded`;
- `finalized_not_committed`;
- `abandoned_before_send`;
- `blocked_privacy_unknown`;
- `blocked_authority_history`;
- `blocked_indeterminate`;
- `blocked_unavailable`.

### 15.4 Common transition graph

```text
local_unknown
  -> challenge_preparing

challenge_preparing
  -> challenge_verified
  -> blocked_unavailable

challenge_verified
  -> request_prepared_expectation_durable
  -> abandoned_before_send

request_prepared_expectation_durable
  -> send_started_ambiguous
  -> abandoned_before_send

send_started_ambiguous
  -> response_verification_pending
  -> admission_readback_pending

response_verification_pending
  -> historical_response_verified
  -> admission_readback_pending
  -> blocked_authority_history
  -> blocked_indeterminate

admission_readback_pending
  -> historical_response_verified
  -> finalized_not_committed
  -> blocked_privacy_unknown
  -> blocked_indeterminate
  -> blocked_unavailable

historical_response_verified
  -> fresh_status_pending
  -> finalization_pending

fresh_status_pending
  -> finalization_pending
  -> finalized_superseded
  -> blocked_privacy_unknown
  -> blocked_indeterminate

finalization_pending
  -> one operation-specific finalized state
```

Every transition is one atomic compare-and-swap plus read-back. No terminal UI
truth is published before read-back.

### 15.5 Operation-specific terminal rules

| Operation | Fresh status required | Terminal truth |
|---|---|---|
| register | yes, registration/correlation | current only on `correlation_current_active`; otherwise superseded/not committed/blocked |
| resolve | no unless result semantics request current registration | verified payload delivered once; unredacted payload not durably retained |
| submit | no unless result semantics request current registration | verified receipt; no blind resend after ambiguity |
| status | response itself must be fresh | exact mapped status, never collapsed negatives |
| revoke | yes, subject current | revoked only after verified receipt and `subject_current_revoked` |
| deregister | yes when a retained tombstone may be disclosed | local cleanup sequence below |

### 15.6 Authoritative deregister to local truth

Required order:

1. verify the authoritative response, minimal tombstone, and pre-send
   expectation;
2. obtain required fresh signed current status without treating local absence
   as proof;
3. enter `finalization_pending`;
4. atomically erase every local raw token value and active binding/default;
5. read back that no raw token/active binding remains;
6. retain only the minimal signed tombstone and non-secret expectation/journal
   fields allowed by the still-open owner retention decision;
7. read back the local tombstone transaction;
8. publish `deregistered` only when owner policy permits; otherwise publish
   `unknown`;
9. enter `finalized_deregistered`.

Crash windows:

- before authoritative verification: preserve recovery handles, publish
  unknown;
- after server commit but before local erase: restart → admission read-back →
  historical verification → fresh status → local erase;
- during local erase: transaction recovery repeats erase/read-back;
- after erase but before tombstone commit/UI: token remains absent, recovery
  uses expectation/status, UI remains unknown;
- after tombstone commit but before UI: read back then publish;
- local erase before verified authoritative commit is forbidden.

Revoke never executes deregister cleanup. Deregister never retains an active
token/binding.

## 16. Binding CellApple vault and evidence continuity

Binding uses exactly one already-existing persistent CellApple Identity vault:

```text
domain:device:notification-callback
```

Normative interface:

```text
openExistingPersistentVault(domain, expectedDescriptor)
  -> vault + signing key + continuity evidence
  | unavailable
```

Creation, ephemeral fallback, owner refresh that creates, and
`makeNewIfNotFound=true` are forbidden.

`VaultBindingCore`

Schema:
`binding.device-ingress.vault-binding-core.v1`

Exact member order:

1. `approvedBuildProvenanceSHA256`
2. `identityDomain`
3. `requesterDescriptorSHA256`
4. `schema`
5. `signingKeyFingerprintSHA256`
6. `vaultInstanceID`

`vaultInstanceID` is an opaque persistent CellApple identifier, 1...128 ASCII,
not a secret or authority by itself.

Every journal, expectation, and local evidence record is digest-bound to exact
`VaultBindingCore` bytes. On every open/restart/restore:

1. open existing vault no-create;
2. verify domain, descriptor, key fingerprint, vault instance, approved build
   provenance, storage protection, and evidence MAC/signature;
3. reject copied evidence from a different device/vault/key/build;
4. reject restored evidence below local monotonic/rollback anchor;
5. reject legacy evidence lacking the complete binding;
6. only then use an expectation for historical verification.

Missing, locked, ephemeral, changed, ambiguous, or rejected vault/evidence
sets local state to `UNKNOWN` and affected readiness to unavailable. Local
absence never means server “not registered,” revoked, or deregistered.

No bearer token, shared server secret, legacy Authorization value, route
possession, or TLS state substitutes for the vault Identity.

Actual Identity descriptors, keys, rotation records, recovery proof, and
cutover evidence remain missing and separate. Therefore no operation is
production-ready.

## 17. Exact future package/source/test/docs ownership

This is a future allowlist and collision ledger only. It grants no write
authority. A path not listed requires a new document-only decision and
independent review.

### 17.1 CellProtocol producer

Exact future source/docs paths:

```text
Package.swift
Sources/CellBase/DeviceIngress/DeviceIngressCanonicalJSON.swift
Sources/CellBase/DeviceIngress/DeviceIngressSignatureEnvelope.swift
Sources/CellBase/DeviceIngress/DeviceIngressCompositionCore.swift
Sources/CellBase/DeviceIngress/DeviceIngressIdentifiers.swift
Sources/CellBase/DeviceIngress/DeviceIngressOperationBodies.swift
Sources/CellBase/DeviceIngress/DeviceIngressResultCores.swift
Sources/CellBase/DeviceIngress/DeviceIngressStatusContract.swift
Sources/CellBase/DeviceIngress/DeviceIngressAuthenticatedErrors.swift
Sources/CellBase/DeviceIngress/DeviceIngressChallengeLedgerContract.swift
Sources/CellBase/DeviceIngress/DeviceIngressRegistrationLifecycle.swift
Sources/CellBase/DeviceIngress/DeviceIngressAuthorityCatalogContract.swift
Sources/CellBase/DeviceIngress/DeviceIngressAuthenticatedBoundary.swift
Sources/CellDeviceIngressTransport/DeviceIngressOpaqueTransport.swift
Docs/DeviceIngressNormativeCompositionV2.md
```

Exact future tests:

```text
Tests/CellBaseTests/DeviceIngressCanonicalCompositionTests.swift
Tests/CellBaseTests/DeviceIngressResultStatusErrorTests.swift
Tests/CellBaseTests/DeviceIngressIdentifierCASTests.swift
Tests/CellBaseTests/DeviceIngressChallengeLedgerTests.swift
Tests/CellBaseTests/DeviceIngressRegistrationLifecycleTests.swift
Tests/CellBaseTests/DeviceIngressAuthorityCatalogTests.swift
Tests/CellBaseTests/DeviceIngressNestedMaximaTests.swift
Tests/CellDeviceIngressTransportTests/DeviceIngressOpaqueTransportTests.swift
Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV2/manifest.json
```

Exact SwiftPM boundary:

- `Package.swift` is development-admin collision-owned for final package graph;
- product `CellDeviceIngressTransport` exposes target
  `CellDeviceIngressTransport`;
- target `CellDeviceIngressTransport` has no dependency on `CellBase` and may
  import only platform byte/container primitives;
- test target `CellDeviceIngressTransportTests` depends only on
  `CellDeviceIngressTransport`;
- existing `CellBase` target owns all semantic cores;
- existing `CellBaseTests` consumes fixture resources at
  `Fixtures/DeviceIngressCompositionV2`;
- semantic consumers import `CellBase`; transport consumers import
  `CellDeviceIngressTransport`; the transport target never imports or calls a
  CJP/core decoder.

### 17.2 CellScaffold server

Exact future paths and one responsibility each:

```text
Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityManifest.swift
  owner: Lane B authority-manifest verifier

Sources/App/Cells/DeviceIngress/DeviceIngressAuthorityCatalogCell.swift
  owner: Lane B pre-existing catalog Cell adapter

Sources/App/Cells/DeviceIngress/DeviceIngressAgreementCatalog.swift
  owner: Lane B catalog import/use ledger

Sources/App/Cells/DeviceIngress/DeviceIngressChallengeIssuerCell.swift
  owner: Lane B pre-existing challenge signer Cell adapter

Sources/App/Cells/DeviceIngress/DeviceIngressResolverRegistration.swift
  owner: Lane B no-create registration/read-back

Sources/App/Cells/DeviceIngress/DeviceIngressChallengeStateMachine.swift
  owner: Lane B U1...U4 and total state transitions

Sources/App/Cells/DeviceIngress/DeviceIngressAdmissionStore.swift
  owner: Lane B admission/terminal evidence ledger

Sources/App/Cells/DeviceIngress/DeviceIngressResponseStore.swift
  owner: Lane B exact response read-back

Sources/App/Cells/DeviceIngress/DeviceIngressRegistrationStore.swift
  owner: Lane B registration indexes/CAS

Sources/App/Cells/DeviceIngress/DeviceIngressTokenStore.swift
  owner: Lane B sealed store and legacy quarantine

Sources/App/Cells/DeviceIngress/DeviceIngressRegistrationTargetAdapter.swift
  owner: Lane B register/status/revoke/deregister target invocation

Sources/App/Cells/DeviceIngress/DeviceIngressCallbackTargetAdapter.swift
  owner: Lane B resolve/submit target invocation

Sources/App/Cells/DeviceIngress/DeviceIngressRegistrationStatusService.swift
  owner: Lane B subject/ID/correlation status

Sources/App/Cells/DeviceIngress/DeviceIngressAdmissionStatusService.swift
  owner: Lane B admission artifact read-back

Sources/App/Cells/DeviceIngress/DeviceIngressRevokeService.swift
  owner: Lane B revoke orchestration

Sources/App/Cells/DeviceIngress/DeviceIngressDeregisterService.swift
  owner: Lane B authoritative deletion/tombstone

Sources/App/Cells/DeviceIngress/DeviceIngressCompositionCoordinator.swift
  owner: Lane B bootstrap/readiness only

Documentation/Operations/DeviceIngress_Normative_Composition_Runbook.md
  owner: Lane B sanitized operations evidence
```

Exact future tests/ledgers:

```text
Tests/AppTests/DeviceIngressNormativeCompositionConsumerTests.swift
Tests/AppTests/DeviceIngressAuthorityBootstrapTests.swift
Tests/AppTests/DeviceIngressAuthorizationCatalogImportTests.swift
Tests/AppTests/DeviceIngressChallengeTotalStateTests.swift
Tests/AppTests/DeviceIngressAdmissionRestartTests.swift
Tests/AppTests/DeviceIngressRegistrationCASTests.swift
Tests/AppTests/DeviceIngressStatusMatrixTests.swift
Tests/AppTests/DeviceIngressResponseReadBackTests.swift
Tests/AppTests/DeviceIngressTokenBoundaryTests.swift
Tests/AppTests/DeviceIngressLegacyTokenQuarantineTests.swift
Tests/AppTests/DeviceIngressRevokeTests.swift
Tests/AppTests/DeviceIngressDeregisterDeletionTests.swift
Tests/AppTests/Fixtures/DeviceIngressCompositionV2/producer-manifest-consumption.json
Tests/AppTests/Fixtures/DeviceIngressCompositionV2/server-negative-evidence.json
```

### 17.3 Binding client include paths

Existing Lane C-owned paths:

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

Exact new Lane C-owned paths:

```text
Binding/DeviceIngress/DeviceIngressCanonicalComposition.swift
Binding/DeviceIngress/DeviceIngressClientStateMachine.swift
Binding/DeviceIngress/DeviceIngressClientEvidenceStore.swift
Binding/DeviceIngress/DeviceIngressChallengeIntentState.swift
Binding/DeviceIngress/DeviceIngressOperationRecovery.swift
Binding/DeviceIngress/DeviceIngressResponseExpectation.swift
Binding/DeviceIngress/DeviceIngressResponseVerifier.swift
Binding/DeviceIngress/DeviceIngressStatusMapping.swift
Binding/DeviceIngress/DeviceIngressTokenObservation.swift
Binding/DeviceIngress/DeviceIngressVaultContinuity.swift
Binding/DeviceIngress/DeviceIngressHTTPTransport.swift
BindingTests/DeviceIngressCanonicalCompositionConsumerTests.swift
BindingTests/DeviceIngressClientStateMachineTests.swift
BindingTests/DeviceIngressClientEvidenceStoreTests.swift
BindingTests/DeviceIngressChallengeIntentStateTests.swift
BindingTests/DeviceIngressOperationRecoveryTests.swift
BindingTests/DeviceIngressResponseExpectationTests.swift
BindingTests/DeviceIngressResponseVerifierTests.swift
BindingTests/DeviceIngressStatusMappingTests.swift
BindingTests/DeviceIngressTokenRotationTests.swift
BindingTests/DeviceIngressVaultContinuityTests.swift
BindingTests/DeviceIngressDeregisterLocalCleanupTests.swift
BindingTests/DeviceIngressHTTPTransportTests.swift
BindingTests/DeviceIngressPrivacyTests.swift
BindingTests/Fixtures/DeviceIngressSharedFixtureManifest.json
BindingTests/Fixtures/DeviceIngressLocalStateV1.json
Documentation/DeviceIngress_Client_Recovery_V2.md
Documentation/DeviceIngress_Binding_Privacy_And_Recovery_V2.md
```

### 17.4 Development-admin collision paths

Only a later explicitly authorized development-admin integration owns:

```text
Package.swift
Binding.xcodeproj/project.pbxproj
Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

`Package.resolved` changes only if a later independently selected dependency
requires it. No dependency resolution is authorized here.

### 17.5 Immutable/no-touch paths

Apple release owner, not Lane C:

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

Separately owned/no-touch:

```text
Binding/Binding-iOS.entitlements
```

Lane C owns no CellProtocol, CellScaffold, Identity, provider, AASA,
deployment, staging, portal, secret, signing, or Apple-release file.

## 18. Exact producer fixture and consumer ledger

### 18.1 Producer fixture filenames

All under:

`Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV2/`

```text
manifest.json
keys/test-signer-public.json
keys/test-signer-private.invalid-for-production.json
cores/register-receipt.positive.json
cores/resolve-result.positive.json
cores/submit-receipt.positive.json
cores/revoke-receipt.positive.json
cores/deregister-receipt.positive.json
cores/status-result.subject-current-active.json
cores/status-result.subject-current-revoked.json
cores/status-result.subject-current-deregistered.json
cores/status-result.subject-current-unknown.json
cores/status-result.correlation-current-active.json
cores/status-result.correlation-superseded.json
cores/status-result.correlation-not-found.json
cores/status-result.correlation-inconsistent.json
cores/status-result.admission-response-available.json
cores/status-result.admission-pending.json
cores/status-result.admission-terminal-indeterminate.json
cores/status-result.admission-terminal-unavailable.json
cores/status-result.privacy-unknown-registration.json
cores/status-result.privacy-unknown-admission.json
cores/status-result.indeterminate.json
cores/authenticated-error.positive.json
cores/admission-terminal-evidence.indeterminate.json
cores/admission-terminal-evidence.unavailable.json
cores/authorization-catalog.positive.json
cores/consent-artifact.positive.json
ids/admission-id.positive.json
ids/admission-id.collision.json
ids/registration-id.collision.json
ids/subject-registration-key.positive.json
ids/submission-id.collision.json
challenge/replay-exact.json
challenge/replay-intent-id-conflict.json
challenge/replay-client-nonce-conflict.json
challenge/replay-intent-digest-conflict.json
challenge/replay-wrong-subject-privacy.json
challenge/pending-active.json
challenge/pending-expired.json
challenge/terminal-response.json
challenge/terminal-indeterminate.json
challenge/terminal-unavailable.json
challenge/compacted-unused.json
challenge/compacted-admitted.json
challenge/compacted-indeterminate.json
challenge/compacted-unavailable.json
registration/enroll-concurrent.json
registration/update-cas.json
registration/reactivate-cas.json
registration/revoke-cas.json
registration/deregister-cas.json
registration/restart-index-readback.json
registration/tombstone-id-reuse.json
catalog/import-accepted.json
catalog/import-revoked.json
catalog/import-expired.json
catalog/import-condition-unsatisfied.json
catalog/import-substituted-consent.json
catalog/import-rollback.json
limits/token-raw-0.reject.json
limits/token-raw-4095.accept.json
limits/token-raw-4096.accept.json
limits/token-raw-4097.reject.json
limits/protected-499.accept.json
limits/protected-500.accept.json
limits/protected-501.reject.json
limits/normal-response-120829.accept.json
limits/normal-response-120830.accept.json
limits/normal-response-120831.reject.json
limits/admission-response-291739.accept.json
limits/admission-response-291740.accept.json
limits/admission-response-291741.reject.json
operations/register.tuple.json
operations/resolve.tuple.json
operations/submit.tuple.json
operations/status-registration.tuple.json
operations/status-admission.tuple.json
operations/revoke.tuple.json
operations/deregister.tuple.json
operations/token-rotation-as-register.json
negative/noncanonical-member-order.json
negative/unknown-member.json
negative/duplicate-member.json
negative/base64-padding.json
negative/result-digest-substitution.json
negative/result-schema-substitution.json
negative/status-field-substitution.json
negative/response-signer-substitution.json
negative/agreement-substitution.json
negative/contract-substitution.json
negative/grant-substitution.json
negative/conditions-substitution.json
negative/consent-substitution.json
negative/test-key-production-rejection.json
```

The manifest schema remains the S3 entry schema and adds:

- `compositionVersion`;
- `boundaryDecodedBytes`;
- `boundaryEncodedBytes`;
- `sanitizedReasonCode`;
- `owner`;
- `consumerRequired`.

Entries are lexicographically sorted by exact relative path. The test private
material is deterministic, test-only, and explicitly rejected by production
composition.

### 18.2 Consumer manifest ledger

Server ledger path:

`Tests/AppTests/Fixtures/DeviceIngressCompositionV2/producer-manifest-consumption.json`

Binding ledger path:

`BindingTests/Fixtures/DeviceIngressSharedFixtureManifest.json`

Schema:

`haven.device-ingress.fixture-consumer-ledger.v1`

Exact member order:

1. `consumer`
2. `entries`
3. `producerManifestByteCount`
4. `producerManifestSHA256`
5. `schema`

Each entry member order:

1. `decodedCoreSHA256`
2. `decision`
3. `fileByteCount`
4. `fileSHA256`
5. `path`
6. `role`
7. `schema`
8. `testKeyRejectedInProduction`
9. `testPath`

Rules:

- consumers reference package/resource bytes or exact copied bytes whose
  byte count and SHA match; they never regenerate a signed expectation;
- manifest hash drift fails every consumer test;
- every producer entry with `consumerRequired=true` appears exactly once in
  each applicable ledger;
- entry order is lexical path order;
- missing, extra, duplicate, locally signed, or mismatched bytes fail;
- the later `MBI-07` output includes both consumer-ledger hashes.

## 19. Exact negative-transition evidence assignment

No test is run here. Future tests must bind fixture/state, sanitized reason,
before/after durable state, and no-secret/no-false-truth assertion.

| ID | Exact Binding test path | Required case | Sanitized reason |
|---|---|---|---|
| `CNEG-01` | `BindingTests/DeviceIngressResponseExpectationTests.swift` | correct request digests, wrong vault/owner/Agreement/Contract/Grant/signer/result schema/purpose/audience/generation/validity | `expectation_mismatch` |
| `CNEG-02` | `BindingTests/DeviceIngressVaultContinuityTests.swift` | missing/locked/ephemeral/replaced vault; auto-create forbidden | `vault_unavailable` |
| `CNEG-03` | `BindingTests/DeviceIngressVaultContinuityTests.swift` | copied/restored/legacy evidence and build mismatch | `evidence_rebind_failed` |
| `CNEG-04` | `BindingTests/DeviceIngressPrivacyTests.swift` | bearer/shared secret/legacy Authorization input | `forbidden_credential` |
| `CNEG-05` | `BindingTests/DeviceIngressPrivacyTests.swift` | token/hash in defaults/log/analytics/diagnostic/crash/export/UI/accessibility | `secret_persistence_detected` |
| `CNEG-06` | `BindingTests/DeviceIngressClientStateMachineTests.swift` | crash before/after expectation and send-boundary for all six operations | `recovery_transition` |
| `CNEG-07` | `BindingTests/DeviceIngressOperationRecoveryTests.swift` | nested response/status finalization and historical signer rotation | `historical_verification` |
| `CNEG-08` | `BindingTests/DeviceIngressClientEvidenceStoreTests.swift` | cross-actor/store/process race on every operationResourceKey | `single_flight_conflict` |
| `CNEG-09` | `BindingTests/DeviceIngressDeregisterLocalCleanupTests.swift` | server commit before local erase, every local crash window | `deregister_cleanup_pending` |
| `CNEG-10` | `BindingTests/DeviceIngressDeregisterLocalCleanupTests.swift` | local erase attempted before verified authoritative commit | `premature_local_erase` |
| `CNEG-11` | `BindingTests/DeviceIngressStatusMappingTests.swift` | all matrix substitutions and all three disjoint negatives | `status_matrix_invalid` |
| `CNEG-12` | `BindingTests/DeviceIngressOperationRecoveryTests.swift` | resolve/submit payload retention without content policy | `payload_retention_forbidden` |
| `CNEG-13` | `BindingTests/DeviceIngressTokenRotationTests.swift` | correlation absent followed by separate subject-current lookup | `correlation_not_found` |
| `CNEG-14` | `BindingTests/DeviceIngressCanonicalCompositionConsumerTests.swift` | producer manifest/hash drift or consumer-local signing | `producer_fixture_drift` |

Every case begins from a named reducer state and asserts the exact next state.
Every case asserts no raw token, token hash, secret, private key, unredacted
payload, or false active/revoked/deregistered truth escaped.

Server negative evidence is bound analogously at:

`Tests/AppTests/Fixtures/DeviceIngressCompositionV2/server-negative-evidence.json`

It covers U1...U4 collision order, all challenge states, admission
absent/wrong-subject equivalence, catalog import states, registration CAS,
legacy quarantine/restore, token length, status matrix, response read-back,
rollback, revoke, and deregister.

## 20. Privacy, missing inputs, and unchanged NO-GOs

### 20.1 Kjetil-owned decision

`MBI-PRIVACY-RETENTION-01` remains:

```text
OPEN
OWNER: Kjetil
NOT DECIDED OR DELEGATED HERE
```

Still required:

- legitimate purpose for tombstone retention;
- exact duration;
- same-subject disclosure duration;
- compaction/deletion behavior;
- backup/restore exposure and destruction;
- revoke-retained sealed ciphertext permission/duration;
- truthful user-facing wording.

Until independently decided:

```text
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE COMPACTION: DISABLED
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

### 20.2 Other missing inputs

`MBI-TRANSPORT-FRAMING-01` remains a missing technical input:

- HTTPS method/path;
- media/carrier bytes;
- outer fields/order;
- compatible outer limits;
- HTTP status/error mapping;
- proxy/effective-authority rule;
- deterministic framing fixtures.

The transport remains opaque and non-authoritative.

Actual requester/issuer/owner descriptors, keys, algorithms, rotation records,
subject-target bindings, authority catalog, Agreement, Contract, Grant,
Conditions, consent, revocation ledger, trusted time, rollback anchor, and
vault continuity evidence are missing. Accepted descriptor/key/target/catalog
sets therefore remain empty.

Identity cutover remains separate and open.

`MBI-06` remains:

```text
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING
```

`MBI-07` remains:

```text
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/fixture/evidence/artifact manifest
= MISSING
```

### 20.3 Preserved evidence/action gates

```text
SOURCE: CLOSED / NO-GO
MATERIAL EDITS: CLOSED / NO-GO
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
NEXT PHASE: CLOSED / NO-GO
PRODUCTION: CLOSED / NO-GO
```

Static contract text substitutes for none of:

- source/runtime evidence;
- database/WAL/filesystem durability;
- actual signed authority material;
- Apple signing/profile/entitlement/archive evidence;
- provider acceptance;
- physical device delivery/callback;
- integrated provenance.

## 21. Independent review requirements

This author performs no self-review. A reviewer distinct from the S3 and S4
authors must, after this file is frozen:

1. bind S3 and all three S3 reviews by exact hash/shape;
2. bind this S4 file by exact hash/shape;
3. reproduce the stale-summary versus actual-finding distinction;
4. adjudicate each of the 11 P1 and three P2 clusters without arithmetic
   double-counting;
5. reproduce every schema/member order/type/enum/digest/ID/sequence equation;
6. prove admission absent and wrong-subject behavior is non-oracular;
7. prove all challenge states, inputs, terminal evidence, replay, restart, and
   compaction are total;
8. prove registration uniqueness and all lifecycle interleavings;
9. recompute every Base64url/wrapper maximum and boundary value;
10. prove token bound language is a HAVEN resource bound, not an Apple claim;
11. prove catalog/import/use-time behavior cannot make attacker-selected
    consent or authority active;
12. prove legacy plaintext cannot enter active delivery or application reads;
13. prove every operation has a durable response expectation and reducer path;
14. prove vault/evidence continuity is no-create and local absence is unknown;
15. verify every path has one owner/disposition and every fixture has an exact
    producer/consumer ledger row;
16. preserve the privacy, Identity, framing, Apple, integration, action, and
    production gates.

No review is opened or credited by this authoring act. The frozen artifact may
only be reviewed after its exact SHA-256, line count, and byte count are
recorded.

## 22. Final author freeze

Author assertion:

```text
S4 ADDITIVE CORRECTION: AUTHOR-FROZEN
BOUND S3:
  5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40
  2403 lines / 72649 bytes
BOUND A REVIEW:
  cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1
  1022 lines / 41591 bytes
BOUND B REVIEW:
  8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb
  819 lines / 38274 bytes
BOUND C REVIEW:
  301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25
  827 lines / 38711 bytes

S3 REVIEW FINDINGS:
  A = 0/4/2
  B = 0/7/2
  C = 0/3/2
CONSOLIDATED STATIC CLUSTERS:
  P1 = 11
  P2 = 3
INDEPENDENT CLOSURE CREDIT: NONE

ACYCLIC ENVELOPE: PRESERVED
WIRE OPERATIONS: EXACTLY SIX
TOKEN ROTATION: REGISTER MUTATION ONLY
TRANSPORT: OPAQUE / NON-AUTHORITATIVE
ORIGIN: https://haven.digipomps.org
BUNDLE/TOPIC: org.digipomps.haven

MBI-PRIVACY-RETENTION-01: OPEN / KJETIL
MBI-TRANSPORT-FRAMING-01: MISSING
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

The only permissible successor is a new independent exact-byte static review
of this frozen S4 artifact. No source, material, Git, build, test, network,
portal, signing, device, APNS, Identity, staging, deployment, integration,
next-phase, or production action is authorized.
