import Foundation
@preconcurrency import CellBase
import SproutCrypto

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

public enum AgentIdentityStoreError: Error, LocalizedError, Sendable {
    case invalidPersistedKeyMaterial
    case invalidPersistedPublicKey

    public var errorDescription: String? {
        switch self {
        case .invalidPersistedKeyMaterial:
            return "Persisted agent identity seed material is invalid."
        case .invalidPersistedPublicKey:
            return "Persisted agent identity public key is invalid."
        }
    }
}

public actor AgentIdentityStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date

    public init(
        fileURL: URL,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileURL = fileURL
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

    public func loadOrCreate(instanceName: String) throws -> AgentIdentityMaterial {
        if let existing = try load() {
            return try validate(existing)
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        let seedBase64URL = Base64URL.encode(privateKey.rawRepresentation)
        let descriptor = try Self.makeDescriptor(
            instanceName: instanceName,
            identityUUID: UUID().uuidString,
            displayName: Self.displayName(for: instanceName),
            publicKeyData: privateKey.publicKey.rawRepresentation,
            createdAt: iso8601String(now())
        )
        let material = AgentIdentityMaterial(
            descriptor: descriptor,
            privateKeySeedBase64URL: seedBase64URL
        )
        try write(material)
        return material
    }

    /// Loads and validates the persisted identity without creating one. Returns
    /// nil when no identity exists yet (e.g. the agent has never run). Useful for
    /// provisioning flows that must bind to an already-established agent key.
    public func loadExistingDescriptor() throws -> AgentIdentityDescriptor? {
        guard let material = try load() else {
            return nil
        }
        return try validate(material).descriptor
    }

    private func load() throws -> AgentIdentityMaterial? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try decoder.decode(AgentIdentityMaterial.self, from: Data(contentsOf: fileURL))
    }

    private func write(_ material: AgentIdentityMaterial) throws {
        let data = try encoder.encode(material)
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
        createdAt: String
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
            storageKind: "state-file"
        )
    }

    private func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
