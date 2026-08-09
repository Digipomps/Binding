# Independent exact-byte review — HAVEN APNS production composition plan

Status: **INDEPENDENT STATIC REVIEW COMPLETE**

Review observation: `2026-07-24T22:37:45+0200` (`CEST`)

## 1. Reviewer independence and constraints

The reviewer did not author the reviewed plan and did not edit it. This review
was limited to the exact input bytes and local, read-only evidence named by the
review mandate.

The review performed no source change, build, test, dependency resolution,
network access, portal access, signing, device action, APNS contact, secret
inspection, staging action, deployment, Git staging, commit, branch mutation,
push, checkout, fetch, reset, stash, or integration. No raw token, private key,
credential, or unsanitized identity material was read or reproduced.

The only file created by the reviewer is this artifact.

## 2. Exact input gate

| Property | Reproduced value |
| --- | --- |
| Exact path | `/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_Production_Composition_Plan_2026-07-24.md` |
| Expected SHA-256 | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` |
| Actual SHA-256 | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` |
| Result | **MATCH — inspection permitted** |
| Size | `38154` bytes |
| Filesystem mtime | `2026-07-24T22:24:24+0200` (`mtime_epoch=1784924664`) |
| Filesystem birth time | `2026-07-24T22:24:24+0200` (`birth_epoch=1784924664`) |

## 3. Evidence ledger

All results below are local observations. Ref observations establish local
Git state at review time, not current remote state.

| Evidence class | Read-only command class | Sanitized result |
| --- | --- | --- |
| Input identity | `shasum -a 256`, `wc -c`, `stat -f` | Exact hash match; `38154` bytes; timestamp above |
| Object type | `git cat-file -t <sha>` | Every candidate and merge-base SHA below is a `commit` object |
| Commit/ref identity | `git show -s --format=... <object-or-ref>` | Candidate objects, subjects, local refs and remote-tracking refs reproduced |
| Merge base | `git merge-base A B` | All bases in section 4 reproduced exactly |
| Ancestry | `git merge-base --is-ancestor A B` | Exit `0` for claimed ancestry; exit `1` for claimed non-containment |
| Worktree inventory | `git worktree list --porcelain` | Named worktree paths, HEADs and branches reproduced; stale prunable entries were not treated as clean worktrees |
| Worktree state | `git status --short --branch` | Clean/dirty facts reproduced separately from commit-object evidence |
| Candidate scope | `git show --name-status --format=... base..candidate` | Candidate file sets and commit ranges inspected without checkout |
| Aggregate no-touch scope | `git show --name-only --format=... base..candidate`, empty-line removal, `sort -u`, `wc -l` | `38195a…`: 25 paths; `d2d1…`: 2; `c700dbc…`: 193; `fefcc…`: 13; `2d241…`: 11 |
| Source contract | `git show <sha>:<path>` plus local `rg`/`sed` | DeviceIngress code, docs, tests, fixtures, server/client composition and Apple settings inspected |
| Fixture identity | `git show <sha>:<fixture> \| shasum -a 256`; sanitized schema-field extraction after base64 decode | Fixture hashes and non-sensitive schema/access fields reproduced; identity/signature material omitted |

No build or test result is asserted by this review.

## 4. Reproduced manifest, refs, merge bases and worktree state

### 4.1 Commit-object and ref evidence

