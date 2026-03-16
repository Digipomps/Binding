import Foundation
import Testing
import SproutCore
import SproutCrypto
import SproutResolverAdapter
@testable import HavenMacAutomation
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap
import Darwin

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

private final class BootstrapProbeProcessRunner: ProcessRunning, @unchecked Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        if let artifactPath = artifactPath(from: arguments) {
            let contract = try ProbeFixtureFactory.makeSignedPortholeAccessContract(contractID: "pac_probe_0001")
            let context = BootstrapExecutionContext(
                runtime: .macOSApp,
                domain: "staging.haven.digipomps.org",
                requestedPortholeKind: .native,
                portholeAccessContract: contract
            )
            try FileManager.default.createDirectory(
                at: artifactPath.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try JSONEncoder().encode(context).write(to: artifactPath, options: [.atomic])
        }

        return SubprocessResult(
            command: [executableURL.path] + arguments,
            terminationStatus: 0,
            standardOutput: #"{"final_state":"joined","contract_id":"pac_probe_0001"}"#,
            standardError: ""
        )
    }

    private func artifactPath(from arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "--state-out"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return URL(fileURLWithPath: NSString(string: arguments[index + 1]).expandingTildeInPath)
    }
}

private enum ProbeFixtureFactory {
    private struct PairingArtifactMirror: Codable {
        struct AgentEnrollmentAttestationMirror: Codable {
            struct Payload: Codable {
                var version: String
                var instanceName: String
                var agentIdentityUUID: String
                var agentDisplayName: String
                var agentDid: String
                var agentPublicKeyBase64URL: String
                var operatorIdentityUUID: String
                var operatorDid: String
                var operatorPublicKeyBase64URL: String
                var purposeRef: String
                var scaffoldDomain: String
                var challenge: String
                var issuedAt: String
            }

            var payload: Payload
            var signatureAlgorithm: String
            var signatureBase64URL: String

            func canonicalPayloadData() throws -> Data {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                return try encoder.encode(payload)
            }
        }

        struct OperatorApprovalMirror: Codable {
            struct Payload: Codable {
                var version: String
                var pairingID: String
                var scaffoldDomain: String
                var purposeRef: String
                var challenge: String
                var attestationSHA256Base64URL: String
                var operatorIdentityUUID: String
                var operatorDisplayName: String
                var operatorDid: String
                var operatorPublicKeyBase64URL: String
                var approvedAt: String
            }

            var payload: Payload
            var signatureBase64: String
            var curveType: String

            func canonicalPayloadData() throws -> Data {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                return try encoder.encode(payload)
            }
        }

        var version: String
        var pairingID: String
        var recordedAt: String
        var verificationStatus: String
        var agentAttestation: AgentEnrollmentAttestationMirror
        var operatorApproval: OperatorApprovalMirror
    }

    static let resolverSeed = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"

