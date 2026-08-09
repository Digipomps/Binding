# APNS S6 Formal Proof Packet C — Durability, Client, and Vault — Independent Cross-Review

Status: **REVIEW-FROZEN / PACKET C NO-GO / RC6 PARTIAL / RC7 PARTIAL / RC8 STATIC CLOSED WITH EXTERNAL FORMAL_NO_GO / S6 INTEGRATION NO-GO / SOURCE NO-GO / MATERIAL NO-GO / PRODUCTION NO-GO**

Date: 2026-07-25 (Europe/Podgorica)

Scope: independent exact-byte cross-review of Packet C only. The reviewer
authored Packet A, not Packet C.

No Packet C byte, source, fixture, manifest, project, dependency, Git state,
build, test, network, portal, signing, device, APNS, secret, Identity, staging,
deployment, integration, material, or production state was changed.

## 1. Exact review gate

### 1.1 Reviewed Packet C bytes

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S6_Formal_Proof_Packet_C_Durability_Client_Vault_2026-07-25.md` | `f929ca08ddc8bcee1727019e9d53022ea99e9dca81d6d9f65aa608556852b225` | 1776 | 63436 |

The exact review output path was absent before authoring.

### 1.2 Packet C bound inputs

Packet C binds:

| Input | SHA-256 | Shape |
|---|---|---:|
| S5 author contract | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554/93787 |
| S5 Lane A review | `dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639` | 1038/36228 |
| S5 Lane B review | `0c98b68d5fdd847289e026173e376ac66dc33f70c7e9d8ebcf22e84573a1c601` | 859/36035 |
| S5 Lane C review | `36ff7ffc838f15abf99bf281c0a0f1ee584a1423d70bf26bdac3a38b2e3ebbc2` | 981/40219 |

All hashes and shapes reproduce. Packet C's reported terminal count for the
Lane A review does not reproduce; see `P2-S6-C-X-01`.

## 2. Review method and severity boundary

The review:

1. read all 1776 Packet C lines;
2. reproduced its exact SHA-256 and shape;
3. rechecked snapshot/watch/name→inode fencing under concurrent create,
   backup, export, rename, restore, and root replacement;
4. checked the provider capability and EMPTY-set behavior;
5. reconstructed every RC6 crash window and finite-completeness claim;
6. canonicalized all six journal-extension maxima independently;
7. checked every extension type, nullability row, enum, range, and digest
   binding;
8. reconstructed conflict namespace and resource-key stability;
9. checked cross-operation leases, vault transition, local trust gates, and
   append-only send/outcome/final markers;
10. reconstructed V/A/E/J/Prepared/marker generations edge-by-edge;
11. checked restored-copy behavior against the current external anchor head;
12. inspected resolve sink handoff and crash recovery;
13. counted and sequenced all fixture entries and checked negative
    applicability; and
14. preserved every EMPTY/UNAVAILABLE and material stop gate.

Severity:

- P0 requires an immediate exploitable or irreversible condition in the
  authorized state. No material implementation/action exists and all external
  proof sets are EMPTY.
- P1 blocks a byte-total, independently implementable formal contract.
- P2 is a bounded provenance, evidence, fixture, or precision defect that does
  not by itself open an authority/success gate.

## 3. Executive verdict

Packet C makes substantial and security-positive progress:

- RC6 has a strong fail-red snapshot/watch/name→inode algorithm and an honest
  provider/custody blocker;
- all six RC7 extension maxima reproduce exactly;
- conflict keys no longer depend on rolling checkpoint bytes;
- cross-operation conflict families and vault-transition fencing are
  conservative;
- send/outcome/finalization and resolve-delivery markers are append-only;
- the RC8 predecessor/successor graph is acyclic;
- restored local state must match the provider's current external head, not an
  old exact generation; and
- hardware, key, custody, rollback, store, and sink evidence remains EMPTY and
  UNAVAILABLE.

Two P1 defects prevent formal closure:

1. RC6 does not define the enumeration manifest whose digest is supposed to
   prove that the fenced snapshot equals the committed inventory; and
2. RC7 defines `JournalID` as both 47 and 48 bytes.

Three P2 defects remain:

1. the bound Lane A terminal count is misstated;
2. fixture applicability/coverage misses several formal negative boundaries;
   and
3. resolve recovery mentions replaying persisted request bytes that Packet C
   never persists and inherited rules keep volatile.

```text
P0: 0
P1: 2
P2: 3

