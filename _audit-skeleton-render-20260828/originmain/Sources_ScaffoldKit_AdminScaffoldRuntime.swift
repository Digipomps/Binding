// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Vapor
@_spi(CellRuntimeRecovery) import CellBase
import CellVapor
#if os(Linux)
import Glibc
#else
import Darwin
#endif

enum AdminScaffoldConfigurationError: Error, LocalizedError, Equatable {
    case missingStorageRoot
    case missingVaultMasterKey
    case invalidOwnerUUID(String)
    case invalidWebSocketEndpoint(String)
    case missingPublicOrigin
    case invalidPublicOrigin(String)
    case invalidBoolean(key: String, value: String)
    case invalidInteger(key: String, value: String)
    case ownerIdentityUnavailable
    case ownerIdentityIsNotSignable
    case trustedAgentKeyBootstrapFailed(String)
    case missingBridgeKeyring
    case invalidBridgeKeyring
    case legacyBridgeConfiguration(String)
    case missingMetricsToken
    case invalidMetricsToken
    case storageProbeFailed(String)
    case activeServiceLock
    case persistentCellManifestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingStorageRoot:
            return "ADMIN_SCAFFOLD_STORAGE_ROOT is required in production."
        case .missingVaultMasterKey:
            return "CELL_VAULT_MASTER_KEY_B64 or CELL_VAULT_MASTER_KEY_PATH is required in production."
        case .invalidOwnerUUID(let value):
            return "ADMIN_SCAFFOLD_OWNER_UUID is not a valid UUID: \(value)"
        case .invalidWebSocketEndpoint(let value):
            return "ADMIN_SCAFFOLD_WEBSOCKET_ENDPOINT is invalid: \(value)"
        case .missingPublicOrigin:
            return "ADMIN_SCAFFOLD_PUBLIC_ORIGIN is required in production."
        case .invalidPublicOrigin(let value):
            return "ADMIN_SCAFFOLD_PUBLIC_ORIGIN must be an HTTPS origin without path, query, user info, or fragment: \(value)"
        case .invalidBoolean(let key, let value):
            return "\(key) must be true or false, got: \(value)"
        case .invalidInteger(let key, let value):
            return "\(key) is not a valid bounded integer: \(value)"
        case .ownerIdentityUnavailable:
            return "AdminScaffold owner identity is unavailable. Restore the persistent vault or explicitly enable first-boot creation."
        case .ownerIdentityIsNotSignable:
            return "AdminScaffold owner identity is not backed by the configured signing vault."
        case .trustedAgentKeyBootstrapFailed(let reason):
            return "Trusted NodeAdminAgent key bootstrap failed: \(reason)"
        case .missingBridgeKeyring:
            return "ADMIN_SCAFFOLD_BRIDGE_KEYRING_PATH is required in production and must contain haven.admin.bridge.keyring.v2."
        case .invalidBridgeKeyring:
            return "AdminScaffold bridge keyring is invalid."
        case .legacyBridgeConfiguration(let key):
            return "Legacy AdminScaffold bridge configuration is forbidden: \(key)"
        case .missingMetricsToken:
            return "ADMIN_SCAFFOLD_METRICS_BEARER_TOKEN or ADMIN_SCAFFOLD_METRICS_BEARER_TOKEN_PATH is required in production."
        case .invalidMetricsToken:
            return "AdminScaffold metrics bearer token must contain at least 24 characters."
        case .storageProbeFailed(let reason):
            return "AdminScaffold persistent storage is not writable: \(reason)"
        case .activeServiceLock:
            return "Another AdminScaffold process or bootstrap operation owns the persistent service lock."
        case .persistentCellManifestFailed(let reason):
            return "AdminScaffold persistent Cell manifest failed closed: \(reason)"
        }
    }
}

