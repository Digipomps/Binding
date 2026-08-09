# APNS S6 Formal Proof Packet A — Independent Cross-Review

Date: 2026-07-25  
Review lane: Packet A, response expectation/outcome/maxima  
Reviewer independence: this reviewer authored Packet B, not Packet A  
Review type: exact-byte, static, document-only cross-review  
Root verdict: **PARTIAL / NO-GO**

## 0. Exact reviewed bytes and review output boundary

Reviewed packet:

```text
path =
  Documentation/APNS_S6_Formal_Proof_Packet_A_Response_Maxima_2026-07-25.md
sha256 =
  4139ad6f863c8e704357f710235dd47d77b9a949c1cb5a6a557e99bd4a19669f
lines = 1200
bytes = 39346
```

The bytes, line count, and SHA-256 reproduced before review.

Pre-write review-output reattestation:

```text
Documentation/APNS_S6_Formal_Proof_Packet_A_Response_Maxima_Independent_Cross_Review_2026-07-25.md
= ABSENT
```

This review creates only the review artifact named above. It does not edit
Packet A or any other file.

Immutable comparison inputs:

```text
S5 author
  sha256 = 0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6
  shape  = 2554 lines / 93787 bytes

S5 CellProtocol review
  sha256 = dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639
  terminal P0/P1/P2 = 0/4/2
  terminal verdict = NO-GO

S5 CellScaffold review
  sha256 = 0c98b68d5fdd847289e026173e376ac66dc33f70c7e9d8ebcf22e84573a1c601
  terminal P0/P1/P2 = 0/5/2
  terminal verdict = NO-GO

S5 Binding review
  sha256 = 36ff7ffc838f15abf99bf281c0a0f1ee584a1423d70bf26bdac3a38b2e3ebbc2
  terminal P0/P1/P2 = 0/4/1
  terminal verdict = NO-GO
```

No source, Git, dependency resolution, build, test, network, portal, signing,
device, APNS, secret, Identity, staging, deployment, integration, or material
action was performed.

## 1. Review method and invariant set

The review independently:

1. reproduced the frozen input bytes;
2. walked the challenge and operation expectation DAG in construction order;
3. enumerated challenge success/error and operation
   success/error/evidence cases;
4. checked `AuthenticatedErrorCore v3` phase nullability and request-digest
   binding;
5. compared every non-status v3 result member with the exact S4 v2/S3
   predecessor chain;
6. recomputed every member contribution, Base64url length, envelope, artifact,
   response, and nested response equation;
7. tested discriminator/nullability reachability, not only integer sums;
8. checked cycles across core, envelope, signed artifact, tombstone, response,
   and nested admission read-back;
9. audited max-1/max/max+1 vector semantics and fixture applicability;
10. kept Identity/Resolver authority separate from local expectations and
    transport.

Protected invariants:

```text
same canonical bytes + same accepted history -> same verifier decision
non-success never becomes success/current truth
transport moves exact bytes and grants no authority
expectation edges point only to earlier completed bytes
operation/status/result discriminator rows are mutually exclusive
signed maxima require an exact accepted signature encoding profile
missing Identity/authority/signing/durability evidence -> EMPTY/UNAVAILABLE
```

## 2. Executive result

Independent finding count:

```text
P0 = 0
P1 = 1
P2 = 2
```

Root classification:

```text
RC1 expectation construction DAG = CLOSED
RC1 post-challenge request digest binding = CLOSED
RC1 result/error/evidence outer union = PARTIAL / P1-S6A-XR-01
RC1 overall = PARTIAL

RC5 result-core arithmetic = CLOSED
RC5 ResponseCore per-discriminator arithmetic = CLOSED
RC5 normal/nested structural equations = CLOSED
RC5 exact fixture/applicability ledger = PARTIAL / P2-S6A-XR-01/02
RC5 accepted signed maxima = FORMAL_NO_GO / SignatureEncodingProfile absent
RC5 overall = PARTIAL

PACKET A ROOT = PARTIAL
S6 INTEGRATION = NO-GO
SOURCE/MATERIAL/PRODUCTION = NO-GO
```

