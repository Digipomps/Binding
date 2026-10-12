// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import CryptoKit
import Foundation

/// Cell payload metadata delivered through the shared authenticated Bridge.
/// Exact scopes bound locally here never replace each Cell's current access check.
nonisolated enum BindingPersonEntityReadRouteContract {
    static let schema = "haven.entity-data-bridge-scopes.v1"
    static let scopeKey = "entityData.proofScopes"
    static let domain = "private"
    static let maximumDescriptorBytes = 8 * 1024
    static let setupLifetime: TimeInterval = 60
    static let connectionLifetime: TimeInterval = 300
    static let clockSkew: TimeInterval = 5

    struct Scope: Codable, Equatable, Sendable {
        enum Role: String, Codable, Sendable { case gateway, query, anchor }
        let role: Role
        let domain: String
        let cellUUID: String
    }
    struct Descriptor: Codable, Equatable, Sendable {
        var schema = BindingPersonEntityReadRouteContract.schema
        var status = "ready"
        let origin: String
        let evidenceReference: String
        let linkID: String
        let linkedIdentityUUID: String
        let linkedKeyFingerprint: String
        let expiresAt: TimeInterval
        let scopes: [Scope]
    }
    enum Failure: Error, Equatable { case malformed, denied, expired, replayed, capacity, unavailable }

    static func scopeRequest(reference: String, linkID: String) -> ValueType {
        .object(["schema": .string(schema), "personEntityEvidenceRef": .string(reference), "personEntityLinkID": .string(linkID)])
    }

    static func decodeDescriptor(_ value: ValueType?, reference: String, linkID: String,
                                 identity: Identity, origin: String, gatewayUUID: String,
                                 approvedDomains: [String], now: Date) throws -> Descriptor {
        guard case let .object(object)? = value else { throw Failure.malformed }
        if object["status"] == .string("denied") { throw Failure.denied }
        guard Set(object.keys) == ["schema", "status", "origin", "evidenceReference", "linkID",
                                  "linkedIdentityUUID", "linkedKeyFingerprint", "expiresAt", "scopes"],
              case let .list(scopes)? = object["scopes"], scopes.count == 3,
              scopes.allSatisfy({ row in
                  guard case let .object(scope) = row else { return false }
                  return Set(scope.keys) == ["role", "domain", "cellUUID"]
              }) else { throw Failure.malformed }
        let data = try encode(object)
        guard data.count <= maximumDescriptorBytes else { throw Failure.malformed }
        let descriptor = try JSONDecoder().decode(Descriptor.self, from: data)
        try validateDescriptor(descriptor, reference: reference, linkID: linkID, identity: identity,
            origin: origin, gatewayUUID: gatewayUUID, approvedDomains: approvedDomains, now: now)
        return descriptor
    }

    static func validateDescriptor(_ d: Descriptor, reference: String, linkID: String,
                                   identity: Identity, origin: String, gatewayUUID: String,
                                   approvedDomains: [String], now: Date) throws {
        guard d.schema == schema, d.status == "ready", d.origin == origin,
              d.evidenceReference == reference, isDigest(reference), d.linkID == linkID,
              UUID(uuidString: linkID) != nil, linkID.utf8.count == 36,
              d.linkedIdentityUUID == identity.uuid, d.linkedKeyFingerprint == identity.signingPublicKeyFingerprint,
              d.expiresAt.isFinite, d.expiresAt > now.timeIntervalSince1970,
              d.expiresAt <= now.timeIntervalSince1970 + setupLifetime + clockSkew,
              d.scopes.count == 3,
              Set(d.scopes.map(\.role.rawValue)) == Set(["gateway", "query", "anchor"]),
              Set(d.scopes.map(\.cellUUID)).count == 3,
              d.scopes.first(where: { $0.role == .gateway })?.cellUUID == gatewayUUID,
              d.scopes.allSatisfy({ $0.domain == domain && approvedDomains.contains($0.domain)
                  && UUID(uuidString: $0.cellUUID) != nil && $0.cellUUID.utf8.count == 36 }),
              try encode(d).count <= maximumDescriptorBytes else { throw Failure.denied }
    }

    static func endpoint(origin: String, bridgeID: String = UUID().uuidString) throws -> URL {
        guard var url = URLComponents(string: origin), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty, url.string == origin, UUID(uuidString: bridgeID) != nil else { throw Failure.malformed }
        url.scheme = "wss"; url.path = "/bridgehead/EntityDataGateway/" + bridgeID
        guard let result = url.url else { throw Failure.malformed }
        return result
    }
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    static func isDigest(_ value: String) -> Bool { value.utf8.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } }
}
