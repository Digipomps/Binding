# APNS S6 Formal Proof Packet B — Authority and Current-Subject Head

Date: 2026-07-25  
Lane: B, CellScaffold server authority/head formal design only  
Author scope: this file only  
Independent review: required; not performed by this author  
Operational verdict: **NO-GO**

Pre-write path reattestation:

```text
Documentation/APNS_S6_Formal_Proof_Packet_B_Authority_Head_2026-07-25.md
= ABSENT
```

## 0. Scope, immutable inputs, and non-claims

This document works only RC3 and RC4 from the frozen S5 composition. It is a
formal, byte-level construction packet. It is not source authorization, an
implementation, a deployment plan, a production proof, an authority grant, or
an APNS delivery proof.

Exact immutable S5 author input:

```text
path  = Documentation/APNS_S5_Normative_Composition_Contract_Correction_2026-07-24.md
sha256 = 0be6f49d214a94965808952041f65241c57f345635ad74dac18dab2c0ad9cad6
lines = 2554
bytes = 93787
```

Exact immutable independent reviews:

```text
CellProtocol review
sha256 = dcfe3cf1c3332c23f0800cf6e5a60204a17d0debbb674285ef21b280e787c639
terminal P0/P1/P2 = 0/4/2
terminal verdict = S5 NO-GO

CellScaffold review
sha256 = 0c98b68d5fdd847289e026173e376ac66dc33f70c7e9d8ebcf22e84573a1c601
terminal P0/P1/P2 = 0/5/2
terminal verdict = S5 NO-GO

Binding review
sha256 = 36ff7ffc838f15abf99bf281c0a0f1ee584a1423d70bf26bdac3a38b2e3ebbc2
terminal P0/P1/P2 = 0/4/1
terminal verdict = S5 NO-GO
```

All three review verdicts remain terminal for their reviewed S5 bytes. This
packet does not rewrite, supersede, or award retrospective PASS credit to S5.

Exact S6 Packet B applicability:

```text
IN:
  RC3 authority construction DAG, current-generation selectors, revocation
  RC4 current-subject head, signed mutation CAS, transitions, collisions

OUT:
  RC1 response/result schemas and integrated envelope mapping
  RC2 challenge state machine
  RC5 maxima and maximum fixtures
  RC6 Binding vault/expectation/journal graph
  RC7 legacy discovery and disposal
  RC8 source/build/signing/integration proof
  Identity cutover
  production signing/profile/entitlements
  portal, device, APNS, staging, deployment, runtime
```

No source, Git, build, test, network, portal, signing, device, APNS, Identity,
staging, deployment, or material operation is authorized by this document.

## 1. Preserved positive contracts

The following S5 positive contracts remain unchanged:

1. The operation set is exactly:

   ```text
   register
   resolve
   submit
   status
   revoke
   deregister
   ```

2. Register mutation modes are exactly:

   ```text
   enroll
   update
   reactivate
   token_rotation
   ```

3. Status remains read-only: `status` has access `r--s`.

4. Register, revoke, and deregister remain mutations with access `rw-s`.

5. Resolve and submit remain fail-closed and are not granted new authority by
   this packet.

6. The HTTP/TLS wrapper is semantically neutral. A route, socket, TLS
   certificate, process identity, administrator, environment, repository,
   deployment credential, or scaffold owner cannot grant Cell authority.

7. Resolver/Cell verification of exact signed authority bytes is mandatory.
   Agreement alone grants nothing.

8. The APNS token remains opaque, between 1 and 4096 raw bytes for this HAVEN
   resource bound, and must not appear in logs, receipts, status, fixtures,
   filenames, identifiers, or hashes used as observability evidence.

9. Deregister requires authoritative endpoint/token-material removal before
   local erasure is reported complete.

10. Challenge replay and status disclosure remain oracle-safe.

11. Exact production identifiers remain:

    ```text
    bundleIdentifier = org.digipomps.haven
    apnsTopic         = org.digipomps.haven
    origin            = https://haven.digipomps.org
    ```

12. Identity cutover is a separate prerequisite. No Identity readiness is
    inferred here.

RC2's frozen positive contracts are preserved without modification. This
packet neither reopens nor operationally proves RC2:

```text
RC2 static state shape = preserved
RC2 runtime/durability/trusted-time proof = NONE
RC2 affected readiness = UNAVAILABLE
```

## 2. Canonical byte rules used below

Every new `Core` below is canonical UTF-8 JSON:

- one JSON object;
- member order exactly as printed;
- no insignificant whitespace;
- strings use the S5 canonical escaping rules;
- integers are unsigned base-10 JSON integers with no leading zero;
- nullable members are present with JSON `null`;
- arrays preserve the explicitly defined order;
- digest strings are lowercase hexadecimal SHA-256;
- opaque nested canonical bytes are unpadded Base64url strings;
- no unknown member is accepted.

Definitions:

```text
LP(x)       = UInt64BE(byteCount(x)) || x
SHA256Hex(x)= lowercaseHex(SHA256(x))
B64(x)      = canonical unpadded Base64url(x)
U64(x)      = UInt64BE(x)
```

All signed artifacts use the frozen S3/S5 `SignedArtifact` and
domain-separated `SignatureProtectedCore` construction. This packet creates no
alternate signature envelope.

If any required exact bytes, trusted signer, trusted time, rollback proof,
durable current-head proof, or Resolver verification is absent:

```text
accepted set = EMPTY
readiness    = UNAVAILABLE
mutation     = NO COMMIT
```

## 3. RC3: acyclic authority construction DAG

### 3.1 Cycle being removed

S5 has an unconstructible cycle:

```text
SubjectTargetBindingCore v2
  -> authorityCatalogSHA256
  -> consentSHA256

ConsentArtifactCore v2
  -> subjectTargetBindingSHA256

AuthorizationCatalogEntryCore v2
  -> exact SubjectTargetBindingArtifact
  -> exact ConsentArtifact

AuthorizationCatalogArtifact
  -> AuthorizationCatalogEntryCore
```

There is no first exact byte string that can satisfy those digest equations.
Random IDs or fixed-point iteration do not make the construction canonical.

### 3.2 Replacement construction order

The only accepted construction order in this packet is:

```text
M  AuthorityManifestArtifact                 external prerequisite
S  OwnerDelegationScopeCore                  tuple bytes
D  CatalogSignerDelegationArtifact v2        optional, owner signed
B  SubjectTargetBindingArtifact v3           owner/direct-or-delegate signed
A  AgreementArtifact                         external prerequisite
C  ContractArtifact                          external prerequisite
G  GrantArtifact                             external prerequisite
K  ConditionsArtifact                        external prerequisite
N  ConsentArtifact v3                        requester signed
Q  AuthorizationTupleCore v1                 complete immutable tuple
E  AuthorizationCatalogEntryCore v3          contains completed artifacts
L  AuthorizationCatalogArtifact v2           owner/direct-or-delegate signed
T* AuthorityHeadMutationArtifact             exact install/replace/revoke
H* Authority current-head/status artifacts   produced after T commits
U  AuthorizationUseSelectorCore v1           use-time current selectors
I  IntentArtifact                            binds L, E, Q, U
Ch ChallengeArtifact                         binds I and operation bytes
R  RequestArtifact                           binds I, Ch and operation bytes
```

