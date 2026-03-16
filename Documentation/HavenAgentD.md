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
- a loopback-only, token-gated local CellProtocol control bridge so Binding can use live supervisor/inbox/review cells without opening localhost authority wider than needed
- a stable persisted agent identity plus `AgentIdentityCell` so Binding can pair the operator identity to a concrete agent device over CellProtocol
- isolated `--root` runtime support and a workspace-level smoke test via `Scripts/test_haven_agentd.sh`
- a real bootstrap probe via `haven-agentd bootstrap-probe` and `Scripts/test_haven_agentd_bootstrap.sh` so staging/dev can be tested from Binding once local pairing has materialized `starter-auth` + entity-link evidence
- security model documentation
- blueprint catalog for the next planned CellProtocol cells

## Binding-side provisioning surface

Binding now also exposes a purpose-driven local provisioning surface for the agent:

- [AgentProvisioningCell](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/AgentProvisioningCell.swift) is the app-side `GeneralCell` that models install, start, connect and stop as CellProtocol actions.
- [AgentEnrollmentCell](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/AgentEnrollmentCell.swift) is the app-side `GeneralCell` that reads the agent identity through the loopback CellProtocol bridge, establishes a normal CellProtocol agreement on that bridge, verifies its signed enrollment attestation, writes a local pairing artifact, then requests and verifies a signed `starter-auth` payload plus a mutually signed entity-link contract from the agent for `sprout`.
- [ConfigurationCatalogCell](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift) now ships an `Agent Setup Workbench` `CellConfiguration` with a concrete skeleton and references to `AgentProvisioning`, `Perspective` and `Porthole`.
- [BootstrapView](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift) registers both `cell:///AgentProvisioning` and `cell:///AgentEnrollment` locally so the workbench can be loaded like any other cell-driven surface.
- [ContentView](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift) includes the workbench in curated menus so the operator can discover it from the normal Binding UX.

This surface is intentionally purpose-first:

- draft or import a purpose from `Perspective`
- write local agent config from that purpose
- install and start `haven-agentd`
- pair the Binding operator identity to the stable agent device identity for that purpose
- run a reviewed connect step without bypassing CellProtocol
- inspect the persisted remote-intent review queue and audit trail
- prefer the live loopback CellProtocol control bridge for operator state and review actions
- fall back to `haven-agentd review-approve` / `review-reject` only when the local bridge is unavailable

The current topology rule is explicit in the workbench state:

- use one local control porthole for operator-facing setup and review
- keep remote peers headless over CellProtocol
- do not allocate a dedicated porthole per remote connection
- keep the operator bridge loopback-only and token-gated so localhost review authority is not ambiently exposed

The current identity rule is also explicit:

- Binding keeps an operator identity
- HavenAgentD keeps a separate stable device identity
- pairing happens through `AgentIdentityCell` + `AgentEnrollmentCell`, not by sharing one vault file between the app and the agent
- the agent now re-verifies the persisted pairing artifact locally before it treats an operator as paired
- `starter-auth` is now signed by the agent identity itself over CellProtocol and written to the config-referenced path, while `sprout` also receives the paired entity-link evidence for the same flow
- the current staging/dev test path is now explicit too: preflight the local pairing artifacts first, then run a real `sprout bootstrap` through `bootstrap-probe`, so any remaining failure shows up as concrete scaffold admission feedback instead of ambiguous local state
- the current scaffold admission follow-up is explicit too: when staging still reports `identity not found in accepted anchor snapshot`, `sprout-admin entity-anchor accept-entity-link` can update and re-sign the existing anchor snapshot with the paired contract ID instead of requiring manual JSON editing

## Intended follow-up

The next implementation step should be a proper integration adapter layer:

- `sprout` for a richer resolver/session lifecycle beyond the current artifact-driven reconnect/renewal loop
- `CellProtocol` for connecting the current local graph to durable approval state, persisted audit, and remote lifecycle orchestration

Do not skip the policy boundary and jump straight from remote intent to AppleScript execution.
