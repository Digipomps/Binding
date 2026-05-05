import Foundation
import HavenAgentCellRuntime
import HavenAgentRuntime
import HavenRuntimeBootstrap

private struct MCPResourceDescriptor {
    let uri: String
    let name: String
    let title: String
    let description: String
    let mimeType: String

    func jsonObject() -> JSONObject {
        [
            "uri": uri,
            "name": name,
            "title": title,
            "description": description,
            "mimeType": mimeType
        ]
    }
}

private struct MCPToolDescriptor {
    let name: String
    let title: String
    let description: String
    let inputSchema: JSONObject

    func jsonObject() -> JSONObject {
        [
            "name": name,
            "title": title,
            "description": description,
            "inputSchema": inputSchema
        ]
    }
}

private struct StoredConversationReply {
    let fileURL: URL
    let reply: AgentConversationPrompt
}

private struct QueuedOperatorRequest {
    let requestID: String
    let responseMode: DeviceActionResponseMode
    let requestFilePath: String
    let conversationID: String
    let jobID: String

    func jsonObject() -> JSONObject {
        [
            "requestId": requestID,
            "responseMode": responseMode.rawValue,
            "status": "queued",
            "requestFilePath": requestFilePath,
            "conversationId": conversationID,
            "jobId": jobID
        ]
    }
}

enum HavenAgentMCPServiceError: Error, LocalizedError {
    case unknownResource(String)
    case invalidToolArguments(String)
    case relayDisabled
    case invalidResponseMode(String)
    case replyPayloadUnsupported(String)

    var errorDescription: String? {
        switch self {
        case .unknownResource(let uri):
            return "Unknown resource: \(uri)"
        case .invalidToolArguments(let message):
            return message
        case .relayDisabled:
            return "Device action relay is not enabled in the active agent config."
        case .invalidResponseMode(let value):
            return "Unsupported responseMode: \(value)"
        case .replyPayloadUnsupported(let key):
            return "Payload value for key '\(key)' is not a supported JSON type."
        }
    }
}

final class HavenAgentMCPService {
    private let paths: RuntimePaths
    private let configURL: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let docsDirectory: URL

    init(
        paths: RuntimePaths,
        configURL: URL,
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.configURL = configURL.standardizedFileURL
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.docsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs", isDirectory: true)
    }

    func listResources() -> [JSONObject] {
        resourceDescriptors.map { $0.jsonObject() }
    }

    func listTools() -> [JSONObject] {
        toolDescriptors.map { $0.jsonObject() }
    }

