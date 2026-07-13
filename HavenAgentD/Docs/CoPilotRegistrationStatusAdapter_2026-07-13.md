# Co-Pilot registration status adapter

Date: 2026-07-13
Owner: Binding / HAVENAgentD
Status: implemented and verified

## Formål and Goals

### `purpose://capability.delivery`

Intent: let Binding obtain the real local HAVENAgentD status observation over
the authenticated loopback bridge and report only the information the
CellScaffold Co-Pilot capability broker needs. The same observation is also
available from `haven-agentd status --json` for non-sandboxed diagnostics.

Goal: focused tests prove that StatusService produces the v1 registration
observation, the live bridge exposes it only after token authentication, and
Binding calls `registration.report` with the same owner requester identity.
Result: passed in this change.

### `purpose://access.audit.privacy`

Intent: preserve the local bridge and identity boundary while status evidence
moves from HAVENAgentD to Co-Pilot.

Goal: the payload contains no access token, credential, private key, identity
UUID, local paths or non-loopback endpoint. Registered status requires a
listening loopback bridge. Result: zero observed leakage in focused tests.

### `purpose://test.acceptance.purpose-decomposition`

Intent: keep the purpose-to-capability escalation deterministic and testable.

Goal: unknown action IDs are filtered, known actions are reported only when
their local policy/route prerequisites are visible, and the observation is
explicitly marked as evidence rather than a grant. Result: passed in this
change.

## Runtime flow

1. `StatusService` inspects the actual config, control bridge and local action
   policy.
2. `haven-agentd status --json` includes
   `registrationObservation` with schema
   `haven.agentd-registration-observation.v1`.
3. The existing authenticated `/onboard/status.json` loopback route exposes the
   report to the sandboxed Binding app. The access token stays in this local
   request boundary.
4. `BindingHavenAgentDStatusClient` accepts only an authenticated loopback
   endpoint and fetches the report without spawning a subprocess.
5. `BindingHavenAgentDRegistrationAdapter` validates the observation, removes
   unknown action IDs and refuses secrets or unsafe endpoints.
6. Binding calls `registration.report` on the resolved
   `HAVENAgentCapabilityBroker` using the existing requester identity.
7. The broker still enforces its normal owner/grant path. The observation never
   grants install, read, write or execution authority.

The adapter is an explicit API. A host surface resolves the owner-scoped broker
and calls `refreshAndReport(...)`; it must not cache or log the full status
document.

## Action availability

The status projection reports only action IDs recognized by the CellScaffold
v1 broker:

- `mac.finder.close-all-windows` and `shortcut.binding.wake` require an exact
  local policy entry with `allowedForRemoteExecution=true`.
- `binding.absorb.cell-input` requires both intent inbox and review routes.
- `folder-watch.changed-input` requires at least one configured folder watch.
- `sprout.sync.local-agent` requires non-disabled Sprout startup and the live
  resolver path.

These checks describe visible local readiness. They are not authorization.
Signed intent, expiry, nonce, local review and the action-specific policy still
apply.

## Claim ledger

### C1 — actual status can produce the broker observation

- Type: project capability
- Strength: assertive
- Support: `StatusService` already owns config, launchd and loopback-bridge
  inspection; the new builder projects a strict subset.
- Counterargument: the status command may exist while the daemon is not
  running.
- Adjudication: registered status requires a listening loopback bridge;
  otherwise the projection is `installed_not_running`.

### C2 — the projection does not create authority

- Type: security property
- Strength: assertive
- Support: the projection says
  `owner-reported-runtime-observation-not-a-grant`; Binding submits it through
  `Meddle.set` with the caller identity, and the broker/resolver enforces access.
- Counterargument: localhost possession could be treated as sufficient trust.
- Adjudication: contradicted by design. A loopback listener is readiness
  evidence only; token, link possession and status do not grant access.

### C3 — capability IDs can be derived conservatively

- Type: project capability
- Strength: moderated
- Support: exact remote-policy flags and configured runtime routes are local
  machine-readable evidence.
- Counterargument: configuration proves intent, not that every downstream
  native action will succeed.
- Adjudication: supported only as readiness metadata. User-facing language and
  broker output must not describe it as successful execution capability.

## Security contract

- Protected action: `HAVENAgentCapabilityBroker.registration.report`.
- Authority path: existing Binding owner identity -> resolver/grant -> broker.
- Evidence path: local `StatusService` -> authenticated loopback status route
  -> Binding validator -> broker.
- Authentication token path: Binding credential source -> loopback request
  query -> HAVENAgentD authorization check; never copied into the observation
  or broker payload.
- Never forwarded: `localControlBridge.accessToken`, private key material,
  credential values, full config, local filesystem paths or identity UUID.
- Registered bridge: `ws`/`wss` loopback only, without credentials or query.
- Side effects: status collection and reporting do not execute an agent action.

## Human decision and open items

Kjetil remains the decision owner for when the host should call the adapter.
Automatic periodic reporting is deliberately not enabled in this change; that
would require an explicit freshness policy, owner-visible control and a
decision about whether runtime observations may be retained.

## Verification

- `swift test --package-path HavenAgentD --filter '(AgentStatusRegistrationObservationTests|StatusServiceTests|AgentCellRuntimeHostTests.hostExposesAgentSupervisorOverLocalControlBridge)'`
  - Result: 5 tests in 3 suites passed.
- `Scripts/test_binding.sh -only-testing:BindingTests/HavenAgentDRegistrationAdapterTests`
  - Result: 6 tests in 1 suite passed in the sandboxed macOS test host.
- `git diff --check` on the scoped files.
