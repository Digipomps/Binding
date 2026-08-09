# Independent exact-byte review — APNS S2 CellScaffold server contract correction packet

Status: **INDEPENDENT STATIC CROSSED REVIEW / LANE B ONLY / P0 0 / P1 5 / P2 1 / MBI-04 NOT GREEN / PLAN NO-GO / NEXT PHASE NO-GO / SOURCE NO-GO**

Review execution date: `2026-07-25`  
Artifact date retained from the reviewed lane: `2026-07-24`

Reviewed packet:

`Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_2026-07-24.md`

Reviewed exact SHA-256:

`cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4`

Reviewed shape:

`1127` lines / `52292` bytes

Owned output:

`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S2_CellScaffold_Server_Contract_Correction_Packet_Independent_Review_2026-07-24.md`

This review is crossed and independent of the Lane B packet author. The reviewer
authored the S2 Lane A producer correction, so that artifact is used here only
as an exact, read-only peer-interface input. This review does not approve,
amend, or replace Lane A or Lane C.

This was an exact-byte static review. It performed no source edit, Git mutation,
dependency resolution, build, test, network request, portal inspection, signing
action, device action, APNS action, secret inspection, Identity mutation,
staging action, or deployment. It authorizes none of those actions.

## 1. Executive verdict

The S2 Lane B packet makes substantial and useful corrections:

- status now uses `r--s`, while result-bearing mutation operations use `rw-s`;
- status commits durable admission/audit/response state without mutating
  registration state;
- the two proposed infrastructure Cells have explicit scope, persistency,
  lifecycle, recovery order, read-back checks, and `makeNewIfNotFound=false`;
- exact signed challenge bytes, rather than a digest-only substitute, are
  retained for byte-identical replay;
- no static application-admin or environment-owner fallback is permitted;
- APNS token records are sealed and a missing/wrong key fails closed;
- SQLite selection, transaction settings, read-back, rollback-anchor
  dependency, and trusted-time dependency are distinguished from operational
  proof;
- callback canonical success is limited to one selected target-Cell
  transaction, with later effects represented by a target-owned outbox;
- Identity cutover remains separate;
- `MBI-06` remains `UNAUDITED / MISSING`;
- `MBI-07` remains `MISSING`;
- the packet preserves `PLAN NO-GO`, `NEXT PHASE NO-GO`, `SOURCE NO-GO`, and
  `PRODUCTION NO-GO`.

Those improvements do not make the packet an implementation-bounding MBI-04
plan. Five P1 defects remain:

1. the protected-operation path still places canonical inner operation/path
   inspection before the authenticated CellProtocol boundary;
2. the packet consumes the superseded five-operation/v3 S1 interface rather
   than the S2 A v4 six-operation, status-recovery, correlation, and
   deregistration contract, so A/B/C do not compose;
3. the challenge precheck and Agreement catalog remain incomplete: challenge
   issuance checks Agreement but not the complete Contract/Grant path, and no
   exact signed Agreement import/output artifact path is frozen;
4. the challenge state machine is not total when an admitted operation is still
   pending at challenge expiry, and its compaction formula depends on bounds
   that Lane A did not freeze;
5. deregistration retains recoverable ciphertext as `retired` rather than
   atomically erasing endpoint/token material, and logical clearing of a legacy
   SQLite column does not prove removal from WAL/free pages/backups.

One P2 exact-byte evidence gap remains: the server consumer plan does not bind
the S2 A producer-manifest path, v4 fixture inventory, manifest SHA handoff, or
an exact server-side consumer ledger.

Final independent count:

```text
P0: 0
P1: 5
P2: 1

S2 LANE B PACKET: NOT GREEN
S1 B FINDINGS: 3 NARROW CLOSURES / 1 PARTIAL / 1 TEST-INVENTORY CLOSURE
MBI-04 STATIC PLAN: PARTIAL / CORRECTION REQUIRED
MBI-04 OPERATIONAL: MISSING / OPEN
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING
SOURCE AUTHORIZATION: NO
PLAN: NO-GO
NEXT PHASE: NO-GO
PRODUCTION: NO-GO
```

## 2. Formål, goals, and adjudication boundary

### Formål A — falsify the claim that all S1 Lane B findings are closed

Goal:

- reproduce every S1 B P1/P2;
- identify the exact S2 correction;
- decide whether the narrow defect is closed, partial, or open;
- cite the exact S2 B lines and any residual defect.

Result: **satisfied as a review goal**. The closure claim is only partially
supported.

### Formål B — test whether MBI-04 is implementation-bounding

Goal:

- test operation authority;
- test Resolver/Cell registration and bootstrap;
- test Agreement source/output;
- test challenge, admission, replay, restart, rollback, compaction, and token
  state;
- distinguish static plan closure from operational proof.

Result: **satisfied as a review goal**. MBI-04 remains partial and not green.

### Formål C — test S2 A/B/C composition

Goal:

- bind the exact peer S2 A and C hashes;
- compare operation, wire, status, deregistration, correlation, challenge, and
  fixture interfaces;
- require fail-closed MBIs instead of invented authority.

Result: **satisfied as a review goal**. The three peer packets do not yet
compose.

### Evidence and authority boundary

This review counts:

- exact local packet bytes and shapes;
- line-numbered static packet content;
- immutable S0/S1 review results;
- CellProtocol transport-neutrality, Resolver, Identity, capability, Agreement,
  replay, and exact-fixture invariants;
- the exact peer S2 A/C bytes for interface comparison only.

This review does not count:

- source behavior not inspected in this review;
- a packet assertion as runtime evidence;
- SQLite/WAL settings as crash durability proof;
- an environment variable or signed-looking file as authority;
- an Agreement as sufficient without the applicable Contract/Grant and
  conditions;
- a unit-test plan as production evidence;
- a peer S2 author packet as independently approved.

## 3. Exact-byte gate and immutable lineage

The review re-attested these exact local artifacts:

| Artifact | SHA-256 | Shape | Treatment |
|---|---|---|---|
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 lines / 38154 bytes | immutable lineage |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 lines / 29346 bytes | immutable lineage |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 lines / 54678 bytes | immutable governing S0 |
| `Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md` | `45d86543bd61cf070243a5cf61aea236fd8ea1e88dd6d53c5e0fecdb82003abd` | 461 lines / 22485 bytes | immutable governing S0 review |
| S1 A producer packet | `ba76396dc4e6941fda61bb932d1509be58045e6a57d9dac05ef6da3f7d512b97` | 1141 lines / 48951 bytes | immutable S1 input |
| S1 A independent review | `0826c7fef19b1affe5e7dd7e434e97ee68cdbaae5cf4d6a484c737b48ff5b51b` | 691 lines / 27880 bytes | `0/5/2`, NO-GO |
| S1 B server packet | `5bb59aba03acbabd2ee3387adc22a9d47311a50089daed11ff98d15e35eea27a` | 1113 lines / 48837 bytes | immutable S1 input |
| S1 B independent review | `09d26350d31563530566c18baa92cb652a311e9a79a5b85e119a91ee23b84a2c` | 822 lines / 37781 bytes | `0/4/1`, exact correction input |
| S1 C Binding packet | `de5f6b9210a53d37422a21e99d0bc01749e381e7502a5934ca46d5b7e3cf995c` | 853 lines / 45250 bytes | immutable S1 input |
| S1 C independent review | `2336b48aa04c1fcafbc9892240d5b813340931f97deaa8af8dd5d5c357f10998` | 471 lines / 21808 bytes | `0/3/4`, NO-GO |
| S2 A producer correction | `1b750373b4cb98c71983b002b6a2ce1fd809086776bd64b92d3b27e386969854` | 1746 lines / 69053 bytes | peer interface only; unreviewed here |
| S2 B server correction | `cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4` | 1127 lines / 52292 bytes | exact review target |
| S2 C Binding correction | `6226c179838398ee7314df26ffc25b0b39a3de7fde9f2733abc2284c6268bc56` | 1112 lines / 52295 bytes | peer interface only; unreviewed here |

The owned review path was absent before this review was written.

S0 remains immutable. Its independent result remains:

```text
P0: 0
P1: 2
P2: 1
PLAN: NO-GO
NEXT PHASE: NO-GO
```

## 4. Review method and severity rule

The reviewer:

1. rehashed and reshaped the S2 B target;
2. read all 1127 target lines;
3. read the complete S1 B independent review;
4. reproduced all four S1 P1 findings and the S1 P2 finding;
5. compared all `B-DEC-01...12` rows with the corrected body;
6. compared MBI-04 with immutable S0;
7. compared S2 B against exact peer S2 A and C interfaces;
8. challenged authority, privacy, state-machine, crash, restart, replay,
   rollback, compaction, token, path, owner, and fixture claims;
9. separated technical invariants from genuine authority/product inputs.

Severity means:

- **P0:** the packet itself authorizes or creates an immediate critical breach
  or irreversible unsafe action;
- **P1:** a contract is unsafe, contradictory, cross-lane incompatible, or too
  incomplete to bound later implementation;
- **P2:** exact test, fixture, documentation, or audit completeness is missing
  but the omission does not independently grant authority.

No unaudited external source is counted as support.

## 5. P0 findings

No P0 finding.

The target remains planning-only, explicitly keeps source and production closed,
and performs no material external action. Its defects are plan-blocking P1/P2
issues rather than an executed production compromise.

## 6. P1 findings

### P1-S2-B-01 — inner operation inspection still occurs before the authenticated CellProtocol boundary

**Exact S2 B locations**

- lines `134–151` place “canonical read-only operation/path inspection owned by
  reviewed Lane A” between transport decode and the verified
  request/challenge/body tuple;
- lines `158–162` preserve this inspection as a dependency and say Lane A must
  resolve ownership;
- lines `994–1002` again list inner-operation inspection ownership as open.

**Contradicting peer interface**

S2 A lines `183–236` freeze:

- the transport and composition adapter pass exact opaque bytes;
- the adapter maps the route to unauthoritative expected-operation metadata;
- the authenticated CellProtocol boundary performs the first inner canonical
  decode;
- the transport must not inspect inner schema, operation, Identity, Agreement,
  Contract, capability, selector, registration, or result.

S2 A lines `394–433` freeze the boundary evaluation order: canonical decode,
route equality, complete tuple, challenge binding, Identity, Resolver,
Agreement/Contract, capability, replay, admission, and target execution.

**Why the S2 B wording is not a harmless abstraction**

Calling the inspection “read-only” does not make it semantically neutral. An
inner operation decoder:

- interprets authority-bearing signed bytes;
- can create a second parser/version decision before the protocol boundary;
- can disagree with the v4 producer decoder;
- can reject or route based on inner semantics outside Resolver/Cell policy;
- undermines the S2 A dependency oracle that the transport target not depend on
  CellBase.

The route label itself is allowed. The inner operation decode is not.

**Impact**

A future implementer could preserve exactly the unsafe split identified by S1
A P1-A-01: transport/composition inspects the operation, while the authenticated
boundary receives already-interpreted semantics. That fails transport
neutrality and can produce divergent authorization and replay behavior.

**Required correction**

The Lane B path must be exactly:

```text
HTTP path -> unauthoritative route label
outer carrier -> exact challenge/request/body bytes
route label + exact bytes -> authenticated CellProtocol boundary
authenticated boundary -> first canonical inner decode
authenticated boundary -> route/operation equality
authenticated boundary -> Identity/Resolver/Agreement/Contract/capability
```

Required assertions:

- no CellBase envelope/request decoder is reachable from the transport module;
- no server adapter decodes the inner operation;
- arbitrary bounded inner bytes reach the authenticated executor unchanged;
- route mismatch is a typed protocol-boundary error;
- mismatch creates no admission or target mutation.

**Disposition:** `OPEN P1 / PLAN BLOCKING`.

### P1-S2-B-02 — the server packet does not consume the S2 v4 six-operation and recovery contract

**Exact S2 B locations**

- lines `100–107` reproduce only current register/resolve/submit and absent
  status/revoke;
- lines `176–186` use the S1 five-operation matrix, mark deregister undefined,
  and give token rotation no reviewed semantic;
- lines `253–278` end bootstrap readiness at
  challenge/register/status/revoke/resolve/submit, omitting deregister;
- lines `426–451` omit deregister from mutation transaction behavior;
- lines `475–492` intentionally provide neither subject-current status recovery
  nor exact registration mutation correlation;
- lines `671–684` keep `B-DEC-02` and `B-DEC-09` tied to the rejected S1 A
  packet;
- lines `696–762` name status and revocation files/tests but no deregistration
  service/test path;
- lines `827–859` contain no deregistration, subject-selector, or correlation
  server errors;
- lines `915–926` test that missing registration ID does not trigger lookup,
  which is the opposite of S2 A's authorized `subject_current` recovery;
- lines `982–1004` explicitly bind only the stale S1 A interface;
- lines `1029–1043` keep deregistration and status recovery blocked on Lane A.

**Peer S2 A interface**

S2 A lines `238–305` freeze the author-proposed v4 interface:

- `cellprotocol.device-ingress.envelope.v4`;
- `haven.device-callback.transport.v4`;
- `haven.device-callback.challenge-request.v2`;
- exactly six protected operations;
- separate `deregisterDevice`;
- status `r--s`;
- all other protected operations `rw-s`.

S2 A lines `531–581` freeze exact registration mutation correlation:

- admission ID;
- request SHA-256;
- body SHA-256;
- expected previous registration generation;
- current/superseded/not-found/inconsistent outcomes.

S2 A lines `583–700` freeze:

- `registration_id`;
- authenticated `subject_current`;
- no cross-subject disclosure;
- unique-current/multiple-record behavior;
- historical replay versus fresh status.

S2 A lines `727–942` freeze distinct revoke/deregister receipts, state effects,
idempotency, generation rules, and terminal ID non-resurrection.

S2 A lines `1647–1666` explicitly require Lane B to consume all six routes,
opaque forwarding, durable status admission, concrete target Cells, and the
producer manifest.

**Peer S2 C interface**

S2 C remains conservative and unapproved, but its lines `327–336`, `1027–1039`
require the server eventually to supply subject-bound status and exact
adjudication. Lines `743–757` require durable admission, response read-back,
subject-bound status, typed revoke/deregister, and protected token storage.

Because S2 C was authored in parallel, it still marks deregister and the v2/v4
wire as upstream inputs. That does not rescue B. It proves the three S2 packets
need a crossed reconciliation after A itself is independently reviewed.

**Additional response-framing conflict**

- S2 B lines `149–150`, `986`, and S2 C lines `734–736` say successful HTTP
  response is raw canonical bytes;
- S2 A lines `227–236` refer to returning exact response bytes inside a
  “specified outer response carrier” and lines `1106–1124` allocate an HTTP
  response outer-carrier limit, but do not freeze that carrier schema in the
  cited transport section.

The server must not guess which framing is canonical.

**Impact**

The current B packet cannot be implemented after S2 A without another
contract correction. It lacks:

- v4 schema/version separation;
- deregister route/readiness/service/errors/tests;
- subject-current status storage constraints;
- exact mutation correlation state;
- v2/v4 fixture consumption;
- a settled response-framing contract.

Generation-only token status could be reported incorrectly, local-ID loss
remains unrecoverable, and revoke could be substituted for privacy erasure.

**Required correction**

After S2 A receives its own crossed review, Lane B must bind:

- exact reviewed producer hash and fixture-manifest hash;
- v4/v2 request, challenge, response, replay, and error schemas;
- all six route labels and expected operations;
- subject-current unique-index and terminal-tombstone behavior;
- exact mutation-correlation persistence and status dispositions;
- separate revoke and deregister services/transactions/readiness/errors/tests;
- one exact HTTP success-response framing.

While the producer artifact is unreviewed or internally ambiguous, those routes
remain unavailable.

**Disposition:** `OPEN P1 / CROSS-LANE PLAN BLOCKING`.

### P1-S2-B-03 — Agreement/Contract/Grant provisioning and challenge authorization remain incomplete

**Exact S2 B locations**

- line `178` says challenge issuance consumes no operation Grant and only
  prechecks that the target-operation Agreement exists;
- lines `207–220` define a signed authority manifest and explicitly say it is
  not an Agreement;
- lines `253–278`, especially step 7, say to import complete owner-signed
  Agreements but name no exact runtime input path, config key, canonical
  artifact, or output ledger;
- lines `284–298` correctly fail closed when owner/Agreement input is absent;
- lines `353–367`, especially line `363`, reverify subject, Resolver target,
  target owner, complete Agreement, generations, issuer, and time before
  challenge signing, but omit the applicable Contract/Grant and conditions;
- `B-DEC-05`, lines `677`, claims the “import/verification/Resolver path” is
  frozen even though only source-code and documentation paths are named;
- lines `969–975` claim S1 P1-03 statically closed.

**Why this remains a P1**

An Agreement is necessary but is not, by itself, authority. The complete
authorization path requires:

- authenticated subject;
- exact Resolver target;
- target owner proof;
- applicable signed Agreement;
- applicable signed Contract or Grant;
- exact operation/resource/capability/access/domain/purpose/audience;
- satisfied conditions;
- validity and revocation generations.

A challenge grants no operation and does not need to consume the protected
operation's mutation admission. It still must not disclose target/owner/
agreement-bound material merely because an Agreement exists without the
prospective Contract/Grant.

S0 MBI-04 explicitly requires Agreement **source/output files**. Naming
`DeviceIngressAuthorityCatalogCell.swift` and an operations document is not the
same as freezing:

- where canonical signed Agreement/Contract bytes enter;
- which signed manifest/ledger names them;
- how their byte hashes and owner bind to the target Cell;
- where accepted/revoked generations persist;
- what exact bytes are read back after restart.

**Supported portion**

The two infrastructure Cell tuples and no-auto-create bootstrap are much
stronger:

- `.scaffoldUnique`;
- `.persistant`;
- `lifecyclePolicy=nil`;
- exact manifest-named persisted instance;
- `makeNewIfNotFound=false`;
- `registerNamedEmitCell`;
- Resolver read-back;
- fail startup on absent/mismatched owner, UUID, scope, or instance.

Those choices correctly avoid an automatic static root.

**Required correction**

Freeze, without inventing authority:

- exact config key/path for a canonical signed Agreement/Contract catalog input;
- sanitized producer manifest/ledger schema and byte-hash binding;
- exact target Cell UUID/owner/subject/domain/purpose/audience/generation fields;
- import transaction and post-import read-back;
- accepted, revoked, expired, and condition-unsatisfied state;
- restart and rollback behavior;
- source/output owner;
- fail-closed behavior while actual owner-signed bytes are absent.

Challenge issuance must validate the complete prospective authorization tuple,
including Contract/Grant and conditions, while still recording that challenge
possession grants nothing.

The actual signing authority and Agreement/Contract bytes remain a genuine
Identity/authority MBI.

**Disposition:** `OPEN P1 / S1 P1-03 ONLY PARTIALLY CLOSED`.

### P1-S2-B-04 — challenge expiry makes the persisted state machine non-total

**Exact S2 B locations**

- line `344` defines `consumedActive` as an admitted challenge whose response
  may still be pending;
- the same line permits transition to either `consumedTerminal` or
  `expiredConsumed`;
- line `347` defines `expiredConsumed` as a state where the exact operation
  response remains in the operation ledger;
- line `348` permits compaction from that terminal description;
- lines `373–385` correctly bind challenge consumption to admission;
- lines `387–399` require restart reconciliation;
- lines `401–417` permit compaction only after a durable readable operation
  response, but use
  `requestLifetime + clockSkew + approvedRestoreWindow`;
- lines `415–417` mark restore window/capacity open but do not mark
  `requestLifetime` or `clockSkew` open;
- lines `898–913` contain no case for expiry while admitted target work is
  pending.

**Contradiction**

The state machine permits:

```text
issuedActive
  -> consumedActive(response pending)
  -> expiredConsumed
```

But `expiredConsumed` asserts that an operation response remains durable and has
no transition back to a pending state or forward to a newly recovered terminal
response. Therefore:

- if expiry occurs while target work is pending, the state name and invariant
  are false;
- if the transition is delayed until response commit, expiry is not represented
  by the stated transition table;
