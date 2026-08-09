# APNS S6 Formal Proof Packet C — Durability, Client, and Vault

Status: **AUTHOR-FROZEN / INDEPENDENT REVIEW REQUIRED / PACKET C FORMAL NO-GO / S6 INTEGRATION NO-GO / SOURCE NO-GO / MATERIAL NO-GO / PRODUCTION NO-GO**

Date: `2026-07-25`  
Packet: `C`  
Exclusive scope: `S5-RC-06`, `S5-RC-07`, and `S5-RC-08`  
Sole owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_S6_Formal_Proof_Packet_C_Durability_Client_Vault_2026-07-25.md`

The sole output path was re-attested absent before this file was created. This
packet changes no prior document, source, fixture, manifest, project,
dependency, Git state, build, test, network, portal, signing, device, APNS,
Identity, staging, deployment, integration, material, or production state.

This is a formal document-only candidate. Author self-classification grants no
closure credit. A distinct independent exact-byte reviewer is required before
an integrator may consume it.

## 1. Exact immutable inputs

### 1.1 S5 author artifact

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| `Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md` | `0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6` | 2554 | 93787 |

### 1.2 Three terminal S5 reviews

| Lane | Artifact | SHA-256 | Lines | Bytes | Terminal P0/P1/P2 | Terminal verdict |
|---|---|---|---:|---:|---:|---|
| A | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_CellProtocol_Conformance_Independent_Review_2026-07-24.md` | `dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639` | 1038 | 36228 | `0/5/2` | NO-GO |
| B | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_CellScaffold_Server_Conformance_Independent_Review_2026-07-24.md` | `0c98b68d5fdd847289e026173e376ac66dc33f70c7e9d8ebcf22e84573a1c601` | 859 | 36035 | `0/5/2` | NO-GO |
| C | `Documentation/APNS_S5_Normative_Composition_Contract_Correction_Binding_Client_Conformance_Independent_Review_2026-07-24.md` | `36ff7ffc838f15abf99bf281c0a0f1ee584a1423d70bf26bdac3a38b2e3ebbc2` | 981 | 40219 | `0/4/1` | NO-GO |

All four inputs remain immutable. This packet does not rewrite or silently
relax them.

## 2. Scope boundary and precedence

If independently accepted later, Packet C may replace only conflicting S5
clauses in:

- section 11, legacy discovery consistency and readiness for RC6;
- section 12, Binding journal extensions, conflict keys, stable-media
  transaction, reducer gate, and resolve handoff for RC7; and
- section 13, Binding vault continuity dependency direction for RC8.

It does not change:

- RC1 outcome/pre-challenge expectation;
- RC2 challenge replay/expiry/compaction;
- RC3 authority/catalog/consent;
- RC4 current subject head or Kjetil's retention decision;
- RC5 signed-wire maxima;
- wire operation names, body schemas, target Cells, access, or authority;
- transport framing;
- Apple signing/profile/entitlement inputs; or
- integrated output.

RC2 remains byte-for-byte governed by S5:

```text
U1...U4 precedence
stored expiry outcome
exact stored replay bytes
no response reconstruction
no re-signing
no new sequence on replay
wrong-subject privacy equivalence
```

Packet C cannot turn a challenge, route, TLS session, local file, provider
capability, lock, checkpoint, or rollback receipt into protocol authority.

## 3. Preserved positive invariants

The following remain mandatory:

- exactly six operations:
  `register`, `resolve`, `submit`, `status`, `revoke`, `deregister`;
- token rotation is only `register/mutationMode=token_rotation`;
- status is `r--s`; mutations are `rw-s`;
- Resolver/Cell enforcement owns Identity, Agreement, Contract, Grant,
  Conditions, target selection, and mutation;
- transport is opaque, byte-preserving, semantically neutral, and grants no
  authority;
- APNS token bytes are opaque, non-empty, and at most 4096 bytes as a HAVEN
  allocation limit only;
- neither raw token nor token hash may enter documents, fixtures, manifests,
  evidence, logs, analytics, diagnostics, crash reports, exports, UI, or
  accessibility;
- local absence never proves server absence, revocation, or deregistration;
- authenticated error or terminal evidence never proves success;
- server-authoritative deregistration and fresh signed status precede local
  token/binding erasure;
- Identity remains `domain:device:notification-callback`;
- no local UUID, boolean, key fingerprint, path, or copied MAC substitutes for
  non-exportability, custody, copy resistance, rollback resistance, or
  authority.

Exact planning literals remain non-evidentiary:

```text
purpose     = purpose://access.audit.privacy/device-notification-callback
audience    = haven.digipomps.org
origin      = https://haven.digipomps.org
bundle      = org.digipomps.haven
APNS topic  = org.digipomps.haven
environment = production
```

## 4. Common formal types

All Packet C objects use S5 CJP-1 canonical JSON and its non-escaping ASCII
profile.

```text
DigestHex       = exactly 64 lowercase [0-9a-f]
Base64url43     = exactly 43 [A-Za-z0-9_-]
AdmissionID     = "adm1_" + Base64url43, exactly 48 bytes
RegistrationID  = "reg1_" + Base64url43, exactly 48 bytes
DeliveryID      = "dly1_" + Base64url43, exactly 48 bytes
JournalID       = "jr1_"  + Base64url43, exactly 48 bytes
ExpectationID   = "exp1_" + Base64url43, exactly 48 bytes
TransactionID   = "ltx1_" + Base64url43, exactly 48 bytes
TokenObservationID = "tokobs1_" + Base64url43, exactly 51 bytes
TicketID        = TokenASCII, 1...128 bytes
TargetCellID    = PathTokenASCII, 1...128 bytes
UInt64          = canonical unsigned decimal, 0...18446744073709551615
PositiveUInt64  = canonical unsigned decimal, 1...18446744073709551615
UInt32          = canonical unsigned decimal, 0...4294967295
UInt16          = canonical unsigned decimal, 0...65535
```

No leading zero is accepted except the scalar zero itself. Integer overflow
rejects before allocation or state change. Nullable members are always present
as exact JSON `null`.

### 4.1 Packet-local provider proof envelope

Provider capability and receipt objects never use the DeviceIngress wire
outcome union. They use this local evidence envelope:

Schema:
`haven.apns.s6.packet-c.provider-proof-envelope.v1`

Exact member order:

1. `algorithm`
2. `artifactKind`
3. `core`
4. `coreSHA256`
5. `keyID`
6. `schema`
7. `signature`
8. `signerDescriptorSHA256`

`core` is Base64url of exact CJP-1 core bytes. `signature` is Base64url of
1...1024 opaque signature bytes. Protection input is:

```text
algorithm = TokenASCII, 1...64, and independently allowlisted
artifactKind = legacy_discovery_consistency_capability
             | legacy_discovery_fence
             | binding_local_durability_provider_capability
             | binding_rollback_anchor_provider_capability
             | binding_rollback_anchor_receipt
             | binding_idempotent_sink_capability
             | binding_idempotent_sink_receipt
keyID = TokenASCII, 1...128, and independently allowlisted for the signer
signerDescriptorSHA256 = DigestHex
```

```text
LP(UTF8("HAVEN-APNS-S6-PACKET-C-PROVIDER-PROOF-V1"))
|| LP(UTF8(artifactKind))
|| LP(exact core bytes)
```

```text
providerProofArtifactSHA256 =
  lowercaseHex(SHA256(exact ProviderProofEnvelope bytes))
