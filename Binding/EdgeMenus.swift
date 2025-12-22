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
        GeometryReader { proxy in
            ZStack {
                // Expansion fan
                if isExpanded {
                    ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                        itemButton(item)
                            .offset(clampedRadialOffset(for: idx, count: items.count, in: proxy.size))
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

    private func clampedRadialOffset(for index: Int, count: Int, in size: CGSize) -> CGSize {
        let pad: CGFloat = 10
        let itemDiameter: CGFloat = 36 // approx: 16pt icon + 2*8pt padding, matches itemButton

        // Compute the raw offset from the anchor (main button center)
        let raw = radialOffset(for: index, count: count)

        // Determine the anchor absolute position for the main button based on EdgePosition
        // EdgeMenusOverlay positions EdgeMenu at edges using .position(...). Inside here, we are at local center.
        // We need to map anchor to actual edge location within this local GeometryReader.
        // We'll approximate anchor points with 32pt margins like documentation suggests.
        let margin: CGFloat = 32
        let anchor: CGPoint
        switch position {
        case .upperLeft:
            anchor = CGPoint(x: margin, y: margin)
        case .upperMid:
            anchor = CGPoint(x: size.width / 2, y: margin)
        case .upperRight:
            anchor = CGPoint(x: size.width - margin, y: margin)
        case .lowerLeft:
            anchor = CGPoint(x: margin, y: size.height - margin)
        case .lowerMid:
            anchor = CGPoint(x: size.width / 2, y: size.height - margin)
        case .lowerRight:
            anchor = CGPoint(x: size.width - margin, y: size.height - margin)
        }

        // Compute the absolute position of the item (center) before clamping
        var absX = anchor.x + raw.width
        var absY = anchor.y + raw.height

        // Clamp within bounds considering padding and item size
        let minX = pad + itemDiameter / 2
        let maxX = size.width - pad - itemDiameter / 2
        let minY = pad + itemDiameter / 2
        let maxY = size.height - pad - itemDiameter / 2

        absX = min(max(absX, minX), maxX)
        absY = min(max(absY, minY), maxY)

        // Convert back to offset relative to anchor
        return CGSize(width: absX - anchor.x, height: absY - anchor.y)
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

