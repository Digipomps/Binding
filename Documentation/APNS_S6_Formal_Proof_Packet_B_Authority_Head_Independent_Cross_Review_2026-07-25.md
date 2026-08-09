# APNS S6 Formal Proof Packet B — Independent Cross-Review

Status: **REVIEW-FROZEN CANDIDATE / PACKET B NO-GO / S6 NO-GO / NO NEXT PHASE**

Date: `2026-07-25`  
Review lane: `B — authority and current-subject head`  
Reviewer relation: distinct from the Packet B author; this reviewer authored
Packet C, not Packet B  
Review type: exact-byte, static, adversarial cross-review only

Sole review output:

`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S6_Formal_Proof_Packet_B_Authority_Head_Independent_Cross_Review_2026-07-25.md`

The review output path was re-attested absent before this file was created.
This review changes no author packet, source, fixture, manifest, project,
dependency, Git state, build, test, network, portal, signing, device, APNS,
Identity, staging, deployment, integration, material, or production state.

## 1. Exact reviewed bytes

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S6_Formal_Proof_Packet_B_Authority_Head_2026-07-25.md` | `36bccdd94e183cae4aa7a26a0637ce8f71abbb7bf8f17086d175859856a0ffb8` | 1905 | 54641 |

The SHA-256 and shape reproduced before review. Findings below apply only to
those exact bytes.

## 2. Review boundary and method

This review independently reconstructed:

1. every Packet B authority node and declared digest/reference edge;
2. direct-owner and delegated signer paths;
3. the requester/subject, target Cell, target owner, Agreement, Contract,
   Grant, Conditions, consent, operation, access, purpose, audience,
   capability, and response-signer tuple;
4. current authority artifact refs, heads, signed statuses, mutations,
   selectors, generation, and revocation;
5. signed register/revoke/deregister current-subject-head expectations;
6. first enroll, retained-head re-enroll, update, token rotation, reactivate,
   revoke, deregister, policy-deletion re-enroll, replay, concurrency,
   collision, restart, and rollback branches;
7. the `MBI-PRIVACY-RETENTION-01` boundary;
8. RC1/status/result dependencies; and
9. all named future vector IDs, applicability information, and repository-path
   claims.

No synthetic authority was treated as accepted. Resolver enforcement remains
the policy boundary. Agreement alone, transport, TLS, process identity,
repository ownership, or a server route grants no authority.

## 3. Executive verdict

```text
P0 = 0
P1 = 5
P2 = 2

IMMUTABLE BINDING/CONSENT/CATALOG CYCLE = REMOVED
COMPLETE CURRENT-AUTHORITY SELECTOR GRAPH = NOT CONSTRUCTIBLE
AUTHORITY REVOKE TRANSITION = INTERNALLY INCONSISTENT
SIGNED SUBJECT-HEAD EXPECTATIONS = PRESENT
CURRENT-SUBJECT HEAD/CAS = PARTIAL
MBI-PRIVACY-RETENTION-01 = NOT CHOSEN
ACCEPTED AUTHORITY = EMPTY
OPERATIONAL READINESS = UNAVAILABLE

RC3 = PARTIAL / FORMAL_NO_GO
RC4 = PARTIAL / FORMAL_NO_GO
PACKET B = NO-GO
S6 INTEGRATION = NO-GO
NEXT PHASE = NO-GO
```

The five P1 findings are internal formal defects, not merely the already
declared absence of production keys/providers. The EMPTY/UNAVAILABLE behavior
is correctly fail-closed, but it does not make a future non-empty composition
constructible.

## 4. Positive findings preserved

The following Packet B properties survive this review:

- the old `B ↔ N ↔ E ↔ L` fixed-point cycle is removed from immutable artifact
  construction;
- B contains neither catalog nor consent digest;
- N references completed B and contains no catalog digest;
- E contains completed B, N, A, C, G, K and Q artifacts/digests;
- L is constructed after E;
- Q binds the intended signer/requester/target/owner/Agreement/Contract/Grant/
  Conditions/consent and operation tuple;
- direct versus delegated nullability is explicitly fail-closed;
- the HTTP/TLS wrapper remains semantically neutral;
- missing M/A/C/G/K/Identity/time/rollback inputs leave authority EMPTY and
  readiness UNAVAILABLE;
- register/revoke/deregister bodies carry exact nested signed head expectation
  bytes and their digest;
- first enrollment, retained-empty-head enrollment, update, token rotation,
  reactivation, revoke, and deregister branches are named;
- same-admission replay, different-request collision, same-head concurrent
  CAS, ID/epoch collision, overflow, and stale-old-request outcomes are
  fail-closed in intent;
- policy deletion, post-policy-deletion enrollment, history compaction, and
  privacy-erasure claims remain disabled while the owner input is absent; and
- resolve/submit acquire no head-derived authority.

These positives do not close the P1 defects below.

## 5. Independent authority DAG reconstruction

### 5.1 Immutable construction DAG

The dependency-correct topological order is:

```text
M, A, C, G, K
  -> S
  -> D?                 (owner signed)
  -> B                  (owner or exact delegate signed)
  -> N                  (requester signed)
  -> Q
  -> E
  -> L                  (owner or exact delegate signed)