struct AdminScaffoldConfiguration: Equatable, Sendable {
    let storageRootPath: String
    let ownerContext: String
    let ownerUUID: String?
    let allowOwnerCreate: Bool
    let trustedAgentKeysPath: String?
    let requireTrustedAgentKey: Bool
    let websocketEndpointComponents: [String]
    let publicOrigin: AdminBridgePublicOrigin
    let maximumBridgeConnections: Int
    let maximumSnapshotBodyBytes: Int
    let bridgeCredentials: [AdminBridgeClientCredential]
    let bridgeMaximumClockSkewSeconds: Int
    let maximumSnapshotRequestsPerMinute: Int
    let maximumBridgeHandshakesPerMinute: Int
    let requireFreshSnapshotForReadiness: Bool
    let requireBuildMetadata: Bool
    let requirePublicOriginAuthority: Bool
    let metricsBearerToken: String?

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        productionLike: Bool
    ) throws -> AdminScaffoldConfiguration {
        let storageRootPath: String
        if let configured = normalized(environment["ADMIN_SCAFFOLD_STORAGE_ROOT"]) {
            storageRootPath = configured
        } else if productionLike {
            throw AdminScaffoldConfigurationError.missingStorageRoot
        } else {
            storageRootPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("AdminScaffold", isDirectory: true)
                .path
        }

        if productionLike,
           normalized(environment["CELL_VAULT_MASTER_KEY_B64"]) == nil,
           normalized(environment["CELL_VAULT_MASTER_KEY_PATH"]) == nil {
            throw AdminScaffoldConfigurationError.missingVaultMasterKey
        }

        let ownerUUID = normalized(environment["ADMIN_SCAFFOLD_OWNER_UUID"])
        if let ownerUUID, UUID(uuidString: ownerUUID) == nil {
            throw AdminScaffoldConfigurationError.invalidOwnerUUID(ownerUUID)
        }

        let rawWebSocketEndpoint = normalized(environment["ADMIN_SCAFFOLD_WEBSOCKET_ENDPOINT"]) ?? "bridgehead"
        guard rawWebSocketEndpoint.rangeOfCharacter(from: CharacterSet(charactersIn: "?#")) == nil else {
            throw AdminScaffoldConfigurationError.invalidWebSocketEndpoint(rawWebSocketEndpoint)
        }
        let websocketEndpointComponents = rawWebSocketEndpoint
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !websocketEndpointComponents.isEmpty,
              websocketEndpointComponents.allSatisfy({ $0 != "." && $0 != ".." }) else {
            throw AdminScaffoldConfigurationError.invalidWebSocketEndpoint(rawWebSocketEndpoint)
        }

        let publicOrigin: AdminBridgePublicOrigin
        if let rawPublicOrigin = normalized(environment["ADMIN_SCAFFOLD_PUBLIC_ORIGIN"]) {
            do {
                publicOrigin = try AdminBridgePublicOrigin(rawPublicOrigin)
            } catch {
                throw AdminScaffoldConfigurationError.invalidPublicOrigin(rawPublicOrigin)
            }
        } else if productionLike {
            throw AdminScaffoldConfigurationError.missingPublicOrigin
        } else {
            publicOrigin = .developmentDefault
        }
        let bridgeCredentialSet: AdminBridgeCredentialSet?
        do {
            bridgeCredentialSet = try AdminSecretMaterial.bridgeCredentialSet(
                environment: environment,
                pathKey: "ADMIN_SCAFFOLD_BRIDGE_KEYRING_PATH",
                publicOrigin: publicOrigin
            )
        } catch AdminSecretMaterialError.legacyBridgeConfiguration(let key) {
            throw AdminScaffoldConfigurationError.legacyBridgeConfiguration(key)
        } catch {
            throw AdminScaffoldConfigurationError.invalidBridgeKeyring
        }
        if productionLike && bridgeCredentialSet == nil {
            throw AdminScaffoldConfigurationError.missingBridgeKeyring
        }

        let metricsBearerToken: String?
        do {
            metricsBearerToken = try AdminSecretMaterial.textSecret(
                environment: environment,
                inlineKey: "ADMIN_SCAFFOLD_METRICS_BEARER_TOKEN",
                pathKey: "ADMIN_SCAFFOLD_METRICS_BEARER_TOKEN_PATH"
            )
        } catch {
            throw AdminScaffoldConfigurationError.invalidMetricsToken
        }
        if productionLike && metricsBearerToken == nil {
            throw AdminScaffoldConfigurationError.missingMetricsToken
        }

        return AdminScaffoldConfiguration(
            storageRootPath: storageRootPath,
            ownerContext: normalized(environment["ADMIN_SCAFFOLD_OWNER_CONTEXT"]) ?? "AdminScaffold",
            ownerUUID: ownerUUID,
            allowOwnerCreate: try boolean(
                environment["ADMIN_SCAFFOLD_ALLOW_OWNER_CREATE"],
                key: "ADMIN_SCAFFOLD_ALLOW_OWNER_CREATE",
                defaultValue: !productionLike
            ),
            trustedAgentKeysPath: normalized(environment["ADMIN_SCAFFOLD_TRUSTED_AGENT_KEYS_PATH"]),
            requireTrustedAgentKey: try boolean(
                environment["ADMIN_SCAFFOLD_REQUIRE_TRUSTED_AGENT_KEY"],
                key: "ADMIN_SCAFFOLD_REQUIRE_TRUSTED_AGENT_KEY",
                defaultValue: productionLike
            ),
            websocketEndpointComponents: websocketEndpointComponents,
            publicOrigin: publicOrigin,
            maximumBridgeConnections: try boundedInteger(
                environment["ADMIN_SCAFFOLD_MAX_BRIDGE_CONNECTIONS"],
                key: "ADMIN_SCAFFOLD_MAX_BRIDGE_CONNECTIONS",
                defaultValue: 128,
                range: 1...4_096
            ),
            maximumSnapshotBodyBytes: try boundedInteger(
                environment["ADMIN_SCAFFOLD_MAX_SNAPSHOT_BODY_BYTES"],
                key: "ADMIN_SCAFFOLD_MAX_SNAPSHOT_BODY_BYTES",
                defaultValue: 1_048_576,
                range: 4_096...8_388_608
            ),
            bridgeCredentials: bridgeCredentialSet?.accepted ?? [],
            bridgeMaximumClockSkewSeconds: try boundedInteger(
                environment["ADMIN_SCAFFOLD_BRIDGE_MAX_CLOCK_SKEW_SECONDS"],
                key: "ADMIN_SCAFFOLD_BRIDGE_MAX_CLOCK_SKEW_SECONDS",
                defaultValue: 30,
                range: 5...300
            ),
            maximumSnapshotRequestsPerMinute: try boundedInteger(
                environment["ADMIN_SCAFFOLD_MAX_SNAPSHOT_REQUESTS_PER_MINUTE"],
                key: "ADMIN_SCAFFOLD_MAX_SNAPSHOT_REQUESTS_PER_MINUTE",
                defaultValue: 120,
                range: 1...10_000
            ),
            maximumBridgeHandshakesPerMinute: try boundedInteger(
                environment["ADMIN_SCAFFOLD_MAX_BRIDGE_HANDSHAKES_PER_MINUTE"],
                key: "ADMIN_SCAFFOLD_MAX_BRIDGE_HANDSHAKES_PER_MINUTE",
                defaultValue: 60,
                range: 1...10_000
            ),
            requireFreshSnapshotForReadiness: try boolean(
                environment["ADMIN_SCAFFOLD_REQUIRE_FRESH_SNAPSHOT_FOR_READINESS"],
                key: "ADMIN_SCAFFOLD_REQUIRE_FRESH_SNAPSHOT_FOR_READINESS",
                defaultValue: productionLike
            ),
            requireBuildMetadata: productionLike,
            requirePublicOriginAuthority: productionLike,
            metricsBearerToken: metricsBearerToken
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func boolean(_ value: String?, key: String, defaultValue: Bool) throws -> Bool {
        guard let normalized = normalized(value)?.lowercased() else {
            return defaultValue
        }
        switch normalized {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            throw AdminScaffoldConfigurationError.invalidBoolean(key: key, value: normalized)
        }
    }

    private static func boundedInteger(
        _ value: String?,
        key: String,
        defaultValue: Int,
        range: ClosedRange<Int>
    ) throws -> Int {
        guard let normalized = normalized(value) else {
            return defaultValue
        }
        guard let parsed = Int(normalized), range.contains(parsed) else {
            throw AdminScaffoldConfigurationError.invalidInteger(key: key, value: normalized)
        }
        return parsed
    }
}

private enum AdminScaffoldProcessProfile {
    static let lock = NSLock()
    static var dedicatedControlPlane = false

    static func configure(dedicatedControlPlane value: Bool) {
        lock.lock()
        dedicatedControlPlane = value
        lock.unlock()
    }

    static func isDedicatedControlPlane() -> Bool {
        lock.lock()
        let value = dedicatedControlPlane
        lock.unlock()
        return value
    }
}

enum AdminScaffoldRuntime {
    static var isDedicatedControlPlane: Bool {
        AdminScaffoldProcessProfile.isDedicatedControlPlane()
    }

    static func configureForTesting(dedicatedControlPlane: Bool) {
        AdminScaffoldProcessProfile.configure(dedicatedControlPlane: dedicatedControlPlane)
    }
}

final class AdminScaffoldRuntimeContext: @unchecked Sendable {
    let configuration: AdminScaffoldConfiguration
    let owner: Identity
    let operations: AdminScaffoldOperations
    let serviceLock: AdminScaffoldServiceLock

    init(
        configuration: AdminScaffoldConfiguration,
        owner: Identity,
        serviceLock: AdminScaffoldServiceLock
    ) {
        self.configuration = configuration
        self.owner = owner
        self.operations = AdminScaffoldOperations(configuration: configuration)
        self.serviceLock = serviceLock
    }
}

extension Application {
    private struct AdminScaffoldRuntimeContextKey: StorageKey {
        typealias Value = AdminScaffoldRuntimeContext
    }

    var adminScaffoldRuntimeContext: AdminScaffoldRuntimeContext? {
        get { storage[AdminScaffoldRuntimeContextKey.self] }
        set { storage[AdminScaffoldRuntimeContextKey.self] = newValue }
    }
}

func isSignableAdminScaffoldOwner(_ identity: Identity) async -> Bool {
    let challenge = Data("admin-scaffold-owner-signability-v1".utf8)
    guard let signature = try? await identity.sign(data: challenge) else {
        return false
    }
    return await identity.verify(signature: signature, for: challenge)
}

/// A private, owner-matched recovery index. The persisted Cells and their
/// owner proofs remain authoritative; this index is not an owner signature.
private struct AdminScaffoldPersistentCellManifest: Codable, Equatable {
    static let schemaVersion = "haven.admin.named-scaffold-cells.v1"

    let schemaVersion: String
    let ownerUUID: String
    let ownerSigningKeyFingerprint: String
    let cells: [String: String]
}

private struct AdminScaffoldPersistentCellDescriptor {
    let name: String
    let runtimeType: Any.Type
    let addResolve: (CellResolver, String) async throws -> Void
    let restore: (CellResolver, String, Identity) async -> PersistedNamedScaffoldCellRestoreResult
    let create: (CellResolver, Identity) async throws -> Emit

    func matches(_ cell: Emit) -> Bool {
        ObjectIdentifier(Swift.type(of: cell)) == ObjectIdentifier(runtimeType)
    }
}

private func adminScaffoldPersistentCellDescriptor<T>(
    name: String,
    type: T.Type
) -> AdminScaffoldPersistentCellDescriptor where T: Emit & OwnerInstantiable {
    AdminScaffoldPersistentCellDescriptor(
        name: name,
        runtimeType: type,
        addResolve: { resolver, ownerContext in
            try await resolver.addCellResolve(
                name: name,
                cellScope: .scaffoldUnique,
                persistency: .persistant,
                identityDomain: ownerContext,
                type: type
            )
        },
        restore: { resolver, uuid, owner in
            await resolver.restorePersistedNamedScaffoldCell(
                uuid: uuid,
                named: name,
                as: type,
                requester: owner,
                authorization: CellResolverRecoveryAuthorization()
            )
        },
        create: { resolver, owner in
            try await resolver.cellAtEndpoint(
                endpoint: "cell:///\(name)",
                requester: owner
            )
        }
    )
}

enum AdminScaffoldPersistentCellRegistry {
    static let manifestFilename = ".admin-scaffold-named-cells-v1.json"

    private enum FileSystemEntryKind {
        case missing
        case regularFile
        case directory
        case symbolicLink
        case other
    }

    private static var descriptors: [AdminScaffoldPersistentCellDescriptor] {
        [
            adminScaffoldPersistentCellDescriptor(name: "AdminEntry", type: AdminEntryCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminAccessRequests", type: AdminAccessRequestCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminResolverStats", type: AdminResolverStatsCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminStorageStats", type: AdminStorageStatsCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminHostMetrics", type: AdminHostMetricsCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminMetricsHistory", type: AdminMetricsHistoryCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminCellLifecycle", type: AdminCellLifecycleCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminProcesses", type: AdminProcessCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminOverview", type: AdminOverviewCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminNodeFleet", type: AdminNodeFleetCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminDeploymentSupervisor", type: AdminDeploymentSupervisorCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminRoleEnrollment", type: AdminRoleEnrollmentCell.self),
            adminScaffoldPersistentCellDescriptor(name: "AdminSecurityPolicy", type: AdminSecurityPolicyCell.self)
        ]
    }

    static func restoreOrCreate(
        resolver: CellResolver,
        owner: Identity,
        ownerContext: String,
        storageRootPath: String
    ) async throws {
        guard let ownerFingerprint = owner.signingPublicKeyFingerprint,
              ownerFingerprint.isEmpty == false else {
            throw failure("owner signing fingerprint is unavailable")
        }
        let expectedNames = Set(descriptors.map(\.name))
        guard expectedNames == AdminScaffoldPublishedSurfacePolicy.allowedCellNames else {
            throw failure("published surface policy and persistent registry differ")
        }
        guard let identityVault = CellBase.defaultIdentityVault,
              let contextOwner = await identityVault.identity(
                for: ownerContext,
                makeNewIfNotFound: false
              ),
              contextOwner.uuid == owner.uuid,
              contextOwner.signingPublicKeyFingerprint == ownerFingerprint else {
            throw failure("owner context does not resolve to the exact runtime owner")
        }

        var existingNames = Set(
            await resolver.resolverRegistrySnapshot(requester: owner).resolves.map(\.name)
        )
        for descriptor in descriptors where existingNames.insert(descriptor.name).inserted {
            try await descriptor.addResolve(resolver, ownerContext)
        }

        let rootURL = URL(fileURLWithPath: storageRootPath, isDirectory: true)
            .standardizedFileURL
        let manifestURL = rootURL.appendingPathComponent(manifestFilename, isDirectory: false)
        let mappings: [String: String]
        switch try fileSystemEntryKind(at: manifestURL) {
        case .regularFile:
            let manifest = try loadManifest(
                at: manifestURL,
                owner: owner,
                ownerFingerprint: ownerFingerprint,
                expectedNames: expectedNames
            )
            mappings = try await restoreMappings(
                manifest.cells,
                resolver: resolver,
                owner: owner
            )
        case .missing:
            let discovered = try await discoverLegacyMappings(
                under: rootURL,
                resolver: resolver,
                owner: owner
            )
            var resolved = try await restoreMappings(
                discovered,
                resolver: resolver,
                owner: owner
            )
            for descriptor in descriptors where resolved[descriptor.name] == nil {
                let cell = try await descriptor.create(resolver, owner)
                guard descriptor.matches(cell),
                      cell.cellScope == .scaffoldUnique,
                      cell.persistancy == .persistant else {
                    throw failure("new Cell \(descriptor.name) violates its declared type or persistence contract")
                }
                try await validateOwner(of: cell, expected: owner)
                resolved[descriptor.name] = cell.uuid
            }
            try validateMappings(resolved, expectedNames: expectedNames)
            let manifest = AdminScaffoldPersistentCellManifest(
                schemaVersion: AdminScaffoldPersistentCellManifest.schemaVersion,
                ownerUUID: owner.uuid,
                ownerSigningKeyFingerprint: ownerFingerprint,
                cells: resolved
            )
            try writeManifestAtomically(manifest, to: manifestURL)
            mappings = resolved
        case .symbolicLink:
            throw failure("manifest path is a symbolic link")
        case .directory, .other:
            throw failure("manifest path is not a regular file")
        }

        try validateMappings(mappings, expectedNames: expectedNames)
        for (name, expectedUUID) in mappings {
            guard await resolver.cellUUID(for: name) == expectedUUID else {
                throw failure("runtime mapping for \(name) does not match its manifest UUID")
            }
        }
    }

    private static func restoreMappings(
        _ mappings: [String: String],
        resolver: CellResolver,
        owner: Identity
    ) async throws -> [String: String] {
        var restored: [String: String] = [:]
        for descriptor in descriptors {
            guard let uuid = mappings[descriptor.name] else {
                continue
            }
            switch await descriptor.restore(resolver, uuid, owner) {
            case .restored(let cell):
                guard descriptor.matches(cell), cell.uuid == uuid else {
                    throw failure("restored Cell \(descriptor.name) changed type or UUID")
                }
                restored[descriptor.name] = uuid
            case .missing:
                throw failure("manifest Cell \(descriptor.name) is missing")
            case .unavailable:
                throw failure("manifest Cell \(descriptor.name) is unreadable")
            case .rejected(let reason):
                throw failure("manifest Cell \(descriptor.name) was rejected: \(reason)")
            }
        }
        return restored
    }

    private static func discoverLegacyMappings(
        under rootURL: URL,
        resolver: CellResolver,
        owner: Identity
    ) async throws -> [String: String] {
        let children = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        var discovered: [String: String] = [:]
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            switch try fileSystemEntryKind(at: child) {
            case .symbolicLink:
                throw failure("legacy storage contains a symbolic-link directory")
            case .directory:
                break
            case .missing, .regularFile, .other:
                continue
            }
            let uuid = child.lastPathComponent
            guard UUID(uuidString: uuid) != nil else { continue }
            let typedCellURL = child.appendingPathComponent("typedCell.json", isDirectory: false)
            switch try fileSystemEntryKind(at: typedCellURL) {
            case .missing:
                continue
            case .regularFile:
                break
            case .symbolicLink:
                throw failure("legacy Cell \(uuid) typedCell.json is a symbolic link")
            case .directory, .other:
                throw failure("legacy Cell \(uuid) typedCell.json is not a regular non-symlink file")
            }

            let cell: Emit
            switch await resolver.loadTypedEmitCellResult(with: uuid) {
            case .loaded(let loaded):
                cell = loaded
            case .missing:
                throw failure("legacy Cell \(uuid) disappeared during discovery")
            case .unavailable:
                throw failure("legacy Cell \(uuid) is unreadable")
            }
            guard cell.uuid == uuid,
                  cell.cellScope == .scaffoldUnique,
                  cell.persistancy == .persistant else {
                throw failure("legacy Cell \(uuid) violates UUID, scope, or persistence constraints")
            }
            try await validateOwner(of: cell, expected: owner)
            guard let descriptor = descriptors.first(where: { $0.matches(cell) }) else {
                throw failure("legacy Cell \(uuid) has an unexpected type")
            }
            guard discovered[descriptor.name] == nil else {
                throw failure("legacy storage contains multiple \(descriptor.name) Cells")
            }
            discovered[descriptor.name] = uuid
        }
        return discovered
    }

    private static func loadManifest(
        at url: URL,
        owner: Identity,
        ownerFingerprint: String,
        expectedNames: Set<String>
    ) throws -> AdminScaffoldPersistentCellManifest {
        guard try fileSystemEntryKind(at: url) == .regularFile else {
            throw failure("manifest is not a regular non-symlink file")
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw failure("manifest is not a regular file")
        }
        guard let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue,
              permissions == 0o600 else {
            throw failure("manifest permissions are not exactly 0600")
        }
        let manifest = try JSONDecoder().decode(
            AdminScaffoldPersistentCellManifest.self,
            from: Data(contentsOf: url)
        )
        guard manifest.schemaVersion == AdminScaffoldPersistentCellManifest.schemaVersion else {
            throw failure("manifest schema version is unsupported")
        }
        guard manifest.ownerUUID == owner.uuid,
              manifest.ownerSigningKeyFingerprint == ownerFingerprint else {
            throw failure("manifest owner metadata does not match the runtime owner")
        }
        try validateMappings(manifest.cells, expectedNames: expectedNames)
        return manifest
    }

    private static func validateMappings(
        _ mappings: [String: String],
        expectedNames: Set<String>
    ) throws {
        guard Set(mappings.keys) == expectedNames else {
            throw failure("manifest Cell names are incomplete or unexpected")
        }
        guard mappings.values.allSatisfy({ UUID(uuidString: $0) != nil }) else {
            throw failure("manifest contains an invalid Cell UUID")
        }
        guard Set(mappings.values).count == mappings.count else {
            throw failure("manifest maps multiple names to one Cell UUID")
        }
    }

    private static func validateOwner(of cell: Emit, expected owner: Identity) async throws {
        let storedOwner = try await cell.getOwner(requester: owner)
        guard storedOwner.uuid == owner.uuid,
              let storedFingerprint = storedOwner.signingPublicKeyFingerprint,
              storedFingerprint == owner.signingPublicKeyFingerprint else {
            throw failure("persisted Cell \(cell.uuid) is owned by another signing Identity")
        }
    }

    private static func writeManifestAtomically(
        _ manifest: AdminScaffoldPersistentCellManifest,
        to manifestURL: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        let temporaryURL = manifestURL.deletingLastPathComponent()
            .appendingPathComponent(".\(manifestFilename).\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(
            atPath: temporaryURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw failure("could not create a private manifest staging file")
        }
        do {
            let handle = try FileHandle(forWritingTo: temporaryURL)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            guard rename(temporaryURL.path, manifestURL.path) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: manifestURL.path
            )
            let directoryPath = manifestURL.deletingLastPathComponent().path
            let directoryDescriptor = open(directoryPath, O_RDONLY)
            guard directoryDescriptor >= 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            defer { _ = close(directoryDescriptor) }
            guard fsync(directoryDescriptor) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw failure("atomic manifest write failed: \(error.localizedDescription)")
        }
    }

    private static func failure(_ reason: String) -> AdminScaffoldConfigurationError {
        .persistentCellManifestFailed(reason)
    }

    private static func fileSystemEntryKind(at url: URL) throws -> FileSystemEntryKind {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else {
            if errno == ENOENT {
                return .missing
            }
            throw failure("could not inspect \(url.lastPathComponent): POSIX error \(errno)")
        }
        let fileType = metadata.st_mode & mode_t(S_IFMT)
        switch fileType {
        case mode_t(S_IFREG):
            return .regularFile
        case mode_t(S_IFDIR):
            return .directory
        case mode_t(S_IFLNK):
            return .symbolicLink
        default:
            return .other
        }
    }
}

