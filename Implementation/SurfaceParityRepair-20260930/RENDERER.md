# Native renderer repair — 2026-09-30

Status: implemented and verified in the isolated worktree; the latest broad Skeleton run passed **188 tests, 0 failures, 0 skips**, including **54 native renderer/layout tests**, on 2026-09-30 at03:17:09 Europe/Oslo. Latest log: `renderer-skeleton-contract-tests-188.log`. This includes all follow-ups after `390a106` and the transport agent's frozen ComponentSurface adapter sources. It supersedes the intermediate164/166/171/175/182-test runs documented below. No visual acceptance by Kjetil is implied. No deployment or app installation has been performed by this subtask.

## Scope and source baseline

Worktree: `workspaces/CellProtocol`, based on `origin/main` `81601a6`.

Native source: `Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift`, `SkeletonNativeStyle.swift`, `SkeletonNativeRuntime.swift`, `CellListView.swift`, and `Skeleton/FlowLayout.swift`.

Web reference: sibling `workspaces/CellScaffold/public/js/skeleton-runtime.js`, `public/css/porthole-webo.css`, `public/css/conference-mvp.css`, and `Sources/App/Cells/PersonalCopilot/PersonalCopilotConfigurationFactory.swift`.

The September 15 candidate was inspected at `../ParityNight-20260914/CellProtocol`. It uses the earlier SwiftUI stack implementation. Its alignment fix is relevant evidence, but its full patch was not applied: today's renderer has `SkeletonLinearLayout`, inherited typography, layout variants, and a separate native styling layer.

## Repairs

- `HStack` and `VStack` position their content using the effective `hAlignment` instead of wrapping every stack in a leading-aligned frame.
- Unbounded `List` uses its content height. A list with `height` or `maxHeightInfinity` keeps its own vertical scroll viewport; `maxHeight` caps natural height and switches to scrolling when the content exceeds the cap. A page list therefore no longer consumes the remaining window height and pushes the following action away. Rows already present in `SkeletonRenderDataContext` are rendered directly and retain their original item/root data.
- Wrapped list rows no longer add an unconditional eight-point expanding spacer. `FlowLayout` constrains an individual item only when its ideal width exceeds the viewport, keeping small items intrinsic and allowing long labels to wrap.
- The native adapter handles `chat-active-tool-chip` and `chat-active-tool-chips`: compact pill background/border/insets, small child text/buttons, six-point flow spacing, bounded chip strip, and zero space for an empty strip. This is a native presentation adapter; the original metadata is retained. Unknown roles are untouched. A separate `chat-prompt-log` row adapter is documented below.
- Native `Section` gets the light Porthole base decoration: white background, one-point pale border, twelve-point radius/padding, separated header/content/footer, and header/footer rules. Explicit background, border, padding, dimensions and other portable modifiers win over these defaults.

## Appearance boundary

The published `/skeleton-parity/{text,list,grid,form}` routes render `conference_mvp`, which uses its own dark gradient, serif section headings and different HStack CSS. `porthole-webo.css` supplies a different light base theme. These are different web host themes even for an identical CellConfiguration. The native base adapter does **not** claim to reproduce conference CSS or arbitrary CSS themes.

The four fixtures remain useful for original-payload contract and native layout checks. Any same-appearance comparison must name the host theme, viewport, color scheme and state. No styleRole/styleClasses normalization is used in the new tests. `SkeletonStyleParity.agreedRoles` has not been broadened to claim universal agreement.

## Verification

`SkeletonNativeSurfaceParityRepairTests` uses `NSHostingView` in a temporary off-screen `NSWindow`, lets SwiftUI tasks execute, and captures actual AppKit-backed PNGs. It exercises stack alignment, unbounded/context-bound lists, explicit scroll viewports, oversized flow items, the two original chip roles, empty chip lists, explicit style precedence and section decoration. Pixel assertions test observable layout/paint instead of only reimplementing style decisions.

Targeted run:

```sh
HAVEN_RENDERER_ARTIFACT_DIR="$REPAIR/artifacts/renderer" \
CLANG_MODULE_CACHE_PATH=/private/tmp/HAVEN-RendererRepair-20260930-module-cache \
swift test \
  --scratch-path /private/tmp/HAVEN-RendererRepair-20260930-build \
  --cache-path /private/tmp/HAVEN-RendererRepair-20260930-cache \
  --config-path /private/tmp/HAVEN-RendererRepair-20260930-config \
  --security-path /private/tmp/HAVEN-RendererRepair-20260930-security \
  --disable-sandbox --jobs 2 \
  --filter 'SkeletonNativeSurfaceParityRepairTests|SkeletonNativeLayoutRoundBTests|SkeletonNativeRendererTests'
```

