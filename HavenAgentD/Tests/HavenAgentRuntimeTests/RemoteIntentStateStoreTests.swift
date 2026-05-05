import Foundation
import Testing
@testable import HavenAgentRuntime

struct RemoteIntentStateStoreTests {
    @Test
    func persistedRemoteIntentStateRoundTrips() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentD-RemoteIntentState-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("remote-intent-state.json")
        let store = RemoteIntentStateStore(fileURL: fileURL)
        let state = PersistedRemoteIntentState(
            queuedIntents: [
                QueuedRemoteIntent(
                    id: "intent-1",
                    topic: "intent.inbox",
                    origin: "trusted.issuer",
                    actionID: "open-url-in-safari",
                    arguments: ["url": "https://example.com"],
                    receivedAt: "2026-03-13T11:00:00Z",
                    issuerID: "trusted.issuer",
                    issuedAt: "2026-03-13T10:59:00Z",
                    expiresAt: "2026-03-13T11:05:00Z",
                    verificationStatus: "verified"
                )
            ],
            seenNonces: ["intent-1"],
            auditTrail: [
                RemoteIntentAuditRecord(
                    intentID: "intent-1",
                    actionID: "open-url-in-safari",
                    issuerID: "trusted.issuer",
                    verificationStatus: "verified",
                    outcome: .approvedDispatched,
                    reviewer: "owner",
                    note: "Approved",
                    recordedAt: "2026-03-13T11:01:00Z",
                    executedAction: ExecutedActionRecord(
                        kind: .appleScript,
                        id: "open-url-in-safari",
                        status: "succeeded",
                        recordedAt: "2026-03-13T11:01:00Z"
                    ),
                    errorMessage: nil
                )
            ],
            recordedAt: "2026-03-13T11:01:00Z"
        )

        try await store.write(state)
        let loaded = try await store.load()

        #expect(loaded == state)
    }
}
