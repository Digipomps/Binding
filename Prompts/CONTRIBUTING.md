// Contributing

Takk for at du vil bidra! Denne veiledningen beskriver hvordan vi jobber og hvilke prinsipper vi følger.

## Prinsipper
- Hold komponenter fokusert på én oppgave og separer ansvar. UI-komponenter skal ikke inneholde forretningslogikk når det kan unngås.
- Foretrekk Swift Concurrency (async/await) og SwiftUI-mønstre konsistent på tvers av prosjektet.
- Skriv tydelige, små commits med beskrivende meldinger.
- Legg til eller oppdater dokumentasjon i `Prompts/` når du introduserer nye mønstre eller komponenter.

## Kodekvalitet
- Bruk eksplisitt typekvalifisering når typeinferens kan feile (f.eks. `EdgePosition.upperLeft`).
- Pakk layout-/state-endringer som påvirker UI i `withAnimation` for en jevn opplevelse.
- Test tilgjengelighet (VoiceOver, Dynamic Type) der det er relevant.

## Testing
- Skriv tester for kritisk logikk. For SwiftUI-visninger, vurder snapshot-/interaksjonstester der det gir verdi.

## Dokumentasjon
- Oppdater relevante `.md`-filer i `Prompts/` ved større endringer.
- Legg korte referansekommentarer i koden som peker til dokumentasjonen.

## Pull Requests
- Beskriv hva som er endret, hvorfor, og eventuelle følgeeffekter.
- Link til relevante issues og dokumenter i `Prompts/`.

