import Foundation
@_spi(CellRuntimeRecovery) @preconcurrency import CellBase
import CellVapor
import CryptoKit
import HavenAgentCells
import HavenAgentRuntime
import HavenMacAutomation
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
    var typedCellUtility: TypedCellProtocol?
    var resolverTypedCellUtility: TypedCellUtility?
    var persistedCellMasterKey: Data?
}

private struct ActiveCellRegistration {
    var descriptor: AgentCellDescriptor
    var cell: GeneralCell
}

private actor AgentCellRuntimeGlobalStateLock {
    static let shared = AgentCellRuntimeGlobalStateLock()

    private var activeToken: UUID?
    private var waiters: [CheckedContinuation<UUID, Never>] = []

    func acquire() async -> UUID {
        if activeToken == nil {
            let token = UUID()
            activeToken = token
            return token
        }

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release(_ token: UUID) {
        guard activeToken == token else {
            return
        }
        guard waiters.isEmpty == false else {
            activeToken = nil
            return
        }

        let nextToken = UUID()
        activeToken = nextToken
        let continuation = waiters.removeFirst()
        continuation.resume(returning: nextToken)
    }
}

/// Carries the (non-Sendable) cell into the service's `@Sendable` sink. The cell
/// is only ever touched through its own async API, so the unchecked assertion is
/// sound for this single-owner hand-off.
private struct SentinelCellBox: @unchecked Sendable {
    let cell: NetworkSentinelCell
}

private struct LocalModelCellBox: @unchecked Sendable {
    let cell: AgentLocalModelCell
    let owner: Identity
}

private struct EntityAnchorCellBox: @unchecked Sendable {
    let cell: EntityAnchorCell
    let owner: Identity
}

private actor AgentCellRuntimeSnapshotStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

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

    func read() throws -> AgentCellRuntimeSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try decoder.decode(
            AgentCellRuntimeSnapshot.self,
            from: Data(contentsOf: fileURL, options: [.mappedIfSafe])
        )
    }
}