    static func makeConfig(paths: RuntimePaths, sproutBinaryPath: String) -> AgentConfig {
        AgentConfig(
            instanceName: "haven-agentd-probe",
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: sproutBinaryPath,
                startupMode: .join,
                runtime: "mac-agent",
                domain: "staging.haven.digipomps.org",
                purpose: "bootstrap.join_scaffold",
                goal: "Join staging scaffold",
                interests: ["haven.core.bootstrap", "haven.core.bridge"],
                resolverBaseURL: "https://staging.haven.digipomps.org",
                starterAuthPath: paths.agentDirectory.appendingPathComponent("starter-auth.json").path,
                entityLinkPath: paths.outputDirectory.appendingPathComponent("agent-operator-entity-link.json").path,
                continuityProofPath: nil,
                admissionContractPath: nil,
                discoveryURL: "https://staging.haven.digipomps.org/v1/bridges/query",
                catalogPath: nil,
                enableLiveResolver: true,
                trustedResolverKey: nil,
                requestedCapabilities: ["cap.native_porthole"],
                requestedPortholeKind: "native",
                renewalLeadTimeSeconds: 600
            ),
            watchFolders: [],
            automationPolicy: .init()
        )
    }

    static func writeExecutableStub(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url, options: [.atomic])
        #if os(macOS)
        chmod(url.path, 0o755)
        #endif
    }

    static func writePairingArtifact(
        to fileURL: URL,
        agentKey: Curve25519.Signing.PrivateKey,
        operatorKey: Curve25519.Signing.PrivateKey,
        scaffoldDomain: String,
        purposeRef: String
    ) throws {
        let recordedAt = "2026-03-15T12:00:00Z"
        let challenge = "pairing-\(UUID().uuidString.lowercased())"
        let pairingID = "pair_\(UUID().uuidString.lowercased())"
        let agentPublicKey = Base64URL.encode(agentKey.publicKey.rawRepresentation)
        let operatorPublicKey = Base64URL.encode(operatorKey.publicKey.rawRepresentation)
        let attestationPayload = PairingArtifactMirror.AgentEnrollmentAttestationMirror.Payload(
            version: "1.0",
            instanceName: "haven-agentd-probe",
            agentIdentityUUID: "agent-identity-001",
            agentDisplayName: "HAVEN Agent",
            agentDid: "did:key:zAgentFixture",
            agentPublicKeyBase64URL: agentPublicKey,
            operatorIdentityUUID: "operator-identity-001",
            operatorDid: "did:key:zOperatorFixture",
            operatorPublicKeyBase64URL: operatorPublicKey,
            purposeRef: purposeRef,
            scaffoldDomain: scaffoldDomain,
            challenge: challenge,
            issuedAt: recordedAt
        )
        var attestation = PairingArtifactMirror.AgentEnrollmentAttestationMirror(
            payload: attestationPayload,
            signatureAlgorithm: "Ed25519",
            signatureBase64URL: ""
        )
        attestation.signatureBase64URL = Base64URL.encode(
            try agentKey.signature(for: attestation.canonicalPayloadData())
        )

        let attestationDigest = Data(SHA256.hash(data: try attestation.canonicalPayloadData()))
        let approvalPayload = PairingArtifactMirror.OperatorApprovalMirror.Payload(
            version: "1.0",
            pairingID: pairingID,
            scaffoldDomain: scaffoldDomain,
            purposeRef: purposeRef,
            challenge: challenge,
            attestationSHA256Base64URL: Base64URL.encode(attestationDigest),
            operatorIdentityUUID: "operator-identity-001",
            operatorDisplayName: "private",
            operatorDid: "did:key:zOperatorFixture",
            operatorPublicKeyBase64URL: operatorPublicKey,
            approvedAt: recordedAt
        )
        var approval = PairingArtifactMirror.OperatorApprovalMirror(
            payload: approvalPayload,
            signatureBase64: "",
            curveType: "ed25519"
        )
        approval.signatureBase64 = try operatorKey.signature(for: approval.canonicalPayloadData()).base64EncodedString()

        let artifact = PairingArtifactMirror(
            version: "1.0",
            pairingID: pairingID,
            recordedAt: recordedAt,
            verificationStatus: "agent-attestation-verified",
            agentAttestation: attestation,
            operatorApproval: approval
        )

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(artifact).write(to: fileURL, options: [.atomic])
    }

    static func writeStarterAuth(
        to fileURL: URL,
        agentKey: Curve25519.Signing.PrivateKey,
        domain: String,
        purpose: String,
        interests: [String]
    ) throws {
        let formatter = ISO8601DateFormatter()
        let createdAt = Date()
        let expiresAt = createdAt.addingTimeInterval(900)
        var payload = StarterAuthPayload(
            version: "1.0",
            domain: domain,
            identity_public_key: Base64URL.encode(agentKey.publicKey.rawRepresentation),
            created_at: formatter.string(from: createdAt),
            expires_at: formatter.string(from: expiresAt),
            nonce: "starter-fixture",
            purpose_interest: StarterPurposeInterest(purpose: purpose, interests: interests),
            signature: ResolverSignatureEnvelope(alg: "Ed25519", sig: "")
        )
        payload.signature = ResolverSignatureEnvelope(
            alg: "Ed25519",
            sig: Base64URL.encode(try agentKey.signature(for: payload.canonicalPayloadData()))
        )

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: fileURL, options: [.atomic])
    }

    static func writeEntityLink(
        to fileURL: URL,
        agentKey: Curve25519.Signing.PrivateKey,
        operatorKey: Curve25519.Signing.PrivateKey,
        domain: String,
        purpose: String
    ) throws {
        var contract = EntityLinkContract(
            contract_id: "elc_fixture_0001",
            domain_a: domain,
            pubkey_a: Base64URL.encode(operatorKey.publicKey.rawRepresentation),
            domain_b: domain,
            pubkey_b: Base64URL.encode(agentKey.publicKey.rawRepresentation),
            scope: "purpose-bound:\(purpose)",
            created_at: "2026-03-15T12:00:00Z",
            revocation: EntityLinkRevocation(mode: "mutual"),
            signatures: []
        )

        let canonical = try contract.canonicalPayloadData()
        contract.signatures = [
            EntityLinkSignature(
                by_pubkey: contract.pubkey_a,
                alg: "Ed25519",
                sig: Base64URL.encode(try operatorKey.signature(for: canonical))
            ),
            EntityLinkSignature(
                by_pubkey: contract.pubkey_b,
                alg: "Ed25519",
                sig: Base64URL.encode(try agentKey.signature(for: canonical))
            )
        ]

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(contract).write(to: fileURL, options: [.atomic])
    }

    static func makeSignedPortholeAccessContract(contractID: String) throws -> PortholeAccessContract {
        let formatter = ISO8601DateFormatter()
        let issuedAt = Date()
        let expiresAt = issuedAt.addingTimeInterval(600)
        let resolverPublicKey = try Ed25519.publicKeyBase64URL(fromSeedBase64URL: resolverSeed)
        var contract = PortholeAccessContract(
            contract_id: contractID,
            scaffold_domain: "staging.haven.digipomps.org",
            entity_id: "entity_staging_fixture",
            identity_public_key: "m2J3MyPvQaEYNIJBlOVRZNMl65zcwQ3dp9EK3k-9j20",
            scaffold_admin_public_key: resolverPublicKey,
            bridge_descriptor_id: "bd_probe_0001",
            bridge_endpoint: "wss://bridge.staging.haven.digipomps.org/cell",
            client_kind: .native,
            porthole_protocol: .cellprotocol,
            capability_grants: ["cap.native_porthole"],
            purpose: "bootstrap.join_scaffold",
            goal: "Join staging scaffold",
            interests: ["haven.core.bootstrap", "haven.core.bridge"],
            issued_at: formatter.string(from: issuedAt),
            expires_at: formatter.string(from: expiresAt),
            issued_by: resolverPublicKey,
            entity_evidence_contract_id: "elc_fixture_0001",
            signature: ResolverSignatureEnvelope(alg: "Ed25519", sig: "")
        )
        contract.signature = ResolverSignatureEnvelope(
            alg: "Ed25519",
            sig: try Ed25519.signBase64URL(
                data: try contract.canonicalPayloadData(),
                seedBase64URL: resolverSeed
            )
        )
        return contract
    }
}

