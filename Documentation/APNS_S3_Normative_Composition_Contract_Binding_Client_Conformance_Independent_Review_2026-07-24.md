# APNS S3 Normative Composition Contract — Binding Client Conformance Independent Review

Date: 2026-07-25 local / 2026-07-24 UTC  
Review lane: S3 Lane C, Binding client conformance  
Reviewer role: independent of the S3 contract author  
Review type: exact-byte, static, document-only  
Source/runtime credit: none

## 1. Scope, authority, and stop conditions

This review evaluates only whether the frozen S3 normative composition contract
is a sufficient static contract for a fail-closed Binding client consumer.

The sole review target is:

```text
Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md
```

The sole output is this file:

```text
Documentation/APNS_S3_Normative_Composition_Contract_Binding_Client_Conformance_Independent_Review_2026-07-24.md
```

Before writing, the output path was re-attested absent.

This review did not:

- modify source, project, dependency, Git, Identity, portal, signing, device,
  APNS, staging, deployment, or production state;
- build, test, resolve dependencies, contact a network service, inspect a
  secret, inspect a raw APNS token, or inspect private key material;
- grant self-review credit to the S3 author;
- authorize a successor phase.

The S0, S1, and S2 documents remain immutable. Identity cutover remains a
separate prerequisite.

## 2. Exact target re-attestation

Re-attested at:

```text
UTC:   2026-07-24T22:36:26Z
local: 2026-07-25T00:36:26+0200 CEST
```

| Property | Exact value |
|---|---|
| Reviewed path | `Documentation/APNS_S3_Normative_Composition_Contract_2026-07-24.md` |
| SHA-256 | `5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40` |
| Lines | 2403 |
| Bytes | 72649 |

The required target shape is reproduced exactly:

```text
5653e34fea6fce25248b04821127ddab95d64235d6b134c0799f0e5e92446b40
2403 lines
72649 bytes
```

## 3. Exact 16-artifact lineage re-attestation

All 16 S0/S1/S2 artifacts were rehashed and reshaped locally. Lineage does not
promote any prior author proposal to canonical source or runtime truth.

### 3.1 S0

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

S0 remains:

```text
P0/P1/P2 = 0/2/1
PLAN = NO-GO
NEXT PHASE = NO-GO
```

### 3.2 S1

| Lane | Artifact | SHA-256 | Lines | Bytes | Frozen review |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | author packet |
| A | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md` | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | `0/5/2`, NO-GO |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | author packet |
| B | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md` | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | `0/4/1`, NO-GO |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | author packet |
| C | `Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md` | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | `0/3/4`, NO-GO |

### 3.3 S2

| Lane | Artifact | SHA-256 | Lines | Bytes | Frozen review |
|---|---|---|---:|---:|---|
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_2026-07-24.md` | `1b750373b4cb98c71983b002b6a2ce1fd809086776bd64b92d3b27e386969854` | 1746 | 69053 | author packet |
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `0f2e813f481dcc9fade979a38dbf6e2a3814d743411dfec0fe63def525ed687a` | 759 | 32502 | `0/4/2`, NO-GO |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_2026-07-24.md` | `cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4` | 1127 | 52292 | author packet |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `f12db49ca272fcbbe5d577c401c21c64b6d6156d9633e0e49fded9796a9fc1ad` | 1400 | 57603 | `0/5/1`, NO-GO |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_2026-07-24.md` | `6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56` | 1112 | 52295 | author packet |
| C | `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_Independent_Review_2026-07-24.md` | `9a80ac8fb42103e27cfe8c3efe5681479e8c4458f2144ebb0d42c3726f6bd365` | 601 | 32361 | `0/4/0`, NO-GO |

## 4. Relevant Lane C historical inputs

These are reproduced as historical inputs, not promoted source baselines.

| Boundary | Commit | Tree | Status in this review |
|---|---|---|---|
| Historical CellProtocol v3 candidate | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` | `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` | superseded as a wire contract by S3 proposal |
| Historical CellProtocol v3 base | `79740304167aa4f4daadd148c5a369e919d25a6a` | `71ee11a69139a1c222c2156ab1bc79dbe0115620` | lineage only |
| Binding common base | `f6536c497b0a4c0a5b32531416bb3712708cf47e` | `ac894efa9e709e788eaa1dc863db1070786fbe0b` | historical composition input |
| Binding inert P1 candidate | `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c` | `e0d6c9ff4fb998fa252ab86621abfe24398d7b18` | historical client input; no runtime credit |
| Apple M1 endpoint | `2d2412090a65e101435ea91c8ea36bc060d3c768` | `34421cbabe9e801fa96da315a191ed23cd023ec8` | separate owner/no-touch input |