```

An envelope is accepted only when its signer/algorithm/key/generation is in an
independently frozen provider-authority set. No such set exists in the frozen
inputs:

```text
accepted provider signers = EMPTY
accepted provider proof artifacts = EMPTY
```

The envelope schema is a fillable interface, not evidence that a provider
exists.

## 5. RC6 — atomic finite legacy discovery

### 5.1 Protected artifact scope

Discovery covers every configured current or historical location capable of
containing legacy plaintext or recoverable token-bearing material:

```text
database
wal
shm
rollback_journal
free_page_risk
backup
snapshot
export
restored_copy
unknown
```

The discovery process never reads, hashes, displays, logs, or exports token
values. Artifact identity remains metadata-only.

### 5.2 LegacyDiscoveryConsistencyCapabilityCore

Schema:
`cellscaffold.device-ingress.legacy-discovery-consistency-capability-core.v1`

Exact member order:

1. `capabilityGeneration`
2. `commitFenceSupported`
3. `descriptorNameInodeFenceSupported`
4. `eventJournalSupported`
5. `expiresAtMilliseconds`
6. `issuedAtMilliseconds`
7. `maximumDepth`
8. `maximumEntriesPerScope`
9. `maximumEventDelta`
10. `maximumRoots`
11. `providerDescriptorSHA256`
12. `schema`
13. `snapshotSupported`

Exact accepted values:

```text
capabilityGeneration                 = PositiveUInt64
commitFenceSupported                 = true
descriptorNameInodeFenceSupported    = true
eventJournalSupported                = true
snapshotSupported                    = true
0 < expiresAtMilliseconds - issuedAtMilliseconds <= 86400000
maximumDepth                         = 1...64
maximumEntriesPerScope               = 1...1000000
maximumEventDelta                    = 1...1000000
maximumRoots                         = 1...64
providerDescriptorSHA256             = DigestHex
```

Artifact kind:
`legacy_discovery_consistency_capability`

Any false feature, larger maximum, expiry, unknown signer, or missing
capability makes legacy readiness unavailable. The numeric ceilings are HAVEN
resource allocations, not claims about an operating system.

### 5.3 LegacyRootFenceObservationCore

Schema:
`cellscaffold.device-ingress.legacy-root-fence-observation-core.v1`

Exact member order:

1. `discoveryRootID`
2. `endEventSequence`
3. `enumeratedEntryCount`
4. `rootBirthTimeNanoseconds`
5. `rootFileIdentity`
6. `rootMetadataGeneration`
7. `rootRelativeNameSHA256`
8. `snapshotGeneration`
9. `startEventSequence`
10. `volumeIdentity`
11. `schema`

Types:

```text
discoveryRootID          = TokenASCII, 1...128
endEventSequence         = UInt64
enumeratedEntryCount     = UInt64, 0...1000000
rootBirthTimeNanoseconds = UInt64
rootFileIdentity         = UInt64
rootMetadataGeneration   = UInt64
rootRelativeNameSHA256   = DigestHex
snapshotGeneration       = PositiveUInt64
startEventSequence       = UInt64
volumeIdentity           = TokenASCII, 1...128
```

Required relation:

```text
endEventSequence >= startEventSequence
endEventSequence - startEventSequence <= capability.maximumEventDelta
```

Root observations are sorted by raw UTF-8 `discoveryRootID`, duplicate-free,
and their count is `1...capability.maximumRoots`.

### 5.4 LegacyDiscoveryFenceCore

Schema:
`cellscaffold.device-ingress.legacy-discovery-fence-core.v1`

Exact member order:

1. `capabilityArtifactSHA256`
2. `completedAtMilliseconds`
3. `enumerationManifestSHA256`
4. `inventoryGeneration`
5. `rootObservations`
6. `scopeGeneration`
7. `snapshotID`
8. `startedAtMilliseconds`
9. `watchOverflow`
10. `watchSealedEventSequence`

`rootObservations` is an array of Base64url exact
`LegacyRootFenceObservationCore` bytes. It is sorted and duplicate-free as
above.

```text
capabilityArtifactSHA256 = DigestHex
enumerationManifestSHA256 = DigestHex
inventoryGeneration = PositiveUInt64
scopeGeneration = PositiveUInt64
snapshotID = "lsn1_" + Base64url43, exactly 48 bytes
watchOverflow = false
watchSealedEventSequence = UInt64
startedAtMilliseconds < completedAtMilliseconds
completedAtMilliseconds <= capability expiry
```

Artifact kind:
`legacy_discovery_fence`

Every root observation's `endEventSequence` equals
`watchSealedEventSequence`. Any other value rejects the whole fence.

### 5.5 Exact snapshot/watch/name-to-inode algorithm

One serialized scope lease executes:

1. verify an accepted, unexpired discovery capability;
2. pre-open every configured root descriptor-relative with no-follow;
3. validate root volume, file identity, owner, mode, link count, type, and
   metadata generation;
4. arm the provider event journal on every root and obtain one ordered start
   watermark before snapshot creation;
5. request one immutable cross-root snapshot generation at that watermark;
6. traverse snapshot roots with bounded depth, entry count, cursor bytes, and
   no-follow descriptor-relative opens;
7. for every name:
   - `fstatat`/equivalent the directory-relative name without following;
   - open the exact descriptor without following;
   - compare name metadata to opened descriptor metadata;
   - inspect metadata only;
   - re-read name metadata after inspection;
   - require name→same opened inode/file identity before and after;
8. reject symlink, hard-link count other than one where a private regular file
   is required, FIFO, socket, device node, unknown type, owner/mode mismatch,
   path escape, depth overflow, entry overflow, cursor overflow, and any
   before/after identity change;
9. drain ordered create, link, unlink, rename, restore, clone, and metadata
   events from the start watermark;
10. re-snapshot and re-enumerate every affected directory/root until one fixed
    point has no unprocessed event at or below the candidate sealed watermark;
11. ask the provider to seal a commit fence at that exact watermark;
12. revalidate every live root name→opened root descriptor, volume/file
    identity, metadata generation, and configured-root digest;
13. atomically commit inventory rows, counts, fence artifact digest,
    `discoveryComplete`, and readiness generation;
14. stable-media sync and read back the database/file plus rollback anchor;
15. acknowledge the exact readiness commit to the provider; and
16. open the provider-delivery gate only while the live provider reports the
    exact committed fence generation and no later event, overflow, root
    replacement, or custody-scope change.

The provider contract must ensure that an event capable of creating or
revealing a covered artifact invalidates the delivery gate before that
artifact can be used by delivery lookup. Otherwise the provider capability is
not accepted.

Concurrent creation after the committed fence is not silently added to a
stale count. It synchronously makes:

```text
discoveryComplete = false
providerDeliveryAllowed = false
registerMutationAllowed = false
readiness = blocked_unavailable
```

and starts a new inventory generation.

### 5.6 RC6 crash and race table

| Window/event | Required recovery |
|---|---|
| crash before watcher arm | no snapshot/fence accepted; readiness red |
| crash after watcher arm before snapshot | discard candidate; reopen roots and new watermark |
| create/rename during snapshot enumeration | consume event, re-snapshot affected root, never commit stale count |
| name replaced before open | before/open descriptor mismatch; reject and restart generation |
| name replaced after open | after/name descriptor mismatch; reject and restart generation |
| hard link introduced | link-count/identity policy failure; readiness red |
| watcher/event journal overflow | `watchOverflow=true` is unrepresentable as accepted fence; readiness unavailable |
| root replacement | root descriptor/name/identity mismatch; readiness red |
| commit fence changes before DB commit | abort DB transaction; readiness red |
| DB commit succeeds, stable-media read-back fails | `blocked_unavailable`; delivery gate closed |
| DB/read-back succeeds, provider acknowledgment missing | gate remains closed; exact idempotent acknowledgment retry |
| event after acknowledgment | provider invalidates gate before delivery lookup and starts next generation |
| restored backup/export outside configured custody | discovery-custody proof invalid; all accepted scopes empty |

### 5.7 RC6 current accepted sets

No immutable input supplies the provider/custody bytes required above:

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

RC6 formal contract may be independently reviewed as closed. RC6 operation
remains `FORMAL_NO_GO` until exact provider/custody artifacts are frozen and
independently accepted.

## 6. RC7 — exact six-operation journal extensions

Packet C replaces S5's six `v1` journal extensions with these `v2` cores. No
extension contains token bytes, token hash, body/request/payload bytes, private
key, bearer credential, or shared server secret.

### 6.1 RegisterJournalExtensionCore v2

Schema:
`binding.device-ingress.register-journal-extension-core.v2`

Exact member order:

1. `expectedHeadGeneration`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `mutationMode`
5. `registrationHeadEpoch`
6. `registrationID`
7. `schema`
8. `tokenDeliveryEpoch`
9. `tokenObservationID`

| Register row | expectedHeadGeneration | expectedRegistrationGeneration | expectedRevocationGeneration | mutationMode | registrationHeadEpoch | registrationID | tokenDeliveryEpoch | tokenObservationID |
|---|---:|---:|---:|---|---|---|---:|---|
| first enrollment, no head | `0` | `0` | `0` | `enroll` | null | null | PositiveUInt64 | TokenObservationID |
| enrollment after `empty_after_deregister` | PositiveUInt64 | `0` | exact current head UInt64 | `enroll` | Base64url43 | null | PositiveUInt64 | TokenObservationID |
| active update | PositiveUInt64 | PositiveUInt64 | UInt64 | `update` | Base64url43 | RegistrationID | PositiveUInt64 | TokenObservationID |
| active token rotation | PositiveUInt64 | PositiveUInt64 | UInt64 | `token_rotation` | Base64url43 | RegistrationID | PositiveUInt64 | TokenObservationID |
| revoked reactivation | PositiveUInt64 | PositiveUInt64 | PositiveUInt64 | `reactivate` | Base64url43 | RegistrationID | PositiveUInt64 | TokenObservationID |

No other nullability or combination is accepted.

Exact reachable maximum CJP-1 bytes: `509`.

### 6.2 ResolveJournalExtensionCore v2

Schema:
`binding.device-ingress.resolve-journal-extension-core.v2`

Exact member order:

1. `contentContractSHA256`
2. `deliveryID`
3. `schema`
4. `ticketID`
5. `ticketLineageSHA256`

All members are non-null:

```text
contentContractSHA256 = DigestHex
deliveryID = DeliveryID
ticketID = TicketID
ticketLineageSHA256 = DigestHex
```

Exact reachable maximum CJP-1 bytes: `455`.

### 6.3 SubmitJournalExtensionCore v2

Schema:
`binding.device-ingress.submit-journal-extension-core.v2`

Exact member order:

1. `contentContractSHA256`
2. `resolveAdmissionID`
3. `schema`
4. `ticketID`
5. `ticketLineageSHA256`

All members are non-null:

```text
contentContractSHA256 = DigestHex
resolveAdmissionID = AdmissionID
ticketID = TicketID
ticketLineageSHA256 = DigestHex
```

Exact reachable maximum CJP-1 bytes: `462`.

### 6.4 StatusJournalExtensionCore v2

Schema:
`binding.device-ingress.status-journal-extension-core.v2`

Exact member order:

1. `correlationSHA256`
2. `registrationID`
3. `schema`
4. `selector`
5. `statusKind`
6. `targetAdmissionID`

| Status row | correlationSHA256 | registrationID | selector | statusKind | targetAdmissionID |
|---|---|---|---|---|---|
| subject current | null or DigestHex | null | `subject_current` | `registration` | null |
| registration ID | null or DigestHex | RegistrationID | `registration_id` | `registration` | null |
| admission ID | null | null | `admission_id` | `admission` | AdmissionID |

`correlationSHA256`, when present, is SHA-256 of exact
`MutationCorrelationCore` bytes. It contains no token/hash.

Exact reachable maxima:

```text
subject_current row  = 259
registration_id row  = 305
admission_id row     = 237
overall maximum      = 305
```

### 6.5 RevokeJournalExtensionCore v2

Schema:
`binding.device-ingress.revoke-journal-extension-core.v2`

Exact member order:

1. `expectedHeadGeneration`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `registrationHeadEpoch`
5. `registrationID`
6. `schema`

Types:

```text
expectedHeadGeneration = PositiveUInt64
expectedRegistrationGeneration = PositiveUInt64
expectedRevocationGeneration = UInt64
registrationHeadEpoch = Base64url43
registrationID = RegistrationID
```

All are non-null. Exact reachable maximum CJP-1 bytes: `358`.

### 6.6 DeregisterJournalExtensionCore v2

Schema:
`binding.device-ingress.deregister-journal-extension-core.v2`

Exact member order:

1. `expectedHeadGeneration`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `registrationHeadEpoch`
5. `registrationID`
6. `schema`

Types and nullability equal revoke. Exact reachable maximum CJP-1 bytes:
`362`.

### 6.7 Extension binding

Every extension is canonicalized independently.

```text
operationExtensionSHA256 =
  lowercaseHex(SHA256(exact extension core bytes))