`$REPAIR` denotes this repair directory. Log: `renderer-tests.log` (exit 0). Final result:

| Suite | Tests | Result |
| --- | ---: | --- |
| SkeletonNativeLayoutRoundBTests | 3 | Pass |
| SkeletonNativeRendererTests | 21 | Pass |
| SkeletonNativeSurfaceParityRepairTests | 8 | Pass |
| Total | 32 | No failures |

The first run's single failure was an incorrectly authored new test fixture: `flowElementSkeleton` requires the canonical `{ "VStack": ... }` wrapper. The fixture was corrected; production parser behavior was not changed. The first-run log is retained as `renderer-tests-first.log` and the intermediate 31-test pass as `renderer-tests-31-pass.log`.

Nine actual NSHostingView PNGs are retained in `artifacts/renderer/`: `stack-center.png`, `stack-trailing.png`, `list-content-height.png`, `list-bounded-height.png`, `list-max-height-short.png`, `flow-long-item.png`, `original-chip-roles.png`, `empty-chip-list.png`, and `section-explicit-style.png`. Images for the chip strip, list, centered stack, flow wrapping and explicit Section style were visually inspected. The list image was also OCR-checked for both data-bound row labels and absence of the unavailable message.

The chip test mirrors Co-Pilot factory styling/actions but substitutes two local items for repeatable layout. It is not a screenshot of a live Co-Pilot session. The published original fixture integration remains the parent task's evidence.

## Remaining limitations

- Arbitrary CSS-only roles, theme overrides, browser gradients, browser form controls and global typography are not exported in the Skeleton payload and are not automatically interpreted by native SwiftUI.
- The two chip roles and native chat-prompt row adapter are not a statement that the other web roles have native parity.
- This suite is a renderer regression suite. Integration into Binding, remote loading, real action dispatch and complete original-fixture coverage are owned by the parent integration task.
- A passing automated rendering test is not personal visual approval from Kjetil.

## Proposed minimum standard host contract (not implemented here)

A shared payload cannot reproduce a web host's implicit CSS when the native host has different implicit defaults. The smallest reviewable contract is a named **standard light Skeleton host**, implemented as matching renderer defaults rather than rewriting downloaded configurations:

| Concern | Proposed common default | Current repair / outstanding work |
| --- | --- | --- |
| Surface | White, top/leading origin, same logical viewport and explicit content padding; compare CSS px to SwiftUI pt at a named output scale | Parent fixes Binding wrapper alignment; PNG pixel scale must be stated |
| Typography | System sans-serif, 16 logical units, regular, foreground `#172033`; explicit node typography and inherited portable typography win | Proposed host font/color; currently macOS defaults can be 13 pt while browser defaults are 16 px |
| Section | Padding/radius 12; border 1 `#e2e8f0`; white; header/footer separation 10; header bottom/footer top padding 6 and one-point separator; content block spacing 0 | Implemented in native base Section; conference theme intentionally remains separate |
| Text in column/block contexts | Fill available cross-axis width with leading content; Text in row/flow contexts remains intrinsic; explicit width/alignment wins | Still outstanding: native intrinsic badges versus web block-width badges need a declared parent-axis default, not fixture rewriting |
| Button | Plain control with one shared solid fill, foreground, border, radius, font weight and insets; for example background `#173140`, foreground `#d9fbff`, border 1 `#2d566b`, radius10, insets8/12, weight600 | Still outstanding: browser default gradient/metrics versus native intrinsic label. Choose the solid base explicitly in both host themes rather than claiming the current gradient already matches |
| Inputs | Plain control at inherited typography plus shared border/insets/minimum height; use explicit existing `controlStyle` and typography contracts where configured | Browser/native focus ring, caret, selection and platform control chrome still differ; behavior must be verified separately |

Do not apply that contract globally to `conference_mvp`, which has an intentional different theme. A conference appearance adapter would be a separately named implementation and comparison. Acceptance for the standard host must rerender the same original JSON and state on both renderers at compact and wide widths, measure bounds/visibility/controls, then record remaining glyph and platform differences; no unshared role may be silently stripped to pass.

## Broader existing Skeleton contract run