Additional exact historical facts:

```text
Binding P1 endpoint paths:          13
Binding P1 name-status SHA-256:     29495a23af28ca7842836f916593f9bdcde79c0d08076422b975e9c405d69f80
Apple M1 endpoint paths:            11
Apple M1 name-status SHA-256:       94c535870b86bcb796ff83f36dda6785db24045343f5b288499282bade13b8b0
Historical CellScaffold carrier:    d2d1b7191d651ad42d172e980ab94a0fd478d07c
```

The inert Binding P1 candidate historically supplied:

- a persistent authenticated CellApple vault Identity in
  `domain:device:notification-callback`;
- no-create behavior for a missing notification Identity;
- response-expectation persistence before a mutation-capable send;
- a descriptor-relative, cross-process-locked evidence store;
- rebound of historical evidence to the currently opened vault/key/build;
- deletion of legacy raw-token `UserDefaults` values without reading them;
- raw-token memory-only handling; and
- inert runtime registration/resolve/submit.

S3 does not inherit those requirements merely by listing the S1/S2 artifact
hashes. A normative successor must explicitly carry forward or deliberately
replace every security-relevant client invariant.

## 5. Positive conformance observations

The following portions are sufficiently exact as a static shared-wire proposal.
They receive no source/runtime/test credit.

### 5.1 Shared bytes and acyclic construction

- Lines 217–460 define one canonical JSON profile, signature-protected core,
  signature envelope, signed artifact, digest input, and a one-direction
  body→intent→challenge→request→response construction.
- Lines 380–393 require exact schema, digest, artifact-kind, signer, signature,
  domain, purpose, audience, operation, target, authority, generation, and time
  verification.
- Lines 2153–2154 require consumers to use exact producer fixture bytes rather
  than regenerate signed expected artifacts.
- Lines 1952–1964 require Lane C to consume reviewed producer bytes, preserve
  response bytes, and fail closed.

Verdict:

```text
BYTE-IDENTICAL SHARED CORE/ENVELOPES: STATIC PASS
FIXTURE CONSUMER RULE: STATIC PASS; FIXTURE BYTES/HASHES NOT YET PRODUCED
HTTP AUTHORITY: NONE
```

### 5.2 Exact production planning bindings

Lines 192–215 freeze:

```text
identity domain = domain:device:notification-callback
purpose         = purpose://access.audit.privacy/device-notification-callback
audience        = haven.digipomps.org
origin          = https://haven.digipomps.org
bundle          = org.digipomps.haven
APNS topic      = org.digipomps.haven
environment     = production
```

The document correctly states that these planning literals do not prove
profile, entitlement, signing, provider acceptance, or device delivery.

### 5.3 Exact wire operation and authority surface

Lines 462–505 define exactly six wire operations:

```text
register
resolve
submit
status
revoke
deregister
```

Token rotation is correctly a `register` mutation mode, not a seventh
operation. Status is `r--s`; mutations are `rw-s`. Lines 607–609 and 1732–1798
keep HTTPS/Host/route/transport possession non-authoritative. Lines 1800–1821
leave actual trust and authority bytes missing and fail closed.

### 5.4 Signed intent, challenge, admission, request, and response

- IntentCore at lines 507–556 binds body hash, operation tuple, client intent,
  client nonce, subject descriptor, minimum issuer generation, and time.
- ChallengeCore at lines 558–612 binds intent, issuer, target Cell/owner,
  Agreement, Contract, Grant, generations, server nonce, and time.
- Admission ID at lines 614–676 has a versioned length-prefixed derivation and
  is explicitly not the old v3 request-hash projection.
- RequestCore and CanonicalOperationRequest at lines 678–732 bind the unchanged
  body and the signed intent/challenge.
- ResponseCore at lines 1011–1061 is one signed application response and the
  HTTP wrapper remains semantically neutral.

### 5.5 Registration correlation and status taxonomy

- RegisterBodyCore and RegisterReceiptCore bind registration ID, body digest,
  generations, mutation mode, `tokenObservationID`, and
  `tokenDeliveryEpoch`.
