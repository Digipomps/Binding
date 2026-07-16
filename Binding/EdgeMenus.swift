import SwiftUI
import CellBase
import CellApple

// MARK: - Models
struct MenuItem: Identifiable {
    let icon: String
    let title: String
    let subtitle: String?
    let configuration: CellConfiguration

    var id: String {
        configuration.uuid
    }

    init(icon: String, configuration: CellConfiguration) {
        let trimmedTitle = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = configuration.description?.trimmingCharacters(in: .whitespacesAndNewlines)

        self.icon = icon
        self.title = trimmedTitle.isEmpty ? "Navnløs" : trimmedTitle
        self.subtitle = {
            guard let trimmedSubtitle, !trimmedSubtitle.isEmpty else { return nil }
            return trimmedSubtitle
        }()
        self.configuration = configuration
    }
}

enum EdgePosition: String, CaseIterable, Identifiable, Hashable {
    case upperLeft, upperMid, upperRight, lowerLeft, lowerMid, lowerRight

    var id: String { rawValue }

    var menuSlotKeypath: String {
        switch self {
        case .upperLeft: return "upperLeftMenu"
        case .upperMid: return "upperMidMenu"
        case .upperRight: return "upperRightMenu"
        case .lowerLeft: return "lowerLeftMenu"
        case .lowerMid: return "lowerMidMenu"
        case .lowerRight: return "lowerRightMenu"
        }
    }

    var localizedTitle: String {
        switch self {
        case .upperLeft: return "Hovedmeny"
        case .upperMid: return "Flater"
        case .upperRight: return "Flere flater"
        case .lowerLeft: return "Kontroll"
        case .lowerMid: return "Favoritter"
        case .lowerRight: return "Åpne og last inn"
        }
    }
}

enum EdgeMenuExpansionStyle: String, CaseIterable, Identifiable {
    case auto
    case stack
    case radial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Automatisk"
        case .stack:
            return "Stabel"
        case .radial:
            return "Radiell"
        }
    }
}

