# APNS-PRODUCTION-COMPOSITION-S0-CORRECTION-V1

Status: **AUTHOR-FROZEN / PLAN NO-GO / NEXT PHASE NO-GO**

Snapshot ID:
`APNS-PRODUCTION-COMPOSITION-S0-CORRECTION-V1/2026-07-24T22:52:27+0200`

Authored at: `2026-07-24T22:52:27+0200` (`CEST`)

Owned output:
`/Users/kjetil/.codex/worktrees/50d3/Binding/Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md`

This is the only file authored by this S0 correction. It does not rewrite its
input plan or independent review. It grants no authority to start S1, source
work, Git integration, build, test, dependency resolution, network access,
Apple portal access, signing, upload, device action, APNS, secrets access,
staging mutation or deployment.

Author self-review has no credit. This document stops for a new exact-byte
independent review by someone other than the author.

## 1. Exact bound inputs

| Input | Exact SHA-256 | Observed bytes | Treatment |
| --- | --- | ---: | --- |
| `Documentation/APNS_Production_Composition_Plan_2026-07-24.md` | `1c2b47a1e282dc22b230a2fd0a00ecfda6bacbf77cf4d118201b955b2df232b6` | `38154` | Immutable input |
| `Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md` | `c9cb6e09d0cd1e9748e86d0b8af3720d4c3aac18a22bc0c34cac7918619d2369` | `29346` | Immutable input |

Independent-review result bound by this correction:

- P0: `0`
- P1: `3`
- P2: `2`
- `PLAN REVIEW: NO-GO`
- `NEXT PHASE: NO-GO`

No source or external source was audited in this phase. Evidence below comes
only from local immutable Git objects, local worktree metadata, and the two
exact input documents. No secret-bearing file contents were inspected.

## 2. Purpose, goal and claim boundary

Purposes:

- `purpose://test.acceptance`: make every plan claim reproducible from exact
  bytes and keep source, archive, runtime, provider and physical evidence
  separate.
- `purpose://access.audit.privacy`: preserve domain-scoped device identity,
  Resolver/Agreement/Contract authority and secret/token non-disclosure.
- `purpose://scaffold.operations`: give every candidate and future output an
  exact owner/path/no-touch boundary without opening an operational phase.

Goal:

> Classify each P1/P2 review finding as closed, author-proposed-and-unreviewed,
> or missing-bound-input; provide exact candidate object/path/dirty evidence;
> and stop at an independently reviewable document.

Root claim:

> This S0 artifact is exact enough to receive an independent static review.

This root claim remains **unaudited** until a different reviewer verifies the
bytes. It is not a claim that the production composition is implementable or
operational.

## 3. Review-finding disposition

| Finding | S0 disposition | Exact correction | Gate |
| --- | --- | --- | --- |
| P1-01 owner/file-scope manifest not closed | **PARTIAL / MISSING-BOUND-INPUT** | Current candidate ranges, known WIPs, known reconciliation outputs, owners, no-touch and collisions are enumerated below. Future status/revoke schemas, production issuer/ledger/Cell files and their dependent client/server outputs cannot be named honestly before their contract/storage decisions exist. | Plan stays NO-GO |
| P1-02 `c700dbc…` not a narrow identity lane | **AUTHOR-PROPOSED CLOSED, UNREVIEWED** | Choose the complete immutable `c700dbc…` tree as the composition baseline. Do not consume a vague 123-commit subset and do not import dirty worktree bytes. Exact tree/diff/commit-list digests are frozen below. | Requires independent review and separate Identity cutover GO |
| P1-03 shared transport unowned/unplaced | **PARTIAL / MISSING-BOUND-INPUT** | Assign the shared existing-v3 wrapper to a new exact CellProtocol SwiftPM product/target and exact producer/consumer files. Freeze the existing register/resolve/submit wrapper schema and paths. Challenge response and missing status/revoke operations remain unbound. | Plan stays NO-GO |
| P2-01 missing tree IDs/diff allowlists/dirty ledgers | **AUTHOR-PROPOSED CLOSED, UNREVIEWED** | Exact tree IDs, null-delimited name-status digests, path lists and dirty status/patch digests are frozen below. | Requires independent review |
| P2-02 AASA owner not path-exact | **AUTHOR-PROPOSED CLOSED, UNREVIEWED** | Exact CellScaffold source/runbook/test/deploy paths and Binding entitlement/policy/preflight paths are assigned below. Include remains conditional; removal remains the fail-closed alternative. | Requires independent review |

### Reviewer count correction

The independent review describes the Identity range as `123 commits/193
paths`. Read-only reproduction gives:

- `123` commits;
- `192 files changed, 74947 insertions(+), 1248 deletions(-)`;
- `192` name-only entries; and
- `192` name-status entries.

The one-path count correction does not weaken P1-02. It is recorded here so a
new reviewer can adjudicate the exact bytes rather than inherit either count.

## 4. Immutable object and manifest ledger

All tree IDs are from `git show -s --format=%T <commit>`. A name-status digest
is SHA-256 over exact null-delimited bytes from:

```text
git diff --name-status -z <base>..<head>
```

| Manifest | Repo | Base commit/tree | Head commit/tree | Exact changed-path count | Name-status SHA-256 |
| --- | --- | --- | --- | ---: | --- |
| `M-CP-V3` | CellProtocol | `79740304167aa4f4daadd148c5a369e919d25a6a` / `71ee11a69139a1c222c2156ab1bc79dbe0115620` | `79ce4f84666fedc446a1c80ab8adce1e7e3898e0` / `92e2deff343d963f5e4d5c2d7fbe567128db3ad3` | 11 | `912ca02e45425581fca429191010002c7f756ba78e002c4b9aceca255ec68cff` |
| `M-CS-TRANSPORT` | CellScaffold | `8bb7b31b13dad09734c88217cb01b9d48801ff27` / `16ab2d81098c12975776db2b4acefb2ec75d1ff2` | `38195a233b84d09f66e5ef483800228f857fff2a` / `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` | 25 | `06cede7316f7553fb824785eaa3eae27a98ec86ebebc96f1d087233ffe217f74` |
| `M-CS-ROUTE-FIX` | CellScaffold | `38195a233b84d09f66e5ef483800228f857fff2a` / `5ef28d51e9e1351ec2fcdaeee099bd6f43b70f1f` | `d2d1b7191d651ad42d172e980ab94a0fd478d07c` / `536531541587b5229b8f325f8935ed11ef85f228` | 2 | `51c3daffedd3330995a84c27fb1d23fee4ef37a7bbfb8dd561db5211d01fa442` |
| `M-CS-IDENTITY-FULL-TREE` | CellScaffold | `8bb7b31b13dad09734c88217cb01b9d48801ff27` / `16ab2d81098c12975776db2b4acefb2ec75d1ff2` | `c700dbc5699ec3a925165d80bc2ec7ad864a1218` / `211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4` | 192 | `702589d3e8437dcadaa8048e6a2ae9efc57b94f4fcc409828c677ad7cf6f49f0` |
| `M-CS-AASA-COMMIT` | CellScaffold | parent `d22e89405cf4460f6f47fb303fb3b75a28b1d75c` | `4e4c6eb372bb08bbb71746f2cdcc1d0535d17f7a` / `761c9078ee0ee36f980e7e9550a13c56f642bfdd` | 7 | `f3ec20872b3c4dcb68bd7ec8e530cceea56ac239c03001abb1cb2e8b4936d6fa` |
| `M-BINDING-P1` | Binding | `f6536c497b0a4c0a5b32531416bb3712708cf47e` / `ac894efa9e709e788eaa1dc863db1070786fbe0b` | `fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c` / `e0d6c9ff4fb998fa252ab86621abfe24398d7b18` | 13 | `29495a23af28ca7842836f916593f9bdcde79c0d08076422b975e9c405d69f80` |
| `M-BINDING-M1` | Binding | `f6536c497b0a4c0a5b32531416bb3712708cf47e` / `ac894efa9e709e788eaa1dc863db1070786fbe0b` | `2d2412090a65e101435ea91c8ea36bc060d3c768` / `34421cbabe9e801fa96da315a191ed23cd023ec8` | 11 | `94c535870b86bcb796ff83f36dda6785db24045343f5b288499282bade13b8b0` |

