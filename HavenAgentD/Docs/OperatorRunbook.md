# HavenAgentD Operator Runbook

This runbook is the current step-by-step guide for installing, configuring, starting, and operating `haven-agentd` as a standalone macOS agent.

It is intentionally narrower than the older Binding-embedded runbook:

- `Binding` no longer installs or exposes agent setup UX by default
- `HavenAgentD` is now the product boundary for agent runtime and operator workflows
- pairing/bootstrap evidence may still come from separate operator tooling, but agent install/run/review now lives here

## Scope

Use this runbook for:

- local package verification
- isolated development runs under `--root`
- real local installation under `~/Library/Application Support/HAVENAgent`
- validating config before first start
- inspecting and deciding queued remote intents
- rendering and installing the per-user `LaunchAgent`

Do not use this runbook as proof that scaffold admission is complete unless `bootstrap-probe --run-bootstrap` succeeds with real pairing artifacts and a real `sprout` binary.

## Current truth

What is fully supported and verified now:

- `swift test`, `swift build`, and the deterministic smoke test
- `print-example-config`
- `validate-config`
- `run --once`
- `review-state`
- `review-approve` and `review-reject`
- `print-launch-agent`
- `bootstrap-probe` preflight behavior

What still depends on external operator material:

- `starter-auth.json`
- `Out/agent-enrollment-pairing.json`
- `Out/agent-operator-entity-link.json`
- a real executable `sproutBinaryPath`

Those artifacts are not created by `haven-agentd` alone today. They must already exist before a real scaffold bootstrap can succeed.

## Prerequisites

- macOS with a logged-in user session
- Xcode command line tools
- this workspace checked out locally
- a buildable `HavenAgentD` package
- for real bootstrap: a working `sprout` binary plus valid pairing/evidence artifacts

Workspace root used below:

```bash
/Users/kjetil/Build/Digipomps/HAVEN/Binding
```

## Important paths

Default installed runtime root:

```text
~/Library/Application Support/HAVENAgent/
```

Important files under that root:

```text
~/Library/Application Support/HAVENAgent/config.json
~/Library/Application Support/HAVENAgent/haven-agentd
~/Library/Application Support/HAVENAgent/starter-auth.json
~/Library/Application Support/HAVENAgent/State/agent-state.json
~/Library/Application Support/HAVENAgent/State/cell-runtime.json
~/Library/Application Support/HAVENAgent/State/remote-intent-state.json
~/Library/Application Support/HAVENAgent/State/agent-identity.json
~/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json
~/Library/Application Support/HAVENAgent/Out/agent-operator-entity-link.json
~/Library/Application Support/HAVENAgent/Logs/stdout.log
~/Library/Application Support/HAVENAgent/Logs/stderr.log
~/Library/LaunchAgents/io.digipomps.haven.agentd.plist
```

Disposable development root:

```text
/tmp/haven-dev/HAVENAgent/
```

## Phase 1: Verify the package

From the workspace root:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
```

Expected result:

- the Swift package builds
- package tests pass
- the smoke test finishes with JSON showing `finalPhase = connected`

Do not continue to installation until this passes.

## Phase 2: Create config

### Option A: disposable local dev root

```bash
rm -rf /tmp/haven-dev
mkdir -p /tmp/haven-dev/HAVENAgent
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd print-example-config > /tmp/haven-dev/HAVENAgent/config.json
```

### Option B: real user install root

```bash
mkdir -p ~/Library/Application\ Support/HAVENAgent
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd print-example-config > ~/Library/Application\ Support/HAVENAgent/config.json
```

## Phase 3: Edit config before first run

At minimum, update these fields in `config.json`:

- `instanceName`
- `scaffold.domain`
- `scaffold.resolverBaseURL`
- `scaffold.discoveryURL`
- `scaffold.sproutBinaryPath`
- `localControlBridge.accessToken`
- `remoteIntentPolicy`
- `automationPolicy`

Important notes:

- `scaffold.sproutBinaryPath` must be an absolute path to an executable binary
- the example config placeholder `/absolute/path/to/sprout` will fail at runtime until replaced
- `localControlBridge.accessToken` should be changed from the example placeholder before a real install
- `config.json` is local policy, not remote content

Validate after editing:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd validate-config --config ~/Library/Application\ Support/HAVENAgent/config.json
```

For a disposable root:

```bash
swift run haven-agentd validate-config --config /tmp/haven-dev/HAVENAgent/config.json
```

Expected result:

```text
Config OK: ...
```

## Phase 4: Install the binary for a real local agent

Build the executable:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift build --product haven-agentd
```

Install it under the agent root:

```bash
mkdir -p ~/Library/Application\ Support/HAVENAgent
cp .build/debug/haven-agentd ~/Library/Application\ Support/HAVENAgent/haven-agentd
chmod 755 ~/Library/Application\ Support/HAVENAgent/haven-agentd
```

Sanity check:

```bash
test -x ~/Library/Application\ Support/HAVENAgent/haven-agentd
```

## Phase 5: Run the agent locally before launchd

### Disposable root validation

This is the safest first run:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd run --config /tmp/haven-dev/HAVENAgent/config.json --root /tmp/haven-dev --once
```

Expected result:

- state files are written under `/tmp/haven-dev/HAVENAgent/State/`
- `CellDocuments/` is created
- if `sproutBinaryPath` is invalid, the command fails clearly before pretending bootstrap worked

