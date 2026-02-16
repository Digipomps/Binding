import Foundation
import Combine
import CellBase

@MainActor
final class EditorState: ObservableObject {
    @Published private(set) var viewerSnapshot: SkeletonElement?
    @Published private(set) var workingCopy: SkeletonElement?
    @Published var selectedNodePath: SkeletonNodePath?
    @Published private(set) var revision: Int = 0

    private var undoStack: [SkeletonElement] = []
    private var redoStack: [SkeletonElement] = []

    var isEditing: Bool { workingCopy != nil }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var selectionSummary: String {
        selectedNodePath?.description ?? "no selection"
    }

    func captureViewerSnapshot(_ skeleton: SkeletonElement) {
        viewerSnapshot = skeleton
    }

    func beginEditing(from skeleton: SkeletonElement) {
        viewerSnapshot = skeleton
        workingCopy = skeleton
        selectedNodePath = .root
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
    }

    func endEditing() {
        workingCopy = nil
        selectedNodePath = nil
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
    }

    func selectNode(_ path: SkeletonNodePath?) {
        guard let path else {
            selectedNodePath = nil
            return
        }
        guard let workingCopy, SkeletonTreeQueries.element(in: workingCopy, at: path) != nil else { return }
        selectedNodePath = path
    }

    func replaceWorkingCopy(with newValue: SkeletonElement, recordUndo: Bool = true) {
        guard let current = workingCopy else {
            workingCopy = newValue
            return
        }
        if recordUndo {
            undoStack.append(current)
            redoStack.removeAll()
        }
        workingCopy = newValue
        revision &+= 1
    }

    func undo() {
        guard let previous = undoStack.popLast(), let current = workingCopy else { return }
        redoStack.append(current)
        workingCopy = previous
        revision &+= 1
    }

    func redo() {
        guard let next = redoStack.popLast(), let current = workingCopy else { return }
        undoStack.append(current)
        workingCopy = next
        revision &+= 1
    }

    func updateModifier(at path: SkeletonNodePath, mutate: (inout SkeletonModifiers) -> Void) {
        guard let workingCopy,
              let updated = SkeletonTreeMutations.updateModifier(in: workingCopy, at: path, mutate: mutate) else { return }
        replaceWorkingCopy(with: updated)
        selectedNodePath = path
    }

    func updateElement(at path: SkeletonNodePath, mutate: (inout SkeletonElement) -> Void) {
        guard let workingCopy,
              let updated = SkeletonTreeMutations.updateElement(in: workingCopy, at: path, mutate: mutate) else { return }
        replaceWorkingCopy(with: updated)
        selectedNodePath = path
    }

    func deleteNode(at path: SkeletonNodePath) {
        guard let workingCopy,
              let updated = SkeletonTreeMutations.delete(in: workingCopy, at: path) else { return }
        replaceWorkingCopy(with: updated)
        selectedNodePath = path.parent
    }

    func insertNode(_ element: SkeletonElement, into parentPath: SkeletonNodePath, at index: Int? = nil) {
        guard let workingCopy,
              let updated = SkeletonTreeMutations.insert(element, in: workingCopy, parentPath: parentPath, at: index) else { return }
        replaceWorkingCopy(with: updated)
        selectedNodePath = parentPath
    }

    func discardChanges() {
        guard let viewerSnapshot else { return }
        workingCopy = viewerSnapshot
        selectedNodePath = .root
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
    }

    @discardableResult
    func commitChanges() -> SkeletonElement? {
        guard let workingCopy else { return nil }
        viewerSnapshot = workingCopy
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
        return workingCopy
    }

    var selectedElement: SkeletonElement? {
        guard let workingCopy, let selectedNodePath else { return nil }
        return SkeletonTreeQueries.element(in: workingCopy, at: selectedNodePath)
    }

    var selectedModifiers: SkeletonModifiers? {
        guard let selectedElement else { return nil }
        return SkeletonTreeQueries.modifiers(on: selectedElement)
    }
}
