import Foundation
@preconcurrency import CellBase
import HavenAgentCells
import HavenAgentRuntime
import HavenRuntimeBootstrap

public struct AgentCellRuntimeSnapshot: Codable, Equatable, Sendable {
    public struct RegisteredCell: Codable, Equatable, Sendable {
        public var endpoint: String
        public var typeName: String
        public var sideEffectBoundary: String
        public var uuid: String

        public init(endpoint: String, typeName: String, sideEffectBoundary: String, uuid: String) {
            self.endpoint = endpoint
            self.typeName = typeName
            self.sideEffectBoundary = sideEffectBoundary
            self.uuid = uuid
        }
    }

    public var instanceName: String
    public var status: String
    public var ownerUUID: String
    public var ownerDisplayName: String
    public var ownerPublicKeyBase64URL: String
    public var ownerDidKey: String
    public var documentRootPath: String
    public var recordedAt: String
    public var controlBridge: LocalControlBridgeStatus?
    public var cells: [RegisteredCell]

    public init(
        instanceName: String,
        status: String,
        ownerUUID: String,
        ownerDisplayName: String,
        ownerPublicKeyBase64URL: String,
        ownerDidKey: String,
        documentRootPath: String,
        recordedAt: String,
        controlBridge: LocalControlBridgeStatus?,
        cells: [RegisteredCell]
    ) {
        self.instanceName = instanceName
        self.status = status
        self.ownerUUID = ownerUUID
        self.ownerDisplayName = ownerDisplayName
        self.ownerPublicKeyBase64URL = ownerPublicKeyBase64URL
        self.ownerDidKey = ownerDidKey
        self.documentRootPath = documentRootPath
        self.recordedAt = recordedAt
        self.controlBridge = controlBridge
        self.cells = cells
    }
}

private struct CellBaseGlobals {
    var defaultIdentityVault: IdentityVaultProtocol?
    var defaultCellResolver: CellResolverProtocol?
    var documentRootPath: String?
}

private struct ActiveCellRegistration {
    var descriptor: AgentCellDescriptor
    var cell: GeneralCell
}

private actor AgentCellRuntimeSnapshotStore {
    private let fileURL: URL
    private let encoder: JSONEncoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func write(_ snapshot: AgentCellRuntimeSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: fileURL, options: [.atomic])
    }
}

public enum AgentCellRuntimeHostError: Error, LocalizedError, Sendable {
    case ownerIdentityUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .ownerIdentityUnavailable(let instanceName):
            return "Unable to create or load a local owner identity for instance '\(instanceName)'."
        }
    }
}