PACKET C: NO-GO
RC6: PARTIAL / FORMAL_NO_GO
RC7: PARTIAL / FORMAL_NO_GO
RC8: CLOSED FOR STATIC DAG / EXTERNAL FORMAL_NO_GO
S6 INTEGRATION: NO-GO
SOURCE/MATERIAL: NO-GO
PRODUCTION: NO-GO
```

## 4. Preserved positive invariants

Packet C correctly preserves:

```text
operations = register, resolve, submit, status, revoke, deregister
token rotation = register/mutationMode=token_rotation
status access = r--s
mutation access = rw-s
transport = opaque, byte-preserving, semantically neutral
Resolver/Cell = authority/policy/mutation boundary
token = opaque 1...4096 HAVEN allocation bound only
token/token-hash disclosure = forbidden
local absence = never server truth
non-success = never success/current truth
server deregister + fresh status = before local erase
Identity domain = domain:device:notification-callback
```

RC2 remains unchanged:

- U1...U4 precedence;
- stored expiry outcome;
- exact replay bytes;
- no reconstruction/re-sign;
- no new replay sequence; and
- wrong-subject privacy equivalence.

No Packet C provider proof, lock, file, capability, checkpoint, marker, route,
TLS session, local key fingerprint, or current key possession becomes
DeviceIngress authority.

## 5. RC6 snapshot/watch/name→inode review

### 5.1 Capability gate

LegacyDiscoveryConsistencyCapabilityCore requires:

- snapshot support;
- event journal support;
- commit-fence support;
- descriptor/name/inode fencing;
- bounded roots, depth, entries, and event delta;
- positive generation and limited validity; and
- an independently accepted provider descriptor/signer.

False feature fields, unknown signer, expiry, or exceeded ceiling make
readiness unavailable.

Current exact state:

```text
accepted discovery consistency capabilities = EMPTY
accepted discovery fences = EMPTY
accepted discovery-custody proofs = EMPTY
accepted migration procedures = EMPTY
accepted deactivation procedures = EMPTY
accepted disposal procedures = EMPTY
accepted backup/restore proofs = EMPTY
legacy/provider delivery readiness = UNAVAILABLE
providerDeliveryAllowed = false
registerMutationAllowed = false
```

This is a correct fail-closed capability blocker. Signed booleans alone are
not operational evidence.

### 5.2 Concurrent create/backup/export fencing

The algorithm correctly requires:

1. pre-opened configured roots with no-follow;
2. one event journal armed before snapshot;
3. immutable cross-root snapshot generation;
4. descriptor-relative bounded traversal;
5. name metadata before open;
6. exact opened-descriptor metadata;
7. name metadata after inspection;
8. name→same inode/file identity before and after;
9. rejection of symlink, hard-link policy failure, FIFO, socket, device,
   unknown type, mode/owner/path/identity drift;
10. draining create/link/unlink/rename/restore/clone/metadata events;
11. re-snapshot to an event fixed point;
12. provider commit fence;
13. live root/name/identity revalidation;
14. atomic inventory/readiness commit and stable read-back;
15. provider acknowledgment; and
16. synchronous gate invalidation on any later covered event.

The crash/race table is fail-red for:

- watcher not armed;
- snapshot interrupted;
- rename/replace around open;
- hard link/FIFO;
- event overflow;
- root replacement;
- fence drift before commit;
- local stable-media/read-back failure;
- missing provider acknowledgment;
- event after acknowledgment; and
- restored material outside proven custody.

A new covered backup/export inside the accepted event/custody scope cannot be
silently omitted: it invalidates the gate and starts a new inventory
generation. A location outside the configured/proven custody scope invalidates
the custody proof; it does not count as complete discovery.

### 5.3 Atomic completeness is not byte-bound

The fence contains:

```text
enumerationManifestSHA256
rootObservations
inventoryGeneration
scopeGeneration
```

but Packet C defines no exact EnumerationManifest core:

- no schema name;
- no member order;
- no per-entry artifact identity/path/root association;
- no sortedness/duplicate rule;
- no per-root submanifest digest;
- no equation tying every observation count to manifest entries;
- no equation tying manifest entries to the exact inventory rows committed in
  the same transaction;
- no total count in the fence; and
- no byte equality/read-back relation between manifest, rows, and fence.

Consequently two implementations can hash different manifest shapes while
claiming the same formal algorithm. The fence digest proves only possession of
some unspecified bytes, not finite completeness of the committed inventory.

Two related validation gaps reinforce the same root:

- capability `maximumEntriesPerScope` is applied as
  `enumeratedEntryCount <= 1000000` on every root observation, but no sum over
  up to 64 roots is checked; an accepted fence can represent 64,000,000
  entries despite a per-scope ceiling of 1,000,000;
- the algorithm requires one ordered start watermark, while the schema checks
  only each `endEventSequence` against the sealed end; it does not require all
  `startEventSequence` values to equal the one scope watermark.

These are not supplied by an external provider artifact because the verifier
needs exact bytes/equations before it can validate that artifact.

This is `P1-S6-C-X-01`.

### 5.4 RC6 crash result

Every explicitly listed crash window is conservative. The unresolved
manifest/count/start-watermark relation means the successful commit branch is
not independently reproducible. Therefore:

```text
RC6 RACE/CRASH FAILURE BRANCHES: STATIC CLOSED
RC6 SUCCESSFUL FINITE-COMPLETENESS BRANCH: OPEN P1
RC6 EXTERNAL PROVIDER OPERATION: FORMAL_NO_GO / EMPTY
```

## 6. RC7 six extension schemas

### 6.1 Independent maxima reproduction

Using exact CJP-1 schema orders, maximum scalar values, and each valid
nullability row:

| Extension/row | Packet C value | Independent value | Result |
|---|---:|---:|---|
| register token rotation | 509 | 509 | reproduced |
| resolve | 455 | 455 | reproduced |
| submit | 462 | 462 | reproduced |
| status subject current | 259 | 259 | reproduced |
| status registration ID | 305 | 305 | reproduced |
| status admission ID | 237 | 237 | reproduced |
| revoke | 358 | 358 | reproduced |
| deregister | 362 | 362 | reproduced |

The decoded maximum is register at 509:

```text
B64(509) = 679
```

No mutually exclusive status/register row was combined to obtain a maximum.

### 6.2 Type/nullability review

Register v2 closes:

- first enrollment with no head;
- enrollment after empty-after-deregister;
- update;
- token rotation; and
- revoked reactivation.

It exactly controls head/registration/revocation generations, head epoch,
registration ID, mutation mode, token-delivery epoch, and sanitized token
observation ID. No raw token/hash is present.

Resolve/submit bind:

- exact content-contract digest;
- ticket and lineage;
- delivery ID or resolve admission ID.

Status closes:

- subject-current;
- registration-ID; and
- admission-ID selectors,

with exact correlation/registration/admission nullability.

Revoke/deregister require non-null current head/registration inputs.

Every extension digest is over exact decoded extension bytes. Wrong operation,
schema, digest, selector, mode, status kind, namespace, nullability, range, or
generation rejects before send.

The extension family itself is byte-total except for the OperationJournal
identifier defect in section 8.

## 7. RC7 stable conflict family and single flight

### 7.1 Stable namespace

VaultConflictNamespaceCore binds:

- fixed identity domain;
- non-exportable-key fingerprint digest;
- requester descriptor; and
- vault generation.

It deliberately excludes rolling checkpoint, expectation, journal,
transaction, marker, and rollback receipt digests. Therefore ordinary
checkpoint generation N→N+1 does not change family keys.

The namespace/fingerprint is not non-exportability proof. The accepted proof
set remains EMPTY.

### 7.2 Resource-family reconstruction

The exact families reproduce:

| Family | Conflicting operations |
|---|---|
| `K_registration` | register, revoke, deregister, status/registration |
| `K_ticket` | resolve, submit for same target/ticket lineage/ID |
| `K_admission` | protected operation recovery and status/admission |
| `K_domain_transition` | short-lived namespace/vault transition guard |

Required operation sets are complete:

```text
register/revoke/deregister
  -> K_registration + own K_admission

