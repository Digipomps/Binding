// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Vapor
import CellBase

struct SproutBridgeDiscoveryQuery: Content, Equatable {
    var scaffold_domain: String
    var purpose: String
    var interests: [String]
}

struct SproutBridgeDiscoveryResponse: Content, Equatable {
    var bridges: [SproutBridgeDescriptor]
}

struct SproutBridgeDescriptor: Content, Equatable {
    var descriptor_id: String
    var bridge_endpoint: String
    var scaffold_domain: String
    var owner_pubkey: String
    var capability_requirements: [String]
    var purpose_constraints: [String]
    var expires_at: String
    var signature: SproutResolverSignatureEnvelope

    func canonicalPayloadData() throws -> Data {
        try SproutJCSCanonicalizer.canonicalizeRemovingTopLevelKeys(
            try JSONEncoder().encode(self),
            keys: ["signature"]
        )
    }

    func verifySignature() throws -> Bool {
        guard signature.alg == "Ed25519" else { return false }
        let payload = try canonicalPayloadData()
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: SproutBase64URL.decode(owner_pubkey))
        return publicKey.isValidSignature(try SproutBase64URL.decode(signature.sig), for: payload)
    }
}

struct SproutBridgeDiscoveryConfiguration {
    var scaffoldDomain: String
    var adminIdentityContext: String
    var allowedPurposes: Set<String>
    var capabilityRequirements: [String]
    var descriptorTTLSeconds: TimeInterval
    var bridgePublisherID: String
    var bridgeID: String
    var nativePortholePurposes: Set<String>

    static func fromEnvironment() -> SproutBridgeDiscoveryConfiguration {
        let ownerContext = Environment.get("CELL_SCAFFOLD_OWNER_CONTEXT") ?? "Scaffold"
        let ttlSeconds = Double(Environment.get("SPROUT_BRIDGE_DESCRIPTOR_TTL_SECONDS") ?? "") ?? 300
        return SproutBridgeDiscoveryConfiguration(
            scaffoldDomain: Environment.get("SPROUT_SCAFFOLD_DOMAIN") ?? Environment.get("RP_ID") ?? "localhost",
            adminIdentityContext: ownerContext,
            allowedPurposes: sproutParseCSVSet(
                Environment.get("SPROUT_BRIDGE_ALLOWED_PURPOSES"),
                defaultValue: ["bootstrap.join_scaffold"]
            ),
            capabilityRequirements: Array(
                sproutParseCSVSet(
                    Environment.get("SPROUT_BRIDGE_CAPABILITY_REQUIREMENTS"),
                    defaultValue: ["cap.join", "cap.discover"]
                )
            ).sorted(),
            descriptorTTLSeconds: max(ttlSeconds, 60),
            bridgePublisherID: sproutTrimmed(Environment.get("SPROUT_BRIDGE_PUBLISHER_ID")) ?? "Porthole",
            bridgeID: sproutTrimmed(Environment.get("SPROUT_BRIDGE_ID")) ?? "CloudBridge",
            nativePortholePurposes: sproutParseCSVSet(
                Environment.get("SPROUT_NATIVE_PORTHOLE_PURPOSES"),
                defaultValue: ["purpose://operate-local-haven-agent"]
            )
        )
    }
}

