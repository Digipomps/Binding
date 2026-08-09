# APNS S5 Normative Composition Contract Correction

Status: **AUTHOR-FROZEN / INDEPENDENT REVIEW REQUIRED / S3+S4+S5 NO-GO / S6 NO-GO / SOURCE NO-GO / PRODUCTION NO-GO**

Date lineage: `2026-07-24`  
Authoring date: `2026-07-25` local  
Scope: one additive, document-only correction of the immutable S3+S4
composition  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md`

The sole output path was re-attested absent immediately before this file was
created. This document changes no prior document, source, fixture, manifest,
configuration, provider, procedure, project, dependency, Git, build, test,
network, portal, signing, device, APNS, Identity, staging, deployment,
integration, material, or production state.

## 1. Exact immutable lineage

### 1.1 Author contracts

| Role | Artifact | SHA-256 | Lines | Bytes |
|---|---|---|---:|---:|
| S3 | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` | 2403 | 72649 |
| S4 | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_2026-07-24.md` | `99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa` | 2377 | 79288 |

### 1.2 Six immutable independent reviews

| Stage/lane | Artifact | SHA-256 | Lines | Bytes | Terminal P0/P1/P2 |
|---|---|---|---:|---:|---:|
| S3 A | `Documentation/APNS_S3_Normative_Composition_Contract_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `cda7090fb641f0001cf24aa46f14e66d71b7cc1260b3965fd68262a21f5d2ee1` | 1022 | 41591 | `0/4/2` |
| S3 B | `Documentation/APNS_S3_Normative_Composition_Contract_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `8f96cfa0132fcd7222926be8f90ab47abdb6e3454d042bf0e40b4671b5f5d9cb` | 819 | 38274 | `0/7/2` |
| S3 C | `Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `301f3532b57a1f0df1d1e05ed0388aba9c0f95600d575b724c203ecb063f7b25` | 827 | 38711 | `0/3/2` |
| S4 A | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `c3a424c777907a7e9c749f2602f1f89252743c36e4f5abdb754dd4f8b98fcace` | 1006 | 34394 | `0/5/2` |
| S4 B | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `1580b3e6206b548c8e2fa1f9ee3d134c77a8ff6b6ef1656a1126fc0598b36334` | 792 | 37012 | `0/5/2` |
| S4 C | `Documentation/APNS_S4_Normative_Composition_Contract_Correction_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `640fe35d9e2ef482c75d8093efe4eb914dd953e678ec4fd79e2b9053ab296985` | 917 | 32388 | `0/4/2` |

The S4 terminal lane counts above are authoritative. Narrative references to
older findings are lineage, not new findings. This correction does not copy a
cross-lane arithmetic count into a new severity result.

## 2. Ordered precedence and preserved positive invariants

The effective future static contract is the ordered composition:

```text
S3 exact bytes
then S4 exact bytes
then S5 exact bytes
```

S5 replaces every conflicting S3/S4 clause it explicitly names. Unnamed S3/S4
clauses remain normative. A producer or consumer may not choose the most
permissive version.

Corrected composition identifier:

```text
APNS-DEVICE-INGRESS-NORMATIVE-COMPOSITION/3
```

Preserved invariants:

- CJP-1 core bytes precede SignatureProtectedCore, signature, envelope, and
  SignedArtifact;
- body → intent → challenge → request → signed outcome remains acyclic;
- exactly six wire operations exist:
  `register`, `resolve`, `submit`, `status`, `revoke`, `deregister`;
- token rotation is only `register` with `mutationMode=token_rotation`;
- status is exactly `r--s`; mutations are exactly `rw-s`;
- transport is semantically neutral, opaque, byte-preserving, and grants no
  authority;
- the authenticated Resolver/Cell boundary owns the first inner decode,
  target selection, policy, Agreement/Contract/Grant/Conditions, and mutation;
- APNS token bytes are opaque, non-empty, at most 4096 raw bytes as a HAVEN
  allocation bound only, never as an Apple length claim;
- no raw token or token hash enters documents, fixtures, manifests, evidence,
  logs, analytics, diagnostics, crash reports, exports, UI, or accessibility;
- server deregistration is authoritative before Binding erases local
  token/binding state;
- route, Host, TLS, bundle, topic, environment, ID, token possession,
  administrator, test key, static file, or unsigned manifest grants no
  authority.

Exact planning literals remain:

```text
identity domain = domain:device:notification-callback
purpose         = purpose://access.audit.privacy/device-notification-callback
audience        = haven.digipomps.org
origin          = https://haven.digipomps.org
bundle          = org.digipomps.haven
APNS topic      = org.digipomps.haven
environment     = production
```

They prove no profile, entitlement, signing identity, archive, provider
acceptance, physical delivery, callback, or production readiness.

## 3. Eight consolidated S4 root causes

The terminal S4 observations map without deletion or duplicate closure credit:

| S5 root | Exact S4 observations | Normative disposition in S5 |
|---|---|---|
| `S5-RC-01` | A-01, C-01 | one total signed outcome union, complete correlation/status semantics, and expectation variants |
| `S5-RC-02` | A-02, B-03 | total replay/expiry/error/compaction precedence and stored bytes |
| `S5-RC-03` | A-03, B-01, B-02 | constructible subject-target artifact and complete catalog/delegation tuple |
| `S5-RC-04` | A-05, B-04 | atomic current subject head independent of permanent historical retention |
| `S5-RC-05` | A-04 | mechanically derived escape-safe maxima |
| `S5-RC-06` | B-05 | crash-durable legacy inventory, quarantine, adjudication, and evidence |
| `S5-RC-07` | C-02, C-03 | exact six-operation journal/reducer, conflict locks, stable media, and resolve handoff |
| `S5-RC-08` | C-04 | constructible vault continuity slots with explicitly missing copy/rollback premises |

This is an author correction map, not independent closure. External authority,
storage, hardware, custody, Identity, and retention premises remain
unsupported and cannot receive PASS from a schema.

The S4 P2 observations are classified into:

| S5 P2 class | Exact S4 observations | S5 correction |
|---|---|---|
| `S5-PATH-01` | A-02, B-01, C-01 | repo-qualified paths with exactly one final-byte owner and one disposition |
| `S5-EVIDENCE-01` | A-01, B-02, C-02 | versioned producer inventory plus per-entry A/B/C applicability and test mapping |

## 4. Canonical non-escaping scalar profile

### 4.1 String alphabets

Every externally derived protocol string used directly in JSON MUST be one of:

```text
TokenASCII     = [A-Za-z0-9._:-]
PathTokenASCII = [A-Za-z0-9._:/-]
Base64urlASCII = [A-Za-z0-9_-]
HexASCII       = [0-9a-f]
RWXSASCII      = exactly four characters, each position fixed to r/w/x/s or -
```

No accepted direct string contains `"`, `\`, control characters, non-ASCII
bytes, or an alternative JSON escape. Arbitrary or human text is bounded raw
UTF-8 bytes carried as canonical Base64url.

| Type | Alphabet and length |
|---|---|
| `DigestHex` | `HexASCII`, exactly 64 |
| `DescriptorDigest` | `DigestHex` |
| `TargetCellID` | `PathTokenASCII`, 1...128 |
| `TicketID` | `TokenASCII`, 1...128 |
| `AlgorithmToken` | `TokenASCII`, 1...64 |
| `KeyID` | `TokenASCII`, 1...128 |
| schema/resource/action/capability/purpose/audience/domain | exact closed literal or `PathTokenASCII` with schema-specific maximum |
| all prefixed IDs | exact prefix plus 43 Base64url characters |

These restrictions replace S4's general printable-ASCII allowance for these
fields. Therefore JSON escaping contributes zero additional value bytes.

### 4.2 Canonical length functions

All lengths are unsigned checked-integer calculations over UTF-8 bytes:

```text
B64(n) =
  4 * floor(n / 3)                  if n mod 3 = 0
  4 * floor(n / 3) + 2              if n mod 3 = 1
  4 * floor(n / 3) + 3              if n mod 3 = 2

StringMember(name,n) = UTF8(name).count + 5 + n
UIntMember(name,d)   = UTF8(name).count + 3 + d
NullMember(name)     = UTF8(name).count + 7

Object(members) =
  2                                  // { }
  + max(0, memberCount - 1)           // commas
  + sum(exact member contributions)
```

All arithmetic checks overflow before allocation. Producers and consumers use
these exact functions, not hand-maintained constants.

## 5. One total signed outcome union

### 5.1 SignedOutcomeArtifact

`SignedOutcomeArtifact` is one closed tagged union of the unchanged S3
SignedArtifact container. The discriminator is the verified protected
`artifactKind`:

| `artifactKind` | Exact core schema | Union case |
|---|---|---|
| `operation_success` | `cellprotocol.device-ingress.response-core.v3` | success |
| `authenticated_error` | `cellprotocol.device-ingress.authenticated-error-core.v2` | authenticated error |
| `admission_terminal_evidence` | `cellprotocol.device-ingress.admission-terminal-evidence-core.v2` | admitted indeterminate/unavailable |

Validation order:

1. canonical-decode SignedArtifact;
2. canonical-decode SignatureEnvelope;
3. canonical-decode SignatureProtectedCore;
4. select exactly one union case from `artifactKind`;
5. require the exact mapped core schema;
6. recompute `coreSHA256`;
7. resolve the exact expectation-allowed signer descriptor, key ID, algorithm,
   role, historical catalog/delegation, authority generation, and revocation;
8. verify the S3 length-framed signature input;
9. verify every common attempt field and variant-specific field;
10. compute outcome artifact digest from complete exact SignedArtifact bytes.

```text
outcomeArtifactSHA256 =
  lowercaseHex(SHA256(exact SignedOutcomeArtifact bytes))
```

No union case may be nested inside another union case. Transport carries the
exact bytes and never selects or constructs a case.

### 5.2 ResponseCore v3

Schema:

`cellprotocol.device-ingress.response-core.v3`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `committedAtMilliseconds`
5. `intentArtifactSHA256`
6. `operation`
7. `requestArtifactSHA256`
8. `requesterDescriptorSHA256`
9. `result`
10. `resultSHA256`
11. `resultSchema`
12. `schema`
13. `serverSequence`
14. `statusKind`
15. `targetCellID`
16. `targetOwnerDescriptorSHA256`

All attempt, target, owner, and result members are non-null. `statusKind` is
null for five non-status operations and exactly `registration` or `admission`
for status.

```text
resultSHA256 =
  lowercaseHex(SHA256(exact decoded result bytes))
```

Exact success mapping:

| operation/statusKind | result schema |
|---|---|
| register/null | `cellprotocol.device-ingress.register-receipt-core.v3` |
| resolve/null | `cellprotocol.device-ingress.resolve-result-core.v3` |
| submit/null | `cellprotocol.device-ingress.submit-receipt-core.v3` |
| status/registration | `cellprotocol.device-ingress.status-result-core.v3` |
| status/admission | `cellprotocol.device-ingress.status-result-core.v3` |
| revoke/null | `cellprotocol.device-ingress.revoke-receipt-core.v3` |
| deregister/null | `cellprotocol.device-ingress.deregister-receipt-core.v3` |

Exact replay returns the original outcome artifact bytes and consumes no new
sequence.

### 5.3 AuthenticatedErrorCore v2

Schema:

`cellprotocol.device-ingress.authenticated-error-core.v2`

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

Closed `phase`:

- `pre_challenge`;
- `post_challenge_pre_admission`;
- `admitted`;
- `readback`.

Closed `terminality`:

- `nonterminal`;
- `terminal`.

Closed `errorCode` and mandatory mapping:

| errorCode | retryClass | terminality |
|---|---|---|
| `authority_unavailable` | `after_authority_recovery` | terminal |
| `authorization_denied` | `never_same_bytes` | terminal |
| `challenge_expired` | `never_same_bytes` | terminal |
| `condition_unsatisfied` | `after_user_action` | terminal |
| `generation_conflict` | `status_only` | terminal |
| `invalid_operation_state` | `status_only` | terminal |
| `legacy_store_quarantined` | `after_authority_recovery` | terminal |
| `operation_pending` | `status_only` | nonterminal |
| `oversize` | `never_same_bytes` | terminal |
| `privacy_unknown` | `status_only` | terminal |
| `replay_conflict` | `never_same_bytes` | terminal |
| `target_unavailable` | `after_authority_recovery` | terminal |
| `trusted_time_unavailable` | `after_authority_recovery` | terminal |
| `unsupported_token_length` | `never_same_bytes` | terminal |

Field matrix:

| phase | admission | body | challenge | intent | request | target/owner | signer role |
|---|---|---|---|---|---|---|---|
| pre_challenge | null | V | null | V | null | null | `challenge_issuer` |
| post_challenge_pre_admission | null | V | V | V | null | V | `target_owner` |
| admitted | V | V | V | V | V | V | `target_owner` |
| readback | V | V | V | V | V | V | expectation-selected historical role |

`operation_pending` is valid only for `phase=admitted`. It is stored in the
admission progress ledger and directs status read-back; it never compacts as a
terminal result and never proves success.

Every other admitted authenticated error is one exact terminal outcome,
committed/read back atomically with the admission. No direct error may be
replayed for a different intent, challenge, request, body, admission, subject,
target, operation, or status kind.

### 5.4 AdmissionTerminalEvidenceCore v2

Schema:

`cellprotocol.device-ingress.admission-terminal-evidence-core.v2`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `committedAtMilliseconds`
5. `evidenceCode`
6. `intentArtifactSHA256`
7. `operation`
8. `reasonCode`
9. `requestArtifactSHA256`
10. `requesterDescriptorSHA256`
11. `schema`
12. `serverSequence`
13. `statusKind`
14. `targetCellID`
15. `targetOwnerDescriptorSHA256`

Every field is non-null except `statusKind` for non-status operations.

Closed `evidenceCode`:

- `indeterminate`;
- `unavailable`.

Closed `reasonCode`:

- `authority_history_unavailable`;
- `response_bytes_corrupt`;
- `response_bytes_missing`;
- `rollback_anchor_failed`;
- `target_idempotency_unreadable`;
- `trusted_time_unavailable`.

It is signed by the expectation-pinned challenge issuer. It asserts no target
success, target failure, absence, or retry safety. It is produced only after
admission when a target mutation MUST NOT be rerun and exact target outcome
cannot be recovered. Exact bytes are committed/read back before release.

### 5.5 OutcomeExpectationVariantCore

Schema:

`binding.device-ingress.outcome-expectation-variant-core.v1`

Exact member order:

1. `allowedErrorCodes`
2. `allowedEvidenceCodes`
3. `artifactKind`
4. `coreSchema`
5. `phase`
6. `resultSchema`
7. `retryClasses`
8. `schema`
9. `signerAlgorithm`
10. `signerDescriptorSHA256`
11. `signerKeyID`
12. `signerRole`

Arrays are sorted lexical, duplicate-free, and empty when not applicable.
Nullable `phase` and `resultSchema` are present.

Rules:

- `operation_success`: exact operation result schema, null phase, empty error/
  evidence/retry arrays, signer role `target_owner`;
- `authenticated_error`: null result schema, exact phase, closed error/retry
  subsets, empty evidence array, signer role from the error field matrix;
- `admission_terminal_evidence`: null phase/result, empty error/retry arrays,
  evidence set `indeterminate|unavailable`, signer role `challenge_issuer`.

### 5.6 ResponseExpectationCore v2

Schema:

`binding.device-ingress.response-expectation-core.v2`

Exact member order:

1. `admissionID`
2. `agreementSHA256`
3. `allowedOutcomeVariants`
4. `allowedOutcomeVariantsSHA256`
5. `authorityCatalogSHA256`
6. `authorityGeneration`
7. `bodySHA256`
8. `buildProvenanceSHA256`
9. `challengeArtifactSHA256`
10. `conditionsSHA256`
11. `consentSHA256`
12. `contractSHA256`
13. `expectationID`
14. `grantSHA256`
15. `identityDomain`
16. `intentArtifactSHA256`
17. `issuerDescriptorSHA256`
18. `issuerGeneration`
19. `minimumRegistrationGeneration`
20. `minimumRevocationGeneration`
21. `minimumServerSequence`
22. `operation`
23. `purpose`
24. `requestArtifactSHA256`
25. `requesterDescriptorSHA256`
26. `requiredAccess`
27. `resource`
28. `schema`
29. `statusKind`
30. `subjectTargetBindingSHA256`
31. `targetCellID`
32. `targetOwnerDescriptorSHA256`
33. `validUntilMilliseconds`
34. `vaultContinuityProofSHA256`

`allowedOutcomeVariants` is an array of Base64url exact
OutcomeExpectationVariantCore bytes, sorted by:

```text
artifactKind || 0x00 || phase-or-empty || 0x00 || coreSchema
```

```text
allowedOutcomeVariantsSHA256 =
  lowercaseHex(SHA256(CJP-1 exact array bytes))
```

Before any send:

- at least success and every reachable authenticated-error phase are present;
- terminal evidence is present only for mutation-capable admitted operations;
- every variant signer is verified through the historical binding/catalog;
- the expectation, operation extension, journal, and vault proof are one local
  stable-media transaction.

At verification, exactly one variant must match. A non-success case never
satisfies success, current-registration, revoke, deregister, resolve-delivery,
or submit-receipt truth.

If any historical signer, owner, catalog, delegation, generation, request,
admission, or vault input is missing:

```text
allowedOutcomeVariants = []
accepted outcome artifacts = EMPTY
operation readiness = UNAVAILABLE
send = FORBIDDEN
```

## 6. StatusResultCore v3

Schema:

`cellprotocol.device-ingress.status-result-core.v3`

Exact member order:

1. `correlationDisposition`
2. `correlationSHA256`
3. `freshUntilMilliseconds`
4. `observedAtMilliseconds`
5. `registrationGeneration`
6. `registrationHeadEpoch`
7. `registrationHeadGeneration`
8. `registrationID`
9. `registrationRecordSHA256`
10. `revocationGeneration`
11. `schema`
12. `selector`
13. `statusCode`
14. `subjectState`
15. `targetAdmissionOutcome`
16. `targetAdmissionOutcomeKind`
17. `targetAdmissionOutcomeSHA256`
18. `tombstoneSHA256`

Closed correlation dispositions:

- `not_requested`;
- `current_exact`;
- `superseded`;
- `not_found`;
- `inconsistent_retryable`;
- `suppressed_privacy`.

Exact semantics:

```text
no correlation in request
  <=> correlationDisposition=not_requested
      and correlationSHA256=null

correlation present, selector outwardly privacy_unknown
  <=> correlationDisposition=suppressed_privacy
      and correlationSHA256=null

correlation present, non-privacy row
  <=> correlationDisposition is current_exact|superseded|not_found|
      inconsistent_retryable
      and correlationSHA256=SHA256(exact correlation core bytes)
```

The suppressed row reveals only what the requester already knows: it supplied
a correlation. It reveals no selected record.

Matrix notation: `V` exact typed non-null value, `N` exact null, `M` row-
constrained value.

| statusCode | selector | C | H | HE | HG | RG | RID | RR | VG | SS | AO | AK | AH | TS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `subject_current_active` | subject_current/owned ID | not_requested | N | V | V | V | V | V | V | active_consented | N | N | N | N |
| `subject_current_revoked` | subject_current/owned ID | not_requested | N | V | V | V | V | V | V | revoked | N | N | N | N |
| `subject_current_deregistered` | subject_current | not_requested | N | V | V | N | N | N | M | deregistered | N | N | N | V |
| `subject_current_unknown` | subject_current | not_requested | N | N | N | N | N | N | N | unknown | N | N | N | N |
| `correlation_current_active` | registration + correlation | current_exact | V | V | V | V | V | V | V | active_consented | N | N | N | N |
| `correlation_superseded` | registration + correlation | superseded | V | V | V | M | M | M | M | M | N | N | N | M |
| `correlation_not_found` | registration + correlation | not_found | V | M | M | N | N | N | N | unknown | N | N | N | N |
| `correlation_inconsistent_retryable` | registration + correlation | inconsistent_retryable | V | M | M | N | N | N | N | indeterminate | N | N | N | N |
| `admission_response_available` | admission_id | not_requested | N | N | N | N | N | N | N | N | V | operation_success | V | N |
| `admission_error_available` | admission_id | not_requested | N | N | N | N | N | N | N | N | V | authenticated_error | V | N |
| `admission_pending` | admission_id | not_requested | N | N | N | N | N | N | N | N | N | N | N | N |
| `admission_terminal_indeterminate` | admission_id | not_requested | N | N | N | N | N | N | N | N | V | admission_terminal_evidence | V | N |
| `admission_terminal_unavailable` | admission_id | not_requested | N | N | N | N | N | N | N | N | V | admission_terminal_evidence | V | N |
| `privacy_unknown` | registration_id, no correlation | not_requested | N | N | N | N | N | N | N | unknown | N | N | N | N |
| `privacy_unknown` | registration_id, correlation present | suppressed_privacy | N | N | N | N | N | N | N | unknown | N | N | N | N |
| `privacy_unknown` | admission_id | not_requested | N | N | N | N | N | N | N | N | N | N | N | N |
| `indeterminate_retryable` | registration selector | M | M | M | M | N | N | N | N | indeterminate | N | N | N | N |
| `indeterminate_retryable` | admission_id | not_requested | N | N | N | N | N | N | N | N | N | N | N | N |

Columns:

```text
C  correlationDisposition
H  correlationSHA256
HE registrationHeadEpoch
HG registrationHeadGeneration
RG registrationGeneration
RID registrationID
RR registrationRecordSHA256
VG revocationGeneration
SS subjectState
AO targetAdmissionOutcome
AK targetAdmissionOutcomeKind
AH targetAdmissionOutcomeSHA256
TS tombstoneSHA256
```

`targetAdmissionOutcome` is Base64url of exact SignedOutcomeArtifact bytes.
Its hash and kind MUST match. Recursive status admission read-back remains
forbidden. An absent, wrong-subject, wrong-target, or unproved admission ID
always uses the same `privacy_unknown` row and lookup/timing/size policy.

`subject_current_deregistered` is emitted only while a Kjetil-approved retained
tombstone is both present and disclosable. Otherwise the row is
`subject_current_unknown`.

## 7. Total challenge replay, expiry, error, and compaction

### 7.1 Unique indexes and equality

S4 U1...U4 remain:

```text
U1 UNIQUE(compositionVersion, issuerDescriptorSHA256, issuerGeneration, challengeID)
U2 UNIQUE(compositionVersion, requesterDescriptorSHA256, clientIntentID)
U3 UNIQUE(compositionVersion, requesterDescriptorSHA256, clientNonce)
U4 UNIQUE(compositionVersion, intentArtifactSHA256)
```

The exact same-request equality tuple is:

```text
exact IntentArtifact bytes/digest
requester descriptor/domain
clientIntentID/clientNonce
operation/resource/action/capability/access/statusKind
body schema/digest
challenge bytes/digest/ID
admission ID
exact RequestArtifact bytes/digest
target Cell/owner
authority/catalog/binding/Agreement/Contract/Grant/Conditions/consent digests
authority/issuer/revocation/catalog/binding/consent generations
```

Fields not yet created are omitted only for that earlier phase.

### 7.2 Issuance precedence

One serialized transaction executes:

1. canonical decode and requester/intent authentication;
2. U4 lookup before state branching;
3. when U4 exists:
   - byte-equal tuple dispatches by the stored state table below;
   - any byte mismatch is `replay_conflict`;
   - no U2/U3 insert or fresh challenge allocation occurs;
4. when U4 is absent, inspect U2 and U3 together:
   - neither exists: proceed to fresh issuance;
   - either exists with a different intent: `replay_conflict`;
   - a same-intent row without U4 is corruption → readiness unavailable;