status/registration
  -> K_registration + own K_admission

resolve/submit
  -> K_ticket + own K_admission

status/admission
  -> target K_admission + own status-request K_admission
```

Family keys are sorted by raw bytes and duplicates collapse.

### 7.3 Cross-process behavior

Durable leases:

- have one unique namespace/conflict-key row;
- have no wall-clock expiry;
- cannot be stolen;
- permit a second process only to perform exact recovery for the existing
  transaction; and
- prevent a conflicting new send.

Vault transition:

- acquires the domain guard exclusively;
- requires an accepted old→new recovery relation;
- refuses every nonterminal lease;
- commits new namespace/genesis and external rollback anchor atomically; and
- only then permits new operations.

This prevents a vault-generation transition from splitting an ambiguous
operation. Concurrent non-conflicting preparations ultimately serialize on
the local journal-head transaction and external current-head CAS; a rejected
branch remains no-send/blocked rather than bypassing the lease.

The conflict-family structure is statically sound.

## 8. RC7 JournalID defect

Packet C defines:

```text
Base64url43 = exactly 43 bytes
JournalID = "jr1_" + Base64url43, exactly 48 bytes
```

Mechanical length:

```text
len("jr1_") = 4
4 + 43 = 47
```

It is impossible to satisfy both the construction and declared 48-byte type.
OperationJournalCore v3 therefore lacks one exact accepted `journalID`
encoding. This also makes independent OperationJournal byte limits and
fixtures ambiguous.

Required correction:

- choose one versioned prefix whose stated length plus Base64url43 equals the
  declared total, or change the total to 47;
- freeze the exact namespace and collision rule;
- recompute every OperationJournal contribution/ceiling;
- add exact 46/47/48 or 47/48/49 boundary vectors, according to the chosen
  type; and
- reject the superseded spelling/length.

This is `P1-S6-C-X-02`.

## 9. RC7 stable-media and append-only marker review

### 9.1 Prepare/anchor/send ordering

The prescribed ordering is conservative:

```text
verify existing vault/current external anchor/provider/authority
-> acquire transition guard and durable family leases
-> construct inherited request
-> construct E/J/Prepared/V successor from predecessors only
-> atomic stable-media commit/read-back
-> external checkpoint anchor CAS/read-back
-> append/read-back send_started_ambiguous
-> externally anchor send marker/read-back
-> transport send
-> verify outcome
-> append/anchor outcome_verified
-> operation-specific fresh status/finalization
-> append/anchor finalized
-> positive UI and lease release
```

No unanchored `send_permitted` state exists.

### 9.2 Immutable markers

OperationJournalCore is immutable after its digest enters Prepared and the
successor checkpoint. Later facts are separate immutable objects:

- send_started_ambiguous;
- outcome_verified; and
- finalized.

Every successor marker binds:

- transaction ID/sequence;
- Prepared transaction;
- successor checkpoint;
- preceding marker;
- preceding external anchor receipt; and
- exact outcome/finalization digests when required.

The external anchor CAS prevents same-generation different-marker forks from
authorizing a side effect or UI. Rewrite-after-checkpoint and
rewrite-after-anchor are explicitly rejected.

### 9.3 Crash windows

The table is fail-closed:

- pre-commit: predecessor remains authoritative, no send;
- torn/failed local transaction: provider-proven rollback/recovery, no send;
- local commit before checkpoint anchor: anchor recovery, no send;
- external checkpoint anchor before local receipt: current-head query and
  exact recovery;
- send marker not anchored: no send;
- send marker anchored before transport: status recovery, never “unsent”;
- transport ambiguity: matching admission/status only;
- outcome not anchored: no finalization/UI;
- final marker not anchored: no UI/lease release;
- wrong root/predecessor/namespace/current anchor: blocked unavailable;
- duplicate process: recovery only;
- vault transition with lease: reject; and
- missing store/anchor provider: readiness unavailable.

`local evidence absent` remains status/registration subject-current only.
Invalid/missing/locked/replaced vault or authority permits no action, including
status. Local evidence never opens mutation by itself.

### 9.4 Durability proof remains external

The durability capability demands atomic multi-record behavior,
cross-process guard, descriptor/name/inode fencing, full sync, parent sync,
power-loss recovery, restored-copy detection, bounded transaction size, and
rollback interop.

The signed capability fields are interface claims only:

```text
accepted local durability providers = EMPTY
Binding protected-operation readiness = UNAVAILABLE
```

No ordinary database commit, Data.write(.atomic), in-memory read-back, path,
timestamp, or self-signed capability becomes stable-media proof.

## 10. Resolve sink handoff

### 10.1 Positive construction

The idempotent sink contract binds:

- independently accepted capability and content policy;
- delivery ID;
- result digest;
- ticket and lineage;
- transaction sequence;
- provider generation; and
- accepted/exact-replay disposition.

Provider uniqueness:

```text
UNIQUE(providerDescriptorSHA256, deliveryID)
```

Same delivery ID and exact tuple returns the exact stored receipt. Any mismatch
rejects without storing.

Resolve delivery uses immutable, externally anchored:

```text
prepared
-> sink_receipt_verified
-> finalized
```

The sink is not invoked before the exact prepared marker is externally
anchored. Delivered truth is not published before the finalized delivery
marker is externally anchored.

Crash after sink acceptance retries the same delivery ID and requires exact
receipt replay. Wrong digest/ID/lineage, missing provider, provider rollback,
unanchored marker, or missing policy blocks.

Current state remains honest:

```text
accepted idempotent sink capabilities = EMPTY
accepted idempotent sink receipts = EMPTY
resolve delivery readiness = UNAVAILABLE
delivered-once PASS = NONE
```

### 10.2 Undefined persisted-request recovery alternative

Packet C section 9 states that after restart:

```text
body/request bytes are never reconstructed from digests
only exact status recovery is allowed
```

Its prepare transaction stores E/J/Prepared/V, leases, sequence, and digests;
OperationJournalCore stores no body, request, or payload bytes. This preserves
the inherited volatile-only treatment of exact operation body/request bytes.

Section 10 nevertheless says recovery may replay “the already stored exact
resolve request bytes.” No Packet C object, transaction field, storage rule,
protection policy, byte limit, deletion rule, or crash test stores those bytes.

The safe branch is already available:

```text
authenticated status/admission query
-> byte-identical server SignedOutcome replay
-> reverify result digest
-> same delivery-ID sink retry
```

If status cannot recover exact outcome/payload, the packet correctly requires
`blocked_unavailable`.

Required precision correction: remove the undefined request-replay branch, or
define a separately reviewed protected request-byte store without weakening
privacy/volatile-only rules. No such store should be inferred here.

Because the exact status-query/block branch remains total and safe, this is
`P2-S6-C-X-03`, not a P1.

## 11. RC8 edge-by-edge DAG reconstruction

### 11.1 Genesis

Construction:

```text
V_0
-> A_0 anchors exact V_0 envelope
```

V_0 contains:

- no applied Prepared digest;
- generation 1;
- empty journal root;
- null latest expectation;
- null predecessor checkpoint; and
- null predecessor anchor.

A_0 has generation 1, exact V_0 artifact digest/kind, checkpoint generation 1,
and null previous anchor.

No genesis cycle exists.

### 11.2 Operation successor

For accepted current predecessor `V_n/A_n`:

```text
V_n + A_n
  -> E_t
  -> extension_t
  -> J_t
  -> Prepared_t
  -> V_(n+1)
  -> A_checkpoint