- restart cannot decide from the table whether to resume reconciliation, return
  historical response, or classify a terminal unavailable result;
- compaction eligibility can be evaluated against a state whose response never
  existed.

S2 A freezes maximum challenge lifetime but does not freeze the B packet's
`requestLifetime` or numeric `clockSkew`. The claim at S2 B line `656` that Lane
A supplies exact lifetime/skew bounds is therefore unsupported.

**Required correction**

Use either orthogonal persisted dimensions:

```text
consumption = unused | admittedPending | terminal
time = active | expired
compaction = retained | tombstoned
```

or explicit total states such as:

```text
consumedPendingActive
consumedPendingExpired
consumedTerminalActive
consumedTerminalExpired
compactedTombstone
```

Exact rules:

- expiry prevents a new admission but never abandons a committed admission;
- an admitted-pending operation remains restart-reconcilable after challenge
  expiry;
- target idempotency decides whether a mutation committed;
- exact stored response wins over reconstruction;
- an unavailable/indeterminate terminal record has its own explicit state and
  replay behavior;
- compaction is impossible until response/terminal evidence is durable and
  all numeric bounds are bound;
- request lifetime, clock skew, restore window, quota, and retention owners are
  explicit MBIs while absent.

Add crash/restart tests for every transition, especially expiry immediately
before and after target mutation and response commit.

**Disposition:** `OPEN P1 / S1 DIGEST DEFECT CLOSED BUT TOTAL MACHINE NOT CLOSED`.

### P1-S2-B-05 — deregistration and legacy plaintext removal do not satisfy exact token-erasure semantics

**Exact S2 B locations**

- lines `515–529` correctly forbid public/log/fixture/plaintext token leakage;
- lines `563–573` define `retired` as ciphertext retained for bounded rollback
  audit and `destroyed` as later removal;
- lines `575–580` say both revocation and deregistration merely remove the
  active reference and mark the sealed record `retired`;
- lines `582–597` logically clear legacy `pushToken`, read back null, and then
  permit readiness after migration succeeds;
- lines `603–626` use SQLite WAL and do not define secure page/WAL/backup
  disposal;
- lines `939–956` demand a no-raw-token backup test but define no storage
  artifact/quarantine/destruction plan that can make the assertion true.

**Contradicting S2 A deregister contract**

S2 A lines `813–907` require deregistration to:

- erase endpoint and APNS token material from active and revoked stores;
- retain only a minimal non-recoverable tombstone;
- prohibit recoverable token ciphertext in the tombstone;
- atomically bind endpoint/token erasure, tombstone, receipt, and exact response;
- distinguish `deregistered` and `already_deregistered`;
- prohibit old registration-ID resurrection.

Revocation is deliberately different. It disables delivery and removes active
token availability but is not privacy erasure.

**Two independent defects**

1. A `retired` sealed token still has nonce, ciphertext, tag, provider, and key
   version. It is recoverable while its key remains available. That may be
   acceptable under a reviewed revoke retention policy, but not under the S2 A
   deregister transition.
2. Updating a SQLite column to NULL proves only logical current-row state. It
   does not prove the old bytes are absent from:
   - WAL frames;
   - free database pages;
   - rollback/inspection copies;
   - filesystem snapshots;
   - existing backups;
   - retained migration artifacts.

The packet therefore cannot claim “no plaintext survives backups” from
post-commit row read-back.

**Required correction**

For revoke:

- remove delivery reference atomically;
- define whether sealed ciphertext is retained, for how long, under which
  Agreement/retention policy, and when it is destroyed;
- never permit delivery from retired state.

For deregister:

- destroy endpoint and token material in the same domain transaction as the
  minimal tombstone and response;
- reject a success receipt if recoverable ciphertext remains in active,
  retired, shadow, quarantine, or migration storage;
- persist no recoverable token material in the tombstone;
- make old registration ID terminal.

For legacy plaintext:

- quarantine readiness before any migration;
- inventory database, WAL, backup, snapshot, and restore artifacts without
  logging token content;
- freeze the storage-owner disposal/rotation/recreation procedure;
- treat pre-existing backups as sensitive until independently sanitized or
  destroyed;
- create a clean database through a reviewed copy of non-secret records if
  in-place SQLite erasure cannot be proven;
- keep production registration/provider readiness red until artifact-level
  evidence exists.

The approved AEAD/key provider, key version, recovery authority, backup
retention, and secure-disposal method remain genuine product/security MBIs.

**Disposition:** `OPEN P1 / PRIVACY AND CROSS-LANE RETENTION BLOCKER`.

## 7. P2 findings

### P2-S2-B-01 — producer fixture manifest consumption is not exact

**Exact S2 B locations**

- lines `764–777` name only four immutable v3 fixtures and say future Lane A
  fixtures will be copied or referenced after a green manifest;
- lines `737–762` contain no server consumer-manifest test/ledger path;
- lines `980–1002` do not name the S2 A producer manifest;
- lines `1029–1043` do not record fixture consumption as an MBI-04 element.

**Peer S2 A input**

S2 A lines `1136–1184` freeze:

- producer path
  `Tests/CellBaseTests/Fixtures/DeviceIngressFixtureManifest.v1.json`;
- schema `cellprotocol.device-ingress.fixture-manifest.v1`;
- v4 contract schema;
- entry path, byte count, file SHA-256, decoded SHA-256, role, and wire schema;
- consumer pinning of the manifest SHA-256.

S2 A lines `1186` onward freeze the v4 positive and negative inventory.

**Impact**

Lane B can say it will use a future green manifest, but a later source phase is
not bounded on:

- exact producer path;
- exact server copy/reference strategy;
- exact manifest hash input;
- exact v3/v4 entry coverage;
- detection of consumer-local regeneration;
- exact server evidence-ledger output.

This is an exact-byte and audit-completeness gap rather than independent
authority leakage, so it is P2.

**Required correction**

After S2 A crossed review:

- bind the exact producer manifest path and reviewed SHA-256;
- freeze one server consumer ledger/test path;
- assert byte count, file SHA, decoded SHA, role, schema, and lexicographic
  manifest order;
- assert v3 bytes remain immutable;
- assert all server-supported v4 operations and negative cases are covered;
- reject locally regenerated signed expected bytes;
- prove production composition rejects test-only keys.

**Disposition:** `OPEN P2 / EXACT-BYTE EVIDENCE INCOMPLETE`.

## 8. Reproduction and adjudication of every S1 Lane B finding

