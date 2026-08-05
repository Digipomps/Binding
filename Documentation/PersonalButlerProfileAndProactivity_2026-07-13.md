# Personal Butler profile and proactivity

Date: 2026-07-13

## Status

Implemented and verified in the owner-scoped `BindingPersonalChatHubCell`.

This slice adds the private policy, HAVEN app lifecycle integration, signed
owner-approved preference sync and user-visible controls. HAVENAgentD owns the
user-defined schedule as a persistent daemon. A separately approved signed
staging signal can ask the daemon to start HAVEN through one fixed wake action.

## Formål and Goals

| Formål | Goal | Baseline | Target | Evidence | Status |
| --- | --- | --- | --- | --- | --- |
| `purpose://human-agency` | The owner can name the butler, describe its style and correct it with small preference signals. | Fixed `HAVEN Co-Pilot` presentation. | Owner-controlled profile is readable and editable without a model call. | `BindingPersonalButlerPolicy`, chat parity tests, skeleton JSON. | satisfied |
| `purpose://preference.owner-controlled` | Unsolicited support is off by default and remains bounded by owner-visible controls. | No explicit butler initiative policy. | Off by default; check-in, advice, quiet hours, cadence and snooze gates are deterministic. | Policy tests and cell action tests. | satisfied |
| `purpose://access.audit.privacy` | Personality and support decisions do not require raw behavior history or hidden emotional/health inference. | Existing chat-scoped privacy policy, no butler profile. | Fixed allowlisted signals, no raw feedback retention, no provider invocation during evaluation. | State contract and negative policy assertions. | satisfied |
| `purpose://preference.owner-sync` | Personality and cadence preferences can move between owner devices without broadening access or copying chat history. | Preferences were device-local. | Both devices approve; packets are owner-signed, short-lived, replay-protected and field-allowlisted. | Cell action tests and signed packet verification. | satisfied |
| `purpose://test.acceptance.purpose-decomposition` | Every load-bearing product claim is either verified, narrowed or left open. | Product request only. | Claim ledger below is adjudicated and residual runtime boundaries are explicit. | This document and focused test output. | satisfied |

## Runtime contract

The private state is `chatHub.state.butler` with five separations:

1. `profile` contains owner-selected name, style guidance and an aggregate
   preference count. Raw feedback is not retained.
2. `capabilities` is a transparent descriptor snapshot derived from visible
   helpers, scoped provider descriptors, current purpose-context status and
   local HAVENAgentD readiness. Refresh does not invoke a provider or agent.
3. `proactivity` contains owner controls. It defaults to disabled, uses a
   72-hour minimum interval, quiet hours from 22:00 to 08:00 and a one-week
   snooze action. App-launch and task-completion triggers are available, while
   the user-defined schedule and staging wake are disabled until the owner
   chooses them.
4. `support` stores only the latest decision and a low-confidence counter. It
   does not store a raw behavior log.
5. `sync` contains device-local approval, endpoint and revision metadata. The
   preference packet contains only name, style and cadence fields.

Supported signals are deliberately narrow:

- `explicit_help`
- `periodic_check_in`
- `app_launch`
- `task_completed`
- `user_schedule`
- `repeated_low_confidence`
- `repeated_failure`
- `advice_opportunity`

Unknown signals are suppressed. Periodic, blocked-work and advice offers must
each pass their relevant owner policy. Repeated failure needs at least two
signals. Every accepted offer is only a local chat message and says that the
user must respond before anything else can happen.

`BindingPersonalButlerLifecycleModifier` evaluates app launch and completed-task
signals through `chatHub.butler.trigger.run`. It sends a privacy-safe cadence
projection to `cell:///agent/butler/scheduler`; it does not copy profile text,
chat or feedback. HAVENAgentD evaluates daily, weekday and weekly slots while
the app is closed and starts the HAVEN bundle with a fixed
`haven://butler/check-in` URL. The app then evaluates the same local policy
before showing an offer. `BindingPersonalButlerTriggerBridge.postTaskCompleted(...)`
is the bounded integration seam for Todo, WorkItem and other task producers.

## Capability transparency

The butler's functional level is a description of currently visible building
blocks, not a quality score:

- `basic_chat`
- `guided_local`
- `model_assisted`
- `contextual_model_assisted`

The snapshot counts provider descriptors; it does not claim that a described
model is reachable, suitable or high quality beyond the descriptor and its
availability field. External providers remain subject to the existing explicit
approval and scoped-provider policy.

## Claim ledger

### C1 - User-shaped personality can avoid hidden profiling

- Type: normative and project capability.
- Claim: an owner-selected profile plus fixed feedback signals can shape the
  assistant without retaining raw behavior.
- Support: profile update and feedback actions store only sanitized preferences
  and an aggregate count.
- Counterargument: explicit controls may adapt less smoothly than behavioral
  inference.
- Adjudication: supported for this slice. The loss of automatic adaptation is
  accepted because agency and privacy are primary requirements.