5. allocate challenge ID; an internal U1 random collision retries without
   outward record disclosure;
6. atomically store intent, challenge, indexes, state, and exact bytes;
7. read back before release.

U1 lookup by an unproved locator never precedes subject authentication.

### 7.3 Stored expiry outcome

Transition from `issued_active_unused` to `issued_expired_unused` atomically
creates one issuer-signed AuthenticatedErrorCore v2:

```text
errorCode = challenge_expired
phase = pre_challenge
retryClass = never_same_bytes
terminality = terminal
```

It binds the exact intent/body/subject/operation and has null challenge,
request, admission, and target fields. The exact SignedOutcomeArtifact bytes
and digest are stored in an expiry-outcome ledger. The transition consumes one
issuer sequence once. Replay returns these stored bytes; it never reconstructs,
re-signs, or consumes a new sequence.

### 7.4 Closed state and terminalKind mapping

| State family | terminalKind | Exact same-request result |
|---|---|---|
| issued active unused | null | exact stored ChallengeArtifact |
| issued expired unused | authenticated_error | exact stored expiry outcome |
| admitted active/expired pending | null | exact stored `operation_pending` outcome; status-only recovery |
| admitted active/expired success terminal | operation_success | exact stored success outcome |
| admitted active/expired error terminal | authenticated_error | exact stored terminal error outcome |
| admitted active/expired indeterminate terminal | admission_terminal_evidence | exact stored evidence |
| admitted active/expired unavailable terminal | admission_terminal_evidence | exact stored evidence |
| compacted unused | authenticated_error | exact expiry outcome from independent ledger |
| compacted admitted success | operation_success | exact outcome from response ledger |
| compacted admitted error | authenticated_error | exact outcome from error ledger |
| compacted admitted indeterminate/unavailable | admission_terminal_evidence | exact evidence ledger bytes |

Different same-subject request is `replay_conflict`. Wrong subject or unproved
locator is oracle-safe `privacy_unknown`.

### 7.5 CompactedChallengeTombstoneCore v2

Schema:

`cellprotocol.device-ingress.compacted-challenge-tombstone-core.v2`

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
14. `terminalKind`
15. `terminalOutcomeSHA256`

Nullability:

| compacted kind | admission | challenge digest | request digest | terminalKind | outcome digest |
|---|---|---|---|---|---|
| unused | null | V | null | authenticated_error | V |
| success | V | V | V | operation_success | V |
| error | V | V | V | authenticated_error | V |
| indeterminate/unavailable | V | V | V | admission_terminal_evidence | V |

Compaction requires expiry, no pending target work, exact terminal outcome in
an independent ledger, rollback-anchor coverage, and atomic tombstone
write/read-back before challenge-byte deletion. Exact outcome bytes are never
reconstructed or re-signed. Quota pressure makes issuance unavailable.

Compacted-record retention/deletion remains governed by
`MBI-PRIVACY-RETENTION-01`; no duration is chosen here.

## 8. Constructible subject-target binding and authorization chain

### 8.1 CatalogSignerDelegationCore

Schema:

`cellprotocol.device-ingress.catalog-signer-delegation-core.v1`

Exact member order:

1. `authorityManifestSHA256`
2. `catalogSignerAlgorithm`
3. `catalogSignerDescriptorSHA256`
4. `catalogSignerKeyID`
5. `delegationGeneration`
6. `delegationID`
7. `expiresAtMilliseconds`
8. `issuedAtMilliseconds`
9. `permittedArtifactKinds`
10. `revocationGeneration`
11. `schema`
12. `targetOwnerDescriptorSHA256`

```text
delegationID = "csd1_" + Base64url(CSPRNG(32 bytes))
```

`permittedArtifactKinds` is a sorted, duplicate-free subset of exactly:

- `authorization_catalog`;
- `subject_target_binding`.

The delegation artifact kind is `catalog_signer_delegation`. It is signed by
the exact target owner key named and authorized by the independently trusted
authority manifest. It binds that manifest digest and has one monotonic
generation/revocation namespace:

```text
(authorityManifestSHA256, targetOwnerDescriptorSHA256, delegationID)
```

### 8.2 SubjectTargetBindingCore v2

Schema:

`cellprotocol.device-ingress.subject-target-binding-core.v2`

Exact member order:

1. `action`
2. `agreementSHA256`
3. `audience`
4. `authorityCatalogSHA256`
5. `authorityGeneration`
6. `bindingGeneration`
7. `bindingID`
8. `capability`
9. `catalogGeneration`
10. `catalogSignerDelegationSHA256`
11. `conditionsSHA256`
12. `consentGeneration`
13. `consentSHA256`
14. `contractSHA256`
15. `expiresAtMilliseconds`
16. `grantSHA256`
17. `identityDomain`
18. `issuedAtMilliseconds`
19. `mutationMode`
20. `operation`
21. `purpose`
22. `requesterDescriptorSHA256`
23. `requiredAccess`
24. `resource`
25. `responseSigner`
26. `revocationGeneration`
27. `schema`
28. `statusKind`
29. `targetCellID`
30. `targetOwnerDescriptorSHA256`

```text
bindingID = "stb1_" + Base64url(CSPRNG(32 bytes))
```

`responseSigner` is Base64url exact ResponseSignerRefCore bytes.
`mutationMode` is non-null only for register and exactly
`enroll|update|reactivate|token_rotation`.
`statusKind` is non-null only for status and exactly
`registration|admission`.

The SignedArtifact uses:

```text
artifactKind = subject_target_binding
core = exact SubjectTargetBindingCore v2 bytes
signer = target owner directly
      or exact unexpired/unrevoked delegated catalog signer
```

The protected signer descriptor/key/algorithm MUST equal the direct target
owner or the exact CatalogSignerDelegationCore. The signature input is the S3
domain-separated `LP(SignatureProtectedCore)` input; no alternate binding
signature format exists.

```text
subjectTargetBindingSHA256 =
  lowercaseHex(SHA256(exact SubjectTargetBindingArtifact bytes))
```

Binding uniqueness and generation:

```text
UNIQUE(authorityCatalogSHA256, targetCellID, requesterDescriptorSHA256,
       operation, mutationMode-or-empty, statusKind-or-empty, bindingID)
```

Generation is `1` initially and increments by one for replacement. Exact replay
returns exact bytes. A revoked, expired, superseded, wrong-owner, wrong-signer,
or rollback generation binding is not accepted.

### 8.3 ConsentArtifactCore v2

Schema:

`cellprotocol.device-ingress.consent-artifact-core.v2`

Exact member order:

1. `agreementSHA256`
2. `audience`
3. `conditionsSHA256`
4. `consentGeneration`
5. `consentID`
6. `contractSHA256`
7. `expiresAtMilliseconds`
8. `grantSHA256`
9. `identityDomain`
10. `issuedAtMilliseconds`
11. `mutationMode`
12. `operation`
13. `purpose`
14. `requesterDescriptorSHA256`
15. `requiredAccess`
16. `resource`
17. `schema`
18. `statusKind`
19. `subjectTargetBindingSHA256`
20. `targetCellID`
21. `termsNoticeSHA256`

```text
consentID = "cns1_" + Base64url(CSPRNG(32 bytes))
```

The requester signs it with `artifactKind=consent`. Generation is monotonic for
the exact full tuple excluding time/ID/generation. Consent replacement,
withdrawal, expiry, or revocation makes the prior generation unusable.
Tuple-compatible artifact substitution fails because every exact authority,
binding, Conditions, and terms digest is signed.

### 8.4 AuthorizationCatalogEntryCore v2

Schema:

`cellprotocol.device-ingress.authorization-catalog-entry-core.v2`

Exact member order:

1. `agreementArtifact`
2. `agreementSHA256`
3. `catalogSignerDelegationArtifact`
4. `catalogSignerDelegationSHA256`
5. `conditionsArtifact`
6. `conditionsSHA256`
7. `consentArtifact`
8. `consentSHA256`
9. `contractArtifact`
10. `contractSHA256`
11. `entryGeneration`
12. `entryID`
13. `grantArtifact`
14. `grantSHA256`
15. `notAfterMilliseconds`
16. `notBeforeMilliseconds`
17. `schema`
18. `subjectTargetBindingArtifact`
19. `subjectTargetBindingSHA256`

```text
entryID = "ace1_" + Base64url(CSPRNG(32 bytes))
```

All artifact members are Base64url exact signed bytes. Delegation may be null
only when catalog and binding are signed directly by the target owner; its
paired digest is then null.

The entry contains no attacker-declared accepted/revoked/expired state. The
importer computes the state from verified bytes, generations, revocation,
conditions, and trusted time.

### 8.5 Complete tuple equality

At import, challenge, operation, and read-back, these values MUST be byte-equal
across manifest, delegation, catalog, binding, Agreement, Contract, Grant,
Conditions, consent, intent, challenge, request, and operation table wherever
present:

```text
identityDomain
audience
purpose
resource
action
capability
requiredAccess (all four RWXS positions)
operation
mutationMode or exact null
statusKind or exact null
requesterDescriptorSHA256
targetCellID
targetOwnerDescriptorSHA256
response signer descriptor/key/algorithm/role
Agreement/Contract/Grant/Conditions/consent/binding digests
authority/catalog/delegation/binding/consent/revocation generations
not-before/not-after validity and trusted-time decision
```

Substitution of any member, artifact, signer, owner, generation, mode, status
kind, or nullability rejects the entire entry. A numerically higher generation
without the accepted signed chain grants nothing.

### 8.6 Catalog signer chain and empty-set rule

Accepted chain is exactly one:

```text
independently trusted AuthorityManifestArtifact
  -> exact target owner key
  -> direct target-owner catalog signature

or

independently trusted AuthorityManifestArtifact
  -> exact target owner key
  -> CatalogSignerDelegationArtifact
  -> delegated catalog signer
  -> AuthorizationCatalogArtifact and SubjectTargetBindingArtifact
```

No environment key, repository key, scaffold owner, test key, TLS key, or
administrator substitutes.

Actual manifest, external signer, key, descriptor, delegation, catalog,
Agreement, Contract, Grant, Conditions, consent, Identity, trusted-time,
revocation, and rollback bytes are absent from the frozen inputs. Therefore:

```text
accepted authority manifests = EMPTY
accepted target owners = EMPTY
accepted catalog signers = EMPTY
accepted subject-target bindings = EMPTY
accepted authorization entries = EMPTY
accepted outcome signers = EMPTY
affected readiness = UNAVAILABLE
```

S5 does not create a fake/static owner.

## 9. Current subject head without permanent historical retention

### 9.1 CurrentSubjectHeadCore

Schema:

`cellscaffold.device-ingress.current-subject-head-core.v1`

Exact member order:

1. `currentRegistrationID`
2. `headEpoch`
3. `headGeneration`
4. `headKey`
5. `identityDomain`
6. `lastDisclosableTombstoneSHA256`
7. `lifecycleState`
8. `registrationGeneration`
9. `requesterDescriptorSHA256`
10. `revocationGeneration`
11. `schema`
12. `targetCellID`

```text
headKey =
  lowercaseHex(
    SHA256(
      LP(UTF8(compositionVersion))
      || LP(UTF8(identityDomain))
      || LP(requesterDescriptorSHA256Raw)
      || LP(UTF8(targetCellID))
    )
  )

headEpoch = Base64url(CSPRNG(32 bytes))
```

Closed `lifecycleState`:

- `active`;
- `revoked`;
- `empty_after_deregister`.

One durable row exists at most:

```text
UNIQUE(compositionVersion, headKey)
```

`currentRegistrationID` is non-null only for active/revoked.
`lastDisclosableTombstoneSHA256` is non-null only while the owner-approved
retained tombstone is present and disclosable.

### 9.2 Head transitions

Every transition locks:

```text
1 headKey
2 currentRegistrationID when present
3 admissionID
4 registration-row key
```

Then exact authority, subject, target, consent, state, expected head generation,
registration generation, and revocation generation are compared.

