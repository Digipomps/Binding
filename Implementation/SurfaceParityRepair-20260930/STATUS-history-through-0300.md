# HAVEN surface parity repair — 2026-09-30

## Authorization and acceptance
User: «Ja jeg legger meg nå - ha det fikset og implementert og testet til i mergen.»
This authorizes implementing and testing the preceding audit findings autonomously overnight. Existing web payload/rendering is the appearance reference. No separate image review or final user acceptance is claimed. User request takes precedence over skill instructions to stop at intermediate approval gates. No production security policy bypass is authorized.

## Current execution
Active root task is implementing; heartbeat fullf-r-haven-flateparitet continues every 30 minutes if needed. Do not create duplicate workspaces or interrupt active builds.
Three isolated worktrees at workspaces/{Binding,CellProtocol,CellScaffold}, branch codex/surface-parity-20260930 from fresh origin/main; baseline.json records SHAs. Shared user WIP is untouched.
Root: Binding native build and original-payload snapshot/coverage harness.
Subagent transport_repair: CellScaffold catalog500 repair and safe native route contract.
Subagent renderer_repair: CellProtocol renderer fixes and regressions.

## Verified starting facts
Audit 2026-09-29: nine HTTP fixtures available, bridgehead fixture404, Co-Pilot catalog500, styleRole disparity. Recheck against latest main. Binding origin/main is much newer than original dirty checkout.

## Next steps
1. Build latest main Binding in isolation, with explicitly recorded local CellProtocol override for integration only; preserve production pins.
2. Fix snapshot test to consume exact state and use real NSHostingView for native Lists.
3. Implement agent findings and test transport authorization/runtime paths.
4. Execute original fixture, action and visual tests; expand coverage from actual enum/catalog.
5. Integrate scoped tested code and preserve artifacts; no production deployment claimed without release verification.

## Completion
Not complete. General safe bridge is blocked on CellProtocol PR53 + AP5/AP7 and Binding adapter provenance (see TRANSPORT.md). No deployment or blanket visual parity claimed.

## Verified progress
- Fresh origin/main Binding build-for-testing succeeded with production CellProtocol pin; nine existing SkeletonRendererParityTests passed (baseline-renderer-tests-summary.json).
- Captured nine original staging fixtures at compact/wide sizes into corpus-staging-original. Original skeleton + root state preserved; no style stripping or materialization.
- Real NSHostingView baseline captured 18 images. Sixteen passed visible-string checks; List compact/wide failed (all12 item fields unavailable). native-before/ contains original failure evidence.
- Web baseline using the exact same frozen corpus and current standard light Porthole CSS passed18/18 content checks. web-original/ assets have hashes. This does not assert equality with conference dark theme.
- Binding host now preserves List row templates, Grid item visibility, per-overlay root/item state and stable row IDs. Top alignment fixed. Chat row style moves into native adapter so List is not flattened.
- Final integrated app run20/20 PASS,0skips,18/18 frozen original-payload scenarios with content assertions. integrated-native-final-summary.json and native-final/. Candidate-host corpus separately aliases only identical endpoints, fixing nested references. Web candidate18/18 also passes. Real appearance still differs in font/control/theme defaults.
- CellProtocol final166/166 PASS,0skips (including10new native regressions). RENDERER.md and renderer-skeleton-contract-tests.log. Source frozen; both agents finished their initial subtasks.
- CellScaffold catalog product code compiled. Strict-vault HTTP test proved4routes correct, but last test assertion decoded wire JSON as native ValueType.cellConfiguration and failed. Assertion fixed; final rerun BLOCKED by capacity preflight (55.6GiB -10GiB reserve, requires40GiB AND5%). No bypass, no cleanup, no active server build. Details TRANSPORT.md.
- Same-endpoint web host alias fix6/6Node tests PASS, existing navigation checkPASS. Broader web26/26PASS. Staging HTTP/action11/11PASS,0skips (remote-http-summary.json).
- Integration.xcworkspace uses explicit local CellProtocol override in separate derived data; production pins remain untouched.
- Active next work: root expands24canonical element fixtures plus Tree/ComponentSurface to native/web coverage. renderer_repair only prepares the2additional fixtures (no production edits).
- Current executable: task integrated DerivedData, `Build/Products/Debug/HAVEN.app` (unsigned test candidate). Compiler provenance confirms localCP81601a6 dirty; app8ce634f dirty. Not installed/released. All worktrees remain uncommitted pending final coverage/docs.
- Learning L-2026-09-30-visuell-skeleton-paritet-ma-testes-gjennom applied+synced to binding-skeleton-parity-testing. Catalog policy learning still to capture. Do not reread/rebuild completed evidence without new changes.

## Expanded type coverage (active)
- Canonical corpus now covers26enum types ×compact/wide=52scenarios;24 from existing CS matrix,2 Tree/ComponentSurface from current passing canonical tests. Inputs corpus-elements/, source extra-element-fixtures.json. Spacer/Image/Divider have raster-only evidence; not a text pass.
- First expanded native run46/52content passes: Reference2 genuine missing localroot support; table Visualization2 genuine emptyvalues; ZStack2 invalid OCR expectation because canonical textlayers intentionally overlap. ZStack expectation now common visible 'Layer', original payload unchanged.
- Web first50/52: List ignores static elements while native binds+appends them. transport_repair implementing webfix +Playwrightnegative-before/positive-after.
- Native renderer_repair implementing Reference+table regressions and false-positive reachability audit: Butterpop URL navigation '/butterpop' was incorrectly required to have keypath. Localcatalog audit1of20falsepositive; do not change the real button.
- CP53 readback remainsOPEN at3824cf8 with no reviewDecision. cp53-status.json. Main branch pins remain untouched.
- LearningL-2026-09-30-offentlig-statisk-katalog-discovery-ma-bruke applied+synced; all learning for this session captured so far.

