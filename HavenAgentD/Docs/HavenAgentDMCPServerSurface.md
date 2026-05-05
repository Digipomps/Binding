# HavenAgentD MCP Server Surface

Status: proposal

This document sketches a concrete v1 API surface for a `haven-agentd-mcp` server that exposes a safe subset of `HavenAgentD` to local AI hosts.

The design goal is not to turn `HavenAgentD` into a generic MCP transport endpoint. The goal is to add a thin MCP adapter in front of the existing agent runtime, review boundary, and local policy model.

## Positioning

- `haven-agentd` remains the long-lived macOS agent runtime.
- `haven-agentd-mcp` is a separate local adapter process that exposes selected `HavenAgentD` capabilities as MCP resources and tools.
- v1 should use MCP `stdio`, not Streamable HTTP.
- the adapter should call Swift library surfaces directly where possible, instead of shelling out to `swift run` in production.

Why `stdio` first:

- it matches the local-host use case for Codex, Claude Code, ChatGPT Desktop, and similar tools
- it avoids introducing HTTP auth, OAuth resource-server metadata, session management, and `Origin` validation in the first iteration
- it keeps the trust boundary aligned with the existing loopback-only local control model

## Non-goals For V1

- no remote MCP exposure over the network
- no generic shell tool
- no raw AppleScript execution tool
- no raw Shortcuts execution tool
- no arbitrary file read/write tool
- no arbitrary bridge-route forwarding tool
- no direct bypass around the existing review and allowlist model

## Adapter Architecture

`haven-agentd-mcp` should reuse the current package layout rather than inventing a parallel admin path.

Primary implementation sources:

- `AgentSupervisorCell` for runtime state, bootstrap state, porthole state, and bridge status
- `AgentIdentityCell` for stable local identity and pairing status
- `RemoteIntentReviewCell` and `ReviewCommandService` for queue and approve/reject operations
- `BootstrapProbeService` for bootstrap preflight and optional real bootstrap verification
- `AgentRuntime.validate` for config validation
- `DeviceActionRelay` request/reply directories for operator prompt and approval workflows

Recommended process model:

1. the MCP host launches `haven-agentd-mcp` over `stdio`
2. the adapter resolves the active agent root and config path
3. read-mostly requests are served from the local control bridge or persisted state
4. write operations are delegated to existing review/bootstrap/relay services
5. the host remains responsible for showing confirmations before sensitive tool calls

## V1 MCP Capabilities

Expose in v1:

- `resources`
- `tools`

Do not expose in v1:

- `sampling`
- `roots`
- `elicitation`
- `tasks`

Notes:

- prompts are optional and can wait until the resource and tool surface is stable
- resource update subscriptions can also wait until the underlying state model is stable enough to justify `resources/subscribe`

## Resource Namespace

Use a dedicated URI scheme:

- `haven-agent://...`

All JSON resources should be returned as:

- `mimeType: application/json`
- canonical structured content rendered as pretty-printed JSON text

Markdown docs should be returned as:

- `mimeType: text/markdown`

### First resources

| URI | MIME | Source | Purpose |
| --- | --- | --- | --- |
| `haven-agent://runtime/state` | `application/json` | `AgentSupervisorCell.state` | Current high-level runtime snapshot for agent health and operator context. |
| `haven-agent://runtime/bootstrap` | `application/json` | `AgentSupervisorCell.bootstrap` | Latest bootstrap invocation summary and artifact metadata. |
| `haven-agent://runtime/porthole` | `application/json` | `AgentSupervisorCell.porthole` | Native porthole ingress phase, endpoint, expiry, retry, and latest accept/reject detail. |
| `haven-agent://identity/descriptor` | `application/json` | `AgentIdentityCell.descriptor` plus pairing status | Stable local device identity and whether the agent is paired. |
| `haven-agent://review/queue` | `application/json` | queued remote-intent state | Pending verified intents waiting for local review. |
| `haven-agent://review/audit` | `application/json` | `RemoteIntentReviewCell.audit` | Approval/reject history and dispatch outcomes. |
| `haven-agent://bridge/status` | `application/json` | local control bridge status | Loopback bridge phase, host, port, and allowlisted routes. |
| `haven-agent://conversation/replies` | `application/json` | `Inbox/Replies/*.json` | Latest prompt and approval replies coming back from Binding. |
| `haven-agent://docs/security-model` | `text/markdown` | `Docs/SecurityModel.md` | Safety context for AI hosts before they invoke sensitive tools. |
| `haven-agent://docs/operator-runbook` | `text/markdown` | `Docs/OperatorRunbook.md` | Operator workflow context for troubleshooting and bootstrap flows. |

