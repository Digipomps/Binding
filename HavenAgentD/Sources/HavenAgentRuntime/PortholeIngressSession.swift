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
    case requesterAuthorityUnavailable
    case requesterPublicKeyMismatch
    case requesterRemoteBridgeAuthorityUnavailable(String)
    case remotePortholeResolutionFailed(String)
    case remotePortholeFlowFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSessionMode(let mode):
            return "Porthole ingress requires a native session, got \(mode)."
        case .descriptorUnavailable:
            return "Porthole ingress could not load a native descriptor."
        case .resolverUnavailable:
            return "Porthole ingress requires a configured CellResolver."
        case .requesterAuthorityUnavailable:
            return "Porthole ingress requires the vault-backed local agent identity."
        case .requesterPublicKeyMismatch:
            return "Porthole ingress contract identity does not match the local agent identity."
        case .requesterRemoteBridgeAuthorityUnavailable(let detail):
            return "Porthole ingress local agent identity could not prove remote bridge authority: \(detail)"
        case .remotePortholeResolutionFailed(let detail):
            return "Porthole ingress failed to resolve the remote Cell: \(detail)"
        case .remotePortholeFlowFailed(let detail):
            return "Porthole ingress resolved the remote Cell but failed to open Flow: \(detail)"
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

        let requester = try await Self.makeRequesterIdentity(
            publicKeyBase64URL: artifact.session.contract.identity_public_key,
            descriptor: await AgentRuntimeBridge.shared.agentIdentityDescriptorSnapshot(),
            vault: CellBase.defaultIdentityVault
        )
        if let failure = await Self.resolverRemoteBridgeAuthorityFailure(
            requester: requester,
            logicalEndpoint: descriptor.bridge_websocket_url
        ) {
            throw PortholeIngressError.requesterRemoteBridgeAuthorityUnavailable(failure)
        }

        await updateStatus(
            phase: .connecting,
            contractID: artifact.session.contract.contract_id,
            bridgeEndpoint: descriptor.bridge_endpoint,
            lastError: nil
        )

        let remotePorthole: Emit
        do {
            remotePorthole = try await resolver.cellAtEndpoint(
                endpoint: descriptor.bridge_websocket_url,
                requester: requester
            )
        } catch {
            throw PortholeIngressError.remotePortholeResolutionFailed(
                String(reflecting: error)
            )
        }
        let publisher: AnyPublisher<FlowElement, Error>
        do {
            publisher = try await remotePorthole.flow(requester: requester)
        } catch {
            throw PortholeIngressError.remotePortholeFlowFailed(
                String(reflecting: error)
            )
        }
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

        if artifact.session.contract.capability_grants.contains(AgentLocalModelReverseIntentContract.capability),
           let providerID = await AgentRuntimeBridge.shared.localModelProviderIDSnapshot(),
           let remotePorthole = remotePorthole as? Meddle {
            _ = try await remotePorthole.set(
                keypath: AgentLocalModelReverseIntentContract.registrationKeypath,
                value: .object([
                    "contractID": .string(artifact.session.contract.contract_id),
                    "providerID": .string(providerID)
                ]),
                requester: requester
            )
        }

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
            if acceptedIntent.actionID == AgentLocalModelReverseIntentContract.actionID {
                await handleLocalModelReverseIntent(acceptedIntent)
            }
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

    private func handleLocalModelReverseIntent(_ intent: QueuedRemoteIntent) async {
        let response: ValueType
        let requestID = intent.arguments["requestID"] ?? intent.id
        let providerID = intent.arguments["providerID"] ?? "unknown"
        do {
            guard let currentPolicy = await AgentRuntimeBridge.shared.remoteIntentPolicySnapshot() else {
                throw RemoteIntentVerificationError.policyUnavailable
            }
            _ = try RemoteIntentVerifier.reverifyQueuedIntent(intent, policy: currentPolicy)
            let request = try AgentLocalModelReverseIntentContract.decode(arguments: intent.arguments)
            let result = await AgentRuntimeBridge.shared.invokeLocalModelReverseIntent(request)
            response = AgentLocalModelReverseIntentContract.responseValue(
                requestID: request.requestID,
                providerID: request.providerID,
                result: result
            )
        } catch {
            response = .object([
                "requestID": .string(requestID),
                "providerID": .string(providerID),
                "result": .object([
                    "status": .string("rejected"),
                    "error": .string(error.localizedDescription)
                ])
            ])
        }

        guard let requester = currentRequester,
              let remotePorthole = currentEmit as? Meddle else { return }
        _ = try? await remotePorthole.set(
            keypath: AgentLocalModelReverseIntentContract.responseKeypath,
            value: response,
            requester: requester
        )
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

    static func makeRequesterIdentity(
        publicKeyBase64URL: String,
        descriptor: AgentIdentityDescriptor?,
        vault: IdentityVaultProtocol?
    ) async throws -> Identity {
        guard let descriptor, let vault else {
            throw PortholeIngressError.requesterAuthorityUnavailable
        }
        guard descriptor.publicKeyBase64URL == publicKeyBase64URL else {
            throw PortholeIngressError.requesterPublicKeyMismatch
        }

        let expectedPublicKey = try Base64URL.decode(publicKeyBase64URL)
        let contexts = [descriptor.identityContext, descriptor.identityUUID]
        for context in contexts {
            guard let identity = await vault.identity(
                for: context,
                makeNewIfNotFound: false
            ) else {
                continue
            }
            guard identity.uuid == descriptor.identityUUID,
                  identity.publicSecureKey?.compressedKey == expectedPublicKey,
                  await vault.identityExistInVault(identity) else {
                continue
            }
            return identity
        }

        if let identity = await vault.identity(forUUID: descriptor.identityUUID),
           identity.publicSecureKey?.compressedKey == expectedPublicKey,
           await vault.identityExistInVault(identity) {
            return identity
        }
        throw PortholeIngressError.requesterAuthorityUnavailable
    }

    static func provesResolverRemoteBridgeAuthority(
        requester: Identity,
        logicalEndpoint: String
    ) async -> Bool {
        await resolverRemoteBridgeAuthorityFailure(
            requester: requester,
            logicalEndpoint: logicalEndpoint
        ) == nil
    }

    static func resolverRemoteBridgeAuthorityFailure(
        requester: Identity,
        logicalEndpoint: String
    ) async -> String? {
        let ownedRequester = Identity(
            requester.uuid,
            displayName: requester.displayName,
            identityVault: requester.identityVault
        )
        ownedRequester.publicSecureKey = requester.publicSecureKey
        ownedRequester.publicKeyAgreementSecureKey = requester.publicKeyAgreementSecureKey
        ownedRequester.homeVaultReference = requester.homeVaultReference

        guard let vault = ownedRequester.identityVault else {
            return "resolver-owned identity clone has no vault"
        }
        guard let homeVaultReference = ownedRequester.homeVaultReference,
              homeVaultReference.isEmpty == false else {
            return "resolver-owned identity clone has no home vault reference"
        }
        guard await vault.identityVaultReference() == homeVaultReference else {
            return "identity vault reference does not match the declared home vault"
        }
        guard ownedRequester.signingPublicKeyFingerprint?.isEmpty == false else {
            return "resolver-owned identity clone has no signing-key fingerprint"
        }
        guard await vault.identityExistInVault(ownedRequester) else {
            return "identity vault does not recognize the resolver-owned identity clone"
        }
        do {
            guard try await ownedRequester.sign(
                data: Data("haven-agentd.remote-bridge-authority-preflight.v1".utf8)
            ) != nil else {
                return "identity vault returned no preflight signature"
            }
        } catch {
            return "identity vault could not sign the preflight payload (\(String(reflecting: type(of: error))))"
        }

        guard let nonce = await vault.randomBytes64(),
              nonce.count >= IdentitySigningChallenge.minimumNonceBytes,
              nonce.count <= IdentitySigningChallenge.maximumNonceBytes else {
            return "identity vault could not create a valid signing-challenge nonce"
        }
        let challengeData: Data
        do {
            challengeData = try IdentitySigningChallenge.signingData(
                for: ownedRequester,
                trustedIdentity: ownedRequester,
                domain: "cellprotocol.remote-bridge",
                resource: CellResolver.remoteBridgeAuthorityChallengeResource(
                    for: logicalEndpoint
                ),
                action: "resolve",
                audience: "CellResolver",
                nonce: nonce
            )
        } catch {
            return "CellProtocol could not encode the signing challenge (\(String(reflecting: error)))"
        }
        do {
            _ = try IdentitySigningChallenge.validateSigningData(
                challengeData,
                for: ownedRequester
            )
        } catch {
            return "CellProtocol rejected its local signing challenge (\(String(reflecting: error)))"
        }
        let challengeSignature: Data
        do {
            guard let signature = try await ownedRequester.sign(data: challengeData) else {
                return "identity vault returned no signing-challenge signature"
            }
            challengeSignature = signature
        } catch {
            return "identity vault could not sign the CellProtocol challenge (\(String(reflecting: type(of: error))))"
        }
        guard IdentityPublicKeySignatureVerifier.verify(
            signature: challengeSignature,
            messageData: challengeData,
            identity: ownedRequester
        ) else {
            return "CellProtocol rejected the local signing-challenge signature"
        }
        return nil
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
