import Foundation
import CellBase

enum CellConfigurationEndpointRetargeting {
    static func rewritingEndpoints(
        in configuration: CellConfiguration,
        transform: (String) -> String
    ) -> CellConfiguration {
        guard let data = try? JSONEncoder().encode(configuration),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let rewrittenObject = rewriteJSONValue(jsonObject, transform: transform),
              JSONSerialization.isValidJSONObject(rewrittenObject),
              let rewrittenData = try? JSONSerialization.data(withJSONObject: rewrittenObject),
              let rewrittenConfiguration = try? JSONDecoder().decode(CellConfiguration.self, from: rewrittenData)
        else {
            return configuration
        }

        return rewrittenConfiguration
    }

    private static func rewriteJSONValue(
        _ value: Any,
        transform: (String) -> String
    ) -> Any? {
        switch value {
        case let string as String:
            return rewriteStringIfEndpointLike(string, transform: transform)
        case let dictionary as [String: Any]:
            var rewritten: [String: Any] = [:]
            rewritten.reserveCapacity(dictionary.count)
            for (key, childValue) in dictionary {
                rewritten[key] = rewriteJSONValue(childValue, transform: transform) ?? childValue
            }
            return rewritten
        case let array as [Any]:
            return array.map { rewriteJSONValue($0, transform: transform) ?? $0 }
        default:
            return value
        }
    }

    private static func rewriteStringIfEndpointLike(
        _ value: String,
        transform: (String) -> String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("cell://") else {
            return value
        }

        let rewritten = transform(trimmed)
        guard rewritten != trimmed else {
            return value
        }

        let prefixLength = value.distance(
            from: value.startIndex,
            to: value.range(of: trimmed)?.lowerBound ?? value.startIndex
        )
        let suffixLength = value.distance(
            from: value.range(of: trimmed)?.upperBound ?? value.endIndex,
            to: value.endIndex
        )

        let prefix = value.prefix(prefixLength)
        let suffix = value.suffix(suffixLength)
        return "\(prefix)\(rewritten)\(suffix)"
    }
}