### Expected shape for key resources

`haven-agent://runtime/state` should expose at least:

```json
{
  "instanceName": "string",
  "status": "string",
  "activeWatchIDs": ["string"],
  "bootstrap": {},
  "porthole": {},
  "identity": {},
  "controlBridge": {},
  "lastAction": {},
  "lastError": "string|null",
  "lastEventSummary": "string|null",
  "lastHeartbeatAt": "string|null"
}
```

`haven-agent://review/queue` should expose a list shape like:

```json
{
  "pendingCount": 1,
  "pending": [
    {
      "intentID": "string",
      "actionID": "string",
      "issuerID": "string|null",
      "verificationStatus": "verified",
      "receivedAt": "string",
      "expiresAt": "string|null"
    }
  ]
}
```

`haven-agent://conversation/replies` should expose:

```json
{
  "replyCount": 1,
  "replies": [
    {
      "id": "string",
      "conversationId": "string",
      "jobId": "string|null",
      "responseKind": "string|null",
      "decision": "string|null",
      "note": "string|null",
      "prompt": "string",
      "receivedAt": "string"
    }
  ]
}
```

## Tool Namespace

Use dot-separated names under the `agent.` prefix.

All tool results should return:

- `structuredContent` for machine use
- a short `text` block for backwards compatibility and easy human inspection

Sensitive tools should be treated by the host as confirmation-required.

### First tools

| Tool | Purpose | Confirmation |
| --- | --- | --- |
| `agent.state.refresh` | Re-read or refresh the current runtime state and return the same shape as `haven-agent://runtime/state`. | No |
| `agent.config.validate` | Validate the active local config and return normalized validation results. | No |
| `agent.bootstrap.probe` | Run bootstrap preflight; optionally run the real bootstrap path when explicitly requested. | Yes when `runBootstrap=true` |
| `agent.review.state` | Return a fresh combined snapshot of pending intents and recent audit entries. | No |
| `agent.review.approve` | Approve one verified pending intent and return outcome plus updated summary. | Yes |
| `agent.review.reject` | Reject one pending intent and return outcome plus updated summary. | Yes |
| `agent.operator.request` | Create an operator-facing prompt or approval request through `DeviceActionRelay`. | Recommended |
| `agent.operator.wait_for_reply` | Wait for a matching prompt or approval reply to come back from Binding. | No |
| `agent.operator.request_and_wait` | Queue an operator prompt or approval request and wait for the matching reply. | Recommended |

### Tool schemas

#### `agent.state.refresh`

Input:

```json
{
  "type": "object",
  "additionalProperties": false
}
```

Output:

- same shape as `haven-agent://runtime/state`

Implementation note:

- use the local supervisor bridge path when available
- otherwise fall back to the persisted runtime snapshot

#### `agent.config.validate`

Input:

```json
{
  "type": "object",
  "properties": {
    "includeEffectivePaths": {
      "type": "boolean",
      "default": true
    }
  },
  "additionalProperties": false
}
```

Output:

```json
{
  "ok": true,
  "configPath": "string",
  "rootPath": "string",
  "effectivePaths": {
    "stateRoot": "string",
    "cellRuntimeFile": "string",
    "remoteIntentStateFile": "string"
  },
  "errors": []
}
```

