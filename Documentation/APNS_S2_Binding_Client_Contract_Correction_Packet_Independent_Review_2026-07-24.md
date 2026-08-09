# APNS S2 Binding Client Contract Correction Packet — Independent Exact-Byte Review

Status: **REVIEW-FROZEN / LANE C PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO**

Review timestamp: `2026-07-25T00:08:18+02:00`  
Review role: independent S2 Lane C reviewer, distinct from the Lane C author  
Review scope: static exact-byte review only  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_Independent_Review_2026-07-24.md`

This review does not amend the reviewed packet, either peer S2 correction, or
any immutable S0/S1 input. It grants no authority for source edits, Git
mutation, dependency resolution, build, test, network, portal, signing,
archive, device action, APNS contact, secret access, Identity work, staging,
deployment or a next material phase.

The review output path was re-attested absent before this artifact was
created. This reviewer did not author the S2 Lane C packet. This reviewer did
author the parallel S2 Lane B correction and therefore awards that packet no
independent-review credit; Lane B is used below only as a read-only interface
comparison.

## 1. Exact review target and bound lineage

### 1.1 Reviewed Lane C bytes

| Path | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| `Documentation/APNS_S2_Binding_Client_Contract_Correction_Packet_2026-07-24.md` | `6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56` | 1112 | 52295 |

The review covers exactly those bytes.

### 1.2 Immutable S0 chain

| Input | SHA-256 | Lines | Bytes |
| --- | --- | ---: | ---: |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 | 22485 |

The inherited S0 result remains immutable:

```text
P0/P1/P2: 0/2/1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

This review awards no S0 closure.

### 1.3 Exact S1 chain

| Lane | Artifact | SHA-256 | Lines | Bytes | Frozen review result |
| --- | --- | --- | ---: | ---: | --- |
| A packet | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_2026-07-24.md` | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 | 48951 | Author proposal |
| A review | `Documentation/APNS_S1_CellProtocol_Producer_Contract_Packet_Independent_Review_2026-07-24.md` | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 | 27880 | `0/5/2`, NO-GO |
| B packet | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_2026-07-24.md` | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 | 48837 | Author proposal |
| B review | `Documentation/APNS_S1_CellScaffold_Server_Contract_Packet_Independent_Review_2026-07-24.md` | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 | 37781 | `0/4/1`, NO-GO |
| C packet | `Documentation/APNS_S1_Binding_Client_Contract_Packet_2026-07-24.md` | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 | 45250 | Author proposal |
| C review | `Documentation/APNS_S1_Binding_Client_Contract_Packet_Independent_Review_2026-07-24.md` | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 | 21808 | `0/3/4`, NO-GO |

All S1 artifacts remain immutable evidence inputs. Their reviews, not their
author self-dispositions, govern the inherited blocker state.

### 1.4 Parallel peer S2 interface inputs

| Lane | Path | SHA-256 | Lines | Bytes | Review treatment |
| --- | --- | --- | ---: | ---: | --- |
| A | `Documentation/APNS_S2_CellProtocol_Producer_Contract_Correction_Packet_2026-07-24.md` | `1b750373b4cb98c71983b002b6a2ce1fd809086776bd64b92d3b27e386969854` | 1746 | 69053 | Parallel author proposal; interface/adversarial comparison only |
| B | `Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_2026-07-24.md` | `cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4` | 1127 | 52292 | Parallel author proposal; interface comparison only; no independent credit from this reviewer |

Neither S2 peer packet had a bound independent review in the Lane C target.
Their bytes therefore cannot be promoted to a canonical implementation
contract by this review. They are nevertheless the exact parallel composition
inputs that Lane C must either match or keep explicitly unreachable.

## 2. Review method and claim boundary

The review:

1. reproduced the target, S0, S1 and peer S2 byte identities;
2. read the complete 1112-line Lane C correction;
3. reproduced every S1 C finding and every `C-DEC-01...12` disposition;
4. checked empty-local truth, durable evidence, response retention, restart,
   ambiguous-send and cross-process behavior;
5. compared Lane C's versioned operation, challenge, status, correlation,
   revoke/deregister and fixture assumptions against peer S2 Lane A;
6. used peer S2 Lane B only to test whether a server interface could cure or
   amplify the Lane A/C mismatch;
7. checked bundle/topic/origin, Apple no-touch, production-evidence separation
   and Identity-cutover separation; and
