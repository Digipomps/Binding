# HavenAgentD

`HavenAgentD` is a headless macOS agent package intended to sit between a HAVEN entity in the cloud and local macOS automation boundaries.

## What this package does now

- establishes a standalone executable, `haven-agentd`
- stores runtime state under `~/Library/Application Support/HAVENAgent/`
- invokes `sprout` startup bootstrap through a dedicated client, not via shell concatenation
- decodes `sprout` join artifacts into an official native `PortholeClientSession`
- opens a live native porthole ingress when bootstrap returns a native contract artifact
- retries failed native bootstrap/join attempts with bounded backoff instead of failing only once at startup
- renews native porthole access before contract expiry by re-running `sprout bootstrap join`
- validates and executes allowlisted Shortcuts and AppleScript handlers
- watches local folders and triggers approved local actions
- writes agent heartbeat and latest action state to disk
- writes a local cell-runtime snapshot to `State/cell-runtime.json`
- writes remote-intent queue/audit/nonce state to `State/remote-intent-state.json`
- renders a `launchd` plist for per-user startup
- supports `--root /path/to/dev-root` so runtime state can be isolated away from the user's real `Application Support`
- ships a deterministic smoke-test path that exercises retry + renewal without a live scaffold
- exposes real CellProtocol `GeneralCell` subclasses for supervisor state and remote-intent inboxing
- installs those cells into a local `CellResolver` graph during `run`
- verifies signed remote intent envelopes against a local trusted-issuer policy before queueing them
- allows explicit approve/reject review of verified intents before any remote side effect is dispatched
- surfaces native porthole ingress status in runtime state and the supervisor cell

## What it does not do yet

- it does not yet call `sprout` APIs directly
- it does not yet bind native porthole ingress to a richer resolver/session lifecycle than the bootstrap artifact alone
- it does not yet auto-execute queued remote intents without explicit review
- it does not yet persist trusted signing material across restarts

Those boundaries are intentional. This package gives a safe executable skeleton first, so that `sprout` and `CellProtocol` can be added behind explicit interfaces instead of collapsing bootstrap, policy and local automation into one process with unclear trust rules.

## Package layout

- `Sources/HavenAgentD`: CLI entrypoint
- `Sources/HavenRuntimeBootstrap`: runtime paths, bootstrap plan, launch agent rendering
- `Sources/HavenAgentRuntime`: config loading, folder monitoring, state persistence, session heartbeat
- `Sources/HavenAgentRuntime/SproutBootstrapClient.swift`: controlled `sprout` invocation builder and runner
- `Sources/HavenAgentRuntime/SproutBootstrapArtifactLoader.swift`: bootstrap artifact loader that materializes native porthole sessions
- `Sources/HavenAgentRuntime/PortholeIngressSession.swift`: live native porthole ingress that extracts signed remote intents from flow events
- `Sources/HavenAgentRuntime/PortholeLifecycleController.swift`: reconnect/renewal orchestration around bootstrap join + ingress lifecycle
- `Sources/HavenMacAutomation`: policy engine, subprocess runner, `shortcuts` and `osascript` bridges
- `Sources/HavenAgentCells`: concrete supervisor/inbox cells, a default cell registry, plus blueprint catalog for the next cells
- `Sources/HavenAgentCellRuntime`: local identity vault, `CellBase` host installation, resolver registration, runtime snapshotting
- `Docs/SecurityModel.md`: security constraints and follow-up requirements

## Security model

The most important rules are simple:

- remote callers must never be allowed to submit arbitrary AppleScript text or arbitrary shell commands
- the agent must never assemble a `sprout` bootstrap shell string from untrusted input

Instead, the executable only runs named actions that are defined locally in config and validated against local policy.
The same principle now applies to `sprout`: the agent builds a fixed argument vector for `Process`, with explicit fields from local config.
The same principle also applies to the first real cells: `RemoteIntentInboxCell` now accepts either local structured payloads or signed remote envelopes, but only the signed envelope path can become a verified remote intent. It still does not invoke AppleScript or Shortcuts directly.
The same principle now also applies to live ingress: only native contracts produced by `sprout bootstrap join` are accepted, and only flow payloads that decode into the signed-envelope shape are handed to remote-intent verification. Other porthole traffic is ignored.
The reconnect/renewal loop follows the same boundary: on failure or near-expiry it re-runs the same local `sprout bootstrap join` path, instead of accepting a remotely supplied websocket or contract override.
When `haven-agentd run` starts, it now installs a narrow local `CellBase` host backed by an in-memory vault and a dedicated `CellDocuments` root under `~/Library/Application Support/HAVENAgent/`.

