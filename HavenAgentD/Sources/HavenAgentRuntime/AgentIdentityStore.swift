import Foundation
@preconcurrency import CellBase
import SproutCrypto
#if canImport(Security)
import Security
#endif

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public struct AgentIdentityDescriptor: Codable, Equatable, Sendable {
    public var version: String
    public var instanceName: String
    public var identityContext: String
    public var identityUUID: String
    public var displayName: String
    public var publicKeyBase64URL: String
    public var didKey: String
    public var createdAt: String
    public var storageKind: String

    public init(
        version: String = "1.0",
        instanceName: String,
        identityContext: String,
        identityUUID: String,
        displayName: String,
        publicKeyBase64URL: String,
        didKey: String,
        createdAt: String,
        storageKind: String
    ) {
        self.version = version
        self.instanceName = instanceName
        self.identityContext = identityContext
        self.identityUUID = identityUUID
        self.displayName = displayName
        self.publicKeyBase64URL = publicKeyBase64URL
        self.didKey = didKey
        self.createdAt = createdAt
        self.storageKind = storageKind
    }
}

public struct AgentIdentityMaterial: Codable, Equatable, Sendable {
    public var descriptor: AgentIdentityDescriptor
    public var privateKeySeedBase64URL: String

    public init(descriptor: AgentIdentityDescriptor, privateKeySeedBase64URL: String) {
        self.descriptor = descriptor
        self.privateKeySeedBase64URL = privateKeySeedBase64URL
    }

    public func privateKey() throws -> Curve25519.Signing.PrivateKey {
        try Curve25519.Signing.PrivateKey(
            rawRepresentation: Base64URL.decode(privateKeySeedBase64URL)
        )
    }
}

private struct PersistedAgentIdentityMetadata: Codable, Equatable, Sendable {
    var descriptor: AgentIdentityDescriptor
    var privateKeySeedBase64URL: String?
}

public protocol AgentIdentitySeedStoring: Sendable {
    var storageKind: String { get }
    func storeSeed(_ seed: Data, handleID: String) async throws
    func loadSeed(handleID: String) async throws -> Data?
    func deleteSeed(handleID: String) async throws
}

public final class FileAgentIdentitySeedStore: AgentIdentitySeedStoring, @unchecked Sendable {
    public let storageKind = "state-file-seed"
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func storeSeed(_ seed: Data, handleID: String) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try Base64URL.encode(seed).write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    public func loadSeed(handleID: String) async throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let encoded = try String(contentsOf: fileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !encoded.isEmpty else {
            return nil
        }
        return try Base64URL.decode(encoded)
    }

    public func deleteSeed(handleID: String) async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}

#if canImport(Security)
public final class AppleKeychainAgentIdentitySeedStore: AgentIdentitySeedStoring, @unchecked Sendable {
    public let storageKind = "keychain"
    private let service: String

    public init(service: String = "no.haven.agentd.identity") {
        self.service = service
    }