The already built test bundle was then run with the same scratch/cache/config/security directories and `--jobs 2 --disable-sandbox`, adding `--skip-build` and replacing the filter with exactly `--filter 'Skeleton.*Tests'`. No dependency pins or production sources changed between these runs.

Result: **164 tests passed, 0 failures, 0 skipped**, twelve suites, at 2026-09-30 01:50:29 Europe/Oslo. Log: `renderer-skeleton-contract-tests.log` (exit 0).

| Suite | Tests |
| --- | ---: |
| SkeletonActionButtonExecutionTests | 6 |
| SkeletonButtonResolutionTests | 2 |
| SkeletonFormatRoundBTests | 4 |
| SkeletonLocalizationTests | 9 |
| SkeletonModifiersStorageTests | 6 |
| SkeletonNativeLayoutRoundBTests | 3 |
| SkeletonNativeRendererTests | 21 |
| SkeletonNativeSurfaceParityRepairTests | 8 |
| SkeletonReachabilityAuditTests | 23 |
| SkeletonStyleParityTests | 7 |
| SkeletonTests | 71 |
| SkeletonTextInputPresentationTests | 4 |

This covers existing typed encode/decode, canonical wrappers and supported legacy shapes, modifier storage and precedence, visibility, component/tree contracts, list selection payloads, source-aware actions and row resolution. It does **not** turn the fixture corpus into evidence that all 26 element cases have been rendered and exercised in both hosts. Keep corpus element coverage separate from these passing contract suites.

Learning to retain in the shared parity workflow: a screenshot comparison must name the web host theme as well as original configuration/state and logical viewport. The published fixture routes and the Porthole shell apply materially different default themes. NSHostingView screenshots are required when AppKit-backed controls must be visible in evidence.


## Final chat row-context preservation

During the parent Binding integration, the production `BindingSkeletonPresentationSupport.materializedList` path was found to flatten ordinary lists into VStacks while retaining relative Text keypaths and discarding the row data context. The parent owns that Binding repair. To keep the former native chat appearance when Binding preserves the original List, this CellProtocol change adds a `chat-prompt-log` adapter **at the real row renderer**:

- `CellListView` passes the unchanged item data through `SkeletonRenderDataContext.row` as before. It adapts a local copy of the row's modifiers instead of replacing the List or turning fields into static text.
- `rowStyleClasses` user/assistant classes select the native bubble variant, falling back to the item's `role`. The former Binding defaults are retained: user `#E8F1FF`/`#9FC1F8` and trailing alignment; assistant `#F4F5F7`/`#D7DCE2` and leading alignment; padding12, radius14, border1. Every explicitly provided modifier, including zero padding/border and custom role/classes, wins.
- Chat list wrapper insets and the trailing spacer no longer add dimensions around those native bubbles.

This preserves the prior **native** chat theme. Current web chat CSS uses different white bubbles and an assistant leading stripe; this adapter does not claim to reproduce that theme.

Final verification rebuilt the changed native sources in the same isolated scratch/cache with `--jobs 2`, then ran the same exact `--filter 'Skeleton.*Tests'`: **166 tests passed, 0 failures, 0 skips** at 01:56:52.989 Europe/Oslo. No dependency pins changed. `renderer-skeleton-contract-tests.log` is the final log; the preceding 164-test log is retained as `renderer-skeleton-contract-tests-164-pass.log`.

The new native suite now has **10 tests**, and native/layout total is **34** (3 + 21 + 10). `testChatPromptRowsKeepSpeakerBodyAndRootBindingsWithNativeBubbleAppearance` OCR-verifies First/Second speaker/body plus Shared root, rejects unavailable text, and checks both native bubble fills. `testChatRowDefaultsNeverReplaceExplicitRowModifiers` verifies override precedence. `artifacts/renderer/chat-row-context.png` was visually inspected and shows both rows with the correct text and root fallback. Ten native PNGs are now retained.

## Supplemental Tree and ComponentSurface corpus inputs

`extra-element-fixtures.json` is an array of two `{id, case, fixture, root, expectedText}` entries for the parent's 26-case image corpus. It does not change any production source or fetched public fixture.

