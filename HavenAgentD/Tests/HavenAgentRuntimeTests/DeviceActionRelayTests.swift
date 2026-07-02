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

private struct ThrowingDeviceActionPublisher: DeviceActionPublishing {
    enum PublishError: Error, LocalizedError {
        case timedOut

        var errorDescription: String? {
            "Simulated publish timed out."
        }
    }

    func publish(_ action: PublishedDeviceAction, requester: Identity) async throws -> DeviceActionPublishReceipt {
        throw PublishError.timedOut
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
        #expect(published.first?.deliveryGoal?.reachPurposeRef == DeviceActionDeliveryPurposes.reachUser)
        #expect(published.first?.deliveryGoal?.responsePurposeRef == DeviceActionDeliveryPurposes.obtainUserResponse)
        #expect(published.first?.deliveryGoal?.diagnosticPurposeRef == DeviceActionDeliveryPurposes.diagnoseDeliveryRoute)
        #expect(published.first?.deliveryGoal?.repairPurposeRef == DeviceActionDeliveryPurposes.repairBridgeUptime)
        #expect(published.first?.deliveryGoal?.routeHints.map(\.kind).contains("alternate_owner_device") == true)
        if case let .object(deliveryGoalObject)? = published.first?.payload["deliveryGoal"] {
            #expect(deliveryGoalObject["requiredOutcome"] == .string("user_response_received"))
            #expect(deliveryGoalObject["reachPurposeRef"] == .string(DeviceActionDeliveryPurposes.reachUser))
        } else {
            Issue.record("Expected deliveryGoal object in published payload")
        }

        let processedFile = relay.processedDirectoryURL().appendingPathComponent("request-1.json")
        let processingFile = paths.inboxDirectory
            .appendingPathComponent("Processing", isDirectory: true)
            .appendingPathComponent("request-1.json")
        #expect(FileManager.default.fileExists(atPath: processedFile.path))
        #expect(FileManager.default.fileExists(atPath: processingFile.path) == false)
        #expect(FileManager.default.fileExists(atPath: relay.requestsDirectoryURL().appendingPathComponent("request-1.json").path) == false)
    }

    @Test
    func scanPendingRequestsPrunesProcessedArchiveToConfiguredLimit() async throws {
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
                maxArchivedFilesPerDirectory: 2
            ),
            publisher: publisher,
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()
        for index in 0..<3 {
            let request = DeviceActionRequest(
                id: "request-\(index)",
                responseMode: .prompt,
                title: "Prompt \(index)",
                message: "Prompt body \(index)"
            )
            try writeJSON(
                request,
                to: relay.requestsDirectoryURL().appendingPathComponent("request-\(index).json")
            )
        }

        let records = try await relay.scanPendingRequests()
        let processedFiles = try archiveFileNames(in: relay.processedDirectoryURL())