Additional immutable Binding objects:

| Commit | Tree | Role |
| --- | --- | --- |
| `3791a431ddb3353c33a657a7bf2cb03cb6f557ea` | `adfb8598a70105b25636e1178fed1d73e399d5cd` | Published PR #8 inert predecessor |
| `6071ca11c207b537ce52ee4aafb686d9a4d955ae` | `e026a77a6fcf0deabc49ecc3a8a8a24287982e67` | Detached documentation observer base |
| `7884e566420cd90eb288881cc8a5df0e3685386b` | `11d72b21614056e17b1bc6991fd57f7480f8b031` | Primary dirty Binding base; no-touch |

Additional immutable repo objects:

| Repo | Commit | Tree | Role |
| --- | --- | --- | --- |
| CellProtocol | `61ffc8990afd34a601231e332e423b905e04535f` | `085b311c392b9898408a948cc3529f44dfd56b47` | Primary dirty checkout base; no-touch and not v3 |
| CellScaffold | `fc72d5133dec7f0661cf31908675e04b26909abc` | `0207cfcd766c982d63427e07d5b56fa3d3a4b5af` | Primary dirty checkout base; no-touch |

## 5. Exact candidate path allowlists

Status letters are Git name-status values relative to the exact base named in
section 4. These are immutable input manifests, not write authorization.

### 5.1 `M-CP-V3` — CellProtocol current v3 candidate

Owner: CellProtocol DeviceIngress contract owner.

```text
M Sources/CellBase/DeviceIngress/DeviceIngressAdmission.swift
A Sources/CellBase/DeviceIngress/DeviceIngressResponse.swift
M Sources/CellBase/DeviceIngress/DeviceIngressWire.swift
M Tests/CellBaseTests/DeviceIngressContractTests.swift
M Tests/CellBaseTests/DeviceIngressWireFixtureTests.swift
A Tests/CellBaseTests/Fixtures/DeviceIngressChallenge.v3.b64
A Tests/CellBaseTests/Fixtures/DeviceIngressRequest.v3.b64
A Tests/CellBaseTests/Fixtures/DeviceIngressResponse.v3.b64
A Tests/CellBaseTests/Fixtures/DeviceIngressSignedContract.v3.b64
M Tests/CellBaseTests/Fixtures/README.md
M Tests/Linux/DeviceIngressCompositionRootPositive.swift
```

Required reconciliation output additionally owns:

```text
Docs/DeviceIngressSecurityContract.md
```

No other output path is authorized by this S0 document.

### 5.2 `M-CS-TRANSPORT` — inert CellScaffold v3 server candidate

Owner: CellScaffold DeviceIngress server owner. Collision paths in section 10
are owned by the development-admin integrator only.

```text
A Documentation/DeviceCallbackCapabilityServer.md
M Documentation/Staging_Deployment.md
M Package.resolved
M Package.swift
A Sources/App/Controllers/DeviceCallbackCapabilityServer.swift
M Sources/App/Controllers/VaporDeviceCallback.swift
M Sources/App/Support/CanonicalCellRuntimeReadinessStore.swift
M Sources/App/configure.swift
M Sources/ScaffoldKit/Application+AuthSecuritySettings.swift
A Tests/AppTests/DeviceCallbackCapabilityServerTests.swift
A Tests/AppTests/Fixtures/DeviceIngressChallenge.v1.b64
A Tests/AppTests/Fixtures/DeviceIngressChallenge.v2.b64
A Tests/AppTests/Fixtures/DeviceIngressChallenge.v3.b64
A Tests/AppTests/Fixtures/DeviceIngressRequest.v1.b64
A Tests/AppTests/Fixtures/DeviceIngressRequest.v2.b64
A Tests/AppTests/Fixtures/DeviceIngressRequest.v3.b64
A Tests/AppTests/Fixtures/DeviceIngressResponse.v3.b64
A Tests/AppTests/Fixtures/DeviceIngressSignedContract.v3.b64
M Tests/AppTests/JWTAuthRoutesTests.swift
M Tests/AppTests/NotificationPushProviderTests.swift
M Tests/AppTests/TopUpCheckoutTests.swift
M docker-compose.yml
M scripts/cellscaffold-container-controller.py
M scripts/deploy-staging.sh
M scripts/tests/test_cellscaffold_container_controller.py
```

### 5.3 `M-CS-ROUTE-FIX` — route/operation successor

Owner: CellScaffold DeviceIngress server owner.

```text
M Sources/App/Controllers/VaporDeviceCallback.swift
M Tests/AppTests/DeviceCallbackCapabilityServerTests.swift
```

### 5.4 `M-CS-IDENTITY-FULL-TREE` — chosen complete Identity boundary

Owner of immutable baseline: development administrator and Identity cutover
owner jointly. The baseline is never edited. A later composition worktree, if
separately authorized, must start from the exact `c700dbc…` tree. The 192
changed paths below are all **included**. No committed path in this range is
selectively excluded. All unchanged paths inherited from the base are included
by the exact head tree ID. Current dirty worktree paths in section 7 are
excluded.

