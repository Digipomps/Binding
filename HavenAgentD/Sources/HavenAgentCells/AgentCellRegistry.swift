import Foundation
import CellBase
import HavenAgentRuntime

public struct AgentCellDescriptor: Equatable, Sendable {
    public var kind: AgentCellKind
    public var endpoint: String
    public var typeName: String
    public var sideEffectBoundary: String

    public init(kind: AgentCellKind, endpoint: String, typeName: String, sideEffectBoundary: String) {
        self.kind = kind
        self.endpoint = endpoint
        self.typeName = typeName
        self.sideEffectBoundary = sideEffectBoundary
    }
}

public enum AgentCellRegistry {
    public static let concreteDescriptors: [AgentCellDescriptor] = [
        AgentCellDescriptor(
            kind: .agentSupervisor,
            endpoint: "cell:///agent/supervisor",
            typeName: "AgentSupervisorCell",
            sideEffectBoundary: "Read-only health projection."
        ),
        AgentCellDescriptor(
            kind: .agentIdentity,
            endpoint: "cell:///agent/identity",
            typeName: "AgentIdentityCell",
            sideEffectBoundary: "Read-only identity projection plus explicit enrollment attestation signing."
        ),
        AgentCellDescriptor(
            kind: .remoteIntentInbox,
            endpoint: "cell:///agent/intents/inbox",
            typeName: "RemoteIntentInboxCell",
            sideEffectBoundary: "Queues structured intents only. Performs no local side effect."
        ),
        AgentCellDescriptor(
            kind: .remoteIntentReview,
            endpoint: "cell:///agent/intents/review",
            typeName: "RemoteIntentReviewCell",
            sideEffectBoundary: "Approves or rejects verified intents and dispatches only locally allowlisted remote actions."
        ),
        AgentCellDescriptor(
            kind: .localModel,
            endpoint: "cell:///agent/local-model",
            typeName: "AgentLocalModelCell",
            sideEffectBoundary: "Calls a configured loopback local model backend; no device automation side effects."
        ),
        AgentCellDescriptor(
            kind: .networkSentinel,
            endpoint: "cell:///agent/network/sentinel",
            typeName: "NetworkSentinelCell",
            sideEffectBoundary: "Read-only link-health projection; emits flood FlowElements; optional bounded capture and notification when enabled."
        ),
        AgentCellDescriptor(
            kind: .secretCredential,
            endpoint: "cell:///agent/credentials",
            typeName: "SecretCredentialCell",
            sideEffectBoundary: "Stores only redacted credential metadata in cell state and encrypted secret blobs in the local vault."
        ),
        AgentCellDescriptor(
            kind: .emailOutbox,
            endpoint: AgentMailDraftAutomation.endpoint,
            typeName: "AgentMailDraftCell",
            sideEffectBoundary: "Prepares reviewed email draft intents; approved execution creates a visible Mail.app draft and does not send automatically."
        ),
        AgentCellDescriptor(
            kind: .signatureStatements,
            endpoint: AgentSignatureStatement.endpoint,
            typeName: "AgentSignatureCell",
            sideEffectBoundary: "Prepares audience-bound signing intents; daemon-owned execution signs detached payload hashes with nonce and expiry enforcement."
        )
    ]

    public static func instantiate(kind: AgentCellKind, owner: Identity) async throws -> GeneralCell {
        switch kind {
        case .agentSupervisor:
            return await AgentSupervisorCell(owner: owner)
        case .agentIdentity:
            return await AgentIdentityCell(owner: owner)
        case .remoteIntentInbox:
            return await RemoteIntentInboxCell(owner: owner)
        case .remoteIntentReview:
            return await RemoteIntentReviewCell(owner: owner)
        case .localModel:
            return await AgentLocalModelCell(owner: owner)
        case .networkSentinel:
            return await NetworkSentinelCell(owner: owner)
        case .secretCredential:
            return await SecretCredentialCell(owner: owner)
        case .emailOutbox:
            return await AgentMailDraftCell(owner: owner)
        case .signatureStatements:
            return await AgentSignatureCell(owner: owner)
        default:
            throw AgentCellRegistryError.unsupportedConcreteKind(kind)
        }
    }

    public static func instantiateDefaultCells(owner: Identity) async -> [GeneralCell] {
        var cells: [GeneralCell] = []
        for descriptor in concreteDescriptors {
            if let cell = try? await instantiate(kind: descriptor.kind, owner: owner) {
                cells.append(cell)
            }
        }
        return cells
    }
}

public enum AgentCellRegistryError: Error, LocalizedError, Sendable {
    case unsupportedConcreteKind(AgentCellKind)

    public var errorDescription: String? {
        switch self {
        case .unsupportedConcreteKind(let kind):
            return "No concrete runtime cell is registered for kind '\(kind.rawValue)'."
        }
    }
}
