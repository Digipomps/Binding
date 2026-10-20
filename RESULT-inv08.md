# RESULT inv08 — blocked, not green

## Evidence and cause

Baseline: b77b5603245779047f92727c7cd1908b6a62d36d.
The original invb71 execution selected device 60A4509A-5AD0-42B9-A1D0-7CEBA044F514, iPhone 16 Pro on iOS 18.6 (read from inv05/SIMULATORS.json before this session attempted the script). Xcode was 27.0, build 27A266a. The original crash report is `~/Library/Logs/DiagnosticReports/HAVEN-2026-10-09-095546.ips`.

The triggered stack is EXC_BAD_ACCESS / null address, in this order:
`Itinerary.PartiallyGenerated` metadata completion → `ItineraryPlanner` metadata completion → ObjC metadata update → `objc_copyClassList` → `+[XCTestCase(RuntimeUtilities) _allSubclasses]`.
These types live in the resolved CellProtocol dependency, `Sources/CellApple/Intelligence/Tools/Itinerary.swift` and `ItineraryPlanner.swift`, import FoundationModels, and declare iOS 27.0 availability. The b77b5603 diff changes URL delivery and its test, not these types.

Strong diagnosis: test discovery realizes linked classes whose FoundationModels metadata is incompatible with the selected iOS 18.6 runtime. This explains the pre-test crash. A compatible-runtime rerun is still needed to confirm causality. This does NOT prove an iOS 18 production app is safe; supporting older runtimes may require a separate CellProtocol metadata/linking fix. No simulator/runtime was removed or changed.

## Change

Added `Scripts/inv08-build-test.sh` in the Binding worktree: a versioned copy of inv05/wp-build-test.sh, selecting only available iPhone simulators on iOS >= 27.0, newest runtime first. It fails clearly if none exists, preserves every original test selection and build option, checks b77b5603 ancestry and a clean worktree, records the actual HEAD, and uses separate inv08 evidence/DerivedData paths. The original inv05 script remains unchanged. No app or test source was modified.

## Validation and blocker

- `/bin/bash -n`: passed.
- `self-test`: passed.
- Selector checks: 2 passed; a booted iOS 18.6 cannot override an available iOS 27 device, and an old-only inventory fails explicitly.
- Requested original inv05/wp-build-test.sh attempt: exit 1 before build/test. Capacity passed (119.8 GiB free, 109.8 GiB after reserve). CoreSimulator access was denied in this managed sandbox (`Operation not permitted`, invalid XPC connection). Its SIMULATORS.json was overwritten by simctl with no usable inventory; original selection evidence above was read before that attempt.
- No new app tests executed. Original run: build passed, test bootstrap failed. The previous 79-test result was reported by the requester, not reverified here.
- Green gate remains outstanding. Run `/bin/bash Scripts/inv08-build-test.sh` from this clean worktree in a permitted host session; this task cannot grant itself simulator access. Do not substitute syntax/selector checks for the app test gate.

Commit SHA is recorded in the handoff copy after committing this file. No push, merge, tag, deployment or TestFlight action.
