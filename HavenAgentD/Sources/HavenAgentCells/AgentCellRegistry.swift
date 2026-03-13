import Foundation
import CellBase

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
        )
    ]

    public static func instantiate(kind: AgentCellKind, owner: Identity) async throws -> GeneralCell {
        switch kind {
        case .agentSupervisor:
            return await AgentSupervisorCell(owner: owner)
        case .remoteIntentInbox:
            return await RemoteIntentInboxCell(owner: owner)
        case .remoteIntentReview:
            return await RemoteIntentReviewCell(owner: owner)
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
