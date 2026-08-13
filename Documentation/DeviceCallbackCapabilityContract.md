# Binding DeviceIngress v3 register candidate

Status: PR #9 is integrated. This follow-up, based on Binding main
`b63ee3bcb8f7c06e75fee0ec150139be0b0e3c24`, makes enrollment depend on an
explicit `disabled|staging|production` rollout environment rather than any
demo or App Store catalog flag. Both checked-in build configurations remain
`disabled`, and the challenge-issuer setting remains empty. A physical build
therefore stays inert unless its release invocation explicitly selects the
environment and injects the exact reviewed issuer descriptor.

## Exact source boundary

- PR #9 final head: `3dab9b083ebaf06bf912458b58a4f961a75c77ab`
- PR #9 merge: `01bd6422778d26d9af156fc21ce105196c96ab0d`
- Binding main baseline for this follow-up:
  `b63ee3bcb8f7c06e75fee0ec150139be0b0e3c24`
- CellProtocol exact revision: `1632ed65d5e4aaf663b26cee1cdddfdcdd5e4412`
- CellScaffold source audited for the register-only server boundary:
  `b96896eea284aed60d5fb307f56c99cd1457e44c`
- The exact final Git revision is supplied by Git and the generated build
  provenance, rather than a self-referential hard-coded source constant.

The CellScaffold revision above is an observation boundary, not operational
proof. The earlier DeviceIngress server prototype branches are not treated as
authority, deployment, readiness, or a current shared transport contract.

The HAVEN target generates a scoped compiler-input attestation after
compilation. It records the actual Xcode Swift file list for the sole build
architecture, generated Swift inputs under `DerivedSources`, a complete
`.swift` inventory of the filesystem-synchronized `Binding` and `Cells`
roots, selected compiler/link settings, the Swift compiler and SDK, the built
Binding Swift module, the Xcode link-file list, and the linked `CellBase.o` and
`CellApple.o` artifacts. It records the exact Binding and CellProtocol HEAD
revisions, independent dirty-worktree flags, and expected code-signing
identity. An ignored or otherwise unlisted `.swift` file in either
synchronized root makes the build fail. Release provenance generation also
fails closed if either source tree is dirty.

This is not a complete full-transitive-build claim. Files outside the declared
roots/inputs are represented by the exact HEAD plus dirty flag, not individual
file digests. On macOS,
`BindingBuildProvenance.current()` checks the static code signature and running
leaf-certificate fingerprint before the attestation may be included in a
register body. Public iOS APIs used by this candidate cannot expose the same
running leaf certificate. The iOS path therefore accepts only the generated
certificate-required mode together with the canonical HAVEN bundle identifier,
the pinned development-team identifier, and a physical-device `iphoneos`
platform attestation; simulator, unsigned-mode, wrong-bundle and wrong-team
inputs fail closed. This is intentionally a narrower platform/build check, not
a claim of running leaf-certificate equivalence. Build provenance is
descriptive evidence and is never an authorization grant.

## Implemented register-only contract

`DeviceIngressRegistrationClient` uses only CellProtocol's canonical v3
contract:

1. It requires an already-provisioned identity in
   `domain:device:notification-callback` and calls the vault with
   `makeNewIfNotFound: false`.
2. Production construction accepts only the authenticated persistent
   `CellApple.IdentityVault`; the prompt-free startup vault is rejected.
3. Audience and challenge issuer are caller-pinned trust inputs. Neither the
   challenge nor transport can select its own trust root.
4. It calls `DeviceIngressRequestFactory.prepare` with the exact canonical
   challenge, protected registration body, persistent identity and
   non-authoritative domain binding.
   Before that call, Binding replaces caller-supplied participant/device and
   consent fields with the authenticated persistent device-identity UUID and
   exact durable consent evidence. The protected body omits the redundant
   `termsAccepted` boolean.
5. The exact accepted consent proof, pending response expectation, and verified
   response evidence are states in one hash-chained journal. Every transition
   is serialized under the canonical OS lock and crash-durably persisted before
   the first mutation-capable transport call: write a mode-0600 temporary file,
   `fsync` and `F_FULLFSYNC` it, read it back, atomically rename the same inode,
   `fsync` the parent directory, then reopen and verify the exact journal and
   hash chain. After each durable journal replacement, its exact head hash and
   monotonically increasing sequence are compare-and-swapped into a separate,
   device-local, non-synchronizing Keychain item and read back while the same
   OS lock remains held. A missing, stale, replayed or rewritten journal/anchor
   pair fails closed; a crash between the two barriers leaves no usable local
   authority. Any failed durability, anchor or read-back barrier prevents
   submit.
6. A registration is returned only after
   `DeviceIngressOperationResponseVerifier.verify` validates the exact signed
   response, durable mutation receipt, target Cell/owner/Agreement bindings
   and an `active_consented` registration receipt.
7. Verified response bytes and their local expectation are persisted together
   and re-verified on restart. Restore returns explicitly historical mutation
   evidence only. It first rebinds evidence to the
   currently authenticated persistent vault's notification identity UUID and
   signing-key fingerprint; portable signed evidence copied from another
   device is rejected.
8. The evidence store walks and pins its owner-controlled 0700 directory chain
   with descriptors. Evidence access is `openat`/`fstatat`/`renameat[x]`/
   `unlinkat` relative to the pinned directory. Managed files must be regular,
   owner-matching, exactly 0600 and `nlink=1`; descriptor, canonical name,
   inode, metadata and content are checked before and after access.
