import Foundation
import Testing
import CellBase
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

private actor RecordingDeviceActionStore {
    private var actions: [PublishedDeviceAction] = []

    func append(_ action: PublishedDeviceAction) {
        actions.append(action)
    }

    func snapshot() -> [PublishedDeviceAction] {
        actions
    }
}

private final class RecordingDeviceActionPublisher: @unchecked Sendable, DeviceActionPublishing {
    private let store = RecordingDeviceActionStore()

    func publish(_ action: PublishedDeviceAction, requester: Identity) async throws -> DeviceActionPublishReceipt {
        await store.append(action)
        return DeviceActionPublishReceipt(
            ticketId: "ticket-\(action.id)",
            publishedAt: "2026-05-02T12:00:00Z",
            response: ["status": .string("queued")]
        )
    }

    func snapshot() async -> [PublishedDeviceAction] {
        await store.snapshot()
    }
}

struct DeviceActionRelayTests {
    @Test
    func scanPendingRequestsPublishesRequestAndWritesProcessedRecord() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let publisher = RecordingDeviceActionPublisher()
        let relay = DeviceActionRelay(
            paths: paths,
            config: DeviceActionRelayConfig(
                enabled: true,
                notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox",
                defaultParticipantID: "participant-phone",
                defaultDeviceID: "device-phone"
            ),
            publisher: publisher,
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()

        let request = DeviceActionRequest(
            id: "request-1",
            responseMode: .approval,
            title: "Continue coding",
            message: "Approve if the assistant should continue the edit.",
            purpose: "purpose://agent-approval",
            purposeDescription: "Operator approval for continued code edits.",
            interests: ["approval", "automation"],
            conversationId: "conversation-1",
            jobId: "job-1",
            sourceCellEndpoint: "cell:///AgentConversationInbox",
            payload: ["source": .string("codex")]
        )
        try writeJSON(
            request,
            to: relay.requestsDirectoryURL().appendingPathComponent("request-1.json")
        )

        let records = try await relay.scanPendingRequests()
        let published = await publisher.snapshot()

        #expect(records.count == 1)
        #expect(published.count == 1)
        #expect(records.first?.action.ticketId == "ticket-request-1")
        #expect(published.first?.participantId == "participant-phone")
        #expect(published.first?.deviceId == "device-phone")
        #expect(published.first?.requiredActionKey == DeviceActionRequest.approvalActionKey)
        #expect(published.first?.triggerEvent == "workflow.review.pending")
        #expect(published.first?.payload["deviceId"] == .string("device-phone"))
        #expect(published.first?.payload["responseMode"] == .string("approval"))
        #expect(published.first?.payload["conversationId"] == .string("conversation-1"))
        #expect(published.first?.payload["interests"] == .array([.string("approval"), .string("automation")]))

        let processedFile = relay.processedDirectoryURL().appendingPathComponent("request-1.json")
        #expect(FileManager.default.fileExists(atPath: processedFile.path))
        #expect(FileManager.default.fileExists(atPath: relay.requestsDirectoryURL().appendingPathComponent("request-1.json").path) == false)
    }

    @Test
    func scanPendingRequestsWritesFailedRecordWhenTargetIdentityIsMissing() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let relay = DeviceActionRelay(
            paths: paths,
            config: DeviceActionRelayConfig(
                enabled: true,
                notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox"
            ),
            publisher: RecordingDeviceActionPublisher(),
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()

        let request = DeviceActionRequest(
            id: "request-2",
            title: "Missing target",
            message: "This should fail without a participant id."
        )
        try writeJSON(
            request,
            to: relay.requestsDirectoryURL().appendingPathComponent("request-2.json")
        )

        let records = try await relay.scanPendingRequests()

        #expect(records.isEmpty)
        let failedFile = relay.failedDirectoryURL().appendingPathComponent("request-2.json")
        #expect(FileManager.default.fileExists(atPath: failedFile.path))
    }

    @Test
    func recordConversationReplyWritesReplyFile() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let relay = DeviceActionRelay(
            paths: paths,
            config: DeviceActionRelayConfig(
                enabled: true,
                notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox"
            ),
            publisher: RecordingDeviceActionPublisher(),
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()

        let reply = AgentConversationPrompt(
            id: "ticket-1::conversation-1::2026-05-02T12:30:00Z",
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
            receivedAt: "2026-05-02T12:30:00Z"
        )

        try await relay.recordConversationReply(reply)

        let replyFile = relay.repliesDirectoryURL().appendingPathComponent("ticket-1--conversation-1--2026-05-02T12-30-00Z.json")
        #expect(FileManager.default.fileExists(atPath: replyFile.path))
    }

    @Test
    func recordConversationReplyRoutesCodexStartPromptToCodexQueue() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let relay = DeviceActionRelay(
            paths: paths,
            config: DeviceActionRelayConfig(
                enabled: true,
                notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox"
            ),
            publisher: RecordingDeviceActionPublisher(),
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()

        let prompt = AgentConversationPrompt(
            id: "codex-request-1",
            requestId: "codex-request-1",
            conversationId: "conversation-codex-1",
            jobId: "job-codex-1",
            participantId: "participant-phone",
            deviceId: "device-phone",
            ticketId: "ticket-codex-1",
            requiredActionKey: CodexPromptQueueContract.requiredActionKey,
            title: "Start Codex",
            message: "Start a coding prompt from the phone.",
            purpose: "purpose://operate-local-haven-agent",
            interests: ["codex", "automation"],
            workspacePath: "/tmp/haven",
            preferredAssistant: "codex",
            prompt: "Run the next safe test."
        )

        try await relay.recordConversationReply(prompt)

        let queue = CodexPromptQueue(paths: paths)
        let queued = queue.queuedRecords()
        #expect(queued.count == 1)
        #expect(queued.first?.request.id == "codex-request-1")
        #expect(queued.first?.request.prompt == "Run the next safe test.")
        #expect(queued.first?.request.purpose == "purpose://operate-local-haven-agent")
        #expect(queued.first?.request.interests == ["codex", "automation"])

        let replyFile = relay.repliesDirectoryURL().appendingPathComponent("codex-request-1.json")
        #expect(FileManager.default.fileExists(atPath: replyFile.path) == false)
    }

    private func makeTemporaryRoot() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentD-DeviceRelay-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private func writeJSON<T: Encodable>(_ value: T, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try encoder.encode(value).write(to: fileURL, options: [.atomic])
    }
}
