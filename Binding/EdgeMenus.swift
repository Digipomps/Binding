import SwiftUI

// MARK: - Models
struct MenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let configuration: CellConfiguration
}

enum EdgePosition: Hashable {
    case upperLeft, upperMid, upperRight, lowerLeft, lowerMid, lowerRight
}

// PreferenceKey to ask overlay to toggle menus from inside EdgeMenu
struct EdgeMenuToggleKey: PreferenceKey {
    static var defaultValue: EdgePosition? = nil
    static func reduce(value: inout EdgePosition?, nextValue: () -> EdgePosition?) {
        value = nextValue() ?? value
    }
}

// MARK: - Edge Menu View
struct EdgeMenu: View {
    let position: EdgePosition
    let items: [MenuItem]
    let isExpanded: Bool
    let onTap: (CellConfiguration?) -> Void

    @State private var fanSpread: CGFloat = 72

    var body: some View {
        ZStack {
            // Expansion fan
            if isExpanded {
                ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                    itemButton(item)
                        .offset(offsetForIndex(idx, count: items.count))
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Main menu button
            Button(action: { onTap(nil) }) {
                Image(systemName: mainIcon)
                    .font(.system(size: 18, weight: .bold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    private func itemButton(_ item: MenuItem) -> some View {
        Button(action: { onTap(item.configuration) }) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .padding(8)
                .background(Color.accentColor.opacity(0.9), in: Circle())
                .foregroundStyle(.white)
        }
        .draggable(item.configuration)
        .buttonStyle(.plain)
    }

    private var mainIcon: String {
        switch position {
        case .upperLeft: return "line.3.horizontal.circle.fill"
        case .upperMid: return "circle.grid.3x3.fill"
        case .upperRight: return "ellipsis.circle.fill"
        case .lowerLeft: return "gearshape.circle.fill"
        case .lowerMid: return "star.circle.fill"
        case .lowerRight: return "square.and.arrow.down.on.square.fill"
        }
    }

    private func offsetForIndex(_ index: Int, count: Int) -> CGSize {
        // Layout strategy: corners = arc from corner; mid = fan horizontally
        switch position {
        case .upperLeft:
            return CGSize(width: CGFloat(index + 1) * fanSpread, height: CGFloat(index + 1) * fanSpread)
        case .upperRight:
            return CGSize(width: CGFloat(-(index + 1)) * fanSpread, height: CGFloat(index + 1) * fanSpread)
        case .lowerLeft:
            return CGSize(width: CGFloat(index + 1) * fanSpread, height: CGFloat(-(index + 1)) * fanSpread)
        case .lowerRight:
            return CGSize(width: CGFloat(-(index + 1)) * fanSpread, height: CGFloat(-(index + 1)) * fanSpread)
        case .upperMid:
            // Fan horizontally outward from center top
            let sign: CGFloat = index % 2 == 0 ? -1 : 1
            let step = CGFloat((index + 1) / 2)
            return CGSize(width: sign * step * fanSpread, height: CGFloat(1) * fanSpread)
        case .lowerMid:
            let sign: CGFloat = index % 2 == 0 ? -1 : 1
            let step = CGFloat((index + 1) / 2)
            return CGSize(width: sign * step * fanSpread, height: CGFloat(-1) * fanSpread)
        }
    }
}
