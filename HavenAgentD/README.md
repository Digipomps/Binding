# HavenAgentD

`HavenAgentD` is a headless macOS agent package intended to sit between a HAVEN entity in the cloud and local macOS automation boundaries.

Binding is now treated as a standalone app product, so agent-specific operator/admin documentation lives under [Docs/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/README.md) instead of the main Binding documentation surface.

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
- persists a stable local agent signing identity to `State/agent-identity.json`
- renders a `launchd` plist for per-user startup
- supports `--root /path/to/dev-root` so runtime state can be isolated away from the user's real `Application Support`
- ships a deterministic smoke-test path that exercises retry + renewal without a live scaffold
- ships a bootstrap probe that verifies pairing, starter-auth and entity-link artifacts before optionally running a real `sprout bootstrap` against staging or dev
- exposes real CellProtocol `GeneralCell` subclasses for supervisor state and remote-intent inboxing
- exposes `AgentIdentityCell` so local operator tooling can attest a stable device identity and request a signed starter-auth payload over the loopback CellProtocol bridge
- exposes `AgentLocalModelCell` for a configured loopback local language model backend such as `llama-server`
- verifies the persisted Binding<->agent pairing artifact before treating an operator identity as paired
- lets `sprout bootstrap join` consume purpose-bound entity-link evidence generated from the Binding<->agent pairing flow
- installs those cells into a local `CellResolver` graph during `run`
- verifies signed remote intent envelopes against a local trusted-issuer policy before queueing them
- allows explicit approve/reject review of verified intents before any remote side effect is dispatched
- surfaces native porthole ingress status in runtime state and the supervisor cell
- exposes a loopback-only, token-gated local CellProtocol control bridge for operator tooling

## What it does not do yet

- it does not yet call `sprout` APIs directly
- it does not yet bind native porthole ingress to a richer resolver/session lifecycle than the bootstrap artifact alone
- it does not yet auto-execute queued remote intents without explicit review
- it does not yet store the persisted agent seed in Keychain
- it does not yet run language models directly on iPhone or iPad; phone access goes through the paired agent/porthole path first

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
- `Sources/HavenAgentCellRuntime/AgentControlBridgeServer.swift`: loopback-only websocket bridge that exposes allowlisted operator cells over CellProtocol
- `Docs/SecurityModel.md`: security constraints and follow-up requirements

## Docs

- [Docs/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/README.md): agent doc index
- [Docs/OperatorRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/OperatorRunbook.md): step-by-step operator guide for setup, install, bootstrap, review, and launchd
- [Docs/BindingBoundary.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/BindingBoundary.md): current Binding vs agent boundary
- [Docs/SecurityModel.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/SecurityModel.md): security model
- [Docs/LocalModels.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/LocalModels.md): local model cell contract and phone/iPad access path
- [Docs/HavenAgentDMCPServerSurface.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/HavenAgentDMCPServerSurface.md): proposed MCP adapter surface for local AI hosts
- [../Documentation/HavenAgentPhoneApprovalLoopRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/HavenAgentPhoneApprovalLoopRunbook.md): physical iPhone install + notification approval loop runbook with current verification state
- [Docs/Legacy/BindingProvisioningRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/Legacy/BindingProvisioningRunbook.md): archived Binding-embedded provisioning flow
- [Docs/Legacy/AgentSetupWorkbench_UI_Review.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/Legacy/AgentSetupWorkbench_UI_Review.md): archived workbench UX review

## Security model

The most important rules are simple:

- remote callers must never be allowed to submit arbitrary AppleScript text or arbitrary shell commands
- the agent must never assemble a `sprout` bootstrap shell string from untrusted input

Instead, the executable only runs named actions that are defined locally in config and validated against local policy.
The same principle now applies to `sprout`: the agent builds a fixed argument vector for `Process`, with explicit fields from local config.
The same principle also applies to the first real cells: `RemoteIntentInboxCell` now accepts either local structured payloads or signed remote envelopes, but only the signed envelope path can become a verified remote intent. It still does not invoke AppleScript or Shortcuts directly.
The same principle now also applies to live ingress: only native contracts produced by `sprout bootstrap join` are accepted, and only flow payloads that decode into the signed-envelope shape are handed to remote-intent verification. Other porthole traffic is ignored.
The reconnect/renewal loop follows the same boundary: on failure or near-expiry it re-runs the same local `sprout bootstrap join` path, instead of accepting a remotely supplied websocket or contract override.
The local model cell follows the same boundary: it calls only the configured loopback model backend by default, and exposes generation through CellProtocol actions and flow events instead of opening a raw model socket to remote clients.
When `haven-agentd run` starts, it now installs a narrow local `CellBase` host backed by an in-memory vault and a dedicated `CellDocuments` root under `~/Library/Application Support/HAVENAgent/`.

## Current cells

- `AgentSupervisorCell`: exposes runtime state, latest bootstrap result, native porthole ingress status, latest action and a refresh event stream
- `AgentIdentityCell`: exposes the stable local agent identity, issues explicit enrollment attestations for Binding-side pairing, and signs purpose-bound starter-auth payloads for `sprout`
- `RemoteIntentInboxCell`: accepts structured local intents or signed remote envelopes, validates payload shape, signature, expiry and nonce, and appends only accepted intents to a local queue
- `RemoteIntentReviewCell`: approves or rejects verified queued intents and dispatches only locally allowlisted remote actions
- `AgentLocalModelCell`: exposes `state`, `contracts`, `llm.health` and `llm.generate` for a configured loopback local model backend, emitting `agent.localModel` flow events
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

