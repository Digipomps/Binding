# Native local-model reverse RPC

HAVENAgentD exposes its loopback local-model provider to an authorised Butler
through the existing outbound Sprout native porthole. The laptop remains a
`startupMode: join` client and does not accept inbound network connections.

## Contract

- Capability: `cap.local_model.generate`
- Intent topic: `haven.agent.local-model.generate.v1`
- Intent action: `agent.local-model.generate`
- Registration keypath: `native.localModel.register`
- Response keypath: `native.localModel.response`

The agent registers only its stable `providerID`; it does not register a model
name. CellScaffold signs every request with its resolver identity, gives it a
30-second expiry, and chunks the request inside the existing remote-intent
argument limits. HAVENAgentD applies `remoteIntentPolicy`, replay protection and
a second verification immediately before calling `AgentLocalModelCell`.

CellScaffold admits the capability only when the agent's signed Entity inclusion
proof resolves to an entity explicitly listed in
`SPROUT_LOCAL_MODEL_ALLOWED_ENTITY_IDS` (or when the exact agent public key is
listed in `SPROUT_LOCAL_MODEL_ALLOWED_IDENTITY_PUBLIC_KEYS`). Butler sees the
provider only when its identity resolves to that same Entity and the matching
outbound porthole is currently attached.

If the laptop sleeps, disconnects, has an expired contract, registers a different
provider, times out, or returns an unsuccessful result, Butler receives no local
result and continues through its existing provider selection and privacy/consent
policy.

## Staging rollout

1. Set `SPROUT_LOCAL_MODEL_ALLOWED_ENTITY_IDS` to Kjetil's verified staging
   Entity ID. Keep the default empty deny policy elsewhere.
2. Configure AgentD's local backend with a stable
   `HAVEN_AGENTD_LOCAL_LLM_PROVIDER_ID`; model and endpoint remain independently
   replaceable through the existing `HAVEN_AGENTD_LOCAL_LLM_*` settings.
3. Add the current staging resolver public signing key to AgentD's
   `remoteIntentPolicy` for only the topic and action above. Keep
   `requireExpiry: true`.
4. Renew the Sprout join contract and confirm that it contains
   `cap.local_model.generate`, then restart AgentD so it registers the provider.

Do not enable the allowlist in production until resolver-key rotation, bounded
prompt/output sizes, disconnect cancellation and end-to-end staging telemetry
have been reviewed.