| Lane | Reproduced object/ref result | Adjudication |
| --- | --- | --- |
| CellProtocol v2 predecessor | `79740304167aa4f4daadd148c5a369e919d25a6a`; subject `Pin device ingress resolver authority (#11)`; local `origin/main` and `origin/HEAD` resolve to it | Supported |
| CellProtocol v3 | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0`; parent `797403…`; subject `Add durable DeviceIngress response contract`; local and remote-tracking candidate refs resolve to it | Supported |
| CellScaffold shared base | `8bb7b31b13dad09734c88217cb01b9d48801ff27` | Supported |
| CellScaffold transport | `38195a233b84d09f66e5ef483800228f857fff2a`; subject `Harden DeviceIngress v3 register foundation` | Supported |
| CellScaffold callback successor | `d2d1b7191d651ad42d172e980ab94a0fd478d07c`; parent `38195…`; subject `Reject unavailable DeviceIngress callback operations` | Supported |
| CellScaffold identity candidate | `c700dbc5699ec3a925165d80bc2ec7ad864a1218`; subject `Add fail-closed Linux identity recovery child` | Object/ref claim supported; composition scope challenged in P1-02 |
| Binding common base | `f6536c497b0a4c0a5b32531416bb3712708cf47e` | Supported |
| Binding PR #8 basis | `3791a431ddb3353c33a657a7bf2cb03cb6f557ea`; parent `f6536c…` | Supported |
| Binding P1 successor | `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c`; parent `3791a431…` | Supported |
| Binding Apple M1 | `2d2412090a65e101435ea91c8ea36bc060d3c768`; subject `chore(apple): bind release identifiers in preflight` | Supported |
| Final protocol/server/Binding/archive revisions | No assigned commit object | Plan correctly uses `UNASSIGNED_NO_INTEGRATION_EXISTS` |

### 4.2 Merge bases and ancestry

| Pair | Reproduced merge base | Reproduced containment |
| --- | --- | --- |
| CellProtocol `797403…` / `79ce4f…` | `79740304167aa4f4daadd148c5a369e919d25a6a` | `797403…` is ancestor of `79ce4f…`; `79ce4f…` is not ancestor of local `origin/main` |
| CellScaffold `8bb7b3…` / `38195a…` | `8bb7b31b13dad09734c88217cb01b9d48801ff27` | Base is ancestor of transport candidate |
| CellScaffold `38195a…` / `d2d1b…` | `38195a233b84d09f66e5ef483800228f857fff2a` | `38195a…` is ancestor of `d2d1…` |
| CellScaffold `d2d1b…` / `c700db…` | `8bb7b31b13dad09734c88217cb01b9d48801ff27` | Neither candidate is ancestor of the other |
| Binding `3791a4…` / `fefcc3…` | `3791a431ddb3353c33a657a7bf2cb03cb6f557ea` | `3791a4…` is ancestor of `fefcc3…` |
| Binding `fefcc3…` / `2d2412…` | `f6536c497b0a4c0a5b32531416bb3712708cf47e` | Neither candidate is ancestor of the other |

### 4.3 Dirty/clean state is not commit-object evidence

The following are separate filesystem observations:

- Observer worktree: detached at `6071ca11c207b537ce52ee4aafb686d9a4d955ae`;
  before this review artifact was created, the predecessor handoff and input
  plan were untracked.
- Binding primary: `7884e566420cd90eb288881cc8a5df0e3685386b`,
  dirty with unrelated project, UI, asset, HavenAgentD and script work.
- CellScaffold primary:
  `fc72d5133dec7f0661cf31908675e04b26909abc`, dirty and reported locally as
  seven commits behind `origin/main`.
- CellProtocol primary:
  `61ffc8990afd34a601231e332e423b905e04535f`, dirty and reported locally as
  eight commits behind `origin/main`.
- Clean named candidate worktrees were reproduced for CellScaffold `38195a…`
  and `d2d1…`, and Binding `3791a…`, `fefcc…`, and `2d241…`.
- Binding push WIP: exactly four modified files on `fefcc…`.
- Binding catalog WIP: dirty on `2d241…`; Associated Domains appears there.
- CellScaffold provider WIP: exactly three modified files on `d2d1…`.
- The identity release-candidate worktree is dirty on `c700dbc…` with ten
  modified paths and one untracked document. Those bytes are not part of the
  candidate commit.
- The detached CellProtocol dependency worktree beside the Binding P1
  candidate is clean at `79ce4f…`.

The plan's instruction not to use the dirty primary worktrees, dirty WIP
bytes, or a mutable local CellProtocol path as release evidence is supported.

## 5. Owner and no-touch boundary reproduction

The plan proposes useful role separation, but its claimed “exact owned file
list” is not closed over either the required output or the actual candidate
diffs:

- The CellProtocol owner must reconcile
  `Docs/DeviceIngressSecurityContract.md`, but that file is absent from the
  row's `Owned inputs`. The v3 candidate also changes
  `Tests/Linux/DeviceIngressCompositionRootPositive.swift`, which is not named.
- The `8bb7b3…..38195a…` server range changes 25 unique paths, including
  `Package.swift`, `Package.resolved`, deployment documentation,
  `docker-compose.yml`, authentication settings, deployment/controller
  scripts and non-DeviceIngress tests. These paths are not closed by the
  proposed DeviceIngress owner list.
- The `f6536c…..fefcc3…` Binding range changes 13 unique paths. In particular,
  `Binding/NotificationCallbackClient.swift` is outside the DeviceIngress
  owner row even though future `resolve`/`submit` work necessarily crosses
  that surface. The Xcode project is touched by the P1 lane and separately
  assigned to the Apple owner without a collision rule.
- The shared byte-preserving transport is a required successor and a current
  blocker, but no row assigns its repository, package identity, exact files,
  owner, or compatibility reviewer.
- The conditional AASA owner has no exact repository/artifact path. This is
  lower severity because the plan safely permits removing Associated Domains.

These are defects in the plan itself, not merely operational release gates.

## 6. CellProtocol `79ce4f…` adversarial adjudication

### 6.1 Code, docs and fixtures

Reproduced source facts:

- `DeviceIngressOperation` contains exactly `register`, `resolve`, and
  `submit`.
- Resources, actions, capabilities, purpose, and identity domain match the
  plan.
- Every current operation returns `requiredAccess == "rw-s"`.
- The envelope and authority-reference schemas are v3.
- Admission record, admission receipt and mutation receipt schemas are v3.
- The response expectation, content policy, operation result, operation
  response and typed result payloads retain their own v1 schema labels.
- `Docs/DeviceIngressSecurityContract.md` at the same commit says “version 2”,
  v2 envelope/authority/admission/mutation schemas and `-w--`.
- That document was not changed by commit `79ce4f…`.

Sanitized fixture evidence:

| Fixture | SHA-256 of stored `.b64` bytes | Reproduced safe fields |
| --- | --- | --- |
| `DeviceIngressChallenge.v3.b64` | `c778bd27eca0e142617e5671d604b64068d37ab5cf5dcd17cb99aa8d1a255869` | v3 envelope/authority, `register`, `rw-s` |
| `DeviceIngressRequest.v3.b64` | `c0c2b0997c6754c5f27c2e0dccb051c26c8b46f6d4363cc4720ada0a73ee6b01` | v3 envelope/authority, v1 domain binding, `register`, `rw-s` |
| `DeviceIngressResponse.v3.b64` | `27c3162acdaeabc38aacdce62fa9d9669b1796c63e2d6b50b79abce4954bd559` | `register`, v3 mutation receipt, v1 operation response/result/registration receipt, `active_consented` |
| `DeviceIngressSignedContract.v3.b64` | `a132873cd7e81e52d753c08a3317eea792206d94436ee5521ced5abaa663dc89` | Signed-contract fixture present; identity/signature material omitted |

The plan correctly classifies the v2/v3 and `-w--`/`rw-s` disagreement as a
release stop.

### 6.2 Challenge, admission, replay and authority

The v3 source defines:

- issuer-signed, subject-bound challenge bytes with bounded lifetime, audience,
  target Cell/owner, Agreement hash, authority and revocation generation;
- requester-signed request bytes bound to the exact challenge and protected
  body digests;
- resolver-selected target Cell and independently verified exact signed
  Contract/Grant;
- durable admission-ledger and same-Cell mutation protocols;
- monotonic generation checks and typed rollback/unavailable failures; and
- a replay contract requiring the same stored canonical response bytes rather
  than re-signing.

This is source-level protocol and interface evidence. It is not evidence that
a production issuer, durable ledger, target Cell or atomic storage
implementation exists. The plan keeps that distinction.

Issuer rotation is not a complete v3 contract: the service pins one expected
issuer descriptor, but no explicit monotonic issuer-rotation generation and
transition proof is defined. The plan correctly requires this in the
successor.

### 6.3 Exact response versus current read-back

The v3 mutation interface requires byte-identical replay of the stored
operation response for the same admission. The response verifier binds the
request, challenge, body, subject, target Cell/owner, signed Agreement,
authority generation, revocation ledger/generation, content policy, mutation
receipt and result digests.

That exact historical replay is not a current registration-status read-back.
There is no `status` operation. A register result may carry `revoked`, but
there is no typed revoke/deregister request and no verifier that proves the
registration's current state after the historical mutation. The plan's
distinction is correct.

### 6.4 Resolve, submit, transport and token rotation

`resolve` and `submit` exist in the protocol enums, typed results and response
verifier, but that does not make their host paths operational.

CellProtocol accepts exact byte inputs and returns canonical response bytes;
it deliberately has no HTTP framing. CellScaffold has a repository-local
base64-on-JSON wrapper. No shared immutable client/server transport package
was found. The plan correctly says Binding must not guess that framing, but
the missing owner/location is a plan defect in P1-03.

The registration receipt deliberately omits the raw APNS token and a stable
token derivative. It carries a registration generation and record hash, but
without a signed current-status operation these do not reconcile an ambiguous
token rotation. The plan's successor requirements are supported.

## 7. CellScaffold, Identity, Binding and Apple evidence

### 7.1 CellScaffold server and provider

At `d2d1b…`:

- `Package.resolved` pins CellProtocol `79ce4f…`.
- The wrapper preserves decoded `Data` bytes and delegates to
  `DeviceIngressAdmissionService`.
- Legacy Authorization and callback-token headers are rejected.
- Challenge issuance fails closed.
- Only `register` can reach admission; `resolve` and `submit` are rejected.
- Production bootstrap keeps register admission and challenge-issuer
  readiness unavailable.
- The testing seam is DEBUG-only; no production service installation was
  found.

The provider WIP is exactly three dirty files. Its source defines production
readiness blockers, the production topic `org.digipomps.haven`, the production
endpoint selection and a generic wake-up/ticket payload without copying the
protected server payload. It remains uncommitted source. No key/account,
runtime installation, provider acceptance or APNS delivery evidence was
inspected or established.

### 7.2 Identity candidate

The ancestry claim is correct, but the integration claim is not exact enough.
From `8bb7b3…` to `c700dbc…`, read-only object inspection finds **123 commits
and 193 unique changed paths**. The range includes identity recovery, but also
committed AASA, payment, development-status, backup/restore, release-gate,
workflow, deployment, Docker, routing and broad application/test changes.

Therefore “integrate the identity candidate” cannot simultaneously mean
“prove unrelated work absent” unless the plan freezes either:

1. the complete `c700dbc…` tree as intentionally in scope with owners for all
   193 paths; or
2. an exact reviewed commit/path allowlist for a narrower identity import.

The current “merge/cherry-pick ledger” wording does not choose between them.
Dirty identity worktree bytes remain correctly excluded.

### 7.3 Binding client and WIP

At clean `fefcc3…`, Binding:

- requires the authenticated persistent CellApple vault;
- refuses to create a missing notification-domain identity;
- validates the non-authoritative domain binding and public descriptor;
- persists the response expectation before the mutation-capable send;
- uses a descriptor-relative, synchronized, hash-chained evidence store with
  cross-process locking;
- verifies the owner-signed response and rebinds restored historical evidence
  to the current vault identity;
- labels restored register evidence historical; and
- keeps the runtime composition and `resolve`/`submit` fail-closed.

The Xcode project still uses local package reference `../CellProtocol`.
`Package.resolved` does not replace that local source selection. The plan
correctly forbids it as release dependency evidence.

The dirty four-file Binding WIP adds the five named operational blocker values
and honest UI/docs language but no transport or operational composition. It is
not a candidate SHA.

### 7.4 Bundle, origin, topic, signing and AASA

Static source observations support the plan:

- Apple M1 selects `org.digipomps.haven` for Release on `iphoneos`, while the
  unconditional bundle setting remains a playground identifier.
- The policy template records `https://haven.digipomps.org` as the decided
  production origin.