```

Edges reproduce:

```text
E_t
  -> SHA(V_n), SHA(A_n)

J_t
  -> SHA(E_t), SHA(V_n), SHA(A_n), extension digest

Prepared_t
  -> SHA(E_t), SHA(J_t), SHA(V_n), SHA(A_n),
     predecessor root, resulting root

V_(n+1)
  -> SHA(Prepared_t), SHA(V_n), SHA(A_n),
     resulting root, SHA(E_t)

A_checkpoint
  -> SHA(V_(n+1)), SHA(A_n)
```

Every edge points to already materialized bytes. V_(n+1) contains no
A_checkpoint digest.

### 11.3 Send/outcome/final chain

```text
A_checkpoint
  -> Marker_send
  -> A_send
  -> Marker_outcome
  -> A_outcome
  -> Marker_final
  -> A_final
```

Edges:

```text
Marker_send
  -> Prepared_t, V_(n+1), A_checkpoint

A_send
  -> Marker_send, A_checkpoint

Marker_outcome
  -> Marker_send, A_send, verified outcome digest

A_outcome
  -> Marker_outcome, A_send

Marker_final
  -> Marker_outcome, A_outcome,
     verified outcome and finalization artifact

A_final
  -> Marker_final, A_outcome
```

No marker contains its own anchor receipt. No anchor contains a future marker.
Every external anchor generation is a strict successor.

### 11.4 Journal-root direction

```text
JournalRoot_0 = domain-separated empty root
JournalLeaf_t = H(domain || t || operationJournalDigest)
JournalRoot_t = H(domain || JournalRoot_(t-1) || JournalLeaf_t)
```

Strict predecessor sequence+1 is required. Duplicate, gap, overflow, wrong
predecessor root, or alternate journal bytes makes readiness unavailable.

The journal/checkpoint DAG has no S5 same-generation E↔V or J↔V cycle.

### 11.5 Resolve-delivery continuation

After the latest accepted operation anchor:

```text
ResolveMarker_prepared
-> external anchor
-> sink call/exact replay
-> ResolveMarker_sink_receipt_verified
-> external anchor
-> ResolveMarker_finalized
-> external anchor
-> delivered truth
```

Each marker references only the preceding marker and anchor. The sink receipt
cannot reference a later local marker.

RC8 DAG verdict: **STATIC ACYCLIC**.

## 12. Restored-copy and current external head

RollbackAnchorProviderCapability requires:

- atomic compare-and-set;
- monotonic generation;
- current-head query;
- exact-generation query;
- tamper-resistant external state; and
- independently proven provider behavior.

Before accepting any local checkpoint, marker, lease recovery, side effect, or
positive UI, the client must query the provider's current head and require
exact equality of:

- anchor generation and exact receipt digest/bytes;
- namespace;
- anchored artifact kind and digest; and
- checkpoint generation.

An old exact-generation query is expressly insufficient. A provider current
head whose bytes are absent locally is `blocked_unavailable`; the client does
not choose the largest local generation.

Therefore:

- restored local state behind provider current head cannot send;
- copied local state with an old exact receipt cannot send;
- a copied ID, boolean, fingerprint, MAC key, or current local key cannot
  satisfy current-head equality;
- rollback proof is distinct from copy/custody proof; and
- non-exportability alone proves neither.

Current accepted sets:

```text
accepted rollback-anchor providers/receipts = EMPTY
accepted non-exportable-key proofs = EMPTY
accepted copy-resistance proofs = EMPTY
accepted custody/recovery proofs = EMPTY
accepted hardware attestations = EMPTY
accepted stable-store proofs = EMPTY
accepted sink proofs = EMPTY