- RotationJournalCore carries the non-secret token-observation correlation
  before send and excludes token, token hash, body, request, key, and callback
  payload bytes.
- Lines 1258–1307 distinguish exactly:
  `subject_current_unknown`, `correlation_not_found`, and `privacy_unknown`.
- Local absence is not one of those signed server results and therefore cannot
  prove a server negative.

These points close the specific old S2 findings about missing pre-send token
correlation, the obsolete v3 admission identifier, and collapsed status
negatives. They do not close the new client-state findings below.

## 6. Finding summary

```text
P0: 0
P1: 3
P2: 2
```

No P0 was found because the contract consistently keeps runtime and production
gates closed. The P1 findings prevent Lane C conformance and source
authorization; a conforming client cannot safely fill the gaps by inference.

## 7. P1 findings

### P1-S3-C-01 — RotationJournalCore is not a complete durable response expectation

#### Evidence

S3 lines 380–393 require a response verifier to enforce:

- signer descriptor, key ID, and algorithm;
- domain, purpose, audience, operation, and time;
- target Cell and owner;
- Agreement, Contract, Grant, conditions, and generations.

S3 lines 411–418 permit the client to persist only non-secret identifiers and
digests required by section 18.

RotationJournalCore at lines 1327–1348 has exactly 14 fields:

```text
admissionID
bodySHA256
challengeArtifactSHA256
expectedRegistrationGeneration
expectedRevocationGeneration
intentArtifactSHA256
journalID
mutationMode
registrationID
requestArtifactSHA256
schema
sendState
tokenDeliveryEpoch
tokenObservationID
```

It does not retain a complete immutable response expectation. In particular, it
does not retain:

- Identity domain and the vault-bound requester identity/key binding;
- purpose, audience, operation tuple, or status kind;
- target Cell ID and expected target-owner descriptor;
- Agreement, Contract, and Grant hashes;
- authority, issuer, and revocation generations;
- expected response/result schemas and signer binding;
- intent/challenge validity interval or the historical issuer descriptor;
- an exact expectation-record ID and expectation digest.

Lines 1399–1404 prohibit reconstruction of request/body bytes after restart and
require status recovery. Lines 1319–1323 may return an exact nested historical
response during admission read-back, but the journal has only the nested
response's request/body/challenge digests—not the complete historical
expectation needed to verify every rule at lines 380–393.

The problem is sharpened by line 418: a Binding implementation may not simply
persist the missing non-secret expectation fields unless the normative
contract first permits and specifies them.

#### Impact

After a crash, Binding has no complete durable, vault-bound, owner/Contract-
pinned expectation against which to verify a nested read-back response.
Verifying against only live/current authority can accept an unintended
historical substitution after legitimate rotation; rejecting all such
responses leaves ambiguous recovery permanently blocked. Reconstructing the
expectation from the response would let the response define what it was
supposed to prove.

This prevents the required:

```text
persist complete response expectation
  -> cross send boundary
  -> crash/restart
  -> retrieve exact historical response
  -> verify against pre-send expectation
  -> adjudicate without replay
```

#### Smallest safe successor scope

One document-only S3 correction must define a Binding-local, non-authoritative,
canonical response-expectation record for every operation. It must:

1. name exact schema, member order, encodings, maxima, and nullable rules;
2. bind the current persistent vault identity/key/domain;
3. bind request/body/intent/challenge/admission identifiers and digests;
4. pin target Cell/owner, Agreement/Contract/Grant, generations, signer,
   operation tuple, response/result schema, purpose/audience, and validity;
5. be persisted/read back before send under the same journal transaction;
6. have a digest referenced by the operation journal;
7. exclude raw token, request/body bytes, private key, server secret, and
   unredacted callback payload;
8. define historical key-rotation verification without accepting a current
   descriptor as proof of the historical expectation.

No source implementation is authorized.

**Verdict:** **OPEN P1 / CRASH-RECOVERY VERIFICATION NOT COMPOSABLE**.

### P1-S3-C-02 — The Binding client state contract is not total for six operations

#### Evidence

The wire enum is correctly six operations at lines 462–481. The durable client
schema at lines 1325–1414 is nevertheless registration-specific:

- it is named `RotationJournalCore`;
- it contains `mutationMode`, registration generations, registration ID, token
  observation ID, and token delivery epoch;