Packet A closes the two S5 expectation-construction defects and the central
unreachable-maxima arithmetic defect. It does not close RC1 completely because
its error applicability/signer selection is broader and less determinate than
the exact verifier needs.

## 3. Two-stage expectation construction

### 3.1 Challenge-exchange expectation

Packet A lines 130–137 construct:

```text
body
-> intent
-> ChallengeOutcomeExpectationCore
-> ResponseExpectationUnionCore(challenge_exchange)
-> durable commit/read-back
-> challenge send
```

The challenge expectation contains only bytes or scalars available before the
challenge send:

```text
authority catalog digest
body digest
build provenance digest
expectation ID
identity domain
intent artifact digest
issuer algorithm/descriptor/generation/key ID
operation/purpose/requester/access/resource/status kind
valid-until time
```

It contains no challenge, request, admission, response, successor-vault, or
self digest. Its union payload digest is computed after the payload exists,
and the union does not contain its own digest.

Conclusion:

```text
S5 P1-S5-A-02 / P1-S5-C-01 pre-challenge constructibility = CLOSED STATIC
runtime durable-store evidence = NONE
send readiness with current inputs = UNAVAILABLE
```

### 3.2 Operation-exchange expectation

Packet A lines 139–145 and 294–360 construct the operation expectation only
after the exact challenge and signed request exist:

```text
verified challenge
-> request + deterministic admission ID
-> OperationOutcomeExpectationCore
-> ResponseExpectationUnionCore(operation_exchange)
-> durable commit/read-back
-> operation send
```

It may reference the already committed challenge-expectation digest. It
contains no operation outcome, response, future checkpoint, journal root, or
self digest.

The resulting dependency direction is:

```text
challenge expectation payload
  -> intent/body/issuer/catalog

challenge expectation union
  -> challenge expectation payload

operation expectation payload
  -> challenge expectation union
  -> challenge/request/admission/authority tuple

operation expectation union
  -> operation expectation payload

later continuity checkpoint
  -> committed expectation/journal root
```

There is no `E -> V -> E` or `E -> journal -> vault -> E` edge inside Packet A.
The actual checkpoint/store integration remains absent and explicitly blocked.

Conclusion:

```text
S5 P1-S5-A-01 / P1-S5-C-02 local digest cycle = CLOSED STATIC
RC7/RC8 store/continuity integration = MISSING / NO-GO
```

### 3.3 Expectation union canonicality

`ResponseExpectationUnionCore v1` is byte-total:

```text
member order =
  expectationKind
  expectationPayload
  expectationPayloadSHA256
  expectationPayloadSchema
  schema

challenge_exchange
  -> binding.device-ingress.challenge-outcome-expectation-core.v1

operation_exchange
  -> binding.device-ingress.operation-outcome-expectation-core.v1
```

The Base64url payload/digest/schema triple prevents payload substitution.
`expectationID` is correctly non-authoritative.

Verdict: **PASS STATIC**.

## 4. Reachable outcome family audit

### 4.1 Challenge exchange

Packet A admits exactly:

| Case | Kind/core | Required signer | Review |
|---|---|---|---|
| issued challenge | `challenge` / ChallengeCore v1 | exact pinned challenge issuer | structurally closed |
| authenticated rejection | `authenticated_error` / AuthenticatedErrorCore v3, pre-challenge | exact pinned challenge issuer | phase shape closed; code applicability open under P1 |
| canonical/signature/transport failure | no application artifact | none | correctly opaque/non-authoritative |

Challenge exchange does not admit operation success or terminal evidence. That
exclusion is correct.

### 4.2 Operation exchange

Packet A admits the S5 three-case signed union:

| Case | Kind/core | Applicability | Review |
|---|---|---|---|
| success | `operation_success` / ResponseCore v3 | all six operations, exact status subtype | structurally closed |
| authenticated error | `authenticated_error` / AuthenticatedErrorCore v3 | post-challenge, admitted, readback | shape closed; applicability/signer open |
| terminal evidence | `admission_terminal_evidence` / AdmissionTerminalEvidenceCore v2 | five non-status operations after admission | structurally preserved |

Status success is the exact StatusResultCore v3 row. Recursive status of a
status outcome remains rejected.

