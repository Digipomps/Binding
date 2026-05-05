import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
@preconcurrency import CellBase
import SproutAppSupport
import SproutCrypto

public enum PortholeIngressPhase: String, Codable, Equatable, Sendable {
    case idle
    case connecting
    case connected
    case disconnected
    case failed
}

public struct PortholeIngressStatus: Codable, Equatable, Sendable {
    public var phase: PortholeIngressPhase
    public var contractID: String?
    public var bridgeEndpoint: String?
    public var artifactExpiresAt: String?
    public var lastRenewedAt: String?
    public var lastMessageAt: String?
    public var lastAcceptedIntentID: String?
    public var lastRejectedReason: String?
    public var nextRetryAt: String?
    public var retryCount: Int?
    public var lastError: String?

    public init(
        phase: PortholeIngressPhase,
        contractID: String? = nil,
        bridgeEndpoint: String? = nil,
        artifactExpiresAt: String? = nil,
        lastRenewedAt: String? = nil,
        lastMessageAt: String? = nil,
        lastAcceptedIntentID: String? = nil,
        lastRejectedReason: String? = nil,
        nextRetryAt: String? = nil,
        retryCount: Int? = nil,
        lastError: String? = nil
    ) {
        self.phase = phase
        self.contractID = contractID
        self.bridgeEndpoint = bridgeEndpoint
        self.artifactExpiresAt = artifactExpiresAt
        self.lastRenewedAt = lastRenewedAt
        self.lastMessageAt = lastMessageAt
        self.lastAcceptedIntentID = lastAcceptedIntentID
        self.lastRejectedReason = lastRejectedReason
        self.nextRetryAt = nextRetryAt
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

public protocol PortholeIngressControlling: Sendable {
    func setStatusHandler(_ handler: @escaping @Sendable (PortholeIngressStatus) async -> Void) async
    func connect(using artifact: SproutBootstrapSessionArtifact) async throws
    func disconnect() async
    func reportLifecycleStatus(_ status: PortholeIngressStatus) async
    func statusSnapshot() async -> PortholeIngressStatus
}

public enum PortholeIngressError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSessionMode(String)
    case descriptorUnavailable
    case resolverUnavailable

    public var errorDescription: String? {
        switch self {
        case .unsupportedSessionMode(let mode):
            return "Porthole ingress requires a native session, got \(mode)."
        case .descriptorUnavailable:
            return "Porthole ingress could not load a native descriptor."
        case .resolverUnavailable:
            return "Porthole ingress requires a configured CellResolver."
        }
    }
}

public actor PortholeIngressSession: PortholeIngressControlling {
    private static let nestedEnvelopeKeys = [
        "signedRemoteIntent",
        "signedIntentEnvelope",
        "remoteIntentEnvelope",
        "envelope"
    ]

    private var flowCancellable: AnyCancellable?
    private var currentRequester: Identity?
    private var currentEmit: Emit?
    private var currentStatus = PortholeIngressStatus(phase: .idle)
    private var statusHandler: (@Sendable (PortholeIngressStatus) async -> Void)?

    public init() {}

    public func setStatusHandler(_ handler: @escaping @Sendable (PortholeIngressStatus) async -> Void) {
        statusHandler = handler
    }

    public func connect(using artifact: SproutBootstrapSessionArtifact) async throws {
        guard artifact.session.mode == .native else {
            throw PortholeIngressError.unsupportedSessionMode(artifact.session.mode.rawValue)
        }
        guard let descriptor = artifact.session.nativeDescriptor else {
            throw PortholeIngressError.descriptorUnavailable
        }
        guard let resolver = await runtimeResolver() else {
            throw PortholeIngressError.resolverUnavailable
        }

        await disconnect()

        let requester = try Self.makeRequesterIdentity(
            publicKeyBase64URL: artifact.session.contract.identity_public_key
        )

        await updateStatus(
            phase: .connecting,
            contractID: artifact.session.contract.contract_id,
            bridgeEndpoint: descriptor.bridge_endpoint,
            lastError: nil
        )

        let remotePorthole = try await resolver.cellAtEndpoint(
            endpoint: descriptor.bridge_websocket_url,
            requester: requester
        )
        let publisher = try await remotePorthole.flow(requester: requester)
        let sessionActor = self

        currentRequester = requester
        currentEmit = remotePorthole
        flowCancellable = publisher.sink(
            receiveCompletion: { completion in
                Task {
                    await sessionActor.handleCompletion(completion)
                }
            },
            receiveValue: { flowElement in
                Task {
                    await sessionActor.consume(flowElement: flowElement)
                }
            }
        )

        await updateStatus(
            phase: .connected,
            contractID: artifact.session.contract.contract_id,
            bridgeEndpoint: descriptor.bridge_endpoint,
            lastError: nil
        )
    }

    public func disconnect() async {
        flowCancellable?.cancel()
        flowCancellable = nil

        if let requester = currentRequester, let currentEmit {
            currentEmit.close(requester: requester)
        }
        currentRequester = nil
        currentEmit = nil

        if currentStatus.phase != .idle {
            await updateStatus(
                phase: .disconnected,
                contractID: currentStatus.contractID,
                bridgeEndpoint: currentStatus.bridgeEndpoint,
                lastError: currentStatus.lastError
            )
        }
    }

    public func reportLifecycleStatus(_ status: PortholeIngressStatus) async {
        currentStatus = status
        if let statusHandler {
            await statusHandler(currentStatus)
        }
    }

    public func statusSnapshot() -> PortholeIngressStatus {
        currentStatus
    }

    func consume(flowElement: FlowElement) async {
        guard let envelope = Self.extractEnvelope(from: flowElement) else {
            return
        }

        let messageTimestamp = Self.iso8601String(Date())
        do {
            let acceptedIntent = try await RemoteIntentInboxService.enqueueSignedEnvelope(envelope)
            await updateStatus(
                phase: .connected,
                contractID: currentStatus.contractID,
                bridgeEndpoint: currentStatus.bridgeEndpoint,
                lastMessageAt: messageTimestamp,
                lastAcceptedIntentID: acceptedIntent.id,
                lastRejectedReason: nil,
                lastError: nil
            )
        } catch {
            await updateStatus(
                phase: .connected,
                contractID: currentStatus.contractID,
                bridgeEndpoint: currentStatus.bridgeEndpoint,
                lastMessageAt: messageTimestamp,
                lastAcceptedIntentID: currentStatus.lastAcceptedIntentID,
                lastRejectedReason: error.localizedDescription,
                lastError: nil
            )
        }
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Error>) async {
        switch completion {
        case .finished:
            await updateStatus(
                phase: .disconnected,
                contractID: currentStatus.contractID,
                bridgeEndpoint: currentStatus.bridgeEndpoint,
                lastError: nil
            )
        case .failure(let error):
            await updateStatus(
                phase: .failed,
                contractID: currentStatus.contractID,
                bridgeEndpoint: currentStatus.bridgeEndpoint,
                lastError: error.localizedDescription
            )
        }
    }

    private func updateStatus(
        phase: PortholeIngressPhase,
        contractID: String?,
        bridgeEndpoint: String?,
        lastMessageAt: String? = nil,
        lastAcceptedIntentID: String? = nil,
        lastRejectedReason: String? = nil,
        lastError: String?
    ) async {
        currentStatus = PortholeIngressStatus(
            phase: phase,
            contractID: contractID,
            bridgeEndpoint: bridgeEndpoint,
            artifactExpiresAt: currentStatus.artifactExpiresAt,
            lastRenewedAt: currentStatus.lastRenewedAt,
            lastMessageAt: lastMessageAt ?? currentStatus.lastMessageAt,
            lastAcceptedIntentID: lastAcceptedIntentID ?? currentStatus.lastAcceptedIntentID,
            lastRejectedReason: lastRejectedReason,
            nextRetryAt: currentStatus.nextRetryAt,
            retryCount: currentStatus.retryCount,
            lastError: lastError
        )
        if let statusHandler {
            await statusHandler(currentStatus)
        }
    }

    private func runtimeResolver() async -> CellResolver? {
        await MainActor.run {
            CellBase.defaultCellResolver as? CellResolver
        }
    }

    private static func makeRequesterIdentity(publicKeyBase64URL: String) throws -> Identity {
        let identity = Identity(
            publicKeyBase64URL,
            displayName: "sprout-native-subject",
            identityVault: nil
        )
        let publicKeyData = try Base64URL.decode(publicKeyBase64URL)
        identity.publicSecureKey = SecureKey(
            date: Date(),
            privateKey: false,
            use: .signature,
            algorithm: .EdDSA,
            size: 256,
            curveType: .Curve25519,
            x: nil,
            y: nil,
            compressedKey: publicKeyData
        )
        return identity
    }

    private static func extractEnvelope(from flowElement: FlowElement) -> SignedRemoteIntentEnvelope? {
        guard let contentValue = try? flowElement.content.valueType() else {
            return nil
        }
        if let direct = extractEnvelope(from: contentValue) {
            return direct
        }
        return nil
    }

    private static func extractEnvelope(from value: ValueType) -> SignedRemoteIntentEnvelope? {
        if let direct = try? SignedRemoteIntentEnvelopeValueCodec.decode(from: value) {
            return direct
        }

        guard case let .object(object) = value else {
            return nil
        }

        for key in nestedEnvelopeKeys {
            guard let nestedValue = object[key] else {
                continue
            }
            if let envelope = try? SignedRemoteIntentEnvelopeValueCodec.decode(from: nestedValue) {
                return envelope
            }
        }

        return nil
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