- `tree-confirmed-visible-nodes`: the exact semantic Tree variant assembled in `CellScaffold/playwright/skeleton-element-catalog.spec.js`, test “WP-R2 Tree: every key, cell confirmation, disclosure isolation, ID focus and ARIA” (lines174–180 at the inspected revision). It takes the canonical Tree specification, uses its established single label row and `Tasks` accessibility label, and supplies the same Root/Other node records and selected ID `z`. This is the semantic test variant, explicitly distinct from the raw all-modifier stress fixture with rotated text.
- `component-surface-two-local-mounts`: the unmodified `skeleton` and `initialRoot` from `CellProtocol/fixtures/skeleton-wp-r1/component-mount-two-instances.json`, also used by the green native mount/action contract tests and the existing web element-catalog mount test. Expected text is Program, Sesjoner, Fra verten and Oppdater. Both mount instances resolve directly from local root data; the `cell:///ProgramFixture` endpoint is source identity metadata. A captured image proves local mount/render behavior only, and does not certify live source action dispatch.

The corresponding source oracle files in CellProtocol and CellScaffold were verified byte-identical. Generated artifact SHA256: `ddfbb47315124c9c5df62985ebf34fab306d9dc7f4e1d764e15636fcc4b879f1`. Parent owns the ensuing cross-renderer captures and their final pass/fail evidence.

## Final 26-case corpus defects: Reference, table and navigation audit

The parent's original-payload element corpus exposed two further native rendering defects and one structural audit false positive. These are fixed only in the isolated CellProtocol worktree:

- `CellReferenceView` previously ignored `keypath` and read only `PortholeViewModel.flowElements`. It now resolves local `SkeletonRenderDataContext` item/root values, renders each local list item with the unchanged root and its own row context, and keeps the existing topic/type-filtered flow fallback only when the local value is absent. An explicitly empty list, null or non-list value is authoritative and does not expose stale flow rows. Flow-template children also explicitly retain root/item context. No network fetch or authorization behavior was added. The native flow view's existing topic label and scroll viewport remain; this is not a claim of identical web Reference chrome.
- `visualizationColumns` called the general display-string converter before inspecting a column object. For `{"key":"name","label":"Name"}`, the converter returned `Name`, and table rows were incorrectly indexed by the display label. Only actual `.string` values now take the column-shorthand path; object columns retain their `key`, `label` and alignment. Typed JSON and original fixture payloads are unchanged.
- `SkeletonReachabilityAudit` now accepts an allowed URL navigation target on a Button without a Cell action keypath. It reuses `SkeletonButtonNavigation.resolveURL` against a synthetic HTTPS base solely for structural checking of relative URLs. `/butterpop`, HTTPS and the existing loopback HTTP policy pass; javascript/file/protocol-relative/userinfo/non-loopback HTTP targets still fail. URLs are not added to reachable Cell action keypaths. This does not certify a deployed public base URL, navigation success or source authority.

Red evidence: `renderer-extra-red-tests.log` ran the five new tests before the production fixes: four tests failed with fourteen assertions, while the rejected/missing URL test passed. `artifacts/renderer-before-extra/` retains eight real NSHostingView images, including the blank Reference and header-only table. After the fixes, the exact existing `--filter 'Skeleton.*Tests'` command and the same isolated scratch/cache with `--jobs 2` passed **171/171**, no skips or new dependency pins, at 02:15:26.519 Europe/Oslo. `git diff --check` passed.

New native tests (suite now 13; native/layout total 3 + 21 + 13 = 37):

- `testReferenceRendersLocalRowsWithItemAndRootContext`: actual NSHostingView/OCR checks Reference row, Second reference and Shared reference root; an enclosing item's list takes precedence over root rows; source encoding is unchanged.
- `testReferenceOnlyFallsBackToFilteredFlowWhenLocalValueIsAbsent`: actual images/OCR check missing local data uses the filtered flow feed and preserves root text; explicit empty/null/non-list values suppress it; other topics/types remain excluded.
- `testVisualizationTableUsesColumnKeysRatherThanDisplayLabels`: actual images/OCR check Rendered and 23 under Name/Value for canonical object columns, string columns and inferred columns, with unchanged source encoding.

Two new `SkeletonReachabilityAuditTests` cover allowed URL-only navigation and rejected/missing destinations; this suite now has 25 tests. All other suite counts remain as above. Eighteen native PNGs are now retained in `artifacts/renderer/`. `reference-local-context.png` and `visualization-table-objects.png` were visually inspected after the green run and show the expected content. Parent owns the updated Binding integration and 52-image cross-renderer corpus checks.

Reusable learning: display-string coercion is unsuitable for detecting structural JSON variants because object metadata such as `label` can masquerade as a string key. Preserve the typed case before applying a display converter, and verify table cell values—not only headers—in actual renderer evidence.