```

Exact reconstructed immutable edges:

| Node | Exact earlier dependencies represented by Packet B |
|---|---|
| M | external prerequisite |
| A/C/G/K | external prerequisites |
| S | M, A, C, G, K digests plus tuple scalars |
| D | M, exact S bytes/digest, owner, delegated signer, generation/revocation |
| B | M, S digest, D digest or null, A/C/G/K digests, subject, target, owner, operation tuple |
| N | M, S digest, B digest, A/C/G/K digests, terms digest, requester signature |
| Q | M, S digest, D digest or null, B/A/C/G/K/N digests, full tuple |
| E | exact Q, D?/B/A/C/G/K/N artifacts and paired digests |
| L | M, D? and sorted exact E bytes |

There is no backward edge from B or N to E/L, and no edge from D to B/N/E/L.
The immutable graph is therefore acyclic.

Packet B's printed order is not itself topological because it lists both S and
B before their A/C/G/K digest prerequisites. That documentation defect is
P2-B-XR-01; the declared edge table and rank table nevertheless expose the
correct acyclic relation.

### 5.2 Current-selection extension

Packet B then adds:

```text
completed artifact
  -> AuthorityArtifactRef
  -> AuthorityHeadMutation
  -> AuthorityCurrentHead
  -> signed AuthorityHeadStatus
  -> AuthorityGenerationSelector

all required selectors + Q + E + L
  -> AuthorizationUseSelector U
  -> Intent
  -> Challenge
  -> Request
```

This extension has no digest fixed-point: mutation/status/selector objects
refer only to completed immutable artifacts or prior current-head scalars.
However, two byte-total defects make the extension nonconstructible:

- the mandatory E selector cannot satisfy Packet B's own artifact-ref rule;
  and
- revoke creates a current-head/ref revocation mismatch.

They are P1-B-XR-01 and P1-B-XR-02.

### 5.3 Digest-edge ledger

Explicit and reproducible:

```text
SHA(S) = SHA256Hex(exact OwnerDelegationScopeCore bytes)
SHA(Q) = SHA256Hex(exact AuthorizationTupleCore bytes)
SHA(headExpectation) =
  SHA256Hex(exact decoded SubjectHeadExpectationCore bytes)

bindingHeadKey =
  SHA256Hex(LP(domain literal) || LP(kind) || LP(exact S))

delegationHeadKey =
  SHA256Hex(LP(domain literal) || LP(kind) || LP(M digest)
            || LP(owner digest) || LP(S digest))

consentHeadKey =
  SHA256Hex(LP(domain literal) || LP(kind) || LP(exact S)
            || LP(B digest) || LP(terms digest))

catalogEntryHeadKey =
  SHA256Hex(LP(domain literal) || LP(kind) || LP(exact Q))

catalogHeadKey =
  SHA256Hex(LP(domain literal) || LP(kind) || LP(M digest)
            || LP(target Cell) || LP(owner digest))