- its terminal `finalized_current` state means current active registration;
- resolve/submit recovery is covered only by the sentence at lines 1413–1414.

No exact Binding-local durable state/transition schema is defined for:

- `resolve`;
- `submit`;
- registration or admission `status`;
- `revoke`;
- `deregister`.

The contract has no client transition that binds a prepared revoke/deregister
expectation to a local stop intent, retains it over an ambiguous send, verifies
the typed receipt plus fresh current status, and atomically updates local truth.

The deregistration transaction at lines 1658–1676 specifies authoritative
server deletion. It does not specify Binding's required local transition after
a verified authoritative commit:

```text
erase raw token/active local binding
retain only the permitted minimal signed tombstone
read back the local commit
publish deregistered/unknown UI truth
```

The tombstone retention itself remains subject to the unresolved owner choice.

S3 line 141 states that prior author packets are not promoted by lineage. The
author disposition at line 2240 therefore cannot close the exact
resolve/submit state requirement by referring to “existing client state
ownership” without incorporating a normative state contract.

#### Impact

Binding cannot derive a total reducer for all six operations. A crash or
cross-process race around resolve, submit, revoke, or deregister has no exact
durable transition, retention, retry, read-back, finalization, or UI-state
rule. Implementations could diverge while all claiming S3 conformance.

The gap is particularly privacy-sensitive for deregistration: server deletion
does not automatically delete a client-side token/default, active binding, or
stale evidence. Conversely, local deletion before a verified authoritative
commit could erase the recovery handle while falsely presenting server-side
success.

#### Smallest safe successor scope

The same document-only S3 correction must freeze one Binding-local total reducer
covering:

```text
challenge -> prepare -> expectation durable -> send ambiguous
-> verified response or admission read-back -> fresh status where required
-> atomic finalization or typed blocked state
```

It must enumerate exact durable and volatile fields, transitions, crash
boundaries, cross-process serialization, retry prohibition, read-back selectors,
and terminal truth for register, resolve, submit, status, revoke, and
deregister. Revoke and deregister must remain distinct.

For authoritative deregistration, it must explicitly order:

1. verify response and minimal signed tombstone against the pre-send
   expectation;
2. obtain any required fresh signed current status;
3. commit/read back local raw-token/active-binding erasure;
4. retain only the owner-approved minimal tombstone evidence;
5. publish current or unknown state only after the durable transaction.

No source implementation is authorized.

**Verdict:** **OPEN P1 / SIX-OPERATION CLIENT REDUCER NOT DEFINED**.

### P1-S3-C-03 — Persistent vault/evidence continuity is not normative at the Lane C boundary

#### Evidence

S3 fixes the identity-domain literal at line 197 and binds
`requesterDescriptorSHA256` into intent, challenge, request, response, admission,
and status authorization. Lines 1800–1821 correctly leave requester Identity
descriptors and proof paths missing and keep Identity cutover separate.

However, the Lane C duties at lines 1952–1964 do not require Binding to:

- open exactly one existing persistent CellApple Identity in
  `domain:device:notification-callback`;
- use no-create behavior for a missing/locked/ephemeral vault;
- rebind every restored journal/expectation/evidence record to the currently
  opened vault identity and signing-key fingerprint;
- reject copied evidence from another device/vault/build;
- treat empty, restored, rejected, or lost local evidence as server state
  `UNKNOWN`;
- prohibit bearer/shared server-secret inputs;
- require a verified signed receipt plus the contract-required fresh signed
  status before publishing current active registration.

The exact 2403-line S3 target contains:

```text
UserDefaults occurrences:       0
IdentityVault occurrences:      0
vault occurrences:              0
responseExpectation occurrences: 0
serversecret occurrences:       0
```

Its one `makeNewIfNotFound` occurrence is the server infrastructure no-create
rule at line 1564, not the Binding vault rule.

The relevant S1/S2 Lane C requirements exist only in historical author packets:
S1 C lines 122–141 and S2 C lines 132–140, 178–225, and 238–283. S3 does not
incorporate them normatively, and its own line 141 denies automatic promotion
through lineage.

#### Impact

A future client could satisfy S3's visible journal and signature fields while
using a newly created or different device identity, trusting copied historical
evidence, accepting a legacy server secret, or converting empty local state into
“not registered.” That would break identity continuity, privacy, and current-
state correctness even though the wire artifacts remain valid.

