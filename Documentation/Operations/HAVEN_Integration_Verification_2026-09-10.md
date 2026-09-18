# HAVEN integration verification — checkpoint 2026-09-10

Status: **incomplete; not release acceptance**. No new screenshots or live
surface-coverage claim is available from this integration yet.

## Exact source boundary

The original Binding consumer security gate is integrated in origin/main at
`ba195299fd9fbf8621fd23eb907af77586e35c00` (PR 31). Its tree
`65582532b1ef3fde94979a9af7a5e36c1fb946b6` equals tested
`644017526471d0befdc7da8bcb32219c10e01108`. Independent fetch and tree comparison
passed. The exact CellProtocol pin is
`e03923cb2f1d5a339eaf62585ddc9dddf7750cec`.

That source receipt reports locked resolution and arm64 build-for-testing
success: 501 BindingTests, 481 passed, 20 existing opt-in skips, no failures.
The synthetic Class-A storage probe passed. This is not BindingUITests,
signed distribution, production service acceptance, or acceptance of the
additional features below.

Additional local app work is retained on branch
`codex/binding-haven-complete-20260910`, code checkpoint
`7278f955`, then merge `609b5fe926f223a3f7e8be09da604f0dc9d62de5` incorporating
the published main ancestry. The branch has not been pushed or merged into
origin/main. No original worktree or WIP was overwritten.

## Reconciliation ledger

| Source | Disposition |
| --- | --- |
| Primary local app feature commits through `775fc93d` | Relations/address book/contact import, invitation/residency/entity extension, startup identity persistence, remote-LLM chat, relevance, scanner and catalog tests integrated into isolated branch. Not yet build/test accepted. |
| Primary dirty app/test code | Selectively ported TLS routing, UI aliases/localization, opt-in diagnostics, notification error text, beacon consent, and test expectations; retained main's DeviceIngress and strict release catalog. |
| Primary untracked Palazzo surface | Retained existing configuration and sidebar route; added staging catalog entry. Remote runtime not verified. |
| Primary remote surface audit helper | Retained for discovery and diagnostics. It is not yet a sufficient acceptance harness: some assertions only establish report creation, with incomplete semantic/action coverage. |
| Parity worktree `372a3332` | Retained native snapshot helper. It now renders original JSON, records style findings without pre-stripping them, and fails if any attempted surface fails. Not executed here yet. |
| Draft inspector PR 27 / `893a7388` | The six app, unit-test and UI-test files are byte-identical to current main; do not reintroduce the historical branch. Packaging belongs to extracted HavenAgentD. PR itself was not modified. |
| Rehabilitation worktree `77e2` | Clean. Its app rehabilitation/inspector is represented on main. |
| Identity-link worktree | Feature already in main PR 30. Dirty old dependency lockfile preserved; integration keeps approved e039 pin. |
| Worktree `37ab` | Retained additional registration-adapter denial test. Its candidate/patch documentation remains preserved, not silently promoted to installed capability. |
| Condition-resolution worktree | No tracked source changes; local task/contract/status notes preserved. |
| Worktrees `50d3`, `9abf`, `f750` | No dirty source found. `50d3` retains untracked historical APNS contract documents. |
| Dirty embedded HavenAgentD subtree in primary checkout | Not restored into Binding after intentional extraction. Bundle identifier correction already exists in standalone source. Idle-watchdog changes and related old packaging/docs still require owning-repo adjudication; not claimed integrated. |
| Primary build wrapper WIP | Workspace switch not copied over the main project-based pinned dependency build. The old added product-path probe omitted forwarded build arguments and could report a different output; still needs an accurate replacement if retained. |
| Other historical documentation/WIP | Preserved in original worktrees. This ledger does not certify every historical note as current or published. |

## New issues and safe boundaries

Startup identity restore previously conflated missing, unreadable and corrupt
Keychain data. The integration now distinguishes these: it does not generate
replacement keys on read/decode errors, and does not advertise new durable
identity keys after failed persistence. Synthetic-store regression tests are
added, but not run yet. This is source implementation plus syntax validation,
not a verified Keychain migration.