8. classified only technical client-plan invariants as closed.

No source object was changed or built. No test, dependency resolver, Git
operation, network, portal, signing, archive, device action, APNS contact,
secret access, Identity action, staging action or deployment occurred.

## 3. Review result

```text
P0: 0
P1: 4
P2: 0

S2 LANE C EXACT-BYTE REVIEW: COMPLETE
S2 LANE C PACKET: NO-GO
MBI-05: PARTIAL / OPEN
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
```

The packet is consistently fail-closed where upstream inputs are absent, so
none of the findings is P0. Four composition-critical client-plan defects
remain P1. No additional standalone P2 is required beyond those P1s and the
packet's correctly preserved missing-bound inputs.

## 4. P1 findings

### P1-S2-C-01 — Lane C consumes the obsolete S1/v3 interface and has no
constructible S2-A challenge-preparation order

**Lane C claims**

- lines 348–358 freeze the operation ledger as `register`, `resolve`,
  `submit`, proposed `status`, proposed `revoke`, and undefined
  `deregister`;
- lines 375–395 order the common flow as durable intent, challenge request,
  verified challenge, then protected-request preparation;
- lines 465–485 conditionally consume
  `cellprotocol.device-ingress.challenge-intent.v1` with `intentID`,
  subject proof, authority/Agreement hints, a minimum issuer generation and
  intent timestamps;
- lines 638–655 retain v3 `registerOrUpdateDevice` only as an unresolved
  rotation possibility; and
- line 820 proposes a Binding transport fixture named
  `DeviceIngressHTTPTransport.v3.json`.

**Peer S2-A interface**

- S2 A lines 238–276 explicitly preserve v3 bytes but prohibit new status,
  revoke, deregister and correlation semantics under v3;
- S2 A lines 281–305 define exactly six v4 operations:
  `registerOrUpdateDevice`, `readRegistrationStatus`, `revokeDevice`,
  `deregisterDevice`, `resolveTicket` and `submitTicketResult`, with status
  exactly `r--s` and all five mutations exactly `rw-s`;
- S2 A lines 307–376 define protected carrier
  `haven.device-callback.transport.v4`, challenge carrier
  `haven.device-callback.challenge-request.v2`, and transport-only route
  labels;
- S2 A lines 496–526 define challenge intent
  `cellprotocol.device-ingress.challenge-intent.v2`; its required fields do
  not match Lane C's v1 field list; and
- S2 A lines 1182–1245 and 1279–1313 define the producer manifest and v4/v2
  fixture inventory instead of the Lane C v3 fixture.

There is also an unresolved preparation cycle. S2 A challenge intent v2
requires `requestSHA256` and `bodySHA256` before challenge issuance. Lane C's
total graph prepares the protected request only after the challenge is
verified. The packet names no reviewed two-phase `RequestFactory` operation,
challenge-independent canonical-body preparation, or other byte-preserving
method that can produce the two digests before requesting the challenge
without later changing the request/body bytes.

Peer S2 B cannot repair this mismatch. Its parallel packet also consumes the
S1 proposed operation/challenge surface and explicitly leaves Lane A green
review as a prerequisite. This review awards B no closure.

**Impact**

Lane C cannot construct or verify the peer S2-A challenge request, cannot
select the exact v4 operation/Grant tuple, and cannot consume the proposed
producer fixture manifest. The common graph is safely unreachable, but it is
not cross-lane composable. `P1-C-03`, `P2-C-04`, `C-DEC-02`,
`C-DEC-03`, and `C-DEC-09` therefore are not closed in the S2 composition.

**Smallest successor scope**

The CellProtocol producer and Binding client owners must freeze one exact
document-only preparation contract:

1. either an explicit two-phase preparation API that creates immutable
   canonical protected-body bytes and stable request/body digests before
   challenge issuance, then binds the returned challenge without changing
   those bytes;
2. or a corrected producer intent whose pre-challenge fields do not depend on
   bytes that can only exist after challenge verification.

The same successor must replace all S1/v3 names with the exact reviewed
version, operation enum, carriers, status/revoke/deregister results, producer
manifest path and consumer fixtures. It must not invent issuer authority or
generate fixture bytes.

**Closure verdict:** **OPEN P1 / CROSS-LANE COMPOSITION BLOCKED**.

