import Foundation
import CryptoKit
import HavenAgentCellRuntime
import HavenMacAutomation
import SproutCrypto
import Testing
@testable import HavenAgentDMCP
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

struct HavenAgentMCPServiceTests {
    @Test
    func mailComposeDraftToolForwardsToRunningAgentControlBridge() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let bridgePort = try Self.allocateLoopbackPort()
        let configURL = try writeConfig(
            paths: paths,
            configure: { config in
                config.localControlBridge = LocalControlBridgeConfig(
                    host: "127.0.0.1",
                    port: bridgePort,
                    accessToken: "mcp-mail-token"
                )
            }
        )
        let host = AgentCellRuntimeHost(paths: paths)
        _ = try await host.start(
            instanceName: "agent",
            configURL: configURL,
            controlBridge: AgentConfig.load(from: configURL).localControlBridge,
            mailDraftCommandHandler: { request in
                #expect(request.to == "kjetilh@mac.com")
                #expect(request.subject == "HAVENAgentD test")
                #expect(request.body == "Forwarded by MCP")
                return AgentMailDraftCommandResult(
                    status: "draft_created",
                    actionID: AgentMailDraftAutomation.actionID,
                    deliveryMode: "visible_mail_app_draft",
                    message: "forwarded"
                )
            }
        )
        defer {
            Task { await host.stop() }
        }

        let service = HavenAgentMCPService(paths: paths, configURL: configURL)
        let output = await service.callTool(
            name: "agent.mail.compose_draft",
            arguments: [
                "to": "kjetilh@mac.com",
                "subject": "HAVENAgentD test",
                "body": "Forwarded by MCP"
            ]
        )

