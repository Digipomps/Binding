import Foundation

public struct QueuedRemoteIntent: Codable, Equatable, Sendable {
    public var id: String
    public var topic: String
    public var origin: String
    public var actionID: String
    public var arguments: [String: String]
    public var receivedAt: String
    public var issuerID: String?
    public var issuedAt: String?
    public var expiresAt: String?
    public var verificationStatus: String

    public init(
        id: String = UUID().uuidString,
        topic: String,
        origin: String,
        actionID: String,
        arguments: [String: String],
        receivedAt: String,
        issuerID: String? = nil,
        issuedAt: String? = nil,
        expiresAt: String? = nil,
        verificationStatus: String = "local"
    ) {
        self.id = id
        self.topic = topic
        self.origin = origin
        self.actionID = actionID
        self.arguments = arguments
        self.receivedAt = receivedAt
        self.issuerID = issuerID
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.verificationStatus = verificationStatus
    }
}

public actor AgentRuntimeBridge {
    public static let shared = AgentRuntimeBridge()

    private var runtimeState: AgentRuntimeState?
    private var localControlBridgeStatus: LocalControlBridgeStatus?
    private var agentIdentityDescriptor: AgentIdentityDescriptor?
    private var queuedIntents: [QueuedRemoteIntent] = []
    private var remoteIntentPolicy: RemoteIntentPolicy?
    private var remoteIntentExecutor: RemoteIntentExecutionBridge?
    private var personalButlerScheduleService: PersonalButlerScheduleService?
    private var seenRemoteIntentNonces: Set<String> = []
    private var remoteIntentAuditTrail: [RemoteIntentAuditRecord] = []
    private var remoteIntentStateStore: RemoteIntentStateStore?
    private var pairingArtifactFileURL: URL?
    private var pairedOperatorIdentity: PairedOperatorIdentity?
    private var pairingArtifactLastError: String?
    private var networkHealth: NetworkHealthSnapshot?

    public init() {}

    public func update(networkHealth: NetworkHealthSnapshot?) {
        self.networkHealth = networkHealth
    }

    public func networkHealthSnapshot() -> NetworkHealthSnapshot? {
        networkHealth
    }

    private var networkSentinelControl: NetworkSentinelControlling?

    public func update(networkSentinelControl: NetworkSentinelControlling?) {
        self.networkSentinelControl = networkSentinelControl
    }

    public func networkSentinelControlSnapshot() -> NetworkSentinelControlling? {
        networkSentinelControl
    }

    public func update(runtimeState: AgentRuntimeState) {
        self.runtimeState = runtimeState
    }

    public func runtimeStateSnapshot() -> AgentRuntimeState? {
        runtimeState
    }

    public func update(localControlBridgeStatus: LocalControlBridgeStatus?) {
        self.localControlBridgeStatus = localControlBridgeStatus
    }

    public func localControlBridgeStatusSnapshot() -> LocalControlBridgeStatus? {
        localControlBridgeStatus
    }

    public func update(agentIdentityDescriptor: AgentIdentityDescriptor?) {
        self.agentIdentityDescriptor = agentIdentityDescriptor
    }

    public func agentIdentityDescriptorSnapshot() -> AgentIdentityDescriptor? {
        agentIdentityDescriptor
    }

    public func configure(pairingArtifactFileURL: URL?) async {
        self.pairingArtifactFileURL = pairingArtifactFileURL
        await refreshPairedOperatorIdentity()
    }

    public func refreshPairedOperatorIdentity() async {
        guard let pairingArtifactFileURL else {
            pairedOperatorIdentity = nil
            pairingArtifactLastError = nil
            return
        }

        do {
            pairedOperatorIdentity = try AgentPairingArtifactLoader.loadPairedOperator(from: pairingArtifactFileURL)
            pairingArtifactLastError = nil
        } catch {
            pairedOperatorIdentity = nil
            pairingArtifactLastError = error.localizedDescription
        }
    }

    public func pairedOperatorSnapshot(refresh: Bool = false) async -> PairedOperatorIdentity? {
        if refresh {
            await refreshPairedOperatorIdentity()
        }
        return pairedOperatorIdentity
    }

    public func pairingArtifactStatusSnapshot(refresh: Bool = false) async -> (path: String?, lastError: String?) {
        if refresh {
            await refreshPairedOperatorIdentity()
        }
        return (pairingArtifactFileURL?.path, pairingArtifactLastError)
    }

    public func update(remoteIntentPolicy: RemoteIntentPolicy?) {
        self.remoteIntentPolicy = remoteIntentPolicy
    }

    public func remoteIntentPolicySnapshot() -> RemoteIntentPolicy? {
        remoteIntentPolicy
    }

    public func update(remoteIntentExecutor: RemoteIntentExecutionBridge?) {
        self.remoteIntentExecutor = remoteIntentExecutor
    }

    public func remoteIntentExecutorSnapshot() -> RemoteIntentExecutionBridge? {
        remoteIntentExecutor
    }

    public func update(personalButlerScheduleService: PersonalButlerScheduleService?) {
        self.personalButlerScheduleService = personalButlerScheduleService
    }

    public func personalButlerScheduleServiceSnapshot() -> PersonalButlerScheduleService? {
        personalButlerScheduleService
    }

    public func configure(remoteIntentStateStore: RemoteIntentStateStore?) {
        self.remoteIntentStateStore = remoteIntentStateStore
    }

    public func restore(remoteIntentState: PersistedRemoteIntentState) {
        queuedIntents = remoteIntentState.queuedIntents
        seenRemoteIntentNonces = Set(remoteIntentState.seenNonces)
        remoteIntentAuditTrail = remoteIntentState.auditTrail
    }

    public func enqueue(intent: QueuedRemoteIntent) {
        queuedIntents.append(intent)
        Task { await persistRemoteIntentStateIfConfigured() }
    }

    public func queuedIntentSnapshot() -> [QueuedRemoteIntent] {
        queuedIntents
    }

    public func queuedIntent(id: String) -> QueuedRemoteIntent? {
        queuedIntents.first { $0.id == id }
    }

    @discardableResult
    public func removeQueuedIntent(id: String) -> QueuedRemoteIntent? {
        guard let index = queuedIntents.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let removed = queuedIntents.remove(at: index)
        Task { await persistRemoteIntentStateIfConfigured() }
        return removed
    }

    public func recordRemoteIntentNonceIfNew(_ nonce: String) -> Bool {
        let inserted = seenRemoteIntentNonces.insert(nonce).inserted
        if inserted {
            Task { await persistRemoteIntentStateIfConfigured() }
        }
        return inserted
    }

    public func appendRemoteIntentAuditRecord(_ record: RemoteIntentAuditRecord) {
        remoteIntentAuditTrail.append(record)
        Task { await persistRemoteIntentStateIfConfigured() }
    }

    public func remoteIntentAuditSnapshot() -> [RemoteIntentAuditRecord] {
        remoteIntentAuditTrail
    }

    public func clearQueuedIntents() {
        queuedIntents.removeAll()
        Task { await persistRemoteIntentStateIfConfigured() }
    }

    public func resetRemoteIntentState() {
        queuedIntents.removeAll()
        seenRemoteIntentNonces.removeAll()
        remoteIntentAuditTrail.removeAll()
        Task { await persistRemoteIntentStateIfConfigured() }
    }

    public func persistedRemoteIntentStateSnapshot() -> PersistedRemoteIntentState {
        PersistedRemoteIntentState(
            queuedIntents: queuedIntents,
            seenNonces: Array(seenRemoteIntentNonces).sorted(),
            auditTrail: remoteIntentAuditTrail,
            recordedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func persistRemoteIntentStateIfConfigured() async {
        guard let remoteIntentStateStore else {
            return
        }
        let snapshot = persistedRemoteIntentStateSnapshot()
        try? await remoteIntentStateStore.write(snapshot)
    }
}
