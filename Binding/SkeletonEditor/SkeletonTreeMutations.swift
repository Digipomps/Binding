import Foundation
import CellBase

enum SkeletonTreeMutations {
    static func updateElement(
        in root: SkeletonElement,
        at path: SkeletonNodePath,
        mutate: (inout SkeletonElement) -> Void
    ) -> SkeletonElement? {
        updateElement(in: root, remainingPath: ArraySlice(path.indices), mutate: mutate)
    }

    static func updateModifier(
        in root: SkeletonElement,
        at path: SkeletonNodePath,
        mutate: (inout SkeletonModifiers) -> Void
    ) -> SkeletonElement? {
        updateModifier(in: root, remainingPath: ArraySlice(path.indices), mutate: mutate)
    }

    static func delete(in root: SkeletonElement, at path: SkeletonNodePath) -> SkeletonElement? {
        guard !path.isRoot else { return nil }
        return delete(in: root, remainingPath: ArraySlice(path.indices))
    }

    static func insert(
        _ elementToInsert: SkeletonElement,
        in root: SkeletonElement,
        parentPath: SkeletonNodePath,
        at index: Int? = nil
    ) -> SkeletonElement? {
        insert(
            elementToInsert,
            in: root,
            remainingParentPath: ArraySlice(parentPath.indices),
            at: index
        )
    }

    static func insertBefore(
        _ elementToInsert: SkeletonElement,
        in root: SkeletonElement,
        siblingPath: SkeletonNodePath
    ) -> SkeletonElement? {
        guard let parentPath = siblingPath.parent,
              let index = siblingPath.indices.last else {
            return nil
        }

        return insert(elementToInsert, in: root, parentPath: parentPath, at: index)
    }

    static func insertAfter(
        _ elementToInsert: SkeletonElement,
        in root: SkeletonElement,
        siblingPath: SkeletonNodePath
    ) -> SkeletonElement? {
        guard let parentPath = siblingPath.parent,
              let index = siblingPath.indices.last else {
            return nil
        }

        return insert(elementToInsert, in: root, parentPath: parentPath, at: index + 1)
    }

    static func replace(
        _ replacement: SkeletonElement,
        in root: SkeletonElement,
        at path: SkeletonNodePath
    ) -> SkeletonElement? {
        updateElement(in: root, at: path) { element in
            element = replacement
        }
    }

    // MARK: - Recursive operations

    private static func updateElement(
        in element: SkeletonElement,
        remainingPath: ArraySlice<Int>,
        mutate: (inout SkeletonElement) -> Void
    ) -> SkeletonElement? {
        guard let next = remainingPath.first else {
            var updated = element
            mutate(&updated)
            return updated
        }

        guard let child = child(at: next, in: element),
              let updatedChild = updateElement(in: child, remainingPath: remainingPath.dropFirst(), mutate: mutate) else {
            return nil
        }

        return replacingChild(at: next, with: updatedChild, in: element)
    }

    private static func updateModifier(
        in element: SkeletonElement,
        remainingPath: ArraySlice<Int>,
        mutate: (inout SkeletonModifiers) -> Void
    ) -> SkeletonElement? {
        guard let next = remainingPath.first else {
            return withUpdatedModifiers(on: element, mutate: mutate)
        }

        guard let child = child(at: next, in: element),
              let updatedChild = updateModifier(in: child, remainingPath: remainingPath.dropFirst(), mutate: mutate) else {
            return nil
        }

        return replacingChild(at: next, with: updatedChild, in: element)
    }

    private static func delete(
        in element: SkeletonElement,
        remainingPath: ArraySlice<Int>
    ) -> SkeletonElement? {
        guard let next = remainingPath.first else { return nil }

        if remainingPath.count == 1 {
            return deletingChild(at: next, in: element)
        }

        guard let child = child(at: next, in: element),
              let updatedChild = delete(in: child, remainingPath: remainingPath.dropFirst()) else {
            return nil
        }

        return replacingChild(at: next, with: updatedChild, in: element)
    }

    private static func insert(
        _ elementToInsert: SkeletonElement,
        in element: SkeletonElement,
        remainingParentPath: ArraySlice<Int>,
        at index: Int?
    ) -> SkeletonElement? {
        guard let next = remainingParentPath.first else {
            return insertingChild(elementToInsert, at: index, in: element)
        }

        guard let child = child(at: next, in: element),
              let updatedChild = insert(
                elementToInsert,
                in: child,
                remainingParentPath: remainingParentPath.dropFirst(),
                at: index
              ) else {
            return nil
        }

        return replacingChild(at: next, with: updatedChild, in: element)
    }

    // MARK: - Modifier update on current node

