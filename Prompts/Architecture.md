// Architecture

Dette dokumentet skisserer hovedprinsippene for arkitekturen i prosjektet.

## Lagdeling
- Presentasjon (SwiftUI-visninger): Ren visning og interaksjon. Minimal forretningslogikk.
- ViewModel(er): Eierskap til tilstand, koordinering av dataflyt, asynkrone kall og sideeffekter.
- Domenemodeller og tjenester: Rent, testbart domene; tjenester for IO, nettverk, persistens osv.

## Mønstre
- Data inn – hendelser ut: Visninger mottar data via bindings/observables og sender hendelser oppover via closures eller observables.
- Preferer dependency injection (init/Environment) fremfor singletons, men tillat singletons for delte systemtjenester når hensiktsmessig.
- Unngå tett kobling mot tredjepartskomponenter i visninger; kapsle i adaptere hvor mulig.

## UI-retningslinjer
- Behold visuell konsistens (spacing, typografi, animasjoner). Dokumentér avvik.
- Bruk `withAnimation` for tilstandsoppdateringer som påvirker layout/overganger.
- Sørg for tilgjengelighet (VoiceOver, Dynamic Type, kontrast).

## Dokumentasjon
- Hver nye komponent bør ha en kort forklaring i `Prompts/`, og koden bør linke til relevant dokumentasjon.
- Se også `Prompts/EdgeMenusOverlay.md` for et eksempel på komponentdokumentasjon og regler.