| Operation | Required head | Atomic new head |
|---|---|---|
| first enroll with no head | no row | new epoch, generation 1, active, new ID, reg gen 1, rev gen 0 |
| enroll after deregister | empty_after_deregister | same epoch, head generation +1, active, new ID, reg gen 1, rev gen 0 |
| update/token rotation | active | head generation +1, same ID, reg generation +1 |
| reactivate | revoked | head generation +1, same ID, reg generation +1, active |
| revoke | active | head generation +1, same ID, revocation generation +1, revoked |
| deregister | active or revoked | after authoritative endpoint/token deletion and outcome commit: head generation +1, current ID null, reg generation null, empty_after_deregister |

The registration row and delivery lookup are changed in the same target
transaction. Deregister clears the current pointer only after authoritative
deletion, tombstone/outcome commit, and read-back. Re-enroll always allocates a
new ID and points the head to it.

Concurrent enroll/revoke/deregister/status serialize on `headKey`. Restart
reads and validates the head, registration row, delivery lookup, admission,
outcome, and rollback anchor before readiness. A partial or multiple head is
`indeterminate_retryable`, never repaired by timestamp guessing.

### 9.3 Historical retention independence

Registration-ID and tombstone indexes are unique only across retained records.
This correction makes no permanent-retention promise.

While a historical row/tombstone is retained:

- exact replay and non-resurrection use its exact bytes;
- wrong-subject disclosure remains privacy unknown;
- old ID cannot become current unless the current head points to that exact
  active/revoked row, which deregister forbids.

After owner-approved historical deletion:

- by-ID status and replay return oracle-safe `privacy_unknown`;
- subject-current returns active/revoked from the current head, otherwise
  `subject_current_unknown`;
- it never returns a fabricated deregistered record or infers global absence;
- an old ID can never mutate because mutation authority requires byte equality
  with `currentRegistrationID` in the current head;
- a new enrollment creates a new random ID and head transition;
- deleted historical bytes are never reconstructed or restored from digests.

If the empty head itself is later deleted under an owner-approved policy, a
future enrollment creates a new random `headEpoch`. Historical comparisons
across the deleted epoch become unavailable, not false. Old signed outcomes
cannot establish current truth because their head epoch/generation does not
match the new signed status.

Tombstone duration, head-after-deregister retention, disclosure, backup/
restore, and deletion remain governed by `MBI-PRIVACY-RETENTION-01`. No
duration or legitimate purpose is decided here.

## 10. Mechanically satisfiable maxima

### 10.1 SignatureProtectedCore

The maximum protected core is mechanically computed from the permitted
non-escaping strings:

| member | contribution |
|---|---:|
| `algorithm`, max 64 | `9 + 5 + 64 = 78` |
| `artifactKind`, max 27 | `12 + 5 + 27 = 44` |
| `coreSHA256`, 64 | `10 + 5 + 64 = 79` |
| `keyID`, max 128 | `5 + 5 + 128 = 138` |
| `schema`, exact 55 | `6 + 5 + 55 = 66` |
| `signerDescriptorSHA256`, 64 | `22 + 5 + 64 = 91` |
| braces | `2` |
| five commas | `5` |

```text
SignatureProtectedCoreMax = 503
RawSignatureMax = 1024
```

The longest allowed artifact kind is exactly
`admission_terminal_evidence`, 27 ASCII bytes.

Exact literal equations:

```text
SignatureEnvelope =
  UTF8('{"protected":"')                 // 14
  || Base64url(protected bytes)
  || UTF8('","schema":"cellprotocol.device-ingress.signature-envelope.v1","signature":"') // 76
  || Base64url(signature bytes)
  || UTF8('"}')                          // 2

SignatureEnvelopeMax =
  14 + B64(503) + 76 + B64(1024) + 2
  = 14 + 671 + 76 + 1366 + 2
  = 2129

SignedArtifact =
  UTF8('{"core":"')                      // 9
  || Base64url(core bytes)
  || UTF8('","schema":"cellprotocol.device-ingress.signed-artifact.v1","signatureEnvelope":"') // 81
  || Base64url(envelope bytes)
  || UTF8('"}')                          // 2

Artifact(C) = 9 + B64(C) + 81 + B64(2129) + 2
            = 92 + B64(C) + 2839
```

### 10.2 Response fixed contribution

For ResponseCore v3 with empty result, every member contribution at its
semantic maximum is:

```text
64+79+92+46+89+24+90+94+11+81+113+55+37+27+145+96
+ 2 braces + 15 commas
= 1160
```

Those contributions are respectively the sixteen members in section 5.2 and
are produced by `StringMember`/`UIntMember`, not an escaping estimate.

```text
NormalResultCoreMax = 65536
NormalResponseCoreMax = 1160 + B64(65536)
                      = 1160 + 87382
                      = 88542
NormalOutcomeArtifactMax = Artifact(88542)
                         = 92 + 118056 + 2839
                         = 120987
```

AuthenticatedErrorCore and AdmissionTerminalEvidenceCore each have inclusive
maximum 8192, so their artifacts are at most:

```text
Artifact(8192) = 13854
```

The success case is therefore the maximum non-status outcome.

### 10.3 Nested admission read-back

For the exact `admission_response_available` StatusResultCore v3 row with an
empty nested outcome, exact contributions are:

```text
40+24+45+45+29+28+33+21+31+27+60+25+43+19+27+48+97+22
+ 2 braces + 17 commas
= 683
```

The contributions correspond in order to all eighteen S5 admission-row
members, including exact null for both head members:

```text
AdmissionStatusResultCoreMax =
  683 + B64(120987)
  = 683 + 161316
  = 161999

AdmissionReadbackResponseCoreMax =
  1160 + B64(161999)
  = 1160 + 215999
  = 217159

AdmissionReadbackOutcomeArtifactMax =
  Artifact(217159)
  = 92 + 289546 + 2839
  = 292477
```

Recursive status read-back is forbidden, so the nesting terminates.

### 10.4 Intent/request bounds

```text
IntentCoreMax = 8192
IntentArtifactMax = Artifact(8192) = 13854
ChallengeCoreMax = 16384
ChallengeArtifactMax = Artifact(16384) = 24777
RequestCoreMax = 16384
RequestArtifactMax = Artifact(16384) = 24777

OperationRequest(B,R) =
  9 + B64(B) + 13 + B64(R) + 62
  = 84 + B64(B) + B64(R)

Largest body max = 65536
CanonicalOperationRequestMax =
  84 + B64(65536) + B64(24777)
  = 84 + 87382 + 33036
  = 120502
```

RegisterBodyCore remains maximum 6065 for a 4096-byte token under the exact
non-escaping field profile.

### 10.5 Independent calculator contract

Both producer and every consumer independently implement:

```text
checkedAdd
checkedMultiply
floorDivide
remainder
B64
StringMember
UIntMember
NullMember
Object
Envelope
Artifact
OperationRequest
```

Each fixture manifest entry records:

- scalar maxima;
- each member contribution;
- decoded core bytes;
- Base64url bytes;
- fixed literal bytes;
- envelope bytes;
- artifact bytes;
- expected accept/reject.

Producer values are not imported as consumer constants. A mismatch between
independent calculations fails the composition.

Exact future calculators:

```text
repo://CellProtocol/Tools/DeviceIngress/device_ingress_maxima_v3.swift
repo://CellScaffold/Tests/Support/DeviceIngressMaximaV3Independent.swift
repo://Binding/BindingTests/Support/DeviceIngressMaximaV3Independent.swift
```

### 10.6 Reachable boundary vectors

Every limit has semantic `max-1`, `max`, and `max+1` vectors:

```text
protected core: 502 / 503 / 504
signature: 1023 / 1024 / 1025
envelope: 2128 / 2129 / 2130
intent artifact: 13853 / 13854 / 13855
challenge artifact: 24776 / 24777 / 24778
request artifact: 24776 / 24777 / 24778
operation request: 120501 / 120502 / 120503
normal result core: 65535 / 65536 / 65537
normal response core: 88541 / 88542 / 88543
normal outcome artifact: 120986 / 120987 / 120988
admission status result: 161998 / 161999 / 162000
admission read-back response: 217158 / 217159 / 217160
admission read-back outcome artifact: 292476 / 292477 / 292478
token raw bytes: 4095 / 4096 / 4097, plus zero reject
```

Accepted maximum fixtures set every non-escaping semantic member to its
allowed maximum and use generated opaque test bytes only. `max+1` rejects
before unbounded allocation. Outer framing must accept at least 292477 opaque
application bytes plus reviewed framing overhead; framing remains missing.

## 11. Crash-durable legacy inventory and quarantine

### 11.1 DiscoveryScopeCore

Schema:

`cellscaffold.device-ingress.legacy-discovery-scope-core.v1`

Exact member order:

1. `backupRoots`
2. `databaseRoots`
3. `exportRoots`
4. `quarantineRoot`
5. `schema`
6. `scopeGeneration`
7. `snapshotRoots`

Roots are canonical descriptor-relative root IDs from signed configuration,
not raw token-bearing paths. Arrays are sorted, duplicate-free, symlink-free,
and finite. Unknown/unreadable roots make scope incomplete and readiness red.

### 11.2 Stable metadata-only artifact identity

For an opened descriptor with `NOFOLLOW`, before any content access:

```text
legacyArtifactID =
  lowercaseHex(
    SHA256(
      LP(UTF8(discoveryRootID))
      || LP(UTF8(canonicalRelativePath))
      || LP(UTF8(volumeIdentity))
      || LP(UInt64BE(fileIdentity))
      || LP(UInt64BE(birthTimeNanoseconds))
      || LP(UInt64BE(metadataByteCount))
      || LP(UInt64BE(metadataGeneration))
    )
  )
```

The relative path uses `PathTokenASCII`, no `..`, no absolute path, and no
symlink traversal. Descriptor metadata is checked before and after inventory.
A changed file creates a new artifact generation and re-enters quarantine.
No token column/value, token hash, ciphertext, key reference, registration ID,
subject descriptor, or payload participates.

Closed artifact classes:

- `database`;
- `wal`;
- `shm`;
- `rollback_journal`;
- `free_page_risk`;
- `backup`;
- `snapshot`;
- `export`;
- `restored_copy`;
- `unknown`.

### 11.3 LegacyArtifactInventoryCore

Schema:

`cellscaffold.device-ingress.legacy-artifact-inventory-core.v1`

Exact member order:

1. `artifactClass`
2. `artifactGeneration`
3. `artifactID`
4. `byteCount`
5. `discoveredAtMilliseconds`
6. `discoveryRootID`
7. `inventoryGeneration`
8. `procedureVersion`
9. `protectionClass`
10. `quarantineLocationID`
11. `schema`
12. `state`

Closed state enum:

- `discovered`;
- `quarantined`;
- `adjudicating`;
- `sealed_migration_pending`;
- `sealed_migrated_pending_disposition`;
- `deactivation_pending`;
- `deactivated_pending_disposition`;
- `disposal_pending`;
- `disposed_verified`;
- `retained_under_owner_policy`;
- `restored_copy_detected`;
- `blocked_unavailable`.

Unique:

```text
UNIQUE(scopeGeneration, artifactID, artifactGeneration)
```

### 11.4 Serialized transitions

```text
discovered
  -> quarantined
  -> adjudicating

adjudicating
  -> sealed_migration_pending
  -> deactivation_pending
  -> blocked_unavailable

sealed_migration_pending
  -> sealed_migrated_pending_disposition
  -> blocked_unavailable

deactivation_pending
  -> deactivated_pending_disposition
  -> blocked_unavailable

sealed_migrated_pending_disposition
  -> disposal_pending
  -> retained_under_owner_policy

deactivated_pending_disposition
  -> disposal_pending
  -> retained_under_owner_policy

disposal_pending
  -> disposed_verified
  -> blocked_unavailable

any terminal or in-progress state + restored/new copy
  -> restored_copy_detected
  -> quarantined
```

One inventory lease key:

```text
SHA256(LP(scopeGeneration) || LP(artifactID) || LP(artifactGeneration))
```

