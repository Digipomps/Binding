import SwiftUI
import CellBase
import CellApple

struct EditorSelectableSkeletonView: View {
    let element: SkeletonElement
    let path: SkeletonNodePath
    let selectedPath: SkeletonNodePath?
    let highlightedDropTargetPaths: Set<SkeletonNodePath>
    let onSelect: (SkeletonNodePath) -> Void

    @EnvironmentObject private var viewModel: PortholeBindingViewModel

    var body: some View {
        render(element, at: path)
    }

    private func render(_ element: SkeletonElement, at path: SkeletonNodePath) -> AnyView {
        switch element {
        case .HStack(let stack):
            return decorate(
                AnyView(
                    HStack(alignment: .center, spacing: 8) {
                        ForEach(Array(stack.elements.enumerated()), id: \.offset) { index, child in
                            EditorSelectableSkeletonView(
                                element: child,
                                path: path.appending(index),
                                selectedPath: selectedPath,
                                highlightedDropTargetPaths: highlightedDropTargetPaths,
                                onSelect: onSelect
                            )
                        }
                    }
                    .editorApplyModifiers(stack.modifiers)
                ),
                path: path
            )

        case .VStack(let stack):
            return decorate(
                AnyView(
                    VStack(alignment: .center, spacing: 8) {
                        ForEach(Array(stack.elements.enumerated()), id: \.offset) { index, child in
                            EditorSelectableSkeletonView(
                                element: child,
                                path: path.appending(index),
                                selectedPath: selectedPath,
                                highlightedDropTargetPaths: highlightedDropTargetPaths,
                                onSelect: onSelect
                            )
                        }
                    }
                    .editorApplyModifiers(stack.modifiers)
                ),
                path: path
            )

        case .ScrollView(let scroll):
            if scroll.axis == "horizontal" {
                return decorate(
                    AnyView(
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(Array(scroll.elements.enumerated()), id: \.offset) { index, child in
                                    EditorSelectableSkeletonView(
                                        element: child,
                                        path: path.appending(index),
                                        selectedPath: selectedPath,
                                        highlightedDropTargetPaths: highlightedDropTargetPaths,
                                        onSelect: onSelect
                                    )
                                }
                            }
                        }
                        .editorApplyModifiers(scroll.modifiers)
                    ),
                    path: path
                )
            }
            return decorate(
                AnyView(
                    ScrollView(.vertical) {
                        VStack {
                            ForEach(Array(scroll.elements.enumerated()), id: \.offset) { index, child in
                                EditorSelectableSkeletonView(
                                    element: child,
                                    path: path.appending(index),
                                    selectedPath: selectedPath,
                                    highlightedDropTargetPaths: highlightedDropTargetPaths,
                                    onSelect: onSelect
                                )
                            }
                        }
                    }
                    .editorApplyModifiers(scroll.modifiers)
                ),
                path: path
            )

        case .Section(let section):
            return decorate(
                AnyView(
                    VStack(alignment: .center, spacing: 8) {
                        if let header = section.header {
                            BindingSkeletonView(element: header)
                        }
                        ForEach(Array(section.content.enumerated()), id: \.offset) { index, child in
                            EditorSelectableSkeletonView(
                                element: child,
                                path: path.appending(index),
                                selectedPath: selectedPath,
                                highlightedDropTargetPaths: highlightedDropTargetPaths,
                                onSelect: onSelect
                            )
                        }
                        if let footer = section.footer {
                            BindingSkeletonView(element: footer)
                        }
                    }
                    .editorApplyModifiers(section.modifiers)
                ),
                path: path
            )

        case .ZStack(let stack):
            return decorate(
                AnyView(
                    ZStack {
                        ForEach(Array(stack.elements.enumerated()), id: \.offset) { index, child in
                            EditorSelectableSkeletonView(
                                element: child,
                                path: path.appending(index),
                                selectedPath: selectedPath,
                                highlightedDropTargetPaths: highlightedDropTargetPaths,
                                onSelect: onSelect
                            )
                        }
                    }
                    .editorApplyModifiers(stack.modifiers)
                ),
                path: path
            )

        case .Grid(let grid):
            return decorate(
                AnyView(
                    LazyVGrid(columns: gridItems(from: grid.columns), spacing: CGFloat(grid.spacing ?? 8)) {
                        ForEach(Array(grid.elements.enumerated()), id: \.offset) { index, child in
                            EditorSelectableSkeletonView(
                                element: child,
                                path: path.appending(index),
                                selectedPath: selectedPath,
                                highlightedDropTargetPaths: highlightedDropTargetPaths,
                                onSelect: onSelect
                            )
                        }
                    }
                    .editorApplyModifiers(grid.modifiers)
                ),
                path: path
            )

