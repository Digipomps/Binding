import Foundation
import CellBase
import CellApple

enum BindingIncomingURLBridge {
    nonisolated static let notificationName = Notification.Name("BindingIncomingURLBridge.received")

    nonisolated private static let urlKey = "url"
    nonisolated private static let targetWindowNumberKey = "targetWindowNumber"

    nonisolated static func post(
        url: URL,
        targetWindowNumber: Int? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        var userInfo: [String: Any] = [urlKey: url]
        if let targetWindowNumber {
            userInfo[targetWindowNumberKey] = targetWindowNumber
        }
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: userInfo
        )
    }

    nonisolated static func url(from notification: Notification) -> URL? {
        notification.userInfo?[urlKey] as? URL
    }

    nonisolated static func targetWindowNumber(from notification: Notification) -> Int? {
        notification.userInfo?[targetWindowNumberKey] as? Int
    }
}

enum BindingConferenceAutomationBridge {
    nonisolated static let notificationName = Notification.Name("BindingConferenceAutomationBridge.received")

    nonisolated private static let hookKey = "hook"
    nonisolated private static let targetWindowNumberKey = "targetWindowNumber"

    nonisolated static func post(
        hook: ContentView.ConferenceAutomationHook,
        targetWindowNumber: Int? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        var userInfo: [String: Any] = [hookKey: hook.rawValue]
        if let targetWindowNumber {
            userInfo[targetWindowNumberKey] = targetWindowNumber
        }
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: userInfo
        )
    }

    nonisolated static func hook(from notification: Notification) -> ContentView.ConferenceAutomationHook? {
        guard let rawValue = notification.userInfo?[hookKey] as? String else { return nil }
        return ContentView.ConferenceAutomationHook(rawValue: rawValue)
    }

    nonisolated static func targetWindowNumber(from notification: Notification) -> Int? {
        notification.userInfo?[targetWindowNumberKey] as? Int
    }
}

enum BindingLaunchWarmup {
    static func preloadLocalRuntime() async {
        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
    }
}

enum BindingRuntimeBootstrap {
    nonisolated private static let localRuntimeOnlyVerifierFlagPath = "/tmp/binding-verifier-local-runtime.flag"
    nonisolated private static let conferenceAutomationLaunchArgument = "--enable-conference-automation"

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
                route: RemoteCellHostRoute(websocketEndpoint: "bridgehead", schemePreference: .automatic)
            )
        }
    }

    @MainActor
    static func ensureBaseline() async {
        if shouldUseLocalRuntimeOnlyForVerifier() {
            await ensureInfrastructureBaseline()
            return
        }

        await ensureInfrastructureBaseline()

        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await CellResolver.sharedInstance.refreshNamedResolveOwnersFromCurrentVault()
    }

    @MainActor
    static var authenticatedRuntimeIsReady: Bool {
        if shouldUseLocalRuntimeOnlyForVerifier() {
            return CellBase.defaultIdentityVault != nil
                && CellBase.defaultCellResolver is CellResolver
        }

        return CellBase.defaultIdentityVault is IdentityVault
            && CellBase.defaultCellResolver is CellResolver
    }

    nonisolated static func shouldUseLocalRuntimeOnlyForVerifier(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if let mode = environment["BINDING_VERIFIER_IDENTITY_MODE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           ["startup", "local", "test", "deterministic"].contains(mode) {
            return true
        }

        if launchArguments.contains(Self.conferenceAutomationLaunchArgument) {
            return true
        }

        if let rawValue = environment["BINDING_ENABLE_CONFERENCE_AUTOMATION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           ["1", "true", "yes"].contains(rawValue) {
            return true
        }

        return FileManager.default.fileExists(atPath: localRuntimeOnlyVerifierFlagPath)
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
            NotificationEnrollmentManager.shared.recordAPNSRegistrationFailure(error)
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
        let userInfo = notification.request.content.userInfo
        Task {
            _ = await NotificationCallbackClient.shared.handleRemoteNotification(userInfo: userInfo)
        }
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task {
            await NotificationCallbackClient.shared.handleNotificationResponse(userInfo: userInfo)
            completionHandler()
        }
    }
}
#endif