Keeping Identity cutover separate is correct. The defect is not that S3 fails
to perform cutover; it is that Lane C lacks the exact fail-closed consumer
boundary while the required Identity input is absent or changes.

#### Smallest safe successor scope

The document-only correction must carry forward, without performing Identity
work:

- existing persistent vault only; no-create;
- exact domain and requester descriptor/key continuity;
- journal/evidence binding to the current vault and approved build evidence;
- copied/restored/legacy evidence rejection;
- local absence/loss/rejection maps only to `UNKNOWN`;
- no bearer/shared server secret or legacy Authorization input;
- fresh signed current-status requirements for active/revoked/deregistered
  local truth;
- fail-closed unavailable states for locked/missing vault, missing trust
  material, rotation gap, rollback, and identity mismatch.

The actual Identity descriptors, keys, rotation records, and cutover evidence
remain separate missing inputs.

**Verdict:** **OPEN P1 / LANE C IDENTITY CONTINUITY CONTRACT INCOMPLETE**.

## 8. P2 findings

### P2-S3-C-01 — The exact Binding consumer path/owner/collision allowlist is incomplete

#### Evidence

S3 lines 2029–2045 propose five source files, five test files, and one document:

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

The list omits the existing Binding integration paths that own APNS token
ingress, consent, enrollment, callback flow, and current registration logic,
including the exact historical paths frozen in S2 C lines 788–824. It also does
not name:

- an exact six-operation state-machine source/test path;
- a hardened evidence/expectation store source/test path;
- challenge-intent/vault continuity source/test paths;
- token-observation and deregister-local-cleanup source/test paths;
- an exact producer-manifest consumer fixture path;
- `Binding.xcodeproj/project.pbxproj` as the development-admin collision path;
- `Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  as the conditional dependency-lock path;
- `Binding/Binding-iOS.entitlements` as separately owned/no-touch;
- the ten other Apple M1 no-touch paths.

Line 2045 says integration/collision paths remain excluded, but exclusion does
not reproduce the exact path and owner ledger required to prevent collision.
Line 2241 claims Apple no-touch is preserved without reproducing the path set.

#### Impact

The contract does not provide an exhaustive future source boundary. A source
author cannot know which existing runtime files must change, which exact project
bytes are development-admin-owned, or which Apple/entitlement/dependency bytes
must remain untouched.

#### Smallest safe successor scope

Extend the document-only path packet with one exact allowlist/no-touch/collision
table. Every file must have one owner and one disposition:

```text
include
conditional development-admin integration
immutable/no-touch
defer/blocked
```

No file outside the reviewed table may be authorized later without a new
document-only decision and independent review.

**Verdict:** **OPEN P2 / EXACT CONSUMER OUTPUT BOUNDARY INCOMPLETE**.

### P2-S3-C-02 — The client negative-test packet is not path- and transition-exact

#### Evidence

S3 lines 2185–2195 list nine broad client test themes. They do not enumerate the
exact negative fixtures/assertions required for the newly normative client
boundary.

Missing explicit cases include:

- response read-back with correct request/body/challenge digests but wrong
  historical vault, target owner, Agreement, Contract, Grant, signer, result
  schema, purpose, audience, generation, or validity;
- empty/restored/copied/legacy evidence and vault-key replacement;
- missing/locked/ephemeral vault and forbidden auto-create;
- shared server secret, bearer token, or legacy Authorization input;
- raw APNS token/token hash in `UserDefaults`, logs, analytics, diagnostics,
  evidence, fixtures, UI, accessibility output, crash reports, and exports;
- crash before/after durable expectation, send-boundary transition, nested
  response verification, status finalization, local token erase, local
  tombstone commit, and UI publication;
- cross-actor/store/process races for all six operations;
- resolve payload and submit result retention despite absent/insufficient
  content policy;
- revoke/deregister substitution and local-clear substitution;
- authoritative deregister response with surviving local token/active binding;
- local erasure before verified authoritative deregister;
- all three negative status codes proving that none opens the wrong gate.

#### Impact

The broad plan could report green while omitting the exact privacy, identity,
restart, and operation-substitution cases needed to demonstrate Lane C
conformance.

#### Smallest safe successor scope

Bind every required negative to:

1. one exact producer fixture or local-state fixture;
2. one exact consumer test path;
3. one expected sanitized reason code;
4. one before/after durable state;
5. one assertion that no token, secret, unredacted payload, or false current
   truth escaped.

**Verdict:** **OPEN P2 / NEGATIVE EVIDENCE PLAN NOT EXHAUSTIVE**.

## 9. Requested Binding conformance matrix

| Requirement | Independent verdict | Exact basis |
|---|---|---|
| Consume byte-identical shared core/envelopes/fixtures | **STATIC PASS / BYTES MISSING** | S3 lines 1954 and 2153–2154 forbid regeneration; producer manifest path exists, but generated fixture bytes/hashes do not |
| Persistent `domain:device:notification-callback` Identity | **PARTIAL / P1-S3-C-03** | Domain is exact; persistent vault/no-create/rebind consumer contract is absent |
| No server secret | **PARTIAL / P1-S3-C-03** | Legacy Authorization is forbidden at line 1796; Lane C does not explicitly reject all shared/bearer server-secret inputs |
| Six wire operations | **PASS** | S3 lines 462–481 |
| Six-operation Binding state machine | **FAIL / P1-S3-C-02** | Only register/rotation has an exact durable client schema |
| Signed intent/nonce/issuer generation | **STATIC PASS / TRUST INPUT OPEN** | IntentCore/ChallengeCore are exact; issuer descriptor/rotation bytes remain missing |
| Persist response expectation before send | **FAIL / P1-S3-C-01** | Correlation journal exists; complete immutable response expectation does not |
| Crash-durable pre-send rotation journal | **STATIC PASS FOR LISTED FIELDS** | S3 lines 1325–1411 |
| Ambiguous recovery/read-back/restart | **PARTIAL / P1-S3-C-01/02** | Registration correlation is exact; response expectation and other operation states are incomplete |
| Admission/registration/body/request/response/CAS binding | **PASS AT WIRE; PARTIAL AT CLIENT RESTART** | Wire schemas/CAS are exact; missing durable expectation prevents complete historical verification |
| Exact three-way negative status graph | **PASS** | S3 lines 1258–1307 |
| Empty local evidence always `UNKNOWN` | **NOT NORMATIVE FOR LANE C / P1-S3-C-03** | Wire taxonomy supports it; explicit local reducer rule was not carried forward |
| Verified signed receipt/current status before active truth | **PARTIAL / P1-S3-C-01/02/03** | Signature/status schemas exist; complete pre-send expectation and local truth reducer do not |
| Raw token never in defaults/log/evidence | **PARTIAL** | S3 requires volatility and journal exclusion, but no legacy/default/log/evidence path-exact rule or tests |
| Resolve/submit fail closed | **SEMANTIC PASS; DURABLE GRAPH FAIL** | Authority/transport fail closed; line 1413 is not a total client state machine |
| Revoke distinct from deregister | **PASS AT WIRE/SERVER** | S3 lines 1642–1692 |
| Client erase after authoritative deregister and retain only minimal tombstone | **FAIL / P1-S3-C-02** | Server deletion is exact; local client commit/order/schema is absent |
| Exact source/test/project/docs paths | **FAIL / P2-S3-C-01** | S3 list is not exhaustive and omits project/no-touch ownership |
| Exact negative tests | **FAIL / P2-S3-C-02** | Broad themes exist, exact transition/fixture assertions do not |
| Bundle/topic/origin | **PASS AS PLANNING BINDINGS** | `org.digipomps.haven` and `https://haven.digipomps.org` are exact |
| Identity cutover | **SEPARATE / NO-GO** | S3 lines 1800–1821 and 2322–2327 |
| Production signing/profile/entitlements | **UNAUDITED / MISSING** | `MBI-06` |
| Integrated output | **MISSING** | `MBI-07` |

## 10. S1 Lane C finding disposition