## 02:26 continuation
- Element corpus exposed and fixed native Reference local-context rows, Visualization column object decoding and URL-only navigation reachability. CP171/171 passing; integrated source rebuilt before the next theme change.
- Web List static data now follows bound data.26/26 targeted web regressions pass;52/52 full type web snapshots pass.
- Canonical Image data URL was corrupt (CRC/zlib), tolerated as1x1white by Chromium. Original evidence retained. Corrected32x32four-color fixture passes10/10catalog tests. corpus-elements-final/ is reproduced by Scripts/create_skeleton_element_corpus.py; web-elements-verified/52/52passes real image samples + text.
- Root added actual native raster assertions and extra overlay tests for bound/static ordering, row-ID scoping and null shadowing. Pending next integration build/test.
- renderer_repair is implementing opt-in .skeletonHostTheme(.portholeLight) for default typography/Button/TextField/TextArea. Binding opts in only in light mode; dark native behavior remains adaptive. Current measured web styles in web-host-controls/*.json (18/18pass). This is not a conference/arbitrary CSS adapter.
- Transport server Swift rerun still blocked by ordinary disk guard (56.1GiB free before10GiB reserve, usable below5%); no cleanup or threshold bypass.
- Third learning L-2026-09-30-full-elementparitet-krever-gyldige-bildefixtures applied+synced.

## Committed candidate and visual follow-up
- All concrete fixes committed locally: Binding86fd4016, CP390a106, CS816be7ce. Candidate app rebuilt; provenance records clean Binding/CP HEADs. candidate-manifest.json. No installed app/pins/deploy changed.
- CP175/175PASS, Binding23/23PASS0skips. native-acceptance70/70 captures:64text-asserted,2four-color image,4Spacer/Divider raster-only. Same web corpus70/70checks. PARITY_REVIEW.html generated from actual captures.
- Server capacity naturally recovered; ordinary gatepassed56.8GiBfree,46.8GiBafterreserve5%. Final corrected CS catalog suite4/4PASS on committed816be7ce withpublishedCPpin, no bypass. TRANSPORT.md updated.
- Actual visual inspection (not OCR) found light-host List default8pt insets and intrinsic Text badges differ substantially from web block-width badges. renderer_repair nowowns narrow opt-in light-theme follow-up; prior175/23evidence retained as before-images, will require updatedCPbuild/integration captures.
- transport_repair read-only audits other actual compactcase images (Grid/Table/Tabs/controls/navigation/uploads/Tree/ComponentSurface) for clipping and majorstyle differences. No other CS code changes planned.
- CP53 stillOPENsamehead at deliveryreadback(cp53-delivery-status.json). Generalbridge AP5/AP7/N35/N05 remains separatelyblocked; native HTTPfixtures do notcloseit.
- Fourth learning aboutnativehit-target/field-editor testing applied+synced.

## Active second repair pass (after committed first candidate)
- First candidate app is built from clean localcommits and passed allinitialgates, but actualvisualinspection found realPickerinitialblank+duplicate-label and List/Textwidth issues. renderer_repair froze these nextchanges;21/21native tests pass,4red-before regressions. Pendingjointfullsuite.
- Root added Binding Tree/ComponentSurface modifier extraction/removal (previouslysilentlymissingtypes), visibility/modalcontracttest, and boundhoststate to userInfoValue ?? viewModel.skeletonRootData. Snapshot70 will nowexercise observableVMrootdelivery. Rootfileeditsnotcommittedyet.
- Rootstronger Pickeroracle nowexpects Normal visibly and actualwebselectedoption, notonlyPrioritylabel. corpus-elements-visual contains unchangedpayloads+newexpectations/capabilityboundaryfile. web-elements-visual isrunning session60679.
- transport_repair implements a source-scoped LOCAL ComponentSurfaceactionadapter withnormalResolver/activerequester and separate mountmetadata. CPfiles: newSkeletonMountedActionAdapter.swift +CellComponentSurfaceView.swift ONLY, nooverlapwithrendereragent. Bindingfiles: newBindingSkeletonMountedActionSupport.swift +newtests ONLY. Rootalreadywired expectedAPI .environment(\.skeletonMountedActionHandler, BindingSkeletonMountedActionSupport.handler(viewModel: viewModel)).
- Mountadapter must preserve nil→GET, explicitnull→SET,payloadunchanged, mountmetadataneverauthority; remoteendpoints rejectedinthislocaladapter untilgeneralbridgeworkcomplete. Neverinstallgeneric .skeletonNativeActionHandler globally because it wouldhijackurlnavigation.
- Needagentfreeze thenCPfullSkeletonsuite, newintegratedbuild+allBindingparity/overlay/catalog/adaptertests+70snapshots, refreshgallery/report/commits/provenance. Preserve first70images asevidence (native-acceptance); use newoutputfornext.
