import Foundation
@preconcurrency import CellBase
import HavenAgentCells
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
    public var documentRootPath: String
    public var recordedAt: String
    public var cells: [RegisteredCell]

    public init(
        instanceName: String,
        status: String,
        ownerUUID: String,
        ownerDisplayName: String,
        documentRootPath: String,
        recordedAt: String,
        cells: [RegisteredCell]
    ) {
        self.instanceName = instanceName
        self.status = status
        self.ownerUUID = ownerUUID
        self.ownerDisplayName = ownerDisplayName
        self.documentRootPath = documentRootPath
        self.recordedAt = recordedAt
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
    }

    public func start(instanceName: String) async throws -> AgentCellRuntimeSnapshot {
        if currentSnapshot?.instanceName == instanceName, !activeRegistrations.isEmpty {
            return try await writeSnapshot(status: "running", instanceName: instanceName)
        }
        if currentSnapshot != nil {
            await stop()
        }

        _ = try bootstrap.bootstrap(paths: paths)

        let vault = LocalIdentityVault()
        let ownerContext = "haven.agent.owner.\(instanceName)"
        guard let owner = await vault.identity(for: ownerContext, makeNewIfNotFound: true) else {
            throw AgentCellRuntimeHostError.ownerIdentityUnavailable(instanceName)
        }

        let previousGlobals = CellBaseGlobals(
            defaultIdentityVault: CellBase.defaultIdentityVault,
            defaultCellResolver: CellBase.defaultCellResolver,
            documentRootPath: CellBase.documentRootPath
        )
        installedGlobals = previousGlobals
        CellBase.defaultIdentityVault = vault
        CellBase.defaultCellResolver = resolver
        CellBase.documentRootPath = paths.cellDocumentDirectory.path

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
        return try await writeSnapshot(status: "running", instanceName: instanceName, owner: owner)
    }

    public func stop() async {
        let instanceName = currentSnapshot?.instanceName ?? "unknown"
        let ownerUUID = currentSnapshot?.ownerUUID ?? "unknown"
        let ownerDisplayName = currentSnapshot?.ownerDisplayName ?? "unknown"

        for registration in activeRegistrations {
            await resolver.unregisterEmitCell(uuid: registration.cell.uuid)
        }
        activeRegistrations.removeAll()

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
            documentRootPath: paths.cellDocumentDirectory.path,
            recordedAt: Self.iso8601String(Date()),
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
        owner: Identity? = nil
    ) async throws -> AgentCellRuntimeSnapshot {
        let ownerUUID = owner?.uuid ?? currentSnapshot?.ownerUUID ?? "unknown"
        let ownerDisplayName = owner?.displayName ?? currentSnapshot?.ownerDisplayName ?? "unknown"
        let snapshot = AgentCellRuntimeSnapshot(
            instanceName: instanceName,
            status: status,
            ownerUUID: ownerUUID,
            ownerDisplayName: ownerDisplayName,
            documentRootPath: paths.cellDocumentDirectory.path,
            recordedAt: Self.iso8601String(Date()),
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