hardware PASS = NONE
copy-resistance PASS = NONE
rollback-resistance PASS = NONE
all affected readiness = UNAVAILABLE
```

RC8 does not falsely turn its fillable schema into an external PASS.

## 13. Fixture/applicability review

### 13.1 Mechanical ledger result

Packet C contains:

```text
52 fixture rows
52 unique IDs
exact ordered sequence S6C001...S6C052
no missing ID
no duplicate ID
```

The applicability core is typed:

- required rows carry exact expected decision, test ID, and repo-qualified
  test path;
- not-applicable rows carry one closed reason and null test fields;
- A/B/C entries are explicit; and
- there is no boolean consumer toggle.

Positive routing is mostly correct:

- RC6 server discovery: A and B required, C server-only N/A;
- RC7/RC8 client-local: A and C required, B client-local N/A;
- external provider absence is exercised as unavailable rather than PASS.

### 13.2 Negative applicability error

S6C009 is:

```text
legacy/missing-provider-capability.json
```

Its C consumer is marked `N/A-E`, meaning
`external_premise_unavailable`. But C is not a consumer because the fixture is
server-only legacy discovery. The precise consumer non-applicability reason is
`N/A-B = server_only_legacy_discovery`.

External provider absence is the fixture's expected server decision, not the
reason the Binding client does not consume a server-only fixture.

### 13.3 Missing adversarial rows

The exact ledger lacks negative fixtures for:

- enumeration manifest entry omitted/extra/duplicate;
- observation count not equal to exact manifest rows;
- committed inventory row not equal to manifest entry;
- sum across roots exceeding `maximumEntriesPerScope`;
- unequal scope start watermarks;
- the 47/48-byte JournalID contradiction;
- restored local copy behind provider current head;
- old exact-generation query without current-head equality; and
- undefined persisted resolve-request replay.

The first group is downstream evidence for `P1-S6-C-X-01`; JournalID is
downstream evidence for `P1-S6-C-X-02`. The restore/current-head omissions are
especially important because that negative is central to RC8's positive
closure.

This applicability/coverage cluster is `P2-S6-C-X-02`.

## 14. Findings

### P0

No P0 was found. Packet C performed no material action and keeps all external
provider/key/hardware/custody/rollback/store/sink sets EMPTY.

### P1

#### P1-S6-C-X-01 — RC6 fence digest does not byte-bind the fenced enumeration to committed inventory

Locations:

- Packet C sections 5.3–5.5;
- LegacyDiscoveryFenceCore;
- the atomic commit step; and
- S6C001...S6C009.

`enumerationManifestSHA256` has no canonical manifest schema or equation tying
root observations/counts to the exact inventory rows committed with
readiness. The per-scope entry ceiling is not summed across roots and the
single start-watermark equality is not validated.

This makes the successful completeness branch non-reproducible across
producer/server implementations.

Required correction:

- define exact `LegacyEnumerationManifestCore` and entry core;
- bind scope/root/snapshot/watermark/artifact identity and inventory row digest
  for every entry;
- sort, deduplicate, and count per root and globally;
- require global count `<= maximumEntriesPerScope`;
- require one exact start and end watermark across the scope;
- hash exact manifest bytes into the fence;
- atomically compare exact manifest entries to committed rows/read-back; and
- add omission/extra/duplicate/count/root/watermark/crash fixtures.

External provider sets remain EMPTY and prevent operational use, but do not
close the static contract.

Verdict: **OPEN P1**.

#### P1-S6-C-X-02 — JournalID construction and declared length are inconsistent

Locations:

- Packet C section 4 common types; and
- OperationJournalCore v3 section 8.2.

`"jr1_"` is four bytes. Four plus Base64url43 is 47, not the declared 48.
There is no exact JournalID satisfying both rules.

Required correction:

- freeze one exact prefix/length/namespace;
- define collision/uniqueness;
- recompute OperationJournal length bounds; and
- add accepted lower/max and rejected alternate spelling/length fixtures.

Verdict: **OPEN P1**.

### P2

#### P2-S6-C-X-01 — Packet C misstates the terminal Lane A review count

Location: Packet C section 1.2.

The exact bound Lane A review at
`dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639`
reports `0/4/2`, not Packet C's `0/5/2`.

The SHA and shape are correct, so this is provenance/count metadata rather
than a different input.

Verdict: **OPEN P2**.

#### P2-S6-C-X-02 — Fixture applicability and negative coverage are incomplete

Locations:

- Packet C section 12;
- S6C009; and
- missing formal negatives listed in section 13.3 above.

The 52 IDs are complete, ordered, and unique. S6C009 uses the wrong
non-applicability reason for C, and the ledger lacks several exact negatives
needed to prove RC6, RC7 JournalID, and restored-copy current-head behavior.

Verdict: **OPEN P2**.

#### P2-S6-C-X-03 — Resolve recovery references request bytes absent from the durability graph

Locations:

- Packet C sections 9.2 and 10.3.

The durable graph persists digests/markers, not exact body/request bytes, and
post-restart rules permit status recovery. The later “already stored exact
resolve request bytes” branch has no storage object or policy.

The status/admission read-back plus exact outcome replay/block path is safe and
total, so the undefined alternative is bounded imprecision rather than an
authority bypass.

Verdict: **OPEN P2**.

## 15. RC6/RC7/RC8 disposition

| Root | Static result | External/operational result | Verdict |
|---|---|---|---|
| RC6 legacy inventory/readiness | race/crash failure branches and provider fail-red gate are strong; successful finite completeness lacks canonical manifest/count/row binding | all providers/custody/procedures EMPTY | **PARTIAL / FORMAL_NO_GO** |
| RC7 journal/reducer/sink | six extensions, maxima, conflict families, leases, append-only markers, trust gate, and sink ordering largely close; JournalID impossible and request-replay wording imprecise | durability and sink providers EMPTY | **PARTIAL / FORMAL_NO_GO** |
| RC8 vault continuity | predecessor/successor checkpoint-anchor-marker graph is acyclic; current external head is mandatory for restore | key/copy/rollback/custody/hardware/store/sink sets EMPTY | **CLOSED FOR STATIC DAG / EXTERNAL FORMAL_NO_GO** |

No row is a runtime, hardware, Identity, authority, source, or production
PASS.

## 16. External premise classification

The following remain exactly EMPTY:

```text
legacy discovery providers/fences/custody proofs
migration/deactivation/disposal/backup procedures
local durability providers
non-exportable key proofs
copy-resistance proofs
rollback-anchor providers/receipts
custody/recovery proofs
hardware attestations
idempotent sink capabilities/receipts
```

Therefore:

```text
legacy/provider delivery readiness = UNAVAILABLE
Binding protected-operation readiness = UNAVAILABLE
resolve delivery readiness = UNAVAILABLE
hardware PASS = NONE
copy-resistance PASS = NONE
rollback-resistance PASS = NONE
delivered-once PASS = NONE
```

No schema, path, boolean, UUID, local key, fingerprint, MAC, file, row,
timestamp, test signer, or code signature fills an external set.

## 17. Preserved out-of-scope blockers

Packet C and this review do not close:

- RC1 pre-challenge expectation;
- RC3 authority/catalog/consent;
- RC4 privacy retention;
- RC5 signed semantic maxima;
- Identity cutover;
- transport framing;
- Apple profile/signing/entitlement/archive evidence;
- integrated repo/dependency/compiler-input/fixture/artifact evidence; or
- any material phase.

```text
MBI-PRIVACY-RETENTION-01 = OPEN / KJETIL
MBI-TRANSPORT-FRAMING-01 = MISSING
MBI-06 = MISSING / UNAUDITED
MBI-07 = MISSING
```

## 18. Mechanical finding-count reconciliation

Finding heading patterns:

```text
^#### P1-S6-C-X-
^#### P2-S6-C-X-
```

Expected counts:

```text
P1 headings = 2
P2 headings = 3
```

Summary reconciliation:

```text
Executive verdict = 0/2/3
Findings section   = 0/2/3
Final decision     = 0/2/3
```

## 19. Preserved stop gates

```text
PACKET C: NO-GO
PLAN: NO-GO
NEXT PHASE: CLOSED / NO-GO
S6 INTEGRATION: CLOSED / NO-GO
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
PRODUCTION: CLOSED / NO-GO
```

## 20. Final independent decision

```text
REVIEW: FROZEN
REVIEWER: DISTINCT FROM PACKET C AUTHOR
REVIEWED SHA-256:
  f929ca08ddc8bcee1727019e9d53022ea99e9dca81d6d9f65aa608556852b225
REVIEWED SHAPE:
  1776 lines / 63436 bytes

P0: 0
P1: 2
P2: 3

RC6: PARTIAL / FORMAL_NO_GO
RC7: PARTIAL / FORMAL_NO_GO
RC8: CLOSED FOR STATIC DAG / EXTERNAL FORMAL_NO_GO

EXTENSION MAXIMA:
  509 / 455 / 462 / 259 / 305 / 237 / 358 / 362
  independently reproduced

FIXTURE ROWS:
  52 / unique / ordered S6C001...S6C052

RESTORED COPY:
  current external anchor-head equality mandatory
  old exact-generation query insufficient

ALL EXTERNAL PROVIDER/HARDWARE/KEY/CUSTODY/ROLLBACK/STORE/SINK SETS:
  EMPTY
ALL AFFECTED OPERATIONAL READINESS:
  UNAVAILABLE

S6 INTEGRATION: NO-GO
SOURCE/MATERIAL AUTHORIZATION: NONE
PRODUCTION: NO-GO
```

This review grants no next-phase authority.
