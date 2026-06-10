# HAVENAgentD Chat Integration Plan

Status date: 2026-05-17

This note captures the current `HAVENAgentD` status and the plan for making chat propose and use the local agent when a user's purpose is better served by the agent runtime than by ordinary chat.

## Current Status

### Verified locally

`HAVENAgentD` is no longer just a sketch. The local agent package currently has:

- `haven-agentd` as a standalone macOS daemon executable.
- `haven-agentd-mcp` as a local MCP stdio adapter.
- local state under `~/Library/Application Support/HAVENAgent/`.
- `sprout bootstrap join` orchestration through `SproutBootstrapClient`.
- remote intent queue/review/audit cells.
- `DeviceActionRelay` request/reply plumbing for phone approval.
- local control bridge support.
- a deterministic smoke test that exercises bootstrap retry, renewal, review and dispatch.

Verification run on 2026-05-11:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
```

Result:

- Swift package build passed.
- 40 package tests passed.
- deterministic smoke finished with `finalPhase = connected`.
- smoke approved and dispatched one reviewed AppleScript action.

During this status pass, `AgentCellsTests` initially failed because the test `MockIdentityVault` produced owner identities without public signing keys. That was fixed by making the fixture issue real Curve25519 signing keys, matching the production ownership proof expected by `GeneralCell`.

Changed file:

- `HavenAgentD/Tests/HavenAgentCellsTests/AgentCellsTests.swift`

### Implemented MCP surface

The current MCP server is implemented as a separate executable target:

- `HavenAgentD/Sources/HavenAgentDMCP/HavenAgentDMCPMain.swift`
- `HavenAgentD/Sources/HavenAgentDMCP/HavenAgentMCPService.swift`

The most important tools for chat/agent collaboration are:

- `agent.config.validate`
- `agent.bootstrap.probe`
- `agent.review.state`
- `agent.review.approve`
- `agent.review.reject`
- `agent.operator.request`
- `agent.operator.wait_for_reply`
- `agent.operator.request_and_wait`

The most important resources are:

- `haven-agent://runtime/state`
- `haven-agent://runtime/bootstrap`
- `haven-agent://runtime/porthole`
- `haven-agent://identity/descriptor`
- `haven-agent://review/queue`
- `haven-agent://review/audit`
- `haven-agent://conversation/replies`

MCP stdio remains the correct first transport for this local host use case. The official MCP transport docs say stdio is one of the standard transports and that clients should support stdio whenever possible. Streamable HTTP adds security duties such as `Origin` validation, localhost binding and authentication, so it should wait until there is a concrete need.

MCP tasks are relevant later for durable long-running workflows, but they are still experimental in the draft spec track. We should not make the first chat integration depend on them.

### Binding chat status

Binding already has a partial chat router:

- `Binding/ChatWorkbenchParityCells.swift`
- `Binding/ChatWorkbenchProviderEvaluation.swift`

What exists:

- `BindingChatIntentClassifier` can classify a limited `agent_action`.
- `BindingChatProviderRouter` has a readiness-aware agent provider.
- `BindingPersonalChatHubCell` can create an `agent-review` workbench module.
- `BindingHavenAgentDStatusProvider` can read local binary/config/starter-auth readiness without mutating state.
- `BindingAgentUseDecision` can tell chat when a phone/Codex/operator-approval prompt should suggest `HAVENAgentD`.
- `BindingPersonalChatHubCell.analyzeDraft` now returns `agentStatus` and `agentUseDecision` in the response and context pack.

What is missing:

- no live `haven-agentd-mcp` call from chat.
- no visible setup/start/connect button that acts on the status detector.
- no phone-first UI entry point that posts `haven.agent.codex.start_prompt` from Binding.
- no full install/start/connect/provisioning flow when the agent is unavailable.
- no complete policy that uses `Perspective` purpose/interest context to decide whether `HAVENAgentD` is the best route.
- no first-class "use the local agent" suggestion card with concrete next action.

### Phone approval status

The phone approval loop is partly implemented and partly unverified live:

- MCP request/reply tools exist and are tested.
- `DeviceActionRelay` request/reply plumbing exists and is tested.
- iPhone app build/install has been verified earlier.
- full push -> phone decision -> reply -> MCP resume has not yet been fully proven.

Known live blockers from the current runbook:

- installed `~/Library/Application Support/HAVENAgent/config.json` may not include `deviceActionRelay`.
- `starter-auth.json` can expire and must be refreshed.
- real staging bootstrap depends on valid pairing, starter auth, entity-link evidence and executable `sprout`.

### Live Mac config status on 2026-05-12

Checked against:

```text
/Users/kjetil/Library/Application Support/HAVENAgent/config.json
```

Current result:

- `haven-agentd validate-config` passes.
- pairing artifact exists and verifies.
- entity-link contract exists and verifies.
- `sproutBinaryPath` points at the local `sprout` build path.
- `starter-auth.json` exists but is expired.
- `deviceActionRelay` is not present in the active config.
- `bootstrap-probe` returns `readyForBootstrap = false` because starter auth is expired.

This means the current Mac install is close, but it cannot yet support live phone approval or phone-originated Codex prompts without refreshing starter auth and enabling the relay.

## Goal

When a user writes in chat, Binding should decide whether ordinary chat, a local helper, a RAG query, or `HAVENAgentD` is the right next capability.

If `HAVENAgentD` is the right route, chat should not silently execute anything. It should propose the agent path with the simplest next step:

- use the installed agent if it is ready.
- use MCP if the MCP adapter is available.
- open Agent Setup Workbench if the agent is not installed or not connected.
- run config/bootstrap checks if installed but not healthy.
- explain when fresh sprout/bootstrap artifacts are required.

There are two distinct directions:

1. Codex asks the phone for approval or a follow-up prompt.
2. The phone asks Codex to start a new prompt or job.

Direction 1 is partly implemented today. Direction 2 is not implemented yet.

## Phone-Initiated Codex Prompts

### What is possible now

As of the 2026-05-12 implementation slice, the repository has the safe v1 backend needed for phone-originated Codex prompts:

- Binding can create a phone-originated payload with `requiredActionKey = haven.agent.codex.start_prompt`.
- `HAVENAgentD` can route that prompt into a persisted local `CodexPromptRequest` queue.
- `haven-agentd-mcp` exposes `haven-agent://codex/prompt-requests`.
- `haven-agentd-mcp` exposes `agent.codex.next_prompt`, `agent.codex.mark_prompt_started`, and `agent.codex.mark_prompt_done`.

This still does not mean the live phone can launch Codex by itself today. The current safe behavior is queue-and-consume: a running Codex host must explicitly consume the request over MCP. A separate allowlisted launch runner is still future work.

The live Mac install also remains blocked until starter auth is refreshed and `deviceActionRelay` is enabled in the active config.

The existing implemented loop is:

```text
Codex or another host -> haven-agentd-mcp -> haven-agentd -> phone -> reply -> haven-agentd-mcp -> host resumes
```

The missing loop is:

```text
phone -> haven-agentd -> Codex host starts or queues a prompt
```

The important distinction is that `HAVENAgentD` can store and relay local requests, but it does not control a Codex session by itself. A running Codex host must either poll the agent over MCP, or we must add a separate approved local host runner that starts Codex with a queued prompt.

### Safe v1 behavior

The first version should not try to launch arbitrary Codex processes from the phone.

Instead:

1. The phone creates a signed or scoped `CodexPromptRequest`.
2. `haven-agentd` stores it under the agent inbox/state root.
3. `haven-agentd-mcp` exposes it to Codex as a resource/tool.
4. A running Codex host explicitly consumes it and starts the work.
5. Codex can then use `agent.operator.request_and_wait` if it needs phone approval while working.

Suggested v1 names:

- request type: `CodexPromptRequest` (implemented)
- request action key: `haven.agent.codex.start_prompt` (implemented)
- MCP resource: `haven-agent://codex/prompt-requests` (implemented)
- MCP tool: `agent.codex.next_prompt` (implemented)
- MCP tool: `agent.codex.mark_prompt_started` (implemented)
- MCP tool: `agent.codex.mark_prompt_done` (implemented)

