# NearbyScanner implementation — 2026-09-10

Senere funksjonsforslag: [felles samtalecelle, samtykket opptak og tillitspakke hos begge](NearbyConversationConsentAndTrust_2026-09-11.md). Dette er en vurdering, ikke implementert opptaksfunksjonalitet.

## Current status: Agreement Conditions and membership proof

Updated 2026-09-11: the disk-space build blocker is resolved. The complete focused run passed **34 tests**, including all eight Agreement proof tests. The new app opens the native radar and its Conditions editor. The reported authentication loop has also been corrected and tested; see [authentication regression record](NearbyScannerAuthenticationFix_2026-09-11.md) for causes, exact command, artifacts and native UI observations. Real two-device authorization and conference radio capacity remain unverified.

The subsequent user request replaces conference-specific scoping with flexible Agreement Conditions, including group membership and relations between EntityRepresentations. The implementation is saved in Binding and the sibling CellProtocol package; staged package files under `/tmp/haven-nearby-20260910/CellApple/EntityRadar/` match the installed sources. New files: `NearbyAccessAgreement.swift`, `NearbyAdvertisementProofSession.swift`, and `BindingTests/NearbyScannerAgreementProofTests.swift`.

An owner-selected Agreement domain, exact native typed Conditions and pinned authority DID protect the selected excerpt. A short issuer-signed, reader-bound Contract with the exact Conditions, domain and `nearby.advertisement.read` read grant is a maximum five-minute authorization lease. Its Agreement must be signed, owned by the issuer, and include issuer and reader as signatories. The issuer is responsible for evaluating those Conditions. All Conditions must be covered; a group label or an EntityRepresentation reference alone is not proof. No automatic graph traversal or credential-store reads occur.

Standalone TrustedIssuerEvaluationReceipts are deliberately rejected. Source review found that `TrustedIssuerCell.trustedIssuers.evaluateSigned` compares credential type/path with its policy, but does not compare the entire supplied `technicalRule` expression with that policy. Such a signed receipt must therefore not substitute for authorization of the exact native Agreement. This task does not change that shared evaluator. A regression creates a real signed receipt via the existing evaluator and asserts that the nearby importer rejects it.

The new encrypted v2 read protocol sends only a policy challenge until proof passes. A fresh nonce binds the holder signature to the request, both discovery session IDs, exact policy and evidence hash. Importing evidence does not send it: the reader explicitly submits it for the selected peer/policy. A fresh challenge is requested after the user has chosen evidence; the eight-second transport deadline does not impose an eight-second file-picker deadline. Source credentials are not copied into the advertisement or emitted as flow data. Local proof and publication state are memory-only. The existing public v1 channel rejects restricted publications; discovery keeps `ad=1` and adds `adp=2` for compatibility. These session bindings do not establish physical proximity or immunity to live radio relaying.

Native Agreement decoding currently permits lossy fallback. Policy validation therefore requires an exact typed-condition roundtrip and rejects unknown, malformed and demo/placeholder Condition types (`grant`, `httpRequest`, `engagement`). Other Conditions are handled through an authority-issued authorization lease, not locally pretended evaluations. The editor imports native Agreement/policy JSON and explicitly selected signed Contract JSON (one Contract or `{ "contracts": [...] }`). The policy contains `title`, `domain`, `verifierDID`, and the native `conditions` array; at most 16 Conditions / 32 KiB. The scope ID must equal the Agreement domain. The wire advertisement limit is now 128 KiB; evidence max 192 KiB / four Contracts; v2 envelopes max 256 KiB. Authority issuance and private graph membership lookup are not implemented by the scanner. A group/relation authority must evaluate its authoritative membership source and issue the short Contract; the synthetic test lookup path is not an existing graph API.

Current verification: Xcode compiled and linked the modified CellApple, Binding and BindingTests sources, and the focused test run succeeded on 2026-09-11. The eight Agreement tests passed. They cover exact policy preservation, malformed/unknown/demo Conditions, missing/expired/overlong/tampered evidence, wrong issuer/domain/grant/holder/group/relation, copied UUID with another key, nonce/session/policy/evidence signature binding, public-protocol fallback denial, owner-only proof submission, challenge display, and rejection of standalone evaluation receipts. The earlier static Explore audit reports 26 complete operation contracts, zero errors/warnings.