Edges point only from a later node to an earlier node:

```text
M -> none in this packet
S -> immutable tuple scalars and external artifact digests
D -> M,S
B -> M,S,D?,A,C,G,K
N -> M,S,B,A,C,G,K
Q -> M,S,D?,B,A,C,G,K,N
E -> Q,D?,B,A,C,G,K,N
L -> M,D?,E[]
T* -> one completed artifact; expected prior head values are scalars, not a digest edge
H* -> T* and one completed artifact
U -> L,E,Q,H*
I -> L,E,Q,U
Ch -> I
R -> I,Ch
```

No B, N, Q, or E member contains `authorizationCatalogSHA256`. No B member
contains `consentSHA256`. No D member contains B, N, E, or L. Therefore the
graph is acyclic and every digest is computable in the stated order.

### 3.3 OwnerDelegationScopeCore v1

Schema:

```text
cellprotocol.device-ingress.owner-delegation-scope-core.v1
```

Exact member order:

1. `action`
2. `agreementSHA256`
3. `audience`
4. `authorityManifestSHA256`
5. `capability`
6. `conditionsSHA256`
7. `contractSHA256`
8. `grantSHA256`
9. `identityDomain`
10. `mutationMode`
11. `operation`
12. `purpose`
13. `requesterDescriptorSHA256`
14. `requiredAccess`
15. `resource`
16. `responseSignerAlgorithm`
17. `responseSignerDescriptorSHA256`
18. `responseSignerKeyID`
19. `schema`
20. `statusKind`
21. `targetCellID`
22. `targetOwnerDescriptorSHA256`

The nullable rules are exact:

```text
operation=register   -> mutationMode non-null, statusKind null
operation=status     -> mutationMode null, statusKind non-null
all other operations -> mutationMode null, statusKind null
```

`requiredAccess` is the complete four-position RWXS string. The exact scope
digest is:

```text
ownerDelegationScopeSHA256 =
  SHA256Hex(exact OwnerDelegationScopeCore v1 bytes)
```

### 3.4 CatalogSignerDelegationCore v2

Schema:

```text
cellprotocol.device-ingress.catalog-signer-delegation-core.v2
```

Exact member order:

1. `authorityManifestSHA256`
2. `delegatedSignerAlgorithm`
3. `delegatedSignerDescriptorSHA256`
4. `delegatedSignerKeyID`
5. `delegationGeneration`
6. `delegationID`
7. `expiresAtMilliseconds`
8. `issuedAtMilliseconds`
9. `ownerDelegationScope`
10. `ownerDelegationScopeSHA256`
11. `permittedArtifactKinds`
12. `revocationGeneration`
13. `schema`
14. `targetOwnerDescriptorSHA256`

`ownerDelegationScope` is B64 of the exact core in 3.3. Its decoded digest must
equal `ownerDelegationScopeSHA256`.

`permittedArtifactKinds` is sorted, duplicate-free, and is a non-empty subset
of exactly:

```text
authorization_catalog
subject_target_binding
```

```text
delegationID = "csd1_" || B64(CSPRNG(32))
```

The delegation artifact is signed only by the exact target owner authorized
by M. It is never signed by the delegated signer itself. D cannot change the
subject, target, owner, Contract, Agreement, Grant, Conditions, response
signer, operation, access, purpose, audience, or nullability in S.

Direct path:

```text
catalogSignerDelegationArtifact = null
catalogSignerDelegationSHA256   = null
artifact signer                 = exact target owner
```

Delegated path:

```text
catalogSignerDelegationArtifact = exact D bytes
catalogSignerDelegationSHA256   = SHA256Hex(D)
artifact signer                 = exact delegated signer named by D
D permitted kind                = artifact kind being verified
D scope                         = byte-equal S
```

Mixed nullability is rejected.

### 3.5 SubjectTargetBindingCore v3

Schema:

```text
cellprotocol.device-ingress.subject-target-binding-core.v3
```

Exact member order:

1. `action`
2. `agreementSHA256`
3. `audience`
4. `authorityGeneration`
5. `authorityManifestSHA256`
6. `bindingGeneration`
7. `bindingID`
8. `capability`
9. `catalogSignerDelegationSHA256`
10. `conditionsSHA256`
11. `contractSHA256`
12. `expiresAtMilliseconds`
13. `grantSHA256`
14. `identityDomain`
15. `issuedAtMilliseconds`
16. `mutationMode`
17. `operation`
18. `ownerDelegationScopeSHA256`
19. `purpose`
20. `requesterDescriptorSHA256`
21. `requiredAccess`
22. `resource`
23. `responseSignerAlgorithm`
24. `responseSignerDescriptorSHA256`
25. `responseSignerKeyID`
26. `revocationGeneration`
27. `schema`
28. `statusKind`
29. `targetCellID`
30. `targetOwnerDescriptorSHA256`

Removed relative to S5 v2:

```text
authorityCatalogSHA256
catalogGeneration
consentGeneration
consentSHA256
responseSigner opaque nested ref
```

The response-signer triple is explicit and participates in exact equality.
The binding is signed by the exact target owner or by D only under 3.4.

```text
bindingID = "stb1_" || B64(CSPRNG(32))
```

The stable current-binding namespace does not include random `bindingID`:

```text
bindingHeadKey =
  SHA256Hex(
    LP(UTF8("HAVEN-DEVICE-INGRESS-AUTHORITY-HEAD-V1"))
    || LP(UTF8("subject_target_binding"))
    || LP(exact OwnerDelegationScopeCore v1 bytes)
  )
```

`bindingID` remains a non-authoritative collision-resistant artifact
identifier. It is not a current selector.

The stable current-delegation namespace does not include random
`delegationID`:

```text
delegationHeadKey =
  SHA256Hex(
    LP(UTF8("HAVEN-DEVICE-INGRESS-AUTHORITY-HEAD-V1"))
    || LP(UTF8("catalog_signer_delegation"))
    || LP(raw authorityManifestSHA256)
    || LP(raw targetOwnerDescriptorSHA256)
    || LP(raw ownerDelegationScopeSHA256)
  )
```

### 3.6 ConsentArtifactCore v3

Schema:

```text
cellprotocol.device-ingress.consent-artifact-core.v3
```

Exact member order:

1. `action`
2. `agreementSHA256`
3. `audience`
4. `authorityManifestSHA256`
5. `capability`
6. `conditionsSHA256`
7. `consentGeneration`
8. `consentID`
9. `contractSHA256`
10. `expiresAtMilliseconds`
11. `grantSHA256`
12. `identityDomain`
13. `issuedAtMilliseconds`
14. `mutationMode`
15. `operation`
16. `ownerDelegationScopeSHA256`
17. `purpose`
18. `requesterDescriptorSHA256`
19. `requiredAccess`
20. `resource`
21. `responseSignerAlgorithm`
22. `responseSignerDescriptorSHA256`
23. `responseSignerKeyID`
24. `revocationGeneration`
25. `schema`
26. `statusKind`
27. `subjectTargetBindingSHA256`
28. `targetCellID`
29. `targetOwnerDescriptorSHA256`
30. `termsNoticeSHA256`

