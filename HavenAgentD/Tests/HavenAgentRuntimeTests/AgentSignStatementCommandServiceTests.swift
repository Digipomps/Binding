import Foundation
@preconcurrency import CellBase
import CryptoKit
import SproutCrypto
import Testing
@testable import HavenAgentRuntime

private final class StatementTestIdentityVault: IdentityVaultProtocol, @unchecked Sendable {
    private let privateKey: Curve25519.Signing.PrivateKey

    init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
    }

    func initialize() async -> IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {}

    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        nil
    }

    func saveIdentity(_ identity: Identity) async {}

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        guard identity.publicSecureKey?.compressedKey == privateKey.publicKey.rawRepresentation else {
            throw IdentityVaultError.noKey
        }
        return try privateKey.signature(for: messageData)
    }

    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: privateKey.publicKey.rawRepresentation)
        return publicKey.isValidSignature(signature, for: messageData)
    }

    func randomBytes64() async -> Data? {
        Data(repeating: 0xA5, count: 64)
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        ("test-key-\(tag)", "test-iv-\(tag)")
    }
}

@Suite
struct AgentSignStatementCommandServiceTests {
    @Test
    func signStatementCreatesVerifiableAudienceBoundEnvelope() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.validRequest(payload: Data("hello HAVEN".utf8), nonce: "nonce-1234567890")

        let result = try await fixture.service.signStatement(request)

        #expect(result.status == "signed_statement_created")
        #expect(result.actionID == "identity.sign-statement")
        #expect(result.deliveryMode == "detached_signed_statement")
        #expect(result.envelope.signed.type == "haven.signed-data.v1")
        #expect(result.envelope.signed.purposeRef == AgentSignatureStatement.purposeRef)
        #expect(result.envelope.signed.signerIdentity.identityUUID == fixture.descriptor.identityUUID)
        #expect(result.envelope.signed.signerIdentity.publicKeyBase64URL == fixture.descriptor.publicKeyBase64URL)
        #expect(result.envelope.signed.audience.entityRef == "entity:victoria")
        #expect(result.envelope.signed.payload.description == "Unit test payload")
        #expect(result.envelope.signed.payload.sizeBytes == 11)
        #expect(result.envelope.signed.payload.sha256Base64URL == Base64URL.encode(Data(SHA256.hash(data: Data("hello HAVEN".utf8)))))
        let signingData = try result.envelope.signed.canonicalPayloadData()
        let signingDigest = Base64URL.encode(Data(SHA256.hash(data: signingData)))
        #expect(signingDigest == result.envelope.signingInputSHA256Base64URL)
        let publicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: Base64URL.decode(result.envelope.signed.signerIdentity.publicKeyBase64URL)
        )
        let signature = try Base64URL.decode(result.envelope.signatureBase64URL)
        #expect(publicKey.isValidSignature(signature, for: signingData))
        #expect(try AgentSignStatementCommandService.verifyEnvelope(result.envelope) == true)
    }

    @Test
    func duplicateNonceIsRejectedPersistently() async throws {
        let fixture = try Self.makeFixture()
        let request = Self.validRequest(payload: Data("first".utf8), nonce: "nonce-duplicate-123")
        _ = try await fixture.service.signStatement(request)

        do {
            _ = try await fixture.service.signStatement(
                Self.validRequest(payload: Data("second".utf8), nonce: "nonce-duplicate-123")
            )
            Issue.record("Expected duplicate nonce rejection.")
        } catch let error as AgentSignStatementError {
            #expect(error == .nonceAlreadyUsed("nonce-duplicate-123"))
        }

        let reloadedService = AgentSignStatementCommandService(
            owner: fixture.owner,
            identityDescriptor: fixture.descriptor,
            nonceStore: AgentSignatureNonceStore(fileURL: fixture.nonceFile),
            now: fixture.now
        )
        do {
            _ = try await reloadedService.signStatement(
                Self.validRequest(payload: Data("third".utf8), nonce: "nonce-duplicate-123")
            )
            Issue.record("Expected duplicate nonce rejection after reload.")
        } catch let error as AgentSignStatementError {
            #expect(error == .nonceAlreadyUsed("nonce-duplicate-123"))
        }
    }

    @Test
    func wrongSignerIdentityIsRejectedBeforeSigning() async throws {
        let fixture = try Self.makeFixture()
        var request = Self.validRequest(payload: Data("hello".utf8), nonce: "nonce-wrong-signer")
        request.signerIdentityUUID = "not-the-agent"

        do {
            _ = try await fixture.service.signStatement(request)
            Issue.record("Expected signer identity mismatch.")
        } catch let error as AgentSignStatementError {
            #expect(error == .invalidSignerIdentity(expected: fixture.descriptor.identityUUID, actual: "not-the-agent"))
        }
    }

    @Test
    func expiredStatementIsRejected() async throws {
        let fixture = try Self.makeFixture()
        var request = Self.validRequest(payload: Data("hello".utf8), nonce: "nonce-expired-statement")
        request.expiresAt = Self.iso8601String(Date(timeIntervalSince1970: 1_700_000_000 - 10))

        do {
            _ = try await fixture.service.signStatement(request)
            Issue.record("Expected expired statement rejection.")
        } catch let error as AgentSignStatementError {
            #expect(error == .expiryInPast)
        }
    }

    private struct Fixture {
        var owner: Identity
        var descriptor: AgentIdentityDescriptor
        var service: AgentSignStatementCommandService
        var nonceFile: URL
        var now: @Sendable () -> Date
    }

    private static func makeFixture() throws -> Fixture {
        let privateKey = Curve25519.Signing.PrivateKey()
        let descriptor = AgentIdentityDescriptor(
            instanceName: "agent",
            identityContext: AgentIdentityStore.identityContext(for: "agent"),
            identityUUID: "agent-identity-1",
            displayName: "HAVEN Agent (agent)",
            publicKeyBase64URL: Base64URL.encode(privateKey.publicKey.rawRepresentation),
            didKey: "did:key:test-agent",
            createdAt: Self.iso8601String(Date(timeIntervalSince1970: 1_700_000_000)),
            storageKind: "test"
        )
        let vault = StatementTestIdentityVault(privateKey: privateKey)
        let owner = Identity(descriptor.identityUUID, displayName: descriptor.displayName, identityVault: vault)
        owner.publicSecureKey = SecureKey(
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
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentSignatureTests-\(UUID().uuidString)", isDirectory: true)
        let nonceFile = root.appendingPathComponent("identity-signature-nonces.json")
        let now: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) }
        let service = AgentSignStatementCommandService(
            owner: owner,
            identityDescriptor: descriptor,
            nonceStore: AgentSignatureNonceStore(fileURL: nonceFile),
            now: now
        )
        return Fixture(owner: owner, descriptor: descriptor, service: service, nonceFile: nonceFile, now: now)
    }

    private static func validRequest(payload: Data, nonce: String) -> AgentSignStatementRequest {
        AgentSignStatementRequest(
            purposeRef: AgentSignatureStatement.purposeRef,
            payloadBase64URL: Base64URL.encode(payload),
            payloadMediaType: "text/plain",
            payloadDescription: "Unit test payload",
            audience: AgentSignatureAudience(
                entityRef: "entity:victoria",
                publicKeyFingerprint: "sha256:recipient-key"
            ),
            expiresAt: Self.iso8601String(Date(timeIntervalSince1970: 1_700_000_000 + 3_600)),
            nonce: nonce
        )
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