An additional unresolved issue blocks durable-data acceptance:
`BindingStartupIdentityVault.scopedSecretData` derives its output solely from
the public tag and a counter. The resolver can use that provider for the
persisted-cell master key. Introducing a proper secret must not silently make
older stored cells unreadable. The user was asked whether older local HAVEN
data must be retained. No real Keychain record or user data has been read,
deleted, rotated, or migrated in this task. Do not start this candidate against
the real data root before resolving this issue.

## Validation actually performed

- `git diff --check`: passed, including comparison against origin/main.
- `plutil -lint` on project and privacy manifest: passed.
- Swift frontend parse of the changed integration, identity, notification,
  catalog, Palazzo and audit-test files: passed. This is syntax checking only,
  not Swift typechecking, linking, or runtime tests.
- Isolated arm64 build-for-testing: **interrupted by resource guard** while
  compiling dependencies, before app compilation. It did not reach a passing
  or failing app build result. Exit from guard 75, child terminated by SIGTERM.
  Reserve: 1,536 MiB; maximum permitted free-space drop: 512 MiB.
  Start free bytes 3,366,588,416; minimum observed 2,827,853,824.
- The build reused an APFS copy of prior DerivedData, preserving the original
  consumer evidence. Relocation still required dependency compilation. Do not
  reset the build's growth accounting repeatedly to bypass its stop condition.
- Read-only Xcode cache inventory: complete, no scan errors, 16,221,543,088
  allocated bytes, including 177 symlinks. This total is NOT a deletion plan.
  Even its impossible whole-root upper-bound reclaim would not meet the
  disk-cleanup skill's 40 GiB / 10% post-cleanup buffer. No cleanup was executed,
  no thresholds lowered, and no destructive authorization token generated.

## Evidence locations on this host

- Integration worktree:
  `/private/tmp/binding-haven-integration-20260910.V2q7pH/Binding`
- Interrupted build log and guard receipt:
  `/private/tmp/binding-haven-integration-20260910.V2q7pH/build.log`
  and `build.resources.json` in the same parent.
- Guard script and separate DerivedData are in that integration parent.
- Original accepted consumer summary:
  `/private/tmp/cp-security-binding-e039-summary.json`
- Original accepted build log:
  `/private/tmp/cp-security-binding-e039-build.log`
- Original acceptance receipt locator:
  `/private/tmp/cp-security-binding-e039-acceptance-receipt-path.txt`
- Detailed continuation ledger:
  `/private/tmp/binding-haven-reconciliation-20260910.md`

Temporary evidence paths are local operational artifacts. Git checkpoints
preserve the integration source and this note; no claim is made that temporary
logs will survive host cleanup.

## Required continuation

1. Resolve safe durable-secret handling and the older-data preservation choice;
   add same-store restart, different-store isolation, read/write failure and
   wrong-identity denial tests. Avoid silent fallback to a public-derived key.
2. Establish sufficient build capacity or an explicitly revised bounded build
   budget. Preserve originals and provenance. Do not treat syntax checks as
   evidence that the integrated app builds.
3. Locked resolve, complete arm64 build, exact source/compiler attestation and
   full BindingTests in a synthetic home. Fix real integration failures.
4. Derive a manifest from the full testing catalog and live runtime discovery;
   keep the App Store release gate separate from test catalog coverage.
5. Exercise accessible local and remote user paths. Capture native/web images
   of matching configuration, state, viewport and theme, plus action evidence.
   Record unsupported, failing and unavailable surfaces explicitly. Never
   reopen unauthenticated bridge routes to manufacture passing tests.
6. Only publish and merge accepted source. Verify final tree equality and
   provenance; retain a per-surface parity/difference report with both images.

HavenAgentD private-artifact PR 13, installed daemon upgrades and production
FIFO transitions are separate. Their outstanding authorization is unchanged.