Important restriction:

- v1 should validate only the active configured root and config path
- do not accept arbitrary filesystem paths from the MCP caller in the first version

#### `agent.bootstrap.probe`

Input:

```json
{
  "type": "object",
  "properties": {
    "runBootstrap": {
      "type": "boolean",
      "default": false
    }
  },
  "additionalProperties": false
}
```

Output:

- the same structured report shape returned by `BootstrapProbeService`

Important restriction:

- `runBootstrap=false` is the safe default
- `runBootstrap=true` should always require explicit host confirmation

#### `agent.review.state`

Input:

```json
{
  "type": "object",
  "additionalProperties": false
}
```

Output:

```json
{
  "pendingCount": 1,
  "auditCount": 2,
  "pending": [],
  "auditTail": []
}
```

#### `agent.review.approve`

Input:

```json
{
  "type": "object",
  "properties": {
    "intentId": {
      "type": "string"
    },
    "reviewer": {
      "type": "string"
    },
    "note": {
      "type": "string"
    }
  },
  "required": ["intentId"],
  "additionalProperties": false
}
```

Output:

```json
{
  "intentId": "string",
  "outcome": "approvedDispatched|approvedFailed",
  "pendingCount": 0,
  "auditCount": 3,
  "executedAction": {},
  "errorMessage": "string|null"
}
```

Important restriction:

- only verified queued intents may be approved
- the tool must not accept a free-form action payload

#### `agent.review.reject`

Input:

```json
{
  "type": "object",
  "properties": {
    "intentId": {
      "type": "string"
    },
    "reviewer": {
      "type": "string"
    },
    "note": {
      "type": "string"
    }
  },
  "required": ["intentId"],
  "additionalProperties": false
}
```

Output:

```json
{
  "intentId": "string",
  "outcome": "rejected",
  "pendingCount": 0,
  "auditCount": 3
}
```

#### `agent.operator.request`

Input:

```json
{
  "type": "object",
  "properties": {
    "responseMode": {
      "type": "string",
      "enum": ["prompt", "approval"]
    },
    "title": {
      "type": "string"
    },
    "message": {
      "type": "string"
    },
    "purpose": {
      "type": "string"
    },
    "purposeDescription": {
      "type": "string"
    },
    "interests": {
      "type": "array",
      "items": { "type": "string" }
    },
    "conversationId": {
      "type": "string"
    },
    "jobId": {
      "type": "string"
    },
    "payload": {
      "type": "object"
    }
  },
  "required": ["responseMode", "title", "message"],
  "additionalProperties": false
}
```

Output:

```json
{
  "requestId": "string",
  "responseMode": "prompt|approval",
  "status": "queued",
  "requestFilePath": "string",
  "conversationId": "string",
  "jobId": "string"
}
```

Important restriction:

- the tool only writes a structured local request for `DeviceActionRelay`
- it does not submit arbitrary remote cell writes

#### `agent.operator.wait_for_reply`

Input:

```json
{
  "type": "object",
  "properties": {
    "requestId": {
      "type": "string"
    },
    "conversationId": {
      "type": "string"
    },
    "jobId": {
      "type": "string"
    },
    "ticketId": {
      "type": "string"
    },
    "timeoutSeconds": {
      "type": "number",
      "default": 300
    },
    "pollIntervalSeconds": {
      "type": "number",
      "default": 2
    }
  },
  "additionalProperties": false
}
```

Output:

```json
{
  "matched": true,
  "timedOut": false,
  "replyFilePath": "string",
  "requestId": "string|null",
  "conversationId": "string|null",
  "jobId": "string|null",
  "ticketId": "string|null",
  "reply": {
    "id": "string",
    "requestId": "string|null",
    "conversationId": "string",
    "jobId": "string|null",
    "responseKind": "decision|prompt|null",
    "decision": "approved|rejected|null",
    "prompt": "string",
    "receivedAt": "string"
  }
}
```

