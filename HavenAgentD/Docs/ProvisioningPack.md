# Provisioning Pack

A **provisioning pack** is a single transferable JSON file that carries the
already-signed evidence one agent needs to join a scaffold. The operator mints
it out-of-band and hands it to the pilot user (e.g. Victoria), who installs it
with `haven-agentd provisioning-import`.

The pack carries **evidence only**. Local admin policy (`config.json`) is
written separately by `haven-agentd setup`. This keeps the trust boundary clean:
the pack proves identity/admission; the config decides local automation policy.

## Round trip

```
Victoria's Mac                     Operator
--------------                     --------
setup                              (has scaffold-admin + operator keys)
provisioning-request  ───────────▶ mint pack bound to the agent's key
                      ◀───────────  pack.json
provisioning-import
bootstrap-probe --run-bootstrap
```

1. **`haven-agentd provisioning-request`** prints the agent's stable identity
   (`boundAgent.agentPublicKeyBase64URL` + UUID + DID) plus the configured
   scaffold domain / purpose / interests. It materializes the identity if the
   agent has never run. Send this output to the operator.
2. The operator mints a pack **bound to that exact agent public key** (see
   fields below), signs the three artifacts, and returns `pack.json`.
3. **`haven-agentd provisioning-import --pack pack.json`** verifies and installs.

## Why the binding matters

Import **refuses any pack whose `boundAgent.agentPublicKeyBase64URL` does not
match the local agent identity**. A pack minted for one agent cannot be
installed on another, even by mistake. Every embedded artifact is then verified
against that same key and the configured scaffold domain *before* anything is
written to disk; a failure installs nothing.

## Format (`version` "1.0", `kind` "haven-agentd-provisioning-pack")

```jsonc
{
  "version": "1.0",
  "kind": "haven-agentd-provisioning-pack",
  "scaffoldDomain": "staging.haven.digipomps.org",  // must equal config.scaffold.domain
  "purposeRef": "bootstrap.join_scaffold",           // optional, informational
  "boundAgent": {
    "agentIdentityUUID": "…",                        // from provisioning-request
    "agentPublicKeyBase64URL": "…"                   // MUST match the agent identity
  },
  "createdAt": "2026-06-16T00:00:00Z",
  "issuedBy": "operator-display-name",               // optional, informational

  "pairing":     { /* agent-enrollment-pairing artifact, verbatim */ },
  "starterAuth": { /* AgentStarterAuthPayload */ },
  "entityLink":  { /* AgentEntityLinkContract (mutually signed) */ },

  // optional scaffold-side evidence; written only when the matching config path is set
  "trustRoot":         { /* scaffold admin trust root */ },
  "admissionContract": { /* admission contract */ },
  "continuityProof":   { /* continuity proof */ }
}
```

### Required artifacts and what import checks

| Artifact | Bound to | Verified |
|----------|----------|----------|
| `pairing` | operator + agent | signatures + internal consistency (via the pairing loader); scaffold domain matches config |
| `starterAuth` | agent key | Ed25519 signature; `identity_public_key` == agent key; `domain` == config domain. Expiry is a **warning**, not a failure (refresh with `refresh-starter-auth`) |
| `entityLink` | operator + agent | mutual signatures; both `domain_a`/`domain_b` == config domain; agent key present; paired operator key present |

### Where verified artifacts are installed

| Pack field | Target path |
|------------|-------------|
| `pairing` | `Out/agent-enrollment-pairing.json` |
| `starterAuth` | `config.scaffold.starterAuthPath` (default `starter-auth.json`) |
| `entityLink` | `config.scaffold.entityLinkPath` (default `Out/agent-operator-entity-link.json`) |
| `admissionContract` | `config.scaffold.admissionContractPath` (if set) |
| `continuityProof` | `config.scaffold.continuityProofPath` (if set) |
| `trustRoot` | `scaffold-admin-trust-root.json` |

(Paths are under the runtime root, default `~/Library/Application Support/HAVENAgent/`.)

## After import

`provisioning-import` runs a `bootstrap-probe` and reports `readyForBootstrap`.
Then:

```bash
haven-agentd bootstrap-probe --run-bootstrap   # real scaffold admission test
```

If the resolver reports `identity not found in accepted anchor snapshot`, the
remaining step is scaffold-side admission of the paired contract via
`sprout-admin entity-anchor accept-entity-link` (see [../README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/README.md)).

## Not yet automated

Minting the pack (signing pairing approval, issuing starter-auth, building the
mutually signed entity-link, and updating the scaffold entity-anchor snapshot)
is **operator-side tooling**, not part of `haven-agentd`. This document defines
the format that tooling must produce. See
[OperatorRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/OperatorRunbook.md)
and [SecurityModel.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/SecurityModel.md).