```

The packet also requires paired artifact/ref/status digests to reproduce under
its canonical byte rules. One used edge is not explicitly frozen:

```text
authorizationUseSelectorSHA256
```

U is defined and Intent is said to bind that digest, but no exact equation is
printed. This is included in P2-B-XR-01 rather than raised as a separate P1
because the packet's global `SHA256Hex` convention gives only one reasonable
candidate. A successor must still freeze the equation explicitly.

## 6. Findings

### P1-B-XR-01 — the mandatory catalog-entry selector has no total ref/revocation construction

Evidence:

- `AuthorizationCatalogEntryCore v3` contains `entryGeneration`, but no
  `revocationGeneration`, native current owner/controller field, or standalone
  signed entry envelope;
- `AuthorityArtifactRefCore v1` requires generation, revocation generation,
  owner, and signer fields;
- no clause maps E's `entryID`, `entryGeneration`, containing L signature,
  target owner/delegate, and initial/current revocation value into one exact
  AuthorityArtifactRef tuple;
- the type-specific status table names the target owner as E's status signer,
  but does not determine the ref's claimed artifact signer or bind the
  containing signed L/inclusion edge into that ref;
- `AuthorizationUseSelectorCore v1` nevertheless requires a non-null
  `authorizationCatalogEntrySelector`; and
- every selector must resolve to `selected`.

Result:

```text
E -> {undefined ref signer/owner/revocation/inclusion projection}
-> no single canonical AuthorityArtifactRef(E) bytes
-> selector(E) != selected
-> EverySelectorSelected(U) = false/unavailable
-> AcceptedAuthority = EMPTY for every attempted non-empty chain
```

The fail-closed reading is UNAVAILABLE, not permission to invent zero,
inherit L's signer, or infer owner/revocation semantics. This is not cured by
supplying external M/A/C/G/K bytes because E is a Packet B schema, not an
external missing contract.

Impact:

- RC3 is not a fillable formal design;
- vector `B-RC3-007` cannot produce a fully selected positive chain; and
- the claimed RC3 formal closure is not earned.

Smallest safe correction:

1. version E or its signed owner-controlled wrapper with exact artifact
   generation, revocation generation, owner/controller, signer, stable head
   key, and current-selection semantics; or
2. remove the independent E selector and prove E only through the exact
   currently selected owner-signed L, with an explicit immutable inclusion
   proof and revocation rule.

Add positive direct/delegated full-U vectors and negative stale/revoked E
selectors. Keep authority EMPTY until a distinct review accepts the successor.

Verdict: **OPEN P1 / RC3 PARTIAL / FORMAL_NO_GO**.

### P1-B-XR-02 — revoke makes current head and retained artifact ref generations disagree

Evidence:

- `AuthorityArtifactRefCore v1` carries `revocationGeneration`;
- it also carries artifact `generation`;
- `AuthorityCurrentHeadCore v1` also carries `revocationGeneration`;
- it carries `headGeneration`;
- Packet B requires the current ref's generation/revocation values and current
  head values to be byte/numerically equal;
- revoke supplies `newArtifact = null`, `newArtifactRef = null`;
- revoke retains the same artifact ref while incrementing the head and
  revocation generations.

For old generation pair `(h, r)`:

```text
retained AuthorityArtifactRef.generation           = h
new AuthorityCurrentHead.headGeneration            = h + 1
retained AuthorityArtifactRef.revocationGeneration = r
new AuthorityCurrentHead.revocationGeneration      = r + 1
required equalities                                = false
```

The next signed status and selector cannot simultaneously validate the
retained ref and revoked head. Consent withdrawal, binding revocation,
delegation revocation, catalog revocation, and every other generic revoke
inherit this contradiction.

Smallest safe correction:

- define ref `generation` as current-selection generation and make revoke
  create an exact new ref for the same immutable artifact digest with
  generation/head generation and revocation generation both incremented; or
- separate immutable artifact generation from current-head generation, remove
  the invalid equality, and bind current revocation solely through the new
  head/status/ref transition.

Freeze nullability for all three `newArtifact`, `newArtifactRef`, and
`newArtifactRefSHA256` fields and add exact before/after bytes.

Verdict: **OPEN P1 / RC3 PARTIAL / FORMAL_NO_GO**.

### P1-B-XR-03 — CurrentSubjectHead is not byte-total and leaves a retention-dependent CAS field unsigned

Evidence:

- `CurrentSubjectHeadCore v2` includes
  `lastDisclosableTombstoneSHA256`;
- no type, nullability, lifecycle matrix, update authority, generation rule,
  or transition rule is defined for that member;
- `SubjectHeadExpectationCore v1` does not contain it;
- `HeadTransitionEvidenceCore v1` does not contain it; and
- `Commit(r)` writes `DurableCurrentHead = r.headExpectation`, although the two
  schemas do not have the same members and no exact comparison projection is
  defined.

Consequences:

1. Two implementations may encode null versus a digest for the same active,
   revoked, or empty head.
2. A tombstone/disclosure update can change durable head bytes without a
   signed expected value or defined head-generation increment.
3. Treating the field as non-null would silently choose retention/disclosure
   behavior despite the owner decision being absent.
4. Treating it as irrelevant makes literal full-head equality in the commit
   equation false or undefined.

Packet B correctly leaves `MBI-PRIVACY-RETENTION-01` open, but this field makes
that open policy leak into the claimed retention-independent correctness
core.

Smallest safe correction:

- while the owner decision is absent, require the member to be exact JSON
  `null`, non-authoritative, immutable, and excluded from every correctness
  claim; or
- define a separately signed and generation-bound retention projection after
  the owner decision, with an exact CAS projection and transition evidence.

Also define exact `CurrentSubjectHeadCore ↔ SubjectHeadExpectationCore`
comparison, including which current-head members are derived, compared, or
intentionally excluded.

Verdict: **OPEN P1 / RC4 PARTIAL / FORMAL_NO_GO**.

### P1-B-XR-04 — mutation visibility and rollback-anchor success are not one atomic boundary

Evidence:

- `Commit(r)` is true only if durable commit/read-back and rollback-anchor
  advance/read-back both succeed;
- Packet B says that if any term is false, no mutation commits;
- section 7.5 first commits current head, registration, lookup, endpoint/token
  state, admission, exact outcome, transition evidence, epoch row, and anchor
  intent in one stable transaction;
- only after that local transaction does the provider advance and read back
  the rollback anchor.

Crash/failure window:

```text
local state transaction commits
-> external anchor advance has not succeeded
-> durable new head/outcome exists
-> Commit(r) is false by the stated equation
-> "no mutation commits" contradicts stored state
```

The named `crash after commit before read-back: unavailable until proof`
vector does not define whether the new head is tentative, invisible,
recoverable, or already authoritative. Exact replay also cannot know which
stored response is authoritative without that state.

The same ambiguity appears in authority-head mutation, where rollback advance
is described as part of one target transaction without an atomic provider
interoperability contract.

Smallest safe correction:

- define a prepared/invisible local generation followed by an externally
  anchored activation marker, with exact crash recovery and replay behavior;
  or
- require and type an independently proven storage/anchor provider that
  atomically commits both namespaces.

The successor must specify before/after bytes for every crash window and keep
all accepted provider sets EMPTY until evidence exists.

Verdict: **OPEN P1 / RC3+RC4 PARTIAL / FORMAL_NO_GO**.

### P1-B-XR-05 — the generation-overflow error row violates the frozen RC1 mapping

Evidence:

Packet B's error table has:

```text
generation overflow | target_unavailable | retry class = terminal
```

The frozen S5 `AuthenticatedErrorCore v2` mapping requires:

```text
target_unavailable
  retryClass  = after_authority_recovery
  terminality = terminal