N is signed only by the requester descriptor named in N. It is constructed
after B and references B. It contains no catalog or catalog-entry digest.

```text
consentID = "cns1_" || B64(CSPRNG(32))
```

The stable current-consent namespace does not include random `consentID`:

```text
consentHeadKey =
  SHA256Hex(
    LP(UTF8("HAVEN-DEVICE-INGRESS-AUTHORITY-HEAD-V1"))
    || LP(UTF8("consent"))
    || LP(exact OwnerDelegationScopeCore v1 bytes)
    || LP(raw subjectTargetBindingSHA256)
    || LP(raw termsNoticeSHA256)
  )
```

Consent withdrawal is not absence. It is a signed transition of the current
consent head to `revoked`, with an incremented revocation generation.

### 3.7 AuthorizationTupleCore v1

Schema:

```text
cellprotocol.device-ingress.authorization-tuple-core.v1
```

Exact member order:

1. `action`
2. `agreementSHA256`
3. `audience`
4. `authorityManifestSHA256`
5. `capability`
6. `catalogSignerDelegationSHA256`
7. `conditionsSHA256`
8. `consentSHA256`
9. `contractSHA256`
10. `grantSHA256`
11. `identityDomain`
12. `mutationMode`
13. `operation`
14. `ownerDelegationScopeSHA256`
15. `purpose`
16. `requesterDescriptorSHA256`
17. `requiredAccess`
18. `resource`
19. `responseSignerAlgorithm`
20. `responseSignerDescriptorSHA256`
21. `responseSignerKeyID`
22. `schema`
23. `statusKind`
24. `subjectTargetBindingSHA256`
25. `targetCellID`
26. `targetOwnerDescriptorSHA256`
27. `termsNoticeSHA256`

Every value is byte-equal to S, B, A, C, G, K, and N wherever the value is
present. The complete digest is:

```text
authorizationTupleSHA256 =
  SHA256Hex(exact AuthorizationTupleCore v1 bytes)
```

Substitution of signer, delegated signer, requester subject, target Cell,
target owner, Contract, Agreement, Grant, Conditions, consent, operation,
mode, status kind, response signer, access, purpose, audience, capability, or
nullability changes Q and is rejected.

### 3.8 AuthorizationCatalogEntryCore v3

Schema:

```text
cellprotocol.device-ingress.authorization-catalog-entry-core.v3
```

Exact member order:

1. `agreementArtifact`
2. `agreementSHA256`
3. `authorizationTuple`
4. `authorizationTupleSHA256`
5. `catalogSignerDelegationArtifact`
6. `catalogSignerDelegationSHA256`
7. `conditionsArtifact`
8. `conditionsSHA256`
9. `consentArtifact`
10. `consentSHA256`
11. `contractArtifact`
12. `contractSHA256`
13. `entryGeneration`
14. `entryID`
15. `grantArtifact`
16. `grantSHA256`
17. `notAfterMilliseconds`
18. `notBeforeMilliseconds`
19. `schema`
20. `subjectTargetBindingArtifact`
21. `subjectTargetBindingSHA256`

Artifact fields are B64 exact signed bytes. Paired digests must reproduce.
Delegation pair nullability follows 3.4.

```text
entryID = "ace1_" || B64(CSPRNG(32))
```

The stable current-entry namespace does not include random `entryID` and does
not include catalog digest:

```text
catalogEntryHeadKey =
  SHA256Hex(
    LP(UTF8("HAVEN-DEVICE-INGRESS-AUTHORITY-HEAD-V1"))
    || LP(UTF8("authorization_catalog_entry"))
    || LP(exact AuthorizationTupleCore v1 bytes)
  )
```

### 3.9 AuthorizationCatalogArtifact v2

The catalog core is constructed only after every E is complete. It contains:

```text
authorityManifestSHA256
catalogGeneration
catalogID
catalogSignerDelegationSHA256 or null
entries, sorted by raw authorizationTupleSHA256 then raw entryID
issuedAtMilliseconds
notAfterMilliseconds
notBeforeMilliseconds
revocationGeneration
schema = cellprotocol.device-ingress.authorization-catalog-core.v2
targetCellID
targetOwnerDescriptorSHA256
```

`catalogID` is a collision-resistant identifier:

```text
catalogID = "acat1_" || B64(CSPRNG(32))
```

The exact canonical member order is the order printed above. Each `entries`
element is B64 exact AuthorizationCatalogEntryCore v3 bytes.

The stable catalog namespace is:

```text
catalogHeadKey =
  SHA256Hex(
    LP(UTF8("HAVEN-DEVICE-INGRESS-AUTHORITY-HEAD-V1"))
    || LP(UTF8("authorization_catalog"))
    || LP(raw authorityManifestSHA256)
    || LP(UTF8(targetCellID))
    || LP(raw targetOwnerDescriptorSHA256)
  )
```

The catalog is signed by the target owner directly or the exact D signer.
Neither B nor N points back to L.

## 4. RC3: byte-total current-generation and revocation selectors

### 4.1 AuthorityArtifactRefCore v1

Schema:

```text
cellprotocol.device-ingress.authority-artifact-ref-core.v1
```

Exact member order:

1. `artifactID`
2. `artifactKind`
3. `artifactSHA256`
4. `generation`
5. `headKey`
6. `ownerDescriptorSHA256`
7. `revocationGeneration`
8. `schema`
9. `signerAlgorithm`
10. `signerDescriptorSHA256`
11. `signerKeyID`

Closed `artifactKind` in this packet:

```text
authority_manifest
catalog_signer_delegation
subject_target_binding
agreement
contract
grant
conditions
consent
authorization_catalog_entry
authorization_catalog
```

For an external artifact whose native schema has no compatible generation,
revocation generation, current-head namespace, or owner, the ref cannot be
constructed. The verifier returns `UNAVAILABLE`; it does not insert zero or
infer ownership.

### 4.2 AuthorityCurrentHeadCore v1

Schema:

```text
cellprotocol.device-ingress.authority-current-head-core.v1
```

Exact member order:

1. `currentArtifactRef`
2. `currentArtifactRefSHA256`
3. `headEpoch`
4. `headGeneration`
5. `headKey`
6. `lifecycleState`
7. `revocationGeneration`
8. `schema`

`currentArtifactRef` is B64 exact AuthorityArtifactRefCore v1 bytes.

Closed lifecycle:

```text
active
revoked
```

There is exactly one durable row:

```text
UNIQUE(compositionVersion, headKey)
```

```text
headEpoch = "ahep1_" || B64(CSPRNG(32))
```

Creation uses expected no-row, generation zero, and creates a random
head epoch. Every accepted replace or revoke operation increments
`headGeneration` by exactly one under CAS. Replacement increments the artifact
generation by exactly one. Revocation increments `revocationGeneration` by
exactly one. Overflow is `UNAVAILABLE` with no commit.

The immutable artifact bytes never self-identify as current. Only an
authoritative current-head row and its signed status select current bytes.

### 4.3 AuthorityHeadStatusCore v1

Schema:

```text
cellprotocol.device-ingress.authority-head-status-core.v1
```

Exact member order:

1. `artifactRefSHA256`
2. `freshUntilMilliseconds`
3. `headEpoch`
4. `headGeneration`
5. `headKey`
6. `issuedAtMilliseconds`
7. `lifecycleState`
8. `revocationGeneration`
9. `schema`
10. `statusAuthorityDescriptorSHA256`
11. `statusSequence`
12. `targetCellID`
13. `targetOwnerDescriptorSHA256`

It is wrapped in the existing SignedArtifact form with:

```text
artifactKind = authority_head_status
```

For each `(targetCellID, headKey)`, `statusSequence` starts at 1 and increases
by exactly one for each newly signed status outcome. Exact replay returns the
stored status artifact and consumes no sequence. Same-sequence different bytes,
sequence rollback, sequence overflow, or multiple current status rows is
`UNAVAILABLE`. `currentArtifactRef` generation/revocation and the corresponding
AuthorityCurrentHeadCore values must be byte/numerically equal.

The accepted status signer is type-specific:

```text
authority_manifest:
  exact externally accepted manifest-status authority

catalog_signer_delegation, subject_target_binding,
contract, grant, conditions, authorization_catalog_entry,
authorization_catalog:
  exact target owner

agreement, consent:
  exact requester subject
```

A different signer is acceptable only under a separately typed, owner-signed
status delegation whose exact bytes, scope, generation, revocation, and
current selector are themselves in the accepted chain. No such bytes are
present here, so this alternative accepted set is EMPTY.

`AuthorityHeadStatusCore.lifecycleState` also permits `superseded` only for a
historical artifact ref that is no longer selected by the current head. A
current AuthorityCurrentHeadCore row can never have that state.

If an artifact type's legitimate authority differs from the mapping above,
that is an owner decision and missing bound input. The server may not guess.

### 4.4 AuthorityGenerationSelectorCore v1

Schema:

```text
cellprotocol.device-ingress.authority-generation-selector-core.v1
```

Exact member order:

1. `artifactKind`
2. `artifactRef`
3. `artifactRefSHA256`
4. `authorityHeadStatusArtifact`
5. `authorityHeadStatusArtifactSHA256`
6. `expectedHeadEpoch`
7. `expectedHeadGeneration`
8. `expectedRevocationGeneration`
9. `schema`

Both nested members are B64 exact bytes. Digests must reproduce. Every
expected value must equal the signed status and the durable target current
head at use time. Status must be fresh under accepted trusted time and at or
above the rollback anchor.

The selector is total:

| Condition | Result |
|---|---|
| exact active ref, head, status, signer, time, rollback | selected |
| signed lifecycle revoked or superseded | not selected |
| wrong artifact, signer, owner, subject, target, tuple, or digest | reject |
| stale generation/revocation/status sequence | reject |
| two heads or two same-generation candidates | unavailable |
| missing current head/status/trusted time/rollback | unavailable |
| overflow or durable read-back failure | unavailable |

`not selected` is a verified negative state. `unavailable` is not converted
to inactive or absent.

### 4.5 AuthorityHeadMutationCore v1

Schema:

```text
cellprotocol.device-ingress.authority-head-mutation-core.v1
```

Exact member order:

1. `artifactKind`
2. `expectedArtifactRefSHA256`
3. `expectedHeadEpoch`
4. `expectedHeadGeneration`
5. `expectedLifecycleState`
6. `expectedRevocationGeneration`
7. `headKey`
8. `mutation`
9. `newArtifact`
10. `newArtifactRef`
11. `newArtifactRefSHA256`
12. `schema`
13. `transitionID`

Closed `mutation`:

```text
install
replace
revoke
```

`newArtifact` is B64 exact completed artifact bytes.
`newArtifactRef` is B64 exact AuthorityArtifactRefCore v1 bytes. Paired
digests must reproduce.

Exact shapes:

| mutation | expected state/ref/epoch | new artifact/ref | new current state |
|---|---|---|---|
| install | absent, null ref, null epoch, head gen 0, rev gen 0 | non-null, artifact gen 1, rev gen 0 | active, new epoch, head gen 1 |
| replace | active or revoked, exact ref/epoch/current generations | non-null, artifact gen old+1, same rev gen | active, same epoch, head gen old+1 |
| revoke | active, exact ref/epoch/current generations | both null | revoked, same ref/epoch, head gen old+1, rev gen old+1 |

`expectedLifecycleState` is exactly `absent|active|revoked`; `absent` is
permitted only for install. The `newArtifact`/ref pair is both null for revoke
and both non-null otherwise. The replacement artifact's native signed bytes
must carry or be bound by its ref generation. If its native schema cannot do
so, replacement is `UNAVAILABLE`.

```text
transitionID = "ahm1_" || B64(CSPRNG(32))
```

The core is wrapped in the frozen SignedArtifact form with:

```text
artifactKind = authority_head_mutation
```

The required mutation signer is the same exact controller named for that
artifact kind in 4.3. In particular, consent withdrawal requires the exact
requester signature; delegation, binding, catalog entry, and catalog mutation
require the exact target owner. External manifest/Agreement/Contract/Grant/
Conditions transitions use this generic mutation only if their separately
reviewed native authority contract accepts the exact same controller and
generation semantics. Otherwise their mutation accepted set is EMPTY.

The target stores an immutable transition row containing the exact signed
mutation artifact, prior current head bytes/digest, new current head
bytes/digest, admission ID, commit sequence, and rollback sequence. This is the
exact durable revocation/withdrawal ledger; absence is not revocation.

### 4.6 AuthorizationUseSelectorCore v1

Schema:

```text
cellprotocol.device-ingress.authorization-use-selector-core.v1
```

Exact member order:

1. `agreementSelector`
2. `authorizationCatalogEntrySelector`
3. `authorizationCatalogSelector`
4. `authorizationTupleSHA256`
5. `authorityManifestSelector`
6. `catalogSignerDelegationSelector`
7. `conditionsSelector`
8. `consentSelector`
9. `contractSelector`
10. `grantSelector`
11. `schema`
12. `subjectTargetBindingSelector`

Each selector is B64 exact AuthorityGenerationSelectorCore v1 bytes.
`catalogSignerDelegationSelector` is null only on the direct-owner path.

All selectors must resolve to `selected`, all artifacts must reproduce Q, and
the signer/delegation/subject/target/owner/Contract tuple must be byte-equal.
Intent, Challenge, and Request bind:

```text
authorizationCatalogArtifactSHA256
authorizationCatalogEntrySHA256
authorizationTupleSHA256
authorizationUseSelectorSHA256
```

The HTTP wrapper forwards only exact bytes and cannot add, repair, select, or
grant authority.

### 4.7 RC3 CAS and rollback behavior

The lock order for authority-head mutation is:

```text
1 targetCellID
2 authority headKey
3 expected current artifact digest, when present
4 admissionID
```

Within one target transaction:

1. verify exact requester and target owner;
2. verify exact signer path and D nullability;
3. verify current head from stable media and rollback anchor;
4. compare expected head epoch, head generation, artifact generation, and
   revocation generation;
5. verify exact signed AuthorityHeadMutationCore bytes and signer;
6. commit new immutable artifact, current head, signed outcome, admission
   outcome, and rollback advance;
7. read back all bytes, digests, indexes, and anchor;
8. expose the new selector only after successful read-back.