Important restriction:

- callers should match on `requestId` when available, otherwise `conversationId`/`jobId`
- the tool only waits on persisted replies already written by `DeviceActionRelay`
- v1 should use polling over the local replies directory rather than inventing a second live reply channel

#### `agent.operator.request_and_wait`

Input:

```json
{
  "type": "object",
  "properties": {
    "responseMode": {
      "type": "string",
      "enum": ["prompt", "approval"]
    },
    "title": {
      "type": "string"
    },
    "message": {
      "type": "string"
    },
    "purpose": {
      "type": "string"
    },
    "purposeDescription": {
      "type": "string"
    },
    "interests": {
      "type": "array",
      "items": { "type": "string" }
    },
    "conversationId": {
      "type": "string"
    },
    "jobId": {
      "type": "string"
    },
    "payload": {
      "type": "object"
    },
    "timeoutSeconds": {
      "type": "number",
      "default": 300
    },
    "pollIntervalSeconds": {
      "type": "number",
      "default": 2
    }
  },
  "required": ["responseMode", "title", "message"],
  "additionalProperties": false
}
```

Output:

```json
{
  "queuedRequest": {
    "requestId": "string",
    "responseMode": "prompt|approval",
    "status": "queued",
    "requestFilePath": "string",
    "conversationId": "string",
    "jobId": "string"
  },
  "matched": true,
  "timedOut": false,
  "reply": {
    "id": "string",
    "requestId": "string|null",
    "conversationId": "string",
    "responseKind": "decision|prompt|null",
    "decision": "approved|rejected|null",
    "prompt": "string"
  }
}
```

Important restriction:

- this is a convenience wrapper around `agent.operator.request` and `agent.operator.wait_for_reply`
- callers that need custom retry or background orchestration should still use the two lower-level tools directly

## Host-side Confirmation Policy

Even though MCP tools are model-callable, the host should require explicit user confirmation for:

- `agent.bootstrap.probe` when `runBootstrap=true`
- `agent.review.approve`
- `agent.review.reject`
- `agent.operator.request` when `responseMode=approval`

Recommended confirmation copy should show:

- tool name
- intent ID when relevant
- reviewer and note fields
- whether the action can lead to local automation side effects

## Error Model

The adapter should follow MCP tool error guidance:

- malformed arguments and unknown tool names return protocol errors
- domain failures return tool results with `isError: true`

Examples of tool execution errors:

- `intent not found`
- `intent is not verified`
- `remote intent executor is not configured`
- `bootstrap probe failed at scaffold admission`
- `device action relay is not enabled`

## Suggested V1 Implementation Order

1. `stdio` server skeleton with `resources/list`, `resources/read`, `tools/list`, and `tools/call`
2. read-only resources for runtime, bootstrap, porthole, identity, queue, and audit
3. safe read tools: `agent.state.refresh`, `agent.config.validate`, `agent.review.state`
4. sensitive write tools: `agent.review.approve`, `agent.review.reject`
5. operator messaging tool: `agent.operator.request`
6. optional `agent.bootstrap.probe`

## Future Extensions

Reasonable phase-2 additions:

- prompt templates for bootstrap diagnosis and pending-intent review
- resource templates for `haven-agent://review/intent/{intentId}`
- subscriptions for runtime-state changes
- MCP `tasks` once the workflow requires durable wait/retry semantics
- a loopback-only Streamable HTTP transport only after explicit `Origin` validation and stronger local auth are designed

## First Recommendation

Build `haven-agentd-mcp` as a separate executable target inside the `HavenAgentD` package, using MCP `stdio`, with the initial surface limited to:

- 8 operational JSON resources
- 2 markdown policy/runbook resources
- 7 core tools

That is enough to let multiple AI hosts share a stable operational view of the same local agent without widening the current security boundary.
