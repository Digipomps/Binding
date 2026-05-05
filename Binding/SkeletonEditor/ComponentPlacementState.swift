import Foundation
import Combine

@MainActor
final class ComponentPlacementState: ObservableObject {
    @Published var activeDragItem: ComponentPaletteItem?
    @Published var armedItem: ComponentPaletteItem?

    var activeInsertionItem: ComponentPaletteItem? {
        activeDragItem ?? armedItem
    }

    var isPlacementArmed: Bool {
        activeDragItem == nil && armedItem != nil
    }

    func clear() {
        activeDragItem = nil
        armedItem = nil
    }
}
