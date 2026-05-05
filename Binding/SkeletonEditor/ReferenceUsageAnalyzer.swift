import Foundation
import CellBase

struct ReferenceUsageReport {
    var referencedLabels: Set<String>
    var unusedTopLevelLabels: Set<String>
}

enum ReferenceUsageAnalyzer {
    private static let referenceSensitiveKeys: Set<String> = [
        "keypath",
        "sourceKeypath",
        "targetKeypath",
        "valueKeypath",
        "stateKeypath",
        "actionKeypath",
        "topic",
        "url",
        "selectionValueKeypath",
        "selectionStateKeypath",
        "selectionActionKeypath",
        "activationActionKeypath"
    ]

    static func pruneNewlyUnusedReferences(
        from references: [CellReference],
        previousSkeleton: SkeletonElement?,
        updatedSkeleton: SkeletonElement?
    ) -> [CellReference] {
        let previousReport = analyze(skeleton: previousSkeleton, references: references)
        let updatedReport = analyze(skeleton: updatedSkeleton, references: references)
        let labelsToRemove = previousReport.referencedLabels.subtracting(updatedReport.referencedLabels)
        guard !labelsToRemove.isEmpty else { return references }

        return references.filter { reference in
            !labelsToRemove.contains(reference.label.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    static func analyze(
        skeleton: SkeletonElement?,
        references: [CellReference]
    ) -> ReferenceUsageReport {
        let referenceValues = referencedValues(in: skeleton)
        let topLevelLabels = topLevelLabelSet(from: references)

        let referencedLabels = Set(topLevelLabels.filter { label in
            referenceValues.contains { value in
                matchesReferenceLabel(label, in: value)
            }
        })

        return ReferenceUsageReport(
            referencedLabels: referencedLabels,
            unusedTopLevelLabels: topLevelLabels.subtracting(referencedLabels)
        )
    }

    static func matchingTopLevelLabels(
        for element: SkeletonElement,
        references: [CellReference]
    ) -> Set<String> {
        let topLevelLabels = topLevelLabelSet(from: references)
        guard !topLevelLabels.isEmpty else { return [] }

        let referenceValues = referencedValues(in: element)
        return Set(topLevelLabels.filter { label in
            referenceValues.contains { value in
                matchesReferenceLabel(label, in: value)
            }
        })
    }

    private static func topLevelLabelSet(from references: [CellReference]) -> Set<String> {
        Set(
            references
                .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private static func matchesReferenceLabel(_ label: String, in value: String) -> Bool {
        value == label ||
        value.hasPrefix(label + ".") ||
        value.contains("cell:///Porthole/\(label).")
    }

    private static func referencedValues(in skeleton: SkeletonElement?) -> [String] {
        guard let skeleton,
              let rawObject = rawObject(from: skeleton)
        else {
            return []
        }

        var collected: [String] = []
        collectValues(from: rawObject, into: &collected)
        return collected
    }

    private static func referencedValues(in element: SkeletonElement) -> [String] {
        guard let rawObject = rawObject(from: element) else { return [] }
        var collected: [String] = []
        collectValues(from: rawObject, into: &collected)
        return collected
    }

    private static func rawObject<T: Encodable>(from value: T) -> Any? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func collectValues(from value: Any, into collected: inout [String]) {
        switch value {
        case let dictionary as [String: Any]:
            for (key, child) in dictionary {
                if let stringValue = child as? String,
                   referenceSensitiveKeys.contains(key) {
                    collected.append(stringValue)
                } else {
                    collectValues(from: child, into: &collected)
                }
            }
        case let array as [Any]:
            for child in array {
                collectValues(from: child, into: &collected)
            }
        default:
            break
        }
    }
}