        default:
            return decorate(
                AnyView(
                    BindingSkeletonView(element: element)
                ),
                path: path
            )
        }
    }

    private func decorate(_ content: AnyView, path: SkeletonNodePath) -> AnyView {
        let isSelected = selectedPath == path
        let isDropTarget = highlightedDropTargetPaths.contains(path)
        return AnyView(
            content
                .environmentObject(viewModel)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isDropTarget ? Color.accentColor.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentColor : (isDropTarget ? Color.accentColor.opacity(0.45) : Color.clear),
                            lineWidth: isSelected ? 2 : (isDropTarget ? 1.5 : 0)
                        )
                )
                .anchorPreference(key: EditorSkeletonNodeBoundsPreferenceKey.self, value: .bounds) { [path.description: $0] }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(path)
                }
        )
    }

    private func gridItems(from cols: [SkeletonGridColumn]) -> [GridItem] {
        cols.map { col in
            switch col.type {
            case .fixed:
                return GridItem(.fixed(CGFloat(col.value ?? 0)))
            case .flexible:
                return GridItem(.flexible(minimum: CGFloat(col.min ?? 0), maximum: CGFloat(col.max ?? .infinity)))
            case .adaptive:
                return GridItem(.adaptive(minimum: CGFloat(col.min ?? 0), maximum: CGFloat(col.max ?? .infinity)))
            }
        }
    }
}

struct EditorSkeletonNodeBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private extension View {
    func editorApplyModifiers(_ modifiers: SkeletonModifiers?) -> AnyView {
        var view: AnyView = AnyView(self)

        if let padding = modifiers?.padding {
            view = AnyView(view.padding(CGFloat(padding)))
        }

        let frameWidth: CGFloat? = modifiers?.width.map { CGFloat($0) }
        let frameHeight: CGFloat? = modifiers?.height.map { CGFloat($0) }
        let maxW: CGFloat? = modifiers?.maxWidthInfinity == true ? .infinity : nil
        let maxH: CGFloat? = modifiers?.maxHeightInfinity == true ? .infinity : nil

        let alignment = Alignment(
            horizontal: mapHorizontalAlignment(modifiers?.hAlignment).horizontal,
            vertical: mapVerticalAlignment(modifiers?.vAlignment).vertical
        )
        view = AnyView(view.frame(width: frameWidth, height: frameHeight, alignment: alignment))
        if maxW != nil || maxH != nil {
            view = AnyView(view.frame(maxWidth: maxW ?? .infinity, maxHeight: maxH ?? .infinity, alignment: alignment))
        }

        if let bg = modifiers?.background, let color = Color(editorHex: bg) {
            view = AnyView(view.background(color))
        }

        if let cornerRadius = modifiers?.cornerRadius {
            view = AnyView(view.cornerRadius(CGFloat(cornerRadius)))
        }

        if let opacity = modifiers?.opacity {
            view = AnyView(view.opacity(opacity))
        }

        if let hidden = modifiers?.hidden, hidden {
            view = AnyView(view.hidden())
        }

        return view
    }

    private func mapHorizontalAlignment(_ value: String?) -> Alignment {
        switch value ?? "" {
        case "leading":
            return .leading
        case "trailing":
            return .trailing
        default:
            return .center
        }
    }

    private func mapVerticalAlignment(_ value: String?) -> Alignment {
        switch value ?? "" {
        case "top":
            return .top
        case "bottom":
            return .bottom
        default:
            return .center
        }
    }
}

private extension Color {
    init?(editorHex: String) {
        var s = editorHex
        if s.hasPrefix("#") { s.removeFirst() }
        var rgba: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgba) else { return nil }
        switch s.count {
        case 6:
            let r = Double((rgba & 0xFF0000) >> 16) / 255.0
            let g = Double((rgba & 0x00FF00) >> 8) / 255.0
            let b = Double(rgba & 0x0000FF) / 255.0
            self = Color(red: r, green: g, blue: b)
        case 8:
            let r = Double((rgba & 0xFF000000) >> 24) / 255.0
            let g = Double((rgba & 0x00FF0000) >> 16) / 255.0
            let b = Double((rgba & 0x0000FF00) >> 8) / 255.0
            let a = Double(rgba & 0x000000FF) / 255.0
            self = Color(red: r, green: g, blue: b).opacity(a)
        default:
            return nil
        }
    }
}