### P1-S2-C-02 — Registration/token correlation is required before send but is
not in the pre-send durable record

**Lane C claims**

- lines 238–260 define the common durable record stored before send; it
  contains no `tokenObservationID`, `tokenDeliveryEpoch`, or
  `expectedPreviousRegistrationGeneration`;
- lines 287–299 say those token-observation fields may be added only after a
  verified register response and “never before”;
- lines 393–414 require the complete expectation before send and promise that
  blocked recovery does not clear token-observation lineage;
- lines 611–620 require a token observation to be mapped to the protected-body
  digest and admission ID before send;
- lines 642–655 require exact update correlation before
  `activeCurrentForObservation`; and
- lines 974–983 require concurrent callbacks and every rotation crash boundary
  to preserve ambiguous evidence.

**Peer S2-A interface**

S2 A lines 531–581 define
`cellprotocol.device-ingress.registration-mutation-correlation.v1` with
required `operation`, `admissionID`, `requestSHA256`, `bodySHA256`, and
`expectedPreviousRegistrationGeneration`. S2 A lines 1671–1684 explicitly
require Lane C to retain that exact tuple before register/update send.

The non-secret observation ID/epoch is the client-local bridge between an iOS
token callback and that exact mutation tuple. If the process dies after
`sendStarted`, the current schema can retain request/body/admission hashes but
cannot prove which token observation they represent or which previous
registration generation the mutation expected. Adding those fields only
after a verified response is too late for ambiguous-send recovery.

This does not justify persisting the raw token or a token hash. Those remain
forbidden.

**Impact**

The claimed admissionID/registrationID/protected-body/expectation/status
read-back graph is not total for first registration, reactivation or token
rotation. A crash can safely end in unknown, but it loses the exact non-secret
lineage needed to distinguish `current_exact`, `superseded`, `not_found`, and
`inconsistent_retryable`. `P1-C-02`, `C-DEC-04`, `C-DEC-05`, and
`C-DEC-07` remain only partial.

**Smallest successor scope**

Add a pre-send registration-mutation extension to the same crash-durable,
locked evidence transaction containing:

```text
tokenObservationID
tokenDeliveryEpoch
operation = registerOrUpdateDevice
admissionID
requestSHA256
bodySHA256
expectedPreviousRegistrationGeneration
```

The raw token and reversible derivatives remain memory-only. Registration ID,
committed generation, record hash and verified receipt fields remain
post-verification only. Add crash/race negatives before and after every field
commit and before/after `sendStarted`.

**Closure verdict:** **OPEN P1 / TOTAL RECOVERY GRAPH NOT CLOSED**.

### P1-S2-C-03 — A v3 admission-ID derivation is promoted to all future
operations without a v4 producer contract

**Lane C claims**

- line 252 requires `admissionID == base64url(requestSHA256)` in every common
  durable operation record;
- lines 406–412 address recovery by admission/expectation bindings; and
- line 921 requires the same formula in every future operation test.

That formula is an immutable current-v3 fact reproduced at Lane C lines
101–112. It is not thereby a v4 fact.

**Peer S2-A interface**

S2 A lines 407–456 define a full immutable v4 admission/replay key over:

```text
envelope schema
challenge issuer ID
challenge generation
challenge nonce
request subject
operation
request SHA-256
body SHA-256
```

with producer-frozen length framing still required before source
authorization. S2 A uses `admissionID` in the registration-correlation object
but does not freeze its v4 derivation as `base64url(requestSHA256)`.

The full replay key does not prove that its public/opaque admission identifier
is the v3 request-hash projection. Lane C cannot independently impose that
formula on v4. Conversely, it cannot silently substitute the full internal
key as a client-visible identifier without a producer-owned schema and
fixture.

**Impact**

The client may persist an identifier that the v4 server never returns or
accepts for status correlation/read-back, or may collapse versioned
admissions that the producer deliberately distinguishes by issuer, subject,
operation and body. This breaks the exact recovery address and producer
fixture contract.

**Smallest successor scope**

The producer owner must freeze:

- the exact v4 `admissionID` derivation or opaque generation rule;
- its relation to the full internal replay key;
- encoding, byte limit and privacy behavior;
- whether it is present in response expectation, receipts and status
  correlation; and
- positive and cross-version/cross-operation substitution fixtures.