Terminal evidence and authenticated errors do not prove target success,
failure, absence, current registration, delivery, commit, revoke, deregister,
or retry safety beyond their exact signed fields.

### 4.3 AuthenticatedErrorCore v3 request-digest matrix

The v3 member order reproduces:

```text
admissionID
bodySHA256
challengeArtifactSHA256
committedAtMilliseconds
errorCode
intentArtifactSHA256
operation
phase
requestArtifactSHA256
requesterDescriptorSHA256
retryClass
schema
serverSequence
statusKind
targetCellID
targetOwnerDescriptorSHA256
terminality
```

Phase matrix:

| phase | admission | challenge | request | target/owner | signer |
|---|---|---|---|---|---|
| pre-challenge | null | null | null | null | challenge issuer |
| post-challenge/pre-admission | null | value | **value** | value | target owner |
| admitted | value | value | value | value | target owner |
| readback | value | value | value | value | historical signer |

Changing `post_challenge_pre_admission.requestArtifactSHA256` from S5 v2 null
to a mandatory exact digest is sound. The request already exists before the
operation send and the target has received it before returning that error.
This prevents reuse of one signed error across different RequestArtifact bytes
with equal semantic fields.

Verdict:

```text
phase nullability = CLOSED
post-challenge request substitution = CLOSED
code/operation/phase/signer applicability = OPEN P1-S6A-XR-01
```

## 5. Five non-status v3 success schemas

Packet A binds the exact S4 document by digest and states that v3 changes only
the schema literal, removes newly generated `exact_replay`, and makes types,
relations, nullability, and maxima explicit. The predecessor chain is
therefore fixed rather than an unversioned prose reference.

### 5.1 Member-by-member result

| Schema | Members | Predecessor equality | Key relation | Arithmetic |
|---|---:|---|---|---|
| RegisterReceipt v3 | 13 | exact S4 v2 order | mode/disposition and `current=previous+1` | 749 reproduced |
| ResolveResult v3 | 6 | exact S4 v2 order | `resolved`, payload 0…48000 raw | 64423 reproduced |
| SubmitReceipt v3 | 7 | exact S4 v2 order | `submitted`, positive generation, exact ID | 519 reproduced |
| RevokeReceipt v3 | 8 | exact S3/S4 order | revoked increments; already equals previous | 417 reproduced |
| DeregisterReceipt v3 | 11 | exact S3/S4 order | exact deletion tuple and signed tombstone | 5797/5805 functions reproduced |

No raw APNS token or token digest appears.

### 5.2 RegisterReceipt v3

Independent sum:

```text
64+79+46+52+29+31+53+67+93+43+63+41+74
+ 2 braces + 12 commas
= 749
```

A reachable maximum exists with `mutationMode=token_rotation`,
`disposition=token_rotated`, and compatible 20-digit generation values.
`tokenDeliveryEpoch` or `revocationGeneration` can independently provide a
valid one-byte-shorter core.

Verdict: **CLOSED STATIC**.

### 5.3 ResolveResult v3

```text
B64(48000) = 64000

90+24+64012+61+141+88
+ 2 braces + 5 commas
= 64423
```

Ticket length 127/128/129 yields exact `64422/64423/64424`, with the last
rejected.

Verdict: **CLOSED STATIC**.

### 5.4 SubmitReceipt v3

```text
25+87+61+43+66+141+88
+ 2 braces + 6 commas
= 519
```

Ticket length 127/128/129 yields exact `518/519/520`.

Verdict: **CLOSED STATIC**.

### 5.5 RevokeReceipt v3

```text
31+51+45+67+93+43+61+17
+ 2 braces + 7 commas
= 417
```

The maximizing disposition is `already_revoked`; both revocation generations
can be equal 20-digit UInt64 values. A 19-digit independent registration
generation yields 416.

Verdict: **CLOSED STATIC**.

### 5.6 DeregisterReceipt v3

The exact S3 tombstone core maximum reproduces:

```text
64+46+45+67+90+43+71+92+145+96
+ 2 braces + 9 commas
= 770
```

For a structural ceiling profile:

```text
TombstoneArtifact = 3953
DeregisterResultFresh = 526 + B64(3953) = 5797
DeregisterResultAlready = 534 + B64(3953) = 5805
```

