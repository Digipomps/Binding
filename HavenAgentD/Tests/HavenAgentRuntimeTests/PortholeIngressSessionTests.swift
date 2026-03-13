import Foundation
@preconcurrency import CellBase
import Testing
import SproutCore
import SproutCrypto
import SproutResolverAdapter
@testable import HavenAgentRuntime

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

private enum PortholeIngressFixtureFactory {
    static let resolverSeed = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"

    static func makeSignedPortholeAccessContract(
        issuedAt: String = "2026-03-13T09:00:00Z",
        expiresAt: String = "2026-03-13T09:05:00Z"
    ) throws -> PortholeAccessContract {
        let resolverPublicKey = try Ed25519.publicKeyBase64URL(fromSeedBase64URL: resolverSeed)
        var contract = PortholeAccessContract(
            contract_id: "pac_fixture_0001",
            scaffold_domain: "example.haven.local",
            entity_id: "entity_example_primary",
            identity_public_key: "m2J3MyPvQaEYNIJBlOVRZNMl65zcwQ3dp9EK3k-9j20",
            scaffold_admin_public_key: resolverPublicKey,
            bridge_descriptor_id: "bd_anchor_0001",
            bridge_endpoint: "wss://bridge.example.haven.local/cell",
            client_kind: .native,
            porthole_protocol: .cellprotocol,
            capability_grants: ["cap.join", "cap.discover"],
            purpose: "bootstrap.join_scaffold",
            goal: "Join scaffold and register identity",
            interests: ["haven.core.bootstrap", "haven.core.bridge"],
            issued_at: issuedAt,
            expires_at: expiresAt,
            issued_by: resolverPublicKey,
            entity_evidence_contract_id: nil,
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

struct PortholeIngressSessionTests {
    @Test
    func bootstrapArtifactLoaderBuildsNativeSessionFromJoinArtifact() throws {
        let contract = try PortholeIngressFixtureFactory.makeSignedPortholeAccessContract()
        let context = BootstrapExecutionContext(
            runtime: .macOSApp,
            domain: "example.haven.local",
            requestedPortholeKind: .native,
            portholeAccessContract: contract
        )

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let artifactURL = root.appendingPathComponent("sprout-bootstrap-state.json")
        try JSONEncoder().encode(context).write(to: artifactURL)

        let artifact = try SproutBootstrapArtifactLoader.loadNativeSession(
            from: artifactURL.path,
            now: ISO8601DateFormatter().date(from: "2026-03-13T09:01:00Z") ?? Date()
        )

        #expect(artifact.context.portholeAccessContract?.contract_id == "pac_fixture_0001")
        #expect(artifact.session.mode == .native)
        #expect(artifact.session.nativeDescriptor?.bridge_endpoint == contract.bridge_endpoint)
        #expect(artifact.session.nativeDescriptor?.cell_endpoint == "cell://bridge.example.haven.local/Porthole")
    }
}