| S1 finding | Exact S2 correction | Independent adjudication | Residual |
|---|---|---|---|
| `P1-01` blanket `rw-s` | S2 B lines `164–194` freeze operation-derived access and status `r--s` | **NARROW S1 DEFECT CLOSED** | S2 A v4 six-operation matrix still not consumed; P1-S2-B-02 |
| `P1-02` status skips durable admission state | S2 B lines `422–479` commit/read back status admission, snapshot, audit, response; distinguish historical replay/fresh request | **CLOSED AS STATIC PLAN** | status selector/correlation/current-state interface still stale; P1-S2-B-02 |
| `P1-03` Resolver Cells/bootstrap incomplete | S2 B lines `196–298` freeze tuples, no-auto-create, registration/read-back, bootstrap order | **PARTIAL** | exact Agreement/Contract source/output input path and complete challenge Grant precheck absent; P1-S2-B-03 |
| `P1-04` challenge bytes-or-digest contradiction | S2 B lines `300–420` retain exact canonical challenge bytes and forbid digest-only replay | **NARROW S1 DEFECT CLOSED** | pending-at-expiry state is contradictory and bounds are incomplete; P1-S2-B-04 |
| `P2-01` token lifecycle/migration tests incomplete | S2 B lines `515–597`, `737–762`, `939–956` add sealed lifecycle, dedicated test paths, and enumerated negative cases | **TEST-INVENTORY DEFECT SUBSTANTIALLY CLOSED** | actual deregister erasure and legacy artifact disposal are unsafe/incomplete; P1-S2-B-05 |

The target's lines `967–977` overstate closure by calling all five
author-proposed closed. The correct crossed result is:

```text
S1 B P1-01: narrow defect closed
S1 B P1-02: closed as static plan
S1 B P1-03: partial
S1 B P1-04: narrow digest defect closed; replacement machine not total
S1 B P2-01: inventory closed; substantive token-erasure P1 remains
```

## 9. Per-operation RWXS and retention adjudication

### 9.1 Exact access

| Operation | S2 A required access | S2 B | Review |
|---|---|---|---|
| challenge issuance | no mutation Grant is consumed; complete prospective authorization still must be checked | Agreement-only precheck stated | **P1 incomplete Contract/Grant precheck** |
| `registerOrUpdateDevice` | `rw-s` | `register rw-s` | compatible in access only |
| `readRegistrationStatus` | `r--s` | `status r--s` | compatible in access |
| `revokeDevice` | `rw-s` | `revoke rw-s` | compatible in access only |
| `deregisterDevice` | `rw-s` | undefined/no access | **P1 missing** |
| `resolveTicket` | `rw-s` | `resolve rw-s` | compatible in access |
| `submitTicketResult` | `rw-s` | `submit rw-s` | compatible in access |

The formula at S2 B lines `166–174` is sound:

```text
request.requiredAccess
  == request.operation.requiredAccess
  == exact signed Grant permission
```

The server's own audit persistence does not add `w` to status requester access.
The packet correctly distinguishes protocol Storage permission from internal
server durability.

### 9.2 Retention

| Result/material | Correct retention boundary | S2 B result |
|---|---|---|
| status signed snapshot | requester may retain under `s`; server retains admission/audit/response; no registration mutation | supported |
| register receipt | exact response and mutation correlation retained; raw token not returned | partial; S2 correlation absent |
| revoke receipt | exact response retained; delivery disabled; token retention requires explicit bounded policy | partial |
| deregister receipt | only minimal tombstone/receipt; endpoint and recoverable token material erased | contradicted by shared `retired` token transition |
| resolve/submit response | exact target response retained; payload retention still follows content policy | conditionally supported |
| challenge | exact canonical challenge retained for replay until safe compaction | supported in bytes; state machine not total |

## 10. Resolver Cell registration, scope, persistency, and bootstrap

### 10.1 Supported static decisions

The packet successfully freezes for the two infrastructure Cells:

| Property | Authority catalog | Challenge issuer |
|---|---|---|
| endpoint | `cell:///DeviceIngressAuthorityCatalog` | `cell:///DeviceIngressChallengeIssuer` |
| name | `DeviceIngressAuthorityCatalog` | `DeviceIngressChallengeIssuer` |
| scope | `.scaffoldUnique` | `.scaffoldUnique` |
| persistency | `.persistant` | `.persistant` |
| lifecycle | `nil`, no TTL eviction | `nil`, no TTL eviction |
| owner source | independently green signed authority manifest | independently green signed authority manifest |
| missing owner | startup/readiness failure | startup/readiness failure |
| vault create | forbidden | forbidden |
| registration | concrete recovered instance only | concrete recovered instance only |
| read-back | endpoint/UUID/owner/scope/instance equality | endpoint/UUID/owner/scope/instance equality |

The bootstrap order at lines `253–282` is explicit and conservative:

- Identity attestation before authority import;
- manifest verification before owner lookup;
- persistent database before Cell recovery;
- authority catalog before Agreements;
- challenge issuer after Agreements;
- target definitions and stores before services;
- readiness last;
- full repetition on restart.

`Application.storage` is correctly non-authoritative.

### 10.2 Honest remaining authority inputs

The following cannot be derived and are correctly left missing:

- signed authority manifest bytes;
- manifest signer authority and continuity;
- owner/issuer descriptors and key control;
- actual persisted infrastructure Cell snapshots;
- target-owner Agreement/Contract bytes;
- revocation generations;
- issuer rotation chain.

No identity, owner, issuer, Agreement, Grant, or Cell UUID may be auto-created.

### 10.3 Residual defect

The packet freezes a config key for the authority manifest but no equivalent
exact signed Agreement/Contract input/output path. That is P1-S2-B-03 and keeps
S0 MBI-04 open.

## 11. Challenge, admission, status, replay, restart, and compaction

### 11.1 Challenge properties supported

The packet correctly requires:

- exact canonical challenge bytes stored before release;
- identical active intent returns exact stored bytes;
- replay never invokes signer;
- nonce/intent conflicts fail;
- consumption links exactly one admission/request;
- issuer rotation never rewrites historical bytes;
- restart hashes and reconciles non-compacted records;
- corruption makes the operation unavailable;
- compaction preserves uniqueness tombstones;
- quota pressure fails closed.

### 11.2 Challenge defect

`consumedActive(response pending) -> expiredConsumed(response durable)` is not a
total transition. P1-S2-B-04 applies.

### 11.3 Admission and status supported

The packet correctly states:

- every protected operation has durable admission before target execution;
- status writes admission/audit/replay state;
- status does not mutate registration/token/revocation state;
- exact replay returns exact historical bytes;
- fresh status requires a new challenge/request;
- disposable projections cannot sign or establish current truth;
- a committed target response must never be reconstructed or re-signed.

### 11.4 Status interface missing

The target lacks:

- authenticated `subject_current`;
- unique-current constraint and multiple-current result;
- deregistered tombstone lookup;
- exact registration mutation correlation;
- current/superseded/not-found/inconsistent dispositions.

Those omissions are P1-S2-B-02, not permission for a server-local invented API.

### 11.5 Callback ambiguity

The packet correctly avoids inventing an external admission-result route. It
retains internal exact response lookup and keeps ambiguous client recovery
unavailable.

