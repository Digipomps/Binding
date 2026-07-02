import Foundation
@preconcurrency import CellBase
import CryptoKit
import SproutCrypto
import Testing
@testable import HavenAgentRuntime

@Suite
struct AgentIdentityStoreTests {
    @Test
    func newIdentityStoresSeedOutsideDescriptorFile() async throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let metadataFile = root.appendingPathComponent("agent-identity.json")
        let seedFile = root.appendingPathComponent("agent-identity.seed")
        let seedStore = FileAgentIdentitySeedStore(fileURL: seedFile)
        let store = AgentIdentityStore(
            fileURL: metadataFile,
            seedStore: seedStore,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let material = try await store.loadOrCreate(instanceName: "agent")

        #expect(material.descriptor.storageKind == seedStore.storageKind)
        #expect(FileManager.default.fileExists(atPath: metadataFile.path))
        #expect(FileManager.default.fileExists(atPath: seedFile.path))
        let metadata = try String(contentsOf: metadataFile, encoding: .utf8)
        #expect(metadata.contains("privateKeySeedBase64URL") == false)
        #expect(metadata.contains(material.privateKeySeedBase64URL) == false)

        let reloaded = try await AgentIdentityStore(fileURL: metadataFile, seedStore: seedStore)
            .loadOrCreate(instanceName: "agent")
        #expect(reloaded.descriptor == material.descriptor)
        #expect(reloaded.privateKeySeedBase64URL == material.privateKeySeedBase64URL)
    }

    @Test
    func legacyInlineSeedMigratesToSeedStore() async throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let metadataFile = root.appendingPathComponent("agent-identity.json")
        let seedFile = root.appendingPathComponent("agent-identity.seed")
        let seedStore = FileAgentIdentitySeedStore(fileURL: seedFile)
        let legacy = try Self.makeLegacyMaterial()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try encoder.encode(legacy).write(to: metadataFile, options: [.atomic])

        let migrated = try await AgentIdentityStore(fileURL: metadataFile, seedStore: seedStore)
            .loadOrCreate(instanceName: "agent")

        #expect(migrated.descriptor.identityUUID == legacy.descriptor.identityUUID)
        #expect(migrated.descriptor.storageKind == seedStore.storageKind)
        #expect(migrated.privateKeySeedBase64URL == legacy.privateKeySeedBase64URL)
        #expect(FileManager.default.fileExists(atPath: seedFile.path))
        let metadata = try String(contentsOf: metadataFile, encoding: .utf8)
        #expect(metadata.contains("privateKeySeedBase64URL") == false)
        #expect(metadata.contains(legacy.privateKeySeedBase64URL) == false)
    }

    @Test
    func descriptorWithoutStoredSeedIsRejected() async throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let metadataFile = root.appendingPathComponent("agent-identity.json")
        let seedFile = root.appendingPathComponent("agent-identity.seed")
        let legacy = try Self.makeLegacyMaterial()
        let metadata = [
            "descriptor": legacy.descriptor
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try encoder.encode(metadata).write(to: metadataFile, options: [.atomic])

        do {
            _ = try await AgentIdentityStore(
                fileURL: metadataFile,
                seedStore: FileAgentIdentitySeedStore(fileURL: seedFile)
            ).loadExistingDescriptor()
            Issue.record("Expected missing seed rejection.")
        } catch let error as AgentIdentityStoreError {
            #expect(error == .missingStoredSeed(legacy.descriptor.storageKind))
        }
    }

    private static func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentIdentityStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func makeLegacyMaterial() throws -> AgentIdentityMaterial {
        let privateKey = Curve25519.Signing.PrivateKey()
        let identityUUID = "legacy-agent-identity"
        let identity = Identity(identityUUID, displayName: "HAVEN Agent (agent)", identityVault: nil)
        identity.publicSecureKey = SecureKey(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            privateKey: false,
            use: .signature,
            algorithm: .EdDSA,
            size: 256,
            curveType: .Curve25519,
            x: nil,
            y: nil,
            compressedKey: privateKey.publicKey.rawRepresentation
        )
        return AgentIdentityMaterial(
            descriptor: AgentIdentityDescriptor(
                instanceName: "agent",
                identityContext: AgentIdentityStore.identityContext(for: "agent"),
                identityUUID: identityUUID,
                displayName: "HAVEN Agent (agent)",
                publicKeyBase64URL: Base64URL.encode(privateKey.publicKey.rawRepresentation),
                didKey: try identity.did(),
                createdAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_000)),
                storageKind: "state-file"
            ),
            privateKeySeedBase64URL: Base64URL.encode(privateKey.rawRepresentation)
        )
    }
}
