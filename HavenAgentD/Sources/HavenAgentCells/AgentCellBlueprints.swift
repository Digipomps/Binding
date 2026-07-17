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
    case networkSentinel
    case secretCredential
    case emailOutbox
    case signatureStatements
    case personalButlerSchedule
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
        ),
        AgentCellBlueprint(
            kind: .networkSentinel,
            suggestedCellName: "NetworkSentinelCell",
            purpose: "Watch local link health and surface flood alerts the operator actually cares about.",
            sideEffectBoundary: "Read-only interface counter observation; emits FlowElements; may trigger a bounded local packet capture and a user notification when enabled."
        ),
        AgentCellBlueprint(
            kind: .secretCredential,
            suggestedCellName: "SecretCredentialCell",
            purpose: "Keep entity-scoped provider credentials as redacted metadata while raw secrets stay encrypted in the local vault.",
            sideEffectBoundary: "May store encrypted credential blobs in Keychain and open them only after explicit unlock-key authorization."
        ),
        AgentCellBlueprint(
            kind: .emailOutbox,
            suggestedCellName: "AgentMailDraftCell",
            purpose: "Prepare locally reviewed email draft intents for contacts that do not have a CellProtocol endpoint.",
            sideEffectBoundary: "Prepares review-intents only; approved execution may create a visible Mail.app draft but never sends automatically."
        ),
        AgentCellBlueprint(
            kind: .signatureStatements,
            suggestedCellName: "AgentSignatureCell",
            purpose: "Prepare audience-bound detached signed statements using the stable local agent identity.",
            sideEffectBoundary: "Prepares redacted signing intents only; daemon-owned execution signs canonical metadata plus payload hash after purpose, audience, expiry and nonce validation."
        ),
        AgentCellBlueprint(
            kind: .personalButlerSchedule,
            suggestedCellName: "PersonalButlerScheduleCell",
            purpose: "Run owner-approved Butler schedules in HAVENAgentD and evaluate fixed signed wake requests.",
            sideEffectBoundary: "May launch only the HAVEN bundle with a fixed haven://butler/check-in URL after local owner policy approval."
        )
    ]
}