```text
M .github/workflows/admin-scaffold-image.yml
A Deployment/local-github-release-gate.suites.json
A Deployment/systemd/development-status-snapshot-producer.env.example
A Deployment/systemd/development-status-snapshot-producer.service
A Deployment/systemd/development-status-snapshot-producer.timer
A Deployment/systemd/development-status-snapshot-producer.tmpfiles.conf
M Dockerfile
M Dockerfile.admin
M Dockerfile.node-admin-tools
M Documentation/AdminScaffold_M4_Runbook.md
M Documentation/Admin_Dashboard_Architecture_2026-07-15.md
M Documentation/Admin_Development_Status_2026-07-18.md
M Documentation/Native_Linux_Deployment.md
A Documentation/Operations/Apple_Associated_Domains_Runbook.md
A Documentation/Operations/Browser_Identity_CQV1_Isolated_Recovery_Authority_V3.md
M Documentation/Operations/Browser_Identity_Continuity_Incident_Analysis_2026-07-19.md
M Documentation/Operations/Browser_Identity_Continuity_Incident_Runbook.md
A Documentation/Operations/Browser_Identity_Cross_UUID_Strict_Raw_Executor_Foundation_V1.md
A Documentation/Operations/Browser_Identity_Offline_Repair_Contract_Freeze_V1.md
A Documentation/Operations/Browser_Identity_Root_Authority_Filesystem_V3.md
A Documentation/Operations/CellScaffold_Quiesced_Backup_Inspection_Copy.md
A Documentation/Operations/Development_Admin_Handoff_2026-07-21.md
A Documentation/Operations/Development_Admin_Release_Control_Runbook.md
A Documentation/Operations/Local_GitHub_Release_Gate.md
A Documentation/Operations/Local_Release_Digest_Domains_v1.md
M Documentation/Staging_Deployment.md
M Package.swift
M Sources/App/Cells/Admin/AdminFundingCell.swift
M Sources/App/Cells/Micropayments/PaymentGateCell.swift
M Sources/App/Controllers/PortholeWebSessionSupport.swift
M Sources/App/Controllers/VaporAdminMVP.swift
M Sources/App/Controllers/VaporBrowserhead.swift
M Sources/App/Controllers/VaporButterpopStudio.swift
M Sources/App/Controllers/VaporChatMVP.swift
M Sources/App/Controllers/VaporConferenceMVP.swift
M Sources/App/Controllers/VaporMicropaymentsMVP.swift
M Sources/App/Controllers/VaporPaymentResolution.swift
M Sources/App/Controllers/VaporPersonalCopilot.swift
M Sources/App/Controllers/VaporProductControl.swift
M Sources/App/Controllers/VaporRestaurantMVP.swift
M Sources/App/Controllers/VaporVaultMVP.swift
A Sources/App/Migrations/AddFidoUserIdentityBindingInvariant.swift
M Sources/App/Models/FidoUser.swift
A Sources/App/Services/BrowserIdentityBindingCoordinator.swift
M Sources/App/Services/DevelopmentStatusSnapshot.swift
M Sources/App/Services/MVPAuthAccess.swift
M Sources/App/Services/PaymentResolutionSupport.swift
M Sources/App/Services/SecureDevelopmentStatusSnapshotFile.swift
A Sources/App/Support/HAVENAppleAppSiteAssociation.swift
M Sources/App/configure.swift
M Sources/App/routes.swift
A Sources/BrowserIdentityRecoveryOperator/main.swift
A Sources/BrowserIdentityRecoveryPOSIX/BrowserIdentityRecoveryChildSandbox.c
M Sources/BrowserIdentityRecoveryPOSIX/BrowserIdentityRecoveryPOSIX.c
A Sources/BrowserIdentityRecoveryPOSIX/include/BrowserIdentityRecoveryChildSandbox.h
M Sources/BrowserIdentityRecoveryPOSIX/include/BrowserIdentityRecoveryPOSIX.h
A Sources/DevelopmentStatusSnapshotProducer/main.swift
A Sources/DevelopmentStatusSnapshotProducerCore/DevelopmentStatusSnapshotProducerCore.swift
M Sources/ScaffoldKit/Application+AuthSecuritySettings.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantine.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineAuthorization.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineAuthorizationV2.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineCipher.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineControllerCheckpointV2.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineFilesystemReceiptV2.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineIsolatedRecoveryAuthorityV3.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineJournalV2.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantinePersistentReplayLedgerV2.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDQuarantineVerifierTokenV2.swift
A Sources/ScaffoldKit/BrowserClientIdentityCrossUUIDStrictRawRepairExecutorV1.swift
A Sources/ScaffoldKit/BrowserClientIdentityLinuxChildExecutorV1.swift
A Sources/ScaffoldKit/BrowserClientIdentityLinuxChildSandboxV1.swift
M Sources/ScaffoldKit/BrowserClientIdentityOfflineInspector.swift
A Sources/ScaffoldKit/BrowserClientIdentityOfflineRepairContractV1.swift
A Sources/ScaffoldKit/BrowserClientIdentityPhysicalAuthorityAttestationV1.swift
A Sources/ScaffoldKit/BrowserClientIdentityPhysicalAuthorityProviderV1.swift
M Sources/ScaffoldKit/BrowserClientIdentityReconciliation.swift
A Sources/ScaffoldKit/BrowserClientIdentityRecordClassification.swift
M Sources/ScaffoldKit/BrowserClientIdentityRecoveryExecutor.swift
A Sources/ScaffoldKit/BrowserClientIdentityRecoveryOperator.swift
A Sources/ScaffoldKit/BrowserClientIdentityRootAuthorityFilesystemV3.swift
M Sources/ScaffoldKit/BrowserClientIdentityVault.swift
M Sources/ScaffoldKit/PaymentGateOwnerIdentitySupport.swift
M Tests/AppTests/AdminCatalogRoutesTests.swift
M Tests/AppTests/AdminCopilotWorkspaceConfigurationTests.swift
M Tests/AppTests/AdminFundingCellTests.swift
M Tests/AppTests/AdminNodeFleetCellTests.swift
M Tests/AppTests/ArendalsukaImportAuthorizationRoutesTests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineAuthorizationV2Tests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineCipherTests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineControllerCheckpointV2Tests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineFilesystemReceiptV2Tests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineIsolatedRecoveryAuthorityV3Tests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineJournalV2Tests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantinePersistentReplayLedgerV2Tests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineTests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDQuarantineVerifierTokenV2Tests.swift
A Tests/AppTests/BrowserClientIdentityCrossUUIDStrictRawRepairExecutorV1Tests.swift
A Tests/AppTests/BrowserClientIdentityLinuxChildExecutorV1Tests.swift
M Tests/AppTests/BrowserClientIdentityOfflineInspectorTests.swift
A Tests/AppTests/BrowserClientIdentityOfflineRepairContractV1Tests.swift
A Tests/AppTests/BrowserClientIdentityPhysicalAuthorityProviderV1Tests.swift
M Tests/AppTests/BrowserClientIdentityReconciliationTests.swift
A Tests/AppTests/BrowserClientIdentityRecordClassificationTests.swift
M Tests/AppTests/BrowserClientIdentityRecoveryExecutorTests.swift
A Tests/AppTests/BrowserClientIdentityRecoveryOperatorTests.swift
A Tests/AppTests/BrowserClientIdentityRootAuthorityFilesystemV3Tests.swift
M Tests/AppTests/BrowserClientIdentityVaultTests.swift
A Tests/AppTests/BrowserIdentityBindingCoordinatorTests.swift
M Tests/AppTests/ButterpopStudioProductTests.swift
M Tests/AppTests/CellScaffoldRuntimeIdentityRegistryTests.swift
M Tests/AppTests/ChatMVPRoutesTests.swift
M Tests/AppTests/ConferenceConnectionHubCellTests.swift
M Tests/AppTests/ConferenceOrganizerProjectionCellTests.swift
M Tests/AppTests/ConferencePublishedContentCellTests.swift
M Tests/AppTests/ConferenceSchedulingCellTests.swift
M Tests/AppTests/ConferenceSponsorLeadAggregateCellTests.swift
M Tests/AppTests/ConferenceSurfaceRoutesTests.swift
M Tests/AppTests/ContractChallengeMVPRoutesTests.swift
M Tests/AppTests/DevelopmentStatusRoutesTests.swift
A Tests/AppTests/DevelopmentStatusSnapshotProducerTests.swift
M Tests/AppTests/DevelopmentStatusSnapshotTests.swift
M Tests/AppTests/EventPlatformRoutesTests.swift
A Tests/AppTests/FidoUserIdentityBindingInvariantTests.swift
A Tests/AppTests/HAVENAppleAppSiteAssociationTests.swift
M Tests/AppTests/JWTAuthRoutesTests.swift
M Tests/AppTests/MicropaymentsMVPRoutesTests.swift
M Tests/AppTests/PaymentGateCellTests.swift
M Tests/AppTests/PaymentGateOwnerIdentitySupportTests.swift
M Tests/AppTests/PortholeConfigurationLoadingTests.swift
M Tests/AppTests/PortholeIdentityContinuityRoutesTests.swift
M Tests/AppTests/PortholeWebSessionPersonaTests.swift
M Tests/AppTests/RAGCellAccessSecurityTests.swift
M Tests/AppTests/RAGGatewayCellTests.swift
M Tests/AppTests/SecureDevelopmentStatusSnapshotFileTests.swift
A Tests/AppTests/Support/BrowserClientIdentityCrossUUIDStrictRawRealV3FixtureV1.swift
A Tests/AppTests/Support/IdentityAuthorityFixtures.swift
M Tests/AppTests/TopUpCheckoutTests.swift
A Tests/fixtures/development-status-producer/codex-task.json
A Tests/fixtures/development-status-producer/github.json
A Tests/fixtures/development-status-producer/graph-store.json
A Tests/fixtures/development-status-producer/human-decision.json
A Tests/fixtures/development-status-producer/project-portfolio.json
A Tests/fixtures/development-status-producer/release-ci.json
A Tests/fixtures/development-status-producer/work-item.json
M docker-compose.yml
A scripts/browser-client-identity-recovery-host.py
A scripts/browser-identity-recovery-inspect-controller.py
A scripts/browser-identity-recovery-inspect-launcher.c
M scripts/build-native-linux.sh
A scripts/cellscaffold-backup-archive.py
M scripts/cellscaffold-container-controller.py
A scripts/cellscaffold-quiesced-backup.sh
A scripts/cellscaffold-restore-observe.sh
A scripts/create_local_release_policy.py
M scripts/deploy-admin-staging.sh
A scripts/import_local_release_evidence.py
A scripts/local-release-launcher-v2/go.mod
A scripts/local-release-launcher-v2/main.go
A scripts/local-release-launcher-v2/main_test.go
A scripts/local-release-launcher-v2/secure_linux.go
A scripts/local-release-launcher-v2/secure_linux_test.go
A scripts/local-release-launcher-v2/secure_other.go
A scripts/local_github_release_gate.py
A scripts/local_release_digest_domains_v1.py
A scripts/local_release_external_controller_v2.py
A scripts/local_release_runner_contract_v3.py
A scripts/local_release_runner_observation_compiler_v4.py
A scripts/local_release_runner_observation_contract_v4.py
M scripts/package-native-linux.sh
A scripts/package-resolved-mirror-normalization.py
A scripts/publish_github_release_status.py
M scripts/run-admin-m4-gate.sh
A scripts/sign_local_release_evidence.py
M scripts/test-admin-deployment-contracts.sh
A scripts/test-compose-config-with-placeholders.sh
A scripts/test-local-release-launcher-v2.sh
A scripts/tests/fixtures/local_release_digest_domains_v1_golden.json
A scripts/tests/test_aasa_compose_contract.py
A scripts/tests/test_browser_client_identity_recovery_host.py
A scripts/tests/test_browser_identity_recovery_inspect_controller.py
M scripts/tests/test_cellscaffold_container_controller.py
A scripts/tests/test_cellscaffold_quiesced_backup_restore.py
A scripts/tests/test_local_github_release_gate.py
A scripts/tests/test_local_release_digest_domains_v1.py
A scripts/tests/test_local_release_external_controller_gate.py
A scripts/tests/test_local_release_runner_contract_v3.py
A scripts/tests/test_local_release_runner_observation_compiler_v4.py
A scripts/tests/test_local_release_runner_observation_contract_v4.py
A scripts/tests/test_local_swiftpm_release_gate.py
A scripts/tests/test_package_resolved_mirror_normalization.py
A scripts/verify_local_release_deploy_preflight.py
```