    public func storeSeed(_ seed: Data, handleID: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: handleID
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = seed
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public func loadSeed(handleID: String) async throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: handleID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public func deleteSeed(handleID: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: handleID
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
#endif

public enum AgentIdentityStoreError: Error, LocalizedError, Equatable, Sendable {
    case invalidPersistedKeyMaterial
    case invalidPersistedPublicKey
    case missingStoredSeed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPersistedKeyMaterial:
            return "Persisted agent identity seed material is invalid."
        case .invalidPersistedPublicKey:
            return "Persisted agent identity public key is invalid."
        case .missingStoredSeed(let storageKind):
            return "Persisted agent identity metadata exists, but no private seed was found in \(storageKind)."
        }
    }
}

public actor AgentIdentityStore {
    private let fileURL: URL
    private let seedStore: any AgentIdentitySeedStoring
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date

    public init(
        fileURL: URL,
        seedStore: (any AgentIdentitySeedStoring)? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.seedStore = seedStore ?? Self.defaultSeedStore(for: fileURL)
        self.now = now
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public static func identityContext(for instanceName: String) -> String {
        "haven.agent.owner.\(instanceName)"
    }

    public static func displayName(for instanceName: String) -> String {
        "HAVEN Agent (\(instanceName))"
    }

    public func loadOrCreate(instanceName: String) async throws -> AgentIdentityMaterial {
        if let existing = try await load() {
            return try validate(existing)
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        let seedBase64URL = Base64URL.encode(privateKey.rawRepresentation)
        let descriptor = try Self.makeDescriptor(
            instanceName: instanceName,
            identityUUID: UUID().uuidString,
            displayName: Self.displayName(for: instanceName),
            publicKeyData: privateKey.publicKey.rawRepresentation,
            createdAt: iso8601String(now()),
            storageKind: seedStore.storageKind
        )
        let material = AgentIdentityMaterial(
            descriptor: descriptor,
            privateKeySeedBase64URL: seedBase64URL
        )
        try await write(material)
        return material
    }

    /// Loads and validates the persisted identity without creating one. Returns
    /// nil when no identity exists yet (e.g. the agent has never run). Useful for
    /// provisioning flows that must bind to an already-established agent key.
    public func loadExistingDescriptor() async throws -> AgentIdentityDescriptor? {
        guard let material = try await load() else {
            return nil
        }
        return try validate(material).descriptor
    }

    private func load() async throws -> AgentIdentityMaterial? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let persisted = try decoder.decode(PersistedAgentIdentityMetadata.self, from: Data(contentsOf: fileURL))
        if let legacySeed = persisted.privateKeySeedBase64URL {
            let seedData = try Base64URL.decode(legacySeed)
            var descriptor = persisted.descriptor
            descriptor.storageKind = seedStore.storageKind
            let material = AgentIdentityMaterial(
                descriptor: descriptor,
                privateKeySeedBase64URL: Base64URL.encode(seedData)
            )
            let validated = try validate(material)
            try await seedStore.storeSeed(seedData, handleID: Self.seedHandleID(for: descriptor))
            try writeDescriptor(validated.descriptor)
            return validated
        }

        let seedData = try await seedStore.loadSeed(handleID: Self.seedHandleID(for: persisted.descriptor))
        guard let seedData else {
            throw AgentIdentityStoreError.missingStoredSeed(persisted.descriptor.storageKind)
        }
        let material = AgentIdentityMaterial(
            descriptor: persisted.descriptor,
            privateKeySeedBase64URL: Base64URL.encode(seedData)
        )
        return try validate(material)
    }

    private func write(_ material: AgentIdentityMaterial) async throws {
        let seed = try Base64URL.decode(material.privateKeySeedBase64URL)
        try await seedStore.storeSeed(seed, handleID: Self.seedHandleID(for: material.descriptor))
        try writeDescriptor(material.descriptor)
    }

    private func writeDescriptor(_ descriptor: AgentIdentityDescriptor) throws {
        let data = try encoder.encode(PersistedAgentIdentityMetadata(
            descriptor: descriptor,
            privateKeySeedBase64URL: nil
        ))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func validate(_ material: AgentIdentityMaterial) throws -> AgentIdentityMaterial {
        let seedData = try Base64URL.decode(material.privateKeySeedBase64URL)
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seedData)
        let expectedPublicKey = Base64URL.encode(privateKey.publicKey.rawRepresentation)
        guard material.descriptor.publicKeyBase64URL == expectedPublicKey else {
            throw AgentIdentityStoreError.invalidPersistedPublicKey
        }
        return material
    }

    private static func makeDescriptor(
        instanceName: String,
        identityUUID: String,
        displayName: String,
        publicKeyData: Data,
        createdAt: String,
        storageKind: String
    ) throws -> AgentIdentityDescriptor {
        let identity = Identity(identityUUID, displayName: displayName, identityVault: nil)
        identity.publicSecureKey = SecureKey(
            date: Date(),
            privateKey: false,
            use: .signature,
            algorithm: .EdDSA,
            size: 256,
            curveType: .Curve25519,
            x: nil,
            y: nil,
            compressedKey: publicKeyData
        )

        return AgentIdentityDescriptor(
            instanceName: instanceName,
            identityContext: identityContext(for: instanceName),
            identityUUID: identityUUID,
            displayName: displayName,
            publicKeyBase64URL: Base64URL.encode(publicKeyData),
            didKey: try identity.did(),
            createdAt: createdAt,
            storageKind: storageKind
        )
    }

    public static func seedHandleID(for descriptor: AgentIdentityDescriptor) -> String {
        "agent-identity:\(descriptor.identityUUID)"
    }

    public static func defaultSeedStore(for fileURL: URL) -> any AgentIdentitySeedStoring {
        let standardizedPath = fileURL.standardizedFileURL.path
        let temporaryPrefixes = [
            FileManager.default.temporaryDirectory.standardizedFileURL.path,
            "/tmp/",
            "/private/tmp/"
        ]
        if temporaryPrefixes.contains(where: { standardizedPath.hasPrefix($0) }) {
            return FileAgentIdentitySeedStore(fileURL: fileURL.deletingPathExtension().appendingPathExtension("seed"))
        }
#if canImport(Security)
        return AppleKeychainAgentIdentitySeedStore()
#else
        return FileAgentIdentitySeedStore(fileURL: fileURL.deletingPathExtension().appendingPathExtension("seed"))
#endif
    }

    private func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
