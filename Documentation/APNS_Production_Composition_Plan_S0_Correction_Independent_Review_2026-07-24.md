# APNS Production Composition Plan S0 Correction — Independent Review

Date: 2026-07-24  
Reviewer: Ptolemy, independent of the S0 author  
Review mode: exact-byte, local, static, read-only  
Review status: COMPLETE  
PLAN decision: **NO-GO**  
NEXT PHASE decision: **NO-GO**

## 1. Purpose, authority and stop boundary

The purpose of this review is to minimize the risk of composing an
irreversible or falsely production-ready APNS/DeviceIngress release from
ambiguous source boundaries.

The measurable goals were:

1. bind and reproduce the three administrator-supplied input documents;
2. reproduce the S0 object, manifest, dirty-exclusion, ownership, collision,
   transport and AASA claims from local immutable objects;
3. adjudicate every prior P1/P2 finding as closed, partial or open;
4. identify any new P0/P1/P2 defect; and
5. preserve `PLAN NO-GO` and `NEXT PHASE NO-GO` while any
   missing-bound-input remains.

The administrator authorized exactly one write:

```text
Documentation/APNS_Production_Composition_Plan_S0_Correction_Independent_Review_2026-07-24.md
```

No input document was edited. No source, Git index, branch, commit, remote,
dependency, build, test, network, Apple portal, signing, device, APNS,
staging or deployment action was performed. Untracked worktree contents were
not opened where the S0 packet marked them excluded.

## 2. Exact input gate

All three supplied byte identities and file shapes matched before review and
again immediately before this file was written.

