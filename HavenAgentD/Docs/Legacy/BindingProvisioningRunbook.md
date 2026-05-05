# HavenAgentD Setup And Test Runbook

Legacy note:

- this document describes the older Binding-embedded provisioning flow
- `Binding` no longer ships `Agent Setup Workbench` as part of the main app boundary
- keep this only as implementation history until a new dedicated operator flow exists under `HavenAgentD`

This runbook describes the exact order for setting up, pairing, admitting and testing `HavenAgentD` from the `Binding` workspace.

It covers:

- local package verification
- provisioning and pairing from `Binding`
- real bootstrap probing against staging or dev
- secure scaffold admission when staging rejects a newly paired agent identity
- optional `launchd` installation for a persistent local agent

This runbook assumes the current workspace root is:

```bash
/Users/kjetil/Build/Digipomps/HAVEN/Binding
```

It also assumes the related repos exist at:

```bash
/Users/kjetil/Build/Digipomps/HAVEN/sprout
/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold
```

## What The Flow Does

The setup flow has four distinct trust steps:

1. `Binding` writes local agent config and installs the local executable.
2. `Binding` pairs the operator identity to a stable local device identity over `CellProtocol`.
3. The agent signs `starter-auth` and `entity-link` evidence over `CellProtocol`.
4. `sprout bootstrap join` uses those artifacts to request native porthole access from the scaffold resolver.

If step 4 fails with a resolver error like `identity not found in accepted anchor snapshot`, that is no longer a local setup failure. It means the scaffold has not yet admitted the new paired contract into its entity anchor snapshot.

## Important Paths

The default runtime root is:

```bash
~/Library/Application Support/HAVENAgent
```

The important files under that root are:

```text
~/Library/Application Support/HAVENAgent/config.json
~/Library/Application Support/HAVENAgent/starter-auth.json
~/Library/Application Support/HAVENAgent/bin/haven-agentd
~/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json
~/Library/Application Support/HAVENAgent/Out/agent-operator-entity-link.json
~/Library/Application Support/HAVENAgent/State/agent-identity.json
~/Library/Application Support/HAVENAgent/State/agent-state.json
~/Library/Application Support/HAVENAgent/State/remote-intent-state.json
~/Library/Application Support/HAVENAgent/State/cell-runtime.json
~/Library/Application Support/HAVENAgent/Logs/stdout.log
~/Library/Application Support/HAVENAgent/Logs/stderr.log
~/Library/Application Support/HAVENAgent/Launchd/io.digipomps.haven.agentd.plist
```

## Phase 1: Verify Local Code Before Provisioning

Run these commands from the `Binding` repo root:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
./Scripts/build_binding.sh
./Scripts/test_binding.sh -only-testing:BindingTests
```

What this means:

- `./Scripts/test_haven_agentd.sh` runs the full `HavenAgentD` Swift test suite, builds the binary, and runs the deterministic retry/renewal smoke test with an isolated fake runtime root.
- `./Scripts/build_binding.sh` confirms the `Binding` app still builds with the current provisioning and enrollment cells.
- `./Scripts/test_binding.sh -only-testing:BindingTests` runs the macOS `BindingTests` target with the same fixed `arm64` destination used by the build wrapper, which avoids the noisy multi-destination selection path in plain `xcodebuild`.

Do not continue until both commands succeed.

## Phase 2: Open Binding And Materialize The Local Agent Artifacts

Build the app if you have not already:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/build_binding.sh
```

Then run `Binding` from Xcode or from the built app bundle in your normal development workflow.

Inside the app:

1. Open `Agent Setup Workbench`.
2. Confirm or set the scaffold domain.
   Recommended staging value:
   `staging.haven.digipomps.org`
3. Confirm or set the purpose, goal and interests.
4. Run the workbench action that writes config.
5. Run the workbench action that installs the agent binary.
6. Run the workbench action that starts the agent.
7. Run the workbench action that pairs the operator identity to the agent identity.

What this produces:

- `config.json`
- installed local agent binary at `~/Library/Application Support/HAVENAgent/bin/haven-agentd`
- local loopback control bridge token inside `config.json`
- stable agent device identity in `State/agent-identity.json`
- pairing artifact in `Out/agent-enrollment-pairing.json`
- signed `starter-auth.json`
- signed `agent-operator-entity-link.json`

Before moving on, check that the three critical evidence files exist:

```bash
test -f ~/Library/Application\ Support/HAVENAgent/config.json
test -f ~/Library/Application\ Support/HAVENAgent/starter-auth.json
test -f ~/Library/Application\ Support/HAVENAgent/Out/agent-operator-entity-link.json
```

Inspect them if needed:

```bash
plutil -p ~/Library/Application\ Support/HAVENAgent/config.json
plutil -p ~/Library/Application\ Support/HAVENAgent/starter-auth.json
plutil -p ~/Library/Application\ Support/HAVENAgent/Out/agent-enrollment-pairing.json
plutil -p ~/Library/Application\ Support/HAVENAgent/Out/agent-operator-entity-link.json
```

## Phase 3: Run Local Preflight Without Touching Staging

