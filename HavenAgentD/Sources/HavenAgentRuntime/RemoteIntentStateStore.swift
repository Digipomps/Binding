import Foundation

public struct PersistedRemoteIntentState: Codable, Equatable, Sendable {
    public var queuedIntents: [QueuedRemoteIntent]
    public var seenNonces: [String]
    public var auditTrail: [RemoteIntentAuditRecord]
    public var recordedAt: String

    public init(
        queuedIntents: [QueuedRemoteIntent],
        seenNonces: [String],
        auditTrail: [RemoteIntentAuditRecord],
        recordedAt: String
    ) {
        self.queuedIntents = queuedIntents
        self.seenNonces = seenNonces
        self.auditTrail = auditTrail
        self.recordedAt = recordedAt
    }
}

public actor RemoteIntentStateStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func load() throws -> PersistedRemoteIntentState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(PersistedRemoteIntentState.self, from: data)
    }

    public func write(_ state: PersistedRemoteIntentState) throws {
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: fileURL, options: [.atomic])
    }
}