| Prior finding | S3 independent disposition |
|---|---|
| `P1-C-01` empty local evidence promoted to not registered | **WIRE MEANING CLOSED; CLIENT CLOSURE PARTIAL/OPEN** — the status taxonomy is exact, but S3 omits the local vault/evidence reducer under P1-S3-C-03 |
| `P1-C-02` ambiguous recovery has no composable path | **PARTIAL / OPEN P1** — registration correlation/read-back is much stronger, but a complete durable response expectation and non-register operation states are missing |
| `P1-C-03` challenge omits signed intent and issuer continuity | **CONSTRUCTION CLOSED; AUTHORITY AND CLIENT CONTINUITY OPEN** — acyclic signed intent/challenge is exact; issuer bytes remain a declared input and vault continuity is P1-S3-C-03 |
| `P2-C-01` resolve/submit are prose only | **REGRESSED TO OPEN / P1-S3-C-02** — S3 uses one sentence and does not incorporate the exact S2 client states |
| `P2-C-02` Apple no-touch incomplete | **S2 STATIC PLAN CLOSED; S3 REPRODUCTION OPEN P2** — no Apple path is authorized, but S3 omits the exact ledger |
| `P2-C-03` status asked to prove topic/origin/signing | **CLOSED FOR EVIDENCE SEPARATION** — S3 explicitly separates protocol status from Apple/provider/device proof |
| `P2-C-04` authority test hard-codes `rw-s` | **CLOSED AT WIRE** — the exact operation/access table gives status `r--s` and mutations `rw-s` |

## 11. S2 Lane C finding disposition

| Prior finding | S3 independent disposition |
|---|---|
| `P1-S2-C-01` obsolete/nonconstructible interface | **CLOSED AS STATIC WIRE CONTRACT** — S3 defines one versioned, acyclic body→intent→challenge→request graph |
| `P1-S2-C-02` pre-send token correlation missing | **CLOSED FOR CORRELATION FIELDS; NEW EXPECTATION P1** — token observation/epoch and mutation/CAS identifiers are pre-send durable, but the full response expectation is not |
| `P1-S2-C-03` v3 admission ID promoted | **CLOSED** — S3 owns exact `adm1_` derivation and explicitly rejects equivalence to `base64url(requestSHA256)` |
| `P1-S2-C-04` negative status mapping ambiguous | **CLOSED AT WIRE** — subject absence, mutation-correlation absence, and by-ID privacy are disjoint |

No prior finding is source/runtime closed by this review.

## 12. `C-DEC-01...12` disposition

| ID | Independent S3 disposition |
|---|---|
| `C-DEC-01` | **PARTIAL** — exact current-status wire taxonomy/freshness now exists; local absence/current reducer is missing under P1-S3-C-03 |
| `C-DEC-02` | **PARTIAL** — revoke and deregister are distinct wire operations; exact client stop/durable-finalization graph is missing |
| `C-DEC-03` | **PARTIAL / EXTERNAL INPUT OPEN** — constructible signed intent/nonce/generation is exact; production issuer/rotation authority remains missing and client vault continuity is incomplete |
| `C-DEC-04` | **CORRELATION CLOSED / EXPECTATION OPEN** — token observation and mutation correlation are durable, complete response expectation is not |
| `C-DEC-05` | **PARTIAL** — registration admission/status recovery is defined; six-operation adjudication and historical response verification remain open |
| `C-DEC-06` | **SUPPORTED FAIL-CLOSED RULE / AUTHORITY INPUT OPEN** — no local/static trust fallback; exact trusted descriptors/manifests/rotation bytes remain missing |
| `C-DEC-07` | **PARTIAL** — registration pending states survive; revoke/deregister/resolve/submit pending and tombstone rules are not total |
| `C-DEC-08` | **SUPPORTED STATIC PRIVACY SHAPE / CLIENT PATH TESTS OPEN** — wire bodies do not invent participant metadata; token/default/log/evidence assertions remain incomplete |
| `C-DEC-09` | **PARTIAL** — producer manifest path/schema exists and consumers may not regenerate; exact generated bytes/hashes and exhaustive Binding consumer paths are absent |
| `C-DEC-10` | **TECHNICALLY CLOSED AS DEFAULT** — resolve/submit payload persistence is not authorized and unredacted read-back payload persistence is forbidden |
| `C-DEC-11` | **OPEN `MBI-07`** — no exact integrated commit/tree/diff/dependency/compiler-input/artifact manifest exists |
| `C-DEC-12` | **EVIDENCE SEPARATION CLOSED / `MBI-06` OPEN** — protocol state does not substitute for production signing/profile/entitlement/archive proof |

## 13. `MBI-05` adjudication

