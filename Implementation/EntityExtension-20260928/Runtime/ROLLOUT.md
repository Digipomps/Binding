# Runtime rollout — active release ledger

Requested explicitly by Kjetil on 2026-09-28: roll out to phone, Sprout, agent,
menu helper, staging and production. Executor/integrator: this Codex task.
Status: PARTIAL LOCAL ROLLOUT; server release is HANDOFF_REQUIRED. User authorization covers the rollout; verification gates
still apply. Preserve identity material and existing data.

## Latest checkpoint — authoritative current state

Only the signed Sprout local candidate is installed. HAVEN, the phone, agent,
menu helper, staging and production have not received this candidate.
CellProtocol 980e8a2 passed both Linux jobs and the runtime benchmark; its
single exact-SHA Mac retry is still running. No merge or version tag exists.
The final consumer graph and signed builds must still be verified, including
revalidation after the latest Explore change.

External prerequisites remain: Mac capacity or the explicit reserve exception
already asked after automatic approval rejection; physical phone connection;
server capacity; GitHub private-repository billing/spending recovery.
RELEASE_PACKET.md records HANDOFF_REQUIRED. No cleanup, capacity bypass,
identity/data migration or server mutation occurred.

The dated entries below are history, not cumulative claims of current status.
ROLLOUT_STATUS.json contains the exact source SHAs and active CI identifiers.

## Dependency freeze: CellProtocol

Initial candidate ce1970e5090c51245513284b86004c6e12a7ec87, based on
81601a6f835252aba7e99d43786fb5d67227c245 / published 2026.9.4.
Scope: owner-attach presence protocol/client/store, admission consistency,
negative and replay tests, ISO8601 golden, iOS 16 focusable availability fix
required by the real phone build. No new identity enrollment or data grants.

Before push/PR, inspected expected workflows: CellProtocol macOS regression,
CellProtocol Swift Linux, Vapor identity vault Swift Linux, runtime capacity
benchmark, and Notify PyCellProtocol -> upstream sync. Both CellProtocol and
PyCellProtocol are public repositories. These candidate checks are included
in this release scope. No private paid CI or unrelated TLS diagnostic is
included. Expected full candidate checks must pass before merge/release.

101 focused protocol tests pass. Signed generic iOS HAVEN build succeeded
with this source after the availability fix. Previous local macOS candidate
had 15 passing app identity/security tests and direct native UI verification.

## Current live inventory

- Staging app feec23725321320ab00f0e7f7bf728b775869ec7,
  CellProtocol 9c60001ac53abc35ba7ad6e2c0efa2a79ab2a366.
- Production app 18c14c32cb6e2957c1d13a20a4b2d97ece2f02b6,
  CellProtocol 473357cf4efee831cb3b55ae87bc921d4bb63c10.
- Documented SSH identity required; default SSH failed, documented key worked.
  Staging deployment doctor exited 0. No deploy performed yet.
- Local bounded server cache lacks ownership marker and exceeds its cap.
  No marker forged, no deletion, no alternate scratch directory used.
- Initial iPhone16e classification was wrong: it is simulated. Physical iPhone17Pro is disconnected; a physical iPad is connected as of the latest check.

## Fresh integration sources

- Binding isolated existing candidate, based on origin/main 8ce634f6.
- HavenAgentD fresh origin/main a9da717453ef3061d288fb5abbb29135c17fc720;
  includes the actual menu helper. Original checkout was 38 commits behind.
- Sprout fresh origin/main 7aea5b0f814e345021c14d2a5389c9880cb988e9;
  existing person entity launcher/nearby integration already present.
- CellScaffold origin/main adf48d4615d1ed143d5bdc190fcf63e266214c8f.

Not yet complete: publish shared dependency; agent durable receiver integration;
policy navigation in Sprout/menu; phone installation; package consumer pins;
clean server build, staged functional check, same-artifact production promotion.

## Continuation checkpoint 2026-09-28 ~20:20 CEST

- Active request is rollout to all named surfaces, not just a proposal. No
  deployment has yet happened in this turn. Physical phone is an external
  prerequisite: devicectl connected iPhone 16e was confirmed `reality=simulated`,
  `transportType=sameMachine`; simctl agrees (booted iOS 26.2). The user has an
  asynchronous request to connect/unlock the real target phone. Corrected the
  initial misleading device classification explicitly. Never call this a
  physical-device verification.
