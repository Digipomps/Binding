import Foundation
import CellBase

struct EditorDocument {
    var configuration: CellConfiguration

    init(configuration: CellConfiguration, fallbackSkeleton: SkeletonElement? = nil) {
        var normalized = configuration
        if normalized.skeleton == nil {
            normalized.skeleton = fallbackSkeleton
        }
        self.configuration = normalized
    }

    var skeleton: SkeletonElement? {
        get { configuration.skeleton }
        set { configuration.skeleton = newValue }
    }
}
