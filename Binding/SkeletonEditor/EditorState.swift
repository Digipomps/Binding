import Foundation
import Combine
import CellBase

@MainActor
final class EditorState: ObservableObject {
    private static let maximumUndoDepth = 32
    private static let maximumRedoDepth = 32

    @Published private(set) var viewerDocument: EditorDocument?
    @Published private(set) var workingDocument: EditorDocument?
    @Published var selectedNodePath: SkeletonNodePath?
    @Published private(set) var revision: Int = 0

    private var undoStack: [EditorDocument] = []
    private var redoStack: [EditorDocument] = []

    var viewerSnapshot: SkeletonElement? { viewerDocument?.skeleton }
    var workingCopy: SkeletonElement? { workingDocument?.skeleton }
    var viewerConfiguration: CellConfiguration? { viewerDocument?.configuration }
    var workingConfiguration: CellConfiguration? { workingDocument?.configuration }
    var currentWorkingDocument: EditorDocument? { workingDocument }
    var currentSourceBackedContext: EditorSourceBackedContext? { workingDocument?.sourceBackedContext ?? viewerDocument?.sourceBackedContext }

    var isEditing: Bool { workingDocument != nil }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isDirty: Bool {
        guard let workingDocument else { return false }
        guard let viewerDocument else { return true }
        return documentSignature(workingDocument) != documentSignature(viewerDocument)
    }

    var selectionSummary: String {
        selectedNodePath?.description ?? "no selection"
    }

    func captureViewerSnapshot(_ skeleton: SkeletonElement) {
        var fallback = CellConfiguration(name: "Viewer Snapshot")
        fallback.skeleton = skeleton
        captureViewerSnapshot(fallback)
    }

    func captureViewerSnapshot(
        _ configuration: CellConfiguration,
        sourceBackedContext: EditorSourceBackedContext? = nil,
        fallbackSkeleton: SkeletonElement? = nil
    ) {
        viewerDocument = EditorDocument(
            configuration: configuration,
            sourceBackedContext: sourceBackedContext,
            fallbackSkeleton: fallbackSkeleton
        )
    }

    func beginEditing(from skeleton: SkeletonElement) {
        var fallback = CellConfiguration(name: "Edited Skeleton")
        fallback.skeleton = skeleton
        beginEditing(configuration: fallback, fallbackSkeleton: skeleton)
    }

    func beginEditing(
        configuration: CellConfiguration,
        sourceBackedContext: EditorSourceBackedContext? = nil,
        fallbackSkeleton: SkeletonElement? = nil
    ) {
        let document = EditorDocument(
            configuration: configuration,
            sourceBackedContext: sourceBackedContext,
            fallbackSkeleton: fallbackSkeleton
        )
        viewerDocument = document
        workingDocument = document
        selectedNodePath = document.skeleton == nil ? nil : .root
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
    }

