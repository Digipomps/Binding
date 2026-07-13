# Personal Butler profile and proactivity

Date: 2026-07-13

## Status

Implemented and verified in the owner-scoped `BindingPersonalChatHubCell`.

This slice adds the private policy and user-visible controls. It does not add a
background scheduler. A host may call `butler.support.consider` on a bounded
foreground event later, but only after the owner has enabled proactive checks.

## Formål and Goals

| Formål | Goal | Baseline | Target | Evidence | Status |
| --- | --- | --- | --- | --- | --- |
| `purpose://human-agency` | The owner can name the butler, describe its style and correct it with small preference signals. | Fixed `HAVEN Co-Pilot` presentation. | Owner-controlled profile is readable and editable without a model call. | `BindingPersonalButlerPolicy`, chat parity tests, skeleton JSON. | satisfied |
| `purpose://preference.owner-controlled` | Unsolicited support is off by default and remains bounded by owner-visible controls. | No explicit butler initiative policy. | Off by default; check-in, advice, quiet hours, cadence and snooze gates are deterministic. | Policy tests and cell action tests. | satisfied |
| `purpose://access.audit.privacy` | Personality and support decisions do not require raw behavior history or hidden emotional/health inference. | Existing chat-scoped privacy policy, no butler profile. | Fixed allowlisted signals, no raw feedback retention, no provider invocation during evaluation. | State contract and negative policy assertions. | satisfied |
| `purpose://test.acceptance.purpose-decomposition` | Every load-bearing product claim is either verified, narrowed or left open. | Product request only. | Claim ledger below is adjudicated and residual scheduler gap is explicit. | This document and focused test output. | satisfied |

## Runtime contract

The private state is `chatHub.state.butler` with four separations:

1. `profile` contains owner-selected name, style guidance and an aggregate
   preference count. Raw feedback is not retained.
2. `capabilities` is a transparent descriptor snapshot derived from visible
   helpers, scoped provider descriptors, current purpose-context status and
   local HAVENAgentD readiness. Refresh does not invoke a provider or agent.
3. `proactivity` contains owner controls. It defaults to disabled, uses a
   72-hour minimum interval, quiet hours from 22:00 to 08:00 and a one-week
   snooze action.
4. `support` stores only the latest decision and a low-confidence counter. It
   does not store a raw behavior log.

Supported signals are deliberately narrow:

- `explicit_help`
- `periodic_check_in`
- `repeated_low_confidence`
- `repeated_failure`
- `advice_opportunity`

Unknown signals are suppressed. Periodic, blocked-work and advice offers must
each pass their relevant owner policy. Repeated failure needs at least two
signals. Every accepted offer is only a local chat message and says that the
user must respond before anything else can happen.

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
- Adjudication: partly supported. The decision gate and chat staging path are
  implemented; automatic foreground scheduling is intentionally open until the
  owner-facing cadence and cross-device behavior have been accepted.

### C4 - The butler can know when the user clearly needs help

- Type: project capability, moderated.
- Support: two consecutive low-confidence or failure signals are observable
  local interaction outcomes.
- Counterargument: failure signals do not establish emotion, wellbeing or a
  desire for advice.
- Adjudication: narrowed. The system may ask a neutral question after repeated
  failure when enabled; it must not infer emotion, health or personal state.

## Security and authority boundary

- Protected resource: owner-private butler profile and proactive preference
  state inside `BindingPersonalChatHubCell`.
- Authority path: the existing owner-scoped Cell agreement and requester
  validation. The policy creates no grants.
- Provider boundary: capability refresh and support evaluation set
  `providerInvoked=false` and never call a language model.
- Side-effect boundary: an offer only appends a local chat row. Sending,
  creating, sharing, installing or invoking a model still requires the existing
  explicit action path.
- Public boundary: no butler profile or support decision is added to a public
  read model.

## Verification

- `Scripts/test_binding.sh -only-testing:BindingTests/ChatWorkbenchParityTests`
  passed with 51 tests in one suite and zero failures. Six tests cover the new
  profile, support gate, capability snapshot, deterministic cadence and
  skeleton contract.
- `Scripts/test_binding.sh -only-testing:BindingTests/CellConfigurationVerifierXCTest/testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures`
  passed with one test and zero failures against the real sandboxed Binding
  runtime.
- `git diff --check` passed before final handoff.

## Human decisions still open

1. Whether 72 hours is the right default minimum interval.
2. Whether foreground scheduling should run on app launch, after a completed
   task or only after a user-defined schedule.
3. Whether owner-approved cross-device sync should exist for personality and
   cadence preferences. This slice keeps them in the owner-scoped chat cell.
