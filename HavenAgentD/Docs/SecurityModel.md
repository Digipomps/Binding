# Security Model

This package is meant to run on a user-owned Mac while accepting intent from a cloud-backed HAVEN entity. That makes the trust boundary explicit and narrow.

## Core rule

The cloud may request an intent.

The Mac decides whether that intent maps to a local side effect.

The cloud does not get a general scripting channel into the machine.

## Non-negotiable constraints

- Never execute raw shell commands from a remote request.
- Never execute raw AppleScript text received from the network.
- Never allow remote requests to bypass the local allowlist.
- Never store long-lived secrets in world-readable folders.
- Never run this as a `LaunchDaemon` if GUI automation is required.

## Why `LaunchAgent`

If the agent needs to interact with Safari, Xcode, Shortcuts or other GUI applications via Apple Events or Accessibility, it must run inside the logged-in user session.

That means:

- use `LaunchAgent`
- keep paths under the current user's `Application Support`
- request Automation / Accessibility permissions in the same user context that will actually execute the automation

## Why named AppleScript definitions

`osascript` is powerful enough to become a remote shell if you let arbitrary script text cross the network boundary.

This package avoids that by requiring:

- a locally defined script ID
- a locally defined script body
- a locally defined argument schema
- strict validation of each argument before execution

The current runner passes values as positional `argv` items to `osascript`. This removes the need to concatenate untrusted strings into the script source.

## Why a dedicated `sprout` client

The bootstrap side has the same risk pattern as local automation: if you turn a config or remote request into a shell string, you have created another injection boundary.

The package now uses a dedicated `SproutBootstrapClient` that:

- constructs a fixed argument vector
- executes `sprout` directly as a binary via `Process`
- writes plan/state artifacts into the agent's own state directory
- rejects invalid or non-absolute binary paths before execution

This is deliberately narrower than "run whatever bootstrap command text the cloud asked for".

## Why the first real cells are read-mostly

The first concrete `GeneralCell` implementations are intentionally low-risk:

- `AgentSupervisorCell` projects local runtime state outward
- `RemoteIntentInboxCell` accepts structured intent payloads and queues them
- neither cell executes a side effect as part of remote input handling

That split is deliberate. It keeps "receive intent" separate from "perform effect", so policy, audit and approval can sit between them.

## Why signed remote intents use a local issuer trust store

The signed remote-intent path is now anchored in local config, not in the envelope itself.

Each trusted issuer entry supplies:

- an issuer ID
- a locally configured public signing key
- the topics that issuer may send
- the action IDs that issuer may request

The envelope may prove that a trusted issuer signed the payload, but it cannot upgrade its own authority beyond what the local policy says that issuer may do.

## Why expiry and nonce checks happen before queueing

`RemoteIntentInboxCell.enqueueSigned` and the native `PortholeIngressSession` now verify:

- payload shape limits
- issuer allowlist membership
- signature validity
- `issuedAt` / `expiresAt` against a local skew window
- nonce uniqueness with persisted replay state across normal restarts

This happens before the intent is appended to the queue. Rejected envelopes emit a rejection flow event instead of silently failing open.

## Why native porthole ingress is artifact-derived

The agent now opens live native ingress only from the artifact produced by `sprout bootstrap join`.

That matters because:

- the websocket URL is derived from a signed porthole access contract, not handwritten config
- `PortholeClientSession.fromContract` verifies contract signature, expiry, client kind and protocol before the agent attempts a live bridge connection
- the agent does not accept an arbitrary websocket endpoint as a substitute for that signed artifact

This keeps the remote ingress bound to the same bootstrap contract that granted native porthole access in the first place.

## Why reconnect and renewal re-run local bootstrap

Native ingress recovery now goes back through `sprout bootstrap join` on two conditions:

- the initial join/connect path fails
- the current contract is near expiry according to local renewal lead time

That matters because:

- recovery does not widen the trust boundary beyond the original local bootstrap rules
- the agent never accepts a replacement websocket endpoint or contract pushed directly from the cloud
- retry timing stays local and bounded by config, not by remote instruction

## Why only signed-envelope flow payloads are consumed

The native porthole can carry ordinary flow traffic, not just remote intents.

`PortholeIngressSession` therefore does not treat all incoming flow elements as executable intent. It only hands off payloads that decode into the expected signed-envelope shape, and ignores everything else.

That matters because:

- the porthole can still be used for ordinary CellProtocol traffic without widening the automation surface
- remote intent verification remains an explicit parse-and-verify step, not an implicit trust of the transport channel
- unrelated porthole updates cannot accidentally become side-effect requests