Current logs: `/tmp/haven-nearby-20260911/test2.log` and `/tmp/haven-nearby-20260911/ScannerAuthTests2.xcresult`. Historical logs: `agreement-build1.log` (package resolution failed for disk space), `agreement-typecheck.log` (successful), `agreement-test1.log` and `AgreementTests1.xcresult` (app link failed for disk space), and `agreement-explore.json`, all under `/tmp/haven-nearby-20260910/`. The sharing editor's Conditions mode was opened in the successful new build; no policy or personal data was published.

Remaining: verify actual two-device authorization, withdrawal and expiry. No immediate remote revocation check exists during the five-minute lease; received copies cannot be recalled. No real conference participant authority, automatic proof acquisition, multi-hop relay, RF capacity or many simultaneous ranging sessions are established. Disk availability had recovered to about 92 GiB before the 2026-09-11 build; this task performed no cleanup. No commit, push or deployment was performed. Sources were verified after saving and temporary EOF padding was removed.

## Earlier radar implementation and verification (before Conditions extension)

Implementation and verification record. The user requested implementation of the radar design and an explicitly chosen, scoped purpose/interest dictionary, with an optional picture when selecting a detection. Nearby sharing is implemented and locally verified; conference membership integration and real two-device radio verification remain outstanding.

## Implementation

- Entity Scanner uses a dedicated native Binding surface and the shared CellApple radar renderer. Its portable Skeleton configuration retains one radar plus start/stop controls, without the old stacked diagnostic cards. The native surface also omits the generic header/inspector cards that previously crowded the radar.
- Measured positions are grouped in screen space. A group opens a searchable, lazy list retaining every member. Search, a session-local follow filter, and the complete detection list support variable populations.
- No direction is invented for unmeasured detections. These remain available in the list. Old measurements stop being plotted; ongoing discovery retains the peer even without a connected session.
- An explicitly selected peer can supply a bounded public excerpt. Selection generation and transport request UUIDs keep a late reply from replacing another selection.
- The owner chooses a name, at most six purpose URI/label pairs and six interest URI/label pairs, and optionally a thumbnail. The editor re-encodes an image, removing source metadata. Nothing is copied automatically from a private profile or Perspective.
- Publications are memory-only, initially off, limited to eight hours, and withdrawn on Stop. A recipient's received copy cannot be recalled.

## Disclosure boundary

`NearbyAdvertisement` contains only `displayName`, `purposes`, `interests`, `scope`, optional `scopeID`, optional base64 `thumbnail`, and `expiresAt`. Unknown JSON fields are not re-emitted. Name/key/label sizes are bounded; image is JPEG or PNG, max 32 KiB and 256 × 256; encoded advertisement max 52,000 bytes.

The EntityScanner owner alone can read/change the local publication or trigger detail selection. The default agreement template does not gain publication grants. Selected remote excerpts are included in owner radar reads only, not relayed through delegated radar reads. Publication flow events contain an active flag, not the excerpt.

Discovery advertises only support for version 1 of the advertisement protocol. Clicking a supporting peer opens a short-lived encrypted MultipeerConnectivity session for a single public read. It does not install a Cell bridge, exchange identity/UWB tokens, or accept an ordinary bridge invitation. At most three excerpt sessions run at once; repeat requests are rate limited and stale sessions time out. Matching peer, protocol, request UUID, scope, size, and expiry are checked before display.

`nearby` means reachable through the local discovery transport, not a guaranteed physical radius. Details are self-declared, not verified identity claims.

`conference` is represented in the data contract but publication currently rejects it with `conferenceAuthorityUnavailable`. A matching conference name, context token, or interest overlap is not membership proof. The user has been asked which participant service should verify membership. This remains a dependency; there is no silent fallback from conference scope to public nearby sharing.

## Files

Binding: `Binding/NearbyScannerSurfaceView.swift`, the Entity Scanner branch in `Binding/ContentView.swift`, `Cells/ConfigurationCatalogCell.swift`, `BindingTests/NearbyScannerImplementationTests.swift`.