serializes discovery, migration, deactivation, disposal, and restore handling.
A conflicting worker reads the durable state and performs no parallel action.

### 11.5 LegacyAdjudicationAttestationCore

Schema:

`cellscaffold.device-ingress.legacy-adjudication-attestation-core.v1`

Exact member order:

1. `artifactClass`
2. `artifactGeneration`
3. `artifactID`
4. `completedAtMilliseconds`
5. `decision`
6. `inventoryGeneration`
7. `procedureArtifactSHA256`
8. `procedureSignerDescriptorSHA256`
9. `schema`
10. `verificationCode`

Closed `decision`:

- `sealed_migrated`;
- `deactivated`;
- `disposed`;
- `retained_under_owner_policy`.

Closed `verificationCode`:

- `sealed_store_readback_verified`;
- `delivery_lookup_absence_verified`;
- `metadata_disposal_verified`;
- `owner_retention_reference_verified`.

The attestation never contains or hashes a token value. It is accepted only
from a separately reviewed provider/procedure signer set.

### 11.6 Readiness coupling

`LegacyReadinessCore`

Schema:
`cellscaffold.device-ingress.legacy-readiness-core.v1`

Member order:

1. `completeArtifactCount`
2. `discoveryComplete`
3. `inventoryGeneration`
4. `nonterminalArtifactCount`
5. `providerDeliveryAllowed`
6. `registerMutationAllowed`
7. `schema`
8. `scopeGeneration`

One database transaction commits inventory transitions, attestations, exact
counts, and readiness generation. Readiness booleans are true only when:

- every configured root was enumerated from a stable descriptor;
- no unknown/unreadable root exists;
- every artifact is `disposed_verified` or
  `retained_under_owner_policy` under an approved owner decision;
- every migration/deactivation attestation verifies;
- database/rollback anchors are current;
- no restored/unseen copy exists.

Otherwise both booleans are false. No provider delivery occurs.

### 11.7 Stable-media premises and crash transitions

For file-backed records the required commit sequence is:

```text
open descriptor-relative temp with exclusive/no-follow
write complete canonical bytes
sync temp file to stable media
rename within same parent
sync parent directory
reopen final descriptor-relative path
verify identity, byte count, SHA-256, generation
advance rollback anchor
read back rollback anchor
```

For database-backed records the provider must document and prove:

- atomic transaction including inventory/readiness;
- full-durability sync mode;
- WAL/rollback-journal checkpoint semantics;
- database file and containing-directory durability;
- power-loss recovery and restored-copy detection.

Crash before final stable-media/DB commit leaves the prior state authoritative
and readiness red. Crash after commit but before anchor/read-back reopens,
verifies, and either completes the anchor or enters `blocked_unavailable`.
Crash during migration never activates legacy delivery. Crash during
deactivation repeats idempotent delivery-lookup removal. Crash during disposal
re-inventories every artifact identity before terminal evidence.

No frozen input proves `fsync`, `F_FULLFSYNC`, database FULL sync, file-system
power-loss behavior, migration provider, disposal provider, or finite backup
custody. Exact missing inputs:

```text
MBI-LEGACY-DURABILITY-PROVIDER-01
MBI-LEGACY-DISCOVERY-CUSTODY-01
MBI-LEGACY-SEALED-MIGRATION-PROCEDURE-01
MBI-LEGACY-DEACTIVATION-PROCEDURE-01
MBI-LEGACY-DISPOSAL-PROCEDURE-01
MBI-LEGACY-BACKUP-RESTORE-PROOF-01
```

Accepted provider/procedure proof sets are EMPTY. Legacy/provider delivery
readiness is UNAVAILABLE. Logical SQL deletion is not disposal proof.

## 12. Total Binding operation journal and reducer

### 12.1 Exact operation extensions

All extension cores use non-secret identifiers/digests only.

`RegisterJournalExtensionCore`

Schema:
`binding.device-ingress.register-journal-extension-core.v1`

Member order:

1. `expectedHeadGeneration`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `mutationMode`
5. `registrationHeadEpoch`
6. `registrationID`
7. `schema`
8. `tokenDeliveryEpoch`
9. `tokenObservationID`

`ResolveJournalExtensionCore`

Schema:
`binding.device-ingress.resolve-journal-extension-core.v1`

Member order:

1. `contentContractSHA256`
2. `deliveryID`
3. `schema`
4. `ticketID`
5. `ticketLineageSHA256`

`SubmitJournalExtensionCore`

Schema:
`binding.device-ingress.submit-journal-extension-core.v1`

Member order:

1. `contentContractSHA256`
2. `resolveAdmissionID`
3. `schema`
4. `ticketID`
5. `ticketLineageSHA256`

`StatusJournalExtensionCore`

Schema:
`binding.device-ingress.status-journal-extension-core.v1`

Member order:

1. `correlationSHA256`
2. `registrationID`
3. `schema`
4. `selector`
5. `statusKind`
6. `targetAdmissionID`

`RevokeJournalExtensionCore`

Schema:
`binding.device-ingress.revoke-journal-extension-core.v1`

Member order:

1. `expectedHeadGeneration`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `registrationHeadEpoch`
5. `registrationID`
6. `schema`

`DeregisterJournalExtensionCore`

Schema:
`binding.device-ingress.deregister-journal-extension-core.v1`

Member order:

1. `expectedHeadGeneration`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `registrationHeadEpoch`
5. `registrationID`
6. `schema`

Nullable members remain present. `deliveryID` is:

```text
"dly1_" + Base64url(CSPRNG(32 bytes))
```

### 12.2 OperationJournalCore v2

Schema:

`binding.device-ingress.operation-journal-core.v2`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `expectationID`
5. `expectationSHA256`
6. `intentArtifactSHA256`
7. `journalID`
8. `operation`
9. `operationExtension`
10. `operationExtensionSHA256`
11. `operationExtensionSchema`
12. `operationResourceKeys`
13. `requestArtifactSHA256`
14. `schema`
15. `sendState`
16. `statusKind`
17. `transactionSequence`
18. `vaultContinuityProofSHA256`

`operationExtension` is Base64url exact matching extension bytes.

```text
operationExtensionSHA256 =
  lowercaseHex(SHA256(exact decoded extension bytes))
```

`operationResourceKeys` is a sorted, duplicate-free array of DigestHex.
The journal/extension/expectation/vault proof are one stable-media transaction
with one positive monotonic `transactionSequence`.

### 12.3 Conflict-class resource keys

No key contains operation name merely to separate conflicting mutations.

Registration family key for register, revoke, deregister, and
status/registration:

```text
K_registration =
  SHA256(
    LP(UTF8("binding-device-ingress-registration-control-v1"))
    || LP(vaultContinuityProofSHA256Raw)
    || LP(UTF8(targetCellID))
    || LP(subjectHeadKeyRaw)
  )
```

Ticket family key for resolve and submit:

```text
K_ticket =
  SHA256(
    LP(UTF8("binding-device-ingress-ticket-control-v1"))
    || LP(vaultContinuityProofSHA256Raw)
    || LP(UTF8(targetCellID))
    || LP(ticketLineageSHA256Raw)
    || LP(UTF8(ticketID))
  )
```

Admission recovery key for every protected operation and status/admission:

```text
K_admission =
  SHA256(
    LP(UTF8("binding-device-ingress-admission-recovery-v1"))
    || LP(vaultContinuityProofSHA256Raw)
    || LP(UTF8(targetCellID))
    || LP(UTF8(admissionID))
  )
```

Required key sets:

| operation | keys |
|---|---|
| register/revoke/deregister | K_registration + K_admission |
| status/registration | K_registration + K_admission for its own status request |
| resolve/submit | K_ticket + K_admission |
| status/admission | target admission K_admission + status request K_admission |

All keys are acquired in raw-byte lexical order. This serializes
register↔revoke↔deregister↔registration-status and
resolve↔submit for the same ticket family. Status read-back updates the same
durable journal CAS rather than racing finalization.

### 12.4 Canonical stable store

All app processes/extensions use one descriptor-relative store root and one
database/file transaction provider selected by signed configuration. The store:

- opens roots no-follow relative to a pre-opened directory descriptor;
- verifies device/volume/file identity, owner, mode/protection, link count, and
  schema before and after lock;
- uses one lock/CAS namespace for every resource key;
- commits expectation, extension, journal, state, delivery marker, and
  transaction sequence to stable media before `send_started_ambiguous`;
- syncs file plus parent directory or uses an independently proven equivalent
  database durability contract;
- advances and reads back the rollback anchor;
- refuses split stores, path replacement, symlink/hard-link substitution, or
  sequence rollback.

Missing platform/store durability proof makes Binding readiness unavailable.
No ordinary in-memory read-back is stable-media proof.

### 12.5 Local-state operation gate

Closed local trust states:

- `vault_or_authority_invalid`;
- `valid_vault_local_evidence_absent`;
- `historical_evidence_unadjudicated`;
- `operation_pending_or_ambiguous`;
- `fresh_subject_current_active`;
- `fresh_subject_current_revoked`;
- `fresh_subject_current_unknown`;
- `fresh_subject_current_deregistered`;
- `blocked_indeterminate`.

| local state | permitted new action |
|---|---|
| vault_or_authority_invalid | none |
| valid_vault_local_evidence_absent | status/registration with selector `subject_current` only |
| historical_evidence_unadjudicated | status recovery only |
| operation_pending_or_ambiguous | matching status/admission or required status/registration only |
| fresh_subject_current_active | operation-specific authorized register update/rotation, resolve, submit, revoke, deregister, status |
| fresh_subject_current_revoked | authorized reactivate, deregister, status |
| fresh_subject_current_unknown | authorized first enroll or status |
| fresh_subject_current_deregistered | authorized fresh enroll with new ID or status, subject to owner policy |
| blocked_indeterminate | status retry only |

An invalid/missing/locked/replaced vault or missing authority permits no status
because it cannot authenticate or verify it. `local_unknown` is not a mutation
gate.

### 12.6 Authenticated outcome reducer branches

After expectation verification:

| union case | reducer branch |
|---|---|
| operation_success | `historical_success_verified`, then operation-specific fresh status/finalization |
| authenticated_error + operation_pending | `admission_readback_pending` |
| authenticated_error + status_only | `status_recovery_required`; never success |
| authenticated_error + after_authority_recovery | `blocked_unavailable` |
| authenticated_error + after_user_action | `blocked_user_action` |
| authenticated_error + never_same_bytes | `finalized_rejected`; a new attempt requires new bytes and authority |
| terminal evidence indeterminate | `blocked_indeterminate` |
| terminal evidence unavailable | `blocked_unavailable` |

No error/evidence branch publishes active, resolved-delivered, submitted,
revoked, deregistered, or not-registered truth.

### 12.7 Resolve delivery handoff

`ResolveDeliveryMarkerCore`

Schema:
`binding.device-ingress.resolve-delivery-marker-core.v1`

Member order:

1. `deliveryID`
2. `deliveryState`
3. `outcomeArtifactSHA256`
4. `resultSHA256`
5. `schema`
6. `sinkReceiptSHA256`
7. `ticketID`
8. `ticketLineageSHA256`
9. `transactionSequence`

Closed `deliveryState`:

- `prepared`;
- `accepted_by_idempotent_sink`;
- `finalized`.

Before exposing volatile resolved payload, Binding commits/read-backs
`prepared`. It invokes a sink with:

```text
(deliveryID, ticket lineage, exact volatile payload, result digest)
```

The sink atomically:

1. checks its durable unique `deliveryID`;
2. accepts payload once or identifies an exact prior acceptance;
3. stores no payload unless its independent content/Storage policy permits;
4. returns a durable receipt binding delivery ID, result digest, sink
   generation, and accepted/exact-replay disposition.

Binding verifies the receipt, stores only its digest, advances marker to
`accepted_by_idempotent_sink`, then `finalized`. A crash retries the same
delivery ID; the sink deduplicates. Without an independently proven durable
idempotent sink, resolve delivery is unavailable and no delivered-once claim is
made.