S2 A explicitly leaves callback submit ambiguity as
`S2-A-MBI-04`. Therefore:

- registration ambiguity may later use the reviewed status correlation;
- callback submit ambiguity remains an exact upstream MBI;
- B must not generalize registration status into an unreviewed callback route.

## 12. Protected-token lifecycle, rotation, and migration

### 12.1 Supported static decisions

The packet correctly freezes:

- raw token only inside verified protected body;
- no token in authority, public hash, receipt, log, fixture, Cell value,
  analytics, or `UserDefaults`;
- sealed record with key provider/version, algorithm, nonce, ciphertext, tag,
  AAD hash, state, and durable sequence;
- AAD binding to registration/device/generation/topic/key/schema;
- key absence/wrong version/tag/AAD mismatch fails closed;
- shadow rewrap rather than in-place overwrite;
- quarantined record is never delivered;
- no legacy raw token becomes active authority;
- re-enrollment required for legacy registration;
- best-effort memory zeroization without overstated proof.

### 12.2 Genuine key-provider MBI

The packet correctly does not invent:

- AEAD suite;
- provider API;
- production key handle;
- key versions;
- recovery authority;
- key rotation record;
- key-provider operational availability.

These remain security/product inputs.

### 12.3 Unsupported erasure claim

Deregister and legacy artifact erasure are not closed, as detailed in
P1-S2-B-05.

The safe operational status is:

```text
SEALED TOKEN DESIGN: CONDITIONAL STATIC PROPOSAL
DEREGISTER TOKEN ERASURE: NOT GREEN
LEGACY ROW LOGICAL DEACTIVATION: PROPOSED
LEGACY SQLITE/WAL/BACKUP ERASURE: MISSING
KEY PROVIDER/AEAD/RECOVERY: MISSING
PRODUCTION TOKEN READINESS: NO-GO
```

## 13. Persistence, restart, read-back, rollback, and compaction

### 13.1 Static database plan

The packet freezes one candidate:

- selected Fluent SQLite dependency pins;
- absolute `SQLITE_DATABASE_PATH`;
- WAL;
- `synchronous=FULL`;
- foreign keys;
- trusted schema off;
- zero busy timeout/fail-closed contention;
- serialized write transaction;
- unique constraints;
- no in-memory fallback;
- post-commit read-back.

That is a technical implementation-bounding candidate, not operational
durability proof.

### 13.2 Operational proof still missing

Still required:

- exact deployed SQLite/runtime/kernel/filesystem combination;
- owner/mode values and enforcement;
- file, WAL, SHM, parent-directory flush behavior;
- process-kill tests at every transaction boundary;
- host crash/restart;
- backup/restore;
- read-back and reconciliation;
- storage pressure;
- corrupt/partial files;
- pool-wide PRAGMA attestation;
- secure backup lifecycle.

### 13.3 Rollback anchor

The packet correctly rejects:

- a counter in the same database;
- Git revision;
- current time;
- WAL presence;
- readiness flag.

The proposed external anchor fields are useful. The provider/API, persistence,
failure behavior, recovery authority, and disaster-recovery policy remain
genuine security/product MBIs.

### 13.4 Trusted time

Monotonic elapsed time plus an externally anchored maximum wall-time watermark
is a sound fail-closed direction. It remains conditional on:

- an approved external rollback anchor;
- exact request lifetime;
- exact clock-skew bound;
- exact forward/backward jump policy;
- restore-window policy.

`B-DEC-11` is therefore technically proposed, not independently closed.

### 13.5 Compaction

The non-destructive tombstone rule is sound in intent. Compaction remains
disabled while any of these are missing:

- terminal response/indeterminate-state semantics;
- request lifetime;
- clock skew;
- restore window;
- external anchor;
- capacity/pressure policy;
- token and Agreement retention policy.

## 14. `B-DEC-01...12` independent adjudication

“Technically resolved” below means only that invariant-derived behavior is
specific enough for a future correction. It never means source or runtime proof.

| ID | Packet claim | Independent result | Exact remaining input/fix |
|---|---|---|---|
| `B-DEC-01` issuer identity/rotation | partial; authority MBI | **SUPPORTED PARTIAL** | signed manifest, signer authority, old/new descriptors, generations, rotation chain, revocation and restart bytes |
| `B-DEC-02` Lane A wire | open on rejected S1 A | **STALE / OPEN / P1-S2-B-02** | crossed S2 A v4/v2 hash, six operations, status selector/correlation, deregister, framing, errors, fixtures |
| `B-DEC-03` database/settings | technically resolved | **CONDITIONAL STATIC CANDIDATE** | deployed engine/library/kernel/filesystem and crash/read-back evidence |
| `B-DEC-04` rollback anchor | open product/security MBI | **PROPERLY OPEN** | independent provider/API, anchor persistence, update atomicity, failure and recovery authority |
| `B-DEC-05` Agreement provisioning | partial; path said frozen | **NOT CLOSED / P1-S2-B-03** | exact canonical signed Agreement/Contract source and output paths/config/ledger, owner, hashes, revocation and restart behavior |
| `B-DEC-06` legacy raw tokens | technically resolved | **PARTIAL / P1-S2-B-05** | deactivation/re-enroll is sound; SQLite/WAL/backup artifact disposal and evidence missing |
| `B-DEC-07` encryption key handle | open product/security MBI | **PROPERLY OPEN** | AEAD/provider/key versions/rotation/recovery/availability and production rejection tests |
| `B-DEC-08` cross-Cell atomicity | same-target result plus outbox | **TECHNICALLY RESOLVED FOR ASYNC SEMANTICS** | any product requirement for synchronous remote result remains unavailable and must be separately specified |
| `B-DEC-09` audience projection | open on Lane A | **UPSTREAM STATIC VALUE EXISTS BUT UNREVIEWED** | after A review, bind exact `haven.digipomps.org`, origin/TLS/redirect/framing; do not derive authority from Host |
| `B-DEC-10` quota/expiry | operations MBI | **PROPERLY OPEN BUT INCOMPLETE LEDGER** | add request lifetime, clock skew, Agreement/token retention, global/per-subject capacity, restore window, pressure behavior |
| `B-DEC-11` trusted time | technically resolved | **CONDITIONAL / PARTIAL** | depends on B-DEC-04 plus exact skew/lifetime/restore bounds; no network-time trust root needed |
| `B-DEC-12` final integration | MBI-07 | **PROPERLY OPEN** | exact final commit/tree/diff/dependency/fixture/provenance manifest from development admin |

No row is delegated to Kjetil. Open authority/product decisions have owner
classes and exact required artifacts.

## 15. MBI-04 closure table

S0 defines MBI-04 as:

> production issuer, durable admission/replay backend, Resolver Cells, and
> Agreement source/output files.