### C2 - More helpers and model descriptors make the butler more functional

- Type: causal, moderated.
- Support: helpers add actions; scoped providers can add interpretation or
  generation capacity; context can improve relevance.
- Counterargument: more providers can also add latency, cost, privacy exposure
  and incorrect output. A descriptor is not proof of quality or reachability.
- Adjudication: narrowed. HAVEN reports visible building blocks and provider
  consequences; it does not equate provider count with quality and does not
  invoke an external provider automatically.

### C3 - A proactive butler can be useful without becoming invasive

- Type: predictive and normative, moderated.
- Support: default-off policy, quiet hours, 72-hour cadence, snooze, fixed
  signal allowlist and no raw behavior log.
- Counterargument: any unsolicited message may still feel intrusive, and a
  scheduler can behave differently across devices and time zones.
- Adjudication: supported across the app and daemon runtime. App launch,
  completed-task notification and HAVENAgentD-owned daily/weekday/weekly
  schedules all pass the same gate. The schedule is consumed once per local
  slot even when quiet hours or cadence suppress the wake.

### C4 - The butler can know when the user clearly needs help

- Type: project capability, moderated.
- Support: two consecutive low-confidence or failure signals are observable
  local interaction outcomes.
- Counterargument: failure signals do not establish emotion, wellbeing or a
  desire for advice.
- Adjudication: narrowed. The system may ask a neutral question after repeated
  failure when enabled; it must not infer emotion, health or personal state.

### C5 - Owner-approved cross-device preference sync preserves privacy

- Type: security and project capability, moderated.
- Support: source and target Cells both require owner approval and normal Cell
  access validation. Packets are signed, expire after 15 minutes and carry a
  monotonic per-device revision.
- Counterargument: reachable remote Cell transport and the same owner authority
  are still required. Device-local offer history can produce an offer on more
  than one device.
- Adjudication: supported for the preference contract. Chat history, support
  counters, raw feedback and provider/model results are explicitly excluded.

## Security and authority boundary

- Protected resource: owner-private butler profile and proactive preference
  state inside `BindingPersonalChatHubCell`.
- Authority path: the existing owner-scoped Cell agreement and requester
  validation. The policy creates no grants. Cross-device import additionally
  requires approval on both source and target.
- Sync integrity: the owner identity signs canonical packets; the receiver
  validates signer/requester identity, expiry, source device and revision before
  applying an exact field allowlist.
- Provider boundary: capability refresh and support evaluation set
  `providerInvoked=false` and never call a language model.
- Side-effect boundary: an offer only appends a local chat row. Sending,
  creating, sharing, installing or invoking a model still requires the existing
  explicit action path.
- Public boundary: no butler profile or support decision is added to a public
  read model.
- Staging boundary: `personal.butler.haven.wake` must first pass the existing
  trusted-issuer signature, expiry, nonce, topic and action allowlists. The
  daemon then requires local owner approval, global proactivity, app-launch
  permission, staging-wake permission, quiet-hours, snooze and cadence gates.
  Remote arguments are ignored and cannot choose a URL or command.

## Verification

- `Scripts/test_binding.sh -only-testing:BindingTests/ChatWorkbenchParityTests`
  executed 55 tests: 53 passed and two existing contact/invite owner-proof
  tests failed with `deniedNoGrant` on `ticket` and `publishEndpoint`. Every
  Personal Butler test passed, including the 72-hour default, all three trigger
  kinds, stable schedule slots, signed two-device approval, allowlisted import,
  replay rejection and the fixed daemon wake URL parser.
- `swift test --package-path HavenAgentD --filter PersonalButler` passed six
  tests across three suites. The daemon scheduler, owner-authorized Cell and
  signed remote wake path are covered.
- `swift test --package-path HavenAgentD --filter AgentConfigTests` passed two
  tests, and `swift test --package-path HavenAgentD --filter AgentCellsTests`
  passed 20 tests across three suites.
- `Scripts/test_binding.sh -only-testing:BindingTests/CellConfigurationVerifierXCTest/testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures`
  passed with one test and zero failures against the real sandboxed Binding
  runtime.
- `git diff --check` passed before final handoff.

## Residual implementation boundaries

1. HAVENAgentD must be installed, running and reachable through its loopback
   Cell bridge before updated app preferences can reach the daemon. The app
   remains usable if that best-effort sync is unavailable.
2. Task Cells must call `BindingPersonalButlerTriggerBridge.postTaskCompleted`
   when their completion becomes authoritative. The bridge and policy path are
   implemented; remote task producers are not silently observed.
3. `butler.sync.push` requires a reachable configured `cell://` endpoint and the
   same owner authority on the target device.
4. Operational cadence history remains device-local because only preferences
   are allowed to sync. A later coordinator would be needed to guarantee a
   single global offer across all owner devices.
5. A real staging issuer must explicitly add the fixed Butler wake action and
   topic to its local trusted-issuer policy. The example issuer key in the
   generated config is still a placeholder and is not production authority.