- The committed iOS entitlement says `aps-environment=development`.
- Associated Domains is pending in the Apple policy and appears only in the
  separate dirty catalog WIP as `applinks:haven.digipomps.org`.
- The uncommitted provider WIP expects APNS topic
  `org.digipomps.haven`.
- Team, profile, distribution certificate/key chain, App ID capability,
  effective archive entitlements and codesign authority remain unverified.

No Apple account, portal, profile, key, archive, deployed AASA or live origin
was inspected. The plan correctly treats source values as premises, not
production proof, and correctly makes Associated Domains conditional on
archive plus AASA proof.

## 8. Include/remove/defer/STOP and Identity separation

The security direction of the table is supported:

- persistent domain-scoped identity is evidence, not authority;
- the exact signed Agreement/Contract and resolver-selected Cell owner remain
  the authority path;
- bearer/server-secret, auto-provisioned authority, unsigned success, raw
  token persistence and sensitive APNS payload fallbacks are correctly
  prohibited;
- current status and typed revoke/deregister are correctly required;
- Associated Domains has a safe removal alternative; and
- prototype/source, archive, deployed-runtime, provider and physical-device
  proof classes are explicitly separated.

Identity cutover is explicitly kept separate from APNS transport and provider
work. That separation is conceptually correct. It is not operationally closed
until the `c700dbc…` import set is made exact.

