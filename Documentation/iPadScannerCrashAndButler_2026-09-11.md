# iPad scanner crash and Butler language follow-up — 2026-09-11

## Current status at 17:54 Oslo

The combined signed app is **installed on both iPhone and iPad**, verified by successful CoreDevice installation receipts and app inventories. Scanner's crash fix was already tested physically on the iPad (two navigation/sharing cycles). The new Butler UI acceptance test is **blocked by device lock**, not passed. Its build/sign succeeded; Xcode stopped before launching the runner, then the waiting test was interrupted explicitly so it will not launch unexpectedly on a later unlock. The Mac was also locked and CUA could not inspect the final build.

Butler local contracts: **6 XCTest tests + 2 updated skeleton contracts passed** in `ButlerLanguageTests8.xcresult` / `butler-test8.log`. The 6 include an opt-in live test with five Norwegian prompts, plus context, action-boundary, draft-content and provider-selection checks. **51 existing chat tests and 5 Chronicle tests passed** in run 7. The earlier failures in run 7 were the new punctuation guard (fixed) and the embedded chat component still having the old send action (fixed in `ComponentInsertionRecipe.swift`). The large test-only recursive skeleton inspection also overflowed its 544-KiB worker stack; that UI contract now runs on MainActor and passes. This is separate from the production scanner crash.

Known limits remain: Apple responses are basic and the request for two sentences still yielded one. Earlier translation probes were inaccurate. The app now conservatively keeps explicit writing/explanation requests in text mode, even when the model would mistake their subject for an action. This guard supplements model interpretation; it is not a claim of general intent reliability. Native todo/reminder/project/meeting/work-item actions still retain drafts, not executed service tasks. A stronger-model route and real execution backends remain outstanding. Three user questions remain unanswered: a concrete failing task example; preferred stronger-model route (own HAVEN server / explicitly chosen cloud / on-device only); and unlocking iPad/iPhone for final UI verification. Do not configure or contact a new external model provider without resolving the route.

Install artifacts under `/tmp/haven-nearby-20260911/`:

- `iphone-final-install.json`, `iphone-final-app.json` — CoreDevice `2A446771-99B8-5EB2-B384-07A156FB3107`, bundle installation `17331E8B-35B0-407D-831A-2A4CC43B3AE4`.
- `ipad-final-install.json`, `ipad-final-app.json` — CoreDevice `90C8A134-0A1A-5026-8C21-0DA21DC67AA8`, bundle installation `F4AB1EDB-7E94-4538-92B8-DE2B06DB6563`.
- Both `org.digipomps.haven`, version 1.0/build 1. Signed app `/tmp/BindingNearby20260910/Build/Products/Debug-iphoneos/HAVEN.app`; `codesign --verify --deep --strict` succeeded. SHA-256 of `HAVEN.debug.dylib`: `6c726f8b1d6a7b16654b9c535bf3aa99e32da1e96a177d1be7f614a9b10b6157`.
- `ipad-butler-ui1.log` / `iPadButlerScannerUI1.xcresult` — UI attempt blocked before runner launch, then `TEST INTERRUPTED` (exit 73) after SIGINT to the owned xcodebuild process. This is not a test pass or an app crash.

Next continuation: if user unlocks, rerun `HAVEN-Scanner-UI` on the iPad using the command below but a new result path, inspect its screenshots/AX artifacts, and correct any actual user-path failures. Resume stronger model/real action integration according to the user's response; do not treat source fixes or injected tests as completion of the requested overall Butler quality lift. No background test is left waiting. No commit/push or device data reset was performed. The historical work notes below describe the investigation.

## User request

After the requested installation on iPhone/iPad, the user reported HAVEN crashes on iPad when Entity Scanner is selected. They also reported that Butler Chat lacks the expected improvement in understanding/executing tasks, understanding text and formulating answers. The Butler complaint is part of this ongoing task, not a replacement for the scanner fix.

## Confirmed scanner cause and fix

