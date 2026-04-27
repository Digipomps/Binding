import Foundation

enum WorkflowNotificationPreferences {
    static let defaultSubscriptionTopics: [String] = [
        "conference.broadcast",
        "conference.organizer",
        "workflow.run",
        "workflow.review",
        "workflow.remote"
    ]

    static let activeBridgeTopics: [String] = [
        "workflow.run",
        "workflow.review",
        "workflow.remote"
    ]
}
