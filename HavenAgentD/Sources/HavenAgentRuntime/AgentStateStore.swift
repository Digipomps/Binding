import Foundation
import HavenRuntimeBootstrap

public struct ExecutedActionRecord: Codable, Equatable, Sendable {
    public var kind: AutomationActionKind
    public var id: String
    public var status: String
    public var recordedAt: String

    public init(kind: AutomationActionKind, id: String, status: String, recordedAt: String) {
        self.kind = kind
        self.id = id
        self.status = status
        self.recordedAt = recordedAt
    }
}

public struct AgentRuntimeState: Codable, Equatable, Sendable {
    public var instanceName: String
    public var status: String
    public var activeWatchIDs: [String]
    public var lastHeartbeatAt: String?
    public var lastEventSummary: String?
    public var lastError: String?
    public var lastExecutedAction: ExecutedActionRecord?
    public var lastSproutBootstrap: SproutBootstrapInvocationRecord?
    public var portholeIngress: PortholeIngressStatus?
    public var bootstrapPlan: SproutBootstrapPlan

    public init(
        instanceName: String,
        status: String,
        activeWatchIDs: [String],
        lastHeartbeatAt: String?,
        lastEventSummary: String?,
        lastError: String?,
        lastExecutedAction: ExecutedActionRecord?,
        lastSproutBootstrap: SproutBootstrapInvocationRecord?,
        portholeIngress: PortholeIngressStatus? = nil,
        bootstrapPlan: SproutBootstrapPlan
    ) {
        self.instanceName = instanceName
        self.status = status
        self.activeWatchIDs = activeWatchIDs
        self.lastHeartbeatAt = lastHeartbeatAt
        self.lastEventSummary = lastEventSummary
        self.lastError = lastError
        self.lastExecutedAction = lastExecutedAction
        self.lastSproutBootstrap = lastSproutBootstrap
        self.portholeIngress = portholeIngress
        self.bootstrapPlan = bootstrapPlan
    }
}

public actor AgentStateStore {
    private let fileURL: URL
    private let encoder: JSONEncoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public func write(_ state: AgentRuntimeState) throws {
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: fileURL, options: [.atomic])
    }
}
