//
//  IdentityLinkFlow.swift
//  Binding
//
//  purpose://candidate.entity-link.binding-uses-link (WP6, PDD_entitetslenking 2026-09-04).
//  Telefonen blir samme entitet som personen allerede er på et scaffold:
//  skann/deep-link → signer forespørsel med egen nøkkel → send til møteplassen →
//  vis firordskoden → hent godkjenningspakken → verifiser lokalt → fullfør på scaffoldet
//  og i egen EntityAnchor → husk konvolutten (DeviceIngress trenger den).
//  Wire-kontrakt: CellScaffold/Deliverables/PDD_entitetslenking-paa-tvers-av-scaffolds_2026-09-04/contract/identity-link-rendezvous.v1.md
//

import Foundation
import SwiftUI
import Combine
import CellNearby
import CellBase
#if canImport(VisionKit) && os(iOS)
import VisionKit
import Vision
import AVFoundation
#endif

// MARK: - Billett (speil av scaffoldets IdentityLinkTicket)

nonisolated struct IdentityLinkTicket: Codable, Equatable, Sendable {
    static let currentSchema = "haven.identity-link.ticket.v1"

    var schema: String
    var ticketID: String
    var audience: String
    var origin: String
    var entityBinding: EntityBindingDescriptor
    var rendezvousURL: String
    var nonce: Data
    var expiresAt: String
    var presentationChallenge: Data
    var presentationDomain: String
    var ownerDisplayName: String
    var approverLabel: String

    enum DecodeError: Error, Equatable { case notATicket, wrongSchema, untrustedOrigin, expired }

    static func decode(deepLink: String, now: Date = Date()) throws -> IdentityLinkTicket {
        guard deepLink.utf8.count <= 32 * 1024,
              let components = URLComponents(string: deepLink.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.user == nil, components.password == nil, components.fragment == nil, components.path.isEmpty,
              components.queryItems?.count == 1,
              components.scheme?.lowercased() == "haven",
              components.host?.lowercased() == "identity-link",
              let raw = components.queryItems?.first(where: { $0.name == "t" })?.value,
              let data = IdentityLinkWire.data(base64URL: raw) else {
            throw DecodeError.notATicket
        }
        let ticket = try JSONDecoder().decode(IdentityLinkTicket.self, from: data)
        guard ticket.schema == currentSchema else { throw DecodeError.wrongSchema }
        guard IdentityLinkTrust.isTrustedOrigin(ticket.origin),
              IdentityLinkTrust.isTrustedAudience(ticket.audience, origin: ticket.origin),
              Self.validRendezvous(ticket.rendezvousURL, origin: ticket.origin),
              ticket.presentationDomain == ticket.origin else {
            throw DecodeError.untrustedOrigin
        }
        guard let expiry = ISO8601DateFormatter().date(from: ticket.expiresAt), expiry > now else {
            throw DecodeError.expired
        }
        return ticket
    }

    static func validRendezvous(_ value: String, origin: String) -> Bool {
        IdentityLinkTrust.isTrustedEndpoint(value, origin: origin) && URLComponents(string: value)?.path == "/link/api"
    }

    var expiryDate: Date? { ISO8601DateFormatter().date(from: expiresAt) }
}

nonisolated enum IdentityLinkTrust {
    /// Hvilke scaffolds telefonen er villig til å bli samme entitet på. Utvides når nye verter finnes;
    /// en angriperstyrt origin skal aldri få en signert forespørsel.
    static let trustedHosts: Set<String> = ["staging.haven.digipomps.org", "haven.digipomps.org"]
    static let developmentHosts: Set<String> = ["localhost", "127.0.0.1"]

    static func isTrustedOrigin(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              components.query == nil, components.fragment == nil,
              components.user == nil, components.password == nil,
              components.path.isEmpty,
              let host = components.host?.lowercased() else { return false }
        if components.scheme == "https", components.port == nil, value == "https://" + host, trustedHosts.contains(host) { return true }
        #if DEBUG
        if components.scheme == "http", developmentHosts.contains(host) { return true }
        #endif
        return false
    }

    static var trustedOrigins: Set<String> { Set(trustedHosts.map { "https://" + $0 }) }

    static func isTrustedEndpoint(_ value: String, origin: String) -> Bool {
        guard isTrustedOrigin(origin), let base = URLComponents(string: origin),
              let target = URLComponents(string: value), target.user == nil, target.password == nil,
              target.fragment == nil, target.scheme == base.scheme, target.host == base.host,
              target.port == base.port, target.query == nil else { return false }
        return target.path.hasPrefix("/link/api/") || target.path == "/link/api"
    }

    static func isTrustedAudience(_ audience: String, origin: String) -> Bool {
        let normalized = audience.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let host = URLComponents(string: origin)?.host?.lowercased() else { return false }
        return normalized == host
    }
}

nonisolated enum IdentityLinkWire {
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func data(base64URL: String) -> Data? {
        var base64 = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

// MARK: - Pakker fra møteplassen

nonisolated struct IdentityLinkSubmitResponse: Codable, Sendable {
    var requestHash: String
    var sas: [String]
    var completionURL: String
}

nonisolated struct IdentityLinkCompletionPackage: Codable, @unchecked Sendable {
    var requestHash: String
    var approval: IdentityEnrollmentApproval
    var sameEntityCredential: VCClaim
    var issuerIdentity: IdentityPublicKeyDescriptor
    var presentationChallenge: Data
    var presentationDomain: String
    var audience: String
    var origin: String
    var completeURL: String
}

// MARK: - Transport (bare signerte objekter krysser nettet)

nonisolated protocol IdentityLinkTransport: Sendable {
    func submitRequest(ticketID: String, request: IdentityEnrollmentRequest, to rendezvousURL: String) async throws -> IdentityLinkSubmitResponse
    /// `nil` = 202, ikke klar ennå.
    func fetchCompletion(url: String) async throws -> IdentityLinkCompletionPackage?
    func complete(envelope: IdentityLinkCompletionEnvelope, url: String) async throws -> ValueType
}

nonisolated enum IdentityLinkTransportError: Error, Equatable {
    case badURL(String)
    case http(Int, String)
    case decode(String)
}

nonisolated struct URLSessionIdentityLinkTransport: IdentityLinkTransport {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.waitsForConnectivity = true
            configuration.httpShouldSetCookies = false
            self.session = URLSession(configuration: configuration, delegate: IdentityLinkNoRedirectDelegate(), delegateQueue: nil)
        }
    }

    func submitRequest(ticketID: String, request: IdentityEnrollmentRequest, to rendezvousURL: String) async throws -> IdentityLinkSubmitResponse {
        struct Body: Encodable { let ticketID: String; let request: IdentityEnrollmentRequest }
        let (data, status) = try await post(url: rendezvousURL + "/request", body: Body(ticketID: ticketID, request: request))
        guard status == 200 else { throw IdentityLinkTransportError.http(status, String(decoding: data, as: UTF8.self)) }
        return try decode(IdentityLinkSubmitResponse.self, from: data)
    }

    func fetchCompletion(url: String) async throws -> IdentityLinkCompletionPackage? {
        guard let target = URL(string: url) else { throw IdentityLinkTransportError.badURL(url) }
        var request = URLRequest(url: target)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard response.url == target, data.count <= 256 * 1024 else { throw IdentityLinkTransportError.decode("response boundary") }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 202 { return nil }
        guard status == 200 else { throw IdentityLinkTransportError.http(status, String(decoding: data, as: UTF8.self)) }
        return try decode(IdentityLinkCompletionPackage.self, from: data)
    }

    func complete(envelope: IdentityLinkCompletionEnvelope, url: String) async throws -> ValueType {
        let (data, status) = try await post(url: url, body: envelope)
        guard status == 200 else { throw IdentityLinkTransportError.http(status, String(decoding: data, as: UTF8.self)) }
        return try decode(ValueType.self, from: data)
    }

    private func post<T: Encodable>(url: String, body: T) async throws -> (Data, Int) {
        guard let target = URL(string: url) else { throw IdentityLinkTransportError.badURL(url) }
        var request = URLRequest(url: target)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try IdentityLinkWire.encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        guard response.url == target, data.count <= 256 * 1024 else { throw IdentityLinkTransportError.decode("response boundary") }
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw IdentityLinkTransportError.decode(String(describing: error)) }
    }
}