```

`terminal` is not a retry-class literal. Packet B then states that all table
retry classes are members of the frozen mapping, which is false for this row.
Decision S6-B-D08 does not excuse the mismatch: no new error label is involved;
the selected error code already has a mandatory frozen mapping.

Impact:

- exact authenticated error bytes for overflow are not constructible from the
  Packet B row;
- the RC1 residual ledger is honest for missing success/status result schemas,
  but not for this already-mapped error branch.

Smallest safe correction:

```text
generation overflow
  errorCode   = target_unavailable
  retryClass  = after_authority_recovery
  terminality = terminal
```

Add terminality as its own explicit column or state that it is inherited
exactly from S5.

Verdict: **OPEN P1 / RC4 ERROR BRANCH PARTIAL / FORMAL_NO_GO**.

### P2-B-XR-01 — construction order and several byte edges need exact editorial closure

The printed “only accepted construction order” lists S and B before A/C/G/K
even though S and B contain their digests. The edge/rank relation is acyclic,
but the printed execution order is not executable.

Additionally:

- `authorizationUseSelectorSHA256` is bound by Intent without an explicit
  digest equation;
- direct-owner S has no explicit transport/materialization source even though
  downstream verification requires exact S bytes; and
- the catalog delegation rule does not state path-exactly that every selected
  E/Q is the exact projection of the D scope used to sign L.

Smallest correction:

- print the topological order from section 5.1 of this review;
- define `SHA256Hex(exact U bytes)`;
- define the canonical Q→S projection for the direct path; and
- require the selected E/Q and L-signing D to share byte-identical S.

Verdict: **OPEN P2 / does not independently create authority while sets remain
EMPTY, but blocks exact cross-runtime reproduction**.

### P2-B-XR-02 — vector IDs are unique, but fixture applicability and repository paths are absent

Mechanical review reproduced:

```text
named vectors = 83
unique vectors = 83
duplicates = 0

