# Binding repository rehabilitation worklog

```yaml
work_id: binding-haven-app-rehabilitation-20260817
status: READY_FOR_CLEAN_CANDIDATE_BUILD
updated_at: "2026-08-17T10:55:55+02:00"
task_thread_id: "01a00ece-301c-7d51-b2ff-f77a3a838c65"
source_deploy_thread_id: "01a00bf7-8bc9-74a3-8a3e-3b2d8a18f31b"
repository: "/Users/kjetil/.codex/worktrees/77e2/Binding"
base_ref: "origin/main"
base_revision: "0189a85845405f0c3ca4644f16156020414d185f"
branch: "codex/binding-haven-app-rehabilitation-20260817"
owner: "task 01a00ece-301c-7d51-b2ff-f77a3a838c65"
integrator: "task 01a00ece-301c-7d51-b2ff-f77a3a838c65"
commit: null
```

## Ownership and privacy boundary

This task owns Binding source audit, focused startup repair, tests, guarded build
and secret-safe physical launch evidence. It does not own CellScaffold staging
or production mutation, DeviceIngress writes, APNs callback/ack, restart or
production cutover. Evidence records schemas, revisions, hashes and sanitized
states, never raw device identifiers, push tokens, signing/profile identifiers
or credentials.

## Freshness and preservation gate

- Both required handoffs were read in full before repository inspection.
- Remote `origin/main`, the local remote-tracking ref and the clean task base
  resolved to `0189a85845405f0c3ca4644f16156020414d185f` after a focused fetch.
- The canonical Binding checkout remained on its existing divergent branch and
  retained all ten pre-existing modified files. It was inspected read-only and
  was not switched, reset, stashed, cleaned or edited.
- The preserved detached staging worktree remained clean on the same base.
- Registered missing temporary worktrees were inventoried but not pruned.

## Source-selection ledger

| Source | Classification | Evidence / decision |
| --- | --- | --- |
| DeviceIngress chain `0405eb44` through `0189a858` | Already merged; include via base | Six consecutive commits are present on `origin/main`. |
| Canonical branch schedule/sentinel/intent/icon/maturity commits | Already merged/superseded | Their combined tree is identical to squash `7d1bcafd`; the later native-model/contact change is patch-equivalent to merged `b63ee3bc`. Do not reapply. |
| Canonical dirty checkout | Preserve; exclude from integration | Four dirty files are byte-identical to current main. Remaining changes are old-base signing/project or documentation WIP and conflict with newer DeviceIngress metadata; no clean source commit establishes selection authority. |
| `893a7388` correspondence approval inspector | Relevant; deliberately included | Clean single commit directly atop the base, cherry-picked as `12085c80`. Four Binding regressions passed 4/4 and the standalone MCP regression passed 1/1 after its pre-existing CellProtocol pin drift was repaired. |
| Older DeviceIngress/APNs/iPad branches | Superseded | Newer merged DeviceIngress sequence owns the active rollout and receipt behavior. |
| Older Kallimachos, universal-link and correspondence-package branches | Independent or uncertain; exclude | Not direct descendants of the current base and not required for the physical staging startup gate. Preserve refs for separate work. |
| Archived stash/worktree refs | Preserve; exclude | Historical/WIP provenance only; no broad merge or cleanup authority. |

## Initial disk gate

At the initial metadata-only inventory, the shared data filesystem had
`138579685376` bytes and `13.933%` available, passing both the `40 GiB` and
`4%` requirements. The stable Binding staging DerivedData root was approximately
`1.64 GB`. No cleanup plan was needed or authorized.

## Implemented repair and consolidation

- Commit `ea62528e` removes configuration construction from release-navigation
  filtering. Static destination names are compared to the release allowlist.
  A task-local DEBUG probe makes the regression fail if the hidden Apple
  Intelligence personal-copilot factory starts while visible destinations are
  calculated. The hidden factory remains available for direct, policy-enabled
  use.
- Commit `12085c80` deliberately includes the fail-closed correspondence
  approval inspector and its app, callback, MCP and provenance coverage. No
  unrelated older correspondence-package branch was merged.
- The standalone HavenAgentD manifest previously used
  `0ef84bcfbb81d2e112e961719821ed218cf95169`, which could not compile existing
  `PortholeIngressSession` source because a required CellResolver authority
  helper was absent. Its only direct pin change is now
  `33bc79fbead935c982a42a888673b5602c33b0d1`, the smallest compatible merged
  origin/main revision found by source-history audit. All other versioned pins
  are unchanged.
- Binding itself remains locked to its existing CellProtocol revision. Debug
  retains the exact DeviceIngress staging bundle identity and rollout contract,
  while its visible name is now `HAVEN Staging`; Release remains `HAVEN`.
  There is no current playground app target in this project, so the retained
  installed playground app is not modified or uninstalled.

## Intermediate focused verification

- Existing navigation plus the new causal no-construction regression: 2 tests,
  2 passed, 0 failed, coverage collection disabled to avoid a reproduced Xcode
  post-test merge hang.
- Four included correspondence Binding regressions: 4 tests, 4 passed, 0
  failed.
- `CorrespondenceMCPTests.identityOutputIncludesTheApprovalFingerprint`: 1 test,
  1 passed, 0 failed using the exact HavenAgentD lockfile.
- `xcodebuild build-for-testing` completed successfully for the consolidated
  Binding test target. Existing Swift concurrency warnings remain warnings.

These are intermediate results. The focused tests will be repeated from the
final clean committed revision before physical installation.

## Durable build and disk gate

`Scripts/build_binding_staging_candidate.sh` and
`Documentation/Operations/Binding_Guarded_Staging_Build.md` establish one
stable DerivedData root, dual capacity thresholds, an ownership marker, a
single-writer lease, explicit size-bounded adoption, locked package resolution,
secret-redacted Xcode output, signed artifact checks, and exact source/build
provenance verification. The workflow never cleans automatically; any future
cleanup must use the separately guarded metadata-inventory and approval-token
workflow.

After the focused build/test work, the stable root was `3354316 KiB` and the
data filesystem still had `130901508 KiB` and `13%` available. No cache,
worktree, source, package checkout, signing material or device evidence was
deleted.

## Verification ledger

Final clean-revision build metadata, artifact hashes and physical normal-launch
evidence are pending. They will be returned as the completion packet to the
source deploy task without copying device, signing or profile identifiers into
this repository.
