import Foundation
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