- CP PR https://github.com/Digipomps/CellProtocol/pull/56 is attached to this task.
  First candidate ce1970e hit a Linux test-fixture packaging dependency:
  BridgeIdentityBoundaryTests referred to another test suite's Store not copied
  by the Linux gate. Fixed with a file-local store and reran 101 tests, all pass.
  New commit 65f8fc3 (get full SHA from worktree), pushed to same PR. Public
  workflows include macOS, two Linux gates, benchmark and PyCellProtocol sync.
  Watcher session 74925 watches PR checks every 60s; if it ended against the old
  candidate, start one watcher for the new SHA. No blind reruns.
- Agent test command with local CP and Sprout overrides completed exit 0:
  49 menu/core tests and 8 AgentCellRuntimeHost tests. New restart test proves
  encrypted owner-attach receipt remains readable after agent stop/start.
  Native agent receiver uses existing persisted service signer plus HKDF with
  separate domain, because LocalIdentityVault scoped secrets are memory-only.
  Old process-global receiver is restored on stop.
- New native URL haven://entity-extension-policy opens policy UI, rejects extra
  payload, and is available from Sprout CLI `entity policy`, Sprout macOS and
  menu helper. Existing Sprout `entity connect` and Nearby were already on main.
  Sprout still delegates human linking/policy to HAVEN; it does not mint proof.
  New Binding test added. Current native build/test session 25046.
- The CP git worktree registration CellProtocol9 disappeared externally while
  sources remained. Recreated metadata with a no-checkout registration and
  `git worktree repair`, initialized only its index with `git read-tree HEAD`.
  Diff was exactly the expected bridge fixture fix. No source/build file changed.
  All five candidate worktrees are now locked against pruning. New CP metadata
  name is CellProtocol-metadata-repair. Its empty bootstrap directory remains.
  Binding provenance inputs regenerated (882 inputs); failure had been Git
  metadata, not code. Do not disable provenance. Regenerate after Git changes.
- Agent optimized build session 92062 -> agent-release-build.log. Sprout release
  build session 30253 -> sprout-release-build.log. Both use --jobs 2.
- Agent manifest currently has explicit local override support and remote CP
  ce1970e pin; must reconcile to final published version. Its Package.resolved
  currently reflects LOCAL override drift and must not be committed that way.
  Sprout main accepts swift-crypto 3.15.1..<5.0.0; no crypto requirement change
  was needed. Sprout only three launcher/UI files changed so far.
- Server adapter now unconditional for published API (was local-only), and a
  non-identifying /health/entity-presence endpoint reports true/503 based on
  host installation. Allowed read-only through admission middleware; no owner
  data. Added OwnerAttachRuntimeSupportTests, not yet compiled. Server current
  manifest still CP/Micro/Mint 2026.9.3; update after CP 2026.9.5 is published.
  Micro 2026.9.4 now exists and accepts compatible CP minor releases; Mint
  2026.9.4 exists with compatible Micro requirements. Verify remote tags before
  updating consumers. CP latest existing tag is 2026.9.4 at base 81601a6f.
- Live staging feec237 is ancestor of main adf48d46: 7 commits / 23 files
  difference, workbench idea selection/TTL/Claude guidance and deploy capacity
  floor. Scope ledger needs this before server promotion.
- Documented SSH: `-i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes` to
  ops@89.167.90.101. Doctor staging exits 0 with old installed tooling, but
  current release rule scripts/production/haven-deploy-capacity requires 40 GiB
  AND 4% on every relevant filesystem. Host df has only ~36 GB available.
  Docker aggregate read-only inventory: images 125.5GB (112GB marked reclaimable),
  Build Cache 31.98GB, 0 active, 10.77GB reclaimable. Do not delete images,
  containers, volumes, source, identities or rollback artifacts. No cleanup
  has been performed. Local server cache remains unmarked and untouched.

Candidate directories: /private/tmp/haven-owner-attach-runtime/{CellProtocol,
CellScaffold,HavenAgentD,sprout}; Binding is the existing isolated
~/.codex/worktrees/entity-extension-security-20260928/Binding. Main checkouts
contain unrelated work and must remain untouched (except mandatory learning).
Need still: pass new CP CI, merge/publish leaf, reconcile pins and commit
consumers, build/test server via allowed path, install signed native/agent/
menu/Sprout with backups and preserve existing identity, staged functional
verification then same-artifact prod promotion when capacity and phone gates
are resolved. Mandatory new learning capture/update/sync still due this turn.