Full-tree binding:

| Property | Exact value |
| --- | --- |
| Head commit | `c700dbc5699ec3a925165d80bc2ec7ad864a1218` |
| Head tree | `211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4` |
| Tracked entries in head tree | `1566` |
| SHA-256 of `git ls-tree -r -z c700dbc…` | `b1f11701fbdf07b91824f6a6fbe82cf8ee983be1968bde20f12e035672c33824` |
| Commit count from `8bb7b31…` | `123` |
| SHA-256 of newline-delimited oldest-first commit list | `6d2ac736c34f6dd7c6d143ddd70bdaad0a8b2a34d050d7236602fb93dc467f39` |
| SHA-256 of null-delimited changed-path name-status | `702589d3e8437dcadaa8048e6a2ae9efc57b94f4fcc409828c677ad7cf6f49f0` |

Composition rule:

- The 123 commits are provenance, not 123 independently selectable inputs.
- A later server composition must use the complete `c700dbc…` tree as one
  immutable baseline or stop.
- No path from the committed tree may be selectively dropped.
- The exact APNS deltas must be reconciled on top under the collision rules;
  they must not redefine Identity authority or declare Identity cutover green.
- A future composition manifest must record the base commit/tree, full-tree
  digests above, APNS input commits/trees/diff digests, output commit/tree,
  collision resolutions and reviewer identities. SHA-256 is computed over
  UTF-8 canonical JSON with sorted keys, no insignificant whitespace and the
  schema string
  `haven.apns-production-composition.full-tree-manifest.v1`.
- No output digest exists now. Inventing one would falsely claim an integration
  tree exists.

### 5.5 `M-CS-AASA-COMMIT` — conditional AASA candidate

Owner: AASA/origin owner. This commit is not an ancestor of `c700dbc…`; both
share merge base `8bb7b31…`. All seven paths collide with paths already changed
in the chosen full-tree baseline.

```text
M .github/workflows/admin-scaffold-image.yml
M Documentation/Operations/Apple_Associated_Domains_Runbook.md
M Sources/App/Support/HAVENAppleAppSiteAssociation.swift
M Tests/AppTests/HAVENAppleAppSiteAssociationTests.swift
M scripts/cellscaffold-container-controller.py
M scripts/tests/test_aasa_compose_contract.py
M scripts/tests/test_cellscaffold_container_controller.py
```

This input is **DEFERRED**, not consumed. Associated Domains must be removed
from the App Store composition unless a later, separately reviewed AASA
reconciliation is exact and production proof is available.

### 5.6 `M-BINDING-P1` — complete Binding DeviceIngress candidate range

Owner: Binding DeviceIngress owner. Collision paths are integrator-owned.

```text
M Binding.xcodeproj/project.pbxproj
A Binding/BindingBuildProvenance.swift
D Binding/DeviceCallbackCapabilityContract.swift
A Binding/DeviceIngressRegistrationClient.swift
M Binding/NotificationCallbackClient.swift
M Binding/NotificationConsentBanner.swift
M Binding/NotificationEnrollmentManager.swift
D BindingTests/DeviceCallbackCapabilityContractTests.swift
A BindingTests/DeviceIngressRegistrationClientTests.swift
M BindingTests/NotificationCallbackClientTests.swift
M BindingTests/NotificationEnrollmentManagerTests.swift
M Documentation/DeviceCallbackCapabilityContract.md
A Scripts/generate_binding_build_provenance.sh
```

### 5.7 `M-BINDING-M1` — Apple identifiers/origin candidate

Owner: Binding Apple release owner. `Binding.xcodeproj/project.pbxproj` is
integrator-owned because it collides with `M-BINDING-P1`.

```text
M Binding.xcodeproj/project.pbxproj
A Documentation/AppleReleaseM0Policy.template.json
A Documentation/AppleReleaseM0Preflight.md
A Scripts/apple_release_m0_preflight.py
A Scripts/apple_release_m0_preflight.sh
A Tests/apple_release_m0_preflight_tests.py
A Tests/fixtures/apple_release_m0_preflight/facts-dirty.json
A Tests/fixtures/apple_release_m0_preflight/facts-pass.json
A Tests/fixtures/apple_release_m0_preflight/policy-mismatch.json
A Tests/fixtures/apple_release_m0_preflight/policy-pass.json
A Tests/fixtures/apple_release_m0_preflight/policy-pending.json
```