Sibling CellProtocol: `Sources/CellApple/EntityRadar/{NearbyAdvertisement,NearbyAdvertisementExchange,RadarClustering,RadarVisualizationView,RadarModels,EntityScannerCell,ScannerService}.swift`.

The shared worktrees contain unrelated existing changes. No commit, push, or deployment has been made. Package edits are installed by a hash-guarded script at `/tmp/haven-nearby-20260910/install.py`, which refuses to overwrite intervening edits.

## Verification status

- Initial package compile passed. First app compile found missing `Combine` import; corrected.
- Focused tests cover population sizes 0/1/10/100/1,000/5,000, non-fabricated coordinates, stale/discovered retention, publication bounds/expiry/roundtrip, owner denial, disabled conference publication, request nonce/peer/scope, rate limiting, and rendering at 360/736 points.
- Rendered visual inspection at 360 and 736 points completed using synthetic data. An initial ImageRenderer snapshot could not capture native controls; the test now renders an NSHostingView. Visual review found adjacent clusters with overlapping hit targets; merging these buckets fixed it, with a regression retaining all 5,000 members while requiring separated hit targets.
- Actual HAVEN app: opened Entity Scanner through the sidebar, opened the sharing editor, entered synthetic text, and verified that seven purpose lines produce a validation error before publishing. Closed the unsaved editor. Reopened the final build, selected Entity Scanner again, and visually verified that the generic header/inspector cards were absent and the full radar was visible in an expanded window. No live personal excerpt or radio test was performed.
- Testing found and fixed a ScannerService lifecycle crash: stopping an unstarted service from deinit must not initialize a lazy MCSession and install a weak delegate to the deinitializing service. Session storage is now explicit and synchronized; Stop only disconnects an existing session.
- Publication contract assertions compare the decoded advertisement dictionary, because the existing ValueType object equality can depend on encoded dictionary order. Owner denial is asserted as CellAuthorizationError.denied from the authorization boundary, not an intercept return string.
- The third test run waited in the real IdentityVault authentication path and was interrupted. The test now uses the repository's EphemeralIdentityVault with real signing keys and access bypass explicitly disabled.
- Final result: **TEST SUCCEEDED**, 13 NearbyScannerImplementationTests plus `BindingTests.entityScannerWorkbenchConfigurationsStayLocalToBinding()`, zero failures. This includes owner publication/withdrawal, all documented selection wrappers through the Cell action path, and the lifecycle crash regression. Final synthetic thumbnail rendering at both widths was inspected.
- Logs/artifacts: `/tmp/haven-nearby-20260910/`; isolated DerivedData: `/tmp/BindingNearby20260910`.
- Real two-device radio delivery, dense conference RF capacity, iOS hardware ranging, and verified conference membership are not established by synthetic rendering/unit tests.

## Reproduction and remaining work

Package sources are installed and match the staged files. Base commits are Binding `775fc93d` and CellProtocol `4096760`, with uncommitted working tree changes. Final run: `xcodebuild -workspace Binding.xcworkspace -scheme HAVEN -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/BindingNearby20260910 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO -only-testing:BindingTests/NearbyScannerImplementationTests '-only-testing:BindingTests/BindingTests/entityScannerWorkbenchConfigurationsStayLocalToBinding()' -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /tmp/haven-nearby-20260910/NearbyTests4.xcresult test`, log `test4.log`.

App used for native inspection: `/tmp/BindingNearby20260910/Build/Products/Debug/HAVEN.app`. Rendering artifacts: `/tmp/haven-nearby-20260910/render/radar-360.png` and `radar-736.png` (synthetic detections and a flat-color test thumbnail). Binding and CellProtocol diffs pass `git diff --check` for the affected files.

Next external requirements are an authoritative conference participant source and a two-device acceptance run covering publish → discover → select → receive excerpt/image → withdraw → new read unavailable. This local verification does not claim conference RF throughput, multi-hop relaying, or many simultaneous UWB position measurements.

Disk pressure interrupted a source edit with `OSError 28: No space left on device`; the rejected edit was later successfully applied after space became available. Free space fluctuated from roughly 100 MiB to 2 GiB. No cleanup was performed. Build index generation and verbose test diagnostics were disabled for later runs to limit additional disk usage.
