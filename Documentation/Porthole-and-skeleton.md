# Porthole og Skeleton

Denne dokumentasjonen forklarer hvordan Porthole og Skeleton henger sammen i prosjektet, hvordan data flyter, og hvordan du legger til eller endrer visninger.

## Oversikt
- **Porthole** er en Cell som kan motta og sende UI-konfigurasjon og innhold via `flow` og `get/set`-operasjoner.
- **Skeleton** er en deklarativ beskrivelse av UI (som en liten DSL) med elementer som `.VStack`, `.HStack`, `.Text`, `.Image`, `.List`, `.Reference`, `.Button` osv.
- **Klienten (appen)** rendrer Skeleton i SwiftUI via `SkeletonView(element:)` og oppdaterer seg når Porthole publiserer nye elementer i strømmen.

## Arkitektur
1. Porthole (server):
   - Eksponerer en strøm (`flow`) av innhold. Innholdet kan være:
     - Et objekt som dekodes direkte til `SkeletonElement`, eller
     - En `CellConfiguration` som inneholder et `skeleton`-felt.
   - Tar imot `set(keypath:value:)`-kall for å bytte konfigurasjon eller trigge handlinger.

2. Klient (UI):
   - Har en view model som kobler til Porthole, lytter på `flow`, og publiserer gjeldende `SkeletonElement` til visningen.
   - Kan sende `set(...)` for å be Porthole laste en ny konfigurasjon.

## View model: PortholeBindingViewModel
Den konsoliderte view-modellen for Porthole heter `PortholeBindingViewModel` og finnes i `PortholeViewModel-Binding.swift`.

Ansvar:
- Koble til Porthole én gang (`connectIfNeeded()`).
- Abonnere på `flow` og dekode innkommende objekter til `SkeletonElement`.
- Eksponere `@Published var currentSkeleton` som UI rendrer.
- Sende `set(keypath:value:)` når brukeren velger en ny konfigurasjon (via `load(configuration:)`).

Forenklet bruk:
```swift
@StateObject private var viewModel = PortholeBindingViewModel()

var body: some View {
    PortholeCanvas(skeleton: viewModel.currentSkeleton)
        .task { await viewModel.connectIfNeeded() }
}