## 6. Known uncommitted candidate/WIP path ledgers

These bytes are not candidate commits. Paths are listed only to prevent
collision or accidental directory-copy integration.

### 6.1 Binding APNS fail-closed WIP

Worktree:
`/private/tmp/haven-binding-v1-push-20260723`

Base commit/tree:
`fefcc3fc3ef2a36e5a9ff1ffd13da8ce7c37647c` /
`e0d6c9ff4fb998fa252ab86621abfe24398d7b18`

```text
M Binding/DeviceIngressRegistrationClient.swift
M Binding/NotificationConsentBanner.swift
M BindingTests/DeviceIngressRegistrationClientTests.swift
M Documentation/DeviceCallbackCapabilityContract.md
```

- status-ledger SHA-256:
  `8dc28f54c0b20d818bdb0c7b41652da8490d4dc8dd5bef50b2591df66044648d`
- tracked binary-patch SHA-256:
  `18c4b3b7795210d7e55acac6588d270be51ea219e31b2d2b2cba7045e854d0c8`
- treatment: **EXCLUDED WIP** until separately committed/reviewed; never copy
  directory bytes.

### 6.2 CellScaffold APNS provider WIP

Worktree:
`/private/tmp/haven-cellscaffold-v1-push-20260723`

Base commit/tree:
`d2d1b7191d651ad42d172e980ab94a0fd478d07c` /
`536531541587b5229b8f325f8935ed11ef85f228`

```text
M Documentation/DeviceCallbackCapabilityServer.md
M Sources/App/Cells/ConferenceMVP/Notifications/PushProviderAdapter.swift
M Tests/AppTests/NotificationPushProviderTests.swift
```

- status-ledger SHA-256:
  `463c92bbc0060c0790141bcc53b062a685bcae1a79e2a637d2295381b7edff01`
- tracked binary-patch SHA-256:
  `a1bcc57a59f9bbcf5f545fc51a43efd13599f36451186981dbc607d0afa80963`
- treatment: **EXCLUDED WIP** until separately committed/reviewed.

### 6.3 Binding catalog/Associated-Domains WIP

Worktree:
`/private/tmp/haven-binding-v1-catalog-20260723`

Base commit/tree:
`2d2412090a65e101435ea91c8ea36bc060d3c768` /
`34421cbabe9e801fa96da315a191ed23cd023ec8`

```text
M Binding/Binding-iOS.entitlements
M Binding/ContentView.swift
M Binding/PortableSurfaceSupport.swift
M Binding/RemoteCatalogSupport.swift
M BindingTests/BindingTests.swift
M Cells/ConfigurationCatalogCell.swift
?? BindingTests/Fixtures/
```

- status-ledger SHA-256:
  `327a3c5c4ae0c301bf567c3b2dd735509ada915e5b730a80f731a7bca9dd4765`
- tracked binary-patch SHA-256:
  `cc00fc28abfab133ccfd2658f58db2131cbc18840256a7aa4b2b636cebd8ee5f`
- untracked fixture contents were not read or hashed.
- treatment: **EXCLUDED WIP**. Associated Domains defaults to removed.

## 7. Exact no-touch dirty ledgers

Status digest is SHA-256 over `git status --porcelain=v1 -z`. Patch digest is
SHA-256 over tracked `git diff --binary`; it excludes untracked contents.
Untracked contents were not read.

### 7.1 Identity candidate worktree — exclude every dirty byte

Worktree:
`/private/tmp/haven-identity-release-candidate-v2`

Committed boundary:
`c700dbc5699ec3a925165d80bc2ec7ad864a1218` /
`211d0b89bf65f8c6cb91f908245b14bf2c0fcbe4`

```text
M Documentation/Operations/Browser_Identity_Root_Authority_Filesystem_V3.md
M Sources/BrowserIdentityRecoveryPOSIX/BrowserIdentityRecoveryChildSandbox.c
M Sources/BrowserIdentityRecoveryPOSIX/include/BrowserIdentityRecoveryChildSandbox.h
M Sources/BrowserIdentityRecoveryPOSIX/include/BrowserIdentityRecoveryPOSIX.h
M Sources/ScaffoldKit/BrowserClientIdentityLinuxChildExecutorV1.swift
M Sources/ScaffoldKit/BrowserClientIdentityPhysicalAuthorityAttestationV1.swift
M Sources/ScaffoldKit/BrowserClientIdentityPhysicalAuthorityProviderV1.swift
M Sources/ScaffoldKit/BrowserClientIdentityRootAuthorityFilesystemV3.swift
M Tests/AppTests/BrowserClientIdentityLinuxChildExecutorV1Tests.swift
M Tests/AppTests/BrowserClientIdentityPhysicalAuthorityProviderV1Tests.swift
?? Documentation/Operations/Browser_Identity_Linux_Child_Descriptor_Preflight_P1.md
```

- status digest:
  `151491a531ba7fa28367c79b9f739f2f1de5b9d4e284373f4ee89a4f6c5ff53f`
- tracked patch digest:
  `96bd1aa0ddba65e094f0a713c5a5f95431c79bd0a0915827d1ba008b922a6feb`
- treatment: all listed bytes are excluded from the full-tree boundary.

### 7.2 Primary CellProtocol checkout — no touch

Commit/tree:
`61ffc8990afd34a601231e332e423b905e04535f` /
`085b311c392b9898408a948cc3529f44dfd56b47`

```text
M Package.swift
M Sources/CellBase/Cells/Chat/ChatCell.swift
M Sources/CellBase/Cells/Chat/ChatMessage.swift
M Sources/CellBase/Cells/Chat/ChatPresentation.swift
M Tests/CellBaseTests/ChatCellTests.swift
?? haven-browser-recovery-cp/
```

- status digest:
  `441fd800ec554cf79df648d4290269d9a756bf98ee05dc5f86af5a20ee1a5f57`
- tracked patch digest:
  `3c3f9391bd4e9afdd597ba803f1bb0d64d745082d0233f20fed9427753f8b67c`

### 7.3 Primary Binding checkout — no touch

Commit/tree:
`7884e566420cd90eb288881cc8a5df0e3685386b` /
`11d72b21614056e17b1bc6991fd57f7480f8b031`