Lane C must consume that rule from the reviewed producer artifact and remove
the unconditional v3 equality if it is not the v4 rule.

**Closure verdict:** **OPEN P1 / RECOVERY IDENTITY NOT COMPOSABLE**.

### P1-S2-C-04 — The authoritative negative-state mapping is not exact and can
confuse status absence with mutation-correlation absence

**Lane C claims**

- lines 178–190 distinguish local `unknown` from `notFoundCurrent`;
- lines 204–220 allow first registration or pre-registration decline after an
  authoritative `not_found`;
- lines 420–447 use fresh subject discovery/status to adjudicate an ambiguous
  first registration; and
- lines 1027–1033 classify the client truth behavior as technically closed
  while leaving the upstream selector/schema open.

**Peer S2-A interface**

- S2 A lines 583–645 define status selectors `registration_id` and
  `subject_current`;
- S2 A lines 647–700 define status state `unknown`, not `not_found`;
- for `subject_current`, `unknown` means no disclosable current status for the
  authenticated subject at `observedAt`, while
  `indeterminate_retryable` remains fail-closed;
- S2 A lines 531–581 separately define correlation disposition `not_found`,
  meaning that no committed mutation matches the complete
  admission/request/body/previous-generation tuple; it does not prove that no
  current registration exists.

Lane C does not freeze which exact signed selector/state tuple maps to local
`notFoundCurrent`. The generic term `not_found` can denote the correlation
disposition in the peer contract, which is insufficient to open
first-registration or decline. It also does not state that only a fresh
`subject_current` status observation, never a `registration_id` privacy
negative or correlation `not_found`, may establish current subject absence.

**Impact**

Without an exact decoder/state mapping, the client either remains permanently
blocked or risks treating “this exact mutation was not found” as “this subject
has no current registration.” The latter can reopen consent/enrollment while
another current registration exists.

**Smallest successor scope**

Freeze a closed mapping table after the producer packet is independently
accepted:

```text
selector = subject_current
+ signed status state = unknown
+ exact current target/owner/Contract/subject
+ accepted generation floors
+ fresh observedAt policy
=> local notFoundCurrent

correlationDisposition = not_found
=> exact mutation historical absence only; never notFoundCurrent

selector = registration_id + state = unknown
=> privacy-preserving unknown for that selector; never subject absence

indeterminate_retryable, stale, replayed, unsigned, multiple-current,
generation-regressed, wrong target/owner/Contract
=> local unknown/blocked
```

The producer owner must also freeze the exact status freshness lifetime or
derivation. Lane C must not invent it.

**Closure verdict:** **OPEN P1 / CONSENT AND FIRST-REGISTRATION GATE NOT
COMPOSABLE**.

## 5. S1 Lane C finding-by-finding adjudication

| S1 C finding | S2 independent verdict | Exact reason |
| --- | --- | --- |
| `P1-C-01` empty local evidence promoted to not registered | **CLIENT INVARIANT CLOSED; INTEGRATED CLOSURE PARTIAL** | Lines 178–225 correctly make local absence unknown and disable mutation. P1-S2-C-04 blocks exact mapping from S2-A status bytes to `notFoundCurrent`. |
| `P1-C-02` ambiguous recovery has no composable path | **PARTIAL / OPEN P1** | The fail-closed graph is much more exact, but P1-S2-C-02 loses pre-send token correlation and P1-S2-C-03 lacks a v4 recovery identifier. Callback submit adjudication remains S2-A-MBI-04. |
| `P1-C-03` challenge omits signed intent and issuer continuity | **OPEN P1** | The S1 v1 consumer state is detailed, but it does not consume S2-A intent v2 and has an unresolved request/body-digest preparation cycle. Issuer-rotation authority also remains missing. |
| `P2-C-01` resolve/submit are prose only | **CLOSED FOR CLIENT STATE PLAN / OPERATIONAL RECOVERY OPEN** | Section 12 names exact durable/volatile states, retained fields and fail-closed crash outcomes. Ambiguous submit remains safely blocked on S2-A-MBI-04. |
| `P2-C-02` Apple no-touch incomplete | **CLOSED FOR STATIC OWNER PLAN** | Lines 858–896 enumerate the exact 11-path M1 ledger, collision owner, entitlement no-touch and all other no-touch domains. |
| `P2-C-03` status asked to prove topic/origin/signing | **CLOSED FOR EVIDENCE SEPARATION** | Section 14 and tests at lines 1014–1020 separate Cell status, transport, signing/provider and physical-device evidence. |
| `P2-C-04` authority test hard-codes `rw-s` | **CONCEPT CLOSED; INTEGRATED CLOSURE PARTIAL** | Lines 340–369 and 947–960 derive exact access per operation and test substitution, but the operation/version table remains the obsolete S1 proposal under P1-S2-C-01. |

