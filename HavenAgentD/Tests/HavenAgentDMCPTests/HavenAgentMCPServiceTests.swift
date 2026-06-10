import Foundation
import HavenMacAutomation
import Testing
@testable import HavenAgentDMCP
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

struct HavenAgentMCPServiceTests {
    @Test
    func waitForReplyReturnsMatchingRequestReply() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let configURL = try writeConfig(paths: paths)
        let service = HavenAgentMCPService(paths: paths, configURL: configURL)

        let repliesDirectory = paths.inboxDirectory.appendingPathComponent("Replies", isDirectory: true)
        try FileManager.default.createDirectory(at: repliesDirectory, withIntermediateDirectories: true, attributes: nil)

        let reply = AgentConversationPrompt(
            id: "reply-1",
            requestId: "request-1",
            conversationId: "conversation-1",
            jobId: "job-1",
            participantId: "participant-phone",
            deviceId: "device-phone",
            ticketId: "ticket-1",
            requiredActionKey: DeviceActionRequest.approvalActionKey,
            title: "Continue coding",
            message: "Approve if the assistant should continue.",
            responseKind: "decision",
            decision: "approved",
            note: nil,
            prompt: "Approved",
            receivedAt: "2026-05-05T10:00:00Z"
        )
        try writeJSON(reply, to: repliesDirectory.appendingPathComponent("reply-1.json"))

        let output = await service.callTool(
            name: "agent.operator.wait_for_reply",
            arguments: [
                "requestId": "request-1",
                "timeoutSeconds": 0
            ]
        )