```text
M Binding.xcodeproj/project.pbxproj
M Binding/Assets.xcassets/AccentColor.colorset/Contents.json
M Binding/Assets.xcassets/AppIcon.appiconset/Contents.json
D Binding/Assets.xcassets/AppIcon.appiconset/Gemini_Generated_Image_55bo1j55bo1j55bo.png
M Binding/BootstrapView.swift
M Binding/ContentView.swift
M Binding/RootView.swift
M BindingTests/BindingTests.swift
M Cells/ConfigurationCatalogCell.swift
M HavenAgentD/Docs/CellConfiguration.network-sentinel.json
M HavenAgentD/Docs/NetworkSentinelCell.md
M HavenAgentD/Sources/HavenAgentCellRuntime/AgentCellRuntimeHost.swift
M HavenAgentD/Sources/HavenAgentCells/NetworkSentinelCell.swift
M HavenAgentD/Sources/HavenAgentRuntime/AgentConfig.swift
M HavenAgentD/Sources/HavenAgentRuntime/NetworkAlertNotificationDispatcher.swift
M HavenAgentD/Sources/HavenAgentRuntime/NetworkHealth.swift
M HavenAgentD/Sources/HavenAgentRuntime/NetworkHealthPurposeCatalog.swift
M HavenAgentD/Sources/HavenAgentRuntime/NetworkReachabilityProbe.swift
M HavenAgentD/Sources/HavenAgentRuntime/NetworkSentinelService.swift
M HavenAgentD/Tests/HavenAgentRuntimeTests/NetworkHealthPurposeCatalogTests.swift
M HavenAgentD/Tests/HavenAgentRuntimeTests/NetworkSentinelConfigTests.swift
M HavenAgentD/Tests/HavenAgentRuntimeTests/NetworkSentinelServiceTests.swift
M Scripts/run_nearby_scanner_device_pair_test.sh
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-1024.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-Dark-1024.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-Tinted-1024.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-128.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-128@2x.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-16.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-16@2x.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-256.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-256@2x.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-32.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-32@2x.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-512.png
?? Binding/Assets.xcassets/AppIcon.appiconset/HavenAppIcon-mac-512@2x.png
?? Binding/HavenArcMark.swift
?? Documentation/HavenAppIconPanelDecision_2026-07-21.md
?? Scripts/generate_haven_app_icons.swift
?? gfx/HavenAppIconConcept_ImageGen.png
?? gfx/HavenAppIconSource.svg
```

- status digest:
  `f3c275dfbe64cb8a1848c2ccc735e440dd4083ad867695ce1aec7e011be192d7`
- tracked patch digest:
  `4de198d126c1b8ffe2605af07dde35d29ff77a071773e311514d2e19ba7261dc`

### 7.4 Primary CellScaffold checkout — no touch

Commit/tree:
`fc72d5133dec7f0661cf31908675e04b26909abc` /
`0207cfcd766c982d63427e07d5b56fa3d3a4b5af`

```text
M Documentation/ClaudeSkills/README.md
M Documentation/Operations/assistant_handoff.md
M Package.swift
M Sources/App/Cells/ConfigurationCatalog/ConfigurationCatalogCell.swift
M Sources/App/Cells/EntityScaffoldEnrollment/EntityScaffoldEnrollmentCell.swift
D Sources/App/Services/NodeAdminAgentDelivery.swift
D Sources/App/Services/NodeAdminAgentSnapshotBuilder.swift
M Sources/App/Services/ScaffoldEntityAtlasCatalog.swift
M Sources/App/configure.swift
M Sources/NodeAdminAgent/main.swift
M Tests/AppTests/EntityScaffoldEnrollmentCellTests.swift
D Tests/AppTests/NodeAdminAgentDeliveryTests.swift
?? .claude/skills/cellprotocol-distributed-entity-data/
?? .claude/skills/personal-data-trust-package/
?? Documentation/Arendalsuka_Maturity_Assessment_2026-07-20.md
?? Documentation/Arendalsuka_Readiness_Evaluation_2026-07-18.md
?? Documentation/Arendalsuka_Validation_Plan_2026-07-20.md
?? Documentation/ClaudeSkills/desktop-src/cellprotocol-distributed-entity-data/
?? Documentation/ClaudeSkills/desktop-src/personal-data-trust-package/
?? Documentation/ClaudeSkills/desktop-zips/cellprotocol-distributed-entity-data.zip
?? Documentation/ClaudeSkills/desktop-zips/personal-data-trust-package.zip
?? Documentation/Entity_Distributed_Data_Architecture_2026-07-23.md
?? Documentation/HAVEN_Development_Tooling_Availability_Analysis_Work_Item_2026-07-23.md
?? Documentation/Personal_Butler_Onboarding_Evaluation_2026-07-20.md
?? Documentation/Personal_Data_Trust_Package_2026-07-23.md
?? Packaging/
?? Sources/App/Cells/PersonalDataTrustPackage/
?? Sources/ScaffoldKit/DistributedEntityData/
?? Sources/ScaffoldKit/NodeAdminAgentDelivery.swift
?? Sources/ScaffoldKit/NodeAdminAgentSnapshotBuilder.swift
?? Tests/AdminPlaneTests/
?? Tests/AppTests/PersonalDataTrustPackageCellTests.swift
?? Tests/fixtures/distributed-entity-data/
```

- status digest:
  `a8ae6601e0d32a5824e18bdbd9b1af07b886f3058eacf9263de203d77383edff`
- tracked patch digest:
  `9a6b3e74f429072df139409f7724544dd7dd2fcb14388a0906e2a6ba60d5dd79`

### 7.5 Clean candidate worktrees

| Worktree | Commit/tree | Status digest | Treatment |
| --- | --- | --- | --- |
| Binding P1 `/private/tmp/haven-binding-device-ingress-v3-p1-fix-20260721/Binding` | `fefcc3…` / `e0d6c9…` | empty SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | Immutable source object only |
| Binding M1 `/Users/kjetil/.codex/worktrees/9abf/Binding` | `2d2412…` / `34421c…` | empty SHA | Immutable source object only |
| CellScaffold transport `/private/tmp/haven-apns-device-ingress-v3-isolated/CellScaffold` | `38195a…` / `5ef28d…` | empty SHA | Immutable source object only |
| AASA `/private/tmp/haven-aasa-contract-20260721` | `4e4c6e…` / `761c90…` | empty SHA | Conditional, deferred input |

### 7.6 Documentation observer

Before this S0 file was created, the detached observer at `6071ca…` had three
untracked documents and no tracked diff:

```text
?? Documentation/APNS_End_to_End_Readiness_Handoff_2026-07-24.md
?? Documentation/APNS_Production_Composition_Plan_2026-07-24.md
?? Documentation/APNS_Production_Composition_Plan_Independent_Review_2026-07-24.md
```

Pre-S0 status digest:
`ea668227e62df595c553ef62034ac9540f91acaaa93399c62510c0cf8cf23734`

Tracked patch digest:
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

The post-S0 ledger must add exactly this file and no other path.

## 8. Exact owner and output-path allowlist

Paths not listed here are not future output authorization. A future task must
receive its own ADMIN-GO and an independently reviewed exact allowlist.