public actor AgentCellRuntimeHost {
    private let paths: RuntimePaths
    private let bootstrap: RuntimeBootstrap
    private let resolver: CellResolver
    private let snapshotStore: AgentCellRuntimeSnapshotStore
    private let controlBridgeServer: AgentControlBridgeServer

    private var installedGlobals: CellBaseGlobals?
    private var currentSnapshot: AgentCellRuntimeSnapshot?
    private var activeRegistrations: [ActiveCellRegistration] = []

    public init(
        paths: RuntimePaths,
        bootstrap: RuntimeBootstrap = RuntimeBootstrap(),
        resolver: CellResolver = .sharedInstance
    ) {
        self.paths = paths
        self.bootstrap = bootstrap
        self.resolver = resolver
        self.snapshotStore = AgentCellRuntimeSnapshotStore(fileURL: paths.cellRuntimeFile)
        self.controlBridgeServer = AgentControlBridgeServer()
    }

    public func start(
        instanceName: String,
        controlBridge configuration: LocalControlBridgeConfig? = nil
    ) async throws -> AgentCellRuntimeSnapshot {
        if currentSnapshot?.instanceName == instanceName, !activeRegistrations.isEmpty {
            return try await writeSnapshot(status: "running", instanceName: instanceName)
        }
        if currentSnapshot != nil {
            await stop()
        }

        _ = try bootstrap.bootstrap(paths: paths)
        await AgentRuntimeBridge.shared.configure(pairingArtifactFileURL: paths.pairingArtifactFile)

        let identityStore = AgentIdentityStore(fileURL: paths.agentIdentityFile)
        let identityMaterial = try await identityStore.loadOrCreate(instanceName: instanceName)
        let vault = LocalIdentityVault()
        let owner = await vault.installIdentity(
            descriptor: identityMaterial.descriptor,
            privateKey: try identityMaterial.privateKey()
        )

        let previousGlobals = CellBaseGlobals(
            defaultIdentityVault: CellBase.defaultIdentityVault,
            defaultCellResolver: CellBase.defaultCellResolver,
            documentRootPath: CellBase.documentRootPath
        )
        installedGlobals = previousGlobals
        CellBase.defaultIdentityVault = vault
        CellBase.defaultCellResolver = resolver
        CellBase.documentRootPath = paths.cellDocumentDirectory.path
        try await resolver.registerDefaultWebSocketBridgeTransports()

        var registrations: [ActiveCellRegistration] = []
        for descriptor in AgentCellRegistry.concreteDescriptors {
            let cell = try await AgentCellRegistry.instantiate(kind: descriptor.kind, owner: owner)
            let registrationName = Self.registrationName(for: descriptor.endpoint)
            try await resolver.registerNamedEmitCell(
                name: registrationName,
                emitCell: cell,
                scope: .scaffoldUnique,
                identity: owner
            )
            registrations.append(ActiveCellRegistration(descriptor: descriptor, cell: cell))
        }

        activeRegistrations = registrations
        let controlBridgeStatus: LocalControlBridgeStatus?
        if let configuration {
            do {
                controlBridgeStatus = try await controlBridgeServer.start(owner: owner, configuration: configuration)
            } catch {
                controlBridgeStatus = LocalControlBridgeStatus(
                    configuration: configuration,
                    phase: .failed,
                    lastError: error.localizedDescription
                )
            }
        } else {
            controlBridgeStatus = nil
        }

        await AgentRuntimeBridge.shared.update(localControlBridgeStatus: controlBridgeStatus)
        await AgentRuntimeBridge.shared.update(agentIdentityDescriptor: identityMaterial.descriptor)
        return try await writeSnapshot(
            status: "running",
            instanceName: instanceName,
            owner: owner,
            identityDescriptor: identityMaterial.descriptor,
            controlBridge: controlBridgeStatus
        )
    }

    public func stop() async {
        let instanceName = currentSnapshot?.instanceName ?? "unknown"
        let ownerUUID = currentSnapshot?.ownerUUID ?? "unknown"
        let ownerDisplayName = currentSnapshot?.ownerDisplayName ?? "unknown"
        let ownerPublicKeyBase64URL = currentSnapshot?.ownerPublicKeyBase64URL ?? ""
        let ownerDidKey = currentSnapshot?.ownerDidKey ?? ownerUUID

        for registration in activeRegistrations {
            await resolver.unregisterEmitCell(uuid: registration.cell.uuid)
        }
        activeRegistrations.removeAll()
        await controlBridgeServer.stop()
        await AgentRuntimeBridge.shared.update(localControlBridgeStatus: await controlBridgeServer.snapshot())
        await AgentRuntimeBridge.shared.update(agentIdentityDescriptor: nil)
        await AgentRuntimeBridge.shared.configure(pairingArtifactFileURL: nil)

        if let installedGlobals {
            CellBase.defaultIdentityVault = installedGlobals.defaultIdentityVault
            CellBase.defaultCellResolver = installedGlobals.defaultCellResolver
            CellBase.documentRootPath = installedGlobals.documentRootPath
            self.installedGlobals = nil
        }

        let stoppedSnapshot = AgentCellRuntimeSnapshot(
            instanceName: instanceName,
            status: "stopped",
            ownerUUID: ownerUUID,
            ownerDisplayName: ownerDisplayName,
            ownerPublicKeyBase64URL: ownerPublicKeyBase64URL,
            ownerDidKey: ownerDidKey,
            documentRootPath: paths.cellDocumentDirectory.path,
            recordedAt: Self.iso8601String(Date()),
            controlBridge: await controlBridgeServer.snapshot(),
            cells: []
        )
        currentSnapshot = stoppedSnapshot
        try? await snapshotStore.write(stoppedSnapshot)
    }

    public func snapshot() -> AgentCellRuntimeSnapshot? {
        currentSnapshot
    }

    private func writeSnapshot(
        status: String,
        instanceName: String,
        owner: Identity? = nil,
        identityDescriptor: AgentIdentityDescriptor? = nil,
        controlBridge: LocalControlBridgeStatus? = nil
    ) async throws -> AgentCellRuntimeSnapshot {
        let ownerUUID = owner?.uuid ?? currentSnapshot?.ownerUUID ?? "unknown"
        let ownerDisplayName = owner?.displayName ?? currentSnapshot?.ownerDisplayName ?? "unknown"
        let descriptor: AgentIdentityDescriptor?
        if let identityDescriptor {
            descriptor = identityDescriptor
        } else {
            descriptor = await AgentRuntimeBridge.shared.agentIdentityDescriptorSnapshot()
        }
        let ownerPublicKeyBase64URL = descriptor?.publicKeyBase64URL ?? currentSnapshot?.ownerPublicKeyBase64URL ?? ""
        let ownerDidKey = descriptor?.didKey ?? currentSnapshot?.ownerDidKey ?? ownerUUID
        let snapshot = AgentCellRuntimeSnapshot(
            instanceName: instanceName,
            status: status,
            ownerUUID: ownerUUID,
            ownerDisplayName: ownerDisplayName,
            ownerPublicKeyBase64URL: ownerPublicKeyBase64URL,
            ownerDidKey: ownerDidKey,
            documentRootPath: paths.cellDocumentDirectory.path,
            recordedAt: Self.iso8601String(Date()),
            controlBridge: controlBridge ?? currentSnapshot?.controlBridge,
            cells: activeRegistrations.map { registration in
                AgentCellRuntimeSnapshot.RegisteredCell(
                    endpoint: registration.descriptor.endpoint,
                    typeName: registration.descriptor.typeName,
                    sideEffectBoundary: registration.descriptor.sideEffectBoundary,
                    uuid: registration.cell.uuid
                )
            }
        )
        currentSnapshot = snapshot
        try await snapshotStore.write(snapshot)
        return snapshot
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func registrationName(for endpoint: String) -> String {
        endpoint.replacingOccurrences(of: "cell:///", with: "")
    }
}