The artifact/core/digest direction is acyclic:

```text
tombstone core
-> tombstone SignedArtifact
-> tombstone artifact digest
-> DeregisterReceiptCore
-> ResponseCore
-> operation-success SignedArtifact
```

The tombstone does not contain the response/result digest.

The maxima are correct. The stated max-1 fixture field is not, as recorded in
P2-S6A-XR-01.

Verdict: **CORE/FUNCTION CLOSED; VECTOR DESCRIPTION PARTIAL**.

## 6. Discriminator and nullability audit

### 6.1 ResponseCore

The exact valid rows are:

```text
register/null/register-receipt-v3
resolve/null/resolve-result-v3
submit/null/submit-receipt-v3
status/registration/status-result-v3
status/admission/status-result-v3
revoke/null/revoke-receipt-v3
deregister/null/deregister-receipt-v3
```

Packet A excludes:

- non-status with non-null status kind;
- status with null/unknown status kind;
- arbitrary 96-byte schema;
- cross-operation result schema;
- mismatched result digest/schema;
- invalid disposition/mode/state;
- extra, missing, reordered, escaped, or padded forms;
- recursive status admission read-back.

The S5 impossible combination:

```text
operation=deregister
statusKind=registration
resultSchema=arbitrary 96-byte value
```

is absent.

Verdict: **CLOSED STATIC**.

### 6.2 Success/result inheritance

The new v3 schemas do not silently add a success meaning. Exact request replay
returns original bytes and is not a disposition. Denials remain authenticated
errors.

The v3 schema chain is sufficiently bound for Packet A's narrow RC1/RC5
formal scope. Packet A does not integrate later RC4 head-transition evidence;
that is correctly outside this packet and remains an S6 integration NO-GO,
not Packet A closure credit.

## 7. Independent maxima reproduction

### 7.1 Encoding helpers

The stated helpers reproduce:

```text
B64(n) =
  4*floor(n/3)                    when n mod 3 = 0
  4*floor(n/3)+2                  when n mod 3 = 1
  4*floor(n/3)+3                  when n mod 3 = 2

StringMember(name,n) = len(name)+5+n
UIntMember(name,d)   = len(name)+3+d
NullMember(name)     = len(name)+7
Object               = 2 + commas + contributions
```

Every calculation below used checked non-negative integers. The largest
published value is far below UInt64, but a producer/consumer must still check
before allocation.

### 7.2 ResponseCore fixed rows

Independent exact fixed values:

| operation/status | fixed |
|---|---:|
| register/null | 1104 |
| resolve/null | 1101 |
| submit/null | 1100 |
| status/registration | 1109 |
| status/admission | 1106 |
| revoke/null | 1100 |
| deregister/null | 1108 |

These are per valid discriminator row. No maximum member from another row was
borrowed.

### 7.3 Non-nested response maxima

Independent results:

| row | equation | result |
|---|---|---:|
| register | `1104+B64(749)` | 2103 |
| resolve | `1101+B64(64423)` | 86999 |
| submit | `1100+B64(519)` | 1792 |
| status/registration | `1109+B64(882)` | 2285 |
| revoke | `1100+B64(417)` | 1656 |
| deregister/fresh structural | `1108+B64(5797)` | 8838 |
| deregister/already structural | `1108+B64(5805)` | 8848 |

The exact maximum non-nested ResponseCore is the resolve row, 86999 bytes.

### 7.4 Signature envelope functions

Independent member accounting reproduces:

```text
Protected(k,A,K) = 284 + A + K + k
Envelope(k,A,K,S) = 92 + B64(Protected(k,A,K)) + B64(S)
Artifact(C,k,A,K,S) = 92 + B64(C) + B64(Envelope(k,A,K,S))
```

At structural scalar ceilings `A=64,K=128,S=1024`:

| kind | protected | envelope |
|---|---:|---:|
| operation success | 493 | 2116 |
| authenticated error | 495 | 2118 |
| deregistration tombstone | 500 | 2125 |
| admission terminal evidence | 503 | 2129 |