No target bytes changed, so this review itself closes no source/runtime gate.

## 6. `C-DEC-01...12` adjudication

| ID | Independent verdict | Technical closure or remaining exact input |
| --- | --- | --- |
| `C-DEC-01` | **PARTIAL** | Empty local evidence and current/historical separation are correct. The exact S2-A `subject_current`/status-state mapping and freshness policy remain open under P1-S2-C-04. |
| `C-DEC-02` | **PARTIAL / STALE INTERFACE** | Client stop behavior is fail-closed. Peer S2 A now proposes distinct `revokeDevice` and `deregisterDevice`, but Lane C still consumes the S1 choice blocker and no v4 result mapping. |
| `C-DEC-03` | **OPEN P1** | The v1 intent/nonce/watermark store is internally useful but does not match S2-A challenge intent v2 or its preparation order. Actual issuer-rotation authority remains a genuine MBI. |
| `C-DEC-04` | **OPEN P1** | Peer S2 A supplies an exact correlation tuple, but Lane C does not persist all tuple and observation fields before send. |
| `C-DEC-05` | **PARTIAL** | No unsafe replay or success is invented. Register/update can eventually use S2-A status correlation after P1s are fixed; exact admission-result retrieval and callback-submit recovery remain missing. |
| `C-DEC-06` | **SUPPORTED FAIL-CLOSED CLIENT RULE / AUTHORITY MBI OPEN** | No local fallback or static trust root is accepted. Production issuer/owner/Agreement/Contract inputs and reviewed rotation authority remain missing. |
| `C-DEC-07` | **PARTIAL** | Tombstone/pending preservation is correct in principle, but token-observation correlation is not crash-durable before send. Server read-back/freshness remains upstream. |
| `C-DEC-08` | **SUPPORTED PRIVACY RULE / BODY INPUT OPEN** | Lane C invents no participant/device fields and leaks none. Exact protected registration-body metadata and reviewed producer fixtures remain owner inputs. |
| `C-DEC-09` | **PARTIAL / STALE CONSUMER PATH** | S2 A now proposes the producer manifest path/schema/inventory, but Lane C still names a generic local v3 fixture and has no exact v4 consumer mapping. Signed fixture bytes/hashes remain S2-A-MBI-02. |
| `C-DEC-10` | **TECHNICALLY CLOSED FOR CLIENT PLAN** | Resolved callback data is volatile by default even when Storage is granted; no generic persistence path is invented. |
| `C-DEC-11` | **OPEN `MBI-07`** | No local provenance substitutes for the missing exact integrated commit/tree/diff/artifact manifest. |
| `C-DEC-12` | **EVIDENCE SEPARATION CLOSED / `MBI-06` OPEN** | DeviceIngress state is separate from Team/profile/certificate/effective production entitlement/codesign/archive evidence. |

## 7. Requested invariant matrix