// MARK: - Koordinator

nonisolated enum IdentityLinkFlowState: Equatable, @unchecked Sendable {
    case idle
    case scanning
    case reviewing(ticket: IdentityLinkTicket)
    case preparing(ticket: IdentityLinkTicket)
    case awaitingApproval(ticket: IdentityLinkTicket, sas: [String], requestHash: String)
    case completing(ticket: IdentityLinkTicket)
    case recovery(ticket: IdentityLinkTicket, message: String, canRetry: Bool)
    case done(record: IdentityLinkRecord, ownerDisplayName: String, origin: String, localConfirmed: Bool)
    case failed(message: String)
}

nonisolated enum IdentityLinkFlowError: Error, Equatable {
    case noLocalIdentity
    case presentationFixtureOnly
    case noSigningKey
    case signingFailed
    case ticketExpired
    case packageMismatch(String)
    case localVerificationFailed(String)
}

/// Kjører hele telefonsiden. Én aktiv billett om gangen.
actor IdentityLinkFlowCoordinator {
    static let shared: IdentityLinkFlowCoordinator = {
        #if DEBUG && os(macOS)
        if IdentityLinkUIFixture.enabled {
            return IdentityLinkFlowCoordinator(outbox: IdentityLinkUIFixtureOutbox(), identityProvider: { nil },
                completionSaver: { _, _, _, _ in throw IdentityLinkOutboxError.invalidFile }, localRuntimeAvailable: { false })
        }
        #endif
        return IdentityLinkFlowCoordinator()
    }()

    private let transport: IdentityLinkTransport
    private let outbox: any IdentityLinkOutbox
    private var completionInFlight = false
    private let identityProvider: @Sendable () async -> Identity?
    private(set) var state: IdentityLinkFlowState = .idle
    private var pollTask: Task<Void, Never>?
    private var generation = UUID()
    private var stateObservers: [UUID: @Sendable (IdentityLinkFlowState) -> Void] = [:]

    private let completionSaver: @Sendable (IdentityLinkCompletionEnvelope, IdentityLinkRecord, String, String?) async throws -> Void
    private let localRuntimeAvailable: @Sendable () async -> Bool

    init(
        transport: IdentityLinkTransport = URLSessionIdentityLinkTransport(),
        outbox: any IdentityLinkOutbox = EncryptedIdentityLinkOutbox.shared,
        identityProvider: @escaping @Sendable () async -> Identity? = {
            await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)
        },
        completionSaver: @escaping @Sendable (IdentityLinkCompletionEnvelope, IdentityLinkRecord, String, String?) async throws -> Void = { envelope, record, origin, reference in
            try IdentityLinkCompletionStore.save(envelope: envelope, record: record, origin: origin, personEvidenceReference: reference)
        },
        localRuntimeAvailable: @escaping @Sendable () async -> Bool = {
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        }
    ) {
        self.transport = transport
        self.outbox = outbox
        self.identityProvider = identityProvider
        self.localRuntimeAvailable = localRuntimeAvailable
        self.completionSaver = completionSaver
    }

    func observe(_ observer: @escaping @Sendable (IdentityLinkFlowState) -> Void) -> UUID {
        let id = UUID()
        stateObservers[id] = observer
        observer(state)
        return id
    }

    func stopObserving(_ id: UUID) { stateObservers[id] = nil }

    private func set(_ newState: IdentityLinkFlowState) {
        state = newState
        for observer in stateObservers.values { observer(newState) }
    }

    func reset() {
        generation = UUID()
        pollTask?.cancel(); pollTask = nil
        set(.idle)
    }

    func beginScanning() async {
        reset()
        if await showPendingCompletion(token: generation) { return }
        set(.scanning)
    }

    /// Opening the flow discovers a saved package without contacting a server.
    private func showPendingCompletion(token: UUID) async -> Bool {
        do {
            let pending = try await outbox.load()
            try requireCurrent(token)
            if let pending {
                set(.recovery(ticket: pending.ticket,
                    message: "En godkjent pakke er lagret kryptert her. Serverens siste resultat er ikke bekreftet. Gjenoppta for å kontrollere status og fullføre.", canRetry: true))
                return true
            }
            return false
        } catch is CancellationError {
            return true
        } catch {
            guard generation == token, !Task.isCancelled else { return true }
            set(.failed(message: "Den ventende koblingen kunne ikke leses sikkert. Lås opp enheten og prøv igjen. Ingen ny forespørsel er sendt."))
            return true
        }
    }

    func resumePendingCompletion() async {
        guard !completionInFlight else { return }
        reset()
        let token = generation
        do {
            let pending = try await outbox.load()
            try requireCurrent(token)
            guard let pending else { set(.scanning); return }
            guard let identity = await identityProvider() else { throw IdentityLinkFlowError.noLocalIdentity }
            try requireCurrent(token)
            try await completePending(pending, identity: identity, token: token)
        } catch is CancellationError { return }
        catch {
            guard generation == token else { return }
            if !(await showPendingCompletion(token: token)) { set(.failed(message: Self.message(for: error))) }
        }
    }

    /// Discards only the local retry. It cannot revoke a remotely completed link.
    func discardPendingCompletion() async {
        guard !completionInFlight else { return }
        reset()
        let token = generation
        do {
            let pending = try await outbox.load()
            try requireCurrent(token)
            if let pending {
                try await outbox.remove(requestID: pending.requestID)
                try requireCurrent(token)
            }
            set(.scanning)
        } catch is CancellationError { return }
        catch {
            guard generation == token, !Task.isCancelled else { return }
            set(.failed(message: "Den ventende koblingen kunne ikke fjernes. Ingen ny forespørsel er sendt."))
        }
    }

    /// A nearby result or QR is an invitation to review, never permission to sign.
    func review(deepLink: String) async {
        guard !completionInFlight else { return }
        reset()
        if await showPendingCompletion(token: generation) { return }
        do { set(.reviewing(ticket: try IdentityLinkTicket.decode(deepLink: deepLink))) }
        catch { set(.failed(message: "Invitasjonen er ugyldig, utløpt eller fra et ukjent sted.")) }
    }

    func confirmReviewedEntity() async {
        guard case let .reviewing(ticket) = state,
              let data = try? IdentityLinkWire.encoder.encode(ticket) else { return }
        await start(deepLink: "haven://identity-link?t=" + IdentityLinkWire.base64URL(data))
    }

    private func requireCurrent(_ token: UUID) throws {
        guard generation == token, !Task.isCancelled else { throw CancellationError() }
    }

    /// Steg 1–3: signer forespørselen, send den, vis koden. Kalles ved deep-link eller skann.
    func start(deepLink: String, now: Date = Date()) async {
        guard !completionInFlight else { return }
        if IdentityLinkUIFixture.enabled {
            set(.failed(message: Self.message(for: IdentityLinkFlowError.presentationFixtureOnly)))
            return
        }
        reset()
        let token = generation
        if await showPendingCompletion(token: token) { return }
        let ticket: IdentityLinkTicket
        do {
            ticket = try IdentityLinkTicket.decode(deepLink: deepLink, now: now)
        } catch IdentityLinkTicket.DecodeError.expired {
            set(.failed(message: "Koden er utløpt. Lag en ny på skjermen der entiteten din bor."))
            return
        } catch IdentityLinkTicket.DecodeError.untrustedOrigin {
            set(.failed(message: "Koden peker på et sted HAVEN ikke stoler på. Ingenting ble signert."))
            return
        } catch {
            set(.failed(message: "Dette er ikke en HAVEN-kode for å koble til en entitet."))
            return
        }
        set(.preparing(ticket: ticket))
        do {
            guard let identity = await identityProvider() else { throw IdentityLinkFlowError.noLocalIdentity }
            try requireCurrent(token)
            let request = try await Self.makeSignedRequest(ticket: ticket, identity: identity, now: now)
            try requireCurrent(token)
            let response = try await transport.submitRequest(ticketID: ticket.ticketID, request: request, to: ticket.rendezvousURL)
            try requireCurrent(token)
            guard IdentityLinkTrust.isTrustedEndpoint(response.completionURL, origin: ticket.origin),
                  URLComponents(string: response.completionURL)?.path == "/link/api/completion/" + response.requestHash else {
                throw IdentityLinkFlowError.packageMismatch("svaret peker på en annen møteplass")
            }
            // Regn koden ut selv — den fra serveren er bare bekvemmelighet.
            let localHash = try IdentityLinkProtocolService.requestHash(for: request)
            let localWords = IdentityLinkSAS.words(requestHash: localHash)
            guard IdentityLinkWire.base64URL(localHash) == response.requestHash, localWords == response.sas else {
                throw IdentityLinkFlowError.packageMismatch("serverens kode stemmer ikke med forespørselen telefonen signerte")
            }
            set(.awaitingApproval(ticket: ticket, sas: localWords, requestHash: response.requestHash))
            startPolling(ticket: ticket, request: request, identity: identity, completionURL: response.completionURL)
        } catch is CancellationError {
            return
        } catch let error as IdentityLinkFlowError {
            guard generation == token else { return }
            set(.failed(message: Self.message(for: error)))
        } catch let error as IdentityLinkTransportError {
            guard generation == token else { return }
            set(.failed(message: Self.message(for: error)))
        } catch {
            guard generation == token else { return }
            set(.failed(message: "Kunne ikke sende forespørselen: \(error)"))
        }
    }

    /// Steg 4–6: hent pakken, verifiser lokalt, fullfør hos scaffoldet og i egen EntityAnchor.
    private func startPolling(ticket: IdentityLinkTicket, request: IdentityEnrollmentRequest, identity: Identity, completionURL: String) {
        let token = generation
        pollTask = Task { [transport] in
            let deadline = ticket.expiryDate ?? Date().addingTimeInterval(600)
            while !Task.isCancelled, Date() < deadline {
                do {
                    if let package = try await transport.fetchCompletion(url: completionURL) {
                        try self.requireCurrent(token)
                        await self.finish(package: package, ticket: ticket, request: request, identity: identity, token: token)
                        return
                    }
                } catch {
                    guard self.generation == token, !Task.isCancelled else { return }
                    await self.set(.failed(message: Self.message(for: error)))
                    return
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            if !Task.isCancelled {
                await self.set(.failed(message: "Ingen godkjenning kom innen tiden. Lag en ny kode og prøv igjen."))
            }
        }
    }

    private func finish(package: IdentityLinkCompletionPackage, ticket: IdentityLinkTicket, request: IdentityEnrollmentRequest, identity: Identity, token: UUID) async {
        set(.completing(ticket: ticket))
        do {
            let requestHash = try IdentityLinkProtocolService.requestHash(for: request)
            guard package.requestHash == IdentityLinkWire.base64URL(requestHash),
                  package.approval.requestHash == requestHash,
                  package.presentationChallenge == ticket.presentationChallenge,
                  package.presentationDomain == ticket.presentationDomain,
                  IdentityLinkTrust.isTrustedEndpoint(package.completeURL, origin: ticket.origin),
                  URLComponents(string: package.completeURL)?.path == "/link/api/complete",
                  package.audience == ticket.audience, package.origin == ticket.origin else {
                throw IdentityLinkFlowError.packageMismatch("pakken gjelder ikke denne forespørselen")
            }
            let presentation = try await IdentityLinkProtocolService.makeVerifierBoundPresentation(
                credential: package.sameEntityCredential,
                holderIdentity: identity,
                challenge: package.presentationChallenge,
                domain: package.presentationDomain
            )
            try requireCurrent(token)
            let envelope = IdentityLinkCompletionEnvelope(
                request: request,
                approval: package.approval,
                sameEntityCredential: package.sameEntityCredential,
                presentation: presentation,
                issuerIdentity: package.issuerIdentity,
                expectedAudience: package.audience,
                expectedOrigin: package.origin,
                expectedPresentationChallenge: package.presentationChallenge,
                expectedPresentationDomain: package.presentationDomain
            )
            // Avvis lokalt før noe sendes: signaturer, binding, utløp, utstedertype.
            let local: IdentityLinkCompletionResult
            do {
                local = try await IdentityLinkProtocolService.verifyCompletion(envelope)
            } catch {
                throw IdentityLinkFlowError.localVerificationFailed(String(describing: error))
            }
            try requireCurrent(token)
            // Persist the exact already verified envelope BEFORE the first remote
            // mutation. On restart it is retried unchanged, without a new signature.
            let pending = IdentityLinkPendingCompletion(ticket: ticket, envelope: envelope,
                verifiedAt: Date(), completeURL: package.completeURL)
            _ = local
            try await outbox.save(pending)
            try requireCurrent(token)
            try await completePending(pending, identity: identity, token: token)
        } catch is CancellationError {
            return
        } catch let error as IdentityLinkFlowError {
            guard generation == token else { return }
            set(.failed(message: Self.message(for: error)))
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            set(.failed(message: Self.message(for: error)))
        }
    }

    private func completePending(_ pending: IdentityLinkPendingCompletion, identity: Identity, token: UUID) async throws {
        guard !completionInFlight else { return }
        completionInFlight = true
        defer { completionInFlight = false }
        set(.completing(ticket: pending.ticket))
        do {
            let envelope = pending.envelope
            guard IdentityLinkTrust.isTrustedOrigin(pending.ticket.origin),
                  IdentityLinkTrust.isTrustedEndpoint(pending.completeURL, origin: pending.ticket.origin),
                  URLComponents(string: pending.completeURL)?.path == "/link/api/complete",
                  envelope.expectedOrigin == pending.ticket.origin,
                  envelope.expectedAudience == pending.ticket.audience,
                  envelope.expectedPresentationChallenge == pending.ticket.presentationChallenge,
                  envelope.expectedPresentationDomain == pending.ticket.origin,
                  envelope.request.newIdentity.uuid == identity.uuid,
                  envelope.request.newIdentity.publicKey == identity.publicSecureKey?.compressedKey,
                  pending.verifiedAt <= Date().addingTimeInterval(5) else {
                throw IdentityLinkFlowError.packageMismatch("den lagrede pakken passer ikke til denne entiteten og stedet")
            }
            // Historical local validation only. The server independently checks
            // current revocation and exact durable ceremony evidence on retry.
            let verified = try await IdentityLinkProtocolService.verifyCompletion(envelope, now: pending.verifiedAt)
            try requireCurrent(token)
            let remote = try await transport.complete(envelope: envelope, url: pending.completeURL)
            guard Self.status(from: remote) == "completed" else {
                throw IdentityLinkFlowError.packageMismatch("stedet bekreftet ikke koblingen")
            }
            let reference: String?
            if case let .object(object) = remote, case let .string(value)? = object["evidenceReference"] {
                guard value.count == 64, value.allSatisfy({ "0123456789abcdef".contains($0) }),
                      case .string(verified.record.linkID)? = object["linkID"] else {
                    throw IdentityLinkFlowError.packageMismatch("kvitteringen gjelder ikke denne koblingen")
                }
                reference = value
            } else { reference = nil }
            try await completionSaver(envelope, verified.record, pending.ticket.origin, reference)
            // Keep exact retry until the completion receipt is durably saved.
            try await outbox.remove(requestID: pending.requestID)
            var localConfirmed = false
            if generation == token, !Task.isCancelled, await localRuntimeAvailable() {
                let outcome = try? await identity.set(keypath: "identity.identityLinks.completeEnrollment",
                    value: try IdentityLinkProtocolService.value(from: envelope), requester: identity)
                if let outcome { localConfirmed = Self.status(from: outcome) == "completed" }
            }
            try requireCurrent(token)
            set(.done(record: verified.record, ownerDisplayName: pending.ticket.ownerDisplayName,
                origin: pending.ticket.origin, localConfirmed: localConfirmed))
        } catch is CancellationError { throw CancellationError() }
        catch {
            guard generation == token, !Task.isCancelled else { return }
            let terminal: Bool
            if case let IdentityLinkTransportError.http(status, _) = error {
                terminal = [400, 401, 403, 404, 409, 410, 422].contains(status)
            } else { terminal = error is IdentityLinkFlowError }
            set(.recovery(ticket: pending.ticket,
                message: terminal
                    ? "Stedet eller den lokale kontrollen avviste pakken. Ingen lokal tilgang er aktivert. Kontroller koblingen på det andre stedet før du lager en ny invitasjon."
                    : "Resultatet er ikke bekreftet. Pakken er lagret kryptert, og kan gjenopptas uten å signere på nytt.",
                canRetry: !terminal))
        }
    }

    // MARK: Forespørselen

    static func makeSignedRequest(ticket: IdentityLinkTicket, identity: Identity, now: Date) async throws -> IdentityEnrollmentRequest {
        guard let key = identity.publicSecureKey, let publicKey = key.compressedKey, !publicKey.isEmpty else {
            throw IdentityLinkFlowError.noSigningKey
        }
        guard let expiry = ticket.expiryDate, expiry > now else { throw IdentityLinkFlowError.ticketExpired }
        let descriptor = IdentityPublicKeyDescriptor(
            uuid: identity.uuid,
            displayName: Self.deviceLabel(),
            publicKey: publicKey,
            algorithm: key.algorithm,
            curveType: key.curveType
        )
        var request = IdentityEnrollmentRequest(
            requestID: "request-\(UUID().uuidString.lowercased())",
            entityBinding: ticket.entityBinding,
            newIdentity: descriptor,
            requestedDomains: ["private", "scaffold"],
            requestedIdentityContexts: ["binding"],
            requestedScopes: [IdentityLinkScope.sameEntity],
            audience: ticket.audience,
            origin: ticket.origin,
            createdAt: ISO8601DateFormatter().string(from: now),
            expiresAt: ISO8601DateFormatter().string(from: min(expiry, now.addingTimeInterval(600))),
            nonce: ticket.nonce,
            platform: Self.platformLabel(),
            deviceLabel: Self.deviceLabel()
        )
        let payload = try request.canonicalPayloadData()
        guard let signature = try await identity.sign(data: payload) else { throw IdentityLinkFlowError.signingFailed }
        request.proof = IdentityEnrollmentRequestProof(
            byIdentityUUID: identity.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )
        return request
    }

    static func deviceLabel() -> String {
        #if os(iOS)
        return "iPhone · HAVEN-appen"
        #elseif os(macOS)
        return "Mac · HAVEN-appen"
        #else
        return "HAVEN-appen"
        #endif
    }

    static func platformLabel() -> String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #else
        return "apple"
        #endif
    }

    private static func status(from value: ValueType) -> String? {
        guard case let .object(object) = value, case let .string(status)? = object["status"] else { return nil }
        return status
    }

    static func message(for error: Error) -> String {
        switch error {
        case IdentityLinkFlowError.presentationFixtureOnly: return "Dette er HAVEN UI-test. Dette bygget kan ikke koble enheter. Åpne det vanlige HAVEN-bygget for å koble til."
        case IdentityLinkFlowError.noLocalIdentity: return "HAVEN har ingen egen identitet på denne enheten ennå."
        case IdentityLinkFlowError.noSigningKey: return "Enhetens identitet mangler signeringsnøkkel."
        case IdentityLinkFlowError.signingFailed: return "Enheten kunne ikke signere forespørselen."
        case IdentityLinkFlowError.ticketExpired: return "Koden er utløpt. Lag en ny."
        case let IdentityLinkFlowError.packageMismatch(detail): return "Avbrutt: \(detail)."
        case let IdentityLinkFlowError.localVerificationFailed(detail): return "Godkjenningen besto ikke telefonens egen kontroll (\(detail)). Ingenting ble lagret."
        case let IdentityLinkTransportError.http(status, body):
            if status == 410 { return "Koden er utløpt. Lag en ny." }
            if status == 409 { return "Koden er allerede brukt. Lag en ny." }
            if status == 422 { return "Scaffoldet avviste forespørselen: \(body)" }
            return "Scaffoldet svarte \(status)."
        case let IdentityLinkTransportError.badURL(url): return "Ugyldig adresse i koden: \(url)"
        case let IdentityLinkTransportError.decode(detail): return "Uventet svar fra scaffoldet: \(detail)"
        default: return "Noe gikk galt: \(error)"
        }
    }
}

