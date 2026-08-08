# Binding DeviceIngress v3 register candidate

Status: source-integrated review candidate in Binding PR #9. It is not wired
to an operational DeviceIngress service, does not send APNS, and is not an
operational device-registration release. The current App Store catalog policy
keeps notification enrollment disabled, and the challenge-issuer setting is
deliberately empty so an accidentally opened registration path fails before
network access.

## Exact source boundary

- Original PR #9 head: `16af4e85e21c15d5f0fa430fd5c045d85f16312b`
- Binding main integrated by this candidate:
  `2d326349643e4b8448a00bae4ce16087209a2586`
- CellProtocol exact revision: `1632ed65d5e4aaf663b26cee1cdddfdcdd5e4412`
- CellScaffold main observed during integration:
  `57b500455a2df668b29a10445f476e07d7aa99dc`
- Candidate state: PR #9 integration pending independent review. The exact
  final Git revision is supplied by Git and the generated build provenance,
  rather than a self-referential hard-coded source constant.

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
composition remains inert: the App Store catalog gate disables enrollment and
the empty issuer descriptor makes runtime configuration unavailable before
network access. Resolve and submit also throw before network access; unsigned
push payloads are not staged as a fallback. No owner identity, Agreement,
revocation state, audience, issuer or transport framing is auto-provisioned or
inferred.

## Remaining operational gates

Neither current CellScaffold main nor the earlier server prototype branches
establish a deployed challenge issuer, durable admission/replay, or operational
authority for this candidate. Binding remains unavailable until a reviewed
composition root supplies all of the following:

- persistent challenge issuer and client-pinned issuer descriptor;
- owner-pinned target Cell and exact signed Contract/Agreement;
- durable authority and revocation generations;
- atomic admission/replay ledger and same-Cell signed response persistence;
- a shared, reviewed transport package so Binding does not copy or guess HTTP
  framing;
- readiness that is red when any dependency is unavailable;
- an explicit custodian/owner provisioning flow for the physical device;
- a canonical signed status/read-back and typed signed revoke/deregister
  operation with durable local tombstone/retry reconciliation;
- reviewed iOS build/signing attestation, or an explicit decision that scoped
  build provenance is non-authoritative metadata only.

Additional review work remains for crash-window/ambiguous-pending
adjudication and the `F_FULLFSYNC` support matrix. Legacy split evidence files
cannot establish the new consent/vault authority and therefore fail closed
rather than being silently migrated. The local rollback boundary assumes the
OS Keychain item remains device-local and unavailable to a filesystem-only
journal rewriter; loss, deletion or mismatch of that item requires explicit
recovery and never recreates acceptance or registration authority.

Only after those gates are deployed in one coordinated window may the physical
iPad acceptance test begin. That later test must separately prove consented
registration, provider acceptance, visible device receipt, callback receipt,
restart continuity and exact build provenance. This candidate proves none of
those live outcomes.