## Local install checkpoint ~20:36 CEST

Sprout local source commit af4ffabafcea96a299c132368882347b0c0bcbc8 is
installed: /Applications/Sprout.app, /usr/local/bin/sprout and sibling
haven-nearby. All signed with Developer ID team 5UT5HQTCV9 and codesign verified.
No preexisting destination existed. CLI help confirms entity policy/connect;
Nearby help confirms Network/Bonjour. GUI handoff still awaits updated HAVEN.
Nearby package source is identical to Sprout's pinned 533b42d5 checkout.
This is local signed candidate installation, not a published Sprout release.

CellProtocol macOS CI finished with 15 assertions in six tests failing due to
unconditional advertisement of the optional owner-attach operations. Linux
gates and runtime benchmark passed. Corrected implementation uses ephemeral
Explore metadata while the host is installed, including late installation,
uninstallation, decoding and keypath audit. Owner-only permissions are empty
(no grant bypass). Existing AI/chat/probe tests are unchanged. 28 focused tests
pass including new lifecycle/persistence test. Full local suite running in
session 36316 -> cp-full-regression.log; candidate not yet repushed.

Binding runtime commit e5691ba2 records the tested UI/wiring and explicit
policy URL. Local signed installation remains pending. Menu release builds.
Physical phone still disconnected. Asked user about increasing server free
space; no cleanup performed. Server BuildKit eligible metadata is recorded,
but local disk skill forbids remote cleanup and provides no remote policy.

## Capacity/approval checkpoint ~21:03 CEST

Automatic approval review rejected the planned signed Mac build because it
changed HAVEN_BUILD_RESERVE_GIB from required 10 to 2. The build DID NOT RUN.
User was told the stated reason and has a pending explicit choice between
retaining 10 GiB and a reviewed cleanup proposal, or allowing 2 GiB for this
incremental build. Do not bypass or treat elapsed time as approval.
Read-only standard capacity check confirms 94.6 GiB free; minus 10 GiB leaves
84.6 GiB (9%), below the documented 10% floor. Xcode default DerivedData
inventory is only 1.50 GB total; cleaning it would not meet the required margin.
No valid cleanup plan or deletion token exists. No deletion performed.

Sprout GUI was launched through CUA and visibly shows both new entity buttons.
That tool call took ~23 minutes. Prefer bounded shell/build verification and
short-timeout GUI calls where possible. Native URL handoff remains unverified
until the target HAVEN app is updated.

Mandatory learning L-2026-09-28-devicectl-can-report-a-simulated-iphone-as was
captured, canonical haven-functional-service-verification skill updated, and
synced to Codex/Claude/Desktop/ZIP. Physical-device results must inspect reality
and transportType and distinguish simulator from real phone.

## Consumer publication scope — before push

Sprout candidate af4ffabafcea96a299c132368882347b0c0bcbc8 changes only three
launcher/UI files. Local evidence: 134 XCTest plus six Swift Testing tests pass,
CLI and macOS release builds pass; signed local install and visible GUI buttons
verified. The native policy handoff remains pending the HAVEN update.
Expected automatic private CI for a codex-branch push and PR: CI/build-test-macos
and CI/build-test-linux. The release workflow is tag/manual only and is excluded.
Nearby companion still uses published 533b42d5 with unchanged package contents.
This executor includes those candidate checks in the rollout. GitHub billing
usage endpoint is readable, but usage is not a remaining-allowance guarantee.
No unrelated native TLS job or label is authorized.

Documentation candidate b57f33f, based on fresh public main 61490b8, changes only
Book chapters 22 and 32. No repository workflows exist. It distinguishes human
entity presence from scaffold delegation and labels the implementation as a
candidate, not deployed. Catalog inventory unchanged; paths validated.

## Verification and publication ~21:10 CEST

Full local CellBase regression after the optional Explore correction PASSES:
1,311 tests, two skips, zero failures, cp-full-final.log. New CP candidate
980e8a2 is pushed to PR #56. CI watcher session 73079 watches that candidate.
No tag or merge yet. Previous CI green Linux/benchmark applies to 65f8fc3 only.