```

Operation, extension schema, status kind, mutation mode, selector, body,
request, expectation, and authority tuple must agree exactly. Wrong schema,
extra member, missing member, nullability mismatch, integer overflow,
generation mismatch, ID namespace mismatch, cross-operation extension, or
digest substitution rejects before send.

The maximum decoded extension is 509 bytes:

```text
B64(509) = 679
```

## 7. RC7 — stable conflict namespace and cross-operation single flight

### 7.1 VaultConflictNamespaceCore

Schema:
`binding.device-ingress.vault-conflict-namespace-core.v1`

Exact member order:

1. `identityDomain`
2. `nonExportableKeyFingerprintSHA256`
3. `requesterDescriptorSHA256`
4. `schema`
5. `vaultGeneration`

```text
identityDomain = domain:device:notification-callback
nonExportableKeyFingerprintSHA256 = DigestHex
requesterDescriptorSHA256 = DigestHex
vaultGeneration = PositiveUInt64
```

```text
vaultConflictNamespaceSHA256 =
  lowercaseHex(SHA256(exact VaultConflictNamespaceCore bytes))
```

The namespace has no rolling checkpoint, expectation, journal, transaction, or
rollback digest. A fingerprint or namespace is not proof of non-exportability;
an accepted non-exportable-key proof is still mandatory.

### 7.2 Stable resource keys

```text
K_domain_transition =
  SHA256(
    LP(UTF8("binding-device-ingress-domain-transition-v1"))
    || LP(UTF8(identityDomain))
  )

K_registration =
  SHA256(
    LP(UTF8("binding-device-ingress-registration-control-v2"))
    || LP(vaultConflictNamespaceSHA256Raw)
    || LP(UTF8(targetCellID))
    || LP(subjectHeadKeyRaw)
  )

K_ticket =
  SHA256(
    LP(UTF8("binding-device-ingress-ticket-control-v2"))
    || LP(vaultConflictNamespaceSHA256Raw)
    || LP(UTF8(targetCellID))
    || LP(ticketLineageSHA256Raw)
    || LP(UTF8(ticketID))
  )

K_admission =
  SHA256(
    LP(UTF8("binding-device-ingress-admission-recovery-v2"))
    || LP(vaultConflictNamespaceSHA256Raw)
    || LP(UTF8(targetCellID))
    || LP(UTF8(admissionID))
  )