| `MBI-05` subclaim | Independent verdict |
|---|---|
| Exact future Binding paths and owners | **PARTIAL / P2-S3-C-01** |
| Persistent vault identity/no-create/rebind | **OPEN P1-S3-C-03** |
| Empty-local/current truth model | **WIRE CLOSED / CLIENT REDUCER OPEN** |
| Constructible signed challenge intent | **STATIC WIRE CLOSED / TRUST INPUT OPEN** |
| Complete durable response expectation | **OPEN P1-S3-C-01** |
| Total register crash/restart graph | **PARTIAL** — correlation/status exist; expectation verification is incomplete |
| Exact resolve/submit durable states | **OPEN P1-S3-C-02** |
| Exact status/revoke/deregister durable states | **OPEN P1-S3-C-02** |
| Token-rotation continuity | **CORRELATION STATIC PASS / FINALIZATION PARTIAL** |
| Raw-token/evidence privacy | **STATIC WIRE/JOURNAL PASS / CLIENT PATH TESTS PARTIAL** |
| Operation-specific access | **STATIC PASS** |
| Producer fixture consumption | **STATIC RULE PASS / BYTES AND PATH EVIDENCE MISSING** |
| Complete Apple no-touch ledger | **NOT REPRODUCED IN S3 / P2-S3-C-01** |
| Production signing readiness | **UNAUDITED / MISSING (`MBI-06`)** |
| Exact integrated output | **MISSING (`MBI-07`)** |

Overall:

```text
MBI-05: PARTIAL / OPEN
```

## 14. Missing-bound inputs and owner decisions

### 14.1 `MBI-PRIVACY-RETENTION-01`

Verdict:

```text
OPEN
DECISION OWNER: KJETIL
NOT DELEGATED TO A/B/C AUTHORS OR REVIEWERS
```

The exact retention duration, legitimate purpose, restore/backup behavior,
subject-current disclosure, compaction/deletion behavior, and revoke-retained
ciphertext policy remain undecided. The deregister production route therefore
remains unavailable.

This review does not choose, infer, or waive that decision.

### 14.2 Trust and Identity inputs

The requester descriptor/proof path, challenge issuer descriptor/key/algorithm/
generation/rotation record, target Cell/owner descriptors, authority manifest,
Agreement/Contract/Grant bytes, condition inputs, revocation ledger, trusted
time, and rollback anchor remain missing.

Identity cutover stays separate. No P1 above requests Identity mutation; each
requires only an exact fail-closed consumer contract for missing or changed
Identity inputs.

### 14.3 `MBI-TRANSPORT-FRAMING-01`

HTTP method/path/media/carrier/error/proxy fixture bytes remain a technical
producer/server/consumer input. They are not a Kjetil product decision. The
inner application bytes remain opaque to transport.

### 14.4 `MBI-06`

```text
Apple Team/App ID/profile/certificate/effective production entitlement/
codesign/archive evidence = UNAUDITED / MISSING
```

### 14.5 `MBI-07`

```text
exact integrated CellProtocol/Identity/CellScaffold/Binding
commit/tree/diff/dependency/compiler-input/artifact manifest = MISSING
```

## 15. Smallest successor scopes

These scopes are recommendations only. This review does not authorize them.

1. **S3 Lane C normative correction, document-only:** add the complete durable
   response expectation, persistent vault/evidence continuity, and a total
   six-operation Binding reducer including local authoritative-deregister
   cleanup.
2. **S3 Lane C output/test correction, document-only:** reproduce the exact
   existing/new/project/no-touch/collision paths and bind every negative to a
   fixture, test path, reason code, and before/after state.
3. **Independent exact-byte review:** a reviewer distinct from both S3 author
   and correction author must adjudicate the corrected bytes.

Even if those static scopes later pass, source remains blocked on the declared
trust/Identity inputs, framing artifact, privacy-retention decision, MBI-06,
MBI-07, and explicit development-admin authorization.

## 16. Final independent verdict

```text
P0: 0
P1: 3
P2: 2

S3 BINDING CLIENT CONFORMANCE REVIEW: FROZEN
LANE C CONFORMANCE: NO-GO
MBI-05: PARTIAL / OPEN
MBI-PRIVACY-RETENTION-01: KJETIL DECISION REQUIRED
MBI-TRANSPORT-FRAMING-01: TECHNICAL INPUT MISSING
TRUST/AUTHORITY BYTES: MISSING
IDENTITY CUTOVER: SEPARATE PREREQUISITE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
S3 PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

Preserved action gates:

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

This independent review stops at this frozen document. It grants no source,
runtime, test, signing, upload, staging, APNS, device, or production authority.
