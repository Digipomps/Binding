import SwiftUI

struct ComponentPalettePanel: View {
    @ObservedObject var editorState: EditorState
    let items: [ComponentPaletteItem]
    let armedItemID: ComponentPaletteItem.ID?
    let onDragStateChange: (ComponentPaletteItem?) -> Void
    let onArmComponent: (ComponentPaletteItem?) -> Void
    let onInsertError: (String) -> Void

    private var visibleItems: [ComponentPaletteItem] {
        items.filter { !editorState.dropTargets(for: $0.recipe).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Components")
                .font(.headline)

            Text("Velg node først. Dra til lerretet, bruk Plasser for a velge punkt, eller Sett inn for anbefalt mal.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if visibleItems.isEmpty {
                Text("Ingen kompatible komponenter for valgt plassering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(visibleItems) { item in
                            componentCard(item)
                                .frame(width: 180, alignment: .topLeading)
                        }
                    }
                }
            }
        }
    }

    private func componentCard(_ item: ComponentPaletteItem) -> some View {
        let targetCount = editorState.dropTargets(for: item.recipe).count
        let isArmed = armedItemID == item.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.icon)
                    .foregroundStyle(isArmed ? Color.white : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isArmed ? Color.white : .primary)
                        .lineLimit(2)
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(isArmed ? Color.white.opacity(0.86) : .secondary)
                            .lineLimit(3)
                    }
                }
            }

            Text("\(targetCount) gyldige mål")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isArmed ? Color.white.opacity(0.82) : .secondary)

            HStack(spacing: 8) {
                Button(isArmed ? "Avbryt" : "Plasser") {
                    onArmComponent(isArmed ? nil : item)
                }
                .buttonStyle(.bordered)
                .tint(isArmed ? .white : .accentColor)
                .controlSize(.small)

                Button("Sett inn") {
                    guard editorState.applyPreferredComponent(item.recipe) else {
                        onInsertError("Ingen gyldig drop-target for \(item.title.lowercased()) i valgt kontekst.")
                        return
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isArmed ? .white : .accentColor)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            isArmed ? Color.accentColor : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .draggable(item) {
            ComponentDragPreviewCard(
                item: item,
                onActivate: { active in onDragStateChange(active) },
                onDeactivate: { onDragStateChange(nil) }
            )
        }
    }
}