Concurrent candidates with the same expected head have exactly one winner.
Every loser receives the frozen generation-conflict family, with no mutation.
Exact replay of a winning admission returns stored outcome bytes and performs
no new signature or state transition.

Restore below the accepted rollback anchor, duplicate current heads, a
same-generation different digest, a stale selector, or a missing authoritative
status makes the accepted set EMPTY.

## 5. RC3 authority acceptance equation

For operation tuple `q`, authority is accepted iff:

```text
AcceptedAuthority(q, now, durableState) =
  Canonical(M,D?,B,A,C,G,K,N,Q,E,L,U)
  ∧ AcyclicConstructionOrder(M,D?,B,A,C,G,K,N,Q,E,L,U)
  ∧ DigestClosure(M,D?,B,A,C,G,K,N,Q,E,L,U)
  ∧ ExactTupleEquality(S,B,N,Q,E,L,U,q)
  ∧ DirectOrExactDelegation(D?,B,L)
  ∧ ExactSubjectSigner(N)
  ∧ ExactTargetOwner(M,B,D?,L)
  ∧ EverySelectorSelected(U,durableState)
  ∧ TrustedTimeWithinAllBounds(now)
  ∧ RollbackAnchorsCurrent(durableState)
  ∧ ResolverAllows(q,U)
```

No term can be omitted. Failure of a verified negative term rejects.
Unavailable evidence yields `UNAVAILABLE`.

Current frozen accepted inputs are:

```text
accepted M = EMPTY
accepted D = EMPTY
accepted B = EMPTY
accepted A = EMPTY
accepted C = EMPTY
accepted G = EMPTY
accepted K = EMPTY
accepted N = EMPTY
accepted E = EMPTY
accepted L = EMPTY
accepted authority/status signers = EMPTY
accepted trusted-time providers = EMPTY
accepted rollback providers = EMPTY
```

Therefore:

```text
AcceptedAuthority = EMPTY
CellScaffold authority readiness = UNAVAILABLE
```

This empty-set result is mandatory and receives no production PASS credit.

## 6. RC4: signed current-subject-head expectation

### 6.1 CurrentSubjectHeadCore v2

Schema:

```text
cellscaffold.device-ingress.current-subject-head-core.v2
```

Exact member order:

1. `currentRegistrationID`
2. `epochAllocationGeneration`
3. `headEpoch`
4. `headGeneration`
5. `headKey`
6. `identityDomain`
7. `lastDisclosableTombstoneSHA256`
8. `lifecycleState`
9. `registrationGeneration`
10. `requesterDescriptorSHA256`
11. `revocationGeneration`
12. `schema`
13. `targetCellID`

Closed lifecycle:

```text
active
revoked
empty_after_deregister
```

The head key remains:

```text
headKey =
  SHA256Hex(
    LP(UTF8(compositionVersion))
    || LP(UTF8(identityDomain))
    || LP(raw requesterDescriptorSHA256)
    || LP(UTF8(targetCellID))
  )
```

There is exactly one current row:

```text
UNIQUE(compositionVersion, headKey)
```

### 6.2 Head epoch allocation

A new head epoch is allocated only when no accepted head exists and the target
can prove one of:

```text
never_initialized
deleted_under_accepted_owner_policy
```

The target maintains a monotonic, non-subject-specific epoch allocation
generation under an independently proven rollback anchor.

```text
headEpochRaw =
  SHA256(
    LP(UTF8("HAVEN-DEVICE-INGRESS-SUBJECT-HEAD-EPOCH-V1"))
    || LP(UTF8(targetCellID))
    || LP(raw headKey)
    || LP(U64(epochAllocationGeneration))
    || LP(CSPRNG(32))
  )

headEpoch = "hep1_" || B64(headEpochRaw)
```

`epochAllocationGeneration` is incremented and committed atomically with the
new head. A reused generation, repeated random bytes, repeated derived epoch,
rollback, missing allocation ledger, missing stable-media proof, or overflow
is `UNAVAILABLE` with no visible partial row.

This packet does not supply a storage engine, rollback provider, or accepted
owner-policy deletion proof. Their accepted sets remain EMPTY.

### 6.3 SubjectHeadExpectationCore v1

Schema:

```text
cellprotocol.device-ingress.subject-head-expectation-core.v1
```

Exact member order:

1. `expectedHeadEpoch`
2. `expectedHeadGeneration`
3. `expectedHeadKey`
4. `expectedLifecycleState`
5. `expectedRegistrationGeneration`
6. `expectedRegistrationID`
7. `expectedRevocationGeneration`
8. `headStatusAdmissionID`
9. `headStatusFreshUntilMilliseconds`
10. `headStatusOutcomeSHA256`
11. `schema`

Closed `expectedLifecycleState`:

```text
absent_never_initialized
absent_after_policy_deletion
active
revoked
empty_after_deregister
```

Nullability:

| expected lifecycle | head epoch | head gen | registration ID | registration gen | revocation gen |
|---|---|---:|---|---:|---:|
| absent_never_initialized | null | 0 | null | 0 | 0 |
| absent_after_policy_deletion | null | 0 | null | 0 | 0 |
| active | non-null | positive | non-null | positive | current |
| revoked | non-null | positive | non-null | positive | positive current |
| empty_after_deregister | non-null | positive | null | 0 | current retained value |

`headStatusAdmissionID` identifies the exact durable status admission.
`headStatusOutcomeSHA256` identifies its exact signed stored outcome.
The server must load the outcome by admission ID, reproduce its hash, verify
the signed response and response signer, verify subject/target/head equality,
verify freshness, and compare it with the current durable row.

The status outcome bytes and their final RC1 result mapping are not defined by
this Packet B. Until an independently reviewed integrated mapping supplies
them:

```text
constructible production SubjectHeadExpectationCore = EMPTY
mutation availability = UNAVAILABLE
```

This is an explicit cross-packet prerequisite, not permission to invent RC1
bytes.

### 6.4 RegisterBodyCore v3

Schema:

```text
cellprotocol.device-ingress.register-body-core.v3
```

Exact member order:

1. `apnsEnvironment`
2. `apnsToken`
3. `apnsTopic`
4. `bundleIdentifier`
5. `consentArtifactSHA256`
6. `expectedRegistrationGeneration`
7. `expectedRevocationGeneration`
8. `headExpectation`
9. `headExpectationSHA256`
10. `mutationMode`
11. `registrationID`
12. `schema`
13. `tokenDeliveryEpoch`
14. `tokenObservationID`

`headExpectation` is B64 exact SubjectHeadExpectationCore v1 bytes.

```text
headExpectationSHA256 =
  SHA256Hex(exact decoded SubjectHeadExpectationCore v1 bytes)
```

The inherited expected registration/revocation members must equal the nested
head expectation. A mismatch rejects before admission mutation.

Production-only composition additionally requires exact equality:

```text
apnsEnvironment = production
apnsTopic        = org.digipomps.haven
bundleIdentifier = org.digipomps.haven
audience/origin  = https://haven.digipomps.org
```

The origin is bound by the exact authorization/intent/request tuple, not
invented from the HTTP `Host` header. Any environment/topic/bundle/origin
mismatch rejects. The raw token remains confined to the protected register
body and target token store; no result, error, status, transition evidence,
fixture, or log may expose it or its digest.