```

`K_domain_transition` is an acquisition/namespace-transition guard. It is
acquired first and released after the durable family leases are installed; it
is not retained as an operation-family lease.

Required durable family lease sets:

| Operation | Acquisition guard | Durable family leases |
|---|---|---|
| register/revoke/deregister | `K_domain_transition` | `K_registration`, own `K_admission` |
| status/registration | `K_domain_transition` | `K_registration`, own `K_admission` |
| resolve/submit | `K_domain_transition` | `K_ticket`, own `K_admission` |
| status/admission | `K_domain_transition` | target admission `K_admission`, own status-request `K_admission` |

After the guard, family keys are sorted by raw 32-byte value before
acquisition. Duplicate family keys collapse to one lease.

### 7.3 DurableResourceLeaseCore

Schema:
`binding.device-ingress.durable-resource-lease-core.v1`

Exact member order:

1. `conflictKeySHA256`
2. `leaseState`
3. `operation`
4. `predecessorCheckpointSHA256`
5. `schema`
6. `transactionID`
7. `transactionSequence`

Closed `leaseState`:

- `prepared`;
- `send_ambiguous`;
- `recovery_only`;
- `terminal`.

There is one durable row:

```text
UNIQUE(vaultConflictNamespaceSHA256, conflictKeySHA256)
```

A nonterminal lease has no wall-clock expiry and cannot be stolen. Another
process may only enter exact status recovery for the existing transaction.
It never sends a different operation.

### 7.4 Vault namespace transition

Every operation briefly acquires `K_domain_transition`, verifies the one
current namespace and that no vault transition is pending, installs all
operation leases, then releases the process lock while durable leases remain.

Vault/key generation transition:

1. exclusively acquires `K_domain_transition`;
2. proves an accepted old→new Identity/vault recovery relation;
3. refuses transition while any nonterminal resource lease exists;
4. commits the new namespace and continuity genesis atomically;
5. advances/read-backs an accepted rollback anchor; and
6. only then permits new operations under the new namespace.

Missing old→new recovery relation makes transition unavailable. Local UUID,
boolean, timestamp, current key possession, or numerically higher generation
cannot authorize it.

This prevents proof/checkpoint generation N→N+1 from changing conflict keys and
prevents vault generation changes from splitting an ambiguous operation.

## 8. RC8 — acyclic predecessor/successor checkpoint DAG

### 8.1 ResponseExpectationCore v3 durability replacement

For post-challenge operation sends only, Packet C replaces S5
`ResponseExpectationCore v2` member `vaultContinuityProofSHA256` with explicit
predecessor inputs and changes the schema to:

`binding.device-ingress.response-expectation-core.v3`

All S5 v2 members and semantics remain in their existing relative order except
that the final durability members are:

34. `predecessorRollbackAnchorReceiptSHA256`
35. `predecessorVaultCheckpointGeneration`
36. `predecessorVaultCheckpointSHA256`
37. `vaultConflictNamespaceSHA256`

Types:

```text
predecessorRollbackAnchorReceiptSHA256 = DigestHex
predecessorVaultCheckpointGeneration = PositiveUInt64
predecessorVaultCheckpointSHA256 = DigestHex
vaultConflictNamespaceSHA256 = DigestHex
```

This Packet C clause does not repair or classify the earlier pre-challenge
expectation from RC1. RC1 remains outside scope and NO-GO.

### 8.2 OperationJournalCore v3

Schema:
`binding.device-ingress.operation-journal-core.v3`

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `challengeArtifactSHA256`
4. `expectationID`
5. `expectationSHA256`
6. `initialSendState`
7. `intentArtifactSHA256`
8. `journalID`
9. `operation`
10. `operationExtension`
11. `operationExtensionSHA256`
12. `operationExtensionSchema`
13. `operationResourceKeys`
14. `predecessorCheckpointGeneration`
15. `predecessorCheckpointSHA256`
16. `predecessorRollbackAnchorReceiptSHA256`
17. `requestArtifactSHA256`
18. `schema`
19. `statusKind`
20. `transactionID`
21. `transactionSequence`
22. `vaultConflictNamespaceSHA256`

`operationResourceKeys` contains exactly the sorted, duplicate-free durable
family key set from section 7.2. It excludes the short-lived
`K_domain_transition` guard and has at most two `DigestHex` entries.

`initialSendState` is exactly `anchor_pending`. The exact journal bytes become
immutable before their digest enters `PreparedLocalTransactionCore`, the
journal root, and the successor checkpoint. Every later send, outcome, or
finalization fact is a separate immutable append-only marker from section 8.8;
the journal is never rewritten in place.

`statusKind` is null for non-status, otherwise `registration|admission`.
`transactionSequence` is PositiveUInt64. Every other ID/digest uses section 4.

The checked allocation ceiling, deliberately not claimed as a semantically
reachable exact maximum across incompatible discriminator cases, is:

```text
OperationJournalCore v3 <= 2300 CJP-1 bytes

operationJournalSHA256 =
  lowercaseHex(SHA256(exact OperationJournalCore v3 bytes))
```

### 8.3 Journal root

Genesis:

```text
JournalRoot_0 =
  SHA256(LP(UTF8("HAVEN-BINDING-DEVICE-INGRESS-JOURNAL-ROOT-EMPTY-V1")))
```

For transaction sequence `t`:

```text
JournalLeaf_t =
  SHA256(
    LP(UTF8("HAVEN-BINDING-DEVICE-INGRESS-JOURNAL-LEAF-V1"))
    || LP(UInt64BE(t))
    || LP(operationJournalSHA256Raw)
  )

JournalRoot_t =
  SHA256(
    LP(UTF8("HAVEN-BINDING-DEVICE-INGRESS-JOURNAL-ROOT-APPEND-V1"))
    || LP(JournalRoot_(t-1))
    || LP(JournalLeaf_t)
  )
```

Only strict `t = predecessor transactionSequence + 1` is accepted. Duplicate,
gap, overflow, wrong predecessor root, or alternate journal bytes make
readiness unavailable.

### 8.4 PreparedLocalTransactionCore

Schema:
`binding.device-ingress.prepared-local-transaction-core.v1`

Exact member order:

1. `expectationSHA256`
2. `journalSHA256`
3. `predecessorJournalRootSHA256`
4. `predecessorRollbackAnchorReceiptSHA256`
5. `predecessorVaultCheckpointSHA256`
6. `resultingJournalRootSHA256`
7. `schema`
8. `transactionID`
9. `transactionSequence`
10. `vaultConflictNamespaceSHA256`

```text
preparedTransactionSHA256 =
  lowercaseHex(SHA256(exact PreparedLocalTransactionCore bytes))
```

It does not contain the successor checkpoint digest.

### 8.5 VaultCheckpointCore v2

Schema:
`binding.device-ingress.vault-checkpoint-core.v2`

Exact member order:

1. `appliedPreparedTransactionSHA256`
2. `approvedBuildProvenanceSHA256`
3. `checkpointGeneration`
4. `custodyProofSHA256`
5. `hardwareAttestationSHA256`
6. `identityDomain`
7. `journalRootSHA256`
8. `latestExpectationSHA256`
9. `nonExportableKeyFingerprintSHA256`
10. `predecessorCheckpointSHA256`
11. `predecessorRollbackAnchorReceiptSHA256`
12. `requesterDescriptorSHA256`
13. `schema`
14. `vaultConflictNamespaceSHA256`
15. `vaultGeneration`

Genesis `V_0`:

```text
appliedPreparedTransactionSHA256 = null
checkpointGeneration = 1
journalRootSHA256 = JournalRoot_0
latestExpectationSHA256 = null
predecessorCheckpointSHA256 = null
predecessorRollbackAnchorReceiptSHA256 = null
```

Successor `V_(n+1)`:

```text
appliedPreparedTransactionSHA256 = preparedTransactionSHA256
checkpointGeneration = V_n.checkpointGeneration + 1
journalRootSHA256 = prepared.resultingJournalRootSHA256
latestExpectationSHA256 = prepared.expectationSHA256
predecessorCheckpointSHA256 = SHA256(exact V_n envelope bytes)
predecessorRollbackAnchorReceiptSHA256 = SHA256(exact A_n envelope bytes)
```

`custodyProofSHA256` and `hardwareAttestationSHA256` are nullable only because
accepted provider policy may explicitly declare them not applicable. Current
accepted provider policy is empty, so no null case is presently operational.

### 8.6 VaultCheckpointEnvelope v2

Schema:
`binding.device-ingress.vault-checkpoint-envelope.v2`

Exact member order:

1. `algorithm`
2. `core`
3. `coreSHA256`
4. `keyID`
5. `protectionMode`
6. `schema`
7. `signatureOrMAC`

Protection input:

```text
LP(UTF8("HAVEN-BINDING-DEVICE-INGRESS-VAULT-CHECKPOINT-V2"))
|| LP(exact VaultCheckpointCore v2 bytes)
```

```text
vaultCheckpointSHA256 =
  lowercaseHex(SHA256(exact VaultCheckpointEnvelope v2 bytes))