Preflight the current Binding-driven enrollment artifacts, or run the actual scaffold bootstrap when you want to test staging/dev:

```bash
swift run haven-agentd bootstrap-probe --config ~/Library/Application\\ Support/HAVENAgent/config.json
swift run haven-agentd bootstrap-probe --config ~/Library/Application\\ Support/HAVENAgent/config.json --run-bootstrap
```

Run once for bootstrap/state validation:

```bash
swift run haven-agentd run --config ~/Library/Application\\ Support/HAVENAgent/config.json --once
```

Inspect persisted review queue/audit state through the same review cell path used by the agent:

```bash
swift run haven-agentd review-state --config ~/Library/Application\\ Support/HAVENAgent/config.json
```

Approve or reject a specific pending intent:

```bash
swift run haven-agentd review-approve --config ~/Library/Application\\ Support/HAVENAgent/config.json --intent-id <intent-id> --reviewer "Binding operator" --note "Approved from local workbench"
swift run haven-agentd review-reject --config ~/Library/Application\\ Support/HAVENAgent/config.json --intent-id <intent-id> --reviewer "Binding operator" --note "Rejected from local workbench"
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
- `~/Library/Application Support/HAVENAgent/State/agent-identity.json` for the stable local agent signing identity used by `AgentIdentityCell`

When `localControlBridge.accessToken` is configured, the bridge only accepts websocket and health requests that present the matching `token` query item. The example config ships with a placeholder token, and any future operator tool should supply its own explicit local token instead of relying on ambient localhost authority.

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

The current local identity-pairing flow is:

1. `AgentCellRuntimeHost` loads or creates a stable agent identity and registers it into the local runtime vault.
2. `AgentIdentityCell` exposes that identity on the loopback control bridge, signs an explicit enrollment attestation, and can sign a purpose-bound starter-auth payload for the same identity.
3. Operator tooling can verify the attestation locally, write a pairing artifact under `~/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json`, request and verify a signed starter-auth payload from the agent over CellProtocol, and materialize a mutually signed entity-link contract under `~/Library/Application Support/HAVENAgent/Out/agent-operator-entity-link.json`.
4. The agent now re-loads and verifies that persisted pairing artifact before treating an operator as paired.
5. Operator tooling writes the verified starter-auth payload to `~/Library/Application Support/HAVENAgent/starter-auth.json`, which is the same path already referenced from the generated agent config.
6. `sprout bootstrap join` now receives the paired agent identity through `--starter` and the operator<->agent relationship through `--entity-link` instead of silently generating a third starter identity.

`review-state`, `review-approve` and `review-reject` now reuse that same review path in a one-shot CLI context, so local operator tooling can inspect or decide on queued intents without inventing a second review mechanism outside CellProtocol.

Render a launch agent plist:

```bash
swift run haven-agentd print-launch-agent
```

Run the package test suite plus a local retry/renewal smoke test from the `Binding` workspace root:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
```

Run the package build plus a real bootstrap probe from the `Binding` workspace root after Binding has already paired and provisioned the agent:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd_bootstrap.sh ~/Library/Application\\ Support/HAVENAgent/config.json
```

The smoke test uses a fake local `sprout` binary, an isolated `--root`, and a scripted ingress controller. It proves:

- initial bootstrap failure is retried
- native contract renewal happens before expiry
- verified remote intents still land in the persisted local queue

The bootstrap probe is the staging/dev-facing complement to that smoke test. It proves that:

- the persisted Binding<->agent pairing artifact still verifies on the agent side
- the agent-signed `starter-auth.json` still matches the configured scaffold domain + purpose
- the mutually signed entity-link contract still binds the paired operator key to the agent key
- `sprout bootstrap join` either succeeds with a real native contract artifact or fails at a concrete scaffold admission boundary

If the probe still fails with resolver output like `identity not found in accepted anchor snapshot`, the remaining step is now an explicit admin action rather than a local code gap. `sprout-admin` can update an existing signed entity-anchor snapshot to accept the paired contract ID:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/sprout
swift run sprout-admin entity-anchor accept-entity-link \
  --snapshot /path/to/current-entity-anchor-snapshot.json \
  --entity-link ~/Library/Application\ Support/HAVENAgent/Out/agent-operator-entity-link.json \
  --identity-context Scaffold \
  --anchored-public-key <existing-operator-public-key-b64url> \
  --out /path/to/entity-anchor-snapshot.updated.json
```

That command re-verifies the existing snapshot signature, re-verifies the entity-link mutual signatures, appends the contract ID to the matching entity record, and re-signs the snapshot with the scaffold admin identity. The remaining operational step after that is deploying the updated snapshot on the scaffold host.

## Planned integration steps

1. Move the reusable runtime bootstrap out of UI-driven `AppInitializer` and into a package that the agent can import.
2. Add richer approval metadata, reviewer identity binding and correlation IDs to the review/audit trail.
3. Bind the current reconnect/renewal loop to a richer `sprout`-managed resolver/session lifecycle than the bootstrap artifact alone.
4. Persist trusted signing material and recovery metadata once rotation/revocation semantics are defined.
5. Introduce dedicated action cells only where they improve clarity without weakening the current review boundary.