## Opt-in Porthole light host theme and final freeze

The parent requested a bounded visual correction after comparing the actual original form fixture in native and light Porthole web. The existing web `Public/css/porthole-webo.css` defines a light host with dark teal controls. This implementation now exposes the native-only public API:

```swift
surface.skeletonHostTheme(.portholeLight)
```

The default is `.platformDefault`; opting in selects a light color scheme and default system text at 16 pt / `#0f172a`. It does not change any encoded Skeleton, fetch new data, rewrite style roles or alter conference CSS. The parent owns Binding's use of the API, including keeping dark-mode surfaces on `.platformDefault` until there is a shared dark-host contract.

Theme defaults are deliberately limited to typography plus Button, TextField and TextArea:

- Button: native system text at 13 1/3 pt, weight600; foreground `#d9fbff`; 8pt vertical / 12pt horizontal padding; 1pt `#2d566b` border; radius10; gradient `#173140` to `#204657`. Browser computed evidence from the parent uses 600 13.3333px Arial, Save draft 90.46875 × 33 CSS px. The native test button is approximately 90 × 32 logical points; the native system family remains a declared difference from browser Arial.
- TextField/TextArea: default 16pt inherited text, foreground `#d5e4ed`, fill `#10212c`, 8pt padding, 1pt `#244457` border and radius8. Themed TextField uses the native plain editing control inside this box. On macOS the themed plain TextArea uses the existing native paragraph editor, without platform insets or an opaque system background, while preserving its real binding and delegate. Its default minimum line height is 1.2 times the effective font size. Parent's browser measured field/area heights are 36/90 CSS px; native text and box metrics can still differ by a few points.
- Explicit portable font size/style/family/weight, foreground/background, border, radius, padding and dimensions win. `controlStyle: plain` or `platform` opts out of theme chrome; host typography remains inherited. Defaults apply to a local render copy only. The default gradient is composed inside the existing box style so explicit opacity, hidden state and interaction backgrounds apply to it.
- Themed button chrome is inside its native `ButtonStyle`, so its padded area participates in the real hit target. This was verified with `NSWindow.sendEvent` mouse-down/up on its leading padding and the unchanged action payload observed by an injected native action handler.

This is a bounded approximation of the light Porthole host, not pixel identity, an arbitrary CSS adapter or coverage of every role/theme/control state. CSS hover/focus outlines and all platform editing details are not claimed to match exactly. The minimal iOS TextEditor branch also hides the system scroll background when this theme is opted in; **the iOS branch was not built or tested**, and no iOS verification is claimed. No additional iOS build roots were created.

Final tests are the same exact `--filter 'Skeleton.*Tests'`, isolated scratch/cache and `--jobs 2`: **175/175 passed, 0 skips**, at 02:34:18.307 Europe/Oslo. `SkeletonNativeSurfaceParityRepairTests` now has17 tests; all other suite counts are unchanged from the 171-test run. Added evidence:

- `testPortholeHostDefaultsPreservePortableOverridesAndControlOptOuts` checks explicit styles and both control-style opt-outs, including fontStyle precedence over the host's 16pt default.
- `testPortholeLightHostRendersAndEditsRealControlsWithoutChangingPayload` produces original/edited NSHostingView PNGs, OCR-verifies text, reads actual native input/editor font16, edits through the real native field editor and paragraph-editor delegate, clicks button padding and verifies the action payload. Save's normal root-data refresh is allowed to finish before editing the deterministic local fixture.
- `testPortholeHostRenderedOverridesKeepColorsTypographyPlainAndOpacity` checks actual24pt input, custom red/green control backgrounds, a plain button and a fully invisible opacity-zero button. Pixel samples avoid text glyphs.
- `testCanonicalImageDataURLPaintsAllFourSourceColors` uses the valid32px canonical four-quadrant PNG from the element matrix. It passed with existing AsyncImage: each of `(220,40,40)`, `(20,170,70)`, `(30,90,220)` and `(245,195,20)` appears in at least100 pixels within tolerance20. **No Image production change was needed.** A generic nonblank fallback would not pass this test.

Twenty-two native PNGs are retained in `artifacts/renderer/`. The new `porthole-light-controls.png`, `porthole-light-controls-edited.png`, `porthole-light-overrides.png` and `canonical-image-data-url.png` were visually inspected. The previous `renderer-host-theme-tests*.log` iterations document test-harness corrections, not an unverified final success. Source pin/dependency pins are unchanged; final `git diff --check` passed. Final `SkeletonView.swift` SHA256 is `9d39dad081f321d10e77017cbdbac6c80539a40795305a2a3721f664a748ef36`.

