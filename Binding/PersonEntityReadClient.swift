// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import CellApple
import CryptoKit
import Foundation

/// Explicit one-direction reads of a previously completed person ceremony.
/// No key provisioning, registry mutation, data cache or automatic reconnect.
actor PersonEntityReadClient {
    private typealias C = BindingPersonEntityReadRouteContract
    typealias ExistingIdentityResolver = @Sendable (String) async -> Identity?
    typealias TransportFactory = @Sendable (URL, Identity) async throws -> BridgeTransportProtocol
    private let makeTransport: TransportFactory
    private let resolveIdentity: ExistingIdentityResolver
    private var bridge: BridgeBase?
    private var transport: BridgeChannelTransport?
    private var linked: Identity?
    private var descriptor: C.Descriptor?
    private var expiresAt: Date?
    private var connectionAttempt: UUID?
    private var pendingTransport: BridgeChannelTransport?
    private var queryAttempt: UUID?

    init(resolveIdentity: @escaping ExistingIdentityResolver = { uuid in
        await BindingStartupIdentityVault.shared.identity(forUUID: uuid)
    }, makeTransport: @escaping TransportFactory = { _, _ in AppleBridgeTransport() }) {
        self.resolveIdentity = resolveIdentity
        self.makeTransport = makeTransport
    }

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
        var opened: (bridge: BridgeBase, gate: BridgeChannelTransport)?
        do {
            let bootstrap = try await openSharedBridge(identity: identity, origin: entry.origin, scopes: nil, attempt: attempt)
            opened = bootstrap
            let result = try await withBridgeCancellation(bootstrap.bridge, gate: bootstrap.gate, identity: identity) {
                try await bootstrap.bridge.set(keypath: C.scopeKey,
                    value: C.scopeRequest(reference: reference, linkID: recorded.linkID), requester: identity)
            }
            try Task.checkCancellation()
            guard connectionAttempt == attempt, bootstrap.bridge.identityDomain == C.domain else { throw C.Failure.denied }
            let descriptor = try C.decodeDescriptor(result, reference: reference, linkID: recorded.linkID,
                identity: identity, origin: entry.origin, gatewayUUID: bootstrap.bridge.uuid,
                approvedDomains: recorded.approvedDomains, now: Date())
            bootstrap.bridge.close(requester: identity)
            await bootstrap.gate.close()
            opened = nil
            guard connectionAttempt == attempt else { throw CancellationError() }
            let scopes = descriptor.scopes.map { BridgeIdentityProofScope(domain: $0.domain, resource: $0.cellUUID) }
            let query = try await openSharedBridge(identity: identity, origin: entry.origin, scopes: scopes, attempt: attempt)
            opened = query
            guard connectionAttempt == attempt, Date().timeIntervalSince1970 < descriptor.expiresAt,
                  query.bridge.uuid == descriptor.scopes.first(where: { $0.role == .gateway })?.cellUUID,
                  query.bridge.identityDomain == C.domain else { throw C.Failure.denied }
            self.bridge = query.bridge; self.transport = query.gate; linked = identity
            self.descriptor = descriptor
            expiresAt = Date().addingTimeInterval(C.connectionLifetime)
            opened = nil
        } catch {
            opened?.bridge.close(requester: identity)
            await opened?.gate.close()
            throw error
        }
    }

    private func openSharedBridge(identity: Identity, origin: String, scopes: [BridgeIdentityProofScope]?,
                                  attempt: UUID) async throws -> (bridge: BridgeBase, gate: BridgeChannelTransport) {
        try Task.checkCancellation()
        guard connectionAttempt == attempt else { throw CancellationError() }
        let endpoint = try C.endpoint(origin: origin)
        let gate = try await BridgeChannelTransport(underlying: makeTransport(endpoint, identity),
            endpoint: .init(url: endpoint, domain: "bridge"))
        let bridge = try await BridgeBase(.init(owner: identity, transport: gate, connection: .outbound,
            identityProofScopes: scopes))
        do {
            guard connectionAttempt == attempt else { throw CancellationError() }
            pendingTransport = gate
            try await withBridgeCancellation(bridge, gate: gate, identity: identity) {
                try await bridge.setTransport(gate, connection: .outbound)
                try await gate.setup(endpoint, identity: identity)
                try Task.checkCancellation()
                try await bridge.retrieveProxyRepresentation(for: identity)
            }
            try Task.checkCancellation()
            guard connectionAttempt == attempt else { throw CancellationError() }
            return (bridge, gate)
        } catch {
            bridge.close(requester: identity); await gate.close(); throw error
        }
    }

    func read(keypaths: [String]) async throws -> PersonEntityReadResult {
        try Task.checkCancellation()
        // Keep this explicitly selected UI read bounded to one operation.
        guard queryAttempt == nil else { throw C.Failure.capacity }
        guard let bridge, let transport, let linked, let descriptor, let expiresAt, Date() < expiresAt,
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
        let result: ValueType
        do {
            guard let value = try await withBridgeCancellation(bridge, gate: transport, identity: linked, operation: {
                try await bridge.set(keypath: "entityData.query", value: payload, requester: linked)
            }) else { throw C.Failure.unavailable }
            result = value
        } catch {
            if Task.isCancelled, self.bridge === bridge { await close() }
            throw error
        }
        try Task.checkCancellation()
        guard queryAttempt == attempt, self.bridge === bridge, Date() < expiresAt else { throw C.Failure.unavailable }
        guard let anchor = descriptor.scopes.first(where: { $0.role == .anchor }) else { throw C.Failure.malformed }
        return try PersonEntityReadResult.decode(result, keypaths: keypaths,
            origin: descriptor.origin, anchorUUID: anchor.cellUUID)
    }

    private func withBridgeCancellation<T>(_ bridge: BridgeBase, gate: BridgeChannelTransport,
                                           identity: Identity, operation: () async throws -> T) async throws -> T {
        try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                let result = try await operation()
                try Task.checkCancellation()
                return result
            } catch {
                if Task.isCancelled { throw CancellationError() }
                throw error
            }
        } onCancel: {
            // Close the exact captured attempt synchronously: retire pending
            // replies and origin-signing permits even if its peer is suspended.
            bridge.close(requester: identity)
            Task { await gate.close() }
        }
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

}