enum EdgeMenuLabelMode: String, CaseIterable, Identifiable {
    case iconOnly
    case titleOnOpen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly:
            return "Bare ikoner"
        case .titleOnOpen:
            return "Vis navn"
        }
    }
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
    let expansionStyle: EdgeMenuExpansionStyle
    let labelMode: EdgeMenuLabelMode
    let showsSubtitle: Bool
    let onTap: (CellConfiguration?) -> Void
    let onShowAll: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @FocusState private var focusedTarget: FocusTarget?

    private let radius: CGFloat = 96
    private let sweepDegrees: CGFloat = 140
    static let presentationLimit = 10

    static func presentationPlan(for itemCount: Int) -> (visibleCount: Int, showsAll: Bool) {
        let normalizedCount = max(0, itemCount)
        let showsAll = normalizedCount > presentationLimit
        return (
            visibleCount: min(normalizedCount, showsAll ? presentationLimit - 1 : presentationLimit),
            showsAll: showsAll
        )
    }

    private enum FocusTarget: Hashable {
        case trigger
        case item(Int)
        case showAll
    }

    private var presentationPlan: (visibleCount: Int, showsAll: Bool) {
        Self.presentationPlan(for: items.count)
    }
    private var hasOverflow: Bool { presentationPlan.showsAll }
    private var visibleItems: [MenuItem] {
        Array(items.prefix(presentationPlan.visibleCount))
    }
    private var presentedItemCount: Int { visibleItems.count + (hasOverflow ? 1 : 0) }

    var body: some View {
        ZStack(alignment: anchorAlignment) {
            ForEach(Array(visibleItems.enumerated()), id: \.offset) { idx, item in
                itemButton(item, index: idx)
                    .frame(maxWidth: stackFrameWidth, alignment: stackItemAlignment)
                    .offset(currentOffset(for: idx, count: presentedItemCount))
                    .opacity(isExpanded ? 1 : 0)
                    .scaleEffect(isExpanded ? 1 : 0.9, anchor: scaleAnchor)
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(!isExpanded)
                    .animation(itemAnimation(for: idx), value: isExpanded)
            }

            if hasOverflow {
                showAllButton
                    .frame(maxWidth: stackFrameWidth, alignment: stackItemAlignment)
                    .offset(currentOffset(for: visibleItems.count, count: presentedItemCount))
                    .opacity(isExpanded ? 1 : 0)
                    .scaleEffect(isExpanded ? 1 : 0.9, anchor: scaleAnchor)
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(!isExpanded)
                    .animation(itemAnimation(for: visibleItems.count), value: isExpanded)
            }

            Button(action: { onTap(nil) }) {
                Image(systemName: mainIcon)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                    .overlay(alignment: .topTrailing) {
                        if items.count > 1 {
                            Text("\(items.count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                                .offset(x: 7, y: -6)
                        }
                    }
            }
            .buttonStyle(.plain)
            .focused($focusedTarget, equals: .trigger)
            .accessibilityLabel(position.localizedTitle)
            .accessibilityValue("\(items.count) \(items.count == 1 ? "flate" : "flater"), \(isExpanded ? "utvidet" : "skjult")")
            .accessibilityHint(items.count > 1 ? "Åpner eller lukker menyfeltet." : "Åpner flaten.")
            .scaleEffect(isExpanded ? 0.92 : 1)
            .opacity(isExpanded ? 0.88 : 1)
            .animation(containerAnimation, value: isExpanded)
        }
        .frame(width: footprint.width, height: footprint.height, alignment: anchorAlignment)
        .contentShape(Rectangle())
        .animation(containerAnimation, value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            Task { @MainActor in
                focusedTarget = expanded && !visibleItems.isEmpty ? .item(0) : .trigger
            }
        }
        .bindingEscapeCommand {
            guard isExpanded else { return }
            onTap(nil)
        }
        .bindingMenuNavigationCommands(
            onPrevious: { moveFocus(by: -1) },
            onNext: { moveFocus(by: 1) },
            onFirst: { focusBoundary(first: true) },
            onLast: { focusBoundary(first: false) }
        )
    }

    private var focusableTargets: [FocusTarget] {
        var targets = visibleItems.indices.map(FocusTarget.item)
        if hasOverflow {
            targets.append(.showAll)
        }
        return targets
    }

    private func moveFocus(by offset: Int) {
        guard isExpanded, !focusableTargets.isEmpty else { return }
        let targets = focusableTargets
        let currentIndex = focusedTarget.flatMap { targets.firstIndex(of: $0) }
            ?? (offset > 0 ? -1 : targets.count)
        let nextIndex = (currentIndex + offset + targets.count) % targets.count
        focusedTarget = targets[nextIndex]
    }

    private func focusBoundary(first: Bool) {
        guard isExpanded else { return }
        focusedTarget = first ? focusableTargets.first : focusableTargets.last
    }

    @ViewBuilder
    private func itemButton(_ item: MenuItem, index: Int) -> some View {
        Button(action: { onTap(item.configuration) }) {
            if labelMode == .titleOnOpen {
                HStack(spacing: 10) {
                    if usesTrailingGlyphLayout {
                        menuTextBlock(for: item, index: index)
                        menuGlyph(for: item)
                    } else {
                        menuGlyph(for: item)
                        menuTextBlock(for: item, index: index)
                    }
                }
                .padding(.vertical, shouldShowSubtitle(for: item) ? 8 : 7)
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 6, y: 3)
            } else {
                menuGlyph(for: item)
            }
        }
        .buttonStyle(.plain)
        .focused($focusedTarget, equals: .item(index))
        .accessibilityLabel("Åpne \(item.title)")
        .accessibilityHint("Laster denne konfigurasjonen i Porthole.")
    }

    private var showAllButton: some View {
        Button {
            onShowAll()
        } label: {
            Text("Vis alle \(items.count)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minWidth: 112, minHeight: 44)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .focused($focusedTarget, equals: .showAll)
        .accessibilityLabel("Vis alle \(items.count) flater i \(position.localizedTitle)")
        .accessibilityHint("Åpner hele biblioteket.")
    }

    private func menuTextBlock(for item: MenuItem, index: Int) -> some View {
        VStack(alignment: textStackAlignment, spacing: shouldShowSubtitle(for: item) ? 2 : 0) {
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if shouldShowSubtitle(for: item), let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(textAlignment)
        .frame(maxWidth: .infinity, alignment: textFrameAlignment)
        .opacity(isExpanded ? 1 : 0)
        .offset(x: isExpanded ? 0 : labelHiddenOffset)
        .animation(labelAnimation(for: index), value: isExpanded)
    }

    private func menuGlyph(for item: MenuItem) -> some View {
        Image(systemName: item.icon)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 34, height: 34)
            .background(Color.accentColor.opacity(0.92), in: Circle())
            .foregroundStyle(.white)
    }

    private var footprint: CGSize {
        guard isExpanded else {
            return CGSize(width: 56, height: 56)
        }

        switch resolvedExpansionStyle {
        case .auto:
            let width = labelMode == .titleOnOpen ? stackFrameWidth : 80
            let height = 56 + CGFloat(presentedItemCount) * currentStackStride
            return CGSize(width: width, height: min(height, 420))
        case .radial:
            switch position {
            case .upperMid, .lowerMid:
                return CGSize(width: 300, height: 220)
            default:
                return CGSize(width: 220, height: 220)
            }
        case .stack:
            let width = labelMode == .titleOnOpen ? stackFrameWidth : 80
            let height = 56 + CGFloat(presentedItemCount) * currentStackStride
            return CGSize(width: width, height: min(height, 420))
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

    private var scaleAnchor: UnitPoint {
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

    private var stackItemAlignment: Alignment {
        switch position {
        case .upperLeft, .lowerLeft:
            return .leading
        case .upperMid, .lowerMid:
            return .center
        case .upperRight, .lowerRight:
            return .trailing
        }
    }

    private var textStackAlignment: HorizontalAlignment {
        switch position {
        case .upperRight, .lowerRight:
            return .trailing
        case .upperMid, .lowerMid:
            return .center
        default:
            return .leading
        }
    }

    private var textFrameAlignment: Alignment {
        switch position {
        case .upperRight, .lowerRight:
            return .trailing
        case .upperMid, .lowerMid:
            return .center
        default:
            return .leading
        }
    }

    private var textAlignment: TextAlignment {
        switch position {
        case .upperRight, .lowerRight:
            return .trailing
        case .upperMid, .lowerMid:
            return .center
        default:
            return .leading
        }
    }

    private var stackFrameWidth: CGFloat {
        switch position {
        case .upperMid, .lowerMid:
            return labelMode == .titleOnOpen ? 304 : 80
        default:
            return labelMode == .titleOnOpen ? 238 : 80
        }
    }

    private var labelHiddenOffset: CGFloat {
        switch position {
        case .upperMid, .lowerMid:
            return 0
        case .upperRight, .lowerRight:
            return 8
        default:
            return -8
        }
    }

    private var usesTrailingGlyphLayout: Bool {
        switch position {
        case .upperRight, .lowerRight:
            return true
        default:
            return false
        }
    }

    private var currentStackStride: CGFloat {
        if labelMode == .iconOnly {
            switch position {
            case .upperMid, .lowerMid:
                return 50
            default:
                return 54
            }
        }
        if shouldShowAnySubtitle {
            switch position {
            case .upperMid, .lowerMid:
                return 64
            default:
                return 68
            }
        }
        switch position {
        case .upperMid, .lowerMid:
            return 54
        default:
            return 58
        }
    }

    private var shouldShowAnySubtitle: Bool {
        items.contains(where: shouldShowSubtitle(for:))
    }

    private func shouldShowSubtitle(for item: MenuItem) -> Bool {
        guard showsSubtitle, labelMode == .titleOnOpen else { return false }
        guard let subtitle = item.subtitle, !subtitle.isEmpty else { return false }
        return true
    }

    private var stackDirection: CGFloat {
        switch position {
        case .upperLeft, .upperMid, .upperRight:
            return 1
        case .lowerLeft, .lowerMid, .lowerRight:
            return -1
        }
    }

    private var resolvedExpansionStyle: EdgeMenuExpansionStyle {
        switch expansionStyle {
        case .auto:
            return .stack
        case .stack:
            return .stack
        case .radial:
            return .radial
        }
    }

    private func currentOffset(for index: Int, count: Int) -> CGSize {
        guard isExpanded else { return .zero }

        switch resolvedExpansionStyle {
        case .stack:
            return CGSize(
                width: stackHorizontalOffset(for: index),
                height: stackDirection * currentStackStride * CGFloat(index + 1)
            )
        case .radial:
            return radialOffset(for: index, count: count)
        case .auto:
            return .zero
        }
    }

    private func stackHorizontalOffset(for index: Int) -> CGFloat {
        switch position {
        case .upperMid, .lowerMid:
            let pattern: [CGFloat] = [0, -12, 12, -7, 7, -4, 4]
            return pattern[index % pattern.count]
        case .upperLeft, .lowerLeft:
            return min(CGFloat(index) * 5, 14)
        case .upperRight, .lowerRight:
            return -min(CGFloat(index) * 5, 14)
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

    private var containerAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .spring(
                response: isCenterPosition ? 0.36 : 0.30,
                dampingFraction: isCenterPosition ? 0.86 : 0.82
            )
    }

    private func itemAnimation(for index: Int) -> Animation? {
        guard !accessibilityReduceMotion else { return nil }
        let baseDelayStep = isCenterPosition ? 0.028 : 0.032
        let delay = Double(index) * baseDelayStep
        let base: Animation = .spring(
                response: isCenterPosition ? 0.34 : 0.28,
                dampingFraction: isCenterPosition ? 0.88 : 0.84
            )
        return base.delay(delay)
    }

    private func labelAnimation(for index: Int) -> Animation? {
        guard !accessibilityReduceMotion else { return nil }
        let baseDelay = isCenterPosition ? 0.06 : 0.08
        let step = isCenterPosition ? 0.022 : 0.03
        let delay = baseDelay + Double(index) * step
        return .easeOut(duration: 0.18).delay(delay)
    }

    private var isCenterPosition: Bool {
        switch position {
        case .upperMid, .lowerMid:
            return true
        default:
            return false
        }
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

private extension View {
    @ViewBuilder
    func bindingEscapeCommand(_ action: @escaping () -> Void) -> some View {
#if os(macOS)
        onExitCommand(perform: action)
#else
        self
#endif
    }

    @ViewBuilder
    func bindingMenuNavigationCommands(
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onFirst: @escaping () -> Void,
        onLast: @escaping () -> Void
    ) -> some View {
#if os(macOS)
        self
            .onMoveCommand { direction in
                switch direction {
                case .up, .left:
                    onPrevious()
                case .down, .right:
                    onNext()
                default:
                    break
                }
            }
            .onKeyPress(.home) {
                onFirst()
                return .handled
            }
            .onKeyPress(.end) {
                onLast()
                return .handled
            }
#else
        self
#endif
    }
}