Reusable learning for the shared workflow: native control theme padding belongs inside a ButtonStyle label so the painted control is also clickable. Keep theme gradients inside the normal modifier/opacity pipeline, and test explicit overrides on actual pixels as well as data structures. Use the real NSTextField field editor for editing tests; directly changing `stringValue` and manually calling the delegate does not reliably update a SwiftUI binding. AppKit text editing and button action mutation can trigger a source refresh, so tests must distinguish unchanged fixture-root refresh behavior from editable draft behavior.

## Follow-up after 390a106: column Text, List row geometry and Picker selection

The parent's actual acceptance images exposed a remaining light-host layout mismatch: native List badges were intrinsic22pt pills instead of full-column blocks, and default List row insets added8pt horizontal/6pt vertical space. These are isolated follow-up changes on top of `390a106`, not an amendment of that commit. No new host API is needed.

- Under `.portholeLight`, undeclared List `rowInsets` default to zero; explicit insets and chat role defaults remain authoritative. Unwrapped row content takes the available width without the former trailing Spacer plus HStack gap. Wrapped rows and `.platformDefault` retain their behavior.
- A private host column context follows the actual VStack/HStack/ScrollView axis and Section content scope. Plain Text fills a column before its background is painted. Horizontal/Flow text stays intrinsic. The context is cleared at each renderer boundary so it cannot leak from an outer VStack into unrelated nested Grid/ComponentSurface implementations. Chip text remains intrinsic.
- Explicit fixed width, `maxWidthInfinity`, own alignment and parent column alignment retain precedence. An explicitly aligned intrinsic Text uses a transparent outer placement frame, leaving its colored background intrinsic. No wire payload or original token is changed.
- Native Picker now displays the first valid option when `allowsEmptySelection` is false and no valid state selection exists, matching the web select's initial presentation. It preserves a valid explicit selection and an allowed empty placeholder. This display fallback dispatches no initial action and writes no source state. The duplicate native Picker label is visually hidden; its one external field label and native control remain.

Four new tests were executed before production fixes: **4 failed with10 assertions**, in `renderer-column-red-tests.log`. The measured before-image badge bounds were `(8,6,22,32)` and `(8,58,22,32)`. The fixed light-host bounds are exactly `(0,0,240,32)` and `(0,40,240,32)` in a240pt column. Explicit row insets top7/leading5/bottom3/trailing9 produce `(5,7,226,32)` and `(5,57,226,32)` and remain unchanged. The next content starts at80pt after the two32pt badges and8pt row/stack gaps.

The targeted `--filter 'SkeletonNativeSurfaceParityRepairTests'` run passed **21/21**, with0 skips, using the same scratch/cache/jobs2. `renderer-column-tests.log` is its log. Added tests are `testPortholeListBadgeBoundsAndRowSpacingMatchColumnHost`, `testPortholeTextFillsColumnsButHorizontalAndFlowBadgesStayIntrinsic`, `testPortholeColumnTextHonorsExplicitWidthFillAndAlignment`, and `testPickerDisplaysFirstRequiredOptionAndPreservesExplicitOrEmptySelection`. Tests measure actual pixels, preserve the platform-default intrinsic Text baseline, check horizontal/Flow counterexamples, and OCR-check Normal/High/Choose option with exactly one Priority label and no initial action dispatch.

New `artifacts/renderer/porthole-column-list.png`, `porthole-text-hstack.png`, `porthole-text-aligned.png` and `picker-selection-required.png` were visually inspected. Follow-up `git diff --check` passed. `SkeletonView.swift` SHA256 after this follow-up is `5e438d41c5a43ce5e3971abe75a8e5002c609ae069fc7f9f70e8d315af6ceff7`. The full shared CP suite will be run after the independently assigned mounted-action adapter is frozen; the earlier175-test result remains the preceding broad baseline until that run completes.

Reusable learning: column fill must be scoped to the actual parent axis and happen before painting Text backgrounds. A global text frame would make horizontal badges and wrapped chips expand; a frame applied after the background would leave the colored pill intrinsic. Pixel geometry and horizontal counterexamples detect both mistakes. Required Picker selection should display a valid option without inventing a source-state mutation or dispatching an action merely to hydrate UI.


## Follow-up: light-host Visualization.table and NavigationBar panels

