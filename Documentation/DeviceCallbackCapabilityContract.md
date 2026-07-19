# Device callback capability contract

Status: Binding-side contract candidate. Not wired to live transport and not a
claim of staging readiness.

## Purposes

- `purpose://access.audit.privacy`: a device may register an APNS token or use a
  callback only through an explicit, identity-bound authority path.
- `purpose://test.acceptance`: success requires a physical-device round trip,
  persistence across restart and negative replay/revocation evidence.

## Incident and prohibited workaround

The deployed `f916` server rejects Binding registration with HTTP 401 in
`VaporDeviceCallback.authorize(_:)`. Binding `6071ca11` sends no ingress
capability. Commit `ce8644e9` injects one shared bearer from an environment
variable. Although that commit is not an ancestor of Binding main, equivalent
code was squashed into `0905abc0`; this change removes it. A shared secret
embedded in an iOS app is extractable, transferable to another device and not bound to a
CellProtocol Identity, purpose, Agreement, request body or expiry.

Participant ID, device ID, APNS token, URL possession and a successful TLS
connection are not authority.

## Binding-side v1 proof

`DeviceCallbackCapabilityProofIssuer` signs an exact request with the existing
persistent IdentityVault identity in
`domain:device:notification-callback`. It refuses to create a new identity in
the request path. `DeviceCallbackAuthenticatedVaultHandle.current()` also
rejects the prompt-free `BindingStartupIdentityVault`; a process-local startup
identity can never become a device credential. The signed canonical payload
binds:

- a short-lived server nonce and challenge ID;
- exact HTTP method, path, purpose, audience and origin;
- requested capability;
- SHA-256 of the exact HTTP body;
- public identity descriptor and non-authoritative vault domain binding;
- a non-secret reference to a previously issued Agreement/credential, including
  the expected participant label, device label, identity UUID and signing-key
  fingerprint; the server still treats all labels as claims until the stored
  authority record is resolved and verified;
- creation time and expiry.

The transport representation is
`Authorization: HAVEN-Device-Proof <base64url-json>`, not a bearer secret.
Authorization headers and request bodies must be redacted from logs.

This commit deliberately does not connect the proof issuer to
`NotificationCallbackClient`. The currently deployed server has no matching
challenge, Agreement-resolution or proof-verification contract. Wiring only
one side would turn a known 401 into an incompatible release.

## Required CellScaffold server contract

The server must implement this atomically before Binding transport wiring:

1. Issue a cryptographically random, 16–64 byte challenge with at most five
   minutes TTL, pinned to one method, path, capability, purpose, public
   authority and normalized HTTPS origin.
2. Consume the challenge exactly once in persistent or otherwise
   restart-safe replay state. Rate-limit challenge issuance and protected
   calls without identity/IP labels in metrics.
3. Decode `HAVEN-Device-Proof`, reconstruct the canonical payload and verify
   the embedded public-key signature.
4. Require the identity descriptor and vault domain binding to match exactly.
   Domain binding is context evidence and grants no authority.
5. Resolve `credentialID` and `agreementID` from server-owned storage. Require
   participant, device, subject UUID/fingerprint, purpose, capability, time window and
   revocation state to match. Unknown, expired or revoked authority fails
   closed. A caller-supplied ID is never sufficient.
6. Verify the SHA-256 digest against the exact received body before decoding or
   mutating `DeviceRegistrationCell`/callback state.
7. Persist only the minimum DeviceRegistration data. APNS tokens remain private
   and must never appear in receipts, logs, metrics or public Entity indexes.
8. Return a signed, subject-bound persistence receipt. Re-read after write and
   prove participant, device hash, identity fingerprint, active consent,
   capability set and update time without returning the APNS token.
9. Preserve DeviceRegistration, Agreement, revocation and replay state across
   restart. A registration is not green until the same identity/fingerprint
   remains active after cold restart.

Admission needs an explicit provisioning path that installs the referenced
Agreement/credential for the device identity. A participant label is not that
path. The recommended route is an existing-device/custodian-approved
CellProtocol identity enrollment followed by a narrow, revocable Grant for
`device.registration.write`, `device.callback.resolve` and/or
`device.callback.submit`.

Binding already contains models and testable protocol services for that
enrollment (`IdentityEnrollmentRequest`, owner/custodian approval,
`SameEntityIdentityLinkCredential`, verifier-bound presentation and
`IdentityLinkRecord`). No installed DeviceCallback credential is established
on the physical iPad by source code or current evidence. The minimum exchange
can be contract-tested without UI, but a real device still needs an explicit
deep-link/UI provisioning step and a persisted completion receipt.

## Acceptance gate

Do not call APNS production-ready until one named physical iPad/iPhone proves:

1. correct signed app revision and APNS entitlement;
2. user consent and persistent device identity;
3. valid challenge/proof registration;
4. rejection of missing proof, shared bearer, wrong audience/path/body,
   expired challenge, replay, wrong subject and revoked Agreement;
5. exactly one APNS test ticket accepted and shown on the target device;
6. callback resolve and submit use separate single-use proofs;
7. cold server restart preserves the active, consented registration and cold
   app restart preserves the same device identity;
8. a second test request is not sent when evidence for the first is ambiguous.
