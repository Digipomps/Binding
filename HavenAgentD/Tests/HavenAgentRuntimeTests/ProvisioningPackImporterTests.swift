import Foundation
import Testing
import SproutCrypto
@testable import HavenMacAutomation
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// Mirrors the (internal) pairing artifact shape so tests can mint a verifiable one.
private struct PairingMirror: Codable {
    struct Attestation: Codable {
        struct Payload: Codable {
            var version = "1.0"
            var instanceName: String
            var agentIdentityUUID: String
            var agentDisplayName = "HAVEN Agent"
            var agentDid = "did:key:zAgentFixture"
            var agentPublicKeyBase64URL: String
            var operatorIdentityUUID = "operator-identity-001"
            var operatorDid = "did:key:zOperatorFixture"
            var operatorPublicKeyBase64URL: String
            var purposeRef: String
            var scaffoldDomain: String
            var challenge: String
            var issuedAt = "2026-03-15T12:00:00Z"
        }
        var payload: Payload
        var signatureAlgorithm = "Ed25519"
        var signatureBase64URL: String
        func canonical() throws -> Data {
            let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return try e.encode(payload)
        }
    }
    struct Approval: Codable {
        struct Payload: Codable {
            var version = "1.0"
            var pairingID: String
            var scaffoldDomain: String
            var purposeRef: String
            var challenge: String
            var attestationSHA256Base64URL: String
            var operatorIdentityUUID = "operator-identity-001"
            var operatorDisplayName = "private"
            var operatorDid = "did:key:zOperatorFixture"
            var operatorPublicKeyBase64URL: String
            var approvedAt = "2026-03-15T12:00:00Z"
        }
        var payload: Payload
        var signatureBase64: String
        var curveType = "ed25519"
        func canonical() throws -> Data {
            let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return try e.encode(payload)
        }
    }
    var version = "1.0"
    var pairingID: String
    var recordedAt = "2026-03-15T12:00:00Z"
    var verificationStatus = "agent-attestation-verified"
    var agentAttestation: Attestation
    var operatorApproval: Approval
}

private enum PackFactory {
    static func pairingJSON(
        agentKey: Curve25519.Signing.PrivateKey,
        operatorKey: Curve25519.Signing.PrivateKey,
        instanceName: String,
        agentIdentityUUID: String,
        domain: String,
        purpose: String
    ) throws -> JSONValue {
        let pairingID = "pair_\(UUID().uuidString.lowercased())"
        let challenge = "pairing-\(UUID().uuidString.lowercased())"
        let agentPub = Base64URL.encode(agentKey.publicKey.rawRepresentation)
        let operatorPub = Base64URL.encode(operatorKey.publicKey.rawRepresentation)

        var attestation = PairingMirror.Attestation(
            payload: .init(
                instanceName: instanceName,
                agentIdentityUUID: agentIdentityUUID,
                agentPublicKeyBase64URL: agentPub,
                operatorPublicKeyBase64URL: operatorPub,
                purposeRef: purpose,
                scaffoldDomain: domain,
                challenge: challenge
            ),
            signatureBase64URL: ""
        )
        attestation.signatureBase64URL = Base64URL.encode(try agentKey.signature(for: attestation.canonical()))

        let digest = Data(SHA256.hash(data: try attestation.canonical()))
        var approval = PairingMirror.Approval(
            payload: .init(
                pairingID: pairingID,
                scaffoldDomain: domain,
                purposeRef: purpose,
                challenge: challenge,
                attestationSHA256Base64URL: Base64URL.encode(digest),
                operatorPublicKeyBase64URL: operatorPub
            ),
            signatureBase64: ""
        )
        approval.signatureBase64 = try operatorKey.signature(for: approval.canonical()).base64EncodedString()

        let mirror = PairingMirror(pairingID: pairingID, agentAttestation: attestation, operatorApproval: approval)
        let data = try JSONEncoder().encode(mirror)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    static func starterAuth(
        agentKey: Curve25519.Signing.PrivateKey,
        domain: String,
        purpose: String,
        interests: [String],
        ttl: TimeInterval = 900
    ) throws -> AgentStarterAuthPayload {
        let f = ISO8601DateFormatter()
        let now = Date()
        var payload = AgentStarterAuthPayload(
            domain: domain,
            identity_public_key: Base64URL.encode(agentKey.publicKey.rawRepresentation),
            created_at: f.string(from: now),
            expires_at: f.string(from: now.addingTimeInterval(ttl)),
            nonce: "starter-fixture",
            purpose_interest: .init(purpose: purpose, interests: interests),
            signature: .init(alg: "Ed25519", sig: "")
        )
        payload.signature = .init(
            alg: "Ed25519",
            sig: Base64URL.encode(try agentKey.signature(for: payload.canonicalPayloadData()))
        )
        return payload
    }

    static func entityLink(
        agentKey: Curve25519.Signing.PrivateKey,
        operatorKey: Curve25519.Signing.PrivateKey,
        domain: String,
        purpose: String
    ) throws -> AgentEntityLinkContract {
        var contract = AgentEntityLinkContract(
            contract_id: "elc_fixture_0001",
            domain_a: domain,
            pubkey_a: Base64URL.encode(operatorKey.publicKey.rawRepresentation),
            domain_b: domain,
            pubkey_b: Base64URL.encode(agentKey.publicKey.rawRepresentation),
            scope: "purpose-bound:\(purpose)",
            created_at: "2026-03-15T12:00:00Z",
            revocation: .init(mode: "mutual"),
            signatures: []
        )
        let canonical = try contract.canonicalPayloadData()
        contract.signatures = [
            .init(by_pubkey: contract.pubkey_a, alg: "Ed25519",
                  sig: Base64URL.encode(try operatorKey.signature(for: canonical))),
            .init(by_pubkey: contract.pubkey_b, alg: "Ed25519",
                  sig: Base64URL.encode(try agentKey.signature(for: canonical)))
        ]
        return contract
    }

    static func makeConfig(paths: RuntimePaths, domain: String, purpose: String, interests: [String]) -> AgentConfig {
        AgentConfig(
            instanceName: "victoria-mac",
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: "/absolute/path/to/sprout",
                startupMode: .join,
                domain: domain,
                purpose: purpose,
                interests: interests,
                resolverBaseURL: "https://\(domain)",
                starterAuthPath: paths.agentDirectory.appendingPathComponent("starter-auth.json").path,
                entityLinkPath: paths.outputDirectory.appendingPathComponent("agent-operator-entity-link.json").path,
                requestedCapabilities: ["cap.native_porthole"]
            ),
            watchFolders: [],
            automationPolicy: .init()
        )
    }
}

