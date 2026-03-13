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
        let topLevelLabels = Set(
            references
                .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        let referencedLabels = Set(topLevelLabels.filter { label in
            referenceValues.contains { value in
                value == label ||
                value.hasPrefix(label + ".") ||
                value.contains("cell:///Porthole/\(label).")
            }
        })

        return ReferenceUsageReport(
            referencedLabels: referencedLabels,
            unusedTopLevelLabels: topLevelLabels.subtracting(referencedLabels)
        )
    }

    private static func referencedValues(in skeleton: SkeletonElement?) -> [String] {
        guard let skeleton,
              let data = try? JSONEncoder().encode(skeleton),
              let rawObject = try? JSONSerialization.jsonObject(with: data)
        else {
            return []
        }

        var collected: [String] = []
        collectValues(from: rawObject, into: &collected)
        return collected
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