actor SproutBridgeDiscoveryService {
    private let configuration: SproutBridgeDiscoveryConfiguration
    private let formatter = ISO8601DateFormatter()

    init(configuration: SproutBridgeDiscoveryConfiguration = .fromEnvironment()) {
        self.configuration = configuration
    }

    func queryBridges(
        _ query: SproutBridgeDiscoveryQuery,
        requestContext: SproutResolverRequestContext
    ) async throws -> SproutBridgeDiscoveryResponse {
        guard query.scaffold_domain == configuration.scaffoldDomain else {
            throw Abort(.forbidden, reason: "scaffold domain mismatch")
        }

        let trimmedPurpose = query.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPurpose.isEmpty else {
            throw Abort(.badRequest, reason: "purpose must be explicit")
        }
        guard !query.interests.isEmpty else {
            throw Abort(.badRequest, reason: "interests must be explicit")
        }
        guard configuration.allowedPurposes.contains(trimmedPurpose) else {
            throw Abort(.forbidden, reason: "purpose is not allowed by bridge discovery policy")
        }

        let ownerIdentity = try await scaffoldAdminIdentity()
        let ownerPublicKey = try publicKeyBase64URL(for: ownerIdentity)
        let issuedAt = Date()
        let expiresAt = issuedAt.addingTimeInterval(configuration.descriptorTTLSeconds)
        let bridgeEndpoint = try bridgeBaseURL(
            query: query,
            requestContext: requestContext,
            nativePorthole: configuration.nativePortholePurposes.contains(trimmedPurpose)
        )
        let descriptorIDSeed = "\(configuration.scaffoldDomain)|\(trimmedPurpose)|\(ownerPublicKey)|\(bridgeEndpoint)"

        var descriptor = SproutBridgeDescriptor(
            descriptor_id: "bd_\(SproutHashing.sha256Base64URL(Data(descriptorIDSeed.utf8)).prefix(16))",
            bridge_endpoint: bridgeEndpoint,
            scaffold_domain: configuration.scaffoldDomain,
            owner_pubkey: ownerPublicKey,
            capability_requirements: configuration.capabilityRequirements,
            purpose_constraints: [trimmedPurpose],
            expires_at: formatter.string(from: expiresAt),
            signature: SproutResolverSignatureEnvelope(alg: "Ed25519", sig: "")
        )
        descriptor.signature = SproutResolverSignatureEnvelope(
            alg: "Ed25519",
            sig: try await signBase64URL(payload: descriptor.canonicalPayloadData(), with: ownerIdentity)
        )
        return SproutBridgeDiscoveryResponse(bridges: [descriptor])
    }

    private func scaffoldAdminIdentity() async throws -> Identity {
        guard let vault = CellBase.defaultIdentityVault else {
            throw Abort(.internalServerError, reason: "identity vault unavailable")
        }
        guard let identity = await vault.identity(for: configuration.adminIdentityContext, makeNewIfNotFound: false) else {
            throw Abort(.internalServerError, reason: "scaffold admin identity unavailable")
        }
        return identity
    }

    private func publicKeyBase64URL(for identity: Identity) throws -> String {
        guard let publicKey = identity.publicSecureKey?.compressedKey else {
            throw Abort(.internalServerError, reason: "scaffold admin public key unavailable")
        }
        return SproutBase64URL.encode(publicKey)
    }

    private func signBase64URL(payload: Data, with identity: Identity) async throws -> String {
        guard let signature = try await identity.sign(data: payload) else {
            throw Abort(.internalServerError, reason: "failed to sign bridge descriptor")
        }
        return SproutBase64URL.encode(signature)
    }

    private func bridgeBaseURL(
        query: SproutBridgeDiscoveryQuery,
        requestContext: SproutResolverRequestContext,
        nativePorthole: Bool
    ) throws -> String {
        let scheme = sproutResolvedScheme(forwardedProto: requestContext.forwardedProto, websocket: true)
        guard var components = URLComponents(string: "\(scheme)://\(requestContext.hostHeader)") else {
            throw Abort(.badRequest, reason: "invalid host header")
        }
        if nativePorthole {
            components.path = "/v1/resolver/native-porthole/\(configuration.bridgePublisherID)"
        } else {
            let target = bridgeTarget(for: query)
            components.path = "/bridgehead/\(target.publisherID)/\(target.bridgeID)"
        }
        guard let url = components.url else {
            throw Abort(.internalServerError, reason: "invalid bridge endpoint")
        }
        return url.absoluteString
    }

    private func bridgeTarget(for query: SproutBridgeDiscoveryQuery) -> (publisherID: String, bridgeID: String) {
        let interests = Set(query.interests.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if interests.contains("rag.catalog.publish") || interests.contains("cell:///raggateway") {
            return ("RAGGateway", "Add2EntityCapture")
        }
        if interests.contains("project.list") || interests.contains("project.create") || interests.contains("cell:///projectportfolio") {
            return ("ProjectPortfolio", "Add2EntityProjects")
        }
        return (configuration.bridgePublisherID, configuration.bridgeID)
    }
}

private struct SproutBridgeDiscoveryServiceKey: StorageKey {
    typealias Value = SproutBridgeDiscoveryService
}

extension Application {
    var sproutBridgeDiscoveryService: SproutBridgeDiscoveryService {
        if let existing = storage[SproutBridgeDiscoveryServiceKey.self] {
            return existing
        }
        let service = SproutBridgeDiscoveryService()
        storage[SproutBridgeDiscoveryServiceKey.self] = service
        return service
    }
}
