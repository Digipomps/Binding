# Native recovery candidate — 2026-09-18

Integrates the preserved personal-entity/correspondence branches with current main and selected local work: bounded authentication, native Nearby scanner, Norwegian Butler analysis, durable relation state, and current CellProtocol main b5b7282b495e96a7899a189087592581426f4bfb. Both Xcode dependency lockfiles carry the same 35 pins.

Correctness fixes include list-row context for Relations visibility, submit-action reference remapping, and binding delayed Butler replies to their originating conversation without clearing a newer draft. Existing App Store surface policy, owner proofs and device ingress restrictions remain enforced.

## Persistence key migration

The prior startup scoped secret was derived entirely from a public tag. Durable startup vaults now initialize one random 64-byte root in the existing Keychain service using atomic insert-if-absent. Per-tag HMAC derivation is stable across launches and requested lengths. Ephemeral vaults keep an independent root only in memory.

Before returning the persistence seed, the application validates existing CELLENC1 typed cells and EntityAnchor side files, prepares copies encrypted with the new key, and retains the exact old ciphertext inside authenticated backups protected by the new key. Source files are changed only after all candidates pass authentication and each source still matches its preflight digest. Mixed generations resume after interruption. Unknown keys, corruption, linked files and unavailable Keychain storage stop migration; original storage is not silently reset.

Backups are under `.startup-secret-migration-v1` within the existing document root. Retain this directory and the Keychain root together. An old binary cannot read the migrated files; a downgrade requires restoring the preserved originals using the migration backup decoder and the new seed before reopening the older binary. No production/user data or actual user Keychain was read or migrated during test development.

## Verification

On native arm64 macOS, the full Binding unit target passed: **678 passed, 0 failed, 24 skipped** (702 total), using locked dependencies and normal Xcode script sandboxing. This includes nine synthetic secret/migration tests, eight startup identity tests, and the delayed-thread regression. Migration fixtures are produced and decoded with the actual CellProtocol crypto, covering typed cells and both EntityAnchor side-file bindings, interrupted resume, corrupt input, symlink/hardlink rejection and Keychain read/write failure.

A separate opt-in live Apple FoundationModels run passed all six Butler language tests before the final combined suite. Normal full-suite execution skips live provider availability checks. Nearby radio pairing with another physical device, committed XCUITest navigation fixtures, signed distribution and an installed production native app were not exercised. Local build/test success is not native distribution acceptance.