9. A process-wide lock plus a cross-process record lock serializes all journal
   transactions. After `lockf` acquisition and at transaction boundaries, the
   canonical dirfd-relative lock name must still resolve to the same locked
   descriptor inode and unchanged metadata. Separate client/store instances
   cannot both cross the pending/decline gate without one failing closed, and a
   separate-process `lockf` test verifies the store waits on the OS claim.

The local v1 capability model and its proof tests are removed. HTTP method,
path, wrapper, bearer token and server secret are absent from the new Binding
contract. Transport is a byte-preserving protocol and has no policy role.

## Privacy and fail-closed behavior

Raw APNS tokens are held only in memory until a protected body is prepared.
Legacy/current APNS-token UserDefaults keys are deleted without reading them,
and unsigned legacy registration-success state is also deleted. Persisted v3
evidence contains the response expectation and signed receipt, not the raw
token or request body.

Terms consent is an explicit `unknown`/`accepted`/`declined` state. Accepted
state requires a journaled proof containing an acceptance ID, exact terms
version, positive acceptance timestamp, and `accepted` decision; unsigned
legacy UserDefaults values are deleted and never migrated to acceptance. The
exact persisted proof is included in the protected registration body and must
match at the pending transition. If the configured required terms version
changes, an earlier accepted proof is projected as `unknown` and cannot prepare
registration until the new version is explicitly accepted and journaled.
“Not now” is explicitly pre-registration-only.
Under the same journal transaction, it first rejects pending or verified
evidence, durably transitions to `declined`, and then clears consent plus the
in-memory token without an actor-reentrancy window. A prepared stale register
cannot persist after that transition.
If pending or verified evidence exists, local consent is preserved and a
future typed signed revoke/deregister flow is required. That revoke operation
is not implemented by this register-only candidate.

Neither absence of local evidence nor restored register evidence proves
current server state. The UI keeps `isDeviceRegistered=false` even after a
verified register mutation. A fresh signed server status/read-back bound to
the current admission, authority and revocation generations, and reconciled
with the local consent journal state, is required before current active
registration can be claimed. The v3 register-only dependency has no such
operation yet.

The register transport implementation is present, but the shipped/default
composition remains inert: `HAVEN_DEVICE_INGRESS_ROLLOUT_ENVIRONMENT` is
`disabled` and the issuer descriptor is empty. An enabled build must select
exactly `staging` or `production`; the client then requires the corresponding
canonical origin and audience and rejects cross-environment substitution.
The build must also inject the exact public issuer descriptor published by
the ready server pilot metadata. A missing, malformed or substituted
descriptor fails before challenge admission. Resolve and submit also throw
before network access; unsigned push payloads are not staged as a fallback.
No owner identity, Agreement, revocation state, audience, issuer or transport
framing is auto-provisioned or inferred.

For staging, the release operator must first observe
`/conference-mvp/api/device/pilot/metadata` with `enabled=true` and
`ready=true`, independently verify its descriptor SHA-256, and supply its
exact `issuerDescriptorBase64` together with these build settings:

```text
HAVEN_DEVICE_INGRESS_ROLLOUT_ENVIRONMENT=staging
HAVEN_DEVICE_INGRESS_PUBLIC_ORIGIN=https://staging.haven.digipomps.org
HAVEN_DEVICE_INGRESS_AUDIENCE=staging.haven.digipomps.org
HAVEN_DEVICE_INGRESS_CHALLENGE_ISSUER_BASE64=<exact reviewed descriptor>
```

Production uses `production`, `https://haven.digipomps.org`, and the exact
production issuer descriptor. A staging descriptor or endpoint cannot be used
by a production rollout. The descriptor is public trust material, not a
secret, but its provenance and digest are release evidence.

## Remaining operational gates

CellScaffold main observed on 2026-08-13 contains canonical v3 registration,
but its active HTTP composition is deliberately register-only:
`DeviceCallbackRegisterAdmissionCompositionRoot` installs
`RegisterOnlyDeviceCallbackAdmissionService`, and `VaporDeviceCallback`
rejects every protected operation except `.register`. The only challenge
issuer API is `issueRegisterChallenge`. There is therefore no reviewed server
contract from which Binding can safely implement callback `resolve`, callback
`submit`, or an acknowledgement/read-back. Those client operations remain
fail-closed; inventing paths, bearer authorization, or locally trusted push
payloads is prohibited.

Registration can be tested independently once the exact staging pilot is
ready and the physical build pins its descriptor. Promotion still requires:

- public readiness and pilot metadata bound to the same app revision;
- explicit signed physical-device build provenance and the exact rollout
  settings above;
- explicit notification consent, APNS token delivery, canonical challenge,
  canonical register, and a verified `active_consented` mutation receipt;
- controlled app/server restart with the historical receipt still verifiable;
- server authority cells and challenge issuance for `.resolve` and `.submit`;
- a canonical callback acknowledgement/status operation, or an explicit
  reviewed protocol extension, before claiming APNS callback/ack success;
- a typed signed revoke/deregister and fresh status/read-back before the UI may
  claim current registration.

Additional review work remains for crash-window/ambiguous-pending
adjudication and the `F_FULLFSYNC` support matrix. Legacy split evidence files
cannot establish the new consent/vault authority and therefore fail closed
rather than being silently migrated. The local rollback boundary assumes the
OS Keychain item remains device-local and unavailable to a filesystem-only
journal rewriter; loss, deletion or mismatch of that item requires explicit
recovery and never recreates acceptance or registration authority.

The physical registration acceptance test may begin once the register-only
staging pilot is ready and the exact signed build pins it. Full callback
acceptance must wait for the callback server gates above. The two gates must be
reported separately: a verified register receipt is not APNS callback/ack
proof. This source candidate proves none of those live outcomes.