This keeps the phone as an intent source, not as a hidden remote shell.

### Later launch-runner behavior

A later version can actually start Codex from the phone if we add an explicit, allowlisted runner.

That runner must have:

- fixed executable path or known app bundle.
- fixed workspace allowlist.
- no arbitrary shell arguments.
- visible local audit trail.
- explicit operator approval before enabling.
- a bounded job state file so the phone can see queued, running, blocked, done or failed.

Suggested action ID:

```text
codex.start-prompt-in-workspace
```

Suggested policy:

```json
{
  "id": "codex.start-prompt-in-workspace",
  "kind": "localHostRunner",
  "allowedWorkspaces": [
    "/Users/kjetil/Build/Digipomps/HAVEN/Binding"
  ],
  "requiresUserApproval": true
}
```

This should come after v1 queue/poll works.

## When Chat Should Suggest HAVENAgentD

Suggest `HAVENAgentD` when the prompt or active `Perspective` indicates one of these needs:

| Need | Why agent is appropriate | First chat action |
| --- | --- | --- |
| Local macOS automation | Needs allowlisted Shortcuts or AppleScript review boundary. | Suggest agent review, never direct execution. |
| Long-running coding job approval | Needs operator approval or next prompt after the host pauses. | Suggest `agent.operator.request_and_wait`. |
| Phone approval/notification | Needs push to iPhone and reply correlation. | Suggest enabling `deviceActionRelay` and MCP request/wait. |
| Remote signed intent review | Needs signed envelope verification and local approve/reject. | Suggest review queue surface. |
| Folder/watch based local workflow | Needs daemon behavior outside current chat session. | Suggest installing/starting `haven-agentd`. |
| Scaffold/Porthole local bridge | Needs `sprout bootstrap join` and native porthole ingress. | Suggest bootstrap probe and sprout artifact refresh. |

Do not suggest `HAVENAgentD` for:

- ordinary Q&A.
- normal code edits already possible inside the current workspace.
- pure chat invite/poll/meeting draft helpers.
- RAG lookups where the dedicated RAG provider has grants.
- anything requiring arbitrary shell or raw AppleScript text.

## Decision Policy

Chat should produce an `AgentUseDecision` object before showing any agent suggestion:

```json
{
  "shouldSuggest": true,
  "reason": "local_automation_requires_review",
  "confidence": 0.86,
  "requiredCapability": "local_agent_review",
  "agentStatus": "installed_not_connected",
  "recommendedNextStep": "open_agent_setup_workbench",
  "instructions": []
}
```

Required inputs:

- user draft.
- latest `BindingChatIntentClassification`.
- `Perspective` active purposes.
- `Perspective` interests derived from active purposes.
- available chat providers.
- local `HAVENAgentD` status.
- MCP adapter status.
- installed config status.

The decision should be deterministic first, model-assisted later.

## Implementation Plan

### Phase 1: Local agent status detector

Add a small shared status service used by chat and setup UI.

Suggested name:

- `BindingHavenAgentDStatusProvider`

It should return:

- whether `haven-agentd` binary exists.
- whether `haven-agentd-mcp` binary exists.
- active config path.
- whether config validates.
- whether `deviceActionRelay` is configured.
- whether `sproutBinaryPath` points to an executable.
- whether pairing artifact exists.
- whether `starter-auth.json` exists and is not expired.
- whether entity-link artifact exists.
- latest `bootstrap-probe` summary if cheap enough.
- whether local control bridge status is readable.

This should be read-only. It should not mutate config or run bootstrap.

### Phase 2: Agent suggestion policy in chat

Extend:

- `BindingChatIntentClassifier`
- `BindingChatProviderRouter`
- `BindingPersonalChatHubCell.analyzeDraft`

Add new recognized helper IDs:

- `agent-setup`
- `agent-review`
- `agent-operator-approval`
- `agent-bootstrap`

Use `Perspective` to strengthen suggestions. For example:

- active purpose includes local automation, coding assistant supervision, scaffold operation, workflow automation, or phone approval.
- active interests include `agent`, `automation`, `approval`, `macos`, `sprout`, `porthole`, `review`, `coding-job`.

Chat output should include:

- human-readable suggestion.
- a concrete next action.
- a short explanation of why agent is better than ordinary chat.
- capability and safety notes.

### Phase 3: Setup and bootstrap guidance surface

When the agent is not ready, chat should open a small "HAVENAgentD setup" surface rather than leaving the user with a vague message.

The surface should show only the relevant next step:

- install binary.
- validate config.
- enable `deviceActionRelay`.
- refresh pairing/starter/entity-link artifacts.
- run bootstrap preflight.
- run real bootstrap when evidence is ready.
- connect/start launch agent.

Preferred easiest path inside Binding:

1. Open `Agent Setup Workbench`.
2. Install `haven-agentd`.
3. Start `haven-agentd`.
4. Connect with current purpose.
5. Run review/bootstrap checks.

CLI fallback:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
swift build --package-path HavenAgentD --product haven-agentd
swift build --package-path HavenAgentD --product haven-agentd-mcp
HavenAgentD/.build/debug/haven-agentd validate-config --config ~/Library/Application\ Support/HAVENAgent/config.json
HavenAgentD/.build/debug/haven-agentd bootstrap-probe --config ~/Library/Application\ Support/HAVENAgent/config.json
```

When evidence is ready:

```bash
HavenAgentD/.build/debug/haven-agentd bootstrap-probe \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --run-bootstrap
```

The chat should mention `sprout` only when the next missing piece is actually sprout-related:

- `scaffold.sproutBinaryPath` is missing or not executable.
- `starter-auth.json` is expired or missing.
- entity-link evidence is missing.
- `bootstrap-probe` reports that real scaffold admission has not happened.

### Phase 4: MCP host integration

Use `haven-agentd-mcp` as the first bridge from external AI hosts.

Example MCP server config shape:

```json
{
  "mcpServers": {
    "haven-agentd": {
      "command": "/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/.build/debug/haven-agentd-mcp",
      "args": [
        "--config",
        "/Users/kjetil/Library/Application Support/HAVENAgent/config.json"
      ]
    }
  }
}
```

The exact location depends on the MCP client. The important rules are:

- use absolute paths.
- launch over stdio.
- do not expose a network MCP endpoint in v1.
- keep approval/review tools confirmation-gated in the host.

For a coding assistant job that needs a human decision:

1. host calls `agent.operator.request_and_wait`.
2. `haven-agentd-mcp` writes a request to `Inbox/Requests`.
3. `DeviceActionRelay` publishes it to Binding/iPhone when configured.
4. phone reply lands in `Inbox/Replies`.
5. MCP tool returns the matching decision/prompt.
6. host continues with the operator's answer.

For a phone-originated Codex job in v1:

1. phone writes a `CodexPromptRequest` through the conversation inbox.
2. `haven-agentd` records the request locally.
3. Codex host reads `haven-agent://codex/prompt-requests`.
4. Codex host calls `agent.codex.next_prompt`.
5. Codex starts work in the host session only after explicitly consuming the queued prompt.
6. Codex reports done/blocked through `agent.codex.mark_prompt_done` or an operator request back to the phone.

### Phase 5: Chat-to-MCP bridge inside Binding

Binding chat itself should not need to become a generic MCP client immediately.

First practical step:

- chat suggests the agent route and opens the correct local setup/review surface.
- external AI hosts use MCP directly.

Second step:

- add a narrow Binding-side invoker for the same `haven-agentd-mcp` tools or equivalent local Swift services.
- expose only named actions:
  - `agent.config.validate`
  - `agent.bootstrap.probe`
  - `agent.review.state`
  - `agent.operator.request`

Do not add:

- arbitrary MCP tool calling from chat.
- arbitrary shell execution.
- raw AppleScript or Shortcuts payloads.

### Phase 6: Tests and acceptance criteria

Add tests that prove:

- chat suggests `HAVENAgentD` for local automation prompts.
- chat does not suggest `HAVENAgentD` for ordinary coding edits or RAG questions.
- active `Perspective` purpose/interest can raise confidence for agent use.
- missing binary gives install guidance.
- missing/expired starter auth gives sprout/bootstrap guidance.
- ready MCP config gives `request_and_wait` guidance.
- phone-originated prompt is queued without launching arbitrary processes.
- Codex host can consume a queued phone prompt over MCP.
- consumed prompt is not returned as new again.
- `./Scripts/test_haven_agentd.sh` stays green.