        #expect(records.count == 3)
        #expect(processedFiles == ["request-1.json", "request-2.json"])
        #expect(FileManager.default.fileExists(atPath: relay.processedDirectoryURL().appendingPathComponent("request-0.json").path) == false)
    }

    @Test
    func concurrentScansClaimRequestBeforePublishing() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let publisher = RecordingDeviceActionPublisher()
        let config = DeviceActionRelayConfig(
            enabled: true,
            notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox",
            defaultParticipantID: "participant-phone",
            defaultDeviceID: "device-phone"
        )
        let requesterProvider: @Sendable () async throws -> Identity = {
            Identity("test-requester", displayName: "Test Requester", identityVault: nil)
        }
        let relayA = DeviceActionRelay(
            paths: paths,
            config: config,
            publisher: publisher,
            requesterProvider: requesterProvider
        )
        let relayB = DeviceActionRelay(
            paths: paths,
            config: config,
            publisher: publisher,
            requesterProvider: requesterProvider
        )

        try await relayA.bootstrap()

        let request = DeviceActionRequest(
            id: "request-race",
            responseMode: .prompt,
            title: "Continue coding",
            message: "Write the next prompt.",
            conversationId: "conversation-race",
            jobId: "job-race"
        )
        try writeJSON(
            request,
            to: relayA.requestsDirectoryURL().appendingPathComponent("request-race.json")
        )

        async let first = relayA.scanPendingRequests()
        async let second = relayB.scanPendingRequests()
        let records = try await first + second
        let published = await publisher.snapshot()

        #expect(records.count == 1)
        #expect(published.count == 1)
        #expect(published.first?.id == "request-race")
        #expect(FileManager.default.fileExists(atPath: relayA.processedDirectoryURL().appendingPathComponent("request-race.json").path))
        #expect(FileManager.default.fileExists(atPath: relayA.failedDirectoryURL().appendingPathComponent("request-race.json").path) == false)
    }

    @Test
    func scanPendingRequestsRecoversStaleProcessingClaim() async throws {
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
                processingClaimTimeoutSeconds: 30
            ),
            publisher: publisher,
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()
        let processingFile = processingDirectoryURL(paths: paths).appendingPathComponent("request-stale.json")
        try writeJSON(
            DeviceActionRequest(
                id: "request-stale",
                responseMode: .prompt,
                title: "Recovered request",
                message: "Retry this stale claim."
            ),
            to: processingFile
        )
        try markFileStale(processingFile)

        let records = try await relay.scanPendingRequests()
        let published = await publisher.snapshot()

        #expect(records.count == 1)
        #expect(published.map(\.id) == ["request-stale"])
        #expect(FileManager.default.fileExists(atPath: processingFile.path) == false)
        #expect(FileManager.default.fileExists(atPath: relay.requestsDirectoryURL().appendingPathComponent("request-stale.json").path) == false)
        #expect(FileManager.default.fileExists(atPath: relay.processedDirectoryURL().appendingPathComponent("request-stale.json").path))
    }

    @Test
    func scanPendingRequestsLeavesFreshProcessingClaimAlone() async throws {
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
                processingClaimTimeoutSeconds: 30
            ),
            publisher: publisher,
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()
        let processingFile = processingDirectoryURL(paths: paths).appendingPathComponent("request-fresh.json")
        try writeJSON(
            DeviceActionRequest(
                id: "request-fresh",
                responseMode: .prompt,
                title: "Fresh request",
                message: "Another scanner is still processing this."
            ),
            to: processingFile
        )

        let records = try await relay.scanPendingRequests()
        let published = await publisher.snapshot()

        #expect(records.isEmpty)
        #expect(published.isEmpty)
        #expect(FileManager.default.fileExists(atPath: processingFile.path))
        #expect(FileManager.default.fileExists(atPath: relay.processedDirectoryURL().appendingPathComponent("request-fresh.json").path) == false)
    }

    @Test
    func scanPendingRequestsArchivesStaleProcessingClaimWhenPendingFileExists() async throws {
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
                processingClaimTimeoutSeconds: 30
            ),
            publisher: publisher,
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()
        let pendingFile = relay.requestsDirectoryURL().appendingPathComponent("request-duplicate.json")
        let processingFile = processingDirectoryURL(paths: paths).appendingPathComponent("request-duplicate.json")
        try writeJSON(
            DeviceActionRequest(
                id: "request-duplicate",
                responseMode: .prompt,
                title: "Pending request",
                message: "Process this pending copy."
            ),
            to: pendingFile
        )
        try writeJSON(
            DeviceActionRequest(
                id: "request-duplicate-stale",
                responseMode: .prompt,
                title: "Stale duplicate",
                message: "Archive this stale processing copy."
            ),
            to: processingFile
        )
        try markFileStale(processingFile)

        let records = try await relay.scanPendingRequests()
        let published = await publisher.snapshot()

        #expect(records.count == 1)
        #expect(published.map(\.id) == ["request-duplicate"])
        #expect(FileManager.default.fileExists(atPath: processingFile.path) == false)
        #expect(FileManager.default.fileExists(atPath: relay.failedDirectoryURL().appendingPathComponent("stale-processing-request-duplicate.json").path))
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
        let failedData = try Data(contentsOf: failedFile)
        let failure = try JSONDecoder().decode(DeviceActionFailureRecord.self, from: failedData)
        #expect(failure.deliveryGoal == nil)
        #expect(failure.diagnosticPurposeRefs == [
            DeviceActionDeliveryPurposes.diagnoseDeliveryRoute,
            DeviceActionDeliveryPurposes.repairBridgeUptime
        ])
        #expect(failure.suggestedNextActions.contains { $0.contains(DeviceActionDeliveryPurposes.diagnoseDeliveryRoute) })
    }

    @Test
    func scanPendingRequestsWritesDeliveryGoalDiagnosticsWhenPublishFails() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let relay = DeviceActionRelay(
            paths: paths,
            config: DeviceActionRelayConfig(
                enabled: true,
                notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox",
                defaultParticipantID: "participant-phone",
                defaultDeviceID: "device-phone"
            ),
            publisher: ThrowingDeviceActionPublisher(),
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()

        let request = DeviceActionRequest(
            id: "request-publish-timeout",
            responseMode: .approval,
            title: "Reach the owner",
            message: "Approval request for fallback diagnostics.",
            conversationId: "conversation-timeout",
            jobId: "job-timeout",
            ttlSeconds: 120
        )
        try writeJSON(
            request,
            to: relay.requestsDirectoryURL().appendingPathComponent("request-publish-timeout.json")
        )

        let records = try await relay.scanPendingRequests()

        #expect(records.isEmpty)
        let failedFile = relay.failedDirectoryURL().appendingPathComponent("request-publish-timeout.json")
        let failure = try JSONDecoder().decode(
            DeviceActionFailureRecord.self,
            from: Data(contentsOf: failedFile)
        )
        #expect(failure.deliveryGoal?.reachPurposeRef == DeviceActionDeliveryPurposes.reachUser)
        #expect(failure.deliveryGoal?.responsePurposeRef == DeviceActionDeliveryPurposes.obtainUserResponse)
        #expect(failure.deliveryGoal?.routeHints.map(\.kind).contains("alternate_owner_device") == true)
        #expect(failure.suggestedNextActions.contains { $0.contains("alternate owner") || $0.contains("alternate owner-scoped route") })
        #expect(failure.suggestedNextActions.contains { $0.contains(DeviceActionDeliveryPurposes.repairBridgeUptime) })
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
    func recordConversationReplyPrunesReplyArchiveToConfiguredLimit() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let relay = DeviceActionRelay(
            paths: paths,
            config: DeviceActionRelayConfig(
                enabled: true,
                notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox",
                maxArchivedFilesPerDirectory: 2
            ),
            publisher: RecordingDeviceActionPublisher(),
            requesterProvider: { Identity("test-requester", displayName: "Test Requester", identityVault: nil) }
        )

        try await relay.bootstrap()
        for index in 0..<3 {
            let reply = AgentConversationPrompt(
                id: "reply-\(index)",
                conversationId: "conversation-\(index)",
                participantId: "participant-phone",
                requiredActionKey: DeviceActionRequest.approvalActionKey,
                title: "Reply \(index)",
                message: "Reply body \(index)",
                responseKind: "decision",
                decision: "approved",
                prompt: "Approved"
            )
            try await relay.recordConversationReply(reply)
        }

        let replyFiles = try archiveFileNames(in: relay.repliesDirectoryURL())
        #expect(replyFiles == ["reply-1.json", "reply-2.json"])
        #expect(FileManager.default.fileExists(atPath: relay.repliesDirectoryURL().appendingPathComponent("reply-0.json").path) == false)
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

    @Test
    func relayConfigDecodesAgentRelayTokenPath() throws {
        let data = Data(
            """
            {
              "enabled": true,
              "notificationOutboxEndpoint": "https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action",
              "defaultParticipantID": "binding-participant",
              "agentRelayTokenPath": "/Users/kjetil/Library/Application Support/HAVENAgent/Secrets/agent-relay-token"
            }
            """.utf8
        )

        let config = try JSONDecoder().decode(DeviceActionRelayConfig.self, from: data)

        #expect(config.enabled)
        #expect(config.notificationOutboxEndpoint == "https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action")
        #expect(config.defaultParticipantID == "binding-participant")
        #expect(config.agentRelayTokenPath == "/Users/kjetil/Library/Application Support/HAVENAgent/Secrets/agent-relay-token")
    }

    @Test
    func relayConfigDerivesConversationRepliesEndpointFromHTTPDeviceActionEndpoint() throws {
        let config = DeviceActionRelayConfig(
            enabled: true,
            notificationOutboxEndpoint: "https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action"
        )

        #expect(config.conversationRepliesEndpoint == "https://staging.haven.digipomps.org/conference-mvp/api/agent/conversation-replies")
    }

    @Test
    func replyPullClientParsesRemoteRecordWithSamePromptContractAsFlow() throws {
        let prompt = try #require(AgentConversationReplyPullClient.prompt(from: [
            "id": .string("conversation-1::job-1"),
            "requestId": .string("request-1"),
            "conversationId": .string("conversation-1"),
            "jobId": .string("job-1"),
            "participantId": .string("binding-participant"),
            "deviceId": .string("iphone-1"),
            "ticketId": .string("ticket-1"),
            "requiredActionKey": .string(AgentConversationFlowContract.requiredActionKey),
            "title": .string("Agenten venter"),
            "message": .string("Svar med neste steg."),
            "responseKind": .string("prompt"),
            "purpose": .string("purpose://obtain-user-response"),
            "interests": .array([.string("binding"), .string("apns")]),
            "prompt": .string("Fortsett med E2E-testen."),
            "status": .string("prompt_received"),
            "updatedAt": .number(1_780_000_000)
        ]))

        #expect(prompt.id == "conversation-1::job-1")
        #expect(prompt.requestId == "request-1")
        #expect(prompt.conversationId == "conversation-1")
        #expect(prompt.jobId == "job-1")
        #expect(prompt.ticketId == "ticket-1")
        #expect(prompt.requiredActionKey == AgentConversationFlowContract.requiredActionKey)
        #expect(prompt.purpose == "purpose://obtain-user-response")
        #expect(prompt.interests == ["binding", "apns"])
        #expect(prompt.prompt == "Fortsett med E2E-testen.")
    }

    @Test
    func httpPublisherReadsRelayTokenFromEnvironmentOrFile() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let tokenFile = root.appendingPathComponent("agent-relay-token")
        try " file-token-value \n".write(to: tokenFile, atomically: true, encoding: .utf8)

        #expect(
            NotificationOutboxDeviceActionPublisher.agentRelayToken(
                environment: [:],
                tokenFilePath: tokenFile.path
            ) == "file-token-value"
        )
        #expect(
            NotificationOutboxDeviceActionPublisher.agentRelayToken(
                environment: ["HAVEN_AGENT_RELAY_TOKEN": " env-token-value "],
                tokenFilePath: tokenFile.path
            ) == "env-token-value"
        )
        #expect(
            NotificationOutboxDeviceActionPublisher.agentRelayToken(
                environment: ["AGENT_NOTIFICATION_RELAY_TOKEN": " legacy-token-value "],
                tokenFilePath: nil
            ) == "legacy-token-value"
        )
        #expect(
            NotificationOutboxDeviceActionPublisher.agentRelayToken(
                environment: [:],
                tokenFilePath: root.appendingPathComponent("missing").path
            ) == nil
        )
    }

    @Test
    func codexPromptQueuePrunesCompletedArchiveToConfiguredLimit() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let queue = CodexPromptQueue(paths: paths, maxCompletedRecords: 2)

        for index in 0..<3 {
            try queue.enqueue(
                CodexPromptRequest(
                    id: "codex-\(index)",
                    conversationId: "conversation-\(index)",
                    prompt: "Run task \(index)",
                    createdAt: "2026-05-02T12:0\(index):00Z",
                    updatedAt: "2026-05-02T12:0\(index):00Z"
                )
            )
            try queue.markCompleted(id: "codex-\(index)", status: .done, summary: "Done \(index)")
        }

        let completed = queue.completedRecords()
        #expect(completed.map(\.request.id) == ["codex-1", "codex-2"])
        #expect(FileManager.default.fileExists(atPath: queue.completedDirectoryURL().appendingPathComponent("codex-0.json").path) == false)
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

    private func processingDirectoryURL(paths: RuntimePaths) -> URL {
        paths.inboxDirectory.appendingPathComponent("Processing", isDirectory: true)
    }

    private func markFileStale(_ fileURL: URL) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -120)],
            ofItemAtPath: fileURL.path
        )
    }

    private func archiveFileNames(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .map(\.lastPathComponent)
        .sorted()
    }
}