## 9. Adversarial findings

### P0

**No P0 defect was found in the plan text.** No production action was
performed. The P0 conditions listed by the plan remain valid future stop
conditions.

### P1

#### P1-01 — Owner/file-scope manifest is not closed

The plan calls section 3 an exact owned-file packet, but required files and
candidate-diff paths fall outside it. The CellProtocol security document is
the clearest contradiction: it must change, yet is not an owned input.
Server and Binding candidate ranges also contain unassigned/colliding paths.

Impact: the proposed packet cannot authorize one-writer ownership or prove
no-touch coverage as written.

Required correction: publish a successor plan whose allowlist is closed over
every candidate path and every required output, with explicit cross-owner
collision rules.

#### P1-02 — `c700dbc…` is not an exact narrow identity composition lane

The stated merge base is correct, but the full range is 123 commits/193 paths
and includes many non-identity surfaces. The plan neither includes those
surfaces with owners nor freezes an exact narrower import.

Impact: merging the full SHA violates the stated unrelated-work exclusion;
selective cherry-picking lacks an exact immutable manifest.

Required correction: choose and review one complete-tree or exact-subset
strategy before server composition.

#### P1-03 — Shared byte-preserving transport has no assigned home or owner

The plan makes a shared immutable transport contract a prerequisite and
correctly says it is currently unavailable, but assigns no repository,
package identity, files, owner, fixture-consumption contract or compatibility
review.