End-to-end acceptance:

1. User asks in Binding chat for a local-agent-suitable purpose.
2. Chat proposes `HAVENAgentD` with a concise reason.
3. If not ready, chat gives exactly the next setup step.
4. If ready, chat offers the MCP/agent review or operator approval path.
5. No side effect happens without explicit approval.
6. For phone approval, a real reply can resume the waiting job.
7. For phone-originated Codex prompts, a running Codex host can consume the queued prompt and record started/done state.

## Suggested Next Implementation Slice

Completed on 2026-05-17:

1. Add `BindingHavenAgentDStatusProvider`.
2. Extend `BindingChatProviderRouter.agentProvider()` with readiness-aware status.
3. Extend `BindingPersonalChatHubCell.analyzeDraft` to include `agentUseDecision`.
4. Add tests for readiness status and chat suggestions:
   - missing relay -> `enable_device_action_relay`.
   - expired starter auth -> `refresh_starter_auth_with_sprout`.
   - valid relay/starter auth -> `configure_codex_mcp_host`.
   - phone-originated Codex prompt -> suggest `agent-setup`.
   - ordinary code explanation -> no agent suggestion.

That gives chat the right instinct before we wire in deeper execution.

The next code slice should now be:

1. Add a visible chat suggestion card or workbench module for `agent-setup`.
2. Show only the current `BindingHavenAgentDStatusProvider.recommendedNextStep` and instructions, not raw JSON.
3. Add a narrow Binding action for phone-originated Codex prompts that calls `AgentConversationClient.postCodexPrompt(...)` with `requiredActionKey = haven.agent.codex.start_prompt`.
4. Keep the first version queue-based: Binding posts intent, `haven-agentd` queues it, and a running Codex host consumes it with `agent.codex.next_prompt`.
5. Do not launch Codex directly from the phone until a separate allowlisted local runner exists.

Phone-originated Codex queue status:

1. `CodexPromptRequest` model and persisted queue are implemented.
2. `DeviceActionRelay` routes `requiredActionKey = haven.agent.codex.start_prompt` into that queue.
3. `haven-agent://codex/prompt-requests` is implemented.
4. `agent.codex.next_prompt`, `agent.codex.mark_prompt_started`, and `agent.codex.mark_prompt_done` are implemented.
5. Remaining work: add a visible chat-first phone UI entry point and readiness guidance that calls `AgentConversationClient.postCodexPrompt(...)`.

## Easiest Setup Steps For The Current Machine

Given the 2026-05-12 live config check, the shortest route to a usable approval loop is:

1. Refresh `starter-auth.json` from the paired agent/operator flow in Binding.
2. Add `deviceActionRelay` to `~/Library/Application Support/HAVENAgent/config.json`.
3. Run:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
HavenAgentD/.build/debug/haven-agentd validate-config --config ~/Library/Application\ Support/HAVENAgent/config.json
HavenAgentD/.build/debug/haven-agentd bootstrap-probe --config ~/Library/Application\ Support/HAVENAgent/config.json
```

4. When the probe says `readyForBootstrap = true`, run:

```bash
HavenAgentD/.build/debug/haven-agentd bootstrap-probe \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --run-bootstrap
```

5. Start or restart the installed agent.
6. Configure the coding host with `haven-agentd-mcp`.
7. Test `agent.operator.request_and_wait`.

Only after that should we test the phone-originated Codex queue.

## References

- Local agent runbook: `HavenAgentD/Docs/OperatorRunbook.md`
- MCP server surface: `HavenAgentD/Docs/HavenAgentDMCPServerSurface.md`
- Phone approval loop: `Documentation/HavenAgentPhoneApprovalLoopRunbook.md`
- Official MCP intro: https://modelcontextprotocol.io/docs/getting-started/intro
- Official MCP transports: https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
- Official MCP tasks draft: https://modelcontextprotocol.io/specification/draft/basic/utilities/tasks