| MBI-04 element | Static review result | Operational result |
|---|---|---|
| exact server topology | partial; coherent target/issuer/catalog shape | missing |
| no static root/auto-create | strong fail-closed proposal | actual signed authority input missing |
| per-operation RWXS | five rows correct; deregister absent | missing |
| v4/v2 wire and six routes | not consumed | missing |
| challenge issuer | exact-byte store proposed; full Contract/Grant precheck incomplete | missing |
| challenge state/replay | bytes issue closed; pending-expiry machine contradictory | missing |
| admission ledger | strong static proposal | backend/runtime proof missing |
| status admission/replay | static transaction corrected | selector/correlation/current recovery absent |
| revoke | partial static proposal | missing |
| deregister | absent and retention-contradictory | missing |
| callback target/outbox | technically bounded for asynchronous semantics | runtime/product proof missing |
| Resolver infrastructure Cells | tuple/order/read-back/no-create frozen | actual Cells/owner snapshots missing |
| target Cells | existing tuple named | adapters/transactions/runtime proof missing |
| Agreement/Contract source/output | source-code type named, canonical input/output path absent | bytes/revocation missing |
| protected token store | conditional sealed design | key provider and evidence missing |
| legacy token migration | logical deactivation proposed | secure artifact disposal missing |
| SQLite plan | exact conditional candidate | durability proof missing |
| rollback anchor | fields frozen | provider/API/recovery missing |
| trusted time | conditional algorithm | anchor/skew/lifetime proof missing |
| compaction/capacity | fail-closed direction | policy and total state missing |
| producer fixture consumption | generic future statement | exact manifest/hash/consumer ledger missing |

Independent result:

```text
MBI-04 STATIC PLAN: PARTIAL / NOT GREEN / CORRECTION REQUIRED
MBI-04 OPERATIONAL: MISSING / OPEN
```

## 16. Exact remaining MBI plan

### B-MBI-01 — signed authority manifest and issuer rotation

**Owner:** Identity/challenge-issuer authority owner crossed with CellScaffold
security/composition owner.

**Required exact input:**

- signed authority manifest canonical bytes and SHA-256;
- signer authority and continuity proof;
- authority catalog Cell UUID/owner/domain;
- challenge issuer Cell UUID/owner/domain;
- issuer public descriptor/fingerprint/generation;
- previous/new issuer rotation record;
- activation/expiry/revocation state;
- persisted-cell snapshot hashes;
- positive and negative test-only vectors.

**Status:** `STATIC CONSUMER PATH PARTIAL / AUTHORITY BYTES MISSING`.

### B-MBI-02 — signed Agreement/Contract catalog source/output

**Owner:** target Cell owner/Agreement authority owner crossed with Resolver and
CellScaffold security owners.

**Required exact input:**

- canonical input path/config key;
- canonical signed Agreement and Contract/Grant bytes;
- target Cell, owner, subject, domain, purpose, audience, operation,
  capability, access, conditions, validity, and revocation bindings;
- import manifest and file hashes;
- accepted/revoked/expired output ledger path;
- durable generations;
- restart/read-back/rollback rules;
- no-auto-create/no-static-fallback tests.

**Status:** `MISSING / BLOCKS MBI-04`.

### B-MBI-03 — reviewed S2 A producer interface

**Owner:** CellProtocol contract/security and transport owners, crossed by
CellScaffold and Binding consumers.

**Required exact input:**

- independently reviewed S2 A hash;
- v4/v2 schemas;
- six-operation table;
- exact response framing;
- subject-current status/correlation;
- revoke/deregister semantics;
- error sets and byte limits;
- producer fixture manifest bytes/SHA.

**Status:** `AUTHOR PACKET EXISTS / CROSSED REVIEW NOT CREDITED HERE`.

### B-MBI-04 — external rollback anchor and trusted time

**Owner:** CellScaffold storage/security/operations owner.

**Required exact input:**

- independent anchor provider/API;
- database/checkpoint/generation binding;
- atomic update protocol;
- outage and rollback behavior;
- backup/restore and disaster-recovery authority;
- exact clock skew, request lifetime, restore window;
- restart and clock-jump vectors.

**Status:** `PRODUCT/SECURITY MISSING`.

### B-MBI-05 — token key provider, retention, and secure legacy disposal

**Owner:** CellScaffold token-security/storage owner crossed with privacy and
backup/operations owners.

**Required exact input:**

- AEAD suite and provider identifier;
- production key handle and versions;
- rotation/rewrap/recovery rules;
- revoke retention duration and authority;
- deregister same-transaction destruction proof;
- database/WAL/free-page/backup/snapshot inventory;
- quarantine/disposal/recreation procedure;
- read-back, restart, restore, and no-plaintext evidence.

**Status:** `MISSING / TOKEN AND DEREGISTER READINESS RED`.

### B-MBI-06 — database/filesystem operational durability

**Owner:** CellScaffold storage/deployment owner.

**Required exact input:**

- deployed dependency/runtime/kernel/filesystem identity;
- absolute database path and owner/mode;
- PRAGMA read-back on every connection;
- file/WAL/SHM/parent flush behavior;
- crash, kill, restart, restore, corruption, pressure, and rollback evidence;
- evidence manifest and timestamp.

**Status:** `STATIC CANDIDATE EXISTS / OPERATIONAL PROOF MISSING`.

### B-MBI-07 — capacity, compaction, and retention policy

**Owner:** CellScaffold operations/privacy/storage owner.

**Required exact input:**

- global and per-subject capacity;
- challenge/request/response retention;
- Agreement/revocation retention;
- revoke token retention;
- restore window;
- compaction order;
- pressure and denial behavior;
- terminal/tombstone non-resurrection tests.

**Status:** `OPERATIONS PRODUCT MISSING / COMPACTION DISABLED`.

### B-MBI-08 — callback submit ambiguity

**Owner:** DeviceCallbackBridge protocol owner, followed by CellScaffold and
Binding consumer owners.

**Required exact input:**

- reviewed subject-bound callback result/status or admission-result operation;
- exact authority tuple;
- schemas, freshness, replay, privacy states;
- producer/server/client fixtures.

**Status:** `MISSING / DO NOT INVENT HTTP ROUTE`.

### B-MBI-09 — final integration output

**Owner:** development admin after every lane is independently green.

**Required exact input:**

- final commits/trees;
- exact diff and path ownership;
- dependency lock/compiler inputs;
- producer/consumer fixture manifest hashes;
- Identity provenance/cutover attestation;
- server/client evidence ledgers.

**Status:** `MBI-07 MISSING`.

## 17. Cross-lane A/B/C interface verdict

