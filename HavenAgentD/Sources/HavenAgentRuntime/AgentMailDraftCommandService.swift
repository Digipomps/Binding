import Foundation
import HavenMacAutomation

public struct AgentMailDraftCommandRequest: Codable, Equatable, Sendable {
    public var to: String
    public var subject: String
    public var body: String

    public init(to: String, subject: String, body: String) {
        self.to = to
        self.subject = subject
        self.body = body
    }
}

public struct AgentMailDraftCommandResult: Codable, Equatable, Sendable {
    public var status: String
    public var actionID: String
    public var deliveryMode: String
    public var message: String

    public init(status: String, actionID: String, deliveryMode: String, message: String) {
        self.status = status
        self.actionID = actionID
        self.deliveryMode = deliveryMode
        self.message = message
    }
}

public actor AgentMailDraftCommandService {
    private let policy: AutomationPolicy
    private let runner: AppleScriptRunner

    public init(
        policy: AutomationPolicy,
        processRunner: any ProcessRunning = FoundationProcessRunner()
    ) {
        self.policy = policy
        self.runner = AppleScriptRunner(processRunner: processRunner)
    }

    public func composeDraft(_ request: AgentMailDraftCommandRequest) async throws -> AgentMailDraftCommandResult {
        let invocation = AppleScriptInvocation(
            id: AgentMailDraftAutomation.actionID,
            origin: .local,
            arguments: [
                "to": request.to,
                "subject": request.subject,
                "body": request.body
            ]
        )
        _ = try await runner.run(invocation, policy: policy)
        return AgentMailDraftCommandResult(
            status: "draft_created",
            actionID: AgentMailDraftAutomation.actionID,
            deliveryMode: "visible_mail_app_draft",
            message: "Mail.app draft created for local operator review."
        )
    }
}
