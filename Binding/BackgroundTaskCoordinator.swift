import Foundation

#if os(iOS)
import UIKit

@MainActor
final class BackgroundTaskCoordinator {
    static let shared = BackgroundTaskCoordinator()

    private init() {}

    func run(name: String, operation: @escaping @Sendable () async -> Void) {
        let taskID = UIApplication.shared.beginBackgroundTask(withName: name)
        Task {
            await operation()
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
}

#else

final class BackgroundTaskCoordinator {
    static let shared = BackgroundTaskCoordinator()

    private init() {}

    func run(name: String, operation: @escaping @Sendable () async -> Void) {
        Task { await operation() }
    }
}

#endif