B-RC3 = 46
B-RC4 = 32
B-PRIV = 5
```

However, Packet B provides no:

- exact fixture producer root;
- fixture filename or bytes/hash/shape;
- per-vector expected typed decision/reason;
- CellProtocol/CellScaffold/Binding consumer applicability;
- exact future test identifier;
- repo-qualified source/test/docs path;
- producer/consumer byte-preservation rule; or
- explicit not-applicable reason.

There are therefore no repository-path statements to falsify, but also no
path-exact fixture contract to validate. Names alone do not satisfy the
contract-testing requirement.

Smallest correction:

- one canonical producer root;
- one manifest entry per vector with exact file/test paths and expected result;
- explicit A/B/C applicability or typed not-applicable reason; and
- byte-identical consumer/hash obligations.

Verdict: **OPEN P2 / fixture implementation and cross-consumer applicability
not reviewable**.

## 7. Signer, delegation, and tuple review

### 7.1 Direct-owner path

Required relation:

```text
D artifact/digest = null/null
B signer          = exact target owner
L signer          = exact target owner
N signer          = exact requester
```

Packet B states this relation and rejects mixed delegation nullability.

### 7.2 Delegated path

Required relation:

```text
D signer             = exact target owner
D delegated signer   = exact B/L signer
D permitted kinds    contains the exact signed kind
D scope              = exact S
B/Q/E selected tuple = exact S projection
N signer             = exact requester in S/Q
```

The core fields exist. P2-B-XR-01 requires the last projection/equality to be
made explicit for the selected catalog entry and L.

### 7.3 Complete tuple

The following substitution classes are digest/signature-visible in Q and the
completed artifacts:

```text
requester/subject
target Cell
target owner
Agreement
Contract
Grant
Conditions
consent
operation
register mutation mode
status kind
action/resource/capability
RWXS access
purpose
audience
Identity domain
response signer algorithm/descriptor/key ID
direct/delegated signer path
```

Wrong bytes reject or become unavailable. No transport field repairs them.
The immutable tuple therefore has a strong non-substitution design. Current
selection remains blocked by P1-B-XR-01/02.

### 7.4 EMPTY behavior

Packet B explicitly freezes all actual authority/status signer, trusted-time,
and rollback accepted sets as EMPTY. Consequently:

```text
AcceptedAuthority = EMPTY
CellScaffold authority readiness = UNAVAILABLE
```

This is correct fail-closed behavior and not production authority evidence.

## 8. Signed subject-head body reconstruction

### 8.1 Register

`RegisterBodyCore v3` contains:

```text
expectedRegistrationGeneration
expectedRevocationGeneration
headExpectation = B64(exact SubjectHeadExpectationCore v1)
headExpectationSHA256 = SHA256Hex(exact decoded expectation bytes)
mutationMode
registrationID
```

The nested expectation contains signed/current-status-bound:

```text
expectedHeadEpoch
expectedHeadGeneration
expectedHeadKey
expectedLifecycleState
expectedRegistrationGeneration
expectedRegistrationID
expectedRevocationGeneration
headStatusAdmissionID
headStatusFreshUntilMilliseconds
headStatusOutcomeSHA256
```

Mode matrix:

| Register mode | Required expected state |
|---|---|
| first enroll | absent-never-initialized, null epoch, head generation 0 |
| retained-head enroll | empty-after-deregister, same non-null epoch/current generation |
| policy-deleted enroll | absent-after-policy-deletion; currently unavailable |
| update | exact active head/ID/generations |
| token rotation | exact active head/ID/generations |
| reactivate | exact revoked head/ID/generations |

The inherited generation fields must equal the nested expectation. The body
digest is then bound by Intent, Challenge, Request, and requester signature.
This closes the original absence of signed head epoch/generation fields.

### 8.2 Revoke

`RevokeBodyCore v2` contains exact nested expectation bytes/digest, expected
registration/revocation generations, reason, registration ID, and schema.
The expectation must select the exact active registration.

### 8.3 Deregister

`DeregisterBodyCore v2` adds exact deletion mode and permits exact active or
revoked current registration. The only mode is:

```text
endpoint_and_token_material
```

It does not claim complete privacy erasure. The transition/result remains
operationally unavailable until RC1 and durability/rollback inputs exist.

## 9. CurrentSubjectHead transition review

| Transition | Static relation in Packet B | Cross-review verdict |
|---|---|---|
| first enroll | absent proof → new epoch, head 1, registration 1, revocation 0 | structurally present; operationally unavailable |
| re-enroll after deregister | retained epoch/empty head → head +1, new ID, registration 1, retained revocation | structurally present |
| re-enroll after policy deletion | accepted deletion proof → new epoch/head 1 | deliberately unavailable |
| update | active same epoch/ID → head +1, registration +1 | structurally present |
| token rotation | active same epoch/ID → head +1, registration +1 | structurally present |
| reactivate | revoked same epoch/ID → head +1, registration +1, active | structurally present |
| revoke | active → head +1, revocation +1, registration unchanged | structurally present |
| deregister | active/revoked → endpoint/token removed, same epoch, head +1, empty | structurally present |
| same expected head concurrently | one CAS winner, stale loser | structurally present |
| same admission/same bytes | stored exact replay | structurally present |
| same admission/different bytes | replay conflict/no mutation | structurally present |
| allocation collision | bounded retry missing; after first collision unavailable | fail-closed |
| generation overflow | no mutation | intent correct; error mapping P1-B-XR-05 |
| crash/rollback | provider required | formal boundary P1-B-XR-04 |

The transition table is useful but not a CLOSED head-CAS contract because the
durable head bytes and atomic authority boundary remain incomplete under
P1-B-XR-03/04.

## 10. Retention and privacy boundary

The review found no selected or encoded retention duration, deletion time,
permanence decision, compaction period, backup behavior, legitimate-purpose
decision, disclosure policy, or user wording.

Packet B explicitly freezes:

```text
policy deletion of current empty head = DISABLED
policy deletion proof accepted set   = EMPTY
post-policy-deletion re-enroll        = UNAVAILABLE
tombstone/history compaction          = DISABLED
privacy claim                         = NONE
```

Therefore `MBI-PRIVACY-RETENTION-01` remains correctly owner-controlled and
open. P1-B-XR-03 is not a finding that Packet B chose a retention policy; it is
the narrower finding that an undefined retention-related member remains
inside the purported correctness/CAS core.

Local or server absence still does not prove deregistration, revocation,
deletion, or privacy erasure.

## 11. RC1/status/result residual review

Correctly declared residuals:

- final signed current-subject status result mapping is outside Packet B;
- production `SubjectHeadExpectationCore` remains EMPTY without it;
- mutation response mapping for `HeadTransitionEvidenceCore` is EMPTY;
- end-to-end mutation readiness is UNAVAILABLE;
- stable-media/rollback, trusted-time, and accepted authority bytes are absent;
- resolve and submit remain fail-closed; and
- no production success is claimed.

Not correctly delegated as residual:

- the generation-overflow retry class is already governed by frozen S5 and is
  wrong in Packet B; this is P1-B-XR-05, not an owner decision.

RC1 remains an explicit prerequisite. This review grants no RC1 closure.

## 12. Final RC3/RC4 disposition

### 12.1 RC3

```text
IMMUTABLE AUTHORITY DAG = ACYCLIC
IMMUTABLE TUPLE NON-SUBSTITUTION = STRONG STATIC DESIGN
MANDATORY E CURRENT SELECTOR = UNCONSTRUCTIBLE
GENERIC AUTHORITY REVOKE = INCONSISTENT
EXTERNAL AUTHORITY INPUTS = EMPTY
OPERATIONAL AUTHORITY = UNAVAILABLE

