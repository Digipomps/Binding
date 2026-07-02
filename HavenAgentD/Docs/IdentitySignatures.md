# Identity Signatures

Status: implemented in `HavenAgentD`

`HavenAgentD` can issue a detached, audience-bound signed statement for data
the user wants to send to another entity.

The feature is intentionally not a generic "sign arbitrary bytes" API. The
agent signs a canonical statement that includes the purpose, signer identity,
audience, payload hash, expiry and nonce. The payload itself can travel
separately, and the receiving entity verifies that payload against the signed
SHA-256 descriptor.

## Production Boundary

The signing key belongs to the local agent identity and is used only inside
`HavenAgentD`.

Callers may reach the feature through:

- `AgentSignatureCell`, for discovery and redacted intent preparation
- `POST /commands/identity/sign-statement`, for the daemon-owned command path
- `agent.identity.sign_statement`, for MCP clients that need a thin local
  forwarder

The MCP server does not sign. It loads the active agent config, requires the
loopback control bridge, requires a configured bridge token, and forwards the
request to the daemon command endpoint.

## Purpose Metadata

Co-Pilot/chat surfaces can use this metadata to understand the user's intent:

- endpoint: `cell:///agent/identity/signatures`
- action ID: `identity.sign-statement`
- topic: `agent.identity.signatures`
- default purpose ref: `personal.identity.sign.statement`
- goal ID: `agent.identity.issue-audience-bound-signature`
- capability ref: `cap.local_identity_sign_statement`
- interests: `agentd`, `identity`, `signature`, `signering`,
  `signed-data`, `verifiable-statement`, `detached-payload`,
  `audience-bound`, `nonce-protected`, `local-key-use`

Allowed purpose refs:

- `personal.identity.sign.statement`
- `personal.identity.prove-data-integrity`
- `personal.entity.send-verifiable-statement`

## Request

HTTP command path:

```http
POST /commands/identity/sign-statement?token=<local-control-bridge-token>
Content-Type: application/json
```

MCP tool:

```text
agent.identity.sign_statement
```

Input:

```json
{
  "purposeRef": "personal.identity.sign.statement",
  "payloadBase64URL": "aGVsbG8",
  "payloadSHA256Base64URL": null,
  "payloadMediaType": "text/plain",
  "payloadDescription": "Short note to the recipient",
  "signerIdentityUUID": null,
  "audience": {
    "entityRef": "entity://recipient",
    "publicKeyBase64URL": "recipient-public-key-if-known",
    "publicKeyFingerprint": null
  },
  "expiresAt": "2026-06-29T15:00:00Z",
  "nonce": "client-generated-single-use-nonce",
  "correlationID": "optional-local-correlation-id"
}
```

Exactly one of these payload fields is required:

- `payloadBase64URL`: raw payload bytes encoded as base64url, accepted up to
  65,536 bytes; the result includes only the SHA-256 descriptor
- `payloadSHA256Base64URL`: an already computed 32-byte SHA-256 digest encoded
  as base64url; useful when the caller does not want to hand raw data to the
  command path

The request must include:

- a supported `purposeRef`
- an `audience.entityRef`
- either `audience.publicKeyBase64URL` or `audience.publicKeyFingerprint`
- `expiresAt` as an ISO-8601 timestamp no more than 24 hours in the future
- a single-line `nonce` between 16 and 160 characters

If `signerIdentityUUID` is supplied, it must match the local agent identity.
That prevents a caller from implying that another local identity signed the
statement.

## Result

The command returns an `AgentSignStatementResult`:

```json
{
  "status": "signed_statement_created",
  "actionID": "identity.sign-statement",
  "deliveryMode": "detached_signed_statement",
  "envelope": {
    "signed": {
      "type": "haven.signed-data.v1",
      "version": "1.0",
      "purposeRef": "personal.identity.sign.statement",
      "signerIdentity": {
        "identityUUID": "agent-identity-uuid",
        "displayName": "HAVEN Agent (local)",
        "didKey": "did:key:...",
        "domain": "haven.agent.owner.local",
        "publicKeyBase64URL": "agent-public-signing-key"
      },
      "audience": {
        "entityRef": "entity://recipient",
        "publicKeyBase64URL": "recipient-public-key-if-known",
        "publicKeyFingerprint": null
      },
      "payload": {
        "encoding": "detached-sha256",
        "sha256Base64URL": "payload-sha256",
        "sizeBytes": 5,
        "mediaType": "text/plain",
        "description": "Short note to the recipient"
      },
      "issuedAt": "2026-06-29T12:00:00Z",
      "expiresAt": "2026-06-29T15:00:00Z",
      "nonce": "client-generated-single-use-nonce",
      "correlationID": "optional-local-correlation-id",
      "canonicalization": "json.encoder.sortedKeys.utf8"
    },
    "signatureAlgorithm": "Ed25519",
    "signatureBase64URL": "signature",
    "signingInputSHA256Base64URL": "sha256-of-canonical-signed-object"
  },
  "message": "Audience-bound signed statement created by local HAVENAgentD identity."
}
```

## Verification Rules

A recipient should verify the envelope before trusting it:

1. Reject expired envelopes.
2. Check that `signed.purposeRef` is acceptable for the receiving context.
3. Check that `signed.audience` names the receiving entity or key.
4. Recompute SHA-256 over the detached payload and compare it with
   `signed.payload.sha256Base64URL`.
5. Re-encode `signed` with JSON sorted keys and UTF-8 bytes.
6. Check that the SHA-256 of that canonical signing input equals
   `signingInputSHA256Base64URL`.
7. Verify the Ed25519 signature using
   `signed.signerIdentity.publicKeyBase64URL`.
8. Keep a recipient-side replay cache for `signerIdentity.identityUUID` +
   `nonce` until at least the envelope expiry.

`HavenAgentD` also keeps a local nonce ledger in
`State/identity-signature-nonces.json` so the same local agent will not issue
two statements with the same nonce across normal restarts. That protects local
issuance. It does not replace recipient-side replay protection.

## Security Notes

- Private signing material never leaves `HavenAgentD`.
- The raw payload is not emitted from `AgentSignatureCell` flow events.
- The signed envelope includes only a payload descriptor, not the payload
  bytes.
- The daemon endpoint is loopback-only and token-gated through the local
  control bridge.
- The current stable agent identity descriptor is stored in
  `State/agent-identity.json`, but production private seed material is stored
  in Apple Keychain under service `no.haven.agentd.identity`.
- Legacy descriptor files that still contain `privateKeySeedBase64URL` migrate
  on load: the seed is copied into the configured seed store and the descriptor
  file is rewritten without inline private material.
