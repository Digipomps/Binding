import Foundation
import CellBase

struct ReferenceMergeResult {
    var mergedReferences: [CellReference]
    var rewrittenFragment: SkeletonElement
    var insertedLabelsByEndpoint: [String: String]
}

enum ReferenceMergeService {
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

    static func merge(
        recipeReferences: [CellReference],
        into existing: [CellReference],
        fragment: SkeletonElement
    ) -> ReferenceMergeResult {
        var merged = existing
        var labelRewrites: [String: String] = [:]
        var insertedLabelsByEndpoint: [String: String] = [:]

        for recipeReference in recipeReferences {
            let endpointKey = endpointIdentity(recipeReference.endpoint)
            let preferredLabel = trimmedLabel(recipeReference.label)

            if let existingIndex = merged.firstIndex(where: { endpointIdentity($0.endpoint) == endpointKey }) {
                let existingLabel = trimmedLabel(merged[existingIndex].label)
                let resolvedLabel = existingLabel.isEmpty ? preferredLabel : existingLabel
                if existingLabel.isEmpty, !resolvedLabel.isEmpty {
                    merged[existingIndex].label = resolvedLabel
                }
                if !preferredLabel.isEmpty, preferredLabel != resolvedLabel {
                    labelRewrites[preferredLabel] = resolvedLabel
                }
                insertedLabelsByEndpoint[endpointKey] = resolvedLabel
                continue
            }

            var inserted = recipeReference
            let uniqueLabel = makeUniqueLabel(preferredLabel, occupiedLabels: Set(merged.map { trimmedLabel($0.label).lowercased() }))
            inserted.label = uniqueLabel
            if !preferredLabel.isEmpty, preferredLabel != uniqueLabel {
                labelRewrites[preferredLabel] = uniqueLabel
            }
            merged.append(inserted)
            insertedLabelsByEndpoint[endpointKey] = uniqueLabel
        }

        let rewrittenFragment = rewrite(fragment: fragment, labelRewrites: labelRewrites) ?? fragment
        return ReferenceMergeResult(
            mergedReferences: merged,
            rewrittenFragment: rewrittenFragment,
            insertedLabelsByEndpoint: insertedLabelsByEndpoint
        )
    }

    private static func makeUniqueLabel(_ preferred: String, occupiedLabels: Set<String>) -> String {
        let base = preferred.isEmpty ? "component" : preferred
        let loweredBase = base.lowercased()
        guard occupiedLabels.contains(loweredBase) else { return base }

        for suffix in 2 ... 99 {
            let candidate = "\(base)\(suffix)"
            if !occupiedLabels.contains(candidate.lowercased()) {
                return candidate
            }
        }
        return "\(base)-\(UUID().uuidString.prefix(4))"
    }

    private static func rewrite(fragment: SkeletonElement, labelRewrites: [String: String]) -> SkeletonElement? {
        guard !labelRewrites.isEmpty,
              let data = try? JSONEncoder().encode(fragment),
              let rawObject = try? JSONSerialization.jsonObject(with: data),
              let rewrittenObject = rewrite(jsonValue: rawObject, labelRewrites: labelRewrites),
              JSONSerialization.isValidJSONObject(rewrittenObject),
              let rewrittenData = try? JSONSerialization.data(withJSONObject: rewrittenObject)
        else {
            return fragment
        }

        return try? JSONDecoder().decode(SkeletonElement.self, from: rewrittenData)
    }

    private static func rewrite(jsonValue: Any, labelRewrites: [String: String]) -> Any? {
        switch jsonValue {
        case let dictionary as [String: Any]:
            var rewritten: [String: Any] = [:]
            for (key, value) in dictionary {
                if let stringValue = value as? String,
                   referenceSensitiveKeys.contains(key) {
                    rewritten[key] = rewrite(value: stringValue, forKey: key, labelRewrites: labelRewrites)
                } else {
                    rewritten[key] = rewrite(jsonValue: value, labelRewrites: labelRewrites) ?? value
                }
            }
            return rewritten
        case let array as [Any]:
            return array.map { rewrite(jsonValue: $0, labelRewrites: labelRewrites) ?? $0 }
        default:
            return jsonValue
        }
    }

    private static func rewrite(value: String, forKey key: String, labelRewrites: [String: String]) -> String {
        var rewritten = value
        for (oldLabel, newLabel) in labelRewrites {
            guard !oldLabel.isEmpty, oldLabel != newLabel else { continue }
            if key == "url" {
                rewritten = rewritten.replacingOccurrences(
                    of: "cell:///Porthole/\(oldLabel).",
                    with: "cell:///Porthole/\(newLabel)."
                )
                continue
            }

            if rewritten == oldLabel {
                rewritten = newLabel
            } else if rewritten.hasPrefix(oldLabel + ".") {
                rewritten = newLabel + rewritten.dropFirst(oldLabel.count)
            }
        }
        return rewritten
    }

    private static func trimmedLabel(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func endpointIdentity(_ endpoint: String) -> String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