RC3 = PARTIAL / FORMAL_NO_GO
```

The Packet B claim `RC3 FORMAL BYTE/DAG DESIGN = CLOSED` is not accepted.

### 12.2 RC4

```text
SIGNED HEAD EPOCH/GENERATION IN MUTATION BODIES = PRESENT
TRANSITION INTENT/CAS MATRIX = PRESENT
CURRENT HEAD BYTE TOTALITY = OPEN P1
ATOMIC ROLLBACK-ACTIVATION BOUNDARY = OPEN P1
POLICY DELETION/RETENTION = PARTIAL, EXACT OWNER RESIDUAL
RC1 STATUS/RESULT = MISSING
OPERATIONAL MUTATION = UNAVAILABLE

RC4 = PARTIAL / FORMAL_NO_GO
```

The narrower signed-body correction is valid, but the Packet B claim
`RC4 SIGNED HEAD-CAS FORMAL DESIGN = CLOSED` is not accepted.

## 13. Finding reconciliation

Authoritative finding headings in this review:

```text
P0 headings = 0
P1 headings = 5
P2 headings = 2
```

IDs:

```text
P1-B-XR-01 mandatory catalog-entry selector unconstructible
P1-B-XR-02 revoke ref/head generation and revocation mismatch
P1-B-XR-03 undefined retention-related current-head CAS member
P1-B-XR-04 non-atomic local commit/external rollback activation
P1-B-XR-05 frozen error mapping violation