No signed-artifact or envelope contains a later artifact digest. Protected core
contains only the completed core digest. Envelope contains protected bytes and
signature. SignedArtifact contains completed core and envelope. The graph is
acyclic.

### 7.5 Normal signed structural maximum

```text
NormalOutcome(64,128,1024)
= Artifact(86999,17,64,128,1024)
= 92 + B64(86999) + B64(2116)
= 92 + 115999 + 2822
= 118913
```

This arithmetic is correct and replaces S5's unreachable 120987 tuple.

### 7.6 Nested admission structural maximum

```text
N  = 118913
SR = 683 + B64(N)
   = 159234
R  = 1106 + B64(SR)
   = 213418
O  = Artifact(R,17,64,128,1024)
   = 287472
```

The inner outcome is complete before the status result. Recursive
status-of-status is rejected. No cycle or unbounded recursion exists.

### 7.7 Overflow and allocation meaning

The functions are monotonic for non-negative bounded inputs. Packet A
correctly distinguishes:

```text
structural scalar ceiling
!= semantically reachable signed maximum
!= accepted production signer/profile
```

The unsigned/core ceilings are useful for fail-before-allocation guards.
`118913` and `287472` are useful only as conservative structural allocation
ceilings under the printed scalar bounds. They are not accepted production
semantic maxima.

## 8. SignatureEncodingProfile adjudication

Packet A requires an independently accepted profile containing exact,
reachable:

```text
algorithm-token length A
key-ID length K
canonical raw-signature length S
```

and explicitly leaves:

```text
algorithm = unselected
key/key ID = unselected
signing root = unselected
accepted profiles = EMPTY
signed boundary fixture = BLOCKED_SIGNATURE_PROFILE
```

This is honest fail-closed classification. A length profile does not grant
Identity, signer, owner, Contract, capability, or Resolver authority.

An accepted future profile must also specify the exact algorithm identifier,
exact canonical raw-signature representation, whether length is fixed or
variable, the reachable maximum rule, signer/key binding, and fixture bytes.
Those are missing inputs, not values this reviewer may select.

Review classification:

```text
structural equations = CLOSED
accepted signed maxima = FORMAL_NO_GO
production signing/Identity authority = EMPTY
```

No finding is charged for leaving the profile open because Packet A neither
invents nor claims it.

## 9. Identity, Resolver, and transport boundaries

Packet A correctly preserves:

- domain-scoped Identity;
- exact historical signer references;
- Agreement/Contract/Grant/Conditions resolution;
- Resolver/Cell authorization as the protected boundary;
- no authority from expectation ID, build provenance, route, process,
  environment, repository, TLS, token possession, or administrator;
- opaque, byte-preserving, semantically neutral transport;
- bundle/topic `org.digipomps.haven`;
- origin `https://haven.digipomps.org`;
- production APNS environment;
- EMPTY accepted signer/authority sets.

Transport failure is correctly outside the application artifact union and
cannot establish success, denial, current state, or retry safety.

Identity cutover, transport framing, Apple signing, profiles, entitlements,
and integrated output remain separate NO-GOs.

Verdict: **BOUNDARIES PRESERVED / NO EXTERNAL EVIDENCE GRANTED**.

## 10. Findings

### P0

No P0 was found. Packet A creates no source or runtime path, keeps every
material/production gate closed, and keeps actual authority/signing/durability
sets EMPTY.

### P1-S6A-XR-01 — Error applicability and readback signer selection are not a total exact verifier contract

Evidence:

- Packet A lines 294–360 define one OperationOutcomeExpectationCore with one
  issuer tuple and one target-owner tuple, but no exact allowed-variant array,
  variant digest, phase-specific signer role, or code/operation applicability
  set.
- Lines 433–440 define a phase matrix whose readback signer is only
  `expectation-selected historical signer`; the expectation contains two
  candidate signer families but no byte that selects one for a readback error.
- Lines 447–452 accept every S5 terminal error code in every phase.

This permits structurally accepted combinations whose producer has no
semantically relevant state at that phase or for that operation. Examples:

```text
pre_challenge + generation_conflict
pre_challenge + invalid_operation_state
resolve + unsupported_token_length
readback + ambiguous issuer-vs-target-owner signer selection
```

