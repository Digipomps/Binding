import Foundation
import CellBase

enum DropPlacement: Equatable {
    case intoContainer(at: SkeletonNodePath, index: Int)
    case beforeNode(at: SkeletonNodePath)
    case afterNode(at: SkeletonNodePath)
    case replaceNode(at: SkeletonNodePath)
    case root

    var insertedSelectionPath: SkeletonNodePath? {
        switch self {
        case .intoContainer(let path, let index):
            return path.appending(index)
        case .beforeNode(let path):
            guard let parent = path.parent, let index = path.indices.last else { return nil }
            return parent.appending(index)
        case .afterNode(let path):
            guard let parent = path.parent, let index = path.indices.last else { return nil }
            return parent.appending(index + 1)
        case .replaceNode(let path):
            return path
        case .root:
            return .root
        }
    }
}

struct DropTargetDescriptor: Identifiable {
    var id: String
    var path: SkeletonNodePath
    var placement: DropPlacement
    var label: String
    var targetKind: String
}

enum DropTargetResolver {
    static func targets(
        for recipe: ComponentInsertionRecipe,
        document: EditorDocument,
        selectedNodePath: SkeletonNodePath?
    ) -> [DropTargetDescriptor] {
        guard supportsComponentInsertion(recipe) else { return [] }

        let supportedKinds = Set(recipe.supportedTargetKinds.map { $0.lowercased() })
        guard let skeleton = document.skeleton else {
            guard supportedKinds.contains("root") else { return [] }
            return [
                DropTargetDescriptor(
                    id: "root",
                    path: .root,
                    placement: .root,
                    label: "Set as root component",
                    targetKind: "root"
                )
            ]
        }

        let nodes = SkeletonTreeQueries.linearizedNodes(in: skeleton)
        var seen: Set<String> = []
        var results: [DropTargetDescriptor] = []

        for descriptor in nodes {
            guard let element = SkeletonTreeQueries.element(in: skeleton, at: descriptor.path) else { continue }
            let elementKind = SkeletonTreeQueries.kindIdentifier(for: element)

            if SkeletonTreeQueries.canContainChildren(element), supportedKinds.contains(elementKind) {
                appendUnique(
                    DropTargetDescriptor(
                        id: "into:\(descriptor.path.description)",
                        path: descriptor.path,
                        placement: .intoContainer(at: descriptor.path, index: SkeletonTreeQueries.childCount(in: element)),
                        label: descriptor.path.isRoot ? "Append to root \(descriptor.title)" : "Append to \(descriptor.title)",
                        targetKind: elementKind
                    ),
                    into: &results,
                    seen: &seen
                )
            }

            guard let parentPath = descriptor.path.parent,
                  let parentElement = SkeletonTreeQueries.element(in: skeleton, at: parentPath)
            else {
                continue
            }

            let parentKind = SkeletonTreeQueries.kindIdentifier(for: parentElement)
            guard supportedKinds.contains(parentKind) else { continue }

            appendUnique(
                DropTargetDescriptor(
                    id: "after:\(descriptor.path.description)",
                    path: descriptor.path,
                    placement: .afterNode(at: descriptor.path),
                    label: "Insert after \(descriptor.title)",
                    targetKind: parentKind
                ),
                into: &results,
                seen: &seen
            )
        }

        return results.sorted { lhs, rhs in
            priority(of: lhs, selectedNodePath: selectedNodePath) < priority(of: rhs, selectedNodePath: selectedNodePath)
        }
    }

    static func preferredTarget(
        for recipe: ComponentInsertionRecipe,
        document: EditorDocument,
        selectedNodePath: SkeletonNodePath?
    ) -> DropTargetDescriptor? {
        targets(for: recipe, document: document, selectedNodePath: selectedNodePath).first
    }

    private static func supportsComponentInsertion(_ recipe: ComponentInsertionRecipe) -> Bool {
        recipe.supportedInsertionModes.contains(.component) || recipe.supportedInsertionModes.contains(.both)
    }

    private static func appendUnique(
        _ descriptor: DropTargetDescriptor,
        into results: inout [DropTargetDescriptor],
        seen: inout Set<String>
    ) {
        guard seen.insert(descriptor.id).inserted else { return }
        results.append(descriptor)
    }

    private static func priority(
        of descriptor: DropTargetDescriptor,
        selectedNodePath: SkeletonNodePath?
    ) -> Int {
        guard let selectedNodePath else {
            return descriptor.path.indices.count
        }

        switch descriptor.placement {
        case .intoContainer(let path, _):
            if path == selectedNodePath { return 0 }
            if path == selectedNodePath.parent { return 2 }
        case .afterNode(let path), .beforeNode(let path), .replaceNode(let path):
            if path == selectedNodePath { return 1 }
            if path == selectedNodePath.parent { return 3 }
        case .root:
            if selectedNodePath.isRoot { return 0 }
            return 4
        }

        return 10 + descriptor.path.indices.count
    }
}

enum SkeletonDropApplicator {
    static func apply(
        _ fragment: SkeletonElement,
        placement: DropPlacement,
        to root: SkeletonElement?
    ) -> SkeletonElement? {
        guard let root else {
            return fragment
        }

        switch placement {
        case .root:
            return fragment
        case .intoContainer(let path, let index):
            return SkeletonTreeMutations.insert(fragment, in: root, parentPath: path, at: index)
        case .beforeNode(let path):
            return SkeletonTreeMutations.insertBefore(fragment, in: root, siblingPath: path)
        case .afterNode(let path):
            return SkeletonTreeMutations.insertAfter(fragment, in: root, siblingPath: path)
        case .replaceNode(let path):
            return SkeletonTreeMutations.replace(fragment, in: root, at: path)
        }
    }
}