| Input | Required SHA-256 | Reproduced lines | Reproduced bytes | Result |
| --- | --- | ---: | ---: | --- |
| `APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | 573 | 38154 | MATCH |
| `APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | 547 | 29346 | MATCH |
| `APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | `4a868f9c03cffcf13c47b92b8b9eaf7e42a7b2af706ce238354c41bf7e759edb` | 984 | 54678 | MATCH |

The review target did not exist at the write boundary. The detached
documentation observer had exactly the four expected pre-review untracked
documents and an empty tracked patch.

## 3. Decision summary

The S0 correction is sufficiently content-addressed to receive this static
review. It substantially repairs the original packet:

- all seven current candidate manifests are exact and reproducible;
- the complete immutable `c700dbc…` tree is now the selected Identity source
  boundary;
- current candidate, WIP, dirty no-touch and collision paths are
  content-addressed;
- a repository, package name, owner and proposed files are assigned to the
  existing-v3 shared transport;
- conditional AASA ownership is path-exact and fail-closed; and
- Identity cutover remains explicitly separate from APNS composition.

That does **not** make the production plan executable. `MBI-01` through
`MBI-07` remain missing, and the proposed transport fixture rule is internally
inconsistent. Therefore:

```text
S0 STATIC REVIEW: COMPLETE
PLAN: NO-GO
NEXT PHASE: NO-GO
SOURCE PHASE AUTHORIZED: NO
PRODUCTION CLAIM AUTHORIZED: NO
```

Any one remaining missing-bound-input is sufficient to preserve both
`PLAN NO-GO` and `NEXT PHASE NO-GO`.

## 4. Immutable candidate-manifest reproduction

For each ordinary range, the review reproduced:

```text
git show -s --format=%T <commit>
git diff --name-status -z <base>..<head>
```

For the AASA commit, its parent-to-head diff was used. The exact path text in
S0 sections 5.1 through 5.7 was independently compared with each normalized
Git result; all seven lists matched with no missing, extra or status-mismatched
entry.

| Manifest | Reproduced base tree | Reproduced head tree | Paths | Reproduced name-status SHA-256 | Result |
| --- | --- | --- | ---: | --- | --- |
| `M-CP-V3` | `71ee11a69139a1c222c2156ab1bc79dbe0115620` | `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` | 11 | `912ca02e45425581fca429191010002c7f756ba78e002c4b9aceca255ec68cff` | MATCH |
| `M-CS-TRANSPORT` | `16ab2d81098c12975776db2b4acefb2ec75d1ff2` | `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` | 25 | `06cede7316f7553fb824785eaa3eae27a98ec86ebebc96f1d087233ffe217f74` | MATCH |
| `M-CS-ROUTE-FIX` | `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` | `536531541587b5229b8f325f8935ed11ef85f228` | 2 | `51c3daffedd3330995a84c27fb1d23fee4ef37a7bbfb8dd561db5211d01fa442` | MATCH |
| `M-CS-IDENTITY-FULL-TREE` | `16ab2d81098c12975776db2b4acefb2ec75d1ff2` | `211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4` | 192 | `702589d3e8437dcadaa8048e6a2ae9efc57b94f4fcc409828c677ad7cf6f49f0` | MATCH |
| `M-CS-AASA-COMMIT` | parent tree `e79c886f1935825935a5add8068b5007c9eea130` | `761c9078ee0ee36f980e7e9550a13c56f642bfdd` | 7 | `f3ec20872b3c4dcb68bd7ec8e530cceea56ac239c03001abb1cb2e8b4936d6fa` | MATCH |
| `M-BINDING-P1` | `ac894efa9e709e788eaa1dc863db1070786fbe0b` | `e0d6c9ff4fb998fa252ab86621abfe24398d7b18` | 13 | `29495a23af28ca7842836f916593f9bdcde79c0d08076422b975e9c405d69f80` | MATCH |
| `M-BINDING-M1` | `ac894efa9e709e788eaa1dc863db1070786fbe0b` | `34421cbabe9e801fa96da315a191ed23cd023ec8` | 11 | `94c535870b86bcb796ff83f36dda6785db24045343f5b288499282bade13b8b0` | MATCH |

The full AASA base commit is
`d22e89405cf4460f6f47fb303fb3b75a28b1d75c`.

## 5. Exact `c700…` full-tree boundary

The complete-tree strategy is reproducible:

| Property | Reproduced value |
| --- | --- |
| Merge base | `8bb7b31b13dad09734c88217cb01b9d48801ff27` |
| Head commit | `c700dbc5699ec3a925165d80bc2ec7ad864a1218` |
| Head tree | `211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4` |
| Commit count | 123 |
| Oldest-first commit-list SHA-256 | `6d2ac736c34f6dd7c6d143ddd70bdaad0a8b2a34d050d7236602fb93dc467f39` |
| Endpoint name-status entries | 192 |
| Endpoint name-status SHA-256 | `702589d3e8437dcadaa8048e6a2ae9efc57b94f4fcc409828c677ad7cf6f49f0` |
| Full-tree tracked entries | 1566 |
| `git ls-tree -r -z` SHA-256 | `b1f11701fbdf07b91824f6a6fbe82cf8ee983be1968bde20f12e035672c33824` |
| Endpoint shortstat | 192 files changed, 74947 insertions, 1248 deletions |

The S0 choice is not a selective 123-commit import. It chooses the exact
complete tree and excludes every dirty worktree byte. That closes the
ambiguity identified by prior `P1-02` for static source provenance.

There is one terminology correction to the S0 “Reviewer count correction”:

- the prior review used a per-commit changed-path union and correctly obtained
  193 unique paths;
- the S0 manifest uses an endpoint `base..<head>` diff and correctly obtains
  192 paths; and
- `scripts/cellscaffold-restore-verify.sh` is in the per-commit union but has
  no endpoint delta.

Therefore neither count falsifies the other. The S0 192-path allowlist is the
correct endpoint composition manifest, but the prior 193-path observation was
not a one-path arithmetic error. This is `P2-S0-01` below.

## 6. Dirty exclusion and no-touch reproduction

Status digests were reproduced over
`git status --porcelain=v1 -z`. Tracked patch digests were reproduced over
`git diff --binary`. Untracked contents were not read.

| Surface | Status SHA-256 | Tracked patch SHA-256 | Result |
| --- | --- | --- | --- |
| Binding APNS fail-closed WIP | `8dc28f54c0b20d818bdb0c7b41652da8490d4dc8dd5bef50b2591df66044648d` | `18c4b3b7795210d7e55acac6588d270be51ea219e31b2d2b2cba7045e854d0c8` | MATCH / EXCLUDED |
| CellScaffold APNS provider WIP | `463c92bbc0060c0790141bcc53b062a685bcae1a79e2a637d2295381b7edff01` | `a1bcc57a59f9bbcf5f545fc51a43efd13599f36451186981dbc607d0afa80963` | MATCH / EXCLUDED |
| Binding catalog/AASA WIP | `327a3c5c4ae0c301bf567c3b2dd735509ada915e5b730a80f731a7bca9dd4765` | `cc00fc28abfab133ccfd2658f58db2131cbc18840256a7aa4b2b636cebd8ee5f` | MATCH / EXCLUDED |
| Identity candidate dirty bytes | `151491a531ba7fa28367c79b9f739f2f1de5b9d4e284373f4ee89a4f6c5ff53f` | `96bd1aa0ddba65e094f0a713c5a5f95431c79bd0a0915827d1ba008b922a6feb` | MATCH / HARD NO-TOUCH |
| Primary CellProtocol | `441fd800ec554cf79df648d4290269d9a756bf98ee05dc5f86af5a20ee1a5f57` | `3c3f9391bd4e9afdd597ba803f1bb0d64d745082d0233f20fed9427753f8b67c` | MATCH / HARD NO-TOUCH |
| Primary Binding | `f3c275dfbe64cb8a1848c2ccc735e440dd4083ad867695ce1aec7e011be192d7` | `4de198d126c1b8ffe2605af07dde35d29ff77a071773e311514d2e19ba7261dc` | MATCH / HARD NO-TOUCH |
| Primary CellScaffold | `a8ae6601e0d32a5824e18bdbd9b1af07b886f3058eacf9263de203d77383edff` | `9a6b3e74f429072df139409f7724544dd7dd2fcb14388a0906e2a6ba60d5dd79` | MATCH / HARD NO-TOUCH |

All four named clean candidate worktrees had both empty status and empty
tracked-patch digest
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The S0 no-touch rule is adequate for static planning: use only named immutable
objects, never directory-copy WIP, never clean up a dirty checkout, and never
import the 11 dirty Identity paths over `c700…`.

## 7. Owner, output-path and collision adjudication

### 7.1 Current candidates and WIPs

Every path in the seven current manifests and all three WIP ledgers has an
owner or an explicit integrator collision rule in S0. The exact path-list
comparisons succeeded. Current bytes are classified as immutable input,
excluded WIP, deferred input or hard no-touch; no current dirty path was
silently promoted to a candidate.

The administrator-supplied filename for this review also resolves the S0
row that intentionally left the independent-review output name unbound. It
does not resolve any production output.

### 7.2 Future outputs

The future-output allowlist is exact only where a contract already exists:

| Owner lane | Review result |
| --- | --- |
| CellProtocol current-v3 reconciliation | Exact 11 manifest paths plus `Docs/DeviceIngressSecurityContract.md`; unopened |
| CellProtocol status/revoke | No paths; `MBI-01`/`MBI-02` remain |
| CellProtocol shared transport | Exact author-proposed package/source/test/fixture paths; implementation absent and unopened |
| Identity full-tree boundary | Exact immutable tree; no writes |
| CellScaffold existing-v3 consumer | Exact existing source/test/fixture/package paths |
| CellScaffold production issuer/admission/status/revoke | No paths; `MBI-04` remains |
| CellScaffold provider | Exact excluded WIP paths only |
| Binding DeviceIngress | Exact 13-path immutable input boundary |
| Binding shared transport consumer | Exact author-proposed source/test/fixture/project paths; unopened |
| Binding status/revoke/rotation | No paths; `MBI-05` remains |
| Binding Apple release | Exact M1 paths plus entitlement planning boundary |
| AASA/origin | Exact CellScaffold and Binding conditional paths; deferred |
| Development-admin integration | Exact collision paths only; no integration output exists |

S0 correctly refuses to invent future paths for unresolved operations,
storage, Cells, Agreements or client behavior. Consequently prior `P1-01` is
only partial, not closed.

### 7.3 Collision matrix

The intersections were independently recomputed:

- Identity full tree × CellScaffold transport: exactly 9 paths;
- Identity full tree × route fix: none;
- Identity full tree × AASA: exactly all 7 AASA paths;
- Identity full tree × provider WIP: none;
- CellScaffold transport × provider WIP: exactly
  `Documentation/DeviceCallbackCapabilityServer.md` and
  `Tests/AppTests/NotificationPushProviderTests.swift`;
- route fix × provider WIP: none;
- Binding P1 × Apple M1: exactly
  `Binding.xcodeproj/project.pbxproj`;
- Binding P1 × Binding APNS WIP: exactly
  `Binding/DeviceIngressRegistrationClient.swift`,
  `Binding/NotificationConsentBanner.swift`,
  `BindingTests/DeviceIngressRegistrationClientTests.swift` and
  `Documentation/DeviceCallbackCapabilityContract.md`;
- Binding P1 × catalog WIP: none; and
- Binding M1 × catalog tracked diff: none.

All intersections and the S0 integrator/no-touch decisions match. The
Identity/transport 9-path set is:

```text
Documentation/Staging_Deployment.md
Package.swift
Sources/App/configure.swift
Sources/ScaffoldKit/Application+AuthSecuritySettings.swift
Tests/AppTests/JWTAuthRoutesTests.swift
Tests/AppTests/TopUpCheckoutTests.swift
docker-compose.yml
scripts/cellscaffold-container-controller.py
scripts/tests/test_cellscaffold_container_controller.py
```

No collision may be resolved until the owning lanes are independently green,
and only the later development-admin integrator may write final collision
bytes.

## 8. Shared transport review

### 8.1 Reproduced existing-v3 boundary

The S0 transport home and owner proposal is explicit:

| Property | S0 assignment / reproduced fact |
| --- | --- |
| Repository | CellProtocol |
| Product/target | `CellDeviceIngressTransport` |
| Producer | `Sources/CellDeviceIngressTransport/DeviceIngressHTTPTransport.swift` |
| Tests | `Tests/CellDeviceIngressTransportTests/DeviceIngressHTTPTransportTests.swift` |
| Outer fixture | `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransport.v3.json` |
| Canonical copies | four named `.v3.b64` fixture-copy paths under the same test target |
| CellScaffold consumer | exact controller, route, test, fixture and package paths in S0 section 8 |
| Binding consumer | exact transport/client/test/fixture/project paths in S0 section 8 |
| Primary owner | CellProtocol shared transport owner |

At immutable CellProtocol `79ce4f…`, the proposed product, target, producer,
test and outer fixture do not exist. They are a planning assignment, not a
reproduced implementation or immutable input.

At CellScaffold `d2d1b…`, local source reproduces:

- schema `haven.device-callback.transport.v3`;
- wrapper fields `schema`, `canonicalChallenge`, `canonicalRequest`,
  `protectedBody`;
- Swift `Codable` `Data` base64-on-JSON behavior;
- maximum wrapper 327680 bytes;
- maximum challenge, request and protected body 65536 bytes each;
- exact register, resolve and submit paths;
- raw canonical operation-response bytes on success; and
- no transport authority.

CellProtocol `79ce4f…` exposes exactly `register`, `resolve` and `submit`.
CellScaffold registers those paths, but only `register` may pass its route
gate; challenge issuance and production admission are unavailable. Binding
`fefcc3…` accepts abstract challenge/request/response `Data` and installs an
inert transport. These facts support the S0 declaration that the shared
transport is incomplete.

### 8.2 New transport-fixture inconsistency

S0 says the producer fixture must be “one outer wrapper containing exact
decoded bytes from the four canonical CellProtocol v3 fixtures.” The frozen
outer wrapper has only three binary fields:

```text
canonicalChallenge
canonicalRequest
protectedBody
```

The canonical registration exchange has four separate pinned fixtures:
challenge, request, signed Contract and response. Current source treats
`protectedBody` as application bytes, decodes the signed Contract separately,
and returns the canonical response raw outside the wrapper. Therefore one
wrapper with the frozen field set cannot contain all four canonical fixtures
as stated.

This is `P1-S0-01`. Before a transport source phase can be considered, the
owner must freeze:

1. the exact protected-body fixture bytes;
2. how the signed Agreement/Contract is supplied and verified without making
   HTTP authoritative;
3. the response fixture as expected raw output, not an input wrapper field;
4. one unambiguous producer-fixture schema and exact consumer assertions; and
5. the still-missing challenge/status/revoke/rotation framing.

No schema or path is invented by this review.

## 9. Conditional AASA review

The conditional AASA commit
`4e4c6eb372bb08bbb71746f2cdcc1d0535d17f7a` and Identity head
`c700dbc5699ec3a925165d80bc2ec7ad864a1218` are not ancestors of one another.
Their merge base is exactly
`8bb7b31b13dad09734c88217cb01b9d48801ff27`.

The seven CellScaffold AASA-owner paths are exact:

```text
.github/workflows/admin-scaffold-image.yml
Documentation/Operations/Apple_Associated_Domains_Runbook.md
Sources/App/Support/HAVENAppleAppSiteAssociation.swift
Tests/AppTests/HAVENAppleAppSiteAssociationTests.swift
scripts/cellscaffold-container-controller.py
scripts/tests/test_aasa_compose_contract.py
scripts/tests/test_cellscaffold_container_controller.py
```

The Binding owner paths are exact:

```text
Binding/Binding-iOS.entitlements
Documentation/AppleReleaseM0Policy.template.json
Documentation/AppleReleaseM0Preflight.md
Scripts/apple_release_m0_preflight.py
Tests/apple_release_m0_preflight_tests.py
```

All seven CellScaffold paths collide with the selected Identity full-tree
endpoint. S0 correctly defers the AASA commit and requires Associated Domains
to be removed unless a later path-exact reconciliation plus production AASA,
TLS and signed-archive entitlement evidence becomes green. Prior `P2-02` is
closed for static ownership/path exactness, not for production readiness.

## 10. Missing-bound-input register

| ID | Independent result | Evidence status |
| --- | --- | --- |
| `MBI-01` current-status contract | **MISSING / OPEN** | Local enum has only register/resolve/submit; no current-state operation/schema/result/fixture |
| `MBI-02` revoke/deregister contract | **MISSING / OPEN** | No typed DeviceIngress revoke/deregister operation |
| `MBI-03` challenge transport framing | **MISSING / OPEN** | Server challenge route is deliberately unavailable; Binding accepts abstract bytes only |
| `MBI-04` production issuer/admission/replay/Cells/Agreement outputs | **MISSING / OPEN** | Current server fails closed without installed production services; exact storage/Cell/output paths are absent |
| `MBI-05` Binding status/revoke/rotation outputs | **MISSING / OPEN** | Depends on unresolved protocol/transport decisions; exact output paths are absent |
| `MBI-06` Apple signing material | **UNAUDITED EXTERNAL INPUT / MISSING** | Portal, profile, certificate, codesign and archive inspection were forbidden; source intention is not proof |
| `MBI-07` integrated output commit/tree/digest | **MISSING / OPEN** | No authorized integration exists; no build/archive/runtime action was permitted |

`MBI-01` through `MBI-05` are locally supported absences. `MBI-06` cannot be
reproduced under this static authority and is explicitly unaudited, not
assumed. `MBI-07` does not exist and was not synthesized.

## 11. Identity cutover separation

The exact `c700…` complete tree closes source-boundary ambiguity only. It is
not evidence of:

- continuity of the production identity root;
- recovery-state or duplicate-state repair;
- physical-authority continuity;
- owner/Agreement continuity;
- resolver cutover;
- migration rollback; or
- production authority.

S0 keeps Identity cutover as a separate prerequisite with its own reviewer
and GO. APNS composition cannot grant that GO, and this review does not do so.

## 12. Prior finding disposition

| Prior finding | S0 author disposition | Independent verdict | Reason |
| --- | --- | --- | --- |
| `P1-01` owner/file-scope manifest not closed | Partial / missing-bound-input | **PARTIAL — REMAINS OPEN** | Current manifests, WIPs, no-touch and collisions are exact; future status/revoke/server/Binding outputs remain unnamed by design |
| `P1-02` `c700…` not an exact narrow lane | Author-proposed closed | **CLOSED FOR STATIC SOURCE BOUNDARY** | Complete immutable tree, 123-commit list, 192 endpoint paths, full tree and dirty exclusion all reproduce; Identity cutover remains separate NO-GO |
| `P1-03` shared transport unowned/unplaced | Partial / missing-bound-input | **PARTIAL — REMAINS OPEN** | Home/owner/proposed files and existing wrapper are assigned, but implementation is absent, challenge/status/revoke/rotation are unbound, and the fixture rule is inconsistent |
| `P2-01` missing tree/diff/dirty evidence | Author-proposed closed | **CLOSED** | Tree IDs, seven exact allowlists, diff digests, WIP/dirty ledgers and clean statuses reproduce |
| `P2-02` AASA ownership not path-exact | Author-proposed closed | **CLOSED FOR STATIC PATH OWNERSHIP** | Repo paths, collisions and fail-closed removal rule are exact; production proof remains absent |

No closed finding is interpreted as permission to open a source,
integration, signing or deployment phase.

## 13. New adversarial findings

### P0

No P0 defect was found in the S0 correction. No production action occurred.

### P1

#### P1-S0-01 — Frozen transport fixture rule cannot represent its four claimed inputs

The exact contradiction and required owner decisions are documented in
section 8.2. It blocks a shared-transport implementation packet.

#### P1-S0-02 — Production output allowlist remains intentionally incomplete

`MBI-01` through `MBI-05` leave status, revoke, challenge, production
authority/storage/Cell and Binding successor outputs without exact paths.
S0 identifies this honestly, so it is not a hidden false claim; it remains a
P1 planning blocker and prevents PLAN GO.

### P2

#### P2-S0-01 — 193 versus 192 is a metric distinction, not a count correction

The 193 per-commit union and 192 endpoint diff are both reproducible. The S0
endpoint manifest is correct, but future packets should name the metric when
describing the discrepancy.

## 14. Final adjudication

| Claim | Independent result |
| --- | --- |
| Three input documents are exact-byte bound | SUPPORTED |
| Candidate commit/tree/diff manifests are exact | SUPPORTED |
| `c700…` complete-tree source boundary is reproducible | SUPPORTED |
| Dirty bytes are excluded and no-touch ledgers reproduce | SUPPORTED |
| Current collisions and conditional AASA paths are exact | SUPPORTED |
| Existing-v3 transport schema/path facts reproduce | SUPPORTED |
| Proposed shared transport is implementable from S0 as written | CONTRADICTED |
| Every required future production output path is assigned | CONTRADICTED / MISSING-BOUND-INPUT |
| Identity cutover is complete | UNSUPPORTED AND SEPARATELY GATED |
| Signing, archive, deployment, provider or physical-device proof exists | UNAUDITED / UNSUPPORTED |
| S1 or any next phase may open | CONTRADICTED |
| Current candidates are production-ready | CONTRADICTED |

Finding count:

```text
P0: 0
P1: 2
P2: 1
```

Final decision:

```text
PLAN NO-GO
NEXT PHASE NO-GO
```

This decision remains mandatory while any one of `MBI-01` through `MBI-07`
is missing or unaudited. The only authorized outcome of this review is this
review artifact.