## Current cells

- `AgentSupervisorCell`: exposes runtime state, latest bootstrap result, native porthole ingress status, latest action and a refresh event stream
- `RemoteIntentInboxCell`: accepts structured local intents or signed remote envelopes, validates payload shape, signature, expiry and nonce, and appends only accepted intents to a local queue
- `RemoteIntentReviewCell`: approves or rejects verified queued intents and dispatches only locally allowlisted remote actions
- `AgentCellRegistry`: instantiates the current safe default cell set for a local owner identity
- `AgentCellRuntimeHost`: installs the local owner/vault, registers the current cells into `CellResolver.sharedInstance`, and persists a runtime snapshot
- `AgentCellBlueprints`: retains the next planned cells, including dedicated action cells, before they are promoted to executable runtime components

## CLI

Print example config:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd print-example-config
```

Validate config:

```bash
swift run haven-agentd validate-config --config ~/Library/Application\\ Support/HAVENAgent/config.json
```

Run once for bootstrap/state validation:

```bash
swift run haven-agentd run --config ~/Library/Application\\ Support/HAVENAgent/config.json --once
```

Run against an isolated development root instead of the user's real `Application Support`:

```bash
swift run haven-agentd run --config /tmp/haven-dev/HAVENAgent/config.json --root /tmp/haven-dev
```

With `--root /tmp/haven-dev`, the agent writes under `/tmp/haven-dev/HAVENAgent/` instead of `~/Library/Application Support/HAVENAgent/`.

During `run`, the executable now also creates:

- `~/Library/Application Support/HAVENAgent/CellDocuments/` for local CellProtocol document-root data
- `~/Library/Application Support/HAVENAgent/State/cell-runtime.json` for the registered cell snapshot
- `~/Library/Application Support/HAVENAgent/State/remote-intent-state.json` for queued intents, review audit and nonce replay window

`config.json` now also supports a `remoteIntentPolicy` section with:

- locally trusted issuer IDs
- per-issuer public signing keys
- per-issuer allowed topics and action IDs
- expiry requirement and max clock skew

The current remote flow is:

1. `sprout bootstrap join` persists a native bootstrap artifact to the agent state directory.
2. `PortholeLifecycleController` retries transient join/connect failures with bounded backoff and re-runs join before contract expiry.
3. `PortholeIngressSession` loads each fresh artifact into a native `PortholeClientSession` and subscribes to the live bridge websocket.
4. Signed envelope-shaped flow events are verified and queued through the same remote-intent policy path as `RemoteIntentInboxCell.enqueueSigned`.
5. `RemoteIntentReviewCell.approve` or `reject` records an audit decision.
6. Approved intents dispatch through `RemoteIntentExecutionBridge`, which still enforces the local automation allowlist for remote execution.

Render a launch agent plist:

```bash
swift run haven-agentd print-launch-agent
```

Run the package test suite plus a local retry/renewal smoke test from the `Binding` workspace root:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
```

The smoke test uses a fake local `sprout` binary, an isolated `--root`, and a scripted ingress controller. It proves:

- initial bootstrap failure is retried
- native contract renewal happens before expiry
- verified remote intents still land in the persisted local queue

## Planned integration steps

1. Move the reusable runtime bootstrap out of UI-driven `AppInitializer` and into a package that the agent can import.
2. Add richer approval metadata, reviewer identity binding and correlation IDs to the review/audit trail.
3. Bind the current reconnect/renewal loop to a richer `sprout`-managed resolver/session lifecycle than the bootstrap artifact alone.
4. Persist trusted signing material and recovery metadata once rotation/revocation semantics are defined.
5. Introduce dedicated action cells only where they improve clarity without weakening the current review boundary.