| Review obligation | Verdict | Evidence |
| --- | --- | --- |
| Empty local evidence remains server-unknown | **PASS — static client invariant** | Lane C lines 178–225 disable all mutation/decline paths until fresh authoritative subject state exists. |
| AdmissionID/registrationID/protected-body/digest/expectation graph is total | **FAIL — P1-S2-C-02/03/04** | Non-secret token correlation is not durable pre-send, v4 admission-ID derivation is not owned, and status-negative mapping is not exact. |
| Client evidence remains private | **PASS — static requirement only** | Raw token, reversible derivative, protected body, private key and unredacted callback payload are excluded from journal/log/UI/export paths. |
| Response retention is Storage-correct | **PASS — static requirement only** | Exact signed response retention requires operation-derived `s`, content-policy permission and private-store placement; resolved payload defaults volatile. |
| Signed challenge intent/nonce/issuer generation matches S2 A/B | **FAIL — P1-S2-C-01** | Lane C consumes S1 intent v1; S2 A proposes intent v2 and a pre-challenge digest order Lane C cannot construct. B cannot confer review credit or cure the mismatch. |
| Resolve/submit state graph is exact | **PASS — client-local fail-closed plan** | Section 12 supplies named durable/volatile states, lineage, crash outcomes and negatives. Callback submit ambiguity remains an explicit upstream MBI. |
| Apple no-touch is exhaustive | **PASS** | Exact 11 M1 paths, project collision ownership, entitlement no-touch and non-Lane-C domains are enumerated. |
| Cell status is separate from APNS topic/origin/signing proof | **PASS** | Section 14 and section 16.9 keep Cell, transport, signed archive/provider and physical receipt as separate evidence classes. |
| Per-operation grants replace blanket `rw-s` | **PASS IN PRINCIPLE / FAIL IN VERSIONED COMPOSITION** | Exact-match/substitution tests are sound; the table must be replaced with reviewed v4 operation names and include distinct deregister. |
| Cross-process/path/link/concurrency negatives are present | **PASS — planned evidence only** | Section 16 covers lock/process races, sync failure, symlink/hardlink/FIFO/device, mode/owner/link count, inode/path swap, rollback and concurrent writer. |
| Shared transport is byte-preserving and semantically neutral | **PASS AS CLIENT REQUIREMENT / PRODUCER ARTIFACT UNREVIEWED** | Lane C assigns no authority to HTTP transport and requires exact bytes. S2-A v4 carrier/manifest consumption remains unresolved by P1-S2-C-01. |
| Cross-lane composition is exact | **FAIL** | Operation versions, challenge-intent fields/order, admission ID, status negative semantics and fixture consumption are not aligned. |
| Bundle/topic/origin are bound without pretending production proof | **PASS** | `org.digipomps.haven` and `https://haven.digipomps.org` remain planning values only. |
| Identity cutover remains separate | **PASS** | No Identity authority or cutover evidence is created or inferred. |

## 8. Cross-lane composition result

### 8.1 S2 A to C

The following peer S2-A outputs are sufficiently exact to be mandatory
consumer inputs after their own independent review:

- the v4 protected-operation set and exact per-operation grants;
- challenge intent v2 and challenge carrier v2;
- protected carrier v4 and semantically neutral route-label mapping;
- `subject_current` and `registration_id` status selectors;
- registration mutation correlation fields and dispositions;
- distinct revoke and deregister operations/results;
- exact origin/audience/redirect/content policy; and
- producer manifest path/schema/inventory.

Lane C does not currently consume those exact interfaces. S2 A also leaves
issuer-rotation authority, signed fixture bytes/hashes, deployed origin proof
and callback-submit recovery missing. Lane C must keep all affected operations
unavailable.

### 8.2 S2 B to C

Peer S2 B supports the following client-side invariants at an interface level:

- durable challenge/admission/response state instead of in-memory success;
- exact Resolver/Cell/Agreement enforcement;
- status admission without registration mutation;
- no static admission root;
- no raw-token client replay requirement; and
- exact response read-back capability inside the server store.

However, B was authored in parallel against the S1 Lane A proposal. It does
not independently settle the S2-A v4 wire, the client-accessible read-back
operation, issuer authority, status-negative mapping or callback-submit
adjudication. This reviewer authored B; this section is not B review credit.

### 8.3 Composition verdict

```text
S2 A ↔ C: NOT COMPOSABLE
S2 B ↔ C: CLIENT INVARIANTS COMPATIBLE, VERSIONED INTERFACE UNSETTLED
S2 A ↔ B ↔ C: NO-GO
```

No source package may be composed from these author packets without crossed
independent reviews and one later exact integrated-output review.

## 9. `MBI-05` adjudication