Exact mode applicability:

| mode | expected lifecycle | registrationID |
|---|---|---|
| enroll, first | absent_never_initialized | null |
| enroll, retained empty head | empty_after_deregister | null |
| enroll, policy-deleted head | absent_after_policy_deletion | null |
| update | active | exact current |
| token_rotation | active | exact current |
| reactivate | revoked | exact current |

Every field above is covered by the body digest and therefore by Intent,
Challenge, Request, and requester signature.

### 6.5 RevokeBodyCore v2

Schema:

```text
cellprotocol.device-ingress.revoke-body-core.v2
```

Exact member order:

1. `expectedRegistrationGeneration`
2. `expectedRevocationGeneration`
3. `headExpectation`
4. `headExpectationSHA256`
5. `reasonCode`
6. `registrationID`
7. `schema`

The expectation must be `active` and identify the exact current registration.
The inherited generation members must equal the nested expectation.

### 6.6 DeregisterBodyCore v2

Schema:

```text
cellprotocol.device-ingress.deregister-body-core.v2
```

Exact member order:

1. `deletionMode`
2. `expectedRegistrationGeneration`
3. `expectedRevocationGeneration`
4. `headExpectation`
5. `headExpectationSHA256`
6. `reasonCode`
7. `registrationID`
8. `schema`

The expectation must be `active` or `revoked` and identify the exact current
registration. The inherited generation members must equal it.

The only deletion mode remains:

```text
endpoint_and_token_material
```

No privacy-erasure claim is added.

### 6.7 Operation applicability

| operation | head expectation in signed body | mutates current subject head |
|---|---|---|
| register/enroll | required | yes |
| register/update | required | yes |
| register/reactivate | required | yes |
| register/token_rotation | required | yes |
| revoke | required | yes |
| deregister | required | yes |
| status | not in status body | no; produces observation prerequisite |
| resolve | not applicable | no |
| submit | not applicable | no |

Resolve and submit gain no head-derived authority.

## 7. RC4 total transitions

### 7.1 Atomic state transition equation

For mutation request `r`:

```text
Commit(r) iff
  AcceptedAuthority(r.tuple) = true
  ∧ ExactSignedBody(r)
  ∧ ExactFreshHeadStatus(r.headExpectation)
  ∧ DurableCurrentHead = r.headExpectation
  ∧ RegistrationRowConsistent(DurableCurrentHead)
  ∧ DeliveryLookupConsistent(DurableCurrentHead)
  ∧ AdmissionReplayDecision(r.admissionID) = new
  ∧ CAS(DurableCurrentHead, NextHead(r)) succeeds
  ∧ AtomicDurableCommitAndReadBack succeeds
  ∧ RollbackAnchorAdvanceAndReadBack succeeds
```

If any term is false or unavailable, no mutation commits.

### 7.2 Lock order

Every applicable mutation locks in this order:

```text
1 headKey
2 currentRegistrationID, when present
3 admissionID
4 registration row
5 delivery lookup row
6 epoch allocation row, only when creating a new head epoch
```

No branch reverses this order.

### 7.3 Transition table

| Request | Required old head | Exact new head |
|---|---|---|
| first enroll | accepted absent-never-initialized proof | allocate epoch, allocation gen +1, head gen 1, active, new registration ID, reg gen 1, rev gen 0 |
| enroll after deregister | same epoch, exact empty head | same epoch, head gen +1, active, new registration ID, reg gen 1, retained rev gen |
| enroll after policy deletion | accepted absent-after-policy-deletion proof | allocate new epoch, allocation gen +1, head gen 1, active, new registration ID, reg gen 1, rev gen 0 |
| update | exact active head | same epoch/ID, head gen +1, reg gen +1, rev gen unchanged |
| token rotation | exact active head | same epoch/ID, head gen +1, reg gen +1, rev gen unchanged |
| reactivate | exact revoked head | same epoch/ID, head gen +1, reg gen +1, active, rev gen unchanged |
| revoke | exact active head | same epoch/ID, head gen +1, reg gen unchanged, rev gen +1, revoked |
| deregister | exact active or revoked head | only after endpoint/token deletion: same epoch, head gen +1, current ID null, reg gen null/encoded 0, empty-after-deregister |

Every `+1` is checked UInt64 addition. Overflow returns unavailable with no
commit.

### 7.4 HeadTransitionEvidenceCore v1

Schema:

```text
cellscaffold.device-ingress.head-transition-evidence-core.v1
```

Exact member order:

1. `admissionID`
2. `bodySHA256`
3. `newCurrentRegistrationID`
4. `newHeadEpoch`
5. `newHeadGeneration`
6. `newLifecycleState`
7. `newRegistrationGeneration`
8. `newRevocationGeneration`
9. `operation`
10. `previousCurrentRegistrationID`
11. `previousHeadEpoch`
12. `previousHeadGeneration`
13. `previousLifecycleState`
14. `previousRegistrationGeneration`
15. `previousRevocationGeneration`
16. `requestArtifactSHA256`
17. `schema`
18. `targetCommitSequence`

Nullable previous and new members remain present. Exact bytes and digest must
be stored in the admission outcome transaction and returned in the
operation-specific signed result.

Packet B defines these evidence bytes but does not assign them to the
still-open RC1 result union. Until integrated result schemas are independently
reviewed:

```text
accepted mutation response mapping = EMPTY
end-to-end mutation readiness = UNAVAILABLE
```

### 7.5 Transaction contents

One stable transaction commits:

```text
current subject head
registration row
delivery lookup
endpoint/token-material state
admission row
stored exact operation outcome
HeadTransitionEvidenceCore bytes and digest
epoch allocation row, when applicable
rollback sequence/anchor intent
```

The provider must then prove stable-media durability, reopen/read-back exact
bytes and indexes, advance the rollback anchor, and read it back. No storage
provider proof is supplied in this packet.

### 7.6 Replay, concurrency, and collisions

Exact replay:

```text
same admission ID + same authenticated request digest
  -> exact stored response bytes
  -> no new signature
  -> no new generation
  -> no new mutation
```

Admission collision:

```text
same admission ID + different authenticated request digest
  -> replay_conflict
  -> no disclosure
  -> no mutation
```

Concurrent mutation:

```text
two requests with same expected head epoch/generation
  -> lock/CAS permits exactly one commit
  -> loser = generation_conflict
  -> retryClass = status_only
  -> terminal for the old request bytes
```

Registration-ID or head-epoch collision during allocation:

```text
collision detected before visible commit
  -> discard candidate
  -> retry CSPRNG allocation within bounded owner-approved attempt count
  -> if bound absent or exhausted: target_unavailable, no commit
```

This packet does not choose the attempt count. Until supplied by the owner:

```text
collision retry bound = MISSING BOUND INPUT
allocation after one collision = UNAVAILABLE
```

Old signed mutation after deregister/re-enroll:

```text
old head epoch/generation != current head epoch/generation
  -> generation_conflict
  -> no mutation
```

Old signed mutation after policy deletion/recreation:

```text
old head epoch != newly allocated head epoch
  -> generation_conflict or privacy_unknown under disclosure policy
  -> no mutation
```

Random registration-ID reuse cannot restore authority because current head
epoch, head generation, requester, target, registration generation, and
revocation generation must all match.

### 7.7 Error/outcome table

| Condition | Public error family | retry class | mutation |
|---|---|---|---|
| exact stale head epoch/generation | `generation_conflict` | `status_only` | none |
| lifecycle does not permit operation | `invalid_operation_state` | `status_only` | none |
| stale status outcome/freshness | `generation_conflict` | `status_only` | none |
| wrong subject or undisclosable ID | `privacy_unknown` | `status_only` | none |
| admission ID collision | `replay_conflict` | `never_same_bytes` | none |
| missing authority or signed head status | `authority_unavailable` | `after_authority_recovery` | none |
| trusted-time provider unavailable | `trusted_time_unavailable` | `after_authority_recovery` | none |
| store/read-back/rollback unavailable | `target_unavailable` | `after_authority_recovery` | none |
| duplicate head/same-generation fork | `target_unavailable` | `after_authority_recovery` | none |
| generation overflow | `target_unavailable` | terminal | none |
| privacy deletion decision absent | `authority_unavailable` | `after_authority_recovery` | none |

All error literals and retry classes in this table are members of the frozen
S5 `AuthenticatedErrorCore v2` mapping. Trusted-time provider failure uses
`trusted_time_unavailable/after_authority_recovery`; the combined
`authority_unavailable` row above applies to missing authority or missing
signed head-status evidence.

## 8. Privacy-retention parameter and deletion boundary

`MBI-PRIVACY-RETENTION-01` remains a human/owner input. This packet does not
choose:

- tombstone retention duration;
- current empty-head retention duration;
- historical registration retention;
- whether any identifier is permanent;
- legitimate purpose;
- disclosure conditions;
- backup/restore behavior;
- compaction timing;
- deletion timing;
- user-facing wording;
- collision retry bound;
- a hidden default.

Without an accepted decision:

```text
policy deletion of current empty head = DISABLED
policy deletion proof accepted set   = EMPTY
post-policy-deletion re-enroll        = UNAVAILABLE
tombstone/history compaction          = DISABLED
privacy claim                         = NONE
```

Endpoint/token-material deregistration may be formally modeled, but it is not
an assertion that all personal data was erased.

If the owner later permits empty-head deletion, the decision input must define
exact scope, purpose, retention, backup/restore, deletion proof signer,
generation, revocation, status/read-back, rollback behavior, disclosure, and
user wording. It must not be inferred from absence, elapsed time, cleanup, or
database compaction.

## 9. Formal invariants

### 9.1 Acyclicity

Let `rank` be:

```text
rank(M)=0
rank(A,C,G,K)=0
rank(S)=1
rank(D)=2
rank(B)=3
rank(N)=4
rank(Q)=5
rank(E)=6
rank(L)=7
rank(T*)=8
rank(H*)=9
rank(U)=10
rank(I)=11
rank(Ch)=12
rank(R)=13
```

For every digest/reference edge `x -> y`:

```text
rank(y) < rank(x)
```

No accepted edge violates the inequality.

### 9.2 Current authority uniqueness

For each authority head key `k`:

```text
count(CurrentAuthorityHead where headKey=k) ∈ {0,1}
```

If count is not 0 or 1, readiness is unavailable.

### 9.3 Current subject-head uniqueness

For each subject head key `h`:

```text
count(CurrentSubjectHead where headKey=h) ∈ {0,1}
```

For active/revoked:

```text
exactly one registration row matches currentRegistrationID
exactly one delivery lookup matches that row
```

For empty-after-deregister:

```text
currentRegistrationID = null
no active delivery lookup exists for the former endpoint/token
```

### 9.4 Non-substitution

For any accepted request `r` and catalog entry `e`:

```text
Tuple(r) = Tuple(e) = Q
SignerPath(r) = DirectOwner or ExactDelegation(D)
Requester(r) = ConsentSigner(N) = Q.requester
Target(r) = Q.targetCellID
Owner(r) = Q.targetOwner
Contract(r) = Q.contractSHA256
```

Replacing any one value without replacing and reauthorizing the complete
downstream DAG causes at least one digest/signature/current-selector failure.

### 9.5 No transport authority

For HTTP wrapper metadata `w`:

```text
Authority(r,w) = Authority(r)
```

No value found only in `w` can make a rejected or unavailable request
accepted.

## 10. Required vectors and fixtures

These are exact future fixture obligations. No fixture file is authored here.
Each positive vector remains non-operational until real independently accepted
authority inputs exist; synthetic fixtures must be marked synthetic and cannot
populate production accepted sets.

### 10.1 RC3 construction vectors

```text
B-RC3-001 direct-owner DAG, every rank decreases
B-RC3-002 delegated DAG, exact D scope and permitted kind
B-RC3-003 B contains no catalog or consent digest
B-RC3-004 N references B but no catalog digest
B-RC3-005 E contains complete B/N and Q
B-RC3-006 L references complete E; earlier nodes do not reference L
B-RC3-007 canonical bytes and every paired digest reproduce
```

### 10.2 RC3 substitution negatives

```text
B-RC3-020 signer descriptor substitution
B-RC3-021 signer key-ID substitution
B-RC3-022 signer algorithm substitution
B-RC3-023 delegation bytes/digest substitution
B-RC3-024 direct/delegated nullability mismatch
B-RC3-025 requester subject substitution
B-RC3-026 target Cell substitution
B-RC3-027 target owner substitution
B-RC3-028 Contract substitution
B-RC3-029 Agreement substitution
B-RC3-030 Grant substitution
B-RC3-031 Conditions substitution
B-RC3-032 consent substitution
B-RC3-033 operation/mode/status-kind substitution
B-RC3-034 access/capability/purpose/audience substitution
B-RC3-035 response signer substitution
B-RC3-036 delegated kind outside permitted set
B-RC3-037 D scope differs by one byte
```

### 10.3 RC3 generation/revocation negatives

```text
B-RC3-050 concurrent alternate initial artifact IDs
B-RC3-051 same head generation, different artifact digest
B-RC3-052 stale artifact generation
B-RC3-053 stale revocation generation
B-RC3-054 revoked selector
B-RC3-055 superseded selector
B-RC3-056 expired status
B-RC3-057 wrong status signer
B-RC3-058 rollback below status sequence
B-RC3-059 duplicate durable current heads
B-RC3-060 missing trusted time
B-RC3-061 missing rollback proof
B-RC3-062 missing external artifact generation semantics
B-RC3-063 exact replay returns stored bytes/no generation
B-RC3-064 install exact absent-to-active transition
B-RC3-065 replace exact generation+1 transition
B-RC3-066 revoke exact revocation+1 transition
B-RC3-067 revoke with replacement bytes non-null
B-RC3-068 replace with null replacement bytes
B-RC3-069 wrong mutation signer/controller
B-RC3-070 absence incorrectly treated as withdrawal
```

### 10.4 RC4 signed-body vectors

