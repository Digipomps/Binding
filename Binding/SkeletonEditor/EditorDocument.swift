import Foundation
import CellBase

struct EditorSourceBackedContext {
    var committedSourceRevision: Int?
    var hasStoredOverride: Bool = false
    var canEdit: Bool
    var sourceCellEndpoint: String
    var sourceCellName: String
    var accessSummary: String

    var sourceLabel: String {
        let trimmedName = sourceCellName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? sourceCellEndpoint : trimmedName
    }

    var readOnlyMessage: String {
        let summary = accessSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if summary.isEmpty {
            return "Denne source-backed CellConfiguration er read-only for den aktive requesteren i Porthole."
        }
        return "Denne source-backed CellConfiguration er read-only for den aktive requesteren i Porthole. \(summary)"
    }
}

struct EditorDocument {
    var configuration: CellConfiguration
    var sourceBackedContext: EditorSourceBackedContext?

    init(
        configuration: CellConfiguration,
        sourceBackedContext: EditorSourceBackedContext? = nil,
        fallbackSkeleton: SkeletonElement? = nil
    ) {
        var normalized = configuration
        if normalized.skeleton == nil {
            normalized.skeleton = fallbackSkeleton
        }
        self.configuration = normalized
        self.sourceBackedContext = sourceBackedContext
    }

    var skeleton: SkeletonElement? {
        get { configuration.skeleton }
        set { configuration.skeleton = newValue }
    }
}