| `MBI-05` subclaim | Independent verdict |
| --- | --- |
| Exact future Binding paths and owners | **PARTIAL** — local paths and Apple collision/no-touch ownership are strong; the versioned v4 fixture/manifest consumer path remains stale |
| Empty-local/current truth model | **CLIENT INVARIANT CLOSED / WIRE MAPPING PARTIAL** |
| Total register crash/restart graph | **PARTIAL / OPEN P1** — pre-send token/correlation lineage and v4 admission identity are incomplete |
| Signed challenge-intent/nonce/issuer continuity | **OPEN P1** — v1 consumer does not match S2-A v2 and preparation order is unresolved |
| Exact resolve/submit durable states | **SUPPORTED AS CLIENT PLAN / CALLBACK RECOVERY OPEN** |
| Token-rotation continuity | **OPEN P1** — exact S2-A tuple is not durable before send |
| Raw-token/evidence privacy | **SUPPORTED AS EXACT STATIC REQUIREMENT / NO RUNTIME PROOF** |
| Operation-specific access tests | **SUPPORTED IN PRINCIPLE / VERSIONED MATRIX PARTIAL** |
| Complete Apple no-touch ledger | **CLOSED FOR STATIC OWNER PLAN** |
| Production signing readiness | **UNAUDITED / MISSING (`MBI-06`)** |
| Exact integrated output | **MISSING (`MBI-07`)** |

Overall:

```text
MBI-05: PARTIAL / OPEN
```

## 10. Genuine missing-bound inputs

The following are not technical shortcuts for Lane C and are not delegated to
Kjetil:

1. **Challenge preparation contract:** CellProtocol producer plus Binding
   consumer owners must resolve the request/body-digest-before-challenge
   composition cycle.
2. **Issuer rotation authority:** the authoritative signed rotation record,
   trust anchor, signer continuity, revocation and fixture bytes remain
   missing.
3. **Admission identifier contract:** producer-owned v4 `admissionID`
   derivation/encoding and relation to the full replay key remain missing.
4. **Status freshness and exact negative mapping:** producer owner must freeze
   exact observation lifetime and selector/state semantics; Binding then
   freezes the local mapping.
5. **Signed producer fixtures:** v4/v2 fixture bytes, byte counts, SHA-256
   ledger, manifest bytes and production rejection of test keys remain
   missing.
6. **Server authority and durability inputs:** actual owner/issuer/Agreement/
   Contract bytes, key provider, rollback anchor, capacity and deployed origin
   evidence remain missing.
7. **Callback submit recovery:** a subject-bound result/read-back operation and
   fixtures remain S2-A-MBI-04.
8. **`MBI-06`:** Team, production profile/certificate, effective
   `aps-environment=production`, codesign/archive and portal evidence remain
   unaudited/missing.
9. **`MBI-07`:** exact integrated CellProtocol/Identity/CellScaffold/Binding
   commit/tree/diff/dependency/compiler-input/artifact manifest remains
   missing.

## 11. Exact smallest successor scopes

This review authorizes none of these scopes. If development-admin later opens
document-only work, the smallest non-colliding scopes are:

1. **A/C challenge-preparation decision:** one producer/consumer contract
   correction resolving the digest/preparation cycle, exact intent/carrier
   version and issuer-watermark inputs.
2. **A admission-ID decision:** one producer-owned definition of the v4
   identifier, replay-key relation, encoding and fixtures.
3. **C durable-correlation correction:** one Binding-only packet adding
   pre-send non-secret observation/correlation fields and exact
   crash/concurrency tests without storing token bytes or hashes.
4. **C status-mapping correction:** one Binding-only closed mapping from exact
   reviewed S2-A selector/state/correlation/freshness bytes to local truth and
   consent gates.
5. **A/B/C exact-byte recomposition review:** only after distinct independent
   reviews accept the relevant A and B interfaces and the above C corrections.

Identity cutover, Apple signing, integrated output, build/test and production
proof remain separate later gates.

## 12. Preserved stops and final verdict

- S0 remains immutable and NO-GO.
- Every S1 packet/review remains immutable and NO-GO where its review says so.
- Both peer S2 packets remain unreviewed author proposals in this review.
- This reviewer gives the self-authored S2 B packet no review credit.
- No P1 is waived because the client currently fails closed.
- Identity cutover remains a separate prerequisite.
- `MBI-06` production profile, Team, certificate, effective entitlement,
  codesign and archive proof remains unaudited/missing.
- `MBI-07` exact integrated output remains missing.
- No raw token, secret, private key or unredacted protected payload was read,
  displayed or stored.
- No source, Git, build, test, network, portal, signing, device, APNS,
  Identity, staging or deployment action is authorized.

Final independent review decision:

```text
P0: 0
P1: 4
P2: 0

S2 LANE C REVIEW: FROZEN
S2 LANE C PACKET: NO-GO
MBI-05: PARTIAL / OPEN
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
```

The review stops after freezing and re-attesting this one review artifact.
