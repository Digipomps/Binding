import Testing
import Foundation
@testable import Binding

@MainActor
@Suite
struct NotificationEnrollmentManagerTests {

    @Test func registrationPayloadCarriesWorkflowSubscriptions() {
        let payload = NotificationEnrollmentManager.registrationPayload(
            participantID: "participant-1",
            deviceID: "device-1",
            pushToken: "apns-token",
            platform: "ios",
            termsVersion: "v1",
            conferenceID: "conf-1",
            subscriptionTopics: WorkflowNotificationPreferences.defaultSubscriptionTopics,
            mutedEventTypes: []
        )

        #expect(stringValue(payload["conferenceId"]) == "conf-1")
        #expect(stringArray(payload["subscriptionTopics"]) == WorkflowNotificationPreferences.defaultSubscriptionTopics)
        #expect(stringArray(payload["callbackCapabilities"]) == ["http", "background", "notification-response", "bridge"])
    }

    @Test func bridgePresenceQueryItemsCarryDeviceIdentityAndTopics() {
        let items = NotificationEnrollmentManager.bridgePresenceQueryItems(
            participantID: "participant-1",
            deviceID: "device-1",
            topics: WorkflowNotificationPreferences.activeBridgeTopics
        )

        #expect(items.first(where: { $0.name == "participantId" })?.value == "participant-1")
        #expect(items.first(where: { $0.name == "deviceId" })?.value == "device-1")
        #expect(items.filter { $0.name == "bridgeTopic" }.compactMap(\.value) == WorkflowNotificationPreferences.activeBridgeTopics)
    }

    @Test func normalizeTopicsDeduplicatesAndTrimsValues() {
        let normalized = NotificationEnrollmentManager.normalizeTopics([
            " workflow.run ",
            "workflow.review",
            "WORKFLOW.RUN",
            "",
            "conference.broadcast"
        ])

        #expect(normalized == ["workflow.run", "workflow.review", "conference.broadcast"])
    }

    private func stringArray(_ value: JSONValue?) -> [String] {
        guard case let .array(items)? = value else { return [] }
        return items.compactMap { item in
            guard case let .string(value) = item else { return nil }
            return value
        }
    }

    private func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(value)? = value else { return nil }
        return value
    }
}
