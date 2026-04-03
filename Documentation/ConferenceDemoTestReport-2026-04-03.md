# Conference Demo Test Report · 2026-04-03

## Scope

Live verification on `My Mac` after the local conference runtime startup fixes in Binding.

Tested binary:

- `/Users/kjetil/Library/Developer/Xcode/DerivedData/Binding-erntjstdfcrbeachccbemadrrbon/Build/Products/Debug/Binding.app`

## Verified

- Fresh Binding launch reaches `Conference Demo Launcher` without crashing in early `PortholeViewModel` setup.
- `Conference Public Surface` remains configured as a no-auth conference surface.
- `Conference Participant Portal Dashboard` now opens from the launcher without triggering Touch ID / LocalAuthentication.
- `/usr/bin/log show --last 5m` returned no `LocalAuthentication`, `evaluatePolicy`, or `Authenticate to access your identities` entries for the participant-portal pass.
- Local conference snapshot refresh paths now stay on Binding-local runtime bootstrap instead of forcing `AppInitializer.initialize()`.

## Build / Test

- `xcodebuild -project /Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build`
  - Passed
- `xcodebuild -project /Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/BindingTests/conferencePublicSurfaceDoesNotRequireAuthenticatedRuntimeBootstrap`
  - Passed, but Xcode still selected `0 tests` for this filter shape

## Evidence

- Window capture after launcher -> participant cockpit:
  - `/tmp/binding_window_after_ax_press_success.png`
- Window capture before the transition:
  - `/tmp/binding_window_after_click.png`

## Remaining Gap

- The large SwiftUI scroll surface in `Conference Participant Portal` is still awkward to drive mechanically through accessibility.
- Off-screen recommendation actions returned successful AX presses, but I could not yet prove the `Vis i siden -> Start chat -> Åpne chatflate` chain end-to-end from the lower recommendation section in the same live automation pass.
- This now looks like a GUI automation limitation around the long scroll container more than another auth/bootstrap failure.

## Next Pass

1. Scroll/focus the recommendation section deterministically in live automation.
2. Verify `Vis i siden` updates the selected participant card live.
3. Verify `Start chat` promotes the participant into `Chat og Oppfølging`.
4. Verify `Åpne chatflate` still opens the dedicated chat workbench from that state.

## Automation Sweep Update

En repeterbar smoke-run finnes nå i:

- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Scripts/run_conference_demo_smoke.sh`

Siste fullkjørte rapport:

- `/tmp/binding-conference-smoke-20260403-175428/report.md`

Siste sweep med native `Conference Automation`-kommandoer og vindusbilder viste:

- `Conference Demo Launcher`: OK
- `Conference Participant Portal`: OK
- `Focus Ane Solberg -> Start chat -> Open focused chat workbench`: OK
- `Conference Control Tower`: OK
- `Conference Scaffold Setup & Identity Link`: OK
- `Conference Public Surface`: laster nå stabilt over bridge og ender i staging-preget `Innholdet er ikke tilgjengelig akkurat nå.` i stedet for host-registration-feil
- `Conference AI Assistant`: fortsatt ikke ferdig. Flaten åpner local-first og krever ikke auth-bootstrap, men blir stående i `Laster innhold...` i smoke-sweepen og kan fortsatt ende i timeout ved lang venting

Dette betyr at GUI-automatiseringen nå er sterk nok til å bevise de fleste demo-flatene ende-til-ende. Den tydeligste gjenværende funksjonelle feilen er fortsatt `Conference AI Assistant`, ikke selve automation-verktøyene.