// MARK: - Lager for konvolutten (DeviceIngress og «Mine apparater» på telefonen)

nonisolated enum IdentityLinkCompletionStore {
    struct Entry: Codable {
        var origin: String
        var record: IdentityLinkRecord
        var envelope: IdentityLinkCompletionEnvelope
        var storedAt: String
        var personEvidenceReference: String? = nil
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("HAVEN/IdentityLinks", isDirectory: true)
    }

    static func save(envelope: IdentityLinkCompletionEnvelope, record: IdentityLinkRecord, origin: String, personEvidenceReference: String? = nil) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let entry = Entry(origin: origin, record: record, envelope: envelope, storedAt: ISO8601DateFormatter().string(from: Date()), personEvidenceReference: personEvidenceReference)
        let data = try IdentityLinkWire.encoder.encode(entry)
        let url = directory.appendingPathComponent(safeName(record.linkID) + ".json")
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func entries() -> [Entry] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.compactMap { url in
            guard url.pathExtension == "json", let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Entry.self, from: data)
        }.sorted { $0.storedAt < $1.storedAt }
    }

    static func entry(forOrigin origin: String) -> Entry? {
        entries().last { $0.origin == origin && $0.record.status == .active }
    }

    private static func safeName(_ value: String) -> String {
        String(value.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    }
}