    func readResource(uri: String) async throws -> JSONObject {
        switch uri {
        case "haven-agent://runtime/state":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: await runtimeStateResource())
        case "haven-agent://runtime/bootstrap":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: await bootstrapResource())
        case "haven-agent://runtime/porthole":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: await portholeResource())
        case "haven-agent://identity/descriptor":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: await identityResource())
        case "haven-agent://review/queue":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: try await reviewQueueResource())
        case "haven-agent://review/audit":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: try await reviewAuditResource())
        case "haven-agent://bridge/status":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: await bridgeStatusResource())
        case "haven-agent://conversation/replies":
            return try makeResourceReadResult(uri: uri, mimeType: "application/json", object: conversationRepliesResource())
        case "haven-agent://docs/security-model":
            return try makeTextResourceReadResult(
                uri: uri,
                mimeType: "text/markdown",
                text: try readDoc(named: "SecurityModel.md")
            )
        case "haven-agent://docs/operator-runbook":
            return try makeTextResourceReadResult(
                uri: uri,
                mimeType: "text/markdown",
                text: try readDoc(named: "OperatorRunbook.md")
            )
        default:
            throw HavenAgentMCPServiceError.unknownResource(uri)
        }
    }

    func callTool(name: String, arguments: JSONObject) async -> MCPToolCallOutput {
        do {
            switch name {
            case "agent.state.refresh":
                let state = await runtimeStateResource()
                return MCPToolCallOutput(
                    structuredContent: state,
                    text: stateSummary(from: state),
                    isError: false
                )

            case "agent.config.validate":
                return try await validateConfigTool(arguments: arguments)

            case "agent.bootstrap.probe":
                return try await bootstrapProbeTool(arguments: arguments)

            case "agent.review.state":
                let summary = try await ReviewCommandService(paths: paths, configURL: configURL).state()
                let object = try jsonObject(from: summary)
                return MCPToolCallOutput(
                    structuredContent: object,
                    text: "Pending intents: \(summary.pendingCount). Audit entries: \(summary.auditCount).",
                    isError: false
                )

            case "agent.review.approve":
                return try await reviewMutationTool(arguments: arguments, action: .approve)

            case "agent.review.reject":
                return try await reviewMutationTool(arguments: arguments, action: .reject)

            case "agent.operator.request":
                return try operatorRequestTool(arguments: arguments)

            case "agent.operator.wait_for_reply":
                return try await waitForReplyTool(arguments: arguments)

            case "agent.operator.request_and_wait":
                return try await requestAndWaitTool(arguments: arguments)

            default:
                throw HavenAgentMCPServiceError.invalidToolArguments("Unknown tool: \(name)")
            }
        } catch {
            let text = error.localizedDescription
            return MCPToolCallOutput(
                structuredContent: ["ok": false, "error": text],
                text: text,
                isError: true
            )
        }
    }

    private var resourceDescriptors: [MCPResourceDescriptor] {
        [
            MCPResourceDescriptor(
                uri: "haven-agent://runtime/state",
                name: "runtime_state",
                title: "Runtime State",
                description: "Current high-level runtime snapshot for the local HAVEN agent.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://runtime/bootstrap",
                name: "runtime_bootstrap",
                title: "Bootstrap Status",
                description: "Latest bootstrap invocation summary and artifact metadata.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://runtime/porthole",
                name: "runtime_porthole",
                title: "Porthole Status",
                description: "Current native porthole ingress state and retry detail.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://identity/descriptor",
                name: "identity_descriptor",
                title: "Identity Descriptor",
                description: "Stable local agent identity plus pairing status.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://review/queue",
                name: "review_queue",
                title: "Review Queue",
                description: "Pending verified intents waiting for local review.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://review/audit",
                name: "review_audit",
                title: "Review Audit",
                description: "Intent review history and dispatch outcomes.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://bridge/status",
                name: "bridge_status",
                title: "Bridge Status",
                description: "Loopback control bridge status and allowlisted routes.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://conversation/replies",
                name: "conversation_replies",
                title: "Conversation Replies",
                description: "Latest prompt and approval replies returned through Binding.",
                mimeType: "application/json"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://docs/security-model",
                name: "security_model_doc",
                title: "Security Model",
                description: "Agent trust model and non-negotiable security constraints.",
                mimeType: "text/markdown"
            ),
            MCPResourceDescriptor(
                uri: "haven-agent://docs/operator-runbook",
                name: "operator_runbook_doc",
                title: "Operator Runbook",
                description: "Current setup, bootstrap, review, and launchd operator guidance.",
                mimeType: "text/markdown"
            )
        ]
    }

    private var toolDescriptors: [MCPToolDescriptor] {
        [
            MCPToolDescriptor(
                name: "agent.state.refresh",
                title: "Refresh Runtime State",
                description: "Read the latest persisted runtime state snapshot for the local HAVEN agent.",
                inputSchema: [
                    "type": "object",
                    "additionalProperties": false
                ]
            ),
            MCPToolDescriptor(
                name: "agent.config.validate",
                title: "Validate Config",
                description: "Validate the active HAVEN agent config and return effective runtime paths.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "includeEffectivePaths": [
                            "type": "boolean",
                            "default": true
                        ]
                    ],
                    "additionalProperties": false
                ]
            ),
            MCPToolDescriptor(
                name: "agent.bootstrap.probe",
                title: "Bootstrap Probe",
                description: "Run bootstrap preflight and optionally the real bootstrap path.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "runBootstrap": [
                            "type": "boolean",
                            "default": false
                        ]
                    ],
                    "additionalProperties": false
                ]
            ),
            MCPToolDescriptor(
                name: "agent.review.state",
                title: "Review State",
                description: "Return the current pending remote-intent queue and audit summary.",
                inputSchema: [
                    "type": "object",
                    "additionalProperties": false
                ]
            ),
            MCPToolDescriptor(
                name: "agent.review.approve",
                title: "Approve Intent",
                description: "Approve one verified pending remote intent using the existing review boundary.",
                inputSchema: reviewMutationSchema()
            ),
            MCPToolDescriptor(
                name: "agent.review.reject",
                title: "Reject Intent",
                description: "Reject one pending remote intent using the existing review boundary.",
                inputSchema: reviewMutationSchema()
            ),
            MCPToolDescriptor(
                name: "agent.operator.request",
                title: "Queue Operator Request",
                description: "Write a structured prompt or approval request for DeviceActionRelay to publish.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "responseMode": [
                            "type": "string",
                            "enum": ["prompt", "approval"]
                        ],
                        "title": [
                            "type": "string"
                        ],
                        "message": [
                            "type": "string"
                        ],
                        "purpose": [
                            "type": "string"
                        ],
                        "purposeDescription": [
                            "type": "string"
                        ],
                        "interests": [
                            "type": "array",
                            "items": [
                                "type": "string"
                            ]
                        ],
                        "conversationId": [
                            "type": "string"
                        ],
                        "jobId": [
                            "type": "string"
                        ],
                        "payload": [
                            "type": "object"
                        ]
                    ],
                    "required": ["responseMode", "title", "message"],
                    "additionalProperties": false
                ]
            ),
            MCPToolDescriptor(
                name: "agent.operator.wait_for_reply",
                title: "Wait For Operator Reply",
                description: "Wait for a matching prompt or approval reply to come back from Binding.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "requestId": [
                            "type": "string"
                        ],
                        "conversationId": [
                            "type": "string"
                        ],
                        "jobId": [
                            "type": "string"
                        ],
                        "ticketId": [
                            "type": "string"
                        ],
                        "timeoutSeconds": [
                            "type": "number",
                            "default": 300
                        ],
                        "pollIntervalSeconds": [
                            "type": "number",
                            "default": 2
                        ]
                    ],
                    "additionalProperties": false
                ]
            ),
            MCPToolDescriptor(
                name: "agent.operator.request_and_wait",
                title: "Request And Wait",
                description: "Queue an operator prompt or approval request and wait for the matching reply.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "responseMode": [
                            "type": "string",
                            "enum": ["prompt", "approval"]
                        ],
                        "title": [
                            "type": "string"
                        ],
                        "message": [
                            "type": "string"
                        ],
                        "purpose": [
                            "type": "string"
                        ],
                        "purposeDescription": [
                            "type": "string"
                        ],
                        "interests": [
                            "type": "array",
                            "items": [
                                "type": "string"
                            ]
                        ],
                        "conversationId": [
                            "type": "string"
                        ],
                        "jobId": [
                            "type": "string"
                        ],
                        "payload": [
                            "type": "object"
                        ],
                        "timeoutSeconds": [
                            "type": "number",
                            "default": 300
                        ],
                        "pollIntervalSeconds": [
                            "type": "number",
                            "default": 2
                        ]
                    ],
                    "required": ["responseMode", "title", "message"],
                    "additionalProperties": false
                ]
            )
        ]
    }

    private func reviewMutationSchema() -> JSONObject {
        [
            "type": "object",
            "properties": [
                "intentId": [
                    "type": "string"
                ],
                "reviewer": [
                    "type": "string"
                ],
                "note": [
                    "type": "string"
                ]
            ],
            "required": ["intentId"],
            "additionalProperties": false
        ]
    }

    private func validateConfigTool(arguments: JSONObject) async throws -> MCPToolCallOutput {
        let includeEffectivePaths = boolValue(arguments["includeEffectivePaths"]) ?? true
        let runtime = AgentRuntime(paths: paths)

        do {
            _ = try await runtime.validate(configURL: configURL)
            var object: JSONObject = [
                "ok": true,
                "configPath": configURL.path,
                "rootPath": paths.applicationSupportDirectory.path,
                "errors": []
            ]
            if includeEffectivePaths {
                object["effectivePaths"] = [
                    "agentDirectory": paths.agentDirectory.path,
                    "stateRoot": paths.stateDirectory.path,
                    "cellRuntimeFile": paths.cellRuntimeFile.path,
                    "remoteIntentStateFile": paths.remoteIntentStateFile.path,
                    "agentIdentityFile": paths.agentIdentityFile.path,
                    "pairingArtifactFile": paths.pairingArtifactFile.path
                ]
            }
            return MCPToolCallOutput(
                structuredContent: object,
                text: "Config OK: \(configURL.path)",
                isError: false
            )
        } catch {
            let object: JSONObject = [
                "ok": false,
                "configPath": configURL.path,
                "rootPath": paths.applicationSupportDirectory.path,
                "errors": [error.localizedDescription]
            ]
            return MCPToolCallOutput(
                structuredContent: object,
                text: error.localizedDescription,
                isError: true
            )
        }
    }

    private func bootstrapProbeTool(arguments: JSONObject) async throws -> MCPToolCallOutput {
        let runBootstrap = boolValue(arguments["runBootstrap"]) ?? false
        let report = await BootstrapProbeService(paths: paths).probe(
            configURL: configURL,
            runBootstrap: runBootstrap
        )
        let object = try jsonObject(from: report)
        let didFail = runBootstrap && (report.bootstrap?.succeeded == false)
        let text = report.bootstrap?.summary
            ?? "Bootstrap preflight readyForBootstrap=\(report.readyForBootstrap)"
        return MCPToolCallOutput(
            structuredContent: object,
            text: text,
            isError: didFail
        )
    }

    private enum ReviewMutationAction {
        case approve
        case reject
    }

    private func reviewMutationTool(
        arguments: JSONObject,
        action: ReviewMutationAction
    ) async throws -> MCPToolCallOutput {
        guard let intentID = stringValue(arguments["intentId"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !intentID.isEmpty else {
            throw HavenAgentMCPServiceError.invalidToolArguments("review mutation requires intentId")
        }
        let reviewer = stringValue(arguments["reviewer"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = stringValue(arguments["note"])?.trimmingCharacters(in: .whitespacesAndNewlines)

        let service = ReviewCommandService(paths: paths, configURL: configURL)
        let summary: ReviewCommandSummary
        switch action {
        case .approve:
            summary = try await service.approve(intentID: intentID, reviewer: reviewer ?? "mcp-operator", note: note)
        case .reject:
            summary = try await service.reject(intentID: intentID, reviewer: reviewer ?? "mcp-operator", note: note)
        }

        var object = try jsonObject(from: summary)
        object["intentId"] = intentID
        object["operation"] = action == .approve ? "approve" : "reject"
        let outcome = summary.lastOutcome ?? "unknown"
        return MCPToolCallOutput(
            structuredContent: object,
            text: "Intent \(intentID) processed with outcome \(outcome). Pending intents: \(summary.pendingCount).",
            isError: false
        )
    }

    private func operatorRequestTool(arguments: JSONObject) throws -> MCPToolCallOutput {
        let queuedRequest = try queueOperatorRequest(arguments: arguments)
        let object = queuedRequest.jsonObject()
        return MCPToolCallOutput(
            structuredContent: object,
            text: "Queued operator \(queuedRequest.responseMode.rawValue) request \(queuedRequest.requestID).",
            isError: false
        )
    }

    private func queueOperatorRequest(arguments: JSONObject) throws -> QueuedOperatorRequest {
        guard let relayConfig = try loadRelayConfig() else {
            throw HavenAgentMCPServiceError.relayDisabled
        }

        guard let responseModeRaw = stringValue(arguments["responseMode"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              let responseMode = DeviceActionResponseMode(rawValue: responseModeRaw) else {
            throw HavenAgentMCPServiceError.invalidResponseMode(stringValue(arguments["responseMode"]) ?? "nil")
        }
        guard let title = stringValue(arguments["title"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            throw HavenAgentMCPServiceError.invalidToolArguments("operator request requires title")
        }
        guard let message = stringValue(arguments["message"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            throw HavenAgentMCPServiceError.invalidToolArguments("operator request requires message")
        }

        let requestID = UUID().uuidString.lowercased()
        let conversationID = stringValue(arguments["conversationId"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? requestID
        let jobID = stringValue(arguments["jobId"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? requestID
        let interests = stringArrayValue(arguments["interests"]) ?? []
        let payload = try relayPayload(from: objectValue(arguments["payload"]) ?? [:])
        let request = DeviceActionRequest(
            id: requestID,
            responseMode: responseMode,
            title: title,
            message: message,
            purpose: stringValue(arguments["purpose"])?.trimmingCharacters(in: .whitespacesAndNewlines),
            purposeDescription: stringValue(arguments["purposeDescription"])?.trimmingCharacters(in: .whitespacesAndNewlines),
            interests: interests,
            conversationId: conversationID,
            jobId: jobID,
            payload: payload
        )

        let requestsDirectory = paths.inboxDirectory.appendingPathComponent(
            relayConfig.requestsDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: requestsDirectory, withIntermediateDirectories: true, attributes: nil)
        let requestFileURL = requestsDirectory.appendingPathComponent("\(requestID).json")
        let data = try encoder.encode(request)
        try data.write(to: requestFileURL, options: [.atomic])

        return QueuedOperatorRequest(
            requestID: requestID,
            responseMode: responseMode,
            requestFilePath: requestFileURL.path,
            conversationID: conversationID,
            jobID: jobID
        )
    }

    private func waitForReplyTool(arguments: JSONObject) async throws -> MCPToolCallOutput {
        let requestID = normalizedFilterValue(arguments["requestId"])
        let conversationID = normalizedFilterValue(arguments["conversationId"])
        let jobID = normalizedFilterValue(arguments["jobId"])
        let ticketID = normalizedFilterValue(arguments["ticketId"])

        guard requestID != nil || conversationID != nil || jobID != nil || ticketID != nil else {
            throw HavenAgentMCPServiceError.invalidToolArguments(
                "wait_for_reply requires at least one of requestId, conversationId, jobId, or ticketId"
            )
        }

        let timeoutSeconds = clampedSeconds(
            doubleValue(arguments["timeoutSeconds"]),
            defaultValue: 300,
            minimum: 0,
            maximum: 3600
        )
        let pollIntervalSeconds = clampedSeconds(
            doubleValue(arguments["pollIntervalSeconds"]),
            defaultValue: 2,
            minimum: 0.25,
            maximum: 30
        )

        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while true {
            let replies = conversationReplyRecords()
            if let match = latestMatchingReply(
                in: replies,
                requestID: requestID,
                conversationID: conversationID,
                jobID: jobID,
                ticketID: ticketID
            ) {
                let replyObject = try jsonObject(from: match.reply)
                let result: JSONObject = [
                    "matched": true,
                    "timedOut": false,
                    "replyFilePath": match.fileURL.path,
                    "reply": replyObject,
                    "requestId": (match.reply.requestId ?? requestID) as Any,
                    "conversationId": match.reply.conversationId,
                    "jobId": match.reply.jobId ?? NSNull(),
                    "ticketId": match.reply.ticketId ?? NSNull()
                ]
                return MCPToolCallOutput(
                    structuredContent: result,
                    text: replySummary(for: match.reply),
                    isError: false
                )
            }

            if timeoutSeconds == 0 || Date() >= deadline {
                let result: JSONObject = [
                    "matched": false,
                    "timedOut": true,
                    "requestId": requestID ?? NSNull(),
                    "conversationId": conversationID ?? NSNull(),
                    "jobId": jobID ?? NSNull(),
                    "ticketId": ticketID ?? NSNull(),
                    "timeoutSeconds": timeoutSeconds,
                    "pollIntervalSeconds": pollIntervalSeconds,
                    "reply": NSNull()
                ]
                let matchLabel = requestID ?? conversationID ?? jobID ?? ticketID ?? "unknown"
                return MCPToolCallOutput(
                    structuredContent: result,
                    text: "Timed out waiting for operator reply matching \(matchLabel).",
                    isError: true
                )
            }

            try await Task.sleep(nanoseconds: sleepNanoseconds(for: pollIntervalSeconds))
        }
    }

    private func requestAndWaitTool(arguments: JSONObject) async throws -> MCPToolCallOutput {
        let queuedRequest = try queueOperatorRequest(arguments: arguments)

        var waitArguments: JSONObject = [
            "requestId": queuedRequest.requestID,
            "conversationId": queuedRequest.conversationID,
            "jobId": queuedRequest.jobID
        ]
        if let timeoutSeconds = doubleValue(arguments["timeoutSeconds"]) {
            waitArguments["timeoutSeconds"] = timeoutSeconds
        }
        if let pollIntervalSeconds = doubleValue(arguments["pollIntervalSeconds"]) {
            waitArguments["pollIntervalSeconds"] = pollIntervalSeconds
        }

        let waitResult = try await waitForReplyTool(arguments: waitArguments)
        var object: JSONObject = [
            "queuedRequest": queuedRequest.jsonObject()
        ]
        if let structuredContent = waitResult.structuredContent {
            object["wait"] = structuredContent
            object["matched"] = structuredContent["matched"] ?? NSNull()
            object["timedOut"] = structuredContent["timedOut"] ?? NSNull()
            object["reply"] = structuredContent["reply"] ?? NSNull()
        }
        return MCPToolCallOutput(
            structuredContent: object,
            text: "Queued operator \(queuedRequest.responseMode.rawValue) request \(queuedRequest.requestID). \(waitResult.text)",
            isError: waitResult.isError
        )
    }

    private func runtimeStateResource() async -> JSONObject {
        let identity = await identityResource()
        let bridgeStatus = await bridgeStatusValue()

        guard let runtimeState = load(AgentRuntimeState.self, from: paths.stateFile) else {
            return [
                "status": "unavailable",
                "activeWatchIDs": [],
                "bootstrap": NSNull(),
                "porthole": NSNull(),
                "identity": identity,
                "controlBridge": bridgeStatus,
                "lastAction": NSNull(),
                "lastError": NSNull(),
                "lastEventSummary": NSNull(),
                "lastHeartbeatAt": NSNull()
            ]
        }

        return [
            "instanceName": runtimeState.instanceName,
            "status": runtimeState.status,
            "activeWatchIDs": runtimeState.activeWatchIDs,
            "bootstrap": codableValueOrNull(runtimeState.lastSproutBootstrap),
            "porthole": codableValueOrNull(runtimeState.portholeIngress),
            "identity": identity,
            "controlBridge": bridgeStatus,
            "lastAction": codableValueOrNull(runtimeState.lastExecutedAction),
            "lastError": runtimeState.lastError ?? NSNull(),
            "lastEventSummary": runtimeState.lastEventSummary ?? NSNull(),
            "lastHeartbeatAt": runtimeState.lastHeartbeatAt ?? NSNull(),
            "bootstrapPlan": codableValueOrNull(runtimeState.bootstrapPlan)
        ]
    }

    private func bootstrapResource() async -> JSONObject {
        guard let runtimeState = load(AgentRuntimeState.self, from: paths.stateFile),
              let record = runtimeState.lastSproutBootstrap,
              let object = try? jsonObject(from: record) else {
            return [
                "available": false
            ]
        }
        return object
    }

    private func portholeResource() async -> JSONObject {
        guard let runtimeState = load(AgentRuntimeState.self, from: paths.stateFile),
              let status = runtimeState.portholeIngress,
              let object = try? jsonObject(from: status) else {
            return [
                "available": false
            ]
        }
        return object
    }

    private func identityResource() async -> JSONObject {
        let pairing = pairedOperatorValue()
        guard let material = load(AgentIdentityMaterial.self, from: paths.agentIdentityFile),
              let object = try? jsonObject(from: material.descriptor) else {
            return [
                "available": false,
                "pairedOperator": pairing
            ]
        }

        var descriptor = object
        descriptor["pairedOperator"] = pairing
        return descriptor
    }

    private func bridgeStatusResource() async -> JSONObject {
        if let value = await bridgeStatusValue() as? JSONObject {
            return value
        }
        return [
            "available": false
        ]
    }

    private func bridgeStatusValue() async -> Any {
        guard let snapshot = load(AgentCellRuntimeSnapshot.self, from: paths.cellRuntimeFile),
              let controlBridge = snapshot.controlBridge,
              let object = try? jsonObject(from: controlBridge) else {
            return NSNull()
        }
        return object
    }

    private func reviewQueueResource() async throws -> JSONObject {
        let state = try await loadRemoteIntentState()
        let pending = state?.queuedIntents ?? []
        let pendingObjects = try pending.map(jsonObject(from:))
        return [
            "pendingCount": pending.count,
            "pending": pendingObjects
        ]
    }

    private func reviewAuditResource() async throws -> JSONObject {
        let state = try await loadRemoteIntentState()
        let audit = state?.auditTrail ?? []
        let auditObjects = try audit.map(jsonObject(from:))
        return [
            "auditCount": audit.count,
            "audit": auditObjects
        ]
    }

    private func conversationRepliesResource() -> JSONObject {
        let sortedReplies = conversationReplyRecords().map(\.reply)
        let replyObjects = (try? sortedReplies.map(jsonObject(from:))) ?? []
        return [
            "replyCount": sortedReplies.count,
            "replies": replyObjects
        ]
    }

    private func conversationReplyRecords() -> [StoredConversationReply] {
        let files = pendingReplyFiles()
        let replies: [StoredConversationReply] = files.compactMap { fileURL in
            guard let reply = load(AgentConversationPrompt.self, from: fileURL) else {
                return nil
            }
            return StoredConversationReply(fileURL: fileURL, reply: reply)
        }
        return replies.sorted {
            $0.reply.receivedAt.localizedStandardCompare($1.reply.receivedAt) == .orderedDescending
        }
    }

    private func latestMatchingReply(
        in replies: [StoredConversationReply],
        requestID: String?,
        conversationID: String?,
        jobID: String?,
        ticketID: String?
    ) -> StoredConversationReply? {
        replies.first { record in
            replyMatches(
                record.reply,
                requestID: requestID,
                conversationID: conversationID,
                jobID: jobID,
                ticketID: ticketID
            )
        }
    }

    private func replyMatches(
        _ reply: AgentConversationPrompt,
        requestID: String?,
        conversationID: String?,
        jobID: String?,
        ticketID: String?
    ) -> Bool {
        if let requestID, reply.requestId != requestID {
            return false
        }
        if let conversationID, reply.conversationId != conversationID {
            return false
        }
        if let jobID, reply.jobId != jobID {
            return false
        }
        if let ticketID, reply.ticketId != ticketID {
            return false
        }
        return true
    }

    private func pairedOperatorValue() -> Any {
        do {
            if let paired = try AgentPairingArtifactLoader.loadPairedOperator(from: paths.pairingArtifactFile),
               var object = try? jsonObject(from: paired) {
                object["status"] = "paired"
                return object
            }
            return [
                "status": "unpaired",
                "path": paths.pairingArtifactFile.path,
                "lastError": NSNull()
            ]
        } catch {
            return [
                "status": "invalid",
                "path": paths.pairingArtifactFile.path,
                "lastError": error.localizedDescription
            ]
        }
    }

    private func loadRelayConfig() throws -> DeviceActionRelayConfig? {
        let config = try AgentConfig.load(from: configURL)
        guard let relay = config.deviceActionRelay, relay.enabled else {
            return nil
        }
        return relay
    }

    private func relayPayload(from object: JSONObject) throws -> [String: RelayJSONValue] {
        var payload: [String: RelayJSONValue] = [:]
        for (key, value) in object {
            guard let relayValue = makeRelayJSONValue(from: value) else {
                throw HavenAgentMCPServiceError.replyPayloadUnsupported(key)
            }
            payload[key] = relayValue
        }
        return payload
    }

    private func loadRemoteIntentState() async throws -> PersistedRemoteIntentState? {
        try await RemoteIntentStateStore(fileURL: paths.remoteIntentStateFile).load()
    }

    private func pendingReplyFiles() -> [URL] {
        let repliesDirectoryName: String
        if let config = try? AgentConfig.load(from: configURL),
           let relay = config.deviceActionRelay {
            repliesDirectoryName = relay.repliesDirectoryName
        } else {
            repliesDirectoryName = DeviceActionRelayConfig().repliesDirectoryName
        }

        let repliesDirectory = paths.inboxDirectory.appendingPathComponent(repliesDirectoryName, isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: repliesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func normalizedFilterValue(_ value: Any?) -> String? {
        guard let rawValue = stringValue(value)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        return rawValue
    }

    private func clampedSeconds(
        _ value: Double?,
        defaultValue: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        let resolved = value ?? defaultValue
        return max(minimum, min(maximum, resolved))
    }

    private func sleepNanoseconds(for seconds: Double) -> UInt64 {
        UInt64((seconds * 1_000_000_000).rounded())
    }

    private func replySummary(for reply: AgentConversationPrompt) -> String {
        if let decision = reply.decision?.trimmingCharacters(in: .whitespacesAndNewlines),
           !decision.isEmpty {
            return "Received operator decision '\(decision)' for conversation \(reply.conversationId)."
        }
        return "Received operator reply for conversation \(reply.conversationId): \(reply.prompt)"
    }

    private func readDoc(named fileName: String) throws -> String {
        let fileURL = docsDirectory.appendingPathComponent(fileName)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func makeResourceReadResult(uri: String, mimeType: String, object: JSONObject) throws -> JSONObject {
        [
            "contents": [
                [
                    "uri": uri,
                    "mimeType": mimeType,
                    "text": try prettyJSONString(from: object)
                ]
            ]
        ]
    }

    private func makeTextResourceReadResult(uri: String, mimeType: String, text: String) throws -> JSONObject {
        [
            "contents": [
                [
                    "uri": uri,
                    "mimeType": mimeType,
                    "text": text
                ]
            ]
        ]
    }

    private func stateSummary(from state: JSONObject) -> String {
        let status = stringValue(state["status"]) ?? "unknown"
        let instanceName = stringValue(state["instanceName"]) ?? "unknown"
        return "Runtime state: \(status) for \(instanceName)."
    }

    private func makeRelayJSONValue(from value: Any) -> RelayJSONValue? {
        switch value {
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .number(Double(int))
        case let double as Double:
            return .number(double)
        case let float as Float:
            return .number(Double(float))
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        case let dictionary as JSONObject:
            var object: [String: RelayJSONValue] = [:]
            for (key, nestedValue) in dictionary {
                guard let relayValue = makeRelayJSONValue(from: nestedValue) else {
                    return nil
                }
                object[key] = relayValue
            }
            return .object(object)
        case let array as [Any]:
            let mapped = array.compactMap(makeRelayJSONValue(from:))
            guard mapped.count == array.count else {
                return nil
            }
            return .array(mapped)
        case is NSNull:
            return .null
        default:
            return nil
        }
    }

    private func codableValueOrNull<T: Encodable>(_ value: T?) -> Any {
        guard let value, let json = try? jsonValue(from: value) else {
            return NSNull()
        }
        return json
    }

    private func load<T: Decodable>(_ type: T.Type, from fileURL: URL) -> T? {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = fileManager.contents(atPath: fileURL.path) else {
            return nil
        }
        return try? decoder.decode(type, from: data)
    }
}