The exact examples are not asserted to be the complete rejected set. The defect
is that Packet A supplies no byte-total rule from:

```text
(operation, statusKind, phase, errorCode)
-> exact signer role
-> exact retry class/terminality
-> exact reachable or rejected decision
```

Calling every terminal code “conservative” does not close the contract.
Authenticated non-success still controls retry, status recovery, UI, and local
state-machine behavior. It must be expectation-bound and deterministic even
though it grants no target success.

This is a new Packet A defect, not authority evidence. The fail-closed runtime
state remains UNAVAILABLE.

Smallest safe correction:

1. restore an acyclic, exact `OutcomeExpectationVariantCore`-style payload or
   equivalent canonical derived matrix;
2. bind its exact bytes/digest into each challenge/operation expectation before
   the corresponding send;
3. enumerate allowed error codes by operation/status/phase;
4. select exactly one signer role/descriptor/key/algorithm per variant;
5. define whether readback returns exact stored historical bytes or a new
   readback error, and bind the corresponding signer;
6. add negative vectors for every excluded cross-product boundary.

The variant bytes depend only on already known issuer/target-owner/operation
inputs, so the correction need not reintroduce a future-byte or vault cycle.

Severity: **P1**.  
Verdict: **RC1 PARTIAL / PACKET A ROOT PARTIAL**.

### P2-S6A-XR-01 — Deregister max-1 vectors name a field that must also match the nested tombstone

Packet A lines 920–927 claim both deregister max-1 rows by changing
`registrationGeneration` from 20 digits to 19 while holding the remaining
maximum profile.

The exact receipt and its nested signed tombstone describe the same
registration generation. Changing only the outer value breaks semantic
equality. Changing both values changes:

```text
DeregisterReceiptCore
DeregistrationTombstoneCore
TombstoneArtifact Base64url length
DeregisterReceiptCore tombstoneArtifact length
```

and is not the stated one-byte perturbation.

The maxima themselves remain correct. Valid exact one-byte alternatives exist:

Fresh deregister:

```text
previousRevocationGeneration = 9999999999999999999   // 19 digits
revocationGeneration         = 10000000000000000000  // 20 digits

all nested current values remain maximum
5797 -> 5796
```

Already deregistered structural row:

```text
nested tombstone committedAtMilliseconds uses 19 rather than 20 digits
TombstoneCore 770 -> 769
TombstoneArtifact 3953 -> 3952
B64 artifact 5271 -> 5270
5805 -> 5804
```

The already-deregistered row must also be labeled structural/privacy-blocked
at max-1, not accepted.

Severity: **P2**.  
Verdict: **local vector correction required; central maxima unchanged**.

### P2-S6A-XR-02 — Fixture/applicability ledger is not exhaustive for the claimed total verifier and boundary proof

Packet A lines 992–1025 provide exact future fixture IDs, but omit distinct
entries for at least:

- each reachable AuthenticatedError phase;
- the exact code/operation/phase/signer matrix required by
  P1-S6A-XR-01;
- admitted `operation_pending` and its illegal phases;
- both terminal evidence codes and each reason-code applicability;
- exact stored historical readback versus newly signed readback behavior;
- AuthenticatedErrorCore v3 max-1/max/max+1;
- AdmissionTerminalEvidenceCore v2 max-1/max/max+1;
- SignatureProtectedCore, SignatureEnvelope, and SignedArtifact profile
  boundaries;
- nested status/admission structural max-1/max/max+1;
- nested admission of authenticated-error and terminal-evidence outcomes;
- all status/admission discriminator rows, not only recursion rejection;
- deregister tombstone core/artifact/digest mismatch and nested equality; and
- variable/fixed signature-encoding profile rejection.

The listed future paths do not exist and correctly receive no PASS. Therefore
this is an evidence/applicability gap, not a claim that tests failed.

Severity: **P2**.  
Verdict: **fixture proof PARTIAL**.

## 11. S5 finding closure map