| Owner | Repo | Exact future output paths allowed by this plan packet | State |
| --- | --- | --- | --- |
| S0 documentation author | Binding observer | `Documentation/APNS_Production_Composition_Plan_S0_Correction_2026-07-24.md` | Current authorized output; stop after write |
| Independent S0 reviewer | Binding observer | one new review file whose exact name must be supplied by admin | **MISSING-BOUND-INPUT**; reviewer is read-only until separately authorized |
| CellProtocol current-v3 reconciliation owner | CellProtocol | all 11 `M-CP-V3` paths plus `Docs/DeviceIngressSecurityContract.md` | Exact scope defined, but S1 is not opened |
| CellProtocol status/revoke contract owner | CellProtocol | none | **MISSING-BOUND-INPUT:** enum/schema/fixture/version decisions and exact paths do not exist |
| CellProtocol shared transport owner | CellProtocol | `Package.swift`; `Sources/CellDeviceIngressTransport/DeviceIngressHTTPTransport.swift`; `Tests/CellDeviceIngressTransportTests/DeviceIngressHTTPTransportTests.swift`; `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransport.v3.json`; `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressChallenge.v3.b64`; `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressRequest.v3.b64`; `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressResponse.v3.b64`; `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressSignedContract.v3.b64` | Author-proposed exact placement; not independently reviewed and no S3 opened |
| Identity full-tree boundary owner | CellScaffold | no writes; immutable tree `211d0b89…` only | Full-tree input chosen; Identity cutover remains separate |
| CellScaffold DeviceIngress consumer owner | CellScaffold | existing `Sources/App/Controllers/DeviceCallbackCapabilityServer.swift`; `Sources/App/Controllers/VaporDeviceCallback.swift`; `Tests/AppTests/DeviceCallbackCapabilityServerTests.swift`; `Tests/AppTests/Fixtures/DeviceIngressChallenge.v3.b64`; `Tests/AppTests/Fixtures/DeviceIngressRequest.v3.b64`; `Tests/AppTests/Fixtures/DeviceIngressResponse.v3.b64`; `Tests/AppTests/Fixtures/DeviceIngressSignedContract.v3.b64`; `Package.swift`; `Package.resolved` | Existing-v3 transport consumption only; no source phase opened |
| CellScaffold production issuer/admission/status/revoke owner | CellScaffold | none | **MISSING-BOUND-INPUT:** storage backend, Cell types, Agreement source and successor operations are not decided |
| CellScaffold APNS provider owner | CellScaffold | WIP paths in section 6.2 only | WIP excluded; future commit/review required |
| Binding DeviceIngress owner | Binding | all 13 `M-BINDING-P1` paths | Input/reconciliation boundary only |
| Binding shared transport consumer owner | Binding | `Binding/DeviceIngressHTTPTransport.swift`; `BindingTests/DeviceIngressHTTPTransportTests.swift`; `BindingTests/Fixtures/DeviceIngressHTTPTransport.v3.json`; `Binding.xcodeproj/project.pbxproj`; `Binding/DeviceIngressRegistrationClient.swift` | Author-proposed exact placement; not reviewed and no source phase opened |
| Binding status/revoke/rotation owner | Binding | none | **MISSING-BOUND-INPUT:** depends on missing protocol and transport operations |
| Binding Apple release owner | Binding | all 11 `M-BINDING-M1` paths; `Binding/Binding-iOS.entitlements` | Planning/signing proof boundary only |
| AASA/origin owner | CellScaffold + Binding | CellScaffold seven `M-CS-AASA-COMMIT` paths; Binding `Binding/Binding-iOS.entitlements`, `Documentation/AppleReleaseM0Policy.template.json`, `Documentation/AppleReleaseM0Preflight.md`, `Scripts/apple_release_m0_preflight.py`, `Tests/apple_release_m0_preflight_tests.py` | Conditional and deferred; remove Associated Domains unless separately green |
| Development-admin integrator | CellScaffold + Binding | collision paths listed in section 10 only | No integration phase opened |

## 9. Shared exact-byte transport freeze

### 9.1 Assigned artifact

| Property | Frozen value |
| --- | --- |
| Repository | CellProtocol |
| SwiftPM product | `CellDeviceIngressTransport` |
| SwiftPM target | `CellDeviceIngressTransport` |
| Producer implementation | `Sources/CellDeviceIngressTransport/DeviceIngressHTTPTransport.swift` |
| Producer tests | `Tests/CellDeviceIngressTransportTests/DeviceIngressHTTPTransportTests.swift` |
| Producer outer-wrapper fixture | `Tests/CellDeviceIngressTransportTests/Fixtures/DeviceIngressHTTPTransport.v3.json` |
| Canonical signed-byte fixture producer | CellProtocol `M-CP-V3` fixture paths |
| Server consumer | exact CellScaffold paths in section 8 |
| Binding consumer | exact Binding paths in section 8 |
| Primary owner | CellProtocol shared transport owner |
| Required reviewers | CellProtocol contract/security reviewer; cross-runtime compatibility reviewer; CellScaffold consumer reviewer; Binding consumer reviewer |

### 9.2 Existing-v3 schema frozen from `d2d1b719…`

This is a transport schema, not a capability or authority source.

| Field | Exact existing value |
| --- | --- |
| Wrapper schema | `haven.device-callback.transport.v3` |
| Wrapper fields | `schema`, `canonicalChallenge`, `canonicalRequest`, `protectedBody` |
| Binary-in-JSON encoding | Swift `Codable` `Data` base64 strings |
| Maximum wrapper bytes | `327680` (`320 * 1024`) |
| Maximum each canonical challenge/request | `65536` bytes |
| Maximum protected body | `65536` bytes |
| Register method/path | `POST /conference-mvp/api/device/register` |
| Resolve method/path | `POST /conference-mvp/api/device/callback/resolve` |
| Submit method/path | `POST /conference-mvp/api/device/callback/submit` |
| Success response | raw canonical `DeviceIngressOperationResponse` bytes; no outer wrapper |
| Authority | none; Resolver-selected Cell, owner, Agreement/Contract and `DeviceIngressAdmissionService` remain authoritative |

The producer fixture must encode one outer wrapper containing exact decoded
bytes from the four canonical CellProtocol v3 fixtures. Each consumer must:

1. pin SHA-256 for the producer fixture and all copied canonical fixtures;
2. prove byte equality after outer decoding;
3. reject unknown schema, missing/empty fields, oversize fields, malformed
   base64, wrong HTTP method/path operation and legacy authorization;
4. return transport errors as transport errors; and
5. never decode/re-encode signed bytes before CellProtocol verification.

### 9.3 Transport missing-bound-inputs

The following cannot be derived exactly from current source without inventing
a contract:

- request schema/body for
  `POST /conference-mvp/api/device/challenge`;
- exact successful challenge response framing;
- canonical operation names, paths and response/result types for current
  status/read-back;
- canonical operation names, paths and response/result types for
  revoke/deregister; and
- token-rotation reconciliation operation/result binding.

Therefore P1-03 is only partially closed. No transport implementation may
start from this document.

## 10. Exact collision and no-touch matrix

Only the development-admin integrator may resolve a collision, in a new clean
worktree and only after all owning lanes are independently green.

| Collision | Exact paths | Resolution rule | Current gate |
| --- | --- | --- | --- |
| Identity full tree × CellScaffold transport | `Documentation/Staging_Deployment.md`; `Package.swift`; `Sources/App/configure.swift`; `Sources/ScaffoldKit/Application+AuthSecuritySettings.swift`; `Tests/AppTests/JWTAuthRoutesTests.swift`; `Tests/AppTests/TopUpCheckoutTests.swift`; `docker-compose.yml`; `scripts/cellscaffold-container-controller.py`; `scripts/tests/test_cellscaffold_container_controller.py` | Start from exact Identity full tree; replay/reconcile APNS delta path-by-path; both owners review final bytes | NO-GO |
| Identity full tree × route fix | none | `M-CS-ROUTE-FIX` remains a separate exact delta after transport reconciliation | NO-GO |
| Identity full tree × AASA candidate | all seven `M-CS-AASA-COMMIT` paths | Do not consume AASA commit now. Remove Associated Domains or later reconcile all seven with AASA + Identity reviewers | DEFER/NO-GO |
| Identity full tree × provider WIP | none | Provider remains separate excluded WIP | NO-GO |
| CellScaffold transport × provider WIP | `Documentation/DeviceCallbackCapabilityServer.md`; `Tests/AppTests/NotificationPushProviderTests.swift` | Server integrator owns final bytes; transport and provider reviewers both sign off | NO-GO |
| Route fix × provider WIP | none | Preserve exact order after transport candidate | NO-GO |
| Binding P1 × Apple M1 | `Binding.xcodeproj/project.pbxproj` | Binding integrator owns final project file; both lane owners review settings and source membership | NO-GO |
| Binding P1 × Binding APNS WIP | `Binding/DeviceIngressRegistrationClient.swift`; `Binding/NotificationConsentBanner.swift`; `BindingTests/DeviceIngressRegistrationClientTests.swift`; `Documentation/DeviceCallbackCapabilityContract.md` | WIP cannot be directory-copied; future committed diff must be reviewed against P1 | NO-GO |
| Binding P1 × catalog WIP | none | Catalog remains excluded | DEFER |
| Binding M1 × catalog WIP | none in tracked diff; catalog adds entitlement path not in M1 diff | Associated Domains entitlement remains excluded unless AASA lane is green | DEFER |
| CellProtocol current-v3 reconciliation × proposed transport | `Package.swift` is transport-only; DeviceIngress source/fixtures are contract-owned and read-only inputs to transport tests | One writer per path. Transport copies fixtures only after contract artifact is immutable | NO-GO |
| Primary dirty worktrees × every lane | every path in section 7 | No source work occurs in a primary dirty worktree; no copying or cleanup | HARD NO-TOUCH |
| Identity candidate dirty bytes × full-tree baseline | all 11 paths in section 7.1 | Only committed `c700dbc…` tree exists for composition; dirty bytes excluded | HARD NO-TOUCH |

