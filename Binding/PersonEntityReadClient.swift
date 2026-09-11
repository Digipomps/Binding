// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import CryptoKit
import Foundation

/// Explicit one-direction reads of a previously completed person ceremony.
/// No key provisioning, registry mutation, data cache or automatic reconnect.
actor PersonEntityReadClient {
    private typealias C = BindingPersonEntityReadRouteContract
    typealias ExistingIdentityResolver = @Sendable (String) async -> Identity?
    private let resolveIdentity: ExistingIdentityResolver
    private var bridge: BridgeBase?
    private var transport: BindingPersonEntityReadTransport?
    private var linked: Identity?
    private var descriptor: C.Descriptor?
    private var expiresAt: Date?
    private var connectionAttempt: UUID?
    private var pendingTransport: BindingPersonEntityReadTransport?
    private var queryAttempt: UUID?

    init(resolveIdentity: @escaping ExistingIdentityResolver = { uuid in
        await BindingStartupIdentityVault.shared.identity(forUUID: uuid)
    }) { self.resolveIdentity = resolveIdentity }

    /// The caller supplies the explicitly selected saved receipt. Merely
    /// loading all receipts must never start network activity or sign proofs.
    func connect(entry: IdentityLinkCompletionStore.Entry) async throws {
        try Task.checkCancellation()
        guard bridge == nil, connectionAttempt == nil else { throw C.Failure.capacity }
        let attempt = UUID()
        connectionAttempt = attempt
        defer { if connectionAttempt == attempt { connectionAttempt = nil; pendingTransport = nil } }
        guard entry.origin.hasPrefix("https://"), IdentityLinkTrust.isTrustedOrigin(entry.origin),
              entry.envelope.expectedOrigin == entry.origin,
              entry.record.status == .active, entry.record.issuerType == .existingDevice,
              entry.record.approvedDomains.contains(C.domain),
              IdentityLinkScope.grantsSameEntity(entry.record.approvedScopes),
              let reference = entry.personEvidenceReference, C.isDigest(reference),
              let verifiedAt = ISO8601DateFormatter().date(from: entry.record.linkedAt),
              verifiedAt <= Date().addingTimeInterval(C.clockSkew) else { throw C.Failure.denied }
        // Historical signature validation only, as in the completion outbox.
        // Current permission and fresh person evidence are checked by the server.
        let historical = try await IdentityLinkProtocolService.verifyCompletion(entry.envelope, now: verifiedAt)
        var expected = historical.record; var recorded = entry.record
        expected.linkedAt = ""; recorded.linkedAt = ""
        expected.lastUsedAt = nil; recorded.lastUsedAt = nil
        guard expected == recorded, C.digest(historical.requestHash) == reference,
              let identity = await resolveIdentity(recorded.linkedIdentity.uuid),
              identity.uuid == recorded.linkedIdentity.uuid,
              identity.publicSecureKey?.compressedKey == recorded.linkedIdentity.publicKey,
              identity.publicSecureKey?.algorithm == recorded.linkedIdentity.algorithm,
              identity.publicSecureKey?.curveType == recorded.linkedIdentity.curveType,
              let vault = identity.identityVault,
              let home = identity.homeVaultReference, home == (await vault.identityVaultReference()),
              await vault.identityExistInVault(identity) else { throw C.Failure.denied }
        try Task.checkCancellation()
        guard connectionAttempt == attempt else { throw CancellationError() }
        let discovery = try await Self.proof(identity: identity, reference: reference, linkID: recorded.linkID,
            origin: entry.origin, action: C.discoveryAction,
            resource: C.discoveryResource(reference: reference, linkID: recorded.linkID))
        try Task.checkCancellation()
        guard connectionAttempt == attempt else { throw CancellationError() }
        let descriptor = try await Self.discover(discovery, origin: entry.origin)
        try C.validateDescriptor(descriptor, proof: discovery, identity: identity, origin: entry.origin,
            approvedDomains: recorded.approvedDomains, now: Date())
        try Task.checkCancellation()
        guard connectionAttempt == attempt else { throw CancellationError() }
        let opening = try await Self.proof(identity: identity, reference: reference, linkID: recorded.linkID,
            origin: entry.origin, action: C.openAction, resource: C.openResource(descriptor: descriptor))
        let open = C.OpenRequest(descriptorDigest: C.digest(try C.encode(descriptor)), proof: opening)
        let header = try C.encode(open).base64EncodedString()
        _ = try C.decodeOpenHeader(header)
        guard let url = URL(string: descriptor.websocketURL), Date().timeIntervalSince1970 < descriptor.setupExpiresAt else {
            throw C.Failure.expired
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue(header, forHTTPHeaderField: C.proofHeader)
        let transport = BindingPersonEntityReadTransport(request: request, identity: identity)
        let bridge = try await BridgeBase(.init(owner: identity, transport: transport, connection: .outbound,
            identityProofScopes: descriptor.scopes.map { BridgeIdentityProofScope(domain: $0.domain, resource: $0.cellUUID) }))
        do {
            guard connectionAttempt == attempt else { throw CancellationError() }
            pendingTransport = transport
            try await bridge.setTransport(transport, connection: .outbound)
            let connectionExpiry = Date().addingTimeInterval(C.connectionLifetime)
            try await transport.setup(url, identity: identity)
            try Task.checkCancellation()
            try await bridge.retrieveProxyRepresentation(for: identity)
            guard connectionAttempt == attempt else { throw CancellationError() }
            guard Date() < connectionExpiry else { throw C.Failure.expired }
            self.bridge = bridge; self.transport = transport; linked = identity
            self.descriptor = descriptor
            expiresAt = connectionExpiry
        } catch {
            bridge.close(requester: identity)
            await transport.close()
            throw error
        }
    }

    func read(keypaths: [String]) async throws -> ValueType {
        try Task.checkCancellation()
        // The pinned BridgeBase correlates SET replies by keypath. Concurrent
        // entityData.query calls on one bridge would overwrite its callback.
        guard queryAttempt == nil else { throw C.Failure.capacity }
        guard let bridge, let linked, let descriptor, let expiresAt, Date() < expiresAt,
              !keypaths.isEmpty, keypaths.count <= 16,
              keypaths.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 1024 }) else { throw C.Failure.unavailable }
        let attempt = UUID()
        queryAttempt = attempt
        defer { if queryAttempt == attempt { queryAttempt = nil } }
        let requests: [ValueType] = keypaths.enumerated().map { index, keypath in
            .object(["requestID": .string(String(index)), "keypath": .string(keypath)])
        }
        let payload: ValueType = .object([
            "schema": .string("haven.entity-data-query.v1"),
            "personEntityEvidenceRef": .string(descriptor.evidenceReference),
            "personEntityLinkID": .string(descriptor.linkID), "requests": .list(requests)
        ])
        guard let result = try await bridge.set(keypath: "entityData.query", value: payload, requester: linked) else {
            throw C.Failure.unavailable
        }
        try Task.checkCancellation()
        guard queryAttempt == attempt, self.bridge === bridge, Date() < expiresAt else { throw C.Failure.unavailable }
        return result
    }

    func close() async {
        if let bridge, let linked { bridge.close(requester: linked) }
        let closing = transport
        let pending = pendingTransport
        connectionAttempt = nil; pendingTransport = nil; queryAttempt = nil
        bridge = nil; transport = nil; linked = nil; descriptor = nil; expiresAt = nil
        await closing?.close()
        await pending?.close()
    }

    private static func proof(identity: Identity, reference: String, linkID: String, origin: String,
                              action: String, resource: String) async throws -> C.Proof {
        guard let nonce = await identity.identityVault?.randomBytes64() else { throw C.Failure.unavailable }
        let challenge = try IdentitySigningChallenge.signingData(for: identity, trustedIdentity: identity,
            domain: C.domain, resource: resource, action: action, audience: origin, nonce: nonce)
        guard let signature = try await identity.sign(data: challenge) else { throw C.Failure.denied }
        let proof = C.Proof(evidenceReference: reference, linkID: linkID, challenge: challenge, signature: signature)
        try C.verify(proof, identity: identity, origin: origin, action: action, resource: resource, now: Date())
        return proof
    }

    private static func discover(_ proof: C.Proof, origin: String) async throws -> C.Descriptor {
        guard let url = URL(string: origin + C.discoveryPath) else { throw C.Failure.malformed }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false; configuration.httpCookieStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 10; configuration.timeoutIntervalForResource = 15
        let session = URLSession(configuration: configuration, delegate: PersonReadNoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try C.encode(proof)
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.url == url,
              http.statusCode == 200, http.mimeType == "application/json",
              http.expectedContentLength <= C.maximumDescriptorBytes else { throw C.Failure.unavailable }
        var bytes = Data()
        for try await byte in stream {
            guard bytes.count < C.maximumDescriptorBytes else { throw C.Failure.malformed }
            bytes.append(byte)
        }
        let descriptor = try JSONDecoder().decode(C.Descriptor.self, from: bytes)
        guard try C.encode(descriptor) == bytes else { throw C.Failure.malformed }
        return descriptor
    }
}

private nonisolated final class PersonReadNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
