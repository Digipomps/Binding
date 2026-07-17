import Foundation
import HavenMacAutomation

public enum RemoteIntentAuditOutcome: String, Codable, Equatable, Sendable {
    case approvedDispatched = "approved_dispatched"
    case approvedFailed = "approved_failed"
    case automaticDispatched = "automatic_dispatched"
    case automaticSuppressed = "automatic_suppressed"
    case automaticFailed = "automatic_failed"
    case rejected
}

public struct RemoteIntentAuditRecord: Codable, Equatable, Sendable {
    public var intentID: String
    public var actionID: String
    public var issuerID: String?
    public var verificationStatus: String
    public var outcome: RemoteIntentAuditOutcome
    public var reviewer: String
    public var note: String?
    public var recordedAt: String
    public var executedAction: ExecutedActionRecord?
    public var errorMessage: String?

    public init(
        intentID: String,
        actionID: String,
        issuerID: String?,
        verificationStatus: String,
        outcome: RemoteIntentAuditOutcome,
        reviewer: String,
        note: String?,
        recordedAt: String,
        executedAction: ExecutedActionRecord? = nil,
        errorMessage: String? = nil
    ) {
        self.intentID = intentID
        self.actionID = actionID
        self.issuerID = issuerID
        self.verificationStatus = verificationStatus
        self.outcome = outcome
        self.reviewer = reviewer
        self.note = note
        self.recordedAt = recordedAt
        self.executedAction = executedAction
        self.errorMessage = errorMessage
    }
}

public enum RemoteIntentExecutionError: Error, Equatable, Sendable, LocalizedError {
    case policyUnavailable
    case intentNotVerified(String)
    case unknownAction(String)
    case ambiguousAction(String)
    case unexpectedShortcutArguments([String])

    public var errorDescription: String? {
        switch self {
        case .policyUnavailable:
            return "Automation policy is not configured for remote intent execution."
        case .intentNotVerified(let intentID):
            return "Remote intent is not verified and cannot be dispatched: \(intentID)"
        case .unknownAction(let actionID):
            return "Remote intent action is not known locally: \(actionID)"
        case .ambiguousAction(let actionID):
            return "Remote intent action matches multiple local action kinds: \(actionID)"
        case .unexpectedShortcutArguments(let keys):
            return "Remote shortcut intent contains unsupported arguments: \(keys.joined(separator: ","))"
        }
    }
}

public actor RemoteIntentExecutionBridge {
    public static let shared = RemoteIntentExecutionBridge()

    private let shortcutRunner: ShortcutRunner
    private let appleScriptRunner: AppleScriptRunner
    private var policy: AutomationPolicy?

    public init(processRunner: any ProcessRunning = FoundationProcessRunner()) {
        self.shortcutRunner = ShortcutRunner(processRunner: processRunner)
        self.appleScriptRunner = AppleScriptRunner(processRunner: processRunner)
    }

    public func update(policy: AutomationPolicy?) {
        self.policy = policy
    }

    public func execute(intent: QueuedRemoteIntent) async throws -> ExecutedActionRecord {
        guard intent.verificationStatus == "verified" else {
            throw RemoteIntentExecutionError.intentNotVerified(intent.id)
        }
        guard let policy else {
            throw RemoteIntentExecutionError.policyUnavailable
        }

        let matchingShortcuts = policy.shortcuts.filter { $0.id == intent.actionID }
        let matchingAppleScripts = policy.appleScripts.filter { $0.id == intent.actionID }

        if matchingShortcuts.isEmpty && matchingAppleScripts.isEmpty {
            throw RemoteIntentExecutionError.unknownAction(intent.actionID)
        }
        if !matchingShortcuts.isEmpty && !matchingAppleScripts.isEmpty {
            throw RemoteIntentExecutionError.ambiguousAction(intent.actionID)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        if !matchingShortcuts.isEmpty {
            let extraKeys = Set(intent.arguments.keys).subtracting(["inputPath"])
            if !extraKeys.isEmpty {
                throw RemoteIntentExecutionError.unexpectedShortcutArguments(extraKeys.sorted())
            }
            let invocation = ShortcutInvocation(
                id: intent.actionID,
                origin: .trustedRemote,
                inputPath: intent.arguments["inputPath"]
            )
            _ = try await shortcutRunner.run(invocation, policy: policy)
            return ExecutedActionRecord(
                kind: .shortcut,
                id: intent.actionID,
                status: "succeeded",
                recordedAt: timestamp
            )
        }

        let invocation = AppleScriptInvocation(
            id: intent.actionID,
            origin: .trustedRemote,
            arguments: intent.arguments
        )
        _ = try await appleScriptRunner.run(invocation, policy: policy)
        return ExecutedActionRecord(
            kind: .appleScript,
            id: intent.actionID,
            status: "succeeded",
            recordedAt: timestamp
        )
    }
}