## 11. Path-exact conditional AASA ownership

Production intention remains:

- bundle: `org.digipomps.haven`;
- origin: `https://haven.digipomps.org`;
- APNS topic: `org.digipomps.haven`; and
- optional associated domain:
  `applinks:haven.digipomps.org`.

CellScaffold AASA owner paths:

```text
.github/workflows/admin-scaffold-image.yml
Documentation/Operations/Apple_Associated_Domains_Runbook.md
Sources/App/Support/HAVENAppleAppSiteAssociation.swift
Tests/AppTests/HAVENAppleAppSiteAssociationTests.swift
scripts/cellscaffold-container-controller.py
scripts/tests/test_aasa_compose_contract.py
scripts/tests/test_cellscaffold_container_controller.py
```

Binding AASA/decision/preflight owner paths:

```text
Binding/Binding-iOS.entitlements
Documentation/AppleReleaseM0Policy.template.json
Documentation/AppleReleaseM0Preflight.md
Scripts/apple_release_m0_preflight.py
Tests/apple_release_m0_preflight_tests.py
```

Decision-record paths:

- Binding include/remove decision:
  `Documentation/AppleReleaseM0Policy.template.json`;
- CellScaffold artifact/deployment policy:
  `Documentation/Operations/Apple_Associated_Domains_Runbook.md`.

Runtime artifact path, if later included:

```text
https://haven.digipomps.org/.well-known/apple-app-site-association
```

No network proof was performed. Until exact production AASA bytes, TLS,
deployed digest/read-back, final app identifier, and effective signed archive
entitlement are proven, the required decision is **REMOVE Associated Domains
from the release composition**. Removing it does not relax APNS entitlement,
profile, Team ID or topic proof.

## 12. Missing-bound-input register

| ID | Missing exact input | Why it cannot be derived now | Required human/owner decision | Effect |
| --- | --- | --- | --- | --- |
| `MBI-01` | Canonical current-status operation/schema/result/fixtures | DeviceIngress v3 exposes only register/resolve/submit; historical receipt is not current state | CellProtocol contract owner freezes names, version and exact files | Blocks CellProtocol, server and Binding status paths |
| `MBI-02` | Canonical revoke/deregister operation/schema/result/fixtures | No typed operation exists | CellProtocol contract owner freezes semantics and exact files | Blocks safe decline-after-registration and deregistration |
| `MBI-03` | Challenge transport request/response framing | Server route is intentionally unavailable and Binding accepts abstract bytes only | Transport + contract owners freeze exact public request/response | Blocks shared transport completion |
| `MBI-04` | Production issuer, durable admission/replay backend, Resolver Cells and Agreement source/output files | No production composition/storage selection exists | CellScaffold authority/storage owner names concrete implementations and paths | Blocks server output allowlist |
| `MBI-05` | Binding current-status/revoke/token-rotation output files | Depends on MBI-01 through MBI-03 | Binding owner names paths after immutable protocol/transport | Blocks Binding output allowlist |
| `MBI-06` | Verified Apple Team ID/profile/certificate/codesign material | Portal/profile access forbidden and project source is not proof | Apple account holder supplies sanitized signed-archive/profile evidence later | Blocks signing/upload |
| `MBI-07` | Exact integrated output commit/tree/digest | No integration exists or is authorized | Development admin only after independent plan and lane GO | Blocks build/archive/runtime |

No placeholder in this table may be converted into a guessed path, schema,
authority, credential or digest.

## 13. Preserved operative NO-GOs

Nothing in this correction relaxes any operative stop:

- CellProtocol `79ce4f…` code/fixtures use v3 while its security document says
  v2 and `-w--`; code requires `rw-s`.
- Signed current status and typed revoke/deregister do not exist.
- Production challenge issuer, durable admission/replay, Resolver-selected
  target Cells, owner-issued Agreements/Contracts and current read-back do not
  exist.
- `resolve` and `submit` are not operational.
- Shared transport is incomplete because its challenge/status/revoke framing
  is missing.
- Binding raw token handling, current-state restoration, revocation and token
  rotation cannot be production-complete yet.
- APNS provider WIP and Binding fail-closed WIP are uncommitted source only.
- Identity cutover is a separate prerequisite. The `c700dbc…` tree is source
  provenance, not proof of identity continuity, repair, cutover or production
  authority.
- Bundle `org.digipomps.haven`, origin
  `https://haven.digipomps.org` and topic `org.digipomps.haven` are intended
  alignment, not archive/runtime proof.
- Team ID, App ID capability, production profile, distribution certificate,
  effective `aps-environment=production`, codesign authority and archive
  provenance are unproved.
- Associated Domains defaults to removed unless the path-exact AASA lane later
  proves production bytes and effective entitlement.
- There is no exact integrated CellProtocol/Identity/CellScaffold/Binding
  revision, no production archive, no deployed runtime proof, no provider
  acceptance and no physical-device callback evidence.

## 14. Claim adjudication and decision

| Claim | Author disposition | Independent status |
| --- | --- | --- |
| Exact input plan and review are bound | Supported by local SHA-256 | Must be rechecked |
| Candidate commits/trees and current diff manifests are exact | Supported by local object reads | Must be rechecked |
| Identity is no longer a vague 123-commit subset | Full-tree strategy selected and content-addressed | Unreviewed |
| Every current candidate/WIP/no-touch path is assigned | Supported for the manifests in sections 5–7 | Unreviewed |
| Every future production output path is assigned | **Unsupported** because MBI-01 through MBI-05 remain | Open blocker |
| Shared existing-v3 wrapper has an exact owner/home/schema/consumer boundary | Author-proposed | Unreviewed and incomplete |
| AASA is path-exact and fail-closed conditional | Author-proposed | Unreviewed |
| The corrected plan can open S1 or another phase | **Contradicted by this document** | No phase opened |
| Current candidates are production-ready | **Unsupported** | Operative NO-GO |

**S0 AUTHOR DECISION: PLAN NO-GO**

Reasons:

1. author self-review has no credit;
2. P1-01 and P1-03 remain partially open through explicit
   missing-bound-inputs;
3. full-tree Identity and shared transport placement require independent
   adversarial review; and
4. all operative release stops remain.

**NEXT PHASE: NO-GO**

The only permissible continuation is a separately authorized, exact-byte,
independent static review of this S0 artifact by a reviewer other than the
author. That review must not start S1, create source, mutate Git, build, test,
use network/portal/signing/device/APNS/secrets, mutate staging or deploy.
