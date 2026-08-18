# Binding Boundary

`HavenAgentD` is the standalone macOS agent repository. Binding is a separate
app repository and integrates with the agent only through released executables,
loopback runtime surfaces, CellProtocol flows, and versioned contracts.

## Current boundary

- `Binding` is the standalone app product.
- `Binding` may connect to remote `CellScaffold`.
- `Binding` must not build, install, launch, or expose `haven-agentd` setup UX as part of normal app behavior.
- `HavenAgentD` owns agent runtime, local automation policy, `launchd` integration, bootstrap tooling, and operator/admin documentation.
- The repositories may be sibling checkouts for development; neither repository assumes that HavenAgentD is nested inside Binding.

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
- machine-readable cross-repository contracts under [`../Contracts`](../Contracts/README.md)
- security and trust-boundary docs under [README.md](../README.md) and [SecurityModel.md](SecurityModel.md)

## Versioned Binding contract

Binding currently consumes `haven.agentd-registration-observation.v1` from the
token-gated loopback onboarding status endpoint. The JSON Schema and a valid
example live under [`Contracts/`](../Contracts/README.md). The observation is
redacted runtime evidence and never an authorization grant.

Binding may use `BINDING_HAVEN_AGENTD_BINARY` and
`BINDING_HAVEN_AGENTD_MCP_BINARY` as explicit development overrides. Normal
operation resolves installed executables; it does not inspect `.build` inside
this repository.

## Operator/admin decision

For the current repo state, agent admin belongs only in the `HavenAgentD` project/docs.

That means:

- no first-class agent setup workbench in Binding
- no Binding menu/catalog/bootstrap exposure for agent provisioning
- any future operator tooling for the agent should be introduced as a dedicated external tool or explicit adapter, not reintroduced into the main Binding app by default

## Legacy note

Earlier Binding-embedded agent setup material is preserved only as historical context under [Legacy](Legacy).