struct BootstrapProbeServiceTests {
    @Test
    func probePreflightValidatesEnrollmentArtifacts() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDProbe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let agentKey = Curve25519.Signing.PrivateKey()
        let operatorKey = Curve25519.Signing.PrivateKey()
        let sproutPath = root.appendingPathComponent("fake-sprout").path
        let config = ProbeFixtureFactory.makeConfig(paths: paths, sproutBinaryPath: sproutPath)

        try ProbeFixtureFactory.writePairingArtifact(
            to: paths.pairingArtifactFile,
            agentKey: agentKey,
            operatorKey: operatorKey,
            scaffoldDomain: config.scaffold.domain,
            purposeRef: try #require(config.scaffold.purpose)
        )
        try ProbeFixtureFactory.writeStarterAuth(
            to: URL(fileURLWithPath: try #require(config.scaffold.starterAuthPath)),
            agentKey: agentKey,
            domain: config.scaffold.domain,
            purpose: try #require(config.scaffold.purpose),
            interests: config.scaffold.interests
        )
        try ProbeFixtureFactory.writeEntityLink(
            to: URL(fileURLWithPath: try #require(config.scaffold.entityLinkPath)),
            agentKey: agentKey,
            operatorKey: operatorKey,
            domain: config.scaffold.domain,
            purpose: try #require(config.scaffold.purpose)
        )
        try config.write(to: paths.configFile)

        let report = await BootstrapProbeService(paths: paths).probe(configURL: paths.configFile)

        #expect(report.readyForBootstrap)
        #expect(report.pairingArtifact.valid)
        #expect(report.starterAuth.valid)
        #expect(report.entityLink.valid)
        #expect(report.bootstrap == nil)
    }

    @Test
    func probeCanRunBootstrapAndLoadNativeJoinArtifact() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDProbe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let agentKey = Curve25519.Signing.PrivateKey()
        let operatorKey = Curve25519.Signing.PrivateKey()
        let sproutPath = root.appendingPathComponent("fake-sprout").path
        let config = ProbeFixtureFactory.makeConfig(paths: paths, sproutBinaryPath: sproutPath)

        try ProbeFixtureFactory.writeExecutableStub(at: sproutPath)
        try ProbeFixtureFactory.writePairingArtifact(
            to: paths.pairingArtifactFile,
            agentKey: agentKey,
            operatorKey: operatorKey,
            scaffoldDomain: config.scaffold.domain,
            purposeRef: try #require(config.scaffold.purpose)
        )
        try ProbeFixtureFactory.writeStarterAuth(
            to: URL(fileURLWithPath: try #require(config.scaffold.starterAuthPath)),
            agentKey: agentKey,
            domain: config.scaffold.domain,
            purpose: try #require(config.scaffold.purpose),
            interests: config.scaffold.interests
        )
        try ProbeFixtureFactory.writeEntityLink(
            to: URL(fileURLWithPath: try #require(config.scaffold.entityLinkPath)),
            agentKey: agentKey,
            operatorKey: operatorKey,
            domain: config.scaffold.domain,
            purpose: try #require(config.scaffold.purpose)
        )
        try config.write(to: paths.configFile)

        let report = await BootstrapProbeService(
            paths: paths,
            processRunner: BootstrapProbeProcessRunner()
        ).probe(
            configURL: paths.configFile,
            runBootstrap: true
        )

        #expect(report.readyForBootstrap)
        #expect(report.bootstrap?.attempted == true)
        #expect(report.bootstrap?.succeeded == true)
        #expect(report.bootstrap?.contractID == "pac_probe_0001")
        #expect(report.bootstrap?.artifactPath == paths.stateDirectory.appendingPathComponent("sprout-bootstrap-state.json").path)
    }
}