```

The existing non-exportable vault key performs the operation without exporting
private key material. `protectionMode` is `signature|mac`. Acceptance still
requires an independently proven non-exportable-key/custody path.

### 8.7 RollbackAnchorReceiptCore

`RollbackAnchorProviderCapabilityCore`

Schema:
`binding.device-ingress.rollback-anchor-provider-capability-core.v1`

Exact member order:

1. `atomicCompareAndSetSupported`
2. `capabilityGeneration`
3. `expiresAtMilliseconds`
4. `issuedAtMilliseconds`
5. `monotonicGenerationSupported`
6. `providerDescriptorSHA256`
7. `queryCurrentHeadSupported`
8. `queryExactGenerationSupported`
9. `schema`
10. `tamperResistantExternalStateSupported`

Exact accepted values:

```text
atomicCompareAndSetSupported = true
capabilityGeneration = PositiveUInt64
0 < expiresAtMilliseconds - issuedAtMilliseconds <= 86400000
monotonicGenerationSupported = true
providerDescriptorSHA256 = DigestHex
queryCurrentHeadSupported = true
queryExactGenerationSupported = true
tamperResistantExternalStateSupported = true
```

Artifact kind:
`binding_rollback_anchor_provider_capability`

Signed booleans are interface claims only. The artifact becomes acceptable
only after independent evidence proves the named provider behavior. The
current accepted capability set is EMPTY.

Before accepting any local checkpoint, marker, lease recovery, side-effect
boundary, or positive UI, the client queries the provider's current head and
requires exact equality of generation, receipt digest, namespace, artifact
kind, artifact digest, and checkpoint generation with its locally durable
head. Querying an old exact generation is insufficient. A current head whose
artifact bytes are absent locally is `blocked_unavailable`, never repaired by
choosing the highest local generation.

Schema:
`binding.device-ingress.rollback-anchor-receipt-core.v1`

Exact member order:

1. `anchorGeneration`
2. `anchoredArtifactKind`
3. `anchoredArtifactSHA256`
4. `checkpointGeneration`
5. `previousAnchorReceiptSHA256`
6. `providerCapabilityArtifactSHA256`
7. `schema`
8. `vaultConflictNamespaceSHA256`

Closed `anchoredArtifactKind`:

- `vault_checkpoint`;
- `local_finalization_marker`;
- `resolve_delivery_marker`.

```text
anchorGeneration = PositiveUInt64
anchoredArtifactSHA256 = DigestHex
checkpointGeneration = PositiveUInt64
previousAnchorReceiptSHA256 = null only for genesis, otherwise DigestHex
providerCapabilityArtifactSHA256 = DigestHex
vaultConflictNamespaceSHA256 = DigestHex
```

Genesis anchor `A_0`:

```text
anchorGeneration = 1
anchoredArtifactKind = vault_checkpoint
anchoredArtifactSHA256 = SHA256(exact V_0 envelope bytes)
checkpointGeneration = 1
previousAnchorReceiptSHA256 = null
```

Successor anchor:

```text
anchorGeneration = A_n.anchorGeneration + 1
anchoredArtifactKind = exact kind of the next immutable critical artifact
anchoredArtifactSHA256 = SHA256(exact next immutable critical artifact bytes)
checkpointGeneration = current accepted vault checkpoint generation
previousAnchorReceiptSHA256 = SHA256(exact A_n provider envelope bytes)
```

For `vault_checkpoint`, the decoded artifact must be the exact accepted
checkpoint envelope: genesis uses generation 1; every later checkpoint is
exactly predecessor checkpoint generation + 1 and binds the immediately
preceding anchor receipt. For either marker kind, checkpoint generation is
unchanged, the marker binds the current checkpoint plus immediately preceding
anchor receipt, and the marker's schema/state relation validates exactly.
Unknown artifact kind, malformed artifact, digest-only substitution, or a
semantically wrong but correctly hashed artifact rejects.

Artifact kind:
`binding_rollback_anchor_receipt`

The provider CAS input is exactly:

```text
(expectedCurrentReceiptEnvelopeBytes,
 exactAnchoredArtifactBytes,
 proposedRollbackAnchorReceiptCoreBytes)
```

It hashes and validates the artifact itself and atomically compares the exact
current receipt bytes; a caller-supplied digest alone is never sufficient.

The external provider atomically rejects same generation/different artifact,
generation gap, previous-anchor mismatch, artifact-kind mismatch, namespace
mismatch, checkpoint-generation rollback, or counter overflow. It stores and
returns the exact accepted artifact tuple. A marker may be used as a send,
sink, or positive-UI boundary only after its exact receipt is durably stored
and read back. No accepted rollback provider currently exists.

### 8.8 LocalFinalizationMarkerCore

Schema:
`binding.device-ingress.local-finalization-marker-core.v1`

Exact member order:

1. `checkpointAnchorReceiptSHA256`
2. `finalizationArtifactSHA256`
3. `markerState`
4. `outcomeArtifactSHA256`
5. `predecessorAnchorReceiptSHA256`
6. `predecessorMarkerSHA256`
7. `preparedTransactionSHA256`
8. `schema`
9. `successorVaultCheckpointSHA256`
10. `transactionID`
11. `transactionSequence`

Closed `markerState`:

- `send_started_ambiguous`;
- `outcome_verified`;
- `finalized`.

Each state is a new immutable append-only marker; no marker is rewritten.
For `send_started_ambiguous`, both artifact fields are null. For
`outcome_verified`, `outcomeArtifactSHA256` is non-null and
`finalizationArtifactSHA256` is null. For `finalized`, both are non-null and
bind the exact verified outcome plus the operation-specific signed fresh
status, receipt, or tombstone that justifies finalization.
The first marker has `predecessorMarkerSHA256 = null` and binds the exact
checkpoint anchor as both `checkpointAnchorReceiptSHA256` and
`predecessorAnchorReceiptSHA256`. Every successor marker binds the preceding
marker digest and its external anchor receipt. Each marker is committed and
read back on stable media, then receives a new exact external
`RollbackAnchorReceiptCore` before the represented fact may authorize the
next irreversible side effect or positive UI. There is no unanchored
`send_permitted` state.

```text
localFinalizationMarkerSHA256 =
  lowercaseHex(SHA256(exact LocalFinalizationMarkerCore bytes))
```

### 8.9 Acyclic proof

The only permitted construction order is:

```text
V_n + A_n
  -> E_t
  -> extension_t
  -> J_t
  -> Prepared_t
  -> V_(n+1)
  -> A_checkpoint
  -> Marker_send_started_ambiguous
  -> A_send_boundary
  -> transport send
  -> Marker_outcome_verified
  -> A_outcome
  -> operation-specific finalization
  -> Marker_finalized
  -> A_finalized
  -> positive UI and lease release
```

Edges:

```text
E_t            contains SHA(V_n), SHA(A_n)
J_t            contains SHA(E_t), SHA(V_n), SHA(A_n), extension digest
Prepared_t     contains SHA(E_t), SHA(J_t), SHA(V_n), SHA(A_n), new root
V_(n+1)        contains SHA(Prepared_t), SHA(V_n), SHA(A_n), new root, SHA(E_t)
A_checkpoint   contains SHA(V_(n+1)), SHA(A_n)
Marker_send    contains SHA(Prepared_t), SHA(V_(n+1)), SHA(A_checkpoint)
A_send         contains SHA(Marker_send), SHA(A_checkpoint)
Marker_outcome contains SHA(Marker_send), SHA(A_send), verified outcome digest
A_outcome      contains SHA(Marker_outcome), SHA(A_send)
Marker_final   contains SHA(Marker_outcome), SHA(A_outcome),
               verified outcome and finalization-artifact digests
