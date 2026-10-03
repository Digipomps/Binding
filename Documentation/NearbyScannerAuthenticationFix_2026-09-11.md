# Entity Scanner authentication regression — 2026-09-11

## Result and scope

The user reported repeated HAVEN authentication dialogs when opening Entity Scanner. The attached dialog showed `Authenticate to access your identities`, with `Use Passcode` incorrectly assigned to the cancellation button.

The local working-tree fix removes automatic authentication retries after an unsuccessful attempt, coalesces concurrent requests, and requires another explicit user action to retry. Background catalog/menu registration cannot initiate authentication. Entity Scanner keeps its existing local-runtime route. The vault still requires successful LocalAuthentication before protected initialization; no identity, resolver grant, keychain access control or signing requirement was bypassed.

Both Binding and the sibling CellProtocol package contain uncommitted changes. Unrelated existing changes were preserved. No commit, push, installation over `/Applications/HAVEN.app` or cleanup was performed. The subsequent user-requested iPhone/iPad installation is recorded below.

## Source findings and changes

- `Binding/ContentView.swift`: protected surface bootstrap chained multiple initialization calls and a 60-iteration readiness loop that retried bootstrap every tenth iteration. Cancellation left readiness false, allowing another prompt. Replaced with one shared attempt and a stopped-state message. Background menu refresh now returns when the authenticated runtime is unavailable.
- `Binding/BootstrapView.swift`: registration could implicitly initialize authentication. Registration now requires an already authenticated runtime, except for the pre-existing isolated verifier mode. Authentication is owned by the user-action bootstrap.
- `Binding/FullLibraryView.swift`: the background bootstrap task reset after failure, so subsequent refreshes could restart it. Initial load is guarded against repeated appearances. Search and automatic refresh respect a stopped attempt; the explicit `Oppdater` buttons can retry. Offline entries remain available.
- New `Binding/BindingAuthenticatedRuntimeAttempt.swift`: shares one in-flight attempt, remembers an unsuccessful result, and permits explicit retry. A successful result still depends on both authenticated readiness and registration. This object schedules initialization; it does not cache an authentication credential or grant access.
- `../CellProtocol/Sources/CellApple/IdentityVault.swift`: corrected `localizedCancelTitle` from `Use Passcode` to `Avbryt`. Selecting the actual password fallback (`LAError.userFallback`) now enters the existing device-owner authentication fallback. User/system/app cancellation and authentication failure stop the attempt.