    func endEditing() {
        workingDocument = nil
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

    func replaceWorkingDocument(with newValue: EditorDocument, recordUndo: Bool = true) {
        guard let current = workingDocument else {
            workingDocument = newValue
            revision &+= 1
            return
        }
        if recordUndo {
            undoStack.append(current)
            if undoStack.count > Self.maximumUndoDepth {
                undoStack.removeFirst(undoStack.count - Self.maximumUndoDepth)
            }
            redoStack.removeAll()
        }
        workingDocument = newValue
        revision &+= 1
    }

    func replaceWorkingCopy(with newValue: SkeletonElement, recordUndo: Bool = true) {
        let currentDocument = workingDocument ?? viewerDocument ?? EditorDocument(configuration: CellConfiguration(name: "Edited Skeleton"))
        var updatedDocument = currentDocument
        updatedDocument.skeleton = newValue
        replaceWorkingDocument(with: updatedDocument, recordUndo: recordUndo)
    }

    func undo() {
        guard let previous = undoStack.popLast(), let current = workingDocument else { return }
        redoStack.append(current)
        if redoStack.count > Self.maximumRedoDepth {
            redoStack.removeFirst(redoStack.count - Self.maximumRedoDepth)
        }
        workingDocument = previous
        normalizeSelection()
        revision &+= 1
    }

    func redo() {
        guard let next = redoStack.popLast(), let current = workingDocument else { return }
        undoStack.append(current)
        workingDocument = next
        normalizeSelection()
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
        guard var document = workingDocument,
              let workingCopy = document.skeleton,
              let updated = SkeletonTreeMutations.delete(in: workingCopy, at: path) else { return }

        if let references = document.configuration.cellReferences {
            let prunedReferences = ReferenceUsageAnalyzer.pruneNewlyUnusedReferences(
                from: references,
                previousSkeleton: workingCopy,
                updatedSkeleton: updated
            )
            document.configuration.cellReferences = prunedReferences.isEmpty ? nil : prunedReferences
        }

        document.skeleton = updated
        replaceWorkingDocument(with: document)
        selectedNodePath = path.parent
    }

    func insertNode(_ element: SkeletonElement, into parentPath: SkeletonNodePath, at index: Int? = nil) {
        guard let workingCopy,
              let updated = SkeletonTreeMutations.insert(element, in: workingCopy, parentPath: parentPath, at: index) else { return }
        replaceWorkingCopy(with: updated)
        selectedNodePath = parentPath
    }

    func discardChanges() {
        guard let viewerDocument else { return }
        workingDocument = viewerDocument
        selectedNodePath = viewerDocument.skeleton == nil ? nil : .root
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
    }

    func discardTransientHistory() {
        undoStack.removeAll(keepingCapacity: false)
        redoStack.removeAll(keepingCapacity: false)
        revision &+= 1
    }

    @discardableResult
    func commitDocumentChanges() -> EditorDocument? {
        guard let workingDocument else { return nil }
        viewerDocument = workingDocument
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
        return workingDocument
    }

    @discardableResult
    func commitChanges() -> SkeletonElement? {
        commitDocumentChanges()?.skeleton
    }

    var selectedElement: SkeletonElement? {
        guard let workingCopy, let selectedNodePath else { return nil }
        return SkeletonTreeQueries.element(in: workingCopy, at: selectedNodePath)
    }

    var selectedModifiers: SkeletonModifiers? {
        guard let selectedElement else { return nil }
        return SkeletonTreeQueries.modifiers(on: selectedElement)
    }

    private func documentSignature(_ document: EditorDocument) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(document.configuration),
              let signature = String(data: data, encoding: .utf8) else {
            return ""
        }
        return signature
    }

    func dropTargets(for recipe: ComponentInsertionRecipe) -> [DropTargetDescriptor] {
        guard let workingDocument else { return [] }
        return DropTargetResolver.targets(
            for: recipe,
            document: workingDocument,
            selectedNodePath: selectedNodePath
        )
    }

    @discardableResult
    func applyPreferredComponent(_ recipe: ComponentInsertionRecipe) -> Bool {
        guard let workingDocument,
              let target = DropTargetResolver.preferredTarget(
                for: recipe,
                document: workingDocument,
                selectedNodePath: selectedNodePath
              ) else {
            return false
        }

        return applyComponentDrop(recipe: recipe, placement: target.placement)
    }

    @discardableResult
    func applyComponentDrop(recipe: ComponentInsertionRecipe, placement: DropPlacement) -> Bool {
        guard var document = workingDocument else { return false }

        let mergeResult = ReferenceMergeService.merge(
            recipeReferences: recipe.referenceTemplate,
            into: document.configuration.cellReferences ?? [],
            fragment: recipe.skeletonTemplate
        )

        guard let updatedSkeleton = SkeletonDropApplicator.apply(
            mergeResult.rewrittenFragment,
            placement: placement,
            to: document.skeleton
        ) else {
            return false
        }

        document.configuration.cellReferences = mergeResult.mergedReferences.isEmpty ? nil : mergeResult.mergedReferences
        document.skeleton = updatedSkeleton
        replaceWorkingDocument(with: document)
        selectedNodePath = placement.insertedSelectionPath
        return true
    }

    private func normalizeSelection() {
        guard let workingCopy else {
            selectedNodePath = nil
            return
        }

        guard let selectedNodePath else {
            self.selectedNodePath = .root
            return
        }

        if SkeletonTreeQueries.element(in: workingCopy, at: selectedNodePath) == nil {
            self.selectedNodePath = .root
        }
    }
}