A_final        contains SHA(Marker_final), SHA(A_outcome)
```

No object contains its own digest or the digest of a later object. There is no
same-generation `E↔V`, `J↔V`, `V↔A`, or marker↔anchor cycle. Every external
anchor generation is a strict successor; all marker and checkpoint references
point only to already materialized predecessors.

## 9. RC7/RC8 stable-media transaction and crash recovery

### 9.1 Required durability capability

`LocalDurabilityProviderCapabilityCore`

Schema:
`binding.device-ingress.local-durability-provider-capability-core.v1`

Exact member order:

1. `atomicMultiRecordSupported`
2. `capabilityGeneration`
3. `crossProcessGuardSupported`
4. `descriptorNameInodeFenceSupported`
5. `durabilityMode`
6. `expiresAtMilliseconds`
7. `issuedAtMilliseconds`
8. `maximumTransactionBytes`
9. `powerLossRecoverySupported`
10. `providerDescriptorSHA256`
11. `restoredCopyDetectionSupported`
12. `rollbackAnchorInteropSupported`
13. `schema`
14. `storeRootDescriptorSHA256`
15. `syncContainingDirectorySupported`

Exact accepted values:

```text
atomicMultiRecordSupported = true
capabilityGeneration = PositiveUInt64
crossProcessGuardSupported = true
descriptorNameInodeFenceSupported = true
durabilityMode = file_full_sync | database_full_sync
0 < expiresAtMilliseconds - issuedAtMilliseconds <= 86400000
maximumTransactionBytes = UInt32, 1...4194304
powerLossRecoverySupported = true
providerDescriptorSHA256 = DigestHex
restoredCopyDetectionSupported = true
rollbackAnchorInteropSupported = true
storeRootDescriptorSHA256 = DigestHex
syncContainingDirectorySupported = true
```

Artifact kind:
`binding_local_durability_provider_capability`

The capability freezes:

- one canonical descriptor-relative store root;
- atomic multi-record transaction semantics;
- mutually exclusive crash-releasing cross-process
  `K_domain_transition` acquisition;
- full file+parent-directory stable-media sync or exact database FULL-sync
  equivalent;
- descriptor/name/inode/owner/mode/link-count checks;
- journal/checkpoint/lease/finalization atomicity;
- power-loss recovery;
- restored-copy detection;
- maximum transaction byte count; and
- rollback-anchor interoperability.

The signed fields are claims, not platform evidence. Accepted durability
providers are currently EMPTY. No `Data.write(.atomic)`, ordinary database
commit, in-memory read-back, local timestamp, path name, or self-signed
capability is proof.

### 9.2 Exact operation prepare/anchor/send sequence

1. open existing persistent CellApple vault, no-create;
2. verify `V_n`, `A_n`, vault namespace, external accepted proofs, authority,
   and local stable-store capability;
3. acquire `K_domain_transition`, then sorted family leases;
4. construct body/intent/challenge/request in the inherited order;
5. construct exact post-challenge `E_t`, extension, `J_t`, `Prepared_t`, and
   `V_(n+1)` without future-digest references;
6. atomically commit/read back E/J/Prepared/V, leases, transaction sequence,
   and `anchor_pending` state to stable media;
7. request idempotent external checkpoint anchor for exact `V_(n+1)`;
8. verify, durably store, and read back that exact anchor receipt;
9. append/read back immutable `send_started_ambiguous`;
10. externally anchor that exact marker, then durably store/read back the
    receipt;
11. only then invoke transport with the already-existing exact request bytes;
12. verify outcome against E/J and inherited SignedOutcome rules;
13. append/read back immutable `outcome_verified`, externally anchor it, then
    durably store/read back the exact anchor receipt;
14. perform operation-specific fresh-status/finalization;
15. append/read back immutable `finalized`, externally anchor it, then durably
    store/read back the exact anchor receipt;
16. only after step 15 publish positive UI and release durable leases.

After process restart, body/request bytes are never reconstructed from digests.
Only exact status recovery is allowed.

### 9.3 Crash windows

| Crash/failure window | Required state/recovery |
|---|---|
| before stable E/J/Prepared/V commit | predecessor V/A remain authoritative; no send |
| during multi-record commit | transaction rollback or provider-proven recovery; no send |
| after local commit before anchor request | `anchor_pending`; idempotently request exact A; no send |
| anchor provider rejects | `blocked_unavailable`; no send |
| checkpoint anchor committed externally before local receipt commit | query exact provider generation/artifact; commit same receipt or block |
| send marker committed locally but not externally anchored | no send; anchor the exact marker or block |
| send marker externally anchored before transport call | conservatively status recovery; never claim unsent |
| after transport call before outcome | matching admission/status recovery only |
| outcome received before outcome-marker anchor | re-read outcome/status; no positive UI or finalization |
| outcome marker anchored before operation-specific finalization | resume exact fresh-status/finalization only |
| final marker committed locally but not externally anchored | no positive UI and no lease release |
| wrong predecessor/root/anchor/namespace on restart | `blocked_unavailable`; no repair by timestamp or highest local generation |
| restored local copy is behind provider current head | `blocked_unavailable`; old exact-generation query cannot authorize recovery or send |
| duplicate process | observes durable lease; recovery only |
| vault transition while lease nonterminal | transition rejected |
| stable-media or rollback provider missing | accepted sets empty; readiness unavailable |

### 9.4 Local trust-state gate

S5's fail-closed distinction remains exact:

| Local trust state | Permitted action |
|---|---|
| invalid/missing/locked/replaced vault or authority | none |
| valid vault and local evidence absent | `status/registration`, selector `subject_current` only |
| historical evidence unadjudicated | exact status recovery only |
| pending/ambiguous operation | matching status/admission or required status/registration only |
| fresh subject active | operation-specific authorized update/rotation, resolve, submit, revoke, deregister, status |
| fresh subject revoked | authorized reactivate, deregister, status |
| fresh subject unknown | authorized first enroll or status |
| fresh subject deregistered | authorized new-ID enroll or status, subject to owner policy |
| blocked indeterminate | status retry only |

No checkpoint or local evidence opens a mutation gate by itself.

## 10. RC7 crash-atomic resolve handoff

### 10.1 IdempotentSinkCapabilityCore

Schema:
`binding.device-ingress.idempotent-sink-capability-core.v1`

Exact member order:

1. `capabilityGeneration`
2. `contentPolicySHA256`
3. `expiresAtMilliseconds`
4. `issuedAtMilliseconds`
5. `maximumPayloadBytes`
6. `providerDescriptorSHA256`
7. `schema`

```text
capabilityGeneration = PositiveUInt64
contentPolicySHA256 = DigestHex
0 < expiresAtMilliseconds - issuedAtMilliseconds <= 86400000
maximumPayloadBytes = UInt32, 1...48000
providerDescriptorSHA256 = DigestHex
```

Artifact kind:
`binding_idempotent_sink_capability`

### 10.2 IdempotentSinkReceiptCore

Schema:
`binding.device-ingress.idempotent-sink-receipt-core.v1`

Exact member order:

1. `deliveryID`
2. `disposition`
3. `resultSHA256`
4. `schema`
5. `sinkCapabilityArtifactSHA256`
6. `sinkGeneration`
7. `ticketID`
8. `ticketLineageSHA256`
9. `transactionSequence`

```text
deliveryID = DeliveryID
disposition = accepted | exact_replay
resultSHA256 = DigestHex
sinkCapabilityArtifactSHA256 = DigestHex
sinkGeneration = PositiveUInt64
ticketID = TicketID
ticketLineageSHA256 = DigestHex
transactionSequence = PositiveUInt64
```

Artifact kind:
`binding_idempotent_sink_receipt`

The provider enforces:

```text
UNIQUE(providerDescriptorSHA256, deliveryID)
```

Same delivery ID and byte-identical tuple returns the exact stored receipt.
Same delivery ID with any mismatch rejects and stores nothing.

### 10.3 ResolveDeliveryMarkerCore v2

Schema:
`binding.device-ingress.resolve-delivery-marker-core.v2`

Exact member order:

1. `deliveryID`
2. `deliveryState`
3. `outcomeArtifactSHA256`
4. `predecessorAnchorReceiptSHA256`
5. `predecessorDeliveryMarkerSHA256`
6. `resultSHA256`
7. `schema`
8. `sinkReceiptArtifactSHA256`
9. `ticketID`
10. `ticketLineageSHA256`
11. `transactionSequence`

Closed states:

- `prepared`;
- `sink_receipt_verified`;
- `finalized`.

For `prepared`, `sinkReceiptArtifactSHA256 = null`. For
`sink_receipt_verified` and `finalized`, it is the same non-null exact
idempotent sink receipt artifact digest.

```text
resolveDeliveryMarkerSHA256 =
  lowercaseHex(SHA256(exact ResolveDeliveryMarkerCore v2 bytes))