| S5 root | Packet A result | Cross-review verdict |
|---|---|---|
| P1-S5-A-01 / P1-S5-C-02 expectation-journal-vault cycle | split temporal expectation, no future/successor digest | CLOSED STATIC |
| P1-S5-A-02 / P1-S5-C-01 pre-challenge expectation impossible | challenge-exchange expectation exists pre-send | CLOSED STATIC |
| P1-S5-B-01 five undefined non-status v3 success schemas | five exact v3 schemas with bound predecessor semantics | CLOSED STATIC for Packet A scope |
| P1-S5-A-04 / P1-S5-B-04 mutually exclusive maxima | per-valid-row arithmetic and exact result maxima | CLOSED STATIC |
| P2-S5-A-02 / P2-S5-C-01 fixture completeness | new ledger improves coverage | PARTIAL; P2-S6A-XR-01/02 |
| RC1 total outcome verifier | improved | PARTIAL; P1-S6A-XR-01 |
| RC5 accepted signed maximum | explicit profile function | FORMAL_NO_GO; profile EMPTY |

No S5 terminal verdict is retroactively changed.

## 12. Exact closure and blocker table

| Claim | Verdict | Residual |
|---|---|---|
| challenge expectation constructible before send | CLOSED STATIC | durable store absent |
| operation expectation constructible before send | CLOSED STATIC | durable store absent |
| expectation/vault digest cycle removed from packet | CLOSED STATIC | integration absent |
| post-challenge error binds request digest | CLOSED STATIC | implementation absent |
| result/error/evidence union discriminator | CLOSED STRUCTURE | error applicability open |
| error code/phase/operation/signer totality | PARTIAL | P1-S6A-XR-01 |
| five non-status v3 result shapes | CLOSED STATIC | later head/integration evidence out of scope |
| per-result maxima | CLOSED | dereg max-1 fixture description P2 |
| per-response maxima | CLOSED | fixtures not implemented |
| normal/nested artifact functions | CLOSED STRUCTURAL | signature profile absent |
| accepted signed semantic maxima | FORMAL_NO_GO | S6A-BLOCK-01 |
| already-deregistered semantic maximum | FORMAL_NO_GO | privacy retention open |
| fixture/applicability proof | PARTIAL | P2-S6A-XR-01/02 |
| Identity/authority | EMPTY | separate prerequisite |
| transport authority | NONE | framing missing, semantics neutral |
| production | NO-GO | all operative gates preserved |

## 13. Required successor scopes

Smallest document-only successor for P1:

```text
one exact Packet A correction document
  - canonical allowed outcome variant bytes/digest
  - exact operation/status/phase/error/signer matrix
  - exact readback stored-vs-new outcome rule
  - no future bytes or successor continuity digest
```

Smallest document-only successor for P2:

```text
one corrected fixture/applicability ledger
  - valid deregister max-1 witnesses
  - all error/evidence phases and boundaries
  - all nested/signed profile boundary families
```

After correction, a distinct reviewer must reproduce the new exact bytes.
Neither successor authorizes integration, source, test creation, signing,
device use, APNS, staging, deployment, or production.

## 14. Terminal review verdict

```text
REVIEWED PACKET A:
  4139ad6f863c8e704357f710235dd47d77b9a949c1cb5a6a557e99bd4a19669f
  1200 lines / 39346 bytes

INDEPENDENT FINDINGS:
  P0 = 0
  P1 = 1
  P2 = 2

RC1:
  EXPECTATION DAG = CLOSED STATIC
  REQUEST-DIGEST MATRIX = CLOSED STATIC
  OUTCOME ERROR APPLICABILITY = PARTIAL / P1-S6A-XR-01
  OVERALL = PARTIAL

RC5:
  CORE/RESPONSE ARITHMETIC = CLOSED
  SIGNED STRUCTURAL FUNCTIONS = CLOSED
  ACCEPTED SIGNED MAXIMA = FORMAL_NO_GO
  FIXTURE/APPLICABILITY = PARTIAL
  OVERALL = PARTIAL

IDENTITY/AUTHORITY/SIGNATURE PROFILE = EMPTY
TRANSPORT = OPAQUE / NON-AUTHORITATIVE
PACKET A ROOT = PARTIAL
S6 INTEGRATION = NO-GO
SOURCE/MATERIAL/PRODUCTION = NO-GO
```

All S5, S6, Identity, signing, device, APNS, staging, deployment, integration,
and production stop gates remain operative.
