import Foundation
import CellBase
import HavenAgentCells
import HavenAgentRuntime
import HavenRuntimeBootstrap

struct ReviewCommandSummary: Codable, Sendable {
    struct PendingIntentSnapshot: Codable, Sendable {
        var id: String
        var actionID: String
        var issuerID: String?
        var origin: String
        var verificationStatus: String
        var receivedAt: String
    }

    struct AuditSnapshot: Codable, Sendable {
        var intentID: String
        var actionID: String
        var outcome: String
        var reviewer: String
        var recordedAt: String
        var errorMessage: String?
    }

    var pendingCount: Int
    var auditCount: Int
    var pending: [PendingIntentSnapshot]
    var audit: [AuditSnapshot]
    var lastOutcome: String?
    var lastIntentID: String?
}

struct ReviewCommandService {
    let paths: RuntimePaths
    let configURL: URL

    func state() async throws -> ReviewCommandSummary {
        try await withPreparedReviewCell(loadExecutionContext: false) { _, requester in
            try await summarize(requester: requester)
        }
    }

    func approve(intentID: String, reviewer: String, note: String?) async throws -> ReviewCommandSummary {
        try await withPreparedReviewCell(loadExecutionContext: true) { cell, requester in
            let payload = makeReviewPayload(intentID: intentID, reviewer: reviewer, note: note)
            _ = try await cell.set(keypath: "approve", value: payload, requester: requester)
            return try await summarize(requester: requester)
        }
    }

    func reject(intentID: String, reviewer: String, note: String?) async throws -> ReviewCommandSummary {
        try await withPreparedReviewCell(loadExecutionContext: false) { cell, requester in
            let payload = makeReviewPayload(intentID: intentID, reviewer: reviewer, note: note)
            _ = try await cell.set(keypath: "reject", value: payload, requester: requester)
            return try await summarize(requester: requester)
        }
    }

    private func withPreparedReviewCell<T>(
        loadExecutionContext: Bool,
        operation: (RemoteIntentReviewCell, Identity) async throws -> T
    ) async throws -> T {
        let remoteIntentStateStore = RemoteIntentStateStore(fileURL: paths.remoteIntentStateFile)
        await AgentRuntimeBridge.shared.configure(remoteIntentStateStore: remoteIntentStateStore)
        await AgentRuntimeBridge.shared.resetRemoteIntentState()
        await AgentRuntimeBridge.shared.update(remoteIntentPolicy: nil)
        await AgentRuntimeBridge.shared.update(remoteIntentExecutor: nil)
        await RemoteIntentExecutionBridge.shared.update(policy: nil)

        if let persisted = try await remoteIntentStateStore.load() {
            await AgentRuntimeBridge.shared.restore(remoteIntentState: persisted)
        }

        if let config = try? AgentConfig.load(from: configURL) {
            await AgentRuntimeBridge.shared.update(remoteIntentPolicy: config.remoteIntentPolicy)
            if loadExecutionContext {
                await RemoteIntentExecutionBridge.shared.update(policy: config.automationPolicy)
                await AgentRuntimeBridge.shared.update(remoteIntentExecutor: RemoteIntentExecutionBridge.shared)
            }
        }

        let requester = Identity(displayName: "haven-agent-cli", identityVault: nil)
        let cell = await RemoteIntentReviewCell(owner: requester)
        return try await operation(cell, requester)
    }

    private func summarize(requester: Identity) async throws -> ReviewCommandSummary {
        let pending = await AgentRuntimeBridge.shared.queuedIntentSnapshot()
        let audit = await AgentRuntimeBridge.shared.remoteIntentAuditSnapshot()
        return ReviewCommandSummary(
            pendingCount: pending.count,
            auditCount: audit.count,
            pending: pending.map { intent in
                ReviewCommandSummary.PendingIntentSnapshot(
                    id: intent.id,
                    actionID: intent.actionID,
                    issuerID: intent.issuerID,
                    origin: intent.origin,
                    verificationStatus: intent.verificationStatus,
                    receivedAt: intent.receivedAt
                )
            },
            audit: audit.reversed().map { record in
                ReviewCommandSummary.AuditSnapshot(
                    intentID: record.intentID,
                    actionID: record.actionID,
                    outcome: record.outcome.rawValue,
                    reviewer: record.reviewer,
                    recordedAt: record.recordedAt,
                    errorMessage: record.errorMessage
                )
            },
            lastOutcome: audit.last?.outcome.rawValue,
            lastIntentID: audit.last?.intentID
        )
    }

    private func makeReviewPayload(intentID: String, reviewer: String, note: String?) -> ValueType {
        var object: Object = [
            "intentID": .string(intentID),
            "reviewer": .string(reviewer)
        ]
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            object["note"] = .string(note)
        }
        return .object(object)
    }
}