```

Sequence:

1. verify resolve success against expectation/journal;
2. append/read back immutable `prepared`, with
   `predecessorDeliveryMarkerSHA256 = null` and the latest accepted operation
   anchor as `predecessorAnchorReceiptSHA256`;
3. externally anchor exact `prepared`, durably store/read back that anchor
   receipt, and only then expose payload to the sink;
4. invoke sink with exact
   `(deliveryID, ticketID, ticketLineageSHA256, volatile payload,
   resultSHA256, transactionSequence)`;
5. verify provider envelope, capability, receipt tuple, unique delivery ID,
   result digest, generation, expiry, and accepted/exact-replay disposition;
6. append/read back immutable `sink_receipt_verified`, binding the preceding
   marker and anchor plus only the receipt artifact digest; externally anchor
   it and durably store/read back the exact anchor receipt;
7. append/read back immutable `finalized`, binding the preceding marker and
   anchor; externally anchor it and durably store/read back the exact receipt;
8. only then publish delivered truth.

Every state is a distinct object; no delivery marker is rewritten. Crash
before the externally anchored `prepared` marker performs no sink invocation.
Crash after that anchor but before sink invocation conservatively queries or
replays the already stored exact resolve request bytes, requires the server's
byte-identical original signed success outcome, re-verifies its result digest,
and retries the same delivery ID; it never reconstructs payload from a digest
or persists the volatile payload locally. If exact outcome replay is
unavailable, recovery is `blocked_unavailable`. Crash after sink acceptance
but before the anchored receipt marker queries/retries the same delivery ID;
the sink returns exact replay. Wrong receipt, unavailable provider, provider
rollback, mismatched digest, unanchored marker, or missing content/storage
policy blocks without positive delivery truth.

Current state:

```text
accepted idempotent sink capabilities = EMPTY
accepted idempotent sink receipts = EMPTY
resolve delivery readiness = UNAVAILABLE
delivered-once claim = NONE
```

## 11. Authoritative deregister and local privacy

Packet C preserves:

```text
verified authoritative server outcome
-> required fresh signed status
-> local finalization_pending
-> local token/active-binding erasure
-> stable-media read-back
-> only owner-approved minimal evidence
-> truthful UI
```

Local erase before verified server commit is forbidden. Revoke never runs
deregister cleanup. A crash after server commit resumes through the same
admission/status recovery and idempotent local erase.

`MBI-PRIVACY-RETENTION-01` remains Kjetil-owned and open. Packet C selects no
retention duration, disclosure, compaction, deletion, backup/restore policy,
ciphertext retention, or user wording.

## 12. Exact Packet C fixture applicability contract

### 12.1 ConsumerApplicabilityCore

Schema:
`haven.apns.s6.packet-c.consumer-applicability-core.v1`

Exact member order:

1. `consumer`
2. `decision`
3. `expectedDecision`
4. `reasonCode`
5. `schema`
6. `testID`
7. `testPath`

For `decision=required`:

```text
expectedDecision = non-null TokenASCII, 1...64
reasonCode = null
testID = non-null TokenASCII, 1...128
testPath = non-null repo-qualified PathTokenASCII, 1...512
```

For `decision=not_applicable`:

```text
expectedDecision = null
reasonCode = server_only_legacy_discovery
           | client_only_local_durability
           | external_premise_unavailable
testID = null
testPath = null
```

`consumer` is exactly `A|B|C`.

Every fixture manifest entry contains Base64url exact applicability cores in
the fixed member order `A`, `B`, `C`; no boolean toggle exists.

### 12.2 Test-code dictionary

| Code | Exact future test path and identifier |
|---|---|
| A-C6 | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressPacketCLegacyContractTests.swift::fixture_<entryID>` |
| A-C78 | `repo://CellProtocol/Tests/CellBaseTests/DeviceIngressPacketCDurabilityContractTests.swift::fixture_<entryID>` |
| B-C6 | `repo://CellScaffold/Tests/AppTests/DeviceIngressLegacyDiscoveryFenceTests.swift::fixture_<entryID>` |
| C-EXT | `repo://Binding/BindingTests/DeviceIngressJournalExtensionV2Tests.swift::fixture_<entryID>` |
| C-LOCK | `repo://Binding/BindingTests/DeviceIngressStableConflictNamespaceTests.swift::fixture_<entryID>` |
| C-DAG | `repo://Binding/BindingTests/DeviceIngressVaultCheckpointDAGTests.swift::fixture_<entryID>` |
| C-STORE | `repo://Binding/BindingTests/DeviceIngressStableTransactionCrashTests.swift::fixture_<entryID>` |
| C-RED | `repo://Binding/BindingTests/DeviceIngressClientReducerTests.swift::fixture_<entryID>` |
| C-SINK | `repo://Binding/BindingTests/DeviceIngressResolveSinkHandoffTests.swift::fixture_<entryID>` |
| C-VAULT | `repo://Binding/BindingTests/DeviceIngressVaultContinuityV2Tests.swift::fixture_<entryID>` |

### 12.3 Exact entry ledger

The single producer root is:

`repo://CellProtocol/Tests/CellBaseTests/Fixtures/DeviceIngressCompositionS6PacketC/`

All table paths are relative to that exact producer root. CellScaffold and
Binding consumers read the producer bytes byte-identically and do not re-sign,
rewrite, or regenerate them.

`N/A-B` means `not_applicable(server_only_legacy_discovery)`.
`N/A-C` means `not_applicable(client_only_local_durability)`.
`N/A-E` means `not_applicable(external_premise_unavailable)`.

| entryID | Exact fixture path | Expected | A | B | C |
|---|---|---|---|---|---|
| S6C001 | `legacy/watch-before-snapshot-create.json` | rescan-gate-red | A-C6 | B-C6 | N/A-B |
| S6C002 | `legacy/rename-between-name-and-open.json` | reject-gate-red | A-C6 | B-C6 | N/A-B |
| S6C003 | `legacy/replace-after-open.json` | reject-gate-red | A-C6 | B-C6 | N/A-B |
| S6C004 | `legacy/hardlink-and-fifo.json` | reject-gate-red | A-C6 | B-C6 | N/A-B |
| S6C005 | `legacy/event-journal-overflow.json` | unavailable | A-C6 | B-C6 | N/A-B |
| S6C006 | `legacy/root-replaced-before-commit.json` | reject-gate-red | A-C6 | B-C6 | N/A-B |
| S6C007 | `legacy/create-after-commit-before-ack.json` | abort-gate-red | A-C6 | B-C6 | N/A-B |
| S6C008 | `legacy/event-after-ack.json` | invalidate-before-delivery | A-C6 | B-C6 | N/A-B |
| S6C009 | `legacy/missing-provider-capability.json` | unavailable | A-C6 | B-C6 | N/A-E |
| S6C010 | `extension/register-first-enroll.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C011 | `extension/register-enroll-after-deregister.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C012 | `extension/register-update.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C013 | `extension/register-reactivate.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C014 | `extension/register-token-rotation.max-509.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C015 | `extension/register-invalid-nullability.json` | reject | A-C78 | N/A-C | C-EXT |
| S6C016 | `extension/resolve.max-455.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C017 | `extension/submit.max-462.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C018 | `extension/status-subject-current.max-259.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C019 | `extension/status-registration-id.max-305.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C020 | `extension/status-admission-id.max-237.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C021 | `extension/status-cross-selector-field.json` | reject | A-C78 | N/A-C | C-EXT |
| S6C022 | `extension/revoke.max-358.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C023 | `extension/deregister.max-362.json` | accept | A-C78 | N/A-C | C-EXT |
| S6C024 | `extension/wrong-schema-operation-digest.json` | reject | A-C78 | N/A-C | C-EXT |
| S6C025 | `lock/register-revoke-deregister-race.json` | serialize | A-C78 | N/A-C | C-LOCK |
| S6C026 | `lock/resolve-submit-race.json` | serialize | A-C78 | N/A-C | C-LOCK |
| S6C027 | `lock/status-recovery-across-checkpoint-generation.json` | same-family-recovery | A-C78 | N/A-C | C-LOCK |
| S6C028 | `lock/vault-transition-with-pending-lease.json` | reject-transition | A-C78 | N/A-C | C-LOCK |
| S6C029 | `dag/genesis-checkpoint-anchor.json` | accept-structure-unavailable-provider | A-C78 | N/A-C | C-DAG |
| S6C030 | `dag/predecessor-operation-successor-anchor.json` | accept-structure-unavailable-provider | A-C78 | N/A-C | C-DAG |
| S6C031 | `dag/same-generation-self-reference.json` | reject | A-C78 | N/A-C | C-DAG |
| S6C032 | `dag/wrong-predecessor-root.json` | reject | A-C78 | N/A-C | C-DAG |
| S6C033 | `dag/wrong-anchor-artifact-kind-or-digest.json` | reject | A-C78 | N/A-C | C-DAG |
| S6C034 | `dag/generation-gap-overflow.json` | reject | A-C78 | N/A-C | C-DAG |
| S6C035 | `store/crash-before-local-commit.json` | no-send | A-C78 | N/A-C | C-STORE |
| S6C036 | `store/crash-after-local-before-anchor.json` | anchor-recovery-no-send | A-C78 | N/A-C | C-STORE |
| S6C037 | `store/checkpoint-anchor-external-before-local-receipt.json` | exact-anchor-recovery | A-C78 | N/A-C | C-STORE |
| S6C038 | `store/send-marker-anchored-before-transport.json` | status-recovery-never-unsent | A-C78 | N/A-C | C-STORE |
| S6C039 | `reducer/local-evidence-absent-status-only.json` | status-only | A-C78 | N/A-C | C-RED |
| S6C040 | `reducer/invalid-vault-no-status.json` | unavailable | A-C78 | N/A-C | C-RED |
| S6C041 | `sink/prepared-marker-local-not-anchored.json` | no-invoke | A-C78 | N/A-C | C-SINK |
| S6C042 | `sink/accept-before-receipt-marker-anchor.json` | exact-replay-no-delivered-truth | A-C78 | N/A-C | C-SINK |
| S6C043 | `sink/wrong-delivery-or-result.json` | reject | A-C78 | N/A-C | C-SINK |
| S6C044 | `sink/missing-provider.json` | unavailable-no-delivery-claim | A-C78 | N/A-C | C-SINK |
| S6C045 | `vault/copied-id-boolean-mac-key.json` | unavailable | A-C78 | N/A-C | C-VAULT |
| S6C046 | `vault/nonexportable-without-rollback.json` | unavailable | A-C78 | N/A-C | C-VAULT |
| S6C047 | `vault/rollback-without-copy-custody.json` | unavailable | A-C78 | N/A-C | C-VAULT |
| S6C048 | `vault/missing-hardware-custody-store-proof.json` | unavailable | A-C78 | N/A-C | C-VAULT |
| S6C049 | `dag/journal-rewrite-after-checkpoint.json` | reject | A-C78 | N/A-C | C-DAG |
| S6C050 | `dag/finalization-marker-rewrite-after-anchor.json` | reject | A-C78 | N/A-C | C-DAG |
| S6C051 | `dag/delivery-marker-rewrite-after-anchor.json` | reject | A-C78 | N/A-C | C-DAG |
| S6C052 | `dag/marker-anchor-same-generation-cycle.json` | reject | A-C78 | N/A-C | C-DAG |

Every future manifest entry must additionally bind exact fixture SHA-256,
lines/bytes, decoded byte count, core digest, expected decision, sanitized
reason, and the three exact applicability-core digests. Actual fixture and
consumer-ledger hashes remain missing `MBI-07` evidence.

## 13. Formal root classification

| Root | Packet C author classification | Residual premise | Operational classification |
|---|---|---|---|
| `S5-RC-06` legacy inventory/readiness | **CLOSED FORMAL CANDIDATE** — atomic snapshot/watch/commit fence, bounded traversal, name→inode fencing, race/crash behavior, and exact provider interface defined | discovery/durability/custody/migration/deactivation/disposal/backup providers and proofs EMPTY | `FORMAL_NO_GO` |
| `S5-RC-07` Binding journal/reducer | **CLOSED FORMAL CANDIDATE** — total six extensions, stable conflict namespace, leases, store sequence, trust gate, crash recovery, and sink receipt defined | local durability provider and idempotent sink accepted sets EMPTY; RC1 remains outside scope | `FORMAL_NO_GO` |
| `S5-RC-08` vault continuity | **CLOSED FORMAL CANDIDATE** — explicit predecessor/successor checkpoint and external-anchor DAG has no same-generation cycle | non-exportable key, copy, rollback, custody, recovery, hardware, store proofs EMPTY; Identity cutover separate | `FORMAL_NO_GO` |

“Closed formal candidate” means the author presents a total fillable contract.
It is not an independent PASS and not a runtime or production closure.

## 14. Current accepted proof sets

No immutable input supplies an accepted artifact for any of these sets:

```text
accepted legacy discovery providers = EMPTY
accepted legacy discovery fences = EMPTY
accepted legacy custody proofs = EMPTY
accepted migration/deactivation/disposal procedures = EMPTY
accepted backup/restore proofs = EMPTY

