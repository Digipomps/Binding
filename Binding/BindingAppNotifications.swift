import Foundation
import CellApple

enum BindingLaunchWarmup {
    static func preloadLocalRuntime() async {
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.warmConferenceRuntime()
    }
}

#if os(iOS)
import UIKit
import UserNotifications

final class BindingAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task(priority: .userInitiated) {
            await BindingLaunchWarmup.preloadLocalRuntime()
        }
        Task { @MainActor in
            NotificationEnrollmentManager.shared.bootstrapIfNeeded()
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            await NotificationEnrollmentManager.shared.updateAPNSToken(token)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            NotificationEnrollmentManager.shared.declineTerms()
        }
        print("APNS registration failed: \(error)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        BackgroundTaskCoordinator.shared.run(name: "binding.notification.callback") {
            let result = await NotificationCallbackClient.shared.handleRemoteNotification(userInfo: userInfo)
            completionHandler(result)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
#endif