### 12.8 Deregister order

The S4 order remains:

```text
verified authoritative server outcome
-> required fresh signed status
-> local finalization_pending
-> local token/active-binding erasure
-> stable-media read-back
-> only owner-approved minimal evidence
-> truthful UI
```

Crash after server commit but before local erasure uses the same expectation,
admission key, status read-back, and idempotent local erase. Local erase before
verified authoritative commit is forbidden.

## 13. Constructible vault continuity slots and explicit unavailable premises

### 13.1 VaultContinuityCore

Schema:

`binding.device-ingress.vault-continuity-core.v1`

Exact member order:

1. `approvedBuildProvenanceSHA256`
2. `continuityGeneration`
3. `custodyProofSHA256`
4. `hardwareAttestationSHA256`
5. `identityDomain`
6. `journalRootSHA256`
7. `latestExpectationSHA256`
8. `nonExportableKeyFingerprintSHA256`
9. `requesterDescriptorSHA256`
10. `rollbackAnchorGeneration`
11. `rollbackAnchorSHA256`
12. `schema`
13. `vaultGeneration`

Nullable custody and hardware attestation fields are present. A copied
`vaultInstanceID` or boolean is deliberately absent.

### 13.2 VaultContinuityEnvelope

Schema:

`binding.device-ingress.vault-continuity-envelope.v1`

Exact member order:

1. `algorithm`
2. `core`
3. `coreSHA256`
4. `keyID`
5. `protectionMode`
6. `schema`
7. `signatureOrMAC`

`core` is Base64url exact VaultContinuityCore bytes.
`protectionMode` is `signature` or `mac`.

Exact protection input:

```text
LP(UTF8("HAVEN-BINDING-DEVICE-INGRESS-VAULT-CONTINUITY-V1"))
|| LP(exact VaultContinuityCore bytes)
```

The current vault key performs the signature/MAC without exporting private key
material. Verification uses an approved local proof path for that exact key
and generation. The envelope digest binds ResponseExpectationCore and
OperationJournalCore.

### 13.3 No-create verification

Binding:

1. opens only the existing persistent CellApple vault for
   `domain:device:notification-callback`;
2. never calls create or accepts an ephemeral fallback;
3. verifies current descriptor, non-exportable key fingerprint, vault
   generation, build provenance, journal Merkle/root digest, latest
   expectation, continuity generation, and rollback anchor;
4. verifies custody/hardware proof only when an independently accepted
   provider supplies it;
5. verifies signature/MAC with the current non-exportable key;
6. compares every restored journal/expectation/marker against the core;
7. updates continuity and journal/expectation in one stable-media transaction.

### 13.4 Copy resistance is not rollback resistance

Copy resistance requires proof that the signing/MAC key or custody evidence
cannot be exported/replayed on another device or vault context.

Rollback resistance requires a monotonic anchor outside the rollbackable local
evidence set. A non-exportable key alone does not prove monotonic state. A
monotonic counter alone does not prove device custody. Build provenance proves
neither.

Legitimate restore/device replacement requires an explicit custody/recovery
policy and a new continuity generation; it cannot silently preserve “same
device” truth.

### 13.5 Exact missing inputs

No frozen input supplies:

```text
MBI-VAULT-CONTINUITY-NONEXPORTABLE-KEY-01
MBI-VAULT-CONTINUITY-COPY-RESISTANCE-01
MBI-VAULT-CONTINUITY-ROLLBACK-ANCHOR-01
MBI-VAULT-CONTINUITY-CUSTODY-RECOVERY-01
MBI-VAULT-CONTINUITY-HARDWARE-ATTESTATION-01
MBI-VAULT-CONTINUITY-PLATFORM-DURABILITY-01
MBI-VAULT-CONTINUITY-IDEMPOTENT-SINK-01
```

Therefore:

```text
accepted non-exportable key proofs = EMPTY
accepted hardware attestations = EMPTY
accepted custody/recovery proofs = EMPTY
accepted rollback anchors = EMPTY
accepted durable store proofs = EMPTY
accepted idempotent sink proofs = EMPTY
Binding protected-operation readiness = UNAVAILABLE
hardware PASS claim = NONE
copy-resistance PASS claim = NONE
rollback-resistance PASS claim = NONE
```

Local absence, copied IDs, booleans, fingerprints, or MACs whose key material
was copied cannot fill these sets.

## 14. Repo-qualified one-owner path ledger

`repo://CellProtocol`, `repo://CellScaffold`, and `repo://Binding` are distinct
repository roots. Relative paths are never used without one root.

### 14.1 Package/project collision rows

| Exact path | Final-byte owner | Required input owners | Mandatory reviewers | Disposition/trigger |
|---|---|---|---|---|
| `repo://CellProtocol/Package.swift` | CellProtocol development admin | Lane A producer | Lane A + package owner | no-touch until source phase explicitly opened |
| `repo://Binding/Binding.xcodeproj/project.pbxproj` | Binding development admin | Lane C + Apple release owner | Lane C + Apple release reviewer | no-touch until integrated project-membership phase |
| `repo://Binding/Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Binding development admin | dependency owner | Lane C + dependency reviewer | conditional only after authorized dependency selection |
| `repo://Binding/Binding/Binding-iOS.entitlements` | Apple release owner | Apple release owner | Apple signing reviewer | immutable/no-touch in DeviceIngress lane |

There is one final-byte owner per path. Input/review responsibility is not
write ownership.

### 14.2 Exact CellProtocol paths

Owner: Lane A producer, except the package row above.

```text
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressSignedOutcome.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressOutcomeExpectationContract.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressChallengeReplayContract.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressSubjectTargetBinding.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressAuthorizationCatalog.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressRegistrationHeadContract.swift
repo://CellProtocol/Sources/CellBase/DeviceIngress/DeviceIngressMaximaContract.swift
repo://CellProtocol/Sources/CellDeviceIngressTransport/DeviceIngressOpaqueTransport.swift
repo://CellProtocol/Tools/DeviceIngress/device_ingress_maxima_v3.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressSignedOutcomeTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressChallengeReplayTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressSubjectTargetBindingTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressRegistrationHeadContractTests.swift
repo://CellProtocol/Tests/CellBaseTests/DeviceIngressMaximaV3Tests.swift
repo://CellProtocol/Tests/CellDeviceIngressTransportTests/DeviceIngressOpaqueTransportTests.swift
repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/manifest.v3.json
repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/consumer-applicability.v3.json
repo://CellProtocol/Docs/DeviceIngressNormativeCompositionV3.md
```

### 14.3 Exact CellScaffold config/provider/procedure paths

Owner is the single role named after each row; all are no-touch until a source
phase is separately authorized.

| Exact path | Owner / one responsibility |
|---|---|
| `repo://CellScaffold/Sources/App/Configuration/DeviceIngress/DeviceIngressAuthorityInputConfiguration.swift` | Lane B authority/config owner; manifest/catalog/binding locations and schemas |
| `repo://CellScaffold/Sources/App/Configuration/DeviceIngress/DeviceIngressPersistenceConfiguration.swift` | Lane B storage config owner; DB, discovery, quarantine roots |
| `repo://CellScaffold/Sources/App/Configuration/DeviceIngress/DeviceIngressReadinessConfiguration.swift` | Lane B readiness output owner |
| `repo://CellScaffold/Sources/App/Providers/DeviceIngress/DeviceIngressTrustedTimeProvider.swift` | trusted-time provider interface owner |
| `repo://CellScaffold/Sources/App/Providers/DeviceIngress/DeviceIngressRollbackAnchorProvider.swift` | rollback-anchor provider interface owner |
| `repo://CellScaffold/Sources/App/Providers/DeviceIngress/DeviceIngressSealedTokenKeyProvider.swift` | sealed-token key-provider interface owner |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacyArtifactDiscoveryProcedure.swift` | legacy finite discovery owner |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacySealedMigrationProcedure.swift` | sealed migration interface owner |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacyDeactivationProcedure.swift` | fail-closed deactivation owner |
| `repo://CellScaffold/Sources/App/Procedures/DeviceIngress/DeviceIngressLegacyDisposalEvidenceProcedure.swift` | disposal evidence interface owner |
| `repo://CellScaffold/Sources/App/Cells/DeviceIngress/DeviceIngressLegacyInventoryStore.swift` | inventory/adjudication/readiness transaction owner |
| `repo://CellScaffold/Configuration/DeviceIngress/authority-input.v1.schema.json` | authority config schema owner |
| `repo://CellScaffold/Configuration/DeviceIngress/persistence-input.v1.schema.json` | storage/discovery config schema owner |
| `repo://CellScaffold/Tests/AppTests/DeviceIngressLegacyInventoryStateTests.swift` | legacy state/crash test owner |
| `repo://CellScaffold/Tests/AppTests/DeviceIngressOutcomeUnionConsumerTests.swift` | server outcome consumer owner |
| `repo://CellScaffold/Tests/AppTests/DeviceIngressCurrentSubjectHeadTests.swift` | head/CAS/re-enroll owner |
| `repo://CellScaffold/Tests/AppTests/Fixtures/DeviceIngressCompositionV3/server-consumption.v3.json` | server consumer ledger owner |

Actual provider/procedure implementers and proofs are missing; a path is not a
PASS.

### 14.4 Exact Binding paths

Owner: Lane C, except project/dependency/entitlement rows above.

```text
repo://Binding/Binding/DeviceIngress/DeviceIngressSignedOutcomeVerifier.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressResponseExpectation.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressOperationJournal.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressJournalExtensions.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressConflictLocks.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressStableStore.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressClientReducer.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressResolveDeliveryHandoff.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressDeregisterLocalCleanup.swift
repo://Binding/Binding/DeviceIngress/DeviceIngressVaultContinuity.swift
repo://Binding/BindingTests/DeviceIngressSignedOutcomeVerifierTests.swift
repo://Binding/BindingTests/DeviceIngressResponseExpectationTests.swift
repo://Binding/BindingTests/DeviceIngressOperationJournalTests.swift
repo://Binding/BindingTests/DeviceIngressConflictLockSubprocessTests.swift
repo://Binding/BindingTests/DeviceIngressStableStoreCrashTests.swift
repo://Binding/BindingTests/DeviceIngressClientReducerTests.swift
repo://Binding/BindingTests/DeviceIngressResolveDeliveryHandoffTests.swift
repo://Binding/BindingTests/DeviceIngressDeregisterLocalCleanupTests.swift
repo://Binding/BindingTests/DeviceIngressVaultContinuityTests.swift
repo://Binding/BindingTests/Support/DeviceIngressMaximaV3Independent.swift
repo://Binding/BindingTests/Fixtures/DeviceIngressCompositionV3/client-consumption.v3.json
repo://Binding/Documentation/DeviceIngress_Client_Recovery_V3.md
```

### 14.5 Apple release no-touch rows

Final-byte owner: Apple release owner. DeviceIngress lanes have disposition
`immutable/no-touch`.

```text
repo://Binding/Documentation/AppleReleaseM0Policy.template.json
repo://Binding/Documentation/AppleReleaseM0Preflight.md
repo://Binding/Scripts/apple_release_m0_preflight.py
repo://Binding/Scripts/apple_release_m0_preflight.sh
repo://Binding/Tests/apple_release_m0_preflight_tests.py
repo://Binding/Tests/fixtures/apple_release_m0_preflight/facts-dirty.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/facts-pass.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/policy-mismatch.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/policy-pass.json
repo://Binding/Tests/fixtures/apple_release_m0_preflight/policy-pending.json
```

## 15. Complete versioned producer/consumer evidence ledger

### 15.1 Manifest schema

Producer path:

`repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionV3/manifest.v3.json`

Schema:

`cellprotocol.device-ingress.fixture-manifest.v3`

Top-level member order:

1. `compositionVersion`
2. `entries`
3. `maximaCalculatorVersion`
4. `schema`

Per-entry member order:

