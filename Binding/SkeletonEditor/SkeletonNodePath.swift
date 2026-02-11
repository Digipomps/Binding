import Foundation

struct SkeletonNodePath: Hashable, Codable, CustomStringConvertible {
    private(set) var indices: [Int]

    static let root = SkeletonNodePath(indices: [])

    init(indices: [Int] = []) {
        self.indices = indices
    }

    var isRoot: Bool { indices.isEmpty }

    func appending(_ index: Int) -> SkeletonNodePath {
        var copy = indices
        copy.append(index)
        return SkeletonNodePath(indices: copy)
    }

    var parent: SkeletonNodePath? {
        guard !indices.isEmpty else { return nil }
        var copy = indices
        _ = copy.popLast()
        return SkeletonNodePath(indices: copy)
    }

    var description: String {
        if indices.isEmpty { return "root" }
        return indices.map(String.init).joined(separator: ".")
    }
}