Impact: CellScaffold and Binding cannot be given exact non-overlapping work
packets without guessing the framing the plan forbids them to guess.

Required correction: freeze the transport artifact location and exact
client/server API/file scope before implementation.

### P2

#### P2-01 — Frozen evidence packet omits object/diff evidence details

The plan records SHAs and merge bases but not candidate tree IDs, exact
candidate-diff allowlists, or the dirty path ledgers needed to reproduce its
no-touch claims without rediscovery. This review reconstructed them, but the
successor packet should carry them.

#### P2-02 — Conditional AASA ownership is not path-exact

The safe include-or-remove decision is correct, but the AASA owner row does not
freeze the repository, artifact path and decision-record path. This remains P2
because removing Associated Domains is an explicit fail-closed alternative.

## 10. Claim adjudication

| Plan claim | Result | Basis |
| --- | --- | --- |
| Exact candidate objects and stated merge bases exist | **Supported** | Local commit/ref/object and merge-base evidence |
| Named clean/dirty worktree facts are accurate | **Supported** | Separate `git status` observations |
| CellProtocol v3 code/fixtures disagree with v2/`-w--` doc | **Supported** | Exact object reads and sanitized fixture fields |
| v3 lacks current-status and typed revoke/deregister | **Supported** | Operation enum and result/verifier inspection |
| v3 has exact historical response/replay contracts | **Supported, source-level only** | Admission/mutation interfaces and verifier |
| Server is fail-closed/inert and callback operations are incomplete | **Supported** | `d2d1b…` source |
| Binding P1 is persistent-evidence capable but operationally inert | **Supported** | `fefcc3…` source and clean status |
| Provider/Binding WIPs are source-only, not candidate or runtime proof | **Supported** | Dirty status and source inspection |
| Bundle/origin/topic values are intended source alignment, not signing proof | **Supported** | Apple M1 and provider WIP source |
| Associated Domains is conditional on AASA/archive proof | **Supported** | Policy, entitlement and plan stop table |
| Identity cutover is separate from APNS | **Supported conceptually** | Explicit plan boundaries |
| Identity candidate can be composed with exact no-touch scope as written | **Contradicted** | 123-commit/193-path range without allowlist |
| Section 3 provides exact owner/file packets sufficient to start work | **Contradicted** | Missing/colliding files and unowned transport |
| Source readiness can establish production acceptance | **Correctly rejected by plan** | Evidence-class separation |
| Current candidates may be signed/uploaded/used for production now | **Correctly unsupported by plan** | Multiple unclosed operational gates |

