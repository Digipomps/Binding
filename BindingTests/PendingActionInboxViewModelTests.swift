import Foundation
import Testing
@testable import Binding

@MainActor
struct PendingActionInboxViewModelTests {
    @Test
    func upsertPersistsPendingActionForRelaunch() throws {
        let suiteName = "PendingActionInboxViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "pending-actions"
        let action = PendingDeviceAction(
            id: "ticket-1",
            participantId: "binding-participant",
            deviceId: "iphone-1",
            ticketId: "ticket-1",
            requiredActionKey: "haven.agent.followup.approval",
            payload: [
                "title": .string("Agent venter"),
                "message": .string("Godkjenn neste steg.")
            ],
            receivedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )

        let model = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)
        model.upsert(action)

        let restored = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)

        #expect(restored.actions.count == 1)
        #expect(restored.actions.first?.ticketId == "ticket-1")
        #expect(restored.actions.first?.requiredActionKey == "haven.agent.followup.approval")
        #expect(restored.actions.first?.payload["title"] == .string("Agent venter"))
    }

    @Test
    func removeClearsPersistedActionAfterSuccessfulSubmit() throws {
        let suiteName = "PendingActionInboxViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "pending-actions"
        let model = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)
        model.upsert(
            PendingDeviceAction(
                id: "ticket-2",
                participantId: "binding-participant",
                deviceId: "iphone-1",
                ticketId: "ticket-2",
                requiredActionKey: "haven.agent.followup.prompt",
                payload: ["message": .string("Skriv svar.")],
                receivedAt: Date(timeIntervalSince1970: 1_780_000_001)
            )
        )

        model.remove(ticketId: "ticket-2")
        let restored = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)

        #expect(restored.actions.isEmpty)
    }
}