accepted local durability providers = EMPTY
accepted non-exportable key proofs = EMPTY
accepted copy-resistance proofs = EMPTY
accepted rollback-anchor providers/receipts = EMPTY
accepted custody/recovery proofs = EMPTY
accepted hardware attestations = EMPTY
accepted idempotent sink capabilities/receipts = EMPTY

legacy/provider delivery readiness = UNAVAILABLE
Binding protected-operation readiness = UNAVAILABLE
resolve delivery readiness = UNAVAILABLE
hardware PASS = NONE
copy-resistance PASS = NONE
rollback-resistance PASS = NONE
delivered-once PASS = NONE
```

Schemas, paths, local IDs, booleans, fingerprints, current-key possession,
files, database rows, code signatures, or timestamps cannot make any set
non-empty.

## 15. Out-of-scope blockers preserved

Packet C does not address and cannot close:

- S5 RC1 pre-challenge expectation;
- S5 RC3 authority/catalog/consent;
- S5 RC4 privacy retention decision;
- S5 RC5 reachable semantic maxima;
- complete repo-qualified cross-lane owner/path ledger;
- complete canonical integrated fixture manifest;
- `MBI-TRANSPORT-FRAMING-01`;
- Identity cutover;
- `MBI-06` Apple production signing/profile/entitlement/archive evidence; or
- `MBI-07` exact integrated source/dependency/compiler-input/fixture/artifact
  manifest.

Overall S6 integration remains NO-GO even if a future reviewer accepts all
three Packet C formal roots.

## 16. Author P0/P1/P2 classification

This author identified no known internal P0/P1/P2 defect in the Packet C
candidate after static construction. This is self-classification only:

```text
P0: 0
P1: 0
P2: 0
INDEPENDENT REVIEW CREDIT: NONE
```

Missing external proof is not hidden as a false PASS; it is typed as EMPTY,
UNAVAILABLE, and `FORMAL_NO_GO`. A reviewer must adversarially verify the byte
schemas, maxima, DAG, locks, provider barriers, crash windows, and fixture
applicability and may return different counts.

## 17. Preserved stop gates

```text
PACKET C: AUTHOR-FROZEN / INDEPENDENT REVIEW REQUIRED
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

## 18. Final author freeze

```text
PACKET = S6-C DURABILITY / CLIENT / VAULT
INPUT S5 = 0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6
INPUT S5 A REVIEW = dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639
INPUT S5 B REVIEW = 0c98b68d5fdd847289e026173e376ac66dc33f70c7e9d8ebcf22e84573a1c601
INPUT S5 C REVIEW = 36ff7ffc838f15abf99bf281c0a0f1ee584a1423d70bf26bdac3a38b2e3ebbc2

RC2 = PRESERVED / UNCHANGED
RC6 = CLOSED FORMAL CANDIDATE / RESIDUAL EXTERNAL PREMISES / FORMAL_NO_GO
RC7 = CLOSED FORMAL CANDIDATE / RESIDUAL EXTERNAL PREMISES / FORMAL_NO_GO
RC8 = CLOSED FORMAL CANDIDATE / RESIDUAL EXTERNAL PREMISES / FORMAL_NO_GO

PACKET AUTHOR P0/P1/P2 = 0/0/0
INDEPENDENT REVIEW CREDIT = NONE

WIRE OPERATIONS = EXACTLY SIX
ROTATION = REGISTER MUTATION ONLY
TRANSPORT = OPAQUE / BYTE-PRESERVING / NON-AUTHORITATIVE
TOKEN = OPAQUE 1...4096 HAVEN RESOURCE BOUND ONLY
TOKEN/TOKEN-HASH LEAKAGE = FORBIDDEN
LOCAL ABSENCE = NEVER SERVER TRUTH
SERVER DEREGISTER BEFORE LOCAL ERASE = PRESERVED

ALL EXTERNAL PROVIDER/HARDWARE/KEY/CUSTODY/ROLLBACK/STORE/SINK SETS = EMPTY
ALL AFFECTED OPERATIONAL READINESS = UNAVAILABLE

IDENTITY CUTOVER = SEPARATE / NO-GO
MBI-PRIVACY-RETENTION-01 = OPEN / KJETIL
MBI-TRANSPORT-FRAMING-01 = MISSING
MBI-06 = UNAUDITED / MISSING
MBI-07 = MISSING

S6 INTEGRATION = NO-GO
SOURCE AUTHORIZATION = NONE
MATERIAL AUTHORIZATION = NONE
PRODUCTION = NO-GO
```

The only permissible successor is an independent exact-byte static review of
this sole frozen Packet C artifact by a reviewer distinct from the author. No
review, integrator action, source, Git, dependency, build, test, network,
portal, signing, device, APNS, Identity, staging, deployment, integration,
material, or production action is authorized here.
