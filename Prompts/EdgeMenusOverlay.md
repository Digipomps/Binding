# EdgeMenusOverlay – Konsepter og retningslinjer

## Oversikt
`EdgeMenusOverlay` plasserer seks kantmenyer rundt lerretet (øvre venstre, øvre midt, øvre høyre, nedre venstre, nedre midt, nedre høyre). Menyene kan ekspanderes for å vise elementer eller trigge en handling ved valg. Hensikten er rask tilgang til forhåndsdefinerte konfigurasjoner uten å fylle UI med støy.

## Viktige komponenter
- `upperLeft`, `upperMid`, `upperRight`, `lowerLeft`, `lowerMid`, `lowerRight`: `[MenuItem]` for hver posisjon.
- `onSelect: (CellConfiguration) -> Void`: Kalles når brukeren velger et element for å laste ny konfigurasjon i porthole/canvas.
- `expanded: Set<EdgePosition>`: Lokal tilstand som sporer hvilke kantmenyer som er åpne.
- `EdgeMenu`: Underkomponent som rendrer menyen for en posisjon og rapporterer interaksjon via closures og `PreferenceKey`.
- `EdgePosition`: Enum som identifiserer posisjonene. Kvalifiser enumcases eksplisitt (f.eks. `EdgePosition.upperLeft`) der typeinferens kan feile.

## Flyt og interaksjon
1. `GeometryReader` gir størrelsen på området; menyene plasseres i et `ZStack` med `.position(x:y:)`.
2. Hver `EdgeMenu` får posisjon, elementer, utvidelsestilstand og en action-closure som enten toggler ekspansjon eller kaller `onSelect`.
3. `EdgeMenu` signaliserer toggle via `PreferenceKey` (f.eks. `EdgeMenuToggleKey`), og `EdgeMenusOverlay` oppdaterer `expanded` med animasjon i `.onPreferenceChange`.

## Viktige detaljer
- Bruk `withAnimation(.spring())` ved toggling for en responsiv opplevelse.
- Bevar konsistente marger (32 pt) og midtposisjonering (`proxy.size.width / 2`, `proxy.size.height - 32`).
- Hold presentasjonslogikk i `EdgeMenusOverlay`; send valg opp via `onSelect` for videre behandling.

## Forenklet eksempel
```swift
private struct EdgeMenusOverlay: View {
    var upperLeft: [MenuItem]
    var upperMid: [MenuItem]
    var upperRight: [MenuItem]
    var lowerLeft: [MenuItem]
    var lowerMid: [MenuItem]
    var lowerRight: [MenuItem]
    var onSelect: (CellConfiguration) -> Void

    @State private var expanded: Set<EdgePosition> = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EdgeMenu(position: EdgePosition.upperLeft,
                         items: upperLeft,
                         isExpanded: expanded.contains(EdgePosition.upperLeft)) {
                    action(EdgePosition.upperLeft, $0)
                }
                .position(x: 32, y: 32)

                // ... tilsvarende for de øvrige posisjonene ...
            }
            .onPreferenceChange(EdgeMenuToggleKey.self) { pos in
                if let pos { toggle(pos) }
            }
        }
    }

    private func action(_ position: EdgePosition, _ config: CellConfiguration?) {
        if let config { onSelect(config) } else { toggle(position) }
    }

    private func toggle(_ position: EdgePosition) {
        withAnimation(.spring()) {
            if expanded.contains(position) { expanded.remove(position) }
            else { expanded.insert(position) }
        }
    }
}