        #expect(output.isError == false)
        let structured = try #require(output.structuredContent)
        #expect(structured["status"] as? String == "draft_created")
        #expect(structured["actionID"] as? String == AgentMailDraftAutomation.actionID)
        #expect(structured["deliveryMode"] as? String == "visible_mail_app_draft")
    }

    @Test
    func identitySignStatementToolForwardsToRunningAgentControlBridge() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let bridgePort = try Self.allocateLoopbackPort()
        let configURL = try writeConfig(
            paths: paths,
            configure: { config in
                config.localControlBridge = LocalControlBridgeConfig(
                    host: "127.0.0.1",
                    port: bridgePort,
                    accessToken: "mcp-sign-token"
                )
            }
        )
        let host = AgentCellRuntimeHost(paths: paths)
        _ = try await host.start(
            instanceName: "agent",
            configURL: configURL,
            controlBridge: AgentConfig.load(from: configURL).localControlBridge,
            signStatementCommandHandler: { request in
                #expect(request.purposeRef == AgentSignatureStatement.purposeRef)
                #expect(request.payloadSHA256Base64URL == Base64URL.encode(Data(SHA256.hash(data: Data("Forwarded by MCP".utf8)))))
                #expect(request.audience.entityRef == "entity:victoria")
                #expect(request.audience.publicKeyFingerprint == "sha256:victoria-key")
                #expect(request.nonce == "mcp-sign-nonce-12345")
                return Self.stubSignedStatementResult(request: request)
            }
        )
        defer {
            Task { await host.stop() }
        }

        let service = HavenAgentMCPService(paths: paths, configURL: configURL)
        let output = await service.callTool(
            name: "agent.identity.sign_statement",
            arguments: [
                "payloadSHA256Base64URL": Base64URL.encode(Data(SHA256.hash(data: Data("Forwarded by MCP".utf8)))),
                "payloadMediaType": "text/plain",
                "payloadDescription": "MCP forwarding test",
                "audience": [
                    "entityRef": "entity:victoria",
                    "publicKeyFingerprint": "sha256:victoria-key"
                ],
                "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3_600)),
                "nonce": "mcp-sign-nonce-12345"
            ]
        )

        #expect(output.isError == false)
        let structured = try #require(output.structuredContent)
        #expect(structured["status"] as? String == "signed_statement_created")
        #expect(structured["actionID"] as? String == "identity.sign-statement")
        #expect(structured["deliveryMode"] as? String == "detached_signed_statement")
    }

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
    func waitForReplyPullsRemoteOwnerInboxWhenLocalReplyIsMissing() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let configURL = try writeConfig(
            paths: paths,
            configure: { config in
                config.deviceActionRelay = DeviceActionRelayConfig(
                    enabled: true,
                    notificationOutboxEndpoint: "https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action",
                    defaultParticipantID: "participant-phone",
                    defaultDeviceID: "device-phone"
                )
            }
        )
        let remoteReply = AgentConversationPrompt(
            id: "remote-reply-1",
            requestId: "remote-request-1",
            conversationId: "remote-conversation-1",
            jobId: "remote-job-1",
            participantId: "participant-phone",
            deviceId: "device-phone",
            ticketId: "remote-ticket-1",
            requiredActionKey: AgentConversationFlowContract.requiredActionKey,
            title: "Remote reply",
            message: "Pulled from owner inbox",
            responseKind: "prompt",
            decision: nil,
            note: nil,
            prompt: "Run the next focused verification step.",
            receivedAt: "2026-05-05T10:00:02Z"
        )
        let service = HavenAgentMCPService(
            paths: paths,
            configURL: configURL,
            remoteReplyPuller: { relay, filter in
                #expect(relay.conversationRepliesEndpoint == "https://staging.haven.digipomps.org/conference-mvp/api/agent/conversation-replies")
                #expect(filter.requestId == "remote-request-1")
                #expect(filter.status == "prompt_received")
                return remoteReply
            }
        )

        let output = await service.callTool(
            name: "agent.operator.wait_for_reply",
            arguments: [
                "requestId": "remote-request-1",
                "timeoutSeconds": 0
            ]
        )

        #expect(output.isError == false)
        let structured = try #require(output.structuredContent)
        #expect((structured["matched"] as? Bool) == true)
        #expect((structured["timedOut"] as? Bool) == false)
        #expect(structured["source"] as? String == "remoteOwnerInboxPull")
        let reply = try #require(structured["reply"] as? [String: Any])
        #expect(reply["requestId"] as? String == "remote-request-1")
        #expect(reply["prompt"] as? String == "Run the next focused verification step.")
        let replyFilePath = try #require(structured["replyFilePath"] as? String)
        #expect(FileManager.default.fileExists(atPath: replyFilePath))
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
    func operatorRequestAcceptsRouteAndDeliveryGoalFields() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let configURL = try writeConfig(paths: paths)
        let service = HavenAgentMCPService(paths: paths, configURL: configURL)

        let output = await service.callTool(
            name: "agent.operator.request",
            arguments: [
                "responseMode": "prompt",
                "title": "Need next prompt",
                "message": "Svar med neste trygge steg.",
                "participantId": "binding-participant",
                "deviceId": "iphone-primary",
                "requiredActionKey": AgentConversationFlowContract.requiredActionKey,
                "sourceCellEndpoint": "cell://staging.haven.digipomps.org/AgentConversationInbox",
                "ttlSeconds": 120,
                "deliveryGoal": [
                    "goalID": "goal-reach-user-test",
                    "reachPurposeRef": DeviceActionDeliveryPurposes.reachUser,
                    "responsePurposeRef": DeviceActionDeliveryPurposes.obtainUserResponse,
                    "diagnosticPurposeRef": DeviceActionDeliveryPurposes.diagnoseDeliveryRoute,
                    "repairPurposeRef": DeviceActionDeliveryPurposes.repairBridgeUptime,
                    "requiredOutcome": "user_response_received",
                    "successSignal": "reply file written",
                    "failureSignal": "timeout without reply",
                    "timeoutSeconds": 120,
                    "fallbackAfterSeconds": 30,
                    "maxRouteAttempts": 4,
                    "routePolicy": "prefer-phone-then-local-agent",
                    "routeHints": [
                        [
                            "routeID": "iphone-primary",
                            "kind": "device_owner_route",
                            "participantId": "binding-participant",
                            "deviceId": "iphone-primary",
                            "priority": 0,
                            "reason": "preferred phone"
                        ],
                        [
                            "routeID": "mac-agent",
                            "kind": "local_agent_bridge",
                            "endpoint": "cell://staging.haven.digipomps.org/AgentConversationInbox",
                            "priority": 10,
                            "reason": "fallback local bridge"
                        ]
                    ]
                ],
                "payload": [
                    "source": "mcp-test"
                ]
            ]
        )

        #expect(output.isError == false)
        let structured = try #require(output.structuredContent)
        let requestFilePath = try #require(structured["requestFilePath"] as? String)
        let requestData = try Data(contentsOf: URL(fileURLWithPath: requestFilePath))
        let request = try JSONDecoder().decode(DeviceActionRequest.self, from: requestData)

        #expect(request.participantId == "binding-participant")
        #expect(request.deviceId == "iphone-primary")
        #expect(request.requiredActionKey == AgentConversationFlowContract.requiredActionKey)
        #expect(request.sourceCellEndpoint == "cell://staging.haven.digipomps.org/AgentConversationInbox")
        #expect(request.ttlSeconds == 120)
        #expect(request.deliveryGoal?.goalID == "goal-reach-user-test")
        #expect(request.deliveryGoal?.reachPurposeRef == DeviceActionDeliveryPurposes.reachUser)
        #expect(request.deliveryGoal?.responsePurposeRef == DeviceActionDeliveryPurposes.obtainUserResponse)
        #expect(request.deliveryGoal?.diagnosticPurposeRef == DeviceActionDeliveryPurposes.diagnoseDeliveryRoute)
        #expect(request.deliveryGoal?.repairPurposeRef == DeviceActionDeliveryPurposes.repairBridgeUptime)
        #expect(request.deliveryGoal?.routeHints.map(\.kind) == ["device_owner_route", "local_agent_bridge"])
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

    private func writeConfig(
        paths: RuntimePaths,
        configure: ((inout AgentConfig) -> Void)? = nil
    ) throws -> URL {
        var config = AgentConfig.example(paths: paths)
        config.deviceActionRelay = DeviceActionRelayConfig(
            enabled: true,
            notificationOutboxEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox",
            defaultParticipantID: "participant-phone",
            defaultDeviceID: "device-phone"
        )
        configure?(&config)

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

    private static func stubSignedStatementResult(request: AgentSignStatementRequest) -> AgentSignStatementResult {
        let signed = AgentSignedStatementSigningPayload(
            purposeRef: request.purposeRef,
            signerIdentity: AgentSignedStatementSignerIdentity(
                identityUUID: "agent-identity",
                displayName: "HAVEN Agent (agent)",
                didKey: "did:key:test-agent",
                domain: "haven.agent.owner.agent",
                publicKeyBase64URL: "agent-public-key"
            ),
            audience: request.audience,
            payload: AgentSignedStatementPayloadDescriptor(
                encoding: "detached-sha256",
                sha256Base64URL: request.payloadSHA256Base64URL ?? "payload-hash",
                mediaType: request.payloadMediaType,
                description: request.payloadDescription
            ),
            issuedAt: ISO8601DateFormatter().string(from: Date()),
            expiresAt: request.expiresAt,
            nonce: request.nonce,
            correlationID: request.correlationID
        )
        let envelope = AgentSignedStatementEnvelope(
            signed: signed,
            signatureBase64URL: "signature",
            signingInputSHA256Base64URL: "signing-input-hash"
        )
        return AgentSignStatementResult(
            status: "signed_statement_created",
            actionID: "identity.sign-statement",
            deliveryMode: "detached_signed_statement",
            envelope: envelope,
            message: "forwarded"
        )
    }

    private static func allocateLoopbackPort() throws -> Int {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        #expect(descriptor >= 0)
        defer { close(descriptor) }

        var value: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        #expect(bindResult == 0)

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &length)
            }
        }
        #expect(nameResult == 0)
        return Int(UInt16(bigEndian: boundAddress.sin_port))
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
