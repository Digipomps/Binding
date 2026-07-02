# HavenAgentD Docs

This folder is the canonical home for agent-specific architecture, operator guidance, and security notes.

## Active docs

- [OperatorRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/OperatorRunbook.md): current step-by-step setup, install, bootstrap, review, and launchd guide for `haven-agentd`
- [BindingBoundary.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/BindingBoundary.md): product-boundary note for how `Binding` and `HavenAgentD` relate after the standalone split
- [SecurityModel.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/SecurityModel.md): trust model, launchd rationale, and local automation constraints
- [LocalModels.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/LocalModels.md): `AgentLocalModelCell`, local `llama-server` configuration, and phone/iPad access path
- [ProvisioningPack.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/ProvisioningPack.md): provisioning pack format and the `provisioning-request` / `provisioning-import` round trip for pilot users
- [IdentitySignatures.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/IdentitySignatures.md): detached, audience-bound signed statements issued by the local agent identity
- [../Packaging/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Packaging/README.md): signed + notarized `.pkg` build, install, and `setup` activation
- [HavenAgentDMCPServerSurface.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/HavenAgentDMCPServerSurface.md): proposed MCP adapter surface with first resources, tools, and confirmation boundaries
- [../../Documentation/HavenAgentPhoneApprovalLoopRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/HavenAgentPhoneApprovalLoopRunbook.md): cross-cutting runbook for the iPhone notification / approval loop and current live verification status

## Legacy docs

These documents describe the older Binding-embedded operator flow and are kept only as historical implementation context:

- [Legacy/BindingProvisioningRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/Legacy/BindingProvisioningRunbook.md)
- [Legacy/AgentSetupWorkbench_UI_Review.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/Legacy/AgentSetupWorkbench_UI_Review.md)
