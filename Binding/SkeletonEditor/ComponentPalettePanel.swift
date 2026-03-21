import SwiftUI

struct ComponentPalettePanel: View {
    @ObservedObject var editorState: EditorState
    @ObservedObject var placementState: ComponentPlacementState
    let items: [ComponentPaletteItem]
    let onArmComponent: (ComponentPaletteItem?) -> Void
    let onInsertError: (String) -> Void

    private var visibleItems: [ComponentPaletteItem] {
        items.filter { !editorState.dropTargets(for: $0.recipe).isEmpty }
    }

    private var activeItemTitle: String? {
        placementState.activeInsertionItem?.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Components")
                    .font(.headline)

                if !visibleItems.isEmpty {
                    PanelBadge(text: "\(visibleItems.count) kompatible", tint: .accentColor)
                }
            }

            if let activeItemTitle {
                Text("\(activeItemTitle) er klar. Dra til lerretet eller bruk en markert drop-slot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Velg node først. Dra til lerretet, bruk Plasser for å velge punkt, eller Sett inn for anbefalt plassering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        let isArmed = placementState.armedItem?.id == item.id
        let isDragging = placementState.activeDragItem?.id == item.id
        let isHighlighted = isArmed || isDragging

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.icon)
                    .foregroundStyle(isHighlighted ? Color.white : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isHighlighted ? Color.white : .primary)
                        .lineLimit(2)
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(isHighlighted ? Color.white.opacity(0.86) : .secondary)
                            .lineLimit(3)
                    }
                }
            }

            HStack(spacing: 6) {
                PanelBadge(text: "\(targetCount) mål", tint: isHighlighted ? .white : .accentColor)
                if isArmed {
                    PanelBadge(text: "Klar", tint: .white)
                }
            }

            HStack(spacing: 8) {
                Button(isArmed ? "Avbryt" : "Plasser") {
                    onArmComponent(isArmed ? nil : item)
                }
                .buttonStyle(.bordered)
                .tint(isHighlighted ? .white : .accentColor)
                .controlSize(.small)

                Button("Sett inn") {
                    guard editorState.applyPreferredComponent(item.recipe) else {
                        onInsertError("Ingen gyldig drop-target for \(item.title.lowercased()) i valgt kontekst.")
                        return
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isHighlighted ? .white : .accentColor)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            isHighlighted ? Color.accentColor : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHighlighted ? Color.accentColor : Color.black.opacity(0.06), lineWidth: isHighlighted ? 0 : 1)
        }
        .draggable(item) {
            ComponentDragPreviewCard(
                item: item,
                onActivate: { active in placementState.activeDragItem = active },
                onDeactivate: { placementState.activeDragItem = nil }
            )
        }
        .animation(.easeInOut(duration: 0.18), value: placementState.activeInsertionItem?.id)
    }
}