The parent's actual acceptance images showed two additional large style differences. These changes stay within the existing `.portholeLight` opt-in; `.platformDefault` retains its prior table and navigation rendering. There is no new host API, action behavior, wire field or conference CSS change.

- NavigationBar gets the current light-host panel defaults from `porthole-webo.css:2312`: 7pt padding, 6pt inter-item gap, 44pt minimum item height, radius16, 1pt translucent teal border, dark `#071720` at approximately96% opacity, inherited16pt bold item text, `#a9cbd4` inactive labels, white active labels and a translucent teal/green gradient with radius11 and border on the active item. Explicit padding, border, radius, background, foreground and typography remain authoritative. The defaults are also applied when VStack/ScrollView lift the NavigationBar into a safe-area inset, since that path skips the normal element branch. No hover/box-shadow identity is claimed; native hit regions and existing actions remain native.
- Visualization.table gets `porthole-webo.css:2881` base fill `#162a3a` at approximately70% opacity, radius8, and clipped rounded content. Header fill is white at6% opacity; default headings are12pt semibold `#9ac4cf`, rows are16pt `#eaf7f8`, with12pt horizontal/10pt vertical cell padding and12pt column gaps. The light theme omits the native-only inter-row Divider. Portable foreground and typography apply inside the table; explicit background and radius replace the default panel decoration. Existing row selection and activation behavior are unchanged.

The three new real NSHosting tests failed before the implementation with **12 assertions**: `renderer-panel-red-tests.log`. Their actual before-images are retained under `artifacts/renderer/panel-before/`. After the correction, `renderer-panel-tests.log` records **24/24 native repair tests passed**,0 skips. New tests:

- `testPortholeTablePaintsRoundedPanelAndCompactHeader`: checks the composited body color near RGB(92,106,117), lighter header, clear rounded corner, compact12pt-header/16pt-row height, actual Rendered text, and the unchanged platform-default light table.
- `testPortholeNavigationPaintsPanelInsetsAndActiveItem`: checks dark inter-item gutter, tinted active item, clear rounded corner, the44+7+7pt panel extent, actual Overview/Chat text and unchanged platform-default rendering.
- `testPortholePanelPortableOverridesRemainAuthoritative`: checks bright green backgrounds, red24pt text, square corners, no theme border and explicit zero nav padding in actual rendered output.

The final combined run uses the exact same `--filter 'Skeleton.*Tests'`, isolated scratch/cache and `--jobs 2`, after the transport agent froze its adapter: **182/182 PASS,0 skips**, in9.601 seconds at02:58:29.693 Europe/Oslo. The native/layout subtotal is3+21+24=48. No dependency pins changed. `porthole-panel-table.png`, `porthole-panel-navigation.png` and `porthole-panel-override-navigation.png` were visually inspected. `git diff --check` passes. Final source SHA256: `SkeletonView.swift` **47cc43c8b4084385b578ead0f9948868674e3e75ed8a46853be7ef84479916a9**, `SkeletonHostTheme.swift` **65b999b937e7ee0ad40ef3a737db5dcc3e1c5d1e0e3f6d3aa5e744872e05a712**. The parent owns the follow-up commit and final Binding integration; this subtask did not commit.

Reusable learning: lifted children (for example NavigationBar extracted into safeAreaInset) can bypass a renderer's normal default/modifier path. Ensure the lifted render entry point applies the same idempotent host defaults, and verify actual paint plus portable override counterexamples. Theme panel fills must be placed in the normal modifier pipeline so backgrounds, opacity and clipping remain composable.


## Final bounded follow-up: Picker chrome, mounted column Buttons and disabled navigation

The parent's final same-host images identified a gray intrinsic native Picker and narrow native root-column Buttons. These are now corrected only under `.portholeLight`:

- Picker uses a real borderless `NSPopUpButton` on macOS, inside the normal Skeleton modifier box. Default font is inherited16pt; fill `#10212c`, foreground `#d5e4ed`, border1pt `#244457`, radius10, padding8pt vertical/12pt horizontal and minHeight36 follow `porthole-webo.css:4561–4590`. The external label is12pt semibold. Explicit font/colors/width/border/radius/padding retain precedence; `controlStyle: platform/plain` and `.platformDefault` preserve the prior SwiftUI Picker. The native double arrow, menu appearance and exact text metrics remain platform-specific.
- The same existing Picker selection binding and payload code is used. Hydration produces no action. A real native `NSMenu.performActionForItem(at:)` updates the actual displayed value to High and dispatches exactly one `settings.setPriority` request; its default `.item` payload contains the selected high/High object. This is native menu-action testing, not a synthetic payload test or a claim of a physical mouse event. Native field geometry, font and accessibility tree are also asserted.
- SwiftUI Menu's macOS platform label adapter discarded its custom label decoration/foreground and stayed intrinsic. That candidate was rejected. The final AppKit popup has a221pt native view/hit region inside a240pt painted field (12pt explicit horizontal content padding and AppKit's native alignment inset). It retains real native keyboard/menu behavior and accessibility. SwiftUI owns the exposed accessibility proxy, so the representable declares its label/value as well as naming the native popup; the materialized AX tree exposes `AXPopUpButton / Priority / Normal`. No accessibility role is hardcoded.
- `NSPopUpButton.addItems(withTitles:)` collapses duplicate titles. A new actual popup regression proved this before correction (one option instead of two). The implementation now creates one `NSMenuItem` per option with its stable index and native target/action. Two Same labels with first/second IDs remain two selectable options, and selecting index1 submits the second ID. Display strings are never option identity.
- Column context now distinguishes a flex column from Section's ordinary block content. A Button in VStack or vertical ScrollView fills the available width before painting; direct Section and HStack Buttons stay intrinsic, and explicit width/alignment/fill win. This fixes the original locally mounted ComponentSurface root VStack without changing its payload or touching the independent mounted-action adapter. The original two-instance fixture now shows full-width Oppdater buttons. Its standalone CP PNG retains the source-adapter diagnostic because that test intentionally supplies no Binding adapter; the parent's separate integration proves the adapter behavior.
- NavigationBar now disables an unresolved URL navigation target or a missing static action keypath, using the unchanged `SkeletonButtonNavigation.resolveURL` policy. A relative `/chat` with no configured base (or an ordinary HTTP test base) is disabled; an allowed HTTPS base or absolute HTTPS target is enabled. Unsafe schemes remain disabled. The original `/chat` fixture is unchanged. The opt-in disabled style applies55% opacity in addition to any platform disabled rendering. Existing dynamic `keypathKeypath`-only navigation action execution was not repaired: the native bar previously called the static button execution path without resolving it, and an empty static action now fails closed. That existing dynamic action limitation is not claimed as verified.

Red evidence: `renderer-picker-red-tests.log` records2 tests failing4 assertions for intrinsic column Buttons and white Picker paint. `renderer-picker-duplicate-red-tests.log` records the duplicate-title failure. Before PNGs are in `artifacts/renderer/picker-before/`. Intermediate Menu and accessibility logs are retained as failed/rejected iterations, not final success evidence.

The final same-cache/jobs2 command `--filter 'Skeleton.*Tests'` passes **188/188,0 skips**, at03:17:09.666 Europe/Oslo in12.598 seconds (`renderer-skeleton-contract-tests-188.log`). Native repair suite is30 tests; native/layout subtotal3+21+30=54. Added six tests cover flex-column/Section/HStack/fixed-width Button geometry, Picker full paint and overrides, actual native menu selection/accessibility/no hydration action, duplicate display labels, the original two-mount root width, and safe navigation enabled/disabled behavior. Actual selected-High, duplicate-label, original mounted-column and disabled-navigation PNGs were visually inspected. `git diff --check` passes, no temporary diagnostics remain, and no commits were made by this subtask.

Final SHA256:

- `CellPickerView.swift`: `79125ce049b6b74beaa3f4d3569327c53876f02deda3fee70f07945f574c1f0e`
- `SkeletonView.swift`: `f2ecf5401f7b218b35d42149a00c5fbd4afd1d69bd035c4785e8461e17a45fbd`
- `SkeletonHostTheme.swift`: `dbe40e1be2882b405ff6eff132a8648805a0d72fd0b37709b543a0cd4ee1ae72`

The iOS Picker branch retains an opt-in SwiftUI Menu presentation; **it was not built or tested**. All native visual/interaction/AX claims in this report apply to macOS. No further OS build roots were created. Parent owns final Binding integration, repository commits and delivery claims.

Reusable learning for the shared capture: preserve native option identity by index, never by display title; AppKit popup convenience insertion deduplicates equal labels. For NSViewRepresentable accessibility, inspect the materialized SwiftUI AX proxy rather than assuming the underlying NSView's reported role is what assistive technology receives. Set the proxy's meaningful label/value and verify its existing native role plus actual selection.