1. `consumerApplicability`
2. `decodedByteCount`
3. `decodedCoreSHA256`
4. `encodedByteCount`
5. `entryID`
6. `expectedDecision`
7. `fileSHA256`
8. `negativeApplicability`
9. `path`
10. `producerTest`
11. `role`
12. `sanitizedReason`
13. `schema`

`consumerApplicability` has exactly A/B/C members. Each is:

```text
required(testPath,testID,expectedDecision)
or
not_applicable(closedReason)
```

Closed non-applicable reasons:

- `producer_only_canonicalization`;
- `server_only_storage`;
- `client_only_local_state`;
- `transport_only`;
- `external_premise_unavailable`.

No future producer can toggle an unconstrained `consumerRequired` boolean.
Every entry has an explicit A/B/C disposition.

### 15.2 Exact test-code dictionary

| Code | Exact test path and identifier |
|---|---|
| A-OUT | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressSignedOutcomeTests.swift::fixture_<entryID>` |
| A-REP | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressChallengeReplayTests.swift::fixture_<entryID>` |
| A-AUTH | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressSubjectTargetBindingTests.swift::fixture_<entryID>` |
| A-HEAD | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressRegistrationHeadContractTests.swift::fixture_<entryID>` |
| A-MAX | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressMaximaV3Tests.swift::fixture_<entryID>` |
| B-OUT | `repo://CellScaffold/Tests/AppTests/DeviceIngressOutcomeUnionConsumerTests.swift::fixture_<entryID>` |
| B-REP | `repo://CellScaffold/Tests/AppTests/DeviceIngressChallengeTotalStateTests.swift::fixture_<entryID>` |
| B-AUTH | `repo://CellScaffold/Tests/AppTests/DeviceIngressAuthorityBootstrapTests.swift::fixture_<entryID>` |
| B-HEAD | `repo://CellScaffold/Tests/AppTests/DeviceIngressCurrentSubjectHeadTests.swift::fixture_<entryID>` |
| B-LEG | `repo://CellScaffold/Tests/AppTests/DeviceIngressLegacyInventoryStateTests.swift::fixture_<entryID>` |
| B-MAX | `repo://CellScaffold/Tests/Support/DeviceIngressMaximaV3Independent.swift::fixture_<entryID>` |
| C-OUT | `repo://Binding/BindingTests/DeviceIngressSignedOutcomeVerifierTests.swift::fixture_<entryID>` |
| C-JRN | `repo://Binding/BindingTests/DeviceIngressOperationJournalTests.swift::fixture_<entryID>` |
| C-LOCK | `repo://Binding/BindingTests/DeviceIngressConflictLockSubprocessTests.swift::fixture_<entryID>` |
| C-STORE | `repo://Binding/BindingTests/DeviceIngressStableStoreCrashTests.swift::fixture_<entryID>` |
| C-RED | `repo://Binding/BindingTests/DeviceIngressClientReducerTests.swift::fixture_<entryID>` |
| C-DEL | `repo://Binding/BindingTests/DeviceIngressResolveDeliveryHandoffTests.swift::fixture_<entryID>` |
| C-VAULT | `repo://Binding/BindingTests/DeviceIngressVaultContinuityTests.swift::fixture_<entryID>` |
| C-MAX | `repo://Binding/BindingTests/Support/DeviceIngressMaximaV3Independent.swift::fixture_<entryID>` |

### 15.3 Exact required entry ledger

All paths are relative to `DeviceIngressCompositionV3/`. `A/B/C` columns name
the exact test code above or `N/A:<closed reason>`.

| entryID | exact path | expected | A | B | C |
|---|---|---|---|---|---|
| F001 | `envelope/signature-protected-core.max.json` | accept | A-OUT | B-OUT | C-OUT |
| F002 | `envelope/signature-envelope.max.json` | accept | A-OUT | B-OUT | C-OUT |
| F003 | `envelope/signed-artifact.operation-success.json` | accept | A-OUT | B-OUT | C-OUT |
| F004 | `envelope/signed-artifact.authenticated-error.json` | accept | A-OUT | B-OUT | C-OUT |
| F005 | `envelope/signed-artifact.terminal-evidence.json` | accept | A-OUT | B-OUT | C-OUT |
| F006 | `outcome/response-core.register.json` | accept | A-OUT | B-OUT | C-OUT |
| F007 | `outcome/response-core.resolve.json` | accept | A-OUT | B-OUT | C-OUT |
| F008 | `outcome/response-core.submit.json` | accept | A-OUT | B-OUT | C-OUT |
| F009 | `outcome/response-core.status-registration.json` | accept | A-OUT | B-OUT | C-OUT |
| F010 | `outcome/response-core.status-admission.json` | accept | A-OUT | B-OUT | C-OUT |
| F011 | `outcome/response-core.revoke.json` | accept | A-OUT | B-OUT | C-OUT |
| F012 | `outcome/response-core.deregister.json` | accept | A-OUT | B-OUT | C-OUT |
| F013 | `outcome/auth-error.pre-challenge.json` | accept | A-OUT | B-OUT | C-OUT |
| F014 | `outcome/auth-error.post-challenge.json` | accept | A-OUT | B-OUT | C-OUT |
| F015 | `outcome/auth-error.admitted-terminal.json` | accept | A-OUT | B-OUT | C-OUT |
| F016 | `outcome/auth-error.operation-pending.json` | accept | A-OUT | B-OUT | C-RED |
| F017 | `outcome/auth-error.cross-attempt-substitution.json` | reject | A-OUT | B-OUT | C-OUT |
| F018 | `outcome/terminal-evidence.indeterminate.json` | accept-blocked | A-OUT | B-OUT | C-RED |
| F019 | `outcome/terminal-evidence.unavailable.json` | accept-blocked | A-OUT | B-OUT | C-RED |
| F020 | `outcome/expectation.variant-success.json` | accept | A-OUT | N/A:producer_only_canonicalization | C-OUT |
| F021 | `outcome/expectation.variant-error.json` | accept | A-OUT | N/A:producer_only_canonicalization | C-OUT |
| F022 | `outcome/expectation.variant-evidence.json` | accept | A-OUT | N/A:producer_only_canonicalization | C-OUT |
| F023 | `outcome/expectation.wrong-signer-role.json` | reject | A-OUT | B-OUT | C-OUT |
| F024 | `status/privacy-registration-correlation-suppressed.json` | accept | A-OUT | B-OUT | C-RED |
| F025 | `status/privacy-admission-absent.json` | accept-privacy | A-OUT | B-OUT | C-RED |
| F026 | `status/privacy-admission-wrong-subject.json` | accept-privacy | A-OUT | B-OUT | C-RED |
| F027 | `status/admission-error-available.json` | accept | A-OUT | B-OUT | C-RED |
| F028 | `status/admission-terminal-indeterminate.json` | accept-blocked | A-OUT | B-OUT | C-RED |
| F029 | `status/invalid-field-nullability.json` | reject | A-OUT | B-OUT | C-RED |
| F030 | `challenge/replay-active-exact.json` | exact stored challenge | A-REP | B-REP | C-OUT |
| F031 | `challenge/replay-expired-exact.json` | exact stored error | A-REP | B-REP | C-OUT |
| F032 | `challenge/replay-compacted-unused.json` | exact stored error | A-REP | B-REP | C-OUT |
| F033 | `challenge/replay-admitted-success.json` | exact stored outcome | A-REP | B-REP | C-OUT |
| F034 | `challenge/replay-admitted-error.json` | exact stored outcome | A-REP | B-REP | C-OUT |
| F035 | `challenge/replay-admitted-evidence.json` | exact stored evidence | A-REP | B-REP | C-OUT |
| F036 | `challenge/u2-intent-id-conflict.json` | reject | A-REP | B-REP | C-OUT |
| F037 | `challenge/u3-nonce-conflict.json` | reject | A-REP | B-REP | C-OUT |
| F038 | `challenge/u4-corrupt-missing-row.json` | unavailable | A-REP | B-REP | C-OUT |
| F039 | `challenge/wrong-subject-oracle-pair.json` | privacy-equivalent | A-REP | B-REP | C-OUT |
| F040 | `authority/catalog-signer-delegation.json` | accept-structure | A-AUTH | B-AUTH | C-OUT |
| F041 | `authority/subject-target-binding.json` | accept-structure | A-AUTH | B-AUTH | C-OUT |
| F042 | `authority/binding-wrong-owner.json` | reject | A-AUTH | B-AUTH | C-OUT |
| F043 | `authority/binding-wrong-delegation.json` | reject | A-AUTH | B-AUTH | C-OUT |
| F044 | `authority/consent-exact-authority-hashes.json` | accept-structure | A-AUTH | B-AUTH | C-OUT |
| F045 | `authority/consent-substituted-conditions.json` | reject | A-AUTH | B-AUTH | C-OUT |
| F046 | `authority/catalog-wrong-mutation-mode.json` | reject | A-AUTH | B-AUTH | C-OUT |
| F047 | `authority/catalog-wrong-status-kind.json` | reject | A-AUTH | B-AUTH | C-OUT |
| F048 | `authority/missing-external-signer.json` | unavailable | A-AUTH | B-AUTH | C-OUT |
| F049 | `head/deregister-reenroll-cycle.json` | accept-current-only | A-HEAD | B-HEAD | C-RED |
| F050 | `head/repeated-deregister-reenroll.json` | accept-current-only | A-HEAD | B-HEAD | C-RED |
| F051 | `head/concurrent-enroll-revoke-deregister.json` | serialize | A-HEAD | B-HEAD | C-LOCK |
| F052 | `head/historical-retention-removed.json` | privacy-unknown | A-HEAD | B-HEAD | C-RED |
| F053 | `head/old-id-mutation-after-deletion.json` | reject | A-HEAD | B-HEAD | C-RED |
| F054 | `head/restart-multiple-head-corruption.json` | unavailable | A-HEAD | B-HEAD | C-RED |
| F055 | `limits/protected-core.502.json` | accept | A-MAX | B-MAX | C-MAX |
| F056 | `limits/protected-core.503.json` | accept | A-MAX | B-MAX | C-MAX |
| F057 | `limits/protected-core.504.json` | reject | A-MAX | B-MAX | C-MAX |
| F058 | `limits/envelope.2128.json` | accept | A-MAX | B-MAX | C-MAX |
| F059 | `limits/envelope.2129.json` | accept | A-MAX | B-MAX | C-MAX |
| F060 | `limits/envelope.2130.json` | reject | A-MAX | B-MAX | C-MAX |
| F061 | `limits/normal-outcome.120986.json` | accept | A-MAX | B-MAX | C-MAX |
| F062 | `limits/normal-outcome.120987.json` | accept | A-MAX | B-MAX | C-MAX |
| F063 | `limits/normal-outcome.120988.json` | reject | A-MAX | B-MAX | C-MAX |
| F064 | `limits/admission-outcome.292476.json` | accept | A-MAX | B-MAX | C-MAX |
| F065 | `limits/admission-outcome.292477.json` | accept | A-MAX | B-MAX | C-MAX |
| F066 | `limits/admission-outcome.292478.json` | reject | A-MAX | B-MAX | C-MAX |
| F067 | `limits/token.4095.json` | accept | A-MAX | B-MAX | C-MAX |
| F068 | `limits/token.4096.json` | accept | A-MAX | B-MAX | C-MAX |
| F069 | `limits/token.4097.json` | reject | A-MAX | B-MAX | C-MAX |
| F070 | `limits/token.0.json` | reject | A-MAX | B-MAX | C-MAX |
| F071 | `legacy/inventory-all-artifact-classes.json` | gate-red | N/A:server_only_storage | B-LEG | N/A:server_only_storage |
| F072 | `legacy/crash-sealed-migration.json` | gate-red/recover | N/A:server_only_storage | B-LEG | N/A:server_only_storage |
| F073 | `legacy/crash-deactivation.json` | gate-red/recover | N/A:server_only_storage | B-LEG | N/A:server_only_storage |
| F074 | `legacy/restored-copy-after-terminal.json` | requarantine | N/A:server_only_storage | B-LEG | N/A:server_only_storage |
| F075 | `legacy/missing-provider-proof.json` | unavailable | N/A:external_premise_unavailable | B-LEG | N/A:external_premise_unavailable |
| F076 | `journal/register-extension.json` | accept | A-OUT | N/A:client_only_local_state | C-JRN |
| F077 | `journal/resolve-extension.json` | accept | A-OUT | N/A:client_only_local_state | C-JRN |
| F078 | `journal/submit-extension.json` | accept | A-OUT | N/A:client_only_local_state | C-JRN |
| F079 | `journal/status-extension.json` | accept | A-OUT | N/A:client_only_local_state | C-JRN |
| F080 | `journal/revoke-extension.json` | accept | A-OUT | N/A:client_only_local_state | C-JRN |
| F081 | `journal/deregister-extension.json` | accept | A-OUT | N/A:client_only_local_state | C-JRN |
| F082 | `journal/extension-digest-substitution.json` | reject | A-OUT | N/A:client_only_local_state | C-JRN |
| F083 | `journal/register-revoke-deregister-race.json` | serialize | N/A:client_only_local_state | N/A:client_only_local_state | C-LOCK |
| F084 | `journal/resolve-submit-race.json` | serialize | N/A:client_only_local_state | N/A:client_only_local_state | C-LOCK |
| F085 | `journal/stable-media-loss-after-readback.json` | unavailable | N/A:client_only_local_state | N/A:client_only_local_state | C-STORE |
| F086 | `reducer/local-absent-status-only.json` | status-only | A-OUT | N/A:client_only_local_state | C-RED |
| F087 | `reducer/invalid-vault-no-status.json` | unavailable | N/A:external_premise_unavailable | N/A:client_only_local_state | C-RED |
| F088 | `reducer/error-retry-class-matrix.json` | exact branch | A-OUT | B-OUT | C-RED |
| F089 | `reducer/terminal-evidence-never-success.json` | blocked | A-OUT | B-OUT | C-RED |
| F090 | `resolve/handoff-crash-before-sink.json` | recover | N/A:client_only_local_state | N/A:client_only_local_state | C-DEL |
| F091 | `resolve/handoff-crash-after-sink.json` | deduplicate | N/A:client_only_local_state | N/A:client_only_local_state | C-DEL |
| F092 | `resolve/missing-idempotent-sink.json` | unavailable | N/A:external_premise_unavailable | N/A:client_only_local_state | C-DEL |
| F093 | `vault/continuity-envelope.json` | accept-structure | A-OUT | N/A:client_only_local_state | C-VAULT |
| F094 | `vault/copied-identifiers-and-mac-key.json` | unavailable | N/A:external_premise_unavailable | N/A:client_only_local_state | C-VAULT |
| F095 | `vault/nonexportable-without-rollback.json` | unavailable | N/A:external_premise_unavailable | N/A:client_only_local_state | C-VAULT |
| F096 | `vault/rollback-without-copy-proof.json` | unavailable | N/A:external_premise_unavailable | N/A:client_only_local_state | C-VAULT |
| F097 | `vault/missing-hardware-attestation.json` | unavailable | N/A:external_premise_unavailable | N/A:client_only_local_state | C-VAULT |
| F098 | `deregister/server-commit-before-local-erase.json` | ordered | A-OUT | B-OUT | C-RED |
| F099 | `deregister/local-erase-before-server-commit.json` | reject | A-OUT | B-OUT | C-RED |
| F100 | `manifest/consumer-entry-omission.json` | reject | A-OUT | B-OUT | C-OUT |