Two device crash reports, `HAVEN-2026-09-11-170129.ips` and `HAVEN-2026-09-11-170213.ips`, both show `EXC_BAD_ACCESS`, `Thread stack size exceeded`, and `___chkstk_darwin` at entry to `ConfigurationCatalogCell.entityScannerToolConfiguration`. The calling path is workbench configuration → personal co-pilot configuration → destination configuration → SwiftUI detail container. This occurs before the scanner transport starts. Reports were copied from the iPad's systemCrashLogs domain to `/tmp/haven-nearby-20260911/ipad-HAVEN-*.ips`.

`Cells/ConfigurationCatalogCell.swift` now separates `entityScannerDiagnosticConfiguration` into a non-inlined function. The main factory's early-return radar branch no longer shares the huge diagnostic workbench's stack frame. No skeleton structure, actions, grants or radio behavior changed in this fix.

`NearbyScannerConfigurationStackTests` exercises both catalog and sidebar factories 20 times on a 512-KiB thread. The focused macOS run passed **15 tests**: the constrained-stack test, 13 existing scanner tests, and the Swift Testing configuration contract. Artifacts: `ScannerStackTests2.xcresult`, `stack-test2.log` under `/tmp/haven-nearby-20260911/`.

Actual iPad navigation **passed** with the fix installed: selected Entity Scanner through Sidebar, asserted Start/search/sharing controls, opened and closed the sharing editor, and repeated the sequence. It did not start radio, publish data or enter credentials. Result: `/tmp/haven-nearby-20260911/iPadScannerUI4.xcresult`; log `ipad-ui4.log`; screenshot `ipad-ui4-artifacts/F53E450F-8A28-4D4A-B128-0868EB8112D5.png`.

For repeatability, `HAVEN-Scanner-UI.xctestplan` was added to the HAVEN scheme and `NearbyScannerNavigationUITests` added. Existing UI test click calls now select tap on iOS; the NSHostingView render test is explicitly macOS-only. The main plan still includes unrelated Mac-specific audit tests that fail to compile on iOS, so the bounded UI plan selects only the UI target. Earlier UI attempts: missing CellBase test import (fixed); Mac-only rendering test build failure (guarded); unrelated renderReport audit compile failure (isolated with UI plan); wrong Flater-menu selector (fixed using observed Sidebar hierarchy).

Successful physical-device command:

```sh
xcodebuild -workspace Binding.xcworkspace -scheme HAVEN -testPlan HAVEN-Scanner-UI \
  -destination 'platform=iOS,id=00008103-00197991227B001E' \
  -derivedDataPath /tmp/BindingNearby20260910 \
  -disableAutomaticPackageResolution -skipPackageUpdates -allowProvisioningUpdates \
  COMPILER_INDEX_STORE_ENABLE=NO -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath /tmp/haven-nearby-20260911/iPadScannerUI4.xcresult test
```

## Butler findings and work in progress

Source-confirmed: `BindingPersonalChatHubCell.analyzeDraft` used only deterministic classification, then optional external `RemoteLLM` answer formulation on submit. `BindingRemoteLLMCell` gets its required key from `BINDING_REMOTE_LLM_API_KEY`, which is launch-environment configuration rather than durable app configuration. No such variables were supplied by our device installation/launch. The existing Apple provider's classifier was not called by the normal submit path; LocalLLM's generate action also just returned deterministic classification. Active conversation was not passed to answer generation. The UI limited answer text to six lines. An unconfigured external model returned nil, hiding the reason behind ordinary-looking rules text.

Apple's local model was probed on this Mac: availability `available`, Norwegian `supportsLocale(nb_NO) == true`. [Apple's SystemLanguageModel documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) and the installed SDK interface confirm availability checking, locale support, structured generation and response-token options. This probe does not prove the model is enabled on the iPad or iPhone.