```text
B-RC4-001 first enroll: absent/null epoch/generation zero
B-RC4-002 enroll after deregister: same epoch/current empty head
B-RC4-003 update: active exact epoch/generation/ID
B-RC4-004 token rotation: active exact epoch/generation/ID
B-RC4-005 reactivate: revoked exact epoch/generation/ID
B-RC4-006 revoke: active exact epoch/generation/ID
B-RC4-007 deregister from active
B-RC4-008 deregister from revoked
B-RC4-009 every body digest changes when head epoch changes
B-RC4-010 every body digest changes when head generation changes
B-RC4-011 nested expectation digest mismatch
B-RC4-012 inherited registration generation differs from expectation
B-RC4-013 inherited revocation generation differs from expectation
```

### 10.5 RC4 concurrency/collision/restart vectors

```text
B-RC4-020 concurrent enroll: exactly one CAS winner
B-RC4-021 concurrent revoke/update: exactly one CAS winner
B-RC4-022 concurrent revoke/deregister: exactly one CAS winner
B-RC4-023 concurrent deregister/re-enroll: stale loser
B-RC4-024 admission ID replay, same request: exact stored bytes
B-RC4-025 admission ID collision, different request: no mutation
B-RC4-026 registration ID collision before commit
B-RC4-027 epoch collision before commit
B-RC4-028 old request after deregister/re-enroll
B-RC4-029 old request after approved head deletion/recreation
B-RC4-030 crash before durable commit: old state authoritative
B-RC4-031 crash after commit before read-back: unavailable until proof
B-RC4-032 rollback below head/epoch allocation anchor
B-RC4-033 duplicate head after restore
B-RC4-034 registration row/head disagreement
B-RC4-035 delivery lookup/head disagreement
B-RC4-036 generation overflow
B-RC4-037 policy-deletion input absent: unavailable
B-RC4-038 status outcome absent or stale: unavailable
```

### 10.6 Privacy-negative fixtures

Fixtures must contain no real APNS token, token hash, personal identifier,
device identifier, real key, or real signed production evidence.

```text
B-PRIV-001 wrong-subject by-ID lookup is oracle-safe
B-PRIV-002 deleted historical bytes are not reconstructed
B-PRIV-003 absence does not prove deregistration
B-PRIV-004 missing retention decision selects no hidden default
B-PRIV-005 deregister wording does not claim total privacy erasure
```

## 11. Decision ledger

| ID | Decision/input | Owner | This packet | Consequence while absent |
|---|---|---|---|---|
| S6-B-D01 | Accept exact M and its status authority | Identity/target owner, separate cutover | not supplied | authority EMPTY |
| S6-B-D02 | Accept exact A/C/G/K semantics and current selectors | artifact owners + CellProtocol review | not supplied | authority EMPTY |
| S6-B-D03 | Accept exact requester and target-owner descriptors/keys | Identity cutover | not supplied | authority EMPTY |
| S6-B-D04 | Accept trusted-time provider | production owner | not supplied | authority/status unavailable |
| S6-B-D05 | Accept rollback/stable-media provider | CellScaffold owner | not supplied | authority/head unavailable |
| S6-B-D06 | Define integrated signed status result carrying current head | RC1 integrator | not supplied | mutation unavailable |
| S6-B-D07 | Define integrated mutation result carrying transition evidence | RC1 integrator | not supplied | response mapping EMPTY |
| S6-B-D08 | Map any new error labels to the frozen error union | integration owner | not supplied | affected branch unavailable |
| S6-B-D09 | Choose collision retry bound | target owner | not supplied | collision retry unavailable |
| MBI-PRIVACY-RETENTION-01 | retention, deletion, purpose, disclosure, backup, wording | Kjetil/owner | deliberately not chosen | deletion/compaction disabled |
| S6-B-D10 | Independent exact-byte review of this packet | independent reviewer | pending | no closure credit |

No document author, route implementer, scaffold process, administrator, test
key, TLS key, or repository key may decide D01–D05 by inference.

## 12. RC3 and RC4 classifications

### 12.1 RC3

Formal claims proven by construction in this packet:

- the authority graph is acyclic;
- B and N can be constructed before E and L;
- direct/delegated signer nullability is total;
- the signer/delegation/subject/target/owner/Contract tuple is exact;
- stable head keys do not include random artifact IDs;
- current generation/revocation selection has exact signed bytes and CAS;
- missing or ambiguous inputs produce EMPTY/UNAVAILABLE;
- transport grants no authority.

Classification:

```text
RC3 FORMAL BYTE/DAG DESIGN = CLOSED
RC3 EXTERNAL AUTHORITY INPUTS = EMPTY
RC3 OPERATIONAL AUTHORITY = UNAVAILABLE
RC3 PRODUCTION PASS = NONE
```

This is a formal-design closure only. It requires independent exact-byte
review before any closure credit.

### 12.2 RC4

Formal claims proven by construction in this packet:

- expected current head epoch and generation are inside exact signed mutation
  body bytes for register/revoke/deregister;
- operation/mode applicability and nullability are total;
- first enroll, retained-head re-enroll, update, token rotation, reactivate,
  revoke, and deregister have exact CAS transitions;
- concurrency, collision, replay, overflow, restart, and rollback outcomes are
  fail-closed;
- a new epoch after accepted deletion prevents old signed bytes from becoming
  current.

Exact residual premise:

```text
MBI-PRIVACY-RETENTION-01 remains human input and UNAVAILABLE.
No empty-head deletion, retention duration, permanent identifier,
tombstone duration, compaction, or hidden default is selected.
```

Additional cross-packet operational premises remain unavailable:

```text
integrated signed status/current-head result
integrated signed mutation result
stable-media/rollback proof
trusted time
accepted authority bytes
```

Classification:

```text
RC4 SIGNED HEAD-CAS FORMAL DESIGN = CLOSED
RC4 POLICY-DELETION/RETENTION BRANCH = PARTIAL, exact residual
RC4 OPERATIONAL MUTATION = UNAVAILABLE
RC4 PRODUCTION PASS = NONE
```

Overall RC4 is **PARTIAL** solely because the owner-controlled privacy
retention/deletion branch and cross-packet operational premises are not
supplied. This packet does not convert those inputs into defaults.

## 13. Author finding count and terminal verdict

Author self-check within the narrow formal document scope:

```text
P0 = 0
P1 = 0
P2 = 0
```

This is not independent review evidence. An independent exact-byte review may
change the count or reject the classifications.

Terminal verdict:

```text
S6 PACKET B AUTHOR DOCUMENT = FROZEN CANDIDATE AFTER HASH ATTESTATION
RC3 FORMAL DESIGN = CLOSED, REVIEW PENDING
RC4 FORMAL HEAD-CAS = CLOSED, REVIEW PENDING
RC4 PRIVACY/RETENTION BRANCH = PARTIAL / MBI-PRIVACY-RETENTION-01
ACCEPTED AUTHORITY SET = EMPTY
OPERATIONAL APNS/DEVICE-INGRESS READINESS = UNAVAILABLE
SOURCE AUTHORIZATION = NONE
NEXT MATERIAL PHASE = NO-GO
```

The smallest allowed successor is one independent exact-byte static review of
this file by a reviewer distinct from the author. No source, Git, build, test,
network, portal, signing, device, APNS, Identity, staging, deployment, or
material work follows from this author packet.