    private static func withUpdatedModifiers(
        on element: SkeletonElement,
        mutate: (inout SkeletonModifiers) -> Void
    ) -> SkeletonElement {
        switch element {
        case .List(var list):
            var modifiers = list.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            list.modifiers = modifiers
            return .List(list)
        case .Object(var object):
            var modifiers = object.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            object.modifiers = modifiers
            return .Object(object)
        case .Spacer(var spacer):
            var modifiers = spacer.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            spacer.modifiers = modifiers
            return .Spacer(spacer)
        case .Image(var image):
            var modifiers = image.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            image.modifiers = modifiers
            return .Image(image)
        case .Text(var text):
            var modifiers = text.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            text.modifiers = modifiers
            return .Text(text)
        case .TextField(var textField):
            var modifiers = textField.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            textField.modifiers = modifiers
            return .TextField(textField)
        case .TextArea(var textArea):
            var modifiers = textArea.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            textArea.modifiers = modifiers
            return .TextArea(textArea)
        case .HStack(var stack):
            var modifiers = stack.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            stack.modifiers = modifiers
            return .HStack(stack)
        case .VStack(var stack):
            var modifiers = stack.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            stack.modifiers = modifiers
            return .VStack(stack)
        case .Reference(var reference):
            var modifiers = reference.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            reference.modifiers = modifiers
            return .Reference(reference)
        case .Button(var button):
            var modifiers = button.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            button.modifiers = modifiers
            return .Button(button)
        case .Divider(var divider):
            var modifiers = divider.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            divider.modifiers = modifiers
            return .Divider(divider)
        case .ScrollView(var scrollView):
            var modifiers = scrollView.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            scrollView.modifiers = modifiers
            return .ScrollView(scrollView)
        case .Section(var section):
            var modifiers = section.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            section.modifiers = modifiers
            return .Section(section)
        case .ZStack(var zStack):
            var modifiers = zStack.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            zStack.modifiers = modifiers
            return .ZStack(zStack)
        case .Grid(var grid):
            var modifiers = grid.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            grid.modifiers = modifiers
            return .Grid(grid)
        case .Toggle(var toggle):
            var modifiers = toggle.modifiers ?? SkeletonModifiers()
            mutate(&modifiers)
            toggle.modifiers = modifiers
            return .Toggle(toggle)
        }
    }

    // MARK: - Tree helpers

    private static func child(at index: Int, in element: SkeletonElement) -> SkeletonElement? {
        guard index >= 0 else { return nil }

        switch element {
        case .HStack(let stack):
            guard index < stack.elements.count else { return nil }
            return stack.elements[index]
        case .VStack(let stack):
            guard index < stack.elements.count else { return nil }
            return stack.elements[index]
        case .ScrollView(let scrollView):
            guard index < scrollView.elements.count else { return nil }
            return scrollView.elements[index]
        case .Section(let section):
            guard index < section.content.count else { return nil }
            return section.content[index]
        case .ZStack(let zStack):
            guard index < zStack.elements.count else { return nil }
            return zStack.elements[index]
        case .Grid(let grid):
            guard index < grid.elements.count else { return nil }
            return grid.elements[index]
        default:
            return nil
        }
    }

    private static func replacingChild(
        at index: Int,
        with replacement: SkeletonElement,
        in element: SkeletonElement
    ) -> SkeletonElement? {
        guard index >= 0 else { return nil }

        switch element {
        case .HStack(var stack):
            guard index < stack.elements.count else { return nil }
            stack.elements[index] = replacement
            return .HStack(stack)
        case .VStack(var stack):
            guard index < stack.elements.count else { return nil }
            stack.elements[index] = replacement
            return .VStack(stack)
        case .ScrollView(var scrollView):
            guard index < scrollView.elements.count else { return nil }
            scrollView.elements[index] = replacement
            return .ScrollView(scrollView)
        case .Section(var section):
            guard index < section.content.count else { return nil }
            section.content[index] = replacement
            return .Section(section)
        case .ZStack(var zStack):
            guard index < zStack.elements.count else { return nil }
            zStack.elements[index] = replacement
            return .ZStack(zStack)
        case .Grid(var grid):
            guard index < grid.elements.count else { return nil }
            grid.elements[index] = replacement
            return .Grid(grid)
        default:
            return nil
        }
    }

    private static func deletingChild(at index: Int, in element: SkeletonElement) -> SkeletonElement? {
        guard index >= 0 else { return nil }

        switch element {
        case .HStack(var stack):
            guard index < stack.elements.count else { return nil }
            stack.elements.remove(at: index)
            return .HStack(stack)
        case .VStack(var stack):
            guard index < stack.elements.count else { return nil }
            stack.elements.remove(at: index)
            return .VStack(stack)
        case .ScrollView(var scrollView):
            guard index < scrollView.elements.count else { return nil }
            scrollView.elements.remove(at: index)
            return .ScrollView(scrollView)
        case .Section(var section):
            guard index < section.content.count else { return nil }
            section.content.remove(at: index)
            return .Section(section)
        case .ZStack(var zStack):
            guard index < zStack.elements.count else { return nil }
            zStack.elements.remove(at: index)
            return .ZStack(zStack)
        case .Grid(var grid):
            guard index < grid.elements.count else { return nil }
            grid.elements.remove(at: index)
            return .Grid(grid)
        default:
            return nil
        }
    }

    private static func insertingChild(
        _ newChild: SkeletonElement,
        at index: Int?,
        in element: SkeletonElement
    ) -> SkeletonElement? {
        switch element {
        case .HStack(var stack):
            let insertIndex = clamp(index, count: stack.elements.count)
            stack.elements.insert(newChild, at: insertIndex)
            return .HStack(stack)
        case .VStack(var stack):
            let insertIndex = clamp(index, count: stack.elements.count)
            stack.elements.insert(newChild, at: insertIndex)
            return .VStack(stack)
        case .ScrollView(var scrollView):
            let insertIndex = clamp(index, count: scrollView.elements.count)
            scrollView.elements.insert(newChild, at: insertIndex)
            return .ScrollView(scrollView)
        case .Section(var section):
            let insertIndex = clamp(index, count: section.content.count)
            section.content.insert(newChild, at: insertIndex)
            return .Section(section)
        case .ZStack(var zStack):
            let insertIndex = clamp(index, count: zStack.elements.count)
            zStack.elements.insert(newChild, at: insertIndex)
            return .ZStack(zStack)
        case .Grid(var grid):
            let insertIndex = clamp(index, count: grid.elements.count)
            grid.elements.insert(newChild, at: insertIndex)
            return .Grid(grid)
        default:
            return nil
        }
    }

    private static func clamp(_ index: Int?, count: Int) -> Int {
        guard let index else { return count }
        return max(0, min(index, count))
    }
}