The manifest contains exactly F001...F100. No timestamp or optional entry
exists. Every file has one byte count, SHA-256, decoded-core rule, role,
decision, sanitized reason, and the exact applicability row above.

The server and Binding consumer ledgers copy no signed expected bytes. They
record the producer manifest SHA/shape and each exact consumed entry SHA/shape,
test path/ID, decision, and decoded/encoded counts. Any omission, extra row,
hash drift, local re-signing, wrong applicability, or changed maxima trace
fails.

Actual future manifest, fixture, and consumer-ledger hashes remain missing and
must later be included in `MBI-07`.

## 16. External premises and unresolved human decision

### 16.1 Privacy retention

```text
MBI-PRIVACY-RETENTION-01: OPEN
OWNER: Kjetil
S5 DECISION CREDIT: NONE
```

Still undecided:

- legitimate purpose;
- tombstone/head/historical-record duration;
- same-subject disclosure duration;
- compaction/deletion;
- backup/restore exposure and destruction;
- revoke-retained ciphertext permission/duration;
- truthful user wording.

Until independently decided:

```text
DEREGISTER PRODUCTION AVAILABILITY: NO-GO
TOMBSTONE/HISTORICAL COMPACTION: DISABLED
PRIVACY/LEGITIMATE-PURPOSE CLAIM: NONE
```

S5 defines behavior before/after a permitted deletion but does not permit the
deletion.

### 16.2 Identity and authority

Identity cutover remains separate/open. External signer, key, descriptor,
manifest, delegation, catalog, Agreement, Contract, Grant, Conditions,
consent, revocation, trusted-time, rollback, and subject-target bytes remain
missing.

All accepted sets named in section 8.6 remain EMPTY. A path/schema cannot make
them non-empty.

### 16.3 Transport, Apple, and integrated output

`MBI-TRANSPORT-FRAMING-01` remains missing. HTTP method/path, carrier/media,
outer fields/order, framing overhead, status/error mapping, proxy authority,
and deterministic framing fixtures are not selected.

```text
MBI-06:
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING

MBI-07:
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/fixture/evidence/artifact manifest
= MISSING
```

Bundle/topic/origin provide no production proof.

## 17. Root-cause disposition

| Root cause | S5 author disposition | Remaining non-static premise |
|---|---|---|
| `S5-RC-01` outcome union/expectation | exact union, variant/core/signer/attempt binding and reducer mapping defined | actual signer/catalog/vault bytes EMPTY |
| `S5-RC-02` challenge replay | exact U1...U4 precedence, expiry outcome, error terminal kind, compacted read-back defined | durable runtime/rollback evidence missing |
| `S5-RC-03` binding/catalog | exact artifact, delegation, complete tuple and consent digests defined | all external authority bytes EMPTY |
| `S5-RC-04` subject head | atomic head/CAS and retention-independent behavior defined | privacy duration remains Kjetil-open |
| `S5-RC-05` maxima | non-escaping alphabet, exact functions/literals/contributions and boundaries defined | independent implementation/test evidence missing |
| `S5-RC-06` legacy | canonical inventory/adjudication/readiness states and crash premises defined | provider/procedure/custody proofs EMPTY |
| `S5-RC-07` Binding reducer | six extension schemas, conflict keys, stable store, gates, outcomes and resolve handoff defined | store/sink platform proofs EMPTY |
| `S5-RC-08` vault continuity | canonical core/envelope and distinct copy/rollback slots defined | all continuity/hardware/custody proofs EMPTY |

Static text may be independently judged sufficient or insufficient. No row is
runtime-, source-, Identity-, hardware-, or production-closed by author claim.

## 18. Independent reviewer checklist

A reviewer distinct from S3/S4/S5 authors must:

1. bind S3, S4, S5, and all six reviews by exact path/SHA/shape;
2. reproduce S4 terminal lane counts without importing an arithmetic sum;
3. map every S4 P1/P2 observation to exactly one S5 root/class or identify a
   missing/duplicate mapping;
4. prove core → protected core → signature → envelope → artifact and
   body → intent → challenge → request → outcome remain acyclic;
5. verify exactly six operations and no rotation operation;
6. reproduce the SignedOutcomeArtifact discriminator/core/artifactKind matrix;
7. reproduce all outcome field/nullability/error/retry/signer/result/status
   mappings and prove a non-success can never establish success/current truth;
8. reproduce ResponseExpectation allowed variants and EMPTY-set behavior;
9. adversarially check correlation privacy, nested admission outcome, and
   absent/wrong-subject oracle equivalence;
10. exhaust every U1...U4/state/input combination, expiry stored bytes,
    authenticated-error terminal kind, compacted replay, sequence, and no
    reconstruction/re-sign;
11. verify the complete subject-target/delegation/catalog/consent tuple and
    every substitution/rotation/revocation/validity failure;
12. verify current-head lock/CAS ordering across repeated deregister/re-enroll,
    concurrent status/mutations, restart, historical deletion, and restore;
13. independently calculate every string/member/literal/Base64/envelope/core/
    response/nested maximum with checked arithmetic;
14. verify max-1/max/max+1 fixtures are semantically reachable and consumer
    limits agree;
15. verify legacy identity is metadata-only, discovery scope is finite,
    readiness is atomically red, and every crash/restore/concurrency branch is
    total;
16. verify all six journal extension bytes/digests, conflict-class locks,
    stable-media transaction, local-state operation gates, error/evidence
    reducer branches, and resolve delivery handoff;
17. verify authoritative server deregister always precedes local erasure;
18. prove vault continuity schema does not claim copy/rollback resistance and
    every missing MBI makes accepted proof sets empty;
19. verify every repo-qualified path has one final-byte owner/disposition;
20. verify F001...F100 each maps to exact A/B/C applicability, test, decision,
    byte counts, reason, and consumer ledger;
21. preserve token zero-leakage and the HAVEN-only 1...4096 resource bound;
22. preserve privacy, Identity, framing, MBI-06/07, all material/action, S6,
    and production NO-GOs.

No reviewer is opened or credited by this authoring act.

## 19. Preserved stop gates

```text
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
NEXT PHASE: CLOSED / NO-GO
S6: CLOSED / NO-GO
PRODUCTION: CLOSED / NO-GO
```

No static schema, fixture name, provider interface, hardware slot, or path
substitutes for actual source/runtime/storage/Identity/Apple/device/APNS/
integration evidence.

## 20. Final author freeze

```text
S5 ADDITIVE CORRECTION: AUTHOR-FROZEN
EFFECTIVE ORDER: S3 -> S4 -> S5

S3:
  5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40
  2403 lines / 72649 bytes
S4:
  99c5b0e5ba35bddba3cd3d762ea7e3930295799661a75dfe4bcde9e882c761aa
  2377 lines / 79288 bytes

S4 REVIEW TERMINAL COUNTS:
  A = 0/5/2
  B = 0/5/2
  C = 0/4/2
S5 CONSOLIDATED ROOT CAUSES: 8
S5 P2 CLASSES: 2
INDEPENDENT S5 CLOSURE CREDIT: NONE

ACYCLIC ENVELOPE: PRESERVED
WIRE OPERATIONS: EXACTLY SIX
ROTATION: REGISTER MUTATION ONLY
TRANSPORT: OPAQUE / NON-AUTHORITATIVE
TOKEN: OPAQUE 1...4096 HAVEN RESOURCE BOUND ONLY
TOKEN/TOKEN-HASH LEAKAGE: FORBIDDEN
SERVER DEREGISTER BEFORE LOCAL ERASE: PRESERVED
ORIGIN: https://haven.digipomps.org
BUNDLE/TOPIC: org.digipomps.haven

EXTERNAL AUTHORITY SETS: EMPTY
EXTERNAL PROVIDER/PROCEDURE SETS: EMPTY
VAULT/HARDWARE/CUSTODY PROOF SETS: EMPTY
HARDWARE PASS: NONE

MBI-PRIVACY-RETENTION-01: OPEN / KJETIL
IDENTITY CUTOVER: SEPARATE / OPEN / NO-GO
MBI-TRANSPORT-FRAMING-01: MISSING
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
PLAN: NO-GO
NEXT PHASE: NO-GO
S6: NO-GO
SOURCE AUTHORIZATION: NONE
MATERIAL AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

The only permissible successor is a new independent exact-byte static review
of this frozen S5 artifact by reviewers distinct from every S5 author. No
source, Git, dependency, build, test, network, portal, signing, device, APNS,
Identity, staging, deployment, integration, material, S6, next-phase, or
production action is authorized.