## 11. Plan defects versus already-described operational release stops

The three P1 items above are defects in the plan artifact and drive the plan
review decision.

The following are not additional plan defects; the plan already describes
them honestly as operational NO-GO gates:

- v3 documentation/schema/access inconsistency;
- missing signed current status and typed revoke/deregister;
- missing production challenge issuer, durable admission/replay implementation,
  persistent target Cells and Agreements;
- unavailable `resolve`/`submit`;
- local mutable CellProtocol dependency in Binding;
- uncommitted provider and Binding WIPs;
- unfinished independent identity continuity/cutover proof;
- unverified Team/App ID/profile/certificate/codesign/production entitlement;
- conditional AASA not proved;
- no exact integrated revisions or archive;
- no deployed runtime/provider acceptance; and
- no physical device receipt/resolve/submit/restart evidence.

Even a corrected plan would therefore remain an operational release NO-GO.

## 12. Exact smallest successor scopes

These are scope definitions only. This review does not authorize or open any
of them.

### S0 — Correct the static composition packet

- Repository: Binding.
- Files: create one new successor plan only; preserve this exact input and
  this review unchanged.
- Contract: add exact candidate tree/diff allowlists, close every owner row
  over required outputs, choose full-tree versus exact-subset identity
  composition, assign the shared transport repository/package/files/owner,
  and name cross-owner collision rules.
- Prerequisites: this review artifact and the exact input hash above.
- Reviewer: independent reviewer who did not author the successor.
- No-touch: all source, candidate worktrees, refs, dependencies and existing
  frozen documents.
- Stop: any wildcard such as “relevant tests/docs”, any unassigned candidate
  path, any unfrozen identity import, or any unowned transport artifact.

### S1 — CellProtocol current-v3 reconciliation

