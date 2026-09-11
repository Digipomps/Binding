// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import CryptoKit
import Foundation

/// App wire contract mirrored from CellScaffold; compare canonical fixtures.
/// Application transport setup only. These signatures cannot authorize a
/// GeneralCell operation, elect an authority, or grant storage permission.
nonisolated enum BindingPersonEntityReadRouteContract {
    static let proofSchema = "haven.person-entity-read-route-proof.v1"
    static let descriptorSchema = "haven.person-entity-read-route.v1"
    // Current GeneralCell operation domain. CellResolve's registration domain
    // selects a service owner and does not change this access-control domain.
    static let domain = "private"
    static let discoveryAction = "person-entity-read-route.discover.v1"
    static let openAction = "person-entity-read-route.open.v1"
    static let discoveryPath = "/entity-data/read/route"
    static let bridgePath = "/entity-data/read/bridge"
    static let proofHeader = "X-Haven-Person-Read-Proof"
    static let maximumProofBytes = 4 * 1024
    static let maximumDescriptorBytes = 8 * 1024
    static let maximumOpenBytes = 5 * 1024
    static let maximumOpenHeaderBytes = 8 * 1024
    static let maximumInboundFrameBytes = 128 * 1024
    static let maximumOutboundFrameBytes = 1024 * 1024
    static let setupLifetime: TimeInterval = 60
    static let connectionLifetime: TimeInterval = 300
    static let clockSkew: TimeInterval = 5

    struct Proof: Codable, Equatable, Sendable {
        var schema = BindingPersonEntityReadRouteContract.proofSchema
        let evidenceReference: String
        let linkID: String
        let challenge: Data
        let signature: Data
    }

    struct Scope: Codable, Equatable, Sendable {
        enum Role: String, Codable, Sendable { case gateway, query, anchor }
        let role: Role
        let domain: String
        let cellUUID: String
    }

    struct OpenRequest: Codable, Equatable, Sendable {
        let descriptorDigest: String
        let proof: Proof
    }

    struct Descriptor: Codable, Equatable, Sendable {
        var schema = BindingPersonEntityReadRouteContract.descriptorSchema
        let origin: String
        let websocketURL: String
        let evidenceReference: String
        let linkID: String
        let linkedIdentityUUID: String
        let linkedKeyFingerprint: String
        let requestDigest: String
        let instanceNonce: String
        let setupExpiresAt: TimeInterval
        let connectionLifetimeSeconds: TimeInterval
        let scopes: [Scope]
    }

    enum Failure: Error, Equatable {
        case malformed, denied, expired, replayed, capacity, unavailable
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    /// Canonical encoding rejects ignored fields, duplicate keys and alternate
    /// encodings before their bytes can become a descriptor/replay binding.
    static func decodeProof(_ data: Data) throws -> Proof {
        guard data.count <= maximumProofBytes,
              let proof = try? JSONDecoder().decode(Proof.self, from: data),
              try encode(proof) == data else { throw Failure.malformed }
        try validateShape(proof)
        return proof
    }

    static func validateShape(_ proof: Proof) throws {
        guard proof.schema == proofSchema, isDigest(proof.evidenceReference),
              UUID(uuidString: proof.linkID) != nil, proof.linkID.utf8.count == 36,
              proof.challenge.count <= IdentitySigningChallenge.maximumEncodedBytes,
              !proof.signature.isEmpty, proof.signature.count <= 256,
              try encode(proof).count <= maximumProofBytes else { throw Failure.malformed }
    }

    static func decodeOpenHeader(_ header: String) throws -> OpenRequest {
        guard header.utf8.count <= maximumOpenHeaderBytes,
              let data = Data(base64Encoded: header), data.count <= maximumOpenBytes,
              data.base64EncodedString() == header,
              let request = try? JSONDecoder().decode(OpenRequest.self, from: data),
              try encode(request) == data, isDigest(request.descriptorDigest) else { throw Failure.malformed }
        try validateShape(request.proof)
        return request
    }

    static func discoveryResource(reference: String, linkID: String) -> String {
        "person-entity-read-route:\(reference):\(linkID)"
    }

    static func openResource(descriptor: Descriptor) throws -> String {
        "person-entity-read-open:" + digest(try encode(descriptor))
    }

    static func verify(_ proof: Proof, identity: Identity, origin: String,
                       action: String, resource: String, now: Date) throws {
        try validateShape(proof)
        let challenge = try IdentitySigningChallenge.validateSigningData(proof.challenge, for: identity, now: now)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard try encoder.encode(challenge) == proof.challenge,
              challenge.domain == domain, challenge.audience == origin,
              challenge.action == action, challenge.resource == resource,
              challenge.issuedAt <= now.timeIntervalSince1970 + clockSkew,
              challenge.expiresAt - challenge.issuedAt > 0,
              challenge.expiresAt - challenge.issuedAt <= setupLifetime,
              IdentityPublicKeySignatureVerifier.verify(signature: proof.signature, messageData: proof.challenge, identity: identity) else {
            throw Failure.denied
        }
    }

    static func validateDescriptor(_ descriptor: Descriptor, proof: Proof,
                                   identity: Identity, origin: String, approvedDomains: [String], now: Date) throws {
        guard descriptor.schema == descriptorSchema, descriptor.origin == origin,
              descriptor.evidenceReference == proof.evidenceReference, descriptor.linkID == proof.linkID,
              descriptor.linkedIdentityUUID == identity.uuid,
              descriptor.linkedKeyFingerprint == identity.signingPublicKeyFingerprint,
              descriptor.requestDigest == digest(try encode(proof)),
              isDigest(descriptor.instanceNonce),
              descriptor.setupExpiresAt > now.timeIntervalSince1970,
              descriptor.setupExpiresAt <= now.timeIntervalSince1970 + setupLifetime + clockSkew,
              descriptor.connectionLifetimeSeconds == connectionLifetime,
              descriptor.websocketURL == (try websocketURL(origin: origin)),
              descriptor.scopes.count == 3,
              Set(descriptor.scopes.map(\.role.rawValue)) == Set(["gateway", "query", "anchor"]),
              Set(descriptor.scopes.map(\.cellUUID)).count == 3,
              descriptor.scopes.allSatisfy({ $0.domain == domain && approvedDomains.contains($0.domain)
                  && UUID(uuidString: $0.cellUUID) != nil && $0.cellUUID.utf8.count == 36 }),
              try encode(descriptor).count <= maximumDescriptorBytes else { throw Failure.denied }
    }

    static func websocketURL(origin: String) throws -> String {
        guard var url = URLComponents(string: origin), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty, url.string == origin else { throw Failure.malformed }
        url.scheme = "wss"; url.path = bridgePath
        guard let result = url.string else { throw Failure.malformed }
        return result
    }

    static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    static func isDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
}
