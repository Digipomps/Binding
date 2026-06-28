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

    @Test func tokenRefreshThrottleAllowsFirstAndStaleRequestsOnly() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(NotificationEnrollmentManager.shouldRequestTokenRefresh(
            now: now,
            lastRequestedAt: nil,
            minimumInterval: 30
        ))
        #expect(!NotificationEnrollmentManager.shouldRequestTokenRefresh(
            now: now,
            lastRequestedAt: now.addingTimeInterval(-10),
            minimumInterval: 30
        ))
        #expect(NotificationEnrollmentManager.shouldRequestTokenRefresh(
            now: now,
            lastRequestedAt: now.addingTimeInterval(-31),
            minimumInterval: 30
        ))
    }

    @Test func registrationResponseValidationAcceptsActiveMatchingDevice() throws {
        try NotificationEnrollmentManager.validateRegistrationResponse(
            [
                "participantId": .string("participant-1"),
                "deviceId": .string("device-1"),
                "isActive": .bool(true),
                "pushTokenHash": .string("abc123")
            ],
            expectedParticipantID: "participant-1",
            expectedDeviceID: "device-1"
        )
    }

    @Test func registrationResponseValidationRejectsCellErrorPayload() {
        #expect(throws: NotificationRegistrationValidationError.invalidServerResponse) {
            try NotificationEnrollmentManager.validateRegistrationResponse(
                [:],
                expectedParticipantID: "participant-1",
                expectedDeviceID: "device-1"
            )
        }
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