P2-B-XR-01 non-topological printed order and incomplete explicit byte edges
P2-B-XR-02 no fixture applicability or repo-qualified path contract
```

## 14. Smallest safe successor scopes

No source work is authorized. The smallest document-only successors are:

1. **RC3 selector/revoke correction:** version E/ref/current-head/mutation/U
   so a complete positive current-selection chain and revoked chain are both
   constructible.
2. **RC4 head/anchor correction:** freeze tombstone-member nullability and
   exact expectation projection; define prepared→externally anchored→active
   crash/replay semantics.
3. **RC1 mapping correction:** use the frozen target-unavailable
   retryClass/terminality tuple and leave missing result/status schemas
   explicitly residual.
4. **Fixture applicability packet:** exact producer root, filenames, hashes,
   expected decisions, A/B/C applicability, test IDs, and repo-qualified
   paths for all 83 vector IDs plus new findings.
5. A new independent exact-byte review by a reviewer distinct from both the
   Packet B author and the correction author.

These scopes may be authored independently but cannot be integrated or
implemented from this review.

## 15. Preserved stop gates

```text
PACKET B = NO-GO
RC3 = PARTIAL / FORMAL_NO_GO
RC4 = PARTIAL / FORMAL_NO_GO
S6 INTEGRATION = NO-GO
NEXT PHASE = NO-GO

SOURCE = NO-GO
GIT = NO-GO
DEPENDENCY RESOLUTION = NO-GO
BUILD = NO-GO
TEST EXECUTION = NO-GO
NETWORK = NO-GO
PORTAL = NO-GO
SIGNING = NO-GO
DEVICE = NO-GO
APNS = NO-GO
SECRETS = NO-GO
IDENTITY ACTION = NO-GO
STAGING = NO-GO
DEPLOYMENT = NO-GO
INTEGRATION = NO-GO
MATERIAL = NO-GO
PRODUCTION = NO-GO
```

## 16. Review freeze

```text
REVIEWED PACKET B SHA-256 =
  36bccdd94e183cae4aa7a26a0637ce8f71abbb7bf8f17086d175859856a0ffb8
REVIEWED PACKET B SHAPE = 1905 lines / 54641 bytes

REVIEWER = DISTINCT FROM PACKET B AUTHOR
REVIEW TYPE = EXACT-BYTE STATIC CROSS-REVIEW
P0/P1/P2 = 0/5/2

IMMUTABLE AUTHORITY DAG = ACYCLIC
CURRENT AUTHORITY SELECTION = PARTIAL / NO-GO
CURRENT SUBJECT HEAD/CAS = PARTIAL / NO-GO
MBI-PRIVACY-RETENTION-01 = OPEN / NOT CHOSEN
ACCEPTED AUTHORITY SET = EMPTY
OPERATIONAL READINESS = UNAVAILABLE
RC1 STATUS/RESULT = RESIDUAL / MISSING

RC3 = PARTIAL / FORMAL_NO_GO
RC4 = PARTIAL / FORMAL_NO_GO
PACKET B = NO-GO
S6 = NO-GO
NO NEXT PHASE
```