private func registerAdminScaffoldCells(
    resolver: CellResolver,
    owner: Identity,
    ownerContext: String,
    storageRootPath: String
) async throws {
    try await AdminScaffoldPersistentCellRegistry.restoreOrCreate(
        resolver: resolver,
        owner: owner,
        ownerContext: ownerContext,
        storageRootPath: storageRootPath
    )
}

private func bootstrapTrustedAgentKeys(
    from path: String,
    owner: Identity
) throws {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let value = try JSONDecoder().decode(ValueType.self, from: data)
    let records: [ValueType]
    switch value {
    case .list(let list):
        records = list
    case .object(let object):
        if case let .list(list)? = object["trustedKeys"] {
            records = list
        } else {
            records = [value]
        }
    default:
        throw AdminScaffoldConfigurationError.trustedAgentKeyBootstrapFailed("root must be an object or list")
    }

    guard !records.isEmpty else {
        throw AdminScaffoldConfigurationError.trustedAgentKeyBootstrapFailed("no trusted keys found")
    }
    for record in records {
        let result = AdminNodeSnapshotStore.shared.trustAgentKey(value: record, requester: owner)
        guard case let .string(status)? = result["status"], status == "trusted" else {
            let reason: String
            if case let .string(value)? = result["reason"] {
                reason = value
            } else {
                reason = "registry rejected a key record"
            }
            throw AdminScaffoldConfigurationError.trustedAgentKeyBootstrapFailed(reason)
        }
    }
}

