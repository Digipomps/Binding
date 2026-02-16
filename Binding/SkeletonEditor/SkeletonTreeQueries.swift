import Foundation
import CellBase

struct SkeletonTreeNodeDescriptor: Identifiable, Hashable {
    let path: SkeletonNodePath
    let depth: Int
    let title: String

    var id: SkeletonNodePath { path }
}

enum SkeletonTreeQueries {
    static func element(in root: SkeletonElement, at path: SkeletonNodePath) -> SkeletonElement? {
        elementAtPath(in: root, remainingPath: ArraySlice(path.indices))
    }

    static func modifiers(on element: SkeletonElement) -> SkeletonModifiers? {
        switch element {
        case .List(let list): return list.modifiers
        case .Object(let object): return object.modifiers
        case .Spacer(let spacer): return spacer.modifiers
        case .Image(let image): return image.modifiers
        case .Text(let text): return text.modifiers
        case .TextField(let textField): return textField.modifiers
        case .HStack(let stack): return stack.modifiers
        case .VStack(let stack): return stack.modifiers
        case .Reference(let reference): return reference.modifiers
        case .Button(let button): return button.modifiers
        case .Divider(let divider): return divider.modifiers
        case .ScrollView(let scrollView): return scrollView.modifiers
        case .Section(let section): return section.modifiers
        case .ZStack(let zStack): return zStack.modifiers
        case .Grid(let grid): return grid.modifiers
        case .Toggle(let toggle): return toggle.modifiers
        }
    }

    static func linearizedNodes(in root: SkeletonElement) -> [SkeletonTreeNodeDescriptor] {
        var result: [SkeletonTreeNodeDescriptor] = []
        walk(root, at: .root, depth: 0, into: &result)
        return result
    }

    static func displayName(for element: SkeletonElement) -> String {
        switch element {
        case .List: return "List"
        case .Object: return "Object"
        case .Spacer: return "Spacer"
        case .Image: return "Image"
        case .Text: return "Text"
        case .TextField: return "TextField"
        case .HStack: return "HStack"
        case .VStack: return "VStack"
        case .Reference: return "Reference"
        case .Button: return "Button"
        case .Divider: return "Divider"
        case .ScrollView: return "ScrollView"
        case .Section: return "Section"
        case .ZStack: return "ZStack"
        case .Grid: return "Grid"
        case .Toggle: return "Toggle"
        }
    }

    static func canContainChildren(_ element: SkeletonElement) -> Bool {
        switch element {
        case .HStack, .VStack, .ScrollView, .Section, .ZStack, .Grid:
            return true
        default:
            return false
        }
    }

    static func childCount(in element: SkeletonElement) -> Int {
        children(in: element).count
    }

    private static func elementAtPath(in element: SkeletonElement, remainingPath: ArraySlice<Int>) -> SkeletonElement? {
        guard let next = remainingPath.first else { return element }
        guard let child = child(at: next, in: element) else { return nil }
        return elementAtPath(in: child, remainingPath: remainingPath.dropFirst())
    }

    private static func walk(
        _ element: SkeletonElement,
        at path: SkeletonNodePath,
        depth: Int,
        into output: inout [SkeletonTreeNodeDescriptor]
    ) {
        output.append(
            SkeletonTreeNodeDescriptor(
                path: path,
                depth: depth,
                title: displayName(for: element)
            )
        )

        for (index, child) in children(in: element).enumerated() {
            walk(child, at: path.appending(index), depth: depth + 1, into: &output)
        }
    }

    private static func children(in element: SkeletonElement) -> [SkeletonElement] {
        switch element {
        case .HStack(let stack):
            return stack.elements
        case .VStack(let stack):
            return stack.elements
        case .ScrollView(let scrollView):
            return scrollView.elements
        case .Section(let section):
            return section.content
        case .ZStack(let zStack):
            return zStack.elements
        case .Grid(let grid):
            return grid.elements
        default:
            return []
        }
    }

    private static func child(at index: Int, in element: SkeletonElement) -> SkeletonElement? {
        guard index >= 0 else { return nil }
        let children = children(in: element)
        guard index < children.count else { return nil }
        return children[index]
    }
}
