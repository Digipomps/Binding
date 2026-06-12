import Foundation

public enum AgentCellKind: String, Codable, CaseIterable, Sendable {
    case fileWatch
    case shortcutAction
    case appleScriptAction
    case remoteIntentInbox
    case remoteIntentReview
    case agentSupervisor
    case agentIdentity
    case localModel
}

public struct AgentCellBlueprint: Codable, Equatable, Sendable {
    public var kind: AgentCellKind
    public var suggestedCellName: String
    public var purpose: String
    public var sideEffectBoundary: String

    public init(
        kind: AgentCellKind,
        suggestedCellName: String,
        purpose: String,
        sideEffectBoundary: String
    ) {
        self.kind = kind
        self.suggestedCellName = suggestedCellName
        self.purpose = purpose
        self.sideEffectBoundary = sideEffectBoundary
    }
}

public enum AgentCellCatalog {
    public static let defaultBlueprints: [AgentCellBlueprint] = [
        AgentCellBlueprint(
            kind: .fileWatch,
            suggestedCellName: "FileWatchCell",
            purpose: "Observe local folders and publish deterministic FlowElements.",
            sideEffectBoundary: "Read-only filesystem observation."
        ),
        AgentCellBlueprint(
            kind: .shortcutAction,
            suggestedCellName: "ShortcutActionCell",
            purpose: "Map typed intents onto local Shortcuts automation.",
            sideEffectBoundary: "May launch approved Shortcuts only."
        ),
        AgentCellBlueprint(
            kind: .appleScriptAction,
            suggestedCellName: "AppleScriptActionCell",
            purpose: "Invoke local AppleScript handlers through allowlisted definitions.",
            sideEffectBoundary: "May talk to GUI apps only through locally approved scripts."
        ),
        AgentCellBlueprint(
            kind: .remoteIntentInbox,
            suggestedCellName: "RemoteIntentInboxCell",
            purpose: "Receive signed remote intents and queue them for local policy evaluation.",
            sideEffectBoundary: "No side effects. Dispatches only after explicit authorization."
        ),
        AgentCellBlueprint(
            kind: .remoteIntentReview,
            suggestedCellName: "RemoteIntentReviewCell",
            purpose: "Approve or reject verified remote intents and record the decision trail.",
            sideEffectBoundary: "May dispatch only locally allowlisted remote actions after explicit approval."
        ),
        AgentCellBlueprint(
            kind: .agentSupervisor,
            suggestedCellName: "AgentSupervisorCell",
            purpose: "Expose heartbeat, last renewal status, audit markers and last side effect.",
            sideEffectBoundary: "Read-only health projection."
        ),
        AgentCellBlueprint(
            kind: .agentIdentity,
            suggestedCellName: "AgentIdentityCell",
            purpose: "Expose the stable local agent identity and issue signed local enrollment attestations.",
            sideEffectBoundary: "Signs only explicit enrollment payloads over the loopback control bridge."
        ),
        AgentCellBlueprint(
            kind: .localModel,
            suggestedCellName: "AgentLocalModelCell",
            purpose: "Expose an operator-approved local language model backend through CellProtocol.",
            sideEffectBoundary: "May call only the configured loopback local model backend by default."
        )
    ]
}