        #expect(output.isError == false)
        let structured = try #require(output.structuredContent)
        #expect((structured["matched"] as? Bool) == true)
        #expect((structured["timedOut"] as? Bool) == false)
        let nestedReply = try #require(structured["reply"] as? [String: Any])
        #expect(nestedReply["requestId"] as? String == "request-1")
        #expect(nestedReply["decision"] as? String == "approved")
        #expect(output.text.contains("approved"))
    }

    @Test
    func waitForReplyTimesOutWhenNoMatchingReplyExists() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let configURL = try writeConfig(paths: paths)
        let service = HavenAgentMCPService(paths: paths, configURL: configURL)

        let output = await service.callTool(
            name: "agent.operator.wait_for_reply",
            arguments: [
                "requestId": "missing-request",
                "timeoutSeconds": 0
            ]
        )

        #expect(output.isError == true)
        let structured = try #require(output.structuredContent)
        #expect((structured["matched"] as? Bool) == false)
        #expect((structured["timedOut"] as? Bool) == true)
    }

    @Test
    func requestAndWaitQueuesRequestAndReturnsReply() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let configURL = try writeConfig(paths: paths)
        let service = HavenAgentMCPService(paths: paths, configURL: configURL)

        let repliesDirectory = paths.inboxDirectory.appendingPathComponent("Replies", isDirectory: true)
        try FileManager.default.createDirectory(at: repliesDirectory, withIntermediateDirectories: true, attributes: nil)

        let writeReplyTask = Task {
            try await Task.sleep(nanoseconds: 50_000_000)
            let requestFiles = try FileManager.default.contentsOfDirectory(
                at: paths.inboxDirectory.appendingPathComponent("Requests", isDirectory: true),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            guard let requestFile = requestFiles.first(where: { $0.pathExtension == "json" }),
                  let requestData = try? Data(contentsOf: requestFile),
                  let request = try? JSONDecoder().decode(DeviceActionRequest.self, from: requestData) else {
                return
            }

            let reply = AgentConversationPrompt(
                id: "reply-\(request.id)",
                requestId: request.id,
                conversationId: request.conversationId ?? request.id,
                jobId: request.jobId,
                participantId: "participant-phone",
                deviceId: "device-phone",
                ticketId: request.ticketId ?? "ticket-\(request.id)",
                requiredActionKey: DeviceActionRequest.approvalActionKey,
                title: request.title,
                message: request.message,
                responseKind: "decision",
                decision: "approved",
                note: nil,
                prompt: "Approved",
                receivedAt: "2026-05-05T10:00:01Z"
            )
            try writeJSON(reply, to: repliesDirectory.appendingPathComponent("reply-\(request.id).json"))
        }
        defer { writeReplyTask.cancel() }

        let output = await service.callTool(
            name: "agent.operator.request_and_wait",
            arguments: [
                "responseMode": "approval",
                "title": "Continue coding",
                "message": "Approve if the assistant should continue.",
                "timeoutSeconds": 1,
                "pollIntervalSeconds": 0.05
            ]
        )

        #expect(output.isError == false)
        let structured = try #require(output.structuredContent)
        let queuedRequest = try #require(structured["queuedRequest"] as? [String: Any])
        let queuedRequestID = try #require(queuedRequest["requestId"] as? String)
        #expect((structured["matched"] as? Bool) == true)
        let reply = try #require(structured["reply"] as? [String: Any])
        #expect(reply["requestId"] as? String == queuedRequestID)
        #expect(reply["decision"] as? String == "approved")
    }

    @Test
    func codexPromptResourceAndToolsClaimAndCompleteQueuedPhonePrompt() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let configURL = try writeConfig(paths: paths)
        let service = HavenAgentMCPService(paths: paths, configURL: configURL)
        let queue = CodexPromptQueue(paths: paths)

        try queue.enqueue(
            CodexPromptRequest(
                id: "codex-request-1",
                requestId: "codex-request-1",
                conversationId: "conversation-codex-1",
                jobId: "job-codex-1",
                participantId: "participant-phone",
                deviceId: "device-phone",
                title: "Start Codex",
                message: "Run the next safe task.",
                prompt: "Inspect status and continue the HAVENAgentD MCP integration.",
                purpose: "purpose://operate-local-haven-agent",
                interests: ["codex", "automation"],
                workspacePath: "/tmp/haven",
                preferredAssistant: "codex",
                source: "test",
                sourceActionKey: CodexPromptQueueContract.requiredActionKey,
                createdAt: "2026-05-12T10:00:00Z",
                updatedAt: "2026-05-12T10:00:00Z"
            )
        )

        let resource = try await service.readResource(uri: "haven-agent://codex/prompt-requests")
        let contents = try #require(resource["contents"] as? [[String: Any]])
        let text = try #require(contents.first?["text"] as? String)
        #expect(text.contains("\"queuedCount\" : 1"))

        let nextOutput = await service.callTool(
            name: "agent.codex.next_prompt",
            arguments: [
                "workspacePath": "/tmp/haven",
                "assistant": "codex",
                "claim": true
            ]
        )

        #expect(nextOutput.isError == false)
        let nextStructured = try #require(nextOutput.structuredContent)
        #expect((nextStructured["matched"] as? Bool) == true)
        #expect((nextStructured["claimed"] as? Bool) == true)
        let nextRequest = try #require(nextStructured["request"] as? [String: Any])
        #expect(nextRequest["id"] as? String == "codex-request-1")
        #expect(nextRequest["status"] as? String == "started")

        let doneOutput = await service.callTool(
            name: "agent.codex.mark_prompt_done",
            arguments: [
                "id": "codex-request-1",
                "status": "done",
                "summary": "Completed in test."
            ]
        )

        #expect(doneOutput.isError == false)
        let doneStructured = try #require(doneOutput.structuredContent)
        let doneRequest = try #require(doneStructured["request"] as? [String: Any])
        #expect(doneRequest["status"] as? String == "done")
        #expect(doneRequest["resultSummary"] as? String == "Completed in test.")
        #expect(queue.queuedRecords().isEmpty)
        #expect(queue.startedRecords().isEmpty)
        #expect(queue.completedRecords().count == 1)
    }

    @Test
    func xcodeEnsureWorkspaceToolUsesSafeDefaultsAndReturnsBuildResult() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let configURL = try writeConfig(paths: paths)
        let xcodeController = RecordingXcodeWorkspaceController(
            result: XcodeWorkspaceResult(
                ok: true,
                workspacePath: "/tmp/CellScaffold/CellScaffold.xcworkspace",
                exclusiveLocalPackagePath: "/tmp/CellProtocol",
                closedWorkspaceNames: ["Binding.xcworkspace"],
                openedWorkspaceName: "CellScaffold.xcworkspace",
                scheme: "Run",
                destination: "My Mac (arm64) [macosx/arm64]",
                closeOtherWorkspaces: true,
                buildRequested: true,
                completed: true,
                status: "succeeded",
                errorCount: 0,
                warningCount: 119
            )
        )
        let service = HavenAgentMCPService(
            paths: paths,
            configURL: configURL,
            xcodeController: xcodeController
        )

        let output = await service.callTool(
            name: "agent.xcode.ensure_workspace",
            arguments: [
                "workspacePath": "/tmp/CellScaffold/CellScaffold.xcworkspace",
                "exclusiveLocalPackagePath": "/tmp/CellProtocol",
                "scheme": "Run"
            ]
        )

        #expect(output.isError == false)
        let maybeRequest = await xcodeController.lastRequest()
        let request = try #require(maybeRequest)
        #expect(request.workspacePath == "/tmp/CellScaffold/CellScaffold.xcworkspace")
        #expect(request.exclusiveLocalPackagePath == "/tmp/CellProtocol")
        #expect(request.scheme == "Run")
        #expect(request.destinationName == "My Mac (arm64)")
        #expect(request.destinationPlatform == "macosx")
        #expect(request.destinationArchitecture == "arm64")
        #expect(request.closeOtherWorkspaces == true)
        #expect(request.build == true)

        let structured = try #require(output.structuredContent)
        #expect(structured["status"] as? String == "succeeded")
        #expect(structured["errorCount"] as? Int == 0)
        #expect(output.text.contains("CellScaffold.xcworkspace"))
    }

    private func makeTemporaryRoot() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDMCP-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private func writeConfig(paths: RuntimePaths) throws -> URL {
        var config = AgentConfig.example(paths: paths)
        config.deviceActionRelay = DeviceActionRelayConfig(
            enabled: true,
            notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox",
            defaultParticipantID: "participant-phone",
            defaultDeviceID: "device-phone"
        )

        let configURL = paths.configFile
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try writeJSON(config, to: configURL)
        return configURL
    }

    private func writeJSON<T: Encodable>(_ value: T, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: fileURL, options: [.atomic])
    }
}

private actor RecordingXcodeWorkspaceController: XcodeWorkspaceControlling {
    private let result: XcodeWorkspaceResult
    private var requests: [XcodeWorkspaceRequest] = []

    init(result: XcodeWorkspaceResult) {
        self.result = result
    }

    func ensureWorkspace(_ request: XcodeWorkspaceRequest) async throws -> XcodeWorkspaceResult {
        requests.append(request)
        return result
    }

    func lastRequest() -> XcodeWorkspaceRequest? {
        requests.last
    }
}