// MARK: - Presentasjon

@MainActor
final class IdentityLinkFlowPresenter: ObservableObject {
    static let shared = IdentityLinkFlowPresenter()

    @Published var isPresented = false
    @Published var state: IdentityLinkFlowState = .idle
    private var observerID: UUID?

    private init() {
        Task {
            observerID = await IdentityLinkFlowCoordinator.shared.observe { [weak self] newState in
                Task { @MainActor in self?.state = newState }
            }
        }
    }

    /// Returnerer true hvis URL-en var en lenkebillett og flyten tok den.
    @discardableResult
    func handle(url: URL) -> Bool {
        let deepLink = url.absoluteString
        if url.scheme == "haven", url.host == "nearby-link" {
            isPresented = true
            state = .scanning
            Task { await IdentityLinkFlowCoordinator.shared.beginScanning() }
            IdentityLinkNearbyModel.shared.reviewPublication(url)
            return true
        }
        if url.scheme == "haven", url.host == "link-devices", url.query == nil {
            presentScanner()
            return true
        }
        guard (try? IdentityLinkTicket.decode(deepLink: deepLink)) != nil || Self.looksLikeTicket(deepLink) else { return false }
        isPresented = true
        IdentityLinkNearbyModel.shared.stop()
        Task { await IdentityLinkFlowCoordinator.shared.review(deepLink: deepLink) }
        return true
    }