This verifies that local artifacts are internally consistent before any real scaffold join is attempted.

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd bootstrap-probe --config ~/Library/Application\ Support/HAVENAgent/config.json
```

Expected result:

- exit code `0`
- JSON output with:
  - `"readyForBootstrap" : true`
  - `"pairingArtifact.valid" : true`
  - `"starterAuth.valid" : true`
  - `"entityLink.valid" : true`

If this command fails, do not touch staging yet. Fix the local pairing/config flow first.

## Phase 4: Run A Real Bootstrap Probe Against Staging Or Dev

From the `Binding` repo root:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd_bootstrap.sh ~/Library/Application\ Support/HAVENAgent/config.json
```

This script:

1. builds `haven-agentd`
2. runs `bootstrap-probe --run-bootstrap`
3. performs local preflight
4. if preflight passes, runs real `sprout bootstrap join`

You can also run the underlying command directly:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd bootstrap-probe \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --run-bootstrap
```

Interpret the result like this:

- If `readyForBootstrap` is `false`, the problem is still local.
- If `readyForBootstrap` is `true` and `bootstrap.succeeded` is `true`, staging admitted the agent and returned a real native contract.
- If `readyForBootstrap` is `true` and `bootstrap.succeeded` is `false`, the failure is on the scaffold side or its resolver-side data.

## Phase 5: If Staging Rejects The Agent, Admit The Paired Contract Securely

The most important failure to recognize is:

```text
identity not found in accepted anchor snapshot
```

That means:

- the local pairing is already valid
- the local `starter-auth` is already valid
- the local `entity-link` is already valid
- the scaffold entity anchor snapshot still does not list the paired contract as accepted membership evidence

The secure fix is to update the signed entity anchor snapshot using `sprout-admin`.

### 5.1 Identify The Existing Anchored Operator Key

You need the already anchored identity for the entity record you want the new agent linked into.

If you already know that public key, use it directly.

If you need to inspect the pairing artifact for the operator-side key that Binding used:

```bash
python3 -c 'import json, pathlib; p=pathlib.Path.home()/ "Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json"; d=json.loads(p.read_text()); print(d["operatorApproval"]["payload"]["operatorPublicKeyBase64URL"])'
```

Important:

- this is the Binding operator key from the pairing artifact
- the scaffold snapshot must already contain some identity from the target entity record
- `accept-entity-link` uses the existing anchored identity to choose which entity record gets the new contract

### 5.2 Update The Snapshot With The Paired Contract ID

Run this from the `sprout` repo:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/sprout
swift run sprout-admin entity-anchor accept-entity-link \
  --snapshot /path/to/current-entity-anchor-snapshot.json \
  --entity-link ~/Library/Application\ Support/HAVENAgent/Out/agent-operator-entity-link.json \
  --identity-context Scaffold \
  --anchored-public-key <existing-anchored-public-key-b64url> \
  --out /path/to/entity-anchor-snapshot.updated.json \
  --summary-out /path/to/entity-anchor-snapshot.updated.summary.json
```

What this command does:

1. loads the existing signed anchor snapshot
2. verifies the existing snapshot signature
3. loads the paired `entity-link` contract from `Binding`
4. verifies both entity-link signatures
5. finds the entity record that contains the anchored identity you named
6. appends the `entity-link` contract ID to `accepted_entity_link_contract_ids`
7. re-signs the full snapshot with the scaffold admin identity from the vault context

If you already know the target entity ID, you can make the operation stricter:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/sprout
swift run sprout-admin entity-anchor accept-entity-link \
  --snapshot /path/to/current-entity-anchor-snapshot.json \
  --entity-link ~/Library/Application\ Support/HAVENAgent/Out/agent-operator-entity-link.json \
  --identity-context Scaffold \
  --entity-id <target-entity-id> \
  --anchored-public-key <existing-anchored-public-key-b64url> \
  --out /path/to/entity-anchor-snapshot.updated.json \
  --summary-out /path/to/entity-anchor-snapshot.updated.summary.json
```

### 5.3 Deploy The Updated Snapshot To The Scaffold Host

This repo does not automate the final deployment step because that depends on how staging is hosted.

What must happen operationally:

1. replace the scaffold's active entity anchor snapshot with `/path/to/entity-anchor-snapshot.updated.json`
2. ensure the scaffold environment points at that updated snapshot
3. restart or reload the scaffold if required by your deployment model

The relevant scaffold side variable is the anchor snapshot path used by the resolver compatibility layer.

### 5.4 Re-run The Real Bootstrap Probe

After deploying the updated snapshot:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd_bootstrap.sh ~/Library/Application\ Support/HAVENAgent/config.json
```

Expected result now:

- `readyForBootstrap` remains `true`
- `bootstrap.succeeded` becomes `true`
- `bootstrap.contractID` is populated
- the probe exits with code `0`

## Phase 6: Inspect The Agent State After A Successful Join

Inspect the runtime state:

```bash
plutil -p ~/Library/Application\ Support/HAVENAgent/State/agent-state.json
plutil -p ~/Library/Application\ Support/HAVENAgent/State/remote-intent-state.json
plutil -p ~/Library/Application\ Support/HAVENAgent/State/cell-runtime.json
```

Useful checks:

```bash
plutil -p ~/Library/Application\ Support/HAVENAgent/State/agent-state.json | rg "contractID|phase|lastHeartbeatAt|lastError"
plutil -p ~/Library/Application\ Support/HAVENAgent/config.json | rg "resolverBaseURL|discoveryURL|starterAuthPath|entityLinkPath"
```

Inspect the local review state through the CLI:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd review-state --config ~/Library/Application\ Support/HAVENAgent/config.json
```

## Phase 7: Install The Agent As A Persistent LaunchAgent

Only do this after the bootstrap probe succeeds.

### 7.1 Build And Install The Binary

The provisioning workbench can do this for you, but the manual terminal sequence is:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift build --product haven-agentd
mkdir -p ~/Library/Application\ Support/HAVENAgent/bin
cp .build/debug/haven-agentd ~/Library/Application\ Support/HAVENAgent/bin/haven-agentd
chmod 755 ~/Library/Application\ Support/HAVENAgent/bin/haven-agentd
```

If your SwiftPM build places the binary under the architecture-specific debug directory instead, use:

```bash
cp .build/arm64-apple-macosx/debug/haven-agentd ~/Library/Application\ Support/HAVENAgent/bin/haven-agentd
chmod 755 ~/Library/Application\ Support/HAVENAgent/bin/haven-agentd
```

### 7.2 Generate The LaunchAgent Plist

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
mkdir -p ~/Library/Application\ Support/HAVENAgent/Launchd
swift run haven-agentd print-launch-agent > ~/Library/Application\ Support/HAVENAgent/Launchd/io.digipomps.haven.agentd.plist
```

This generates a `LaunchAgent`, not a `LaunchDaemon`. That is required if the agent is ever going to interact with GUI apps like Safari, Xcode or Shortcuts.

### 7.3 Load The LaunchAgent

```bash
launchctl bootstrap gui/$(id -u) ~/Library/Application\ Support/HAVENAgent/Launchd/io.digipomps.haven.agentd.plist
launchctl kickstart -k gui/$(id -u)/io.digipomps.haven.agentd
```

Check status:

```bash
launchctl print gui/$(id -u)/io.digipomps.haven.agentd
tail -n 80 ~/Library/Application\ Support/HAVENAgent/Logs/stdout.log
tail -n 80 ~/Library/Application\ Support/HAVENAgent/Logs/stderr.log
```

To stop it:

```bash
launchctl bootout gui/$(id -u)/io.digipomps.haven.agentd
```

## Phase 8: Optional Isolated Dev Root

Use an isolated root when you want to test runtime behavior without touching your real `Application Support`.

Validate once:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd run --config /tmp/haven-dev/HAVENAgent/config.json --once --root /tmp/haven-dev
```

Run full agent:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd run --config /tmp/haven-dev/HAVENAgent/config.json --root /tmp/haven-dev
```

Run smoke test:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
```

What this means:

- `/tmp/haven-dev/HAVENAgent/...` is used instead of `~/Library/Application Support/HAVENAgent/...`
- no real launch agent is required
- no real staging join is attempted unless you explicitly run the bootstrap probe against a config that points at staging

## Failure Checklist

If local preflight fails:

1. inspect `config.json`
2. inspect `starter-auth.json`
3. inspect `agent-enrollment-pairing.json`
4. inspect `agent-operator-entity-link.json`
5. rerun the pairing flow in `Agent Setup Workbench`

If bootstrap probe fails but preflight passes:

1. read the resolver error in probe output
2. if it says `identity not found in accepted anchor snapshot`, update and redeploy the entity anchor snapshot
3. rerun the bootstrap probe

If the launch agent loads but the agent does not stay healthy:

1. inspect `stdout.log`
2. inspect `stderr.log`
3. inspect `State/agent-state.json`
4. rerun `swift run haven-agentd run --once --config ...` manually to isolate runtime errors from `launchd`

## Minimal Happy Path Command Sequence

If you already know the UI pairing step has been completed in `Binding`, this is the shortest terminal path:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
./Scripts/build_binding.sh
./Scripts/test_haven_agentd_bootstrap.sh ~/Library/Application\ Support/HAVENAgent/config.json
```

If the last command fails with `identity not found in accepted anchor snapshot`, run:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/sprout
swift run sprout-admin entity-anchor accept-entity-link \
  --snapshot /path/to/current-entity-anchor-snapshot.json \
  --entity-link ~/Library/Application\ Support/HAVENAgent/Out/agent-operator-entity-link.json \
  --identity-context Scaffold \
  --anchored-public-key <existing-anchored-public-key-b64url> \
  --out /path/to/entity-anchor-snapshot.updated.json \
  --summary-out /path/to/entity-anchor-snapshot.updated.summary.json
```

Deploy the updated snapshot, then rerun:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd_bootstrap.sh ~/Library/Application\ Support/HAVENAgent/config.json
```