Apple documents `localizedCancelTitle` as the cancellation button title, and distinguishes password fallback from cancellation: [localizedCancelTitle](https://developer.apple.com/documentation/localauthentication/lacontext/localizedcanceltitle), [userFallback](https://developer.apple.com/documentation/localauthentication/laerror-swift.struct/code/userfallback), [userCancel](https://developer.apple.com/documentation/localauthentication/laerror-swift.struct/code/usercancel). Those semantics explain the misleading button in the supplied screenshot.

## Automated verification

**34 tests passed, zero failures:** 7 new authentication tests, 5 runtime bootstrap tests, 8 Agreement proof tests, 13 scanner implementation tests, and 1 Swift Testing configuration test. This also completes the Agreement extension test run previously blocked by disk space.

Authentication regressions cover 60 calls after denial producing only one authentication attempt and no registration, a successful explicit retry, eight concurrent consumers sharing an attempt, cancellation before load, registration failure, password fallback versus cancellation, repeated library refresh/appearance, and local scanner versus protected remote surface classification. The tests use injected outcomes for prompt scheduling; they do not supply real user credentials or claim successful Touch ID verification.

Exact successful command, from the Binding repository:

```sh
xcodebuild -workspace Binding.xcworkspace -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/BindingNearby20260910 \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -only-testing:BindingTests/AuthenticationAttemptTests \
  -only-testing:BindingTests/NearbyScannerImplementationTests \
  -only-testing:BindingTests/NearbyScannerAgreementProofTests \
  -only-testing:BindingTests/BindingRuntimeBootstrapXCTest \
  '-only-testing:BindingTests/BindingTests/entityScannerWorkbenchConfigurationsStayLocalToBinding()' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath /tmp/haven-nearby-20260911/ScannerAuthTests2.xcresult test
```

Artifacts: `/tmp/haven-nearby-20260911/test2.log`, `/tmp/haven-nearby-20260911/ScannerAuthTests2.xcresult`. A first compile failed for a missing `CellBase` import in the new test file; corrected before this successful run. The CellApple vault change was staged under `/tmp/haven-nearby-20260911/IdentityVault.swift` and copied with a pre-edit SHA-256 guard to avoid overwriting another edit.

## Native user-path verification

Executed through native accessibility controls and visually inspected in the freshly built app at `/tmp/BindingNearby20260910/Build/Products/Debug/HAVEN.app`. `/tmp/binding-verifier-local-runtime.flag` was absent; the app ran with normal runtime behavior. The earlier running Xcode app under the user's DerivedData directory still showed the old stacked scanner interface, so it was not treated as the new build.

1. Opened Entity Scanner through the sidebar. The dedicated `I nærheten` radar opened without an authentication dialog. It showed Start, Stopp, Del detaljer, search, follow, an empty radar and `Alle treff (0)`; no repeated dialog appeared while the surface remained open.
2. Opened Del detaljer and selected `De som oppfyller vilkårene`. The editor displayed Agreement domain, proof-authority DID, Agreement import and the Conditions explanation. Closed the unsaved editor. No publication was sent.
3. Opened Bibliotek. It moved from `Klargjør ConfigurationCatalog…` to `Autentisering stoppet. Trykk Oppdater for å prøve igjen.`, with local fallback entries available. No authentication dialog was visible in the settled screenshot. The precise OS failure/cancellation cause was not established by this UI observation.
4. Entered `Entity Scanner` in the library search field. Results updated and the stopped status remained; no new authentication dialog appeared. Closed Bibliotek and returned to the native radar, still stopped with zero detections.

The test did not enter a password, approve Touch ID or physically click the OS cancellation button. Actual biometric success and password entry remain user/hardware checks. Radio discovery was not started; two-device proof delivery, dense-conference RF throughput, relay behavior and hardware ranging remain outside this regression's evidence. The new app was left on Entity Scanner for review.

## User-requested iPhone and iPad installation

On 2026-09-11, the user explicitly requested installation on both devices. Built the current workspace with `xcodebuild -workspace Binding.xcworkspace -scheme HAVEN -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/BindingNearby20260910 -disableAutomaticPackageResolution -skipPackageUpdates COMPILER_INDEX_STORE_ENABLE=NO build`. The build succeeded. The existing `HAVEN iOS Development 2026` profile includes both devices and expires 2027-08-05. `codesign --verify --deep --strict` succeeded with normal certificate-store access; the sandboxed check had reported `CSSMERR_TP_NOT_TRUSTED`.

Installed `/tmp/BindingNearby20260910/Build/Products/Debug-iphoneos/HAVEN.app` using `xcrun devicectl device install app` on the paired iPhone 17 Pro and iPad Pro 12.9-inch (5th generation). Both installation commands succeeded, and a subsequent bundle-specific app inventory confirmed `org.digipomps.haven`, display name HAVEN, version 1.0, build 1, on both. No uninstall or device-data reset was performed. The iPad's previous app with the same bundle ID displayed HAVEN Staging, build 3; it was replaced by this requested development build.

Launch verification was attempted once per device. Both devices were locked, and iOS refused launch with `BSErrorCodeDescription = Locked`. Installation is complete, but app startup and the scanner UI on physical iOS devices have not been verified in this run. The user must unlock the devices to open HAVEN.

Artifacts under `/tmp/haven-nearby-20260911/`: `ios-build.log`, `iphone-install.json`, `ipad-install.json`, `iphone-after.json`, `ipad-after.json`, `iphone-launch.json`, `ipad-launch.json`. The built executable SHA-256 is `f01125d745dfa603decdec44b2ea1b5dcfcf67780a94de04ac8b2b56d51b9ae2`; `HAVEN.debug.dylib` SHA-256 is `b0bf46a76c3a98d6a7c4349a012e537b6bcb6ce7ee98f97da218261c03c9ca48`. The unchanged marketing/build numbers alone do not distinguish this binary from earlier builds.