private func tempRoot() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("haven-provimport-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite struct ProvisioningPackImporterTests {
    private let domain = "staging.haven.digipomps.org"
    private let purpose = "bootstrap.join_scaffold"
    private let interests = ["haven.core.bootstrap", "haven.core.bridge"]

    private func mintPackAndConfig(root: URL) async throws -> (pack: ProvisioningPack, paths: RuntimePaths, agentPub: String) {
        let paths = RuntimePaths.rooted(at: root)
        let config = PackFactory.makeConfig(paths: paths, domain: domain, purpose: purpose, interests: interests)
        try config.write(to: paths.configFile)

        // Establish the agent identity and sign with its real key.
        let material = try await AgentIdentityStore(fileURL: paths.agentIdentityFile)
            .loadOrCreate(instanceName: config.instanceName)
        let agentKey = try material.privateKey()
        let operatorKey = Curve25519.Signing.PrivateKey()

        let pack = ProvisioningPack(
            scaffoldDomain: domain,
            purposeRef: purpose,
            boundAgent: .init(
                agentIdentityUUID: material.descriptor.identityUUID,
                agentPublicKeyBase64URL: material.descriptor.publicKeyBase64URL
            ),
            createdAt: "2026-06-16T00:00:00Z",
            issuedBy: "operator-test",
            pairing: try PackFactory.pairingJSON(
                agentKey: agentKey, operatorKey: operatorKey,
                instanceName: config.instanceName,
                agentIdentityUUID: material.descriptor.identityUUID,
                domain: domain, purpose: purpose
            ),
            starterAuth: try PackFactory.starterAuth(
                agentKey: agentKey, domain: domain, purpose: purpose, interests: interests
            ),
            entityLink: try PackFactory.entityLink(
                agentKey: agentKey, operatorKey: operatorKey, domain: domain, purpose: purpose
            )
        )
        return (pack, paths, material.descriptor.publicKeyBase64URL)
    }

    @Test func importsVerifiedPackAndReportsReady() async throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (pack, paths, _) = try await mintPackAndConfig(root: root)

        let packURL = root.appendingPathComponent("pack.json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(pack).write(to: packURL, options: [.atomic])

        let report = try await ProvisioningPackImporter(paths: paths)
            .performImport(packURL: packURL, configURL: paths.configFile)

        #expect(report.boundAgentMatches)
        #expect(report.installed)
        #expect(report.readyForBootstrap)
        #expect(report.artifacts.count >= 3)

        // Files landed at the configured paths and re-verify through the probe.
        #expect(FileManager.default.fileExists(atPath: paths.pairingArtifactFile.path))
        #expect(FileManager.default.fileExists(atPath: paths.agentDirectory.appendingPathComponent("starter-auth.json").path))
        #expect(FileManager.default.fileExists(atPath: paths.outputDirectory.appendingPathComponent("agent-operator-entity-link.json").path))

        let probe = await BootstrapProbeService(paths: paths).probe(configURL: paths.configFile)
        #expect(probe.readyForBootstrap)
    }

    @Test func rejectsPackBoundToDifferentAgent() async throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var (pack, paths, _) = try await mintPackAndConfig(root: root)

        // Tamper the binding to a foreign key.
        pack.boundAgent = .init(
            agentIdentityUUID: pack.boundAgent.agentIdentityUUID,
            agentPublicKeyBase64URL: Base64URL.encode(Curve25519.Signing.PrivateKey().publicKey.rawRepresentation)
        )
        let packURL = root.appendingPathComponent("pack.json")
        try JSONEncoder().encode(pack).write(to: packURL, options: [.atomic])

        await #expect(throws: ProvisioningImportError.self) {
            _ = try await ProvisioningPackImporter(paths: paths)
                .performImport(packURL: packURL, configURL: paths.configFile)
        }
        // Nothing should have been installed.
        #expect(FileManager.default.fileExists(atPath: paths.pairingArtifactFile.path) == false)
    }

    @Test func requestEmitsBoundAgentForOperator() async throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths.rooted(at: root)
        let config = PackFactory.makeConfig(paths: paths, domain: domain, purpose: purpose, interests: interests)
        try config.write(to: paths.configFile)

        let request = try await ProvisioningPackImporter(paths: paths).makeRequest(configURL: paths.configFile)

        #expect(request.scaffoldDomain == domain)
        #expect(request.purposeRef == purpose)
        #expect(request.boundAgent.agentPublicKeyBase64URL.isEmpty == false)
        // Identity now persisted, so a follow-up import can bind to it.
        #expect(FileManager.default.fileExists(atPath: paths.agentIdentityFile.path))
    }
}