### Real local root validation

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd run --config ~/Library/Application\ Support/HAVENAgent/config.json --once
```

Expected result:

- `State/agent-state.json`
- `State/cell-runtime.json`
- `State/agent-identity.json`

If this fails with `Sprout binary is not executable`, fix `scaffold.sproutBinaryPath` first.

## Phase 6: Preflight pairing and bootstrap evidence

Run preflight only:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd bootstrap-probe --config ~/Library/Application\ Support/HAVENAgent/config.json
```

Expected result when evidence is ready:

- `readyForBootstrap = true`
- pairing artifact is present and valid
- starter auth is present and valid
- entity-link evidence is present and valid

Expected result when evidence is not ready:

- JSON report with `readyForBootstrap = false`
- explicit summaries such as:
  - `Pairing artifact is missing.`
  - `Starter auth is not configured.`
  - `Entity-link evidence is not configured.`

This is the correct stopping point if operator provisioning has not been completed yet.

## Phase 7: Run a real bootstrap probe

Only do this when:

- `scaffold.sproutBinaryPath` is real
- pairing artifact exists
- `starter-auth.json` exists
- entity-link contract exists

Command:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd bootstrap-probe \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --run-bootstrap
```

Interpretation:

- `readyForBootstrap = false`
  Local operator setup is incomplete.
- `readyForBootstrap = true` and bootstrap succeeds
  Agent admission and native contract bootstrap succeeded.
- `readyForBootstrap = true` and bootstrap fails
  Local evidence is valid, but scaffold admission or resolver-side state still blocks the agent.

If the resolver reports `identity not found in accepted anchor snapshot`, the remaining action is scaffold-side admission of the paired contract.

## Phase 8: Inspect and decide queued intents

Inspect queue and audit:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd review-state --config ~/Library/Application\ Support/HAVENAgent/config.json
```

Approve a verified intent:

```bash
swift run haven-agentd review-approve \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --intent-id <intent-id> \
  --reviewer "Local Operator" \
  --note "Approved from CLI"
```

Reject a verified intent:

```bash
swift run haven-agentd review-reject \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --intent-id <intent-id> \
  --reviewer "Local Operator" \
  --note "Rejected from CLI"
```

Expected behavior:

- `review-state` reflects the persisted queue and audit snapshot for the config you point it at
- `review-reject` removes the pending item and appends an audit record
- `review-approve` appends audit and attempts local execution through the configured allowlist

Important note:

- an `approved_failed` outcome means the review path itself worked, but execution failed against local policy or action lookup

## Phase 9: Install as LaunchAgent

Render the plist:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd print-launch-agent > /tmp/io.digipomps.haven.agentd.plist
```

Review it, then install:

```bash
cp /tmp/io.digipomps.haven.agentd.plist ~/Library/LaunchAgents/io.digipomps.haven.agentd.plist
launchctl unload ~/Library/LaunchAgents/io.digipomps.haven.agentd.plist >/dev/null 2>&1 || true
launchctl load ~/Library/LaunchAgents/io.digipomps.haven.agentd.plist
```

Verify:

```bash
launchctl list | grep io.digipomps.haven.agentd
```

Check logs:

```bash
tail -n 200 ~/Library/Application\ Support/HAVENAgent/Logs/stdout.log
tail -n 200 ~/Library/Application\ Support/HAVENAgent/Logs/stderr.log
```

## Phase 10: Health checks after install

After first successful start, verify these files exist:

```bash
test -f ~/Library/Application\ Support/HAVENAgent/State/agent-state.json
test -f ~/Library/Application\ Support/HAVENAgent/State/cell-runtime.json
test -f ~/Library/Application\ Support/HAVENAgent/State/agent-identity.json
```

If remote intents are expected, also inspect:

```bash
plutil -p ~/Library/Application\ Support/HAVENAgent/State/remote-intent-state.json
```

## Troubleshooting

`Config OK`, but `run --once` fails:

- check `scaffold.sproutBinaryPath`
- ensure the binary is absolute and executable

`bootstrap-probe` says pairing artifact missing:

- check `Out/agent-enrollment-pairing.json`
- check that the config path points to the intended agent root

`bootstrap-probe` says starter auth or entity-link missing:

- operator provisioning has not completed yet
- do not proceed to real bootstrap until those files exist

`review-state` shows no pending intents when you expected some:

- confirm you are pointing at the same `config.json` root as the running agent
- inspect the matching `State/remote-intent-state.json` directly

`review-approve` returns `approved_failed`:

- the intent was reviewable
- the action was not executable under current local allowlist or policy
- inspect `errorMessage` in the returned audit record

`launchctl` starts the agent but GUI automation does not work:

- confirm the process is installed as a per-user `LaunchAgent`, not a daemon
- confirm Automation / Accessibility permissions were granted in the logged-in user session

## Recommended release gate

Before calling the operator flow healthy, require all of these:

1. `./Scripts/test_haven_agentd.sh`
2. `validate-config`
3. `run --once`
4. `bootstrap-probe`
5. `review-state`
6. one real `review-reject` or `review-approve` decision against a queued test intent
7. `print-launch-agent` and one successful local launchd start

## Related docs

- [README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/README.md)
- [SecurityModel.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/SecurityModel.md)
- [BindingBoundary.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/BindingBoundary.md)
- [Legacy/BindingProvisioningRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/Legacy/BindingProvisioningRunbook.md)