Further confirmed causes: the visible ↑ button called `ui.openSuggestedHelper`, which stages a synchronous deterministic suggestion. Only Enter called `prompt.submit`. Thus adding a language model to submit alone would miss the main user path. The button now submits; a separate “Åpne forslag” button opens the proposed helper. Existing skeleton contracts were updated for this intentional correction.

The native task actions `todo.create`, `reminder.create`, `project.create`, `meeting.schedule`, `idea.capture`, `workItem.capture`, and agent-review actions call `createWorkbenchModule`. They do not call the corresponding execution service. Previously they also discarded the filled draft and stored only a generic helper title. They now retain the actual draft/title and say `requestedActionExecuted=false`, with “Utkast · ikke utført” and honest button labels. Reminder drafts explicitly do not send notifications. This is not an implementation of scheduling or a completed task backend. Poll and invite have their own paths, unchanged here.

In-progress `Binding/ButlerLanguageSupport.swift` separates structured interpretation (request, intent, title) from free-form answer generation, using bounded recent submitted messages from the active thread. Helpers map to canonical existing routes with approval; unknown routes, nonfinite confidence and deterministic negation do not open access. Model output never executes a tool. Task proposal text is application-authored so the model cannot claim successful execution. The title is used in the helper and the original prompt is retained as notes. `dateText` remains empty unless supplied by the internal test seam; the original time phrase remains in the notes/title and no time is scheduled. A fixed 0.8 suggestion weight is a proposal threshold, not calibrated model confidence.

The chat uses Apple when registered and no remote provider is configured. Descriptor normalization maps `ready` to `available_in_cell_scope`; the new availability guard recognizes both so explicit remote configuration keeps precedence. Remote generation still uses its existing formulation-only route. A test-only responder property is internal, not exposed on the wire. Generated answers carry provider provenance, failures show limited-mode text, and answer truncation at six lines was removed. Full-content Chronicle retention now selects the actual submitted answer rather than the deterministic suggestion explanation; the owner's retention policy is unchanged. Draft-analysis records are tagged `submittedTurn=false` and excluded from model history.

Live-model evidence: several small Apple-only tests have **failed** language/intent quality, including treating a request to write a meeting-room message as scheduling and an instruction to compose a reminder as setting one. Adding output fields sometimes changed classification. Free-form translation probes also hallucinated extra content or omitted parts of the translation. A separate three-field classification probe (`model-probe1.log`) correctly classified seven synthetic examples. The current code adopts this simpler separation. This is not evidence that general Butler quality is solved. An optional question is pending asking whether stronger inference should use the user's HAVEN server, an explicitly chosen cloud provider, or only on-device models. No server/cloud setting or new external data transmission has been made.

New `ButlerLanguageSupportTests` cover active-thread context, route/negation guards, normalized remote-provider precedence, no model invocation on draft analysis, submission, conversation continuity, populated drafts and truthful confirmation results. The opt-in live test asks five synthetic Norwegian prompts (explanation, todo, meeting-room writing, reminder writing, reminder action). Previous existing `ChatWorkbenchParityTests`: **51 passed** in runs 1, 2 and 5; live quality tests failed as documented. Run 4 failed compilation due to a wrong SkeletonText initializer, corrected. Run 6 still misclassified the meeting-room writing request, leading to the explicit writing guard; old hint assertions were updated for the corrected send/open split. Environment flags `HAVEN_TEST_LIVE_BUTLER=1` and `TEST_RUNNER_HAVEN_TEST_LIVE_BUTLER=1` enable the local-only live test. Final results are at the top of this note.

New `BindingUITests/ButlerConversationUITests.swift` uses the actual iPad Sidebar, composer and ↑ button, checks a generated writing answer, then opens a populated task draft without confirming. It is included alongside the scanner in `HAVEN-Scanner-UI.xctestplan`. The test build succeeds but the new Butler UI path has not yet executed because the iPad is locked. CUA selected the existing Mac app and observed the old ↑ behavior from source; it could not inspect the final build after the Mac locked. Both devices now have the combined app, as recorded above.
