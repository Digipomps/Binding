# Scheduled events

HAVENAgentD owns local wall-clock scheduling because it already owns the macOS
process lifecycle, local automation policy, and audit state. CellProtocol cells
may describe or request a schedule, but the daemon remains the effect boundary.

## Purpose and goals

- Purpose: start an approved local event at a declared time without giving a
  CellConfiguration or remote caller general command execution.
- Goal: support one run, an exact number of runs, or repetition until stopped.
- Goal: persist run count, next fire time, result summary, and stop state across
  worker restarts.
- Goal: execute only named actions present in the local automation policy.

## Configuration

`AgentConfig.scheduledEvents` contains event definitions. `firstFireAt` is an
ISO-8601 timestamp. Repeating events require a positive `intervalSeconds`.
`count` also requires a positive `repeatCount`.

```json
{
  "automationPolicy": {
    "localTasks": [
      {
        "id": "resume-approved-session",
        "description": "Resume one locally approved agent session.",
        "executablePath": "/absolute/path/to/agent-cli",
        "arguments": ["--resume", "approved-session-id", "--print", "Continue"],
        "requiresUserSession": true
      }
    ]
  },
  "scheduledEvents": [
    {
      "id": "resume-once",
      "firstFireAt": "2026-07-10T23:00:00Z",
      "repeatMode": "once",
      "action": { "kind": "localTask", "id": "resume-approved-session", "arguments": {} }
    }
  ]
}
```

Run the worker independently of scaffold connectivity:

```sh
haven-agentd schedule-worker --config /path/to/config.json
haven-agentd schedule-list --config /path/to/config.json
haven-agentd schedule-stop --event-id resume-once --config /path/to/config.json
```

Runtime state is written atomically to `State/scheduled-events.json`. A local
task has a fixed absolute executable path and fixed arguments in policy; a
scheduled event references only its ID. This deliberately excludes arbitrary
shell source, environment injection, and remote argument substitution.

## CellConfiguration boundary

A CellConfiguration can render a reference that reads scheduler state or sends
a typed schedule/stop request once `ScheduledEventCell` is exposed through the
local control bridge. That control surface must accept only action IDs already
present in the local policy. The worker and persistence model in this change are
the daemon-owned foundation for that surface; direct arbitrary commands are not
part of the contract.
