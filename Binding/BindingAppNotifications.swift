import Foundation
import CellBase
import CellApple

enum BindingIncomingURLBridge {
    nonisolated static let notificationName = Notification.Name("BindingIncomingURLBridge.received")

    nonisolated private static let urlKey = "url"

    nonisolated static func post(url: URL, notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: [urlKey: url]
        )
    }

    nonisolated static func url(from notification: Notification) -> URL? {
        notification.userInfo?[urlKey] as? URL
    }
}

enum BindingLaunchWarmup {
    static func preloadLocalRuntime() async {
        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
    }
}

enum BindingRuntimeBootstrap {
    @MainActor
    static func ensureInfrastructureBaseline() async {
        CellBase.sendDataAsText = true

        if CellBase.defaultIdentityVault == nil {
            CellBase.defaultIdentityVault = BindingStartupIdentityVault.shared
        }

        let resolver = CellResolver.sharedInstance
        if !(CellBase.defaultCellResolver is CellResolver) {
            CellBase.defaultCellResolver = resolver
        }

#if DEBUG
        CellBase.webSocketSecurityPolicy = .developmentOnlyInsecureAllowed
#else
        CellBase.webSocketSecurityPolicy = .requireTLS
#endif

        CellBase.documentRootPath = documentsDirectoryPath()

        if resolver.tcUtility == nil {
            let utility = TypedCellUtility(storage: FileSystemCellStorage())
            resolver.tcUtility = utility
            CellBase.typedCellUtility = utility
        } else if CellBase.typedCellUtility == nil {
            CellBase.typedCellUtility = resolver.tcUtility
        }

        try? await resolver.registerDefaultWebSocketBridgeTransports()
        if CellBase.hostname != "localhost", !CellBase.hostname.isEmpty {
            resolver.registerRemoteCellHost(
                CellBase.hostname,
                route: RemoteCellHostRoute(websocketEndpoint: "publishersws", schemePreference: .automatic)
            )
        }
    }

    @MainActor
    static func ensureBaseline() async {
        await ensureInfrastructureBaseline()

        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
    }

    @MainActor
    static var authenticatedRuntimeIsReady: Bool {
        CellBase.defaultIdentityVault is IdentityVault
            && CellBase.defaultCellResolver is CellResolver
    }

    private static func documentsDirectoryPath() -> String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
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

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        BindingIncomingURLBridge.post(url: url)
        return true
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