public enum AgentCellRuntimeHostError: Error, LocalizedError, Sendable {
    case ownerIdentityUnavailable(String)
    case entityAnchorRecoveryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .ownerIdentityUnavailable(let instanceName):
            return "Unable to create or load a local owner identity for instance '\(instanceName)'."
        case .entityAnchorRecoveryFailed(let detail):
            return "Unable to recover the persistent local EntityAnchor: \(detail)"
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
    private var entityAnchorBox: EntityAnchorCellBox?
    private var networkSentinelService: NetworkSentinelService?
    private var globalStateLockToken: UUID?

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
        configURL: URL? = nil,
        controlBridge configuration: LocalControlBridgeConfig? = nil,
        networkSentinel: NetworkSentinelConfig? = nil,
        automationPolicy: AutomationPolicy? = nil,
        mailDraftCommandHandler: (@Sendable (AgentMailDraftCommandRequest) async throws -> AgentMailDraftCommandResult)? = nil,
        signStatementCommandHandler: (@Sendable (AgentSignStatementRequest) async throws -> AgentSignStatementResult)? = nil
    ) async throws -> AgentCellRuntimeSnapshot {
        if currentSnapshot?.instanceName == instanceName, !activeRegistrations.isEmpty {
            return try await writeSnapshot(status: "running", instanceName: instanceName)
        }
        if currentSnapshot != nil {
            await stop()
        }

        globalStateLockToken = await AgentCellRuntimeGlobalStateLock.shared.acquire()
        do {
            _ = try bootstrap.bootstrap(paths: paths)
            let persistedRuntimeSnapshot = try await snapshotStore.read()
            await AgentRuntimeBridge.shared.configure(pairingArtifactFileURL: paths.pairingArtifactFile)

            let identityStore = AgentIdentityStore(fileURL: paths.agentIdentityFile)
            let identityMaterial = try await identityStore.loadOrCreate(instanceName: instanceName)
            let identityPrivateKey = try identityMaterial.privateKey()
            let vault = LocalIdentityVault()
            let owner = await vault.installIdentity(
                descriptor: identityMaterial.descriptor,
                privateKey: identityPrivateKey
            )
            SecretCredentialCell.metadataStoreFactory = { [paths] in
                FileSecretCredentialMetadataStore(
                    fileURL: paths.stateDirectory.appendingPathComponent("secret-credentials.json")
                )
            }

            let previousGlobals = CellBaseGlobals(
                defaultIdentityVault: CellBase.defaultIdentityVault,
                defaultCellResolver: CellBase.defaultCellResolver,
                documentRootPath: CellBase.documentRootPath,
                typedCellUtility: CellBase.typedCellUtility,
                resolverTypedCellUtility: resolver.tcUtility,
                persistedCellMasterKey: CellBase.persistedCellMasterKey
            )
            installedGlobals = previousGlobals
            CellBase.defaultIdentityVault = vault
            CellBase.defaultCellResolver = resolver
            CellBase.documentRootPath = paths.cellDocumentDirectory.path
            var persistenceKeyMaterial = Data(
                "haven-agentd.cell-persistence-master.v1\u{0}".utf8
            )
            persistenceKeyMaterial.append(identityPrivateKey.rawRepresentation)
            CellBase.persistedCellMasterKey = Data(
                SHA256.hash(data: persistenceKeyMaterial)
            )
            let typedCellUtility = TypedCellUtility(storage: FileSystemCellStorage())
            CellBase.typedCellUtility = typedCellUtility
            resolver.tcUtility = typedCellUtility
            try await resolver.registerDefaultWebSocketBridgeTransports()

            let entityAnchorName = "EntityAnchor"
            let registrySnapshot = await resolver.resolverRegistrySnapshot(requester: owner)
            if let registeredResolve = registrySnapshot.resolves.first(where: { $0.name == entityAnchorName }) {
                guard registeredResolve.cellType == String(describing: EntityAnchorCell.self),
                      registeredResolve.cellScope == .identityUnique,
                      registeredResolve.persistancy == .persistant,
                      registeredResolve.identityDomain == identityMaterial.descriptor.identityContext else {
                    throw AgentCellRuntimeHostError.entityAnchorRecoveryFailed(
                        "the existing resolver contract does not match the agent EntityAnchor contract"
                    )
                }
                try typedCellUtility.register(
                    name: String(describing: EntityAnchorCell.self),
                    type: EntityAnchorCell.self
                )
            } else {
                try await resolver.addCellResolve(
                    name: entityAnchorName,
                    cellScope: .identityUnique,
                    persistency: .persistant,
                    identityDomain: identityMaterial.descriptor.identityContext,
                    type: EntityAnchorCell.self
                )
            }

            var expectedRecoveredEntityAnchorUUID: String?
            if let persistedRuntimeSnapshot,
               let persistedCell = persistedRuntimeSnapshot.cells.first(where: {
                   $0.endpoint == "cell:///\(entityAnchorName)"
               }) {
                guard persistedRuntimeSnapshot.instanceName == instanceName,
                      persistedRuntimeSnapshot.ownerUUID == owner.uuid,
                      persistedRuntimeSnapshot.ownerPublicKeyBase64URL == identityMaterial.descriptor.publicKeyBase64URL,
                      persistedRuntimeSnapshot.documentRootPath == paths.cellDocumentDirectory.path,
                      UUID(uuidString: persistedCell.uuid) != nil else {
                    throw AgentCellRuntimeHostError.entityAnchorRecoveryFailed(
                        "the persisted runtime manifest is not bound to the active agent identity and storage root"
                    )
                }

                switch await resolver.loadTypedEmitCellResult(with: persistedCell.uuid) {
                case .loaded(let loaded):
                    guard let persistedEntityAnchor = loaded as? EntityAnchorCell,
                          persistedEntityAnchor.cellScope == .identityUnique,
                          persistedEntityAnchor.persistancy == .persistant else {
                        throw AgentCellRuntimeHostError.entityAnchorRecoveryFailed(
                            "the persisted Cell does not prove the expected type, scope, and persistence"
                        )
                    }
                    let persistedOwner = try await persistedEntityAnchor.getOwner(requester: owner)
                    guard persistedOwner.uuid == owner.uuid,
                          persistedOwner.signingPublicKeyFingerprint == owner.signingPublicKeyFingerprint else {
                        throw AgentCellRuntimeHostError.entityAnchorRecoveryFailed(
                            "the persisted Cell owner does not match the active agent identity"
                        )
                    }
                    _ = try await resolver.restoreIdentityNamedCellsFillingGaps(
                        [owner.uuid: [entityAnchorName: persistedCell.uuid]],
                        requester: owner,
                        authorization: CellResolverRecoveryAuthorization()
                    )
                    expectedRecoveredEntityAnchorUUID = persistedCell.uuid
                case .missing:
                    break
                case .unavailable:
                    throw AgentCellRuntimeHostError.entityAnchorRecoveryFailed(
                        "the persisted Cell exists but could not be decoded or decrypted"
                    )
                }
            }

            let resolvedEntityAnchor: EntityAnchorCell
            do {
                guard let existing = try await resolver.cellAtEndpoint(
                    endpoint: "cell:///\(entityAnchorName)",
                    requester: owner
                ) as? EntityAnchorCell else {
                    throw CellBaseError.noTargetCell
                }
                resolvedEntityAnchor = existing
            } catch let initialResolutionError {
                throw initialResolutionError
            }
            if let expectedRecoveredEntityAnchorUUID,
               resolvedEntityAnchor.uuid != expectedRecoveredEntityAnchorUUID {
                throw AgentCellRuntimeHostError.entityAnchorRecoveryFailed(
                    "the resolver returned a different Cell than the validated runtime manifest"
                )
            }
            entityAnchorBox = EntityAnchorCellBox(cell: resolvedEntityAnchor, owner: owner)

            var registrations: [ActiveCellRegistration] = []
            for descriptor in AgentCellRegistry.hostedRuntimeDescriptors {
                if descriptor.kind == .entityAnchor {
                    registrations.append(
                        ActiveCellRegistration(
                            descriptor: descriptor,
                            cell: resolvedEntityAnchor
                        )
                    )
                    continue
                }
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
            if let localModelCell = registrations
                .first(where: { $0.descriptor.kind == .localModel })?.cell as? AgentLocalModelCell {
                let box = LocalModelCellBox(cell: localModelCell, owner: owner)
                await AgentRuntimeBridge.shared.update(
                    localModelProviderID: AgentLocalModelCell.backendConfigFactory().providerID
                )
                await AgentRuntimeBridge.shared.update(localModelReverseIntentHandler: { request in
                    let backend = AgentLocalModelCell.backendConfigFactory()
                    guard request.providerID == backend.providerID else {
                        return .object([
                            "status": .string("providerUnavailable"),
                            "requestedProviderID": .string(request.providerID),
                            "providerID": .string(backend.providerID),
                            "error": .string("The requested provider is not served by this AgentD runtime.")
                        ])
                    }
                    do {
                        return try await box.cell.set(
                            keypath: "llm.generate",
                            value: request.cellValue,
                            requester: box.owner
                        ) ?? .object(["status": .string("emptyResponse")])
                    } catch {
                        return .object([
                            "status": .string("failed"),
                            "error": .string(error.localizedDescription)
                        ])
                    }
                })
            }
            await startNetworkSentinel(registrations: registrations, config: networkSentinel ?? NetworkSentinelConfig())
            let controlBridgeStatus: LocalControlBridgeStatus?
            if let configuration {
                let resolvedMailDraftCommandHandler: (@Sendable (AgentMailDraftCommandRequest) async throws -> AgentMailDraftCommandResult)?
                if let mailDraftCommandHandler {
                    resolvedMailDraftCommandHandler = mailDraftCommandHandler
                } else if let automationPolicy {
                    let service = AgentMailDraftCommandService(policy: automationPolicy)
                    resolvedMailDraftCommandHandler = { request in
                        try await service.composeDraft(request)
                    }
                } else {
                    resolvedMailDraftCommandHandler = nil
                }
                let resolvedSignStatementCommandHandler: (@Sendable (AgentSignStatementRequest) async throws -> AgentSignStatementResult)?
                if let signStatementCommandHandler {
                    resolvedSignStatementCommandHandler = signStatementCommandHandler
                } else {
                    let nonceStore = AgentSignatureNonceStore(
                        fileURL: paths.stateDirectory.appendingPathComponent("identity-signature-nonces.json")
                    )
                    let service = AgentSignStatementCommandService(
                        owner: owner,
                        identityDescriptor: identityMaterial.descriptor,
                        nonceStore: nonceStore
                    )
                    resolvedSignStatementCommandHandler = { request in
                        try await service.signStatement(request)
                    }
                }
                do {
                    controlBridgeStatus = try await controlBridgeServer.start(
                        owner: owner,
                        configuration: configuration,
                        paths: paths,
                        configURL: configURL ?? paths.configFile,
                        mailDraftCommandHandler: resolvedMailDraftCommandHandler,
                        signStatementCommandHandler: resolvedSignStatementCommandHandler,
                        runtimeSnapshotProvider: { [weak self] in
                            await self?.snapshot()
                        }
                    )
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
        } catch {
            await stop()
            throw error
        }
    }

    public func stop() async {
        if let networkSentinelService {
            await networkSentinelService.stop()
        }
        networkSentinelService = nil
        await AgentRuntimeBridge.shared.update(networkSentinelControl: nil)
        await AgentRuntimeBridge.shared.update(localModelReverseIntentHandler: nil)
        await AgentRuntimeBridge.shared.update(localModelProviderID: nil)

        let instanceName = currentSnapshot?.instanceName ?? "unknown"
        let ownerUUID = currentSnapshot?.ownerUUID ?? "unknown"
        let ownerDisplayName = currentSnapshot?.ownerDisplayName ?? "unknown"
        let ownerPublicKeyBase64URL = currentSnapshot?.ownerPublicKeyBase64URL ?? ""
        let ownerDidKey = currentSnapshot?.ownerDidKey ?? ownerUUID
        let persistedCellManifest = currentSnapshot?.cells.filter {
            $0.endpoint == "cell:///EntityAnchor"
        } ?? []

        for registration in activeRegistrations {
            await resolver.unregisterEmitCell(uuid: registration.cell.uuid)
        }
        activeRegistrations.removeAll()
        entityAnchorBox = nil
        await controlBridgeServer.stop()
        await AgentRuntimeBridge.shared.update(localControlBridgeStatus: await controlBridgeServer.snapshot())
        await AgentRuntimeBridge.shared.update(agentIdentityDescriptor: nil)
        await AgentRuntimeBridge.shared.configure(pairingArtifactFileURL: nil)

        if let installedGlobals {
            CellBase.defaultIdentityVault = installedGlobals.defaultIdentityVault
            CellBase.defaultCellResolver = installedGlobals.defaultCellResolver
            CellBase.documentRootPath = installedGlobals.documentRootPath
            CellBase.typedCellUtility = installedGlobals.typedCellUtility
            resolver.tcUtility = installedGlobals.resolverTypedCellUtility
            CellBase.persistedCellMasterKey = installedGlobals.persistedCellMasterKey
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
            cells: persistedCellManifest
        )
        currentSnapshot = stoppedSnapshot
        try? await snapshotStore.write(stoppedSnapshot)

        if let globalStateLockToken {
            await AgentCellRuntimeGlobalStateLock.shared.release(globalStateLockToken)
            self.globalStateLockToken = nil
        }
    }

    public func snapshot() -> AgentCellRuntimeSnapshot? {
        currentSnapshot
    }

    public func persistValidatedContact(
        _ input: AgentValidatedContactStoreInput
    ) async throws -> AgentValidatedContactStoreReceipt {
        guard let entityAnchorBox else {
            throw AgentValidatedContactStoreError.runtimeUnavailable
        }
        return try await Task.detached {
            let record = input.recordValue()
            let receipt = try await EntityValidatedContactPersistence.persist(
                entityAnchor: entityAnchorBox.cell,
                identity: entityAnchorBox.owner,
                relationID: input.relationID,
                record: record,
                sourceUUID: "haven-agentd:\(entityAnchorBox.owner.uuid)"
            )
            return AgentValidatedContactStoreReceipt(
                relationID: input.relationID,
                keypath: EntityValidatedContactRecordV1.keypath(relationID: input.relationID),
                partitionID: receipt.partitionID,
                epoch: receipt.epoch,
                revision: receipt.revision,
                entryHash: receipt.entryHash,
                payloadHash: receipt.payloadHash,
                authorityCellUUID: receipt.authorityCellUUID,
                authorityIdentityUUID: receipt.authorityIdentityUUID,
                committedAtEpochMilliseconds: receipt.committedAtEpochMilliseconds,
                durabilityLevel: receipt.durabilityLevel,
                replicationState: receipt.replicationState,
                quorumSatisfied: receipt.quorumSatisfied,
                distributedCommit: receipt.distributedCommit,
                storageAuthorized: true,
                disclosureAuthorized: false,
                readAfterReloadVerified: true
            )
        }.value
    }

    public func verifyValidatedContact(
        _ input: AgentValidatedContactStoreInput
    ) async throws -> AgentValidatedContactVerification {
        guard let entityAnchorBox else {
            throw AgentValidatedContactStoreError.runtimeUnavailable
        }
        let matches = try await Task.detached {
            let stored = try await entityAnchorBox.cell.get(
                keypath: EntityValidatedContactRecordV1.keypath(relationID: input.relationID),
                requester: entityAnchorBox.owner
            )
            return ExploreContractValidator.deepEqual(stored, input.recordValue())
        }.value
        return AgentValidatedContactVerification(
            relationID: input.relationID,
            keypath: EntityValidatedContactRecordV1.keypath(relationID: input.relationID),
            matchesAuthorizedRecord: matches,
            storageAuthorized: true,
            disclosureAuthorized: false
        )
    }

    func validatedContactMatches(_ input: AgentValidatedContactStoreInput) async throws -> Bool {
        try await verifyValidatedContact(input).matchesAuthorizedRecord
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

    /// Constructs the native measurement service for the hosted
    /// NetworkSentinelCell, wires its sink to (1) the cell's FlowElement emission
    /// and (2) the macOS notification dispatcher, registers it as the bridge
    /// control surface for runtime toggles, and starts it.
    private func startNetworkSentinel(
        registrations: [ActiveCellRegistration],
        config: NetworkSentinelConfig
    ) async {
        guard config.enabled else { return }
        guard let registration = registrations.first(where: { $0.descriptor.kind == .networkSentinel }),
              let cell = registration.cell as? NetworkSentinelCell else {
            return
        }
        let captureDirectory = paths.outputDirectory.appendingPathComponent("network-captures", isDirectory: true)
        let service = NetworkSentinelService(
            interface: config.interface,
            thresholds: config.thresholds,
            intervalSeconds: config.intervalSeconds,
            probeMonitoringEnabled: config.probeMonitoringEnabled,
            probeKind: config.probeKind,
            probeTarget: config.probeTarget,
            probeTimeoutSeconds: config.probeTimeoutSeconds,
            notificationsEnabled: config.notificationsEnabled,
            captureDirectory: captureDirectory,
            captureEnabled: config.captureEnabled,
            captureDurationSeconds: config.captureDurationSeconds,
            capturePacketLimit: config.capturePacketLimit,
            captureSnaplen: config.captureSnaplen
        )
        let cellBox = SentinelCellBox(cell: cell)
        let dispatcher = NetworkAlertNotificationDispatcher()
        await service.setSink { snapshot, transition in
            await cellBox.cell.emitNetworkEvent(snapshot: snapshot, transition: transition)
            await dispatcher.handle(snapshot: snapshot, transition: transition)
        }
        await AgentRuntimeBridge.shared.update(networkSentinelControl: service)
        await service.start()
        networkSentinelService = service
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func registrationName(for endpoint: String) -> String {
        endpoint.replacingOccurrences(of: "cell:///", with: "")
    }
}
