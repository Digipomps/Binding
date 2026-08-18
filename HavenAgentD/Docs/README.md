# HavenAgentD Docs

This folder is the canonical home for agent-specific architecture, operator guidance, and security notes.

## Active docs

- [OperatorRunbook.md](OperatorRunbook.md): current step-by-step setup, install, bootstrap, review, and launchd guide for `haven-agentd`
- [BindingBoundary.md](BindingBoundary.md): repository and runtime boundary between Binding and HavenAgentD
- [SecurityModel.md](SecurityModel.md): trust model, launchd rationale, and local automation constraints
- [LocalModels.md](LocalModels.md): `AgentLocalModelCell`, local `llama-server` configuration, and phone/iPad access path
- [ProvisioningPack.md](ProvisioningPack.md): provisioning pack format and the `provisioning-request` / `provisioning-import` round trip for pilot users
- [IdentitySignatures.md](IdentitySignatures.md): detached, audience-bound signed statements issued by the local agent identity
- [../Packaging/README.md](../Packaging/README.md): signed + notarized `.pkg` build, install, and `setup` activation
- [HavenAgentDMCPServerSurface.md](HavenAgentDMCPServerSurface.md): proposed MCP adapter surface with first resources, tools, and confirmation boundaries
- [Binding phone approval runbook](https://github.com/Digipomps/Binding/blob/main/Documentation/HavenAgentPhoneApprovalLoopRunbook.md): cross-cutting iPhone notification and approval loop

## Legacy docs

These documents describe the older Binding-embedded operator flow and are kept only as historical implementation context:

- [Legacy/BindingProvisioningRunbook.md](Legacy/BindingProvisioningRunbook.md)
- [Legacy/AgentSetupWorkbench_UI_Review.md](Legacy/AgentSetupWorkbench_UI_Review.md)
