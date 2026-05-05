# Binding Boundary

`HavenAgentD` is the standalone macOS agent project in this workspace. After the Binding standalone split, agent-specific operator/admin concerns belong here, not in the main Binding app surface.

## Current boundary

- `Binding` is the standalone app product.
- `Binding` may connect to remote `CellScaffold`.
- `Binding` must not build, install, launch, or expose `haven-agentd` setup UX as part of normal app behavior.
- `HavenAgentD` owns agent runtime, local automation policy, `launchd` integration, bootstrap tooling, and operator/admin documentation.

## Why the split matters

The headless agent has a different operational profile from the app:

- user-session daemon behavior via `LaunchAgent`
- stable local storage under `Application Support`
- local automation policy and allowlists
- loopback operator bridge and runtime approval state
- no dependence on the SwiftUI app lifecycle

Keeping those concerns in `HavenAgentD` prevents Binding from regressing back into a bundled helper-installer product.

## What lives in HavenAgentD now

- standalone `haven-agentd` executable target
- runtime/bootstrap/config support under `Sources/HavenRuntimeBootstrap` and `Sources/HavenAgentRuntime`
- local automation bridges under `Sources/HavenMacAutomation`
- agent-specific `GeneralCell` implementations under `Sources/HavenAgentCells`
- local CellProtocol runtime hosting under `Sources/HavenAgentCellRuntime`
- security and trust-boundary docs under [README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/README.md) and [SecurityModel.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/SecurityModel.md)

## Operator/admin decision

For the current repo state, agent admin belongs only in the `HavenAgentD` project/docs.

That means:

- no first-class agent setup workbench in Binding
- no Binding menu/catalog/bootstrap exposure for agent provisioning
- any future operator tooling for the agent should be introduced as a dedicated external tool or explicit adapter, not reintroduced into the main Binding app by default

## Legacy note

Earlier Binding-embedded agent setup material is preserved only as historical context under [Legacy](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/Legacy).
