import Testing
import Foundation
@testable import Binding

@MainActor
struct NotificationCallbackClientTests {
    @Test
    func baseURLDefaultsToStagingDeviceCallbackAPI() {
        #expect(
            NotificationCallbackClient.baseURLString(environment: [:])
                == "https://staging.haven.digipomps.org/conference-mvp/api/device"
        )
    }

    @Test
    func baseURLPrefersEnvironmentOverride() {
        #expect(
            NotificationCallbackClient.baseURLString(
                environment: ["BINDING_NOTIFICATION_API_BASE": "http://localhost:9089/conference-mvp/api/device"]
            ) == "http://localhost:9089/conference-mvp/api/device"
        )
    }

    @Test
    func ticketDecisionResultCarriesGenericDeviceActionDecision() {
        let action = PendingDeviceAction(
            id: "ticket-1",
            participantId: "participant-1",
            deviceId: "phone-1",
            ticketId: "ticket-1",
            requiredActionKey: "binding.notification.staging.test",
            payload: [:],
            receivedAt: .init(timeIntervalSince1970: 0)
        )

        let result = NotificationCallbackClient.ticketDecisionResult(
            action: action,
            decision: .approved
        )

        #expect(result["requiredActionKey"] == .string("binding.notification.staging.test"))
        #expect(result["responseKind"] == .string("decision"))
        #expect(result["decision"] == .string("approved"))
        #expect(result["prompt"] == .string("Approved"))
    }
}
