import Foundation
import HavenAgentRuntime
import HavenMacAutomation
import Testing

private actor RecordingMailDraftProcessRunner: ProcessRunning {
    private(set) var invocations: [(executableURL: URL, arguments: [String])] = []

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        invocations.append((executableURL, arguments))
        return SubprocessResult(
            command: [executableURL.path] + arguments,
            terminationStatus: 0,
            standardOutput: "draft-created\n",
            standardError: ""
        )
    }
}

@Suite
struct AgentMailDraftCommandServiceTests {
    @Test
    func composeDraftRunsAllowlistedMailDraftActionInsideAgentRuntime() async throws {
        let runner = RecordingMailDraftProcessRunner()
        let service = AgentMailDraftCommandService(
            policy: AutomationPolicy(appleScripts: [AgentMailDraftAutomation.appleScriptDefinition]),
            processRunner: runner
        )

        let result = try await service.composeDraft(
            AgentMailDraftCommandRequest(
                to: "kjetilh@mac.com",
                subject: "HAVENAgentD test",
                body: "Dette er en test fra HAVENAgentD."
            )
        )

        #expect(result.status == "draft_created")
        #expect(result.actionID == AgentMailDraftAutomation.actionID)
        #expect(result.deliveryMode == "visible_mail_app_draft")

        let invocations = await runner.invocations
        let invocation = try #require(invocations.first)
        #expect(invocation.executableURL.path == "/usr/bin/osascript")
        #expect(invocation.arguments.contains(AgentMailDraftAutomation.appleScriptDefinition.source))
        #expect(invocation.arguments.suffix(3) == ["kjetilh@mac.com", "HAVENAgentD test", "Dette er en test fra HAVENAgentD."])
    }
}