- Repository: CellProtocol.
- Bounded existing files:
  `Docs/DeviceIngressSecurityContract.md`,
  `Tests/CellBaseTests/Fixtures/README.md`,
  `Sources/CellBase/DeviceIngress/DeviceIngressWire.swift`,
  `Sources/CellBase/DeviceIngress/DeviceIngressAdmission.swift`,
  `Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift`,
  `Tests/CellBaseTests/DeviceIngressContractTests.swift`,
  `Tests/CellBaseTests/DeviceIngressWireFixtureTests.swift`,
  `Tests/CellBaseTests/Fixtures/DeviceIngressChallenge.v3.b64`,
  `Tests/CellBaseTests/Fixtures/DeviceIngressRequest.v3.b64`,
  `Tests/CellBaseTests/Fixtures/DeviceIngressResponse.v3.b64`,
  `Tests/CellBaseTests/Fixtures/DeviceIngressSignedContract.v3.b64`, and
  `Tests/Linux/DeviceIngressCompositionRootPositive.swift`.
- Contract: first make existing v3 code, docs, fixture descriptions and
  `rw-s` semantics agree. Status/revoke schema names and any new fixture paths
  must be frozen explicitly before being added.
- Prerequisites: S0 GO and a clean worktree rooted in reviewed `79ce4f…` or an
  explicitly reviewed replacement.
- Reviewer: CellProtocol security/contract reviewer independent of the author.
- No-touch: HTTP routes, APNS, Apple settings, host credentials, server/client
  composition and raw tokens.
- Stop: any new path not added to the frozen allowlist, any host framing in
  CellProtocol, or any weakening of resolver/Agreement/Storage checks.

### S2 — Freeze the identity import

- Repository: CellScaffold.
- Files: one new identity-composition allowlist document only; no source
  integration.
- Contract: list the exact source commit set, resulting tree, every included
  path, every deliberately excluded `c700dbc…` path, dependency order and
  continuity/cutover evidence class.
- Prerequisites: human decision between complete-tree and narrow-subset
  strategy.
- Reviewer: identity/cutover reviewer plus independent security reviewer.
- No-touch: APNS provider, DeviceIngress transport, device registration,
  staging, recovery execution and dirty identity worktree bytes.
- Stop: full `c700dbc…` merge without ownership of all 193 paths, or selective
  import without an immutable commit/path ledger.

### S3 — Freeze the shared transport artifact

- Repository: must be selected in S0; it is intentionally **unassigned now**.
- Files: exact package manifest, client adapter, server adapter and shared
  golden-fixture consumer paths must be named in S0 before source work.
- Contract: transport carries exact challenge/request/protected-body/response
  bytes; it cannot choose identity, purpose, audience, operation, Cell, owner,
  Agreement, authority or success.
- Prerequisites: S0 GO and S1's frozen canonical contract.
- Reviewer: cross-runtime compatibility reviewer plus security reviewer.
- No-touch: authority policy, raw token persistence, shared secrets, signing,
  provider credentials and deployment.
- Stop: unresolved repository/package identity, duplicated client/server
  framing, fixture mismatch, or any transport-selected authority.

### S4 — Later server and Binding composition

- Repositories: CellScaffold and Binding in separate clean worktrees.
- Files: exact per-repository allowlists must be produced by S0 after S1–S3
  assign all new issuer/ledger/Cell/adapter/status/revocation paths.
- Contract: preserve the plan's order—identity gate, server composition,
  Binding composition, exact review, then separately authorized build/sign/
  runtime/device phases.
- Prerequisites: S1, S2 and S3 independently GO; exact immutable protocol,
  identity and transport artifacts.
- Reviewers: separate server, Binding, Apple and independent security
  reviewers; one writer per worktree.
- No-touch: primary dirty worktrees, dirty WIPs by directory copy, unrelated
  catalog/UI/payment/recovery/deployment work, secrets and production systems.
- Stop: any missing exact file allowlist, unresolved merge conflict,
  dependency drift, dirty source, missing status/revoke/callback operation, or
  attempt to treat source readiness as production proof.

## 13. Decisions

**PLAN REVIEW: NO-GO**

Reason: no P0 was found, but P1-01 through P1-03 prevent the plan from being
the exact, closed owner/no-touch packet it claims to be.

**NEXT PHASE: NO-GO**

No successor assignment, source implementation, integration, build, signing,
runtime action or production proof phase was opened. The smallest possible
later action is a separately authorized documentation-only S0 correction.