public func configureAdminScaffold(_ app: Application) async throws {
    let productionLike = RuntimeDeploymentMode.isProductionLike(app.environment)
    let configuration = try AdminScaffoldConfiguration.fromEnvironment(
        ProcessInfo.processInfo.environment,
        productionLike: productionLike
    )

    try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: configuration.storageRootPath, isDirectory: true),
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    do {
        try AdminScaffoldStorageProbe.verifyWritable(rootPath: configuration.storageRootPath)
    } catch {
        throw AdminScaffoldConfigurationError.storageProbeFailed(error.localizedDescription)
    }
    let serviceLock: AdminScaffoldServiceLock
    do {
        serviceLock = try AdminScaffoldServiceLock.acquire(
            rootPath: configuration.storageRootPath
        )
    } catch AdminScaffoldServiceLockError.activeServiceLock {
        throw AdminScaffoldConfigurationError.activeServiceLock
    }
    CellBase.documentRootPath = configuration.storageRootPath
    AdminScaffoldProcessProfile.configure(dedicatedControlPlane: true)
    AdminControlPlaneRouting.configureCurrent(
        .adminScaffoldSurfaceRouting(
            publicOrigin: configuration.publicOrigin,
            websocketEndpoint: configuration.websocketEndpointComponents.joined(separator: "/")
        )
    )
    AdminMetricsSupport.primeStorageInventoryRefresh()

    let resolver = CellResolver.sharedInstance
    let typedUtility = TypedCellUtility(storage: LargeStackCellStorage())
    resolver.tcUtility = typedUtility
    CellBase.typedCellUtility = typedUtility
    try await resolver.registerDefaultWebSocketBridgeTransports()
    CellBase.defaultCellResolver = resolver
    CellBase.sendDataAsText = true
    CellBase.debugValidateAccessForEverything = false

    let vault = await VaporIdentityVault.shared.initialize()
    CellBase.defaultIdentityVault = vault
    let owner: Identity?
    if let ownerUUID = configuration.ownerUUID {
        owner = await vault.identity(forUUID: ownerUUID)
    } else {
        owner = await vault.identity(
            for: configuration.ownerContext,
            makeNewIfNotFound: configuration.allowOwnerCreate
        )
    }
    guard let owner else {
        throw AdminScaffoldConfigurationError.ownerIdentityUnavailable
    }
    guard await isSignableAdminScaffoldOwner(owner) else {
        throw AdminScaffoldConfigurationError.ownerIdentityIsNotSignable
    }

    if CellBase.securityEventSink == nil {
        CellBase.securityEventSink = InMemoryCellSecurityEventSink()
    }
    if CellBase.securityContainmentController == nil {
        CellBase.securityContainmentController = CellSecurityContainmentController()
    }
    CellBase.securityContainmentPolicy = app.environment == .testing ? .monitorOnly : .localProtection

    try await registerAdminScaffoldCells(
        resolver: resolver,
        owner: owner,
        ownerContext: configuration.ownerContext,
        storageRootPath: configuration.storageRootPath
    )
    let existingTrustedKeyCount: Int = {
        switch AdminNodeSnapshotStore.shared.stateObject()["trustedAgentKeyCount"] {
        case .integer(let value)?, .number(let value)?:
            return value
        default:
            return 0
        }
    }()
    if existingTrustedKeyCount == 0,
       let trustedAgentKeysPath = configuration.trustedAgentKeysPath {
        try bootstrapTrustedAgentKeys(from: trustedAgentKeysPath, owner: owner)
    }

    app.adminScaffoldRuntimeContext = AdminScaffoldRuntimeContext(
        configuration: configuration,
        owner: owner,
        serviceLock: serviceLock
    )
    app.middleware.use(AdminScaffoldHTTPMetricsMiddleware())
    app.routes.defaultMaxBodySize = ByteCount(value: configuration.maximumSnapshotBodyBytes)
    app.logger.notice("AdminScaffold owner resolved: \(owner.uuid)")
    try app.register(collection: AdminScaffoldBridgeRoutes(configuration: configuration))
}
