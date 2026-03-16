import Foundation
import CellBase
import HavenAgentRuntime

public final class RemoteIntentReviewCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case version
    }

    public required init(owner: Identity) async {
        await super.init(owner: owner)
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let cell = UncheckedSendableReference(value: self)
        Task {
            let requester = Identity()
            let decodedOwner = (try? await cell.value.getOwner(requester: requester)) ?? requester
            await cell.value.setupPermissions(owner: decodedOwner)
            await cell.value.setupKeys(owner: decodedOwner)
        }
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "audit")
        agreementTemplate.addGrant("rw--", for: "approve")
        agreementTemplate.addGrant("rw--", for: "reject")
        agreementTemplate.addGrant("r---", for: "flow")
    }

    private func setupKeys(owner: Identity) async {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "state", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeStateValue()
        })

        await addInterceptForGet(requester: owner, key: "audit", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "audit", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeAuditValue()
        })

        await addInterceptForSet(requester: owner, key: "approve", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("rw--", at: "approve", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            do {
                let request = try self.parseReviewRequest(from: value, reviewer: requester.displayName)
                let intent = try await self.loadPendingIntent(intentID: request.intentID)
                let executor = try await self.loadExecutor()
                let executedAction = try await executor.execute(intent: intent)
                _ = await AgentRuntimeBridge.shared.removeQueuedIntent(id: request.intentID)
                let record = RemoteIntentAuditRecord(
                    intentID: intent.id,
                    actionID: intent.actionID,
                    issuerID: intent.issuerID,
                    verificationStatus: intent.verificationStatus,
                    outcome: .approvedDispatched,
                    reviewer: request.reviewer,
                    note: request.note,
                    recordedAt: executedAction.recordedAt,
                    executedAction: executedAction,
                    errorMessage: nil
                )
                await AgentRuntimeBridge.shared.appendRemoteIntentAuditRecord(record)
                await self.publishReviewEvent(record: record, requester: requester)
                return await self.makeStateValue()
            } catch {
                if let request = try? self.parseReviewRequest(from: value, reviewer: requester.displayName),
                   let intent = await AgentRuntimeBridge.shared.queuedIntent(id: request.intentID) {
                    let record = RemoteIntentAuditRecord(
                        intentID: intent.id,
                        actionID: intent.actionID,
                        issuerID: intent.issuerID,
                        verificationStatus: intent.verificationStatus,
                        outcome: .approvedFailed,
                        reviewer: request.reviewer,
                        note: request.note,
                        recordedAt: ISO8601DateFormatter().string(from: Date()),
                        executedAction: nil,
                        errorMessage: error.localizedDescription
                    )
                    await AgentRuntimeBridge.shared.appendRemoteIntentAuditRecord(record)
                    await self.publishReviewEvent(record: record, requester: requester)
                }
                return .string("error: \(error.localizedDescription)")
            }
        })

        await addInterceptForSet(requester: owner, key: "reject", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("rw--", at: "reject", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            do {
                let request = try self.parseReviewRequest(from: value, reviewer: requester.displayName)
                guard let intent = await AgentRuntimeBridge.shared.removeQueuedIntent(id: request.intentID) else {
                    throw ReviewError.intentNotFound(request.intentID)
                }
                let record = RemoteIntentAuditRecord(
                    intentID: intent.id,
                    actionID: intent.actionID,
                    issuerID: intent.issuerID,
                    verificationStatus: intent.verificationStatus,
                    outcome: .rejected,
                    reviewer: request.reviewer,
                    note: request.note,
                    recordedAt: ISO8601DateFormatter().string(from: Date()),
                    executedAction: nil,
                    errorMessage: nil
                )
                await AgentRuntimeBridge.shared.appendRemoteIntentAuditRecord(record)
                await self.publishReviewEvent(record: record, requester: requester)
                return await self.makeStateValue()
            } catch {
                return .string("error: \(error.localizedDescription)")
            }
        })
    }

    private func parseReviewRequest(from value: ValueType, reviewer defaultReviewer: String) throws -> ReviewRequest {
        guard case let .object(object) = value else {
            throw ReviewError.invalidRequest
        }
        guard case let .string(intentID)? = object["intentID"] else {
            throw ReviewError.invalidRequest
        }
        let note: String?
        if case let .string(value)? = object["note"] {
            note = value
        } else {
            note = nil
        }
        let reviewer: String
        if case let .string(value)? = object["reviewer"] {
            reviewer = value
        } else {
            reviewer = defaultReviewer
        }
        return ReviewRequest(intentID: intentID, reviewer: reviewer, note: note)
    }

    private func loadPendingIntent(intentID: String) async throws -> QueuedRemoteIntent {
        guard let intent = await AgentRuntimeBridge.shared.queuedIntent(id: intentID) else {
            throw ReviewError.intentNotFound(intentID)
        }
        guard intent.verificationStatus == "verified" else {
            throw ReviewError.intentNotVerified(intentID)
        }
        return intent
    }

    private func loadExecutor() async throws -> RemoteIntentExecutionBridge {
        guard let executor = await AgentRuntimeBridge.shared.remoteIntentExecutorSnapshot() else {
            throw ReviewError.executorUnavailable
        }
        return executor
    }

    private func publishReviewEvent(record: RemoteIntentAuditRecord, requester: Identity) async {
        let payload: Object = [
            "intentID": .string(record.intentID),
            "actionID": .string(record.actionID),
            "outcome": .string(record.outcome.rawValue),
            "reviewer": .string(record.reviewer),
            "recordedAt": .string(record.recordedAt),
            "verificationStatus": .string(record.verificationStatus),
            "issuerID": record.issuerID.map(ValueType.string) ?? .null,
            "note": record.note.map(ValueType.string) ?? .null,
            "errorMessage": record.errorMessage.map(ValueType.string) ?? .null
        ]
        var flowElement = FlowElement(
            title: "intent.review.updated",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "intent.review"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func makeStateValue() async -> ValueType {
        let queue = await AgentRuntimeBridge.shared.queuedIntentSnapshot()
        let audit = await AgentRuntimeBridge.shared.remoteIntentAuditSnapshot()
        return .object([
            "pendingCount": .integer(queue.count),
            "auditCount": .integer(audit.count),
            "lastOutcome": audit.last.map { .string($0.outcome.rawValue) } ?? .null,
            "lastIntentID": audit.last.map { .string($0.intentID) } ?? .null
        ])
    }

    private func makeAuditValue() async -> ValueType {
        let audit = await AgentRuntimeBridge.shared.remoteIntentAuditSnapshot()
        return .list(audit.map { record in
            .object([
                "intentID": .string(record.intentID),
                "actionID": .string(record.actionID),
                "issuerID": record.issuerID.map(ValueType.string) ?? .null,
                "verificationStatus": .string(record.verificationStatus),
                "outcome": .string(record.outcome.rawValue),
                "reviewer": .string(record.reviewer),
                "note": record.note.map(ValueType.string) ?? .null,
                "recordedAt": .string(record.recordedAt),
                "errorMessage": record.errorMessage.map(ValueType.string) ?? .null,
                "executedAction": record.executedAction.map(makeExecutedActionObject) ?? .null
            ])
        })
    }

    private func makeExecutedActionObject(_ record: ExecutedActionRecord) -> ValueType {
        .object([
            "kind": .string(record.kind.rawValue),
            "id": .string(record.id),
            "status": .string(record.status),
            "recordedAt": .string(record.recordedAt)
        ])
    }
}

private struct ReviewRequest {
    var intentID: String
    var reviewer: String
    var note: String?
}

private enum ReviewError: Error, LocalizedError {
    case invalidRequest
    case intentNotFound(String)
    case intentNotVerified(String)
    case executorUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid review request"
        case .intentNotFound(let intentID):
            return "Pending intent not found: \(intentID)"
        case .intentNotVerified(let intentID):
            return "Intent is not verified and cannot be approved: \(intentID)"
        case .executorUnavailable:
            return "Remote intent executor is not configured."
        }
    }
}