Sprout PR https://github.com/Digipomps/Sprout/pull/4 and docs PR
https://github.com/Digipomps/CellProtocolDocuments/pull/26 were created and
attached. Sprout watcher session 61094. Both automatic push and PR candidate
checks were declared before push. No private server CI or TLS proof dispatched.

CellScaffold readiness suite is included in ci/test-filter.txt (coverage guard
passes, 343 suites). ValueType size gate passes with HAVEN_PYTHON=/usr/bin/python3;
auto-selected /usr/local/bin/python3.12 failed with Bad CPU type before scanner
execution. The source was not weakened. Server Swift test remains uncompiled.

## External gates ~21:15 CEST

Sprout CI never started either job (empty steps, no logs). GitHub annotations
for checks 109090536674 and 109090536843 say recent account payments failed
or the spending limit needs increase. Runs 36470283753 (push) and 36470288447
(PR) both rejected at scheduler. No rerun requested. Treat private consumer/
server CI as unavailable until account billing is resolved. This is separate
from local test results and the Mac build auto-review rejection.

Latest devicectl read: physical iPad Pro 12.9-inch 5th generation is wired and
connected with Developer Mode enabled; physical iPhone 17 Pro remains local
network/disconnected. The original request targets a phone, so no iPad install
was substituted. Simulator iPhone16e is still connected/sameMachine.

CellScaffold now explicitly clears the optional runtime host when no scaffold
owner resolves, avoiding stale readiness from an earlier process-global host.
Its new health endpoint/test remain uncompiled, not deployment evidence.

## Exact-candidate CI retry ~21:20 CEST

CP 980e8a2845905391fb66ce098958dcdc4194d144 passed both Linux jobs. Mac run
36469713446 failed only CellLifecycleTests.testMemoryTTLWarningAndExpiryEventsAreEmitted
at line 186: warning absent, expiry present. This existing test allows a 150ms
warning window with 250ms TTL; resolver clamps periodic sweeps to 200ms and the
test also manually polls at 50ms. Scheduler timing is a plausible cause; not
a proven product regression. Both local full runs passed this test. All earlier
owner-attach Explore failures are gone. One public failed-job-only rerun was
requested for job 109088604432 on the unchanged SHA. No tests/workflows changed.
Watcher -> cp-mac-retry-watch.log. No further reruns without new evidence.

## Resume order / current stopping boundary

1. CP candidate is 980e8a2845905391fb66ce098958dcdc4194d144. Read the terminal
   result of public macOS retry session 74550 / run 36469713446 attempt 2,
   and all-PR watcher session 73079. Runtime benchmark run 36469713329 was
   still running at 21:20 CEST. Do not call any CI green until exact SHA is
   verified. One timing-test rerun has already been used.
2. Only after green review/merge may CP publish a NEW verified tag (planned
   2026.9.5, first check that it has not already been used). Compare tested
   tree with merge tree. No tag/merge occurred in this session.
3. Reconcile Binding, Agent and CellScaffold remote manifests/lockfiles to that
   release. Do not commit Agent's local-override Package.resolved drift.
4. Native/Agent/menu release build/install must respect pending Mac capacity
   approval. Normal capacity check fails. Auto-review rejection is authoritative
   until user permits the specific 2 GiB exception or adequate space exists.
   No automatic reinterpretation of deployment authorization as that exception.
5. Phone still needs physical connection/unlock. Do not substitute the connected
   iPad or simulator and claim phone completion.
6. Private Actions need billing/spending recovery. Server root needs >=40 GiB
   after candidate/build/backup/rollback growth. No server deploy or cleanup
   occurred. Stage functional proof must precede same-artifact production.

Installed so far: signed local Sprout candidate only. HAVE NOT installed new
HAVEN, agent or menu helper. Existing agent read-only summary returns HTTP 200;
job-state metadata had one registered/four done, no running entry at inspection.
MCP jobs connector failed Transport closed; do not confuse that with daemon
health. Existing identities and data were not migrated or relinked.

All candidate worktrees are locked. Sources, scoped patches and this checkpoint
are preserved. Source-related work can continue without reopening old dirty
main checkouts. Docs PR #26 and Sprout PR #4 are attached to the task.
