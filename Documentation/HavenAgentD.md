# HavenAgentD Integration Note

`HavenAgentD` is a new standalone Swift package under [HavenAgentD](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD) that sketches the headless macOS agent architecture discussed for HAVEN/CellProtocol orchestration.

## Why it lives separately

Binding already has live app-side cells and UI flows. The headless Mac agent needs a different operational profile:

- user-session daemon via `LaunchAgent`
- stable local storage under `Application Support`
- explicit automation policy
- no dependence on the SwiftUI app lifecycle

Keeping the package separate avoids mixing those concerns into the current Binding app while the trust boundaries are still being designed.

## Current deliverables

- standalone `haven-agentd` executable target
- explicit `SproutBootstrapClient` for local `sprout` bootstrap planning/join
- folder watch runtime
- allowlisted `shortcuts` bridge
- allowlisted `osascript` bridge
- state persistence and heartbeat
- `AgentSupervisorCell` and `RemoteIntentInboxCell` as real `GeneralCell` implementations
- `RemoteIntentReviewCell` for explicit approve/reject/dispatch handling of verified remote intents
- `AgentCellRegistry` to instantiate the safe default cell set for a local owner
- `AgentCellRuntimeHost` to install a local vault/resolver host and register those cells into `CellResolver.sharedInstance`
- dedicated `CellDocuments` storage plus `State/cell-runtime.json` snapshotting
- signed remote intent verification against a local trusted-issuer policy
- persisted remote-intent queue/audit/nonce state plus remote-safe dispatch through the local automation allowlist
- native porthole ingress derived from the official `sprout` bootstrap artifact, with live flow ingestion into the verified remote-intent queue
- retry/reconnect after transient startup failure plus pre-expiry contract renewal by re-running local `sprout bootstrap join`
- supervisor visibility for native porthole ingress phase and last accepted/rejected intent status
- isolated `--root` runtime support and a workspace-level smoke test via `Scripts/test_haven_agentd.sh`
- security model documentation
- blueprint catalog for the next planned CellProtocol cells

## Intended follow-up

The next implementation step should be a proper integration adapter layer:

- `sprout` for a richer resolver/session lifecycle beyond the current artifact-driven reconnect/renewal loop
- `CellProtocol` for connecting the current local graph to durable approval state, persisted audit, and remote lifecycle orchestration

Do not skip the policy boundary and jump straight from remote intent to AppleScript execution.