| Interface | S2 A | S2 B | S2 C | Result |
|---|---|---|---|---|
| transport inner decode | authenticated CellProtocol boundary only | read-only operation/path inspection before verified tuple | waits for decode owner | **contradiction; P1-S2-B-01** |
| protected carrier | v4 | stale S1 wrapper/interface | stale conditional wrapper | **not composed** |
| challenge carrier | v2 | S1 outline | v1 conditional intent | **not composed** |
| operations | six | five plus undefined deregister | deregister undefined | **not composed; P1-S2-B-02** |
| status access | `r--s` | `r--s` | `r--s` conditional | access compatible |
| status durable admission | required | required | required from server | compatible in principle |
| subject-current status | exact | intentionally absent | required upstream | **not composed** |
| registration correlation | exact four-part tuple | absent | required upstream | **not composed** |
| revoke | exact separate operation | partial | conditional | not green |
| deregister | exact terminal operation | absent; token retired | absent/conditional | **contradiction** |
| challenge exact replay | exact bytes | exact bytes | exact intent/challenge evidence | compatible in bytes |
| challenge expiry pending | producer requires replay/admission integrity | non-total state | expects durable adjudication | **not composed** |
| issuer rotation | exact MBI, no invented trust | exact MBI | exact MBI | correctly blocked |
| Agreement/Contract/Grant | complete tuple required | operation path complete, challenge precheck Agreement-only | no local fallback | **challenge gap** |
| success response framing | outer carrier referenced but not fully frozen | raw canonical bytes | raw canonical bytes | **upstream ambiguity** |
| producer manifest | exact path/schema/inventory | generic future manifest | waits for exact manifest | **P2 gap** |
| callback submit recovery | explicit A MBI | internal response only; no route | remains ambiguous | correctly blocked |

The peer S2 packets were authored independently and are not automatically a
merged contract. A crossed integration correction is required after each packet
has its own review.

## 18. Preserved S0 and production separation

Planning values remain:

```text
bundle identifier = org.digipomps.haven
APNS topic         = org.digipomps.haven
public origin      = https://haven.digipomps.org
audience proposal  = haven.digipomps.org
```

They grant no authority and prove no:

- Team ID;
- App ID capability;
- production provisioning profile;
- certificate;
- effective production entitlement;
- codesign authority;
- archive;
- APNS provider acceptance;
- token lifecycle;
- physical-device receipt;
- foreground/background delivery;
- restart/restore behavior.

Identity remains separate:

- `c700dbc…` is source provenance only;
- no Identity bytes were inspected or changed by this review;
- no owner, issuer, device identity, Agreement, Contract, or capability is
  created;
- owner/recovery/root continuity and cutover remain prerequisites;
- a manifest or service handle is not authority.

`MBI-06` remains:

`UNAUDITED / MISSING`

`MBI-07` remains:

`MISSING`

Associated Domains remains removed unless its separate exact AASA lane is green.

## 19. Claim adjudication

| Root claim | Independent result |
|---|---|
| exact S2 B bytes were reviewed | **SUPPORTED** |
| all immutable S0/S1 inputs are bound | **SUPPORTED** |
| every S1 B finding is statically closed | **CONTRADICTED/PARTIAL** |
| transport remains semantically neutral | **CONTRADICTED by pre-boundary inner inspection** |
| per-operation least privilege replaces blanket access | **SUPPORTED for listed rows** |
| status has durable admission and historical replay | **SUPPORTED as plan** |
| status/current recovery composes with S2 A/C | **CONTRADICTED** |
| Resolver infrastructure Cells have exact no-auto-create tuples | **SUPPORTED as plan** |
| Agreement source/output provisioning is frozen | **CONTRADICTED** |
| challenge exact bytes are retained | **SUPPORTED** |
| challenge persisted lifecycle is total | **CONTRADICTED** |
| raw token is excluded from public/log/receipt state | **SUPPORTED as requirement** |
| deregistration erases recoverable token material | **CONTRADICTED** |
| logical SQLite NULL proves legacy plaintext artifact erasure | **CONTRADICTED** |
| database/rollback/trusted-time behavior is proven | **UNSUPPORTED; static requirements only** |
| cross-Cell asynchronous outbox boundary is technically bounded | **SUPPORTED conditionally** |
| all owner/product inputs exist | **CONTRADICTED** |
| MBI-04 is green | **CONTRADICTED** |
| MBI-06 exists | **CONTRADICTED; unaudited/missing** |
| MBI-07 exists | **CONTRADICTED; missing** |
| source or next phase is authorized | **CONTRADICTED** |

## 20. Required correction packet

The next Lane B correction must, without touching source:

1. remove every pre-authenticated inner operation decode/inspection;
2. bind the independently reviewed S2 A producer artifact;
3. freeze v4/v2 carriers and one response framing;
4. include all six protected operations and routes;
5. add exact subject-current status and mutation-correlation server state;
6. add separate deregister service, transaction, receipt, readiness, errors,
   paths, and tests;
7. distinguish revoke retention from deregister destruction;
8. freeze exact Agreement/Contract source/output paths and bootstrap behavior;
9. require full Contract/Grant/condition precheck before challenge issuance;
10. replace the challenge state table with one total pending/terminal/expiry
    model;
11. add exact numeric/time/retention inputs to B-DEC-10/11 MBIs;
12. freeze safe legacy SQLite/WAL/backup quarantine/disposal behavior;
13. bind the producer fixture manifest path/hash and server consumer ledger;
14. update every S1 finding and B-DEC closure claim honestly;
15. preserve all current NO-GOs.

Actual authority/trust/product inputs must remain exact MBIs. The correction must
not invent:

- manifest signer;
- issuer or owner identity;
- Agreement/Contract bytes;
- rollback provider;
- AEAD/key provider;
- backup disposal authority;
- capacity/retention policy;
- response framing not frozen by the producer;
- callback submit recovery route;
- final integrated commit.

## 21. Final independent decision

```text
S2 LANE B EXACT-BYTE CROSSED REVIEW: COMPLETE
REVIEWED SHA-256: cd2cb731ce84d076044a20477ff1050ffc7765f054ea05bd0da69fcaf28d36d4
REVIEWED SHAPE: 1127 LINES / 52292 BYTES

P0: 0
P1: 5
P2: 1

S2 LANE B PACKET: NOT GREEN
S1 B P1/P2 CLOSURE: PARTIAL
B-DEC-01...12: ADJUDICATED; GENUINE MBIs PRESERVED
MBI-04 STATIC PLAN: PARTIAL / CORRECTION REQUIRED
MBI-04 OPERATIONAL: MISSING / OPEN
S2 A/B/C INTERFACE: NOT COMPOSED
IDENTITY CUTOVER: SEPARATE / NO-GO
MBI-06: UNAUDITED / MISSING
MBI-07: MISSING

PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

The only permissible continuation is another static Lane B correction, followed
by a new crossed independent exact-byte review. The correction should bind only
an independently reviewed producer interface; until then the affected routes
remain unavailable.

This review opens no source, Git, dependency, build, test, network, portal,
signing, device, APNS, secrets, Identity, staging, deployment, or integration
work.