## Why approval and execution are still separate steps

The agent now has a `RemoteIntentReviewCell`, but approval still sits between inboxing and execution:

- inbox verification proves the payload came from a trusted issuer
- review decides whether that verified request should be acted on locally
- execution still goes back through the local automation allowlist using remote origin rules

That means a valid signature is necessary, but not sufficient, for a remote side effect to happen.

## Why review/audit state is persisted separately

The agent now persists queued intents, review audit and seen nonces into a dedicated `remote-intent-state.json`, separate from the main heartbeat/runtime-state file.

That split matters because:

- review/queue state changes can happen from cells outside the normal heartbeat loop
- replay protection must survive a normal restart to remain meaningful
- audit-ish operational data should not be mixed into the main runtime heartbeat document

This is still operational persistence, not a tamper-evident ledger. It improves continuity across restarts, but it is not yet compliance-grade evidence.

## Why porthole ingress status is surfaced in runtime state

The agent now records native ingress phase, bridge endpoint, latest accepted intent ID and latest rejection/error detail into runtime state and exposes it via `AgentSupervisorCell`.

That matters because:

- a headless agent needs an observable distinction between "bootstrap succeeded" and "live ingress is actually connected"
- rejection/error details from remote-intent ingestion should be inspectable without attaching a debugger
- local review logic depends on operators being able to see whether the queue is empty because nothing arrived or because ingress failed earlier

## Why the local cell host is explicit and temporary

The agent now installs a local `CellBase` host at runtime using:

- a dedicated in-memory `LocalIdentityVault`
- `CellResolver.sharedInstance`
- a document root under `~/Library/Application Support/HAVENAgent/CellDocuments`

This host is installed explicitly when `haven-agentd run` starts and restored on shutdown.

That matters because `CellBase.defaultIdentityVault`, `CellBase.defaultCellResolver` and `CellBase.documentRootPath` are mutable globals. The host captures the previous values, installs only what it needs, and restores the old values on stop instead of assuming permanent ownership of process-wide state.

## Why the local vault is in-memory for now

`LocalIdentityVault` currently exists to give the local cell graph a stable owner identity for the life of the process and to provide real signing primitives where the `IdentityVaultProtocol` expects them.

It does not yet persist long-lived agent identity material across restarts.

That is intentional at this stage:

- it narrows secret residency while the remote-intent trust model is still being designed
- it avoids silently creating a durable machine identity before policy and recovery rules are settled

## Why decode restore avoids the global default vault

The new cells rehydrate their intercepts from their decoded owner identity, not from `CellBase.defaultIdentityVault`.

This matters for two reasons:

- it avoids reintroducing a mutable global dependency during decode
- it keeps restored cell permissions bound to the serialized owner, not to whatever vault happens to be globally installed at restore time

## Why Shortcuts first

Shortcuts is the preferred integration point for many local actions because it:

- keeps workflows user-visible
- can be reviewed and edited locally
- gives a narrower and more legible side-effect surface than unrestricted AppleScript

AppleScript should be reserved for actions that cannot be covered well by Shortcuts.

## Why `--root` is only a local development tool

The CLI now supports `--root /path/to/dev-root`, which relocates agent state under `/path/to/dev-root/HAVENAgent/` instead of the user's real `Application Support`.

That is useful for smoke tests and local development because:

- it avoids touching the operator's live agent state
- it lets retry/renewal flows be exercised against disposable artifacts and queues
- it keeps development scaffolding separate from production policy files

It does not weaken the production storage rule: a real installed agent should still keep its admin-owned config and runtime state under the current user's `Application Support`.

## Config ownership

`config.json` is local policy. It must be treated as admin-owned machine configuration, not as remote content.

Recommended controls:

- write it only from a trusted local admin workflow
- keep it under `~/Library/Application Support/HAVENAgent/`
- do not sync it automatically from the cloud without signature and local approval

## Future hardening checklist

- add signed remote-intent envelopes tied to scaffold domain, capability scope and expiry
- add a local approval state machine for high-risk side effects
- bind runtime audit logs to immutable append-only storage
- split heartbeat state from side-effect audit trail
- move from raw folder watches to richer FSEvents handling where tree coverage matters
- persist and rotate local agent signing material only after recovery and revocation semantics are defined
- harden replay-protection retention and pruning rules for the persisted nonce window
- add dedicated action cells only after intent signature checks, approval state and audit hooks are in place