    func presentScanner() {
        isPresented = true
        Task { await IdentityLinkFlowCoordinator.shared.beginScanning() }
    }

    func dismiss() {
        isPresented = false
        IdentityLinkNearbyModel.shared.stop()
        Task { await IdentityLinkFlowCoordinator.shared.reset() }
    }

    static func looksLikeTicket(_ value: String) -> Bool {
        guard let components = URLComponents(string: value) else { return false }
        return components.scheme?.lowercased() == "haven"
            && components.host?.lowercased() == "identity-link"
            && components.queryItems?.contains(where: { $0.name == "t" }) == true
    }
}

struct IdentityLinkFlowView: View {
    @ObservedObject private var presenter = IdentityLinkFlowPresenter.shared
    @State private var pasted = ""
    @State private var cameraRequested = false
    @State private var cameraDenied = false
    @ObservedObject private var nearby = IdentityLinkNearbyModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if IdentityLinkUIFixture.enabled {
                        Text("HAVEN UI-test – kan ikke koble enheter")
                            .font(.headline)
                    }
                    if nearby.publication != nil || nearby.state == .advertising {
                        IdentityLinkNearbyPanel(model: nearby)
                    } else {
                        if case .scanning = presenter.state { IdentityLinkNearbyPanel(model: nearby) }
                        if case .idle = presenter.state { IdentityLinkNearbyPanel(model: nearby) }
                        content
                    }
                }
            }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { nearby.stop(); cameraRequested = false }
                }
                .onChange(of: nearby.state) { _, state in
                    if state != .stopped { cameraRequested = false }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(red: 0.953, green: 0.965, blue: 0.945).ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelTitle) { presenter.dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 520, minHeight: 620, idealHeight: 720)
        #endif
    }

    private var cancelTitle: String {
        if case .done = presenter.state { return "Lukk" }
        return "Avbryt"
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.state {
        case .idle, .scanning:
            scanning
        case let .reviewing(ticket):
            VStack(alignment: .leading, spacing: 16) {
                header("Utvid min entitet hit", "Koble entiteten din her til den du allerede bruker et annet sted.")
                card {
                    keyValue("Her", "Min entitet i denne HAVEN-appen")
                    keyValue("Der", ticket.ownerDisplayName)
                    keyValue("Sted", URLComponents(string: ticket.origin)?.host ?? ticket.origin)
                }
                Text("Når du har bevist kontroll over begge, kan de handle som samme entitet. Data flyttes ikke av denne koblingen.")
                Text("Kontroller navn og sted. Du bekrefter også kontrollordene og godkjenner der den andre entiteten er.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Dette er mine entiteter — fortsett") {
                    Task { await IdentityLinkFlowCoordinator.shared.confirmReviewedEntity() }
                }.buttonStyle(.borderedProminent)
                Spacer()
            }
        case let .preparing(ticket):
            waiting(title: "Forbereder …", subtitle: "Telefonen signerer forespørselen til \(ticket.ownerDisplayName) sin entitet med sin egen nøkkel.")
        case let .awaitingApproval(ticket, sas, _):
            code(ticket: ticket, sas: sas)
        case let .completing(ticket):
            waiting(title: "Fullfører …", subtitle: "Godkjenningen fra \(ticket.approverLabel) kontrolleres på telefonen før den lagres.")
        case let .recovery(ticket, message, canRetry):
            VStack(alignment: .leading, spacing: 16) {
                header("Kobling venter på bekreftelse", message)
                card {
                    keyValue("Entitet", ticket.ownerDisplayName)
                    keyValue("Sted", URLComponents(string: ticket.origin)?.host ?? ticket.origin)
                }
                if canRetry {
                    Button("Gjenoppta godkjent kobling") {
                        Task { await IdentityLinkFlowCoordinator.shared.resumePendingCompletion() }
                    }.buttonStyle(.borderedProminent)
                }
                Text("Å forkaste pakken her fjerner ikke en kobling som allerede ble godkjent der. Fjern den fra entitetens koblingsside om du vil trekke tilgangen tilbake.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Forkast lokal ventende pakke") {
                    Task { await IdentityLinkFlowCoordinator.shared.discardPendingCompletion() }
                }.buttonStyle(.bordered)
            }
        case let .done(record, ownerDisplayName, origin, localConfirmed):
            done(record: record, ownerDisplayName: ownerDisplayName, origin: origin, localConfirmed: localConfirmed)
        case let .failed(message):
            failed(message)
        }
    }

    // L2a — images/app-skann-v1.png
    private var scanning: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Utvid min entitet", "Finn eller skann invitasjonen fra en av dine entiteter.")
            #if canImport(VisionKit) && os(iOS)
            if cameraRequested, IdentityLinkScannerView.isAvailable {
                IdentityLinkScannerView { payload in
                    nearby.stop()
                    Task { await IdentityLinkFlowCoordinator.shared.review(deepLink: payload) }
                }
                .frame(maxWidth: .infinity, minHeight: 380)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Button("Skann QR-kode") {
                    nearby.stop()
                    Task {
                        let allowed = await AVCaptureDevice.requestAccess(for: .video)
                        cameraRequested = allowed
                        cameraDenied = !allowed || !IdentityLinkScannerView.isAvailable
                    }
                }.buttonStyle(.borderedProminent)
                if cameraDenied { unavailableScanner }
            }
            #else
            Text("Bruk nærhetssøk, eller lim inn invitasjonen fra den andre entiteten din.")
                .font(.footnote).foregroundStyle(.secondary)
            #endif
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                TextField("haven://identity-link?t=…", text: $pasted)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Button("Bruk innlimt lenke") {
                    nearby.stop()
                    Task { await IdentityLinkFlowCoordinator.shared.review(deepLink: pasted) }
                }
                .buttonStyle(.bordered)
                .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var unavailableScanner: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(red: 0.11, green: 0.14, blue: 0.13))
            .frame(maxWidth: .infinity, minHeight: 240)
            .overlay(Text("Kamera er ikke tilgjengelig her. Skann koden med Kamera-appen, eller lim inn lenken under.")
                .foregroundStyle(.white).multilineTextAlignment(.center).padding())
    }

    // L2b — images/app-kode-v1.png
    private func code(ticket: IdentityLinkTicket, sas: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Er dette deg?", "Sjekk at ordene er de samme som på skjermen.")
            card {
                IdentityLinkWordsView(words: sas)
                    .frame(maxWidth: .infinity)
            }
            card {
                keyValue("Entitet", ticket.ownerDisplayName)
                keyValue("Sted", URLComponents(string: ticket.origin)?.host ?? ticket.origin)
                keyValue("Godkjennes fra", ticket.approverLabel)
            }
            Text("Telefonen har signert forespørselen med sin egen nøkkel. Ingen hemmelighet sendes. Godkjenn på skjermen — telefonen fullfører selv.")
                .font(.footnote).foregroundStyle(.secondary)
            ProgressView().frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }

    // L2c — images/app-ferdig-v1.png
    private func done(record: IdentityLinkRecord, ownerDisplayName: String, origin: String, localConfirmed: Bool) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            ZStack {
                Circle().fill(Color(red: 0.863, green: 0.922, blue: 0.894)).frame(width: 72, height: 72)
                Image(systemName: "checkmark").font(.system(size: 30, weight: .semibold)).foregroundStyle(Color(red: 0.141, green: 0.361, blue: 0.306))
            }
            Text(localConfirmed ? "Koblingen er godkjent" : "Godkjent — lokal aktivering gjenstår").font(.system(.title, design: .serif))
            Text(localConfirmed
                ? "Koblingen til \(ownerDisplayName) sin entitet på \(URLComponents(string: origin)?.host ?? origin) er godkjent der, og registreringen er lagret lokalt."
                : "Koblingen til \(ownerDisplayName) på \(URLComponents(string: origin)?.host ?? origin) er godkjent der og beviset er lagret her. Lokal tilgang er ikke bekreftet ennå.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            card {
                keyValue("Lenket", Self.displayDate(record.linkedAt))
                keyValue("Omfang", "samme entitet")
                keyValue("Fjern", "fra koblingssiden der du godkjente")
            }
            Spacer()
            Button("Fortsett") { presenter.dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.141, green: 0.361, blue: 0.306))
                .frame(maxWidth: .infinity)
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Ikke lenket", message)
            Button("Prøv igjen") { Task { await IdentityLinkFlowCoordinator.shared.beginScanning() } }
                .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func waiting(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title, subtitle)
            ProgressView().frame(maxWidth: .infinity)
            Spacer()
        }
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 26, design: .serif))
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1, green: 0.996, blue: 0.976))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.847, green: 0.878, blue: 0.847)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(key).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            Text(value)
        }
        .font(.subheadline)
    }

    private static func displayDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d. MMM yyyy HH:mm"
        return formatter.string(from: date)
    }
}

struct IdentityLinkWordsView: View {
    let words: [String]

    var body: some View {
        // Fire ord, to og to på smale skjermer.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
            ForEach(words, id: \.self) { word in
                Text(word)
                    .font(.system(size: 28, design: .serif))
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.886, green: 0.929, blue: 0.953))
                    .foregroundStyle(Color(red: 0.192, green: 0.373, blue: 0.486))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

#if canImport(VisionKit) && os(iOS)
struct IdentityLinkScannerView: UIViewControllerRepresentable {
    let onPayload: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPayload: onPayload) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onPayload: (String) -> Void
        private var delivered = false

        init(onPayload: @escaping (String) -> Void) { self.onPayload = onPayload }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue,
                   IdentityLinkFlowPresenter.looksLikeTicket(payload) {
                    delivered = true
                    dataScanner.stopScanning()
                    onPayload(payload)
                    return
                }
            }
        }
    }
}
#endif
