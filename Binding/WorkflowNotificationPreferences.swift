import Foundation

enum WorkflowNotificationPreferences {
    static let contactRequestReceivedTopic = "contact.request.received"

    static let defaultSubscriptionTopics: [String] = [
        "conference.broadcast",
        "conference.organizer",
        "workflow.run",
        "workflow.review",
        "workflow.remote",
        contactRequestReceivedTopic
    ]

    static let activeBridgeTopics: [String] = [
        "workflow.run",
        "workflow.review",
        "workflow.remote",
        contactRequestReceivedTopic
    ]
}
