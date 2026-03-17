import SwiftUI
import CellBase
import CellApple

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

    @State private var radius: CGFloat = 96
    @State private var sweepDegrees: CGFloat = 140

    var body: some View {
        ZStack(alignment: anchorAlignment) {
            if isExpanded {
                ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                    itemButton(item)
                        .offset(radialOffset(for: idx, count: items.count))
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Button(action: { onTap(nil) }) {
                Image(systemName: mainIcon)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(width: footprint.width, height: footprint.height, alignment: anchorAlignment)
        .contentShape(Rectangle())
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

    private var footprint: CGSize {
        switch position {
        case .upperMid, .lowerMid:
            return CGSize(width: 300, height: 220)
        default:
            return CGSize(width: 220, height: 220)
        }
    }

    private var anchorAlignment: Alignment {
        switch position {
        case .upperLeft:
            return .topLeading
        case .upperMid:
            return .top
        case .upperRight:
            return .topTrailing
        case .lowerLeft:
            return .bottomLeading
        case .lowerMid:
            return .bottom
        case .lowerRight:
            return .bottomTrailing
        }
    }

    private func degreesToRadians(_ deg: CGFloat) -> CGFloat { deg * .pi / 180 }

    private func centerAngleDegrees(for position: EdgePosition) -> CGFloat {
        switch position {
        case .upperLeft: return 45    // down-right
        case .upperMid:  return 90    // straight down
        case .upperRight:return 135   // down-left
        case .lowerLeft: return -45   // up-right
        case .lowerMid:  return -90   // straight up
        case .lowerRight:return -135  // up-left
        }
    }

    private func sweepDegreesForPosition(_ position: EdgePosition) -> CGFloat {
        // Allow mid positions a wider fan by default
        switch position {
        case .upperMid, .lowerMid: return sweepDegrees
        default: return min(sweepDegrees, 150)
        }
    }

    private func radialOffset(for index: Int, count: Int) -> CGSize {
        guard count > 0 else { return .zero }
        let center = centerAngleDegrees(for: position)
        let sweep = sweepDegreesForPosition(position)
        let step: CGFloat = count > 1 ? (sweep / CGFloat(count - 1)) : 0
        let start = center - sweep / 2
        let angleDeg = start + step * CGFloat(index)
        let angle = degreesToRadians(angleDeg)
        let x = cos(angle) * radius
        let y = sin(angle) * radius
        return CGSize(width: x, height: y)
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
}
