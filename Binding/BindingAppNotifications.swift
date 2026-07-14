import Foundation
import CellBase
import CellApple

nonisolated struct BindingIncomingURLEvent: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let targetWindowNumber: Int?
    let targetSceneID: UUID?
    let createdAt: Date
}

nonisolated struct BindingIncomingURLLease: Equatable {
    let event: BindingIncomingURLEvent
    let token: UUID
}

nonisolated struct BindingIncomingURLDeliveryFailure: Equatable {
    let reason: String
    let targetWindowNumber: Int?
    let targetSceneID: UUID?
}

enum BindingIncomingURLBridge {
    nonisolated static let notificationName = Notification.Name("BindingIncomingURLBridge.received")
    nonisolated static let deliveryFailureNotificationName = Notification.Name("BindingIncomingURLBridge.deliveryFailed")

    nonisolated private static let eventKey = "event"
    nonisolated private static let deliveryFailureKey = "deliveryFailure"
    private static let maximumPendingEvents = 32
    // Route work can include discovery plus a supported 30-second Porthole
    // load. Keep the lease longer than the route deadline to prevent a second
    // consumer from retrying while the first generation is still cancelling.
    private static let leaseLifetime: TimeInterval = 90
    private static let pendingEventLifetime: TimeInterval = 300
    private struct LeaseRecord {
        let consumerID: UUID
        let token: UUID
        let leasedAt: Date
    }
    @MainActor private static var pendingEvents: [BindingIncomingURLEvent] = []
    @MainActor private static var leasesByEventID: [UUID: LeaseRecord] = [:]

    @discardableResult
    @MainActor
    static func post(
        url: URL,
        targetWindowNumber: Int? = nil,
        targetSceneID: UUID? = nil,
        now: Date = Date(),
        notificationCenter: NotificationCenter = .default
    ) -> Bool {
        reapExpiredState(now: now)
        guard pendingEvents.count < maximumPendingEvents else {
            return false
        }
        let event = BindingIncomingURLEvent(
            id: UUID(),
            url: url,
            targetWindowNumber: targetWindowNumber,
            targetSceneID: targetSceneID,
            createdAt: now
        )
        pendingEvents.append(event)
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: [eventKey: event]
        )
        return true
    }

    /// Production delivery retries bounded-queue backpressure before emitting
    /// a query-free failure notification that the app can show to the user.
    @MainActor
    static func submit(
        url: URL,
        targetWindowNumber: Int? = nil,
        targetSceneID: UUID? = nil,
        notificationCenter: NotificationCenter = .default,
        retryDelays: [Duration] = [.milliseconds(150), .milliseconds(500), .seconds(1)]
    ) {
        guard !post(
            url: url,
            targetWindowNumber: targetWindowNumber,
            targetSceneID: targetSceneID,
            notificationCenter: notificationCenter
        ) else { return }

        Task { @MainActor in
            for delay in retryDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                if post(
                    url: url,
                    targetWindowNumber: targetWindowNumber,
                    targetSceneID: targetSceneID,
                    notificationCenter: notificationCenter
                ) {
                    return
                }
            }
            notificationCenter.post(
                name: deliveryFailureNotificationName,
                object: nil,
                userInfo: [deliveryFailureKey: BindingIncomingURLDeliveryFailure(
                    reason: "incoming_url_queue_full",
                    targetWindowNumber: targetWindowNumber,
                    targetSceneID: targetSceneID
                )]
            )
        }
    }

    nonisolated static func event(from notification: Notification) -> BindingIncomingURLEvent? {
        notification.userInfo?[eventKey] as? BindingIncomingURLEvent
    }

    nonisolated static func url(from notification: Notification) -> URL? {
        event(from: notification)?.url
    }

    nonisolated static func targetWindowNumber(from notification: Notification) -> Int? {
        event(from: notification)?.targetWindowNumber
    }

    nonisolated static func deliveryFailure(
        from notification: Notification
    ) -> BindingIncomingURLDeliveryFailure? {
        notification.userInfo?[deliveryFailureKey] as? BindingIncomingURLDeliveryFailure
    }

    @MainActor
    static func lease(
        _ event: BindingIncomingURLEvent,
        consumerID: UUID,
        hostingWindowNumber: Int?,
        hostingSceneID: UUID? = nil,
        now: Date = Date()
    ) -> BindingIncomingURLLease? {
        reapExpiredState(now: now)
        guard pendingEvents.contains(where: { $0.id == event.id }),
              leasesByEventID[event.id] == nil,
              matches(
                event: event,
                hostingWindowNumber: hostingWindowNumber,
                hostingSceneID: hostingSceneID
              ) else {
            return nil
        }
        let token = UUID()
        leasesByEventID[event.id] = LeaseRecord(
            consumerID: consumerID,
            token: token,
            leasedAt: now
        )
        return BindingIncomingURLLease(event: event, token: token)
    }

    @MainActor
    static func leasePending(
        consumerID: UUID,
        hostingWindowNumber: Int?,
        hostingSceneID: UUID? = nil,
        now: Date = Date()
    ) -> [BindingIncomingURLLease] {
        reapExpiredState(now: now)
        return pendingEvents.compactMap { event in
            lease(
                event,
                consumerID: consumerID,
                hostingWindowNumber: hostingWindowNumber,
                hostingSceneID: hostingSceneID,
                now: now
            )
        }
    }

    /// Leases only the next runnable event. Production consumers use this
    /// instead of pre-leasing the whole backlog so a lease cannot expire while
    /// its operation is still waiting behind unrelated route work.
    @MainActor
    static func leaseNextPending(
        consumerID: UUID,
        hostingWindowNumber: Int?,
        hostingSceneID: UUID? = nil,
        now: Date = Date()
    ) -> BindingIncomingURLLease? {
        reapExpiredState(now: now)
        guard let event = pendingEvents.first(where: {
            leasesByEventID[$0.id] == nil
                && matches(
                    event: $0,
                    hostingWindowNumber: hostingWindowNumber,
                    hostingSceneID: hostingSceneID
                )
        }) else {
            return nil
        }
        return lease(
            event,
            consumerID: consumerID,
            hostingWindowNumber: hostingWindowNumber,
            hostingSceneID: hostingSceneID,
            now: now
        )
    }

    @MainActor
    static func acknowledge(_ lease: BindingIncomingURLLease, consumerID: UUID) {
        guard let record = leasesByEventID[lease.event.id],
              record.consumerID == consumerID,
              record.token == lease.token else { return }
        leasesByEventID.removeValue(forKey: lease.event.id)
        pendingEvents.removeAll { $0.id == lease.event.id }
    }

    @MainActor
    static func release(_ lease: BindingIncomingURLLease, consumerID: UUID) {
        guard let record = leasesByEventID[lease.event.id],
              record.consumerID == consumerID,
              record.token == lease.token else { return }
        leasesByEventID.removeValue(forKey: lease.event.id)
    }

    @MainActor
    static func releaseAll(consumerID: UUID) {
        leasesByEventID = leasesByEventID.filter { $0.value.consumerID != consumerID }
    }

    @MainActor
    static func discardTargetedPending(
        targetWindowNumber: Int?,
        targetSceneID: UUID?
    ) {
        let removedIDs = Set(pendingEvents.compactMap { event -> UUID? in
#if canImport(AppKit)
            guard let targetWindowNumber,
                  event.targetWindowNumber == targetWindowNumber else { return nil }
#else
            guard let targetSceneID,
                  event.targetSceneID == targetSceneID else { return nil }
#endif
            return event.id
        })
        pendingEvents.removeAll { removedIDs.contains($0.id) }
        leasesByEventID = leasesByEventID.filter { !removedIDs.contains($0.key) }
    }

    @MainActor
    private static func reapExpiredState(now: Date) {
        leasesByEventID = leasesByEventID.filter {
            now.timeIntervalSince($0.value.leasedAt) < leaseLifetime
        }
        let expiredEventIDs = Set(pendingEvents.compactMap { event in
            now.timeIntervalSince(event.createdAt) >= pendingEventLifetime ? event.id : nil
        })
        pendingEvents.removeAll { expiredEventIDs.contains($0.id) }
        leasesByEventID = leasesByEventID.filter { !expiredEventIDs.contains($0.key) }
    }

    @MainActor
    static func contains(eventID: UUID) -> Bool {
        pendingEvents.contains { $0.id == eventID }
    }

    @MainActor
    static func leaseCount() -> Int {
        leasesByEventID.count
    }

    @MainActor
    static func removeForTesting(eventID: UUID) {
        leasesByEventID.removeValue(forKey: eventID)
        pendingEvents.removeAll { $0.id == eventID }
    }

    @MainActor
    static func pendingCount() -> Int {
        pendingEvents.count
    }

    @MainActor
    static func pendingCount(now: Date) -> Int {
        reapExpiredState(now: now)
        return pendingEvents.count
    }

    @MainActor
    static func resetForTesting() {
        pendingEvents.removeAll()
        leasesByEventID.removeAll()
    }

    @MainActor
    private static func matches(
        event: BindingIncomingURLEvent,
        hostingWindowNumber: Int?,
        hostingSceneID: UUID?
    ) -> Bool {
#if canImport(AppKit)
        _ = hostingSceneID
        guard let targetWindowNumber = event.targetWindowNumber else { return true }
        return hostingWindowNumber == targetWindowNumber
#else
        _ = hostingWindowNumber
        guard event.targetWindowNumber == nil,
              let targetSceneID = event.targetSceneID,
              let hostingSceneID else { return false }
        return targetSceneID == hostingSceneID
#endif
    }
}

@MainActor
final class BindingRuntimeRouteExecution {
    private(set) var isActive = true

    func invalidate() {
        isActive = false
    }

    /// Performs a state commit atomically with the active-generation check.
    /// Cancellation alone is not sufficient because resolver and transport
    /// operations are allowed to finish after their caller has timed out.
    @discardableResult
    func commit(_ operation: @MainActor () -> Void) -> Bool {
        guard isActive else { return false }
        operation()
        return true
    }
}

@MainActor
final class BindingRuntimeRouteQueue {
    enum Outcome: Equatable {
        case completed
        case timedOut
        case cancelled
    }

    private struct PendingOperation {
        let operation: @MainActor (BindingRuntimeRouteExecution) async -> Void
        let completion: @MainActor (Outcome) -> Void
    }

    private final class CompletionGate {
        private var continuation: CheckedContinuation<Outcome, Never>?
        private var outcome: Outcome?

        func wait() async -> Outcome {
            if let outcome { return outcome }
            return await withCheckedContinuation { continuation in
                if let outcome {
                    continuation.resume(returning: outcome)
                } else {
                    self.continuation = continuation
                }
            }
        }

        func resolve(_ outcome: Outcome) {
            guard self.outcome == nil else { return }
            self.outcome = outcome
            continuation?.resume(returning: outcome)
            continuation = nil
        }
    }

    private let maximumPendingOperations: Int
    private let operationTimeout: Duration
    private var pending: [PendingOperation] = []
    private var worker: Task<Void, Never>?
    private var runningOperation: Task<Void, Never>?
    private var runningGate: CompletionGate?
    private var runningExecution: BindingRuntimeRouteExecution?
    private var runningOperationID: UUID?

    init(
        maximumPendingOperations: Int = 32,
        operationTimeout: Duration = .seconds(60)
    ) {
        self.maximumPendingOperations = maximumPendingOperations
        self.operationTimeout = operationTimeout
    }

    @discardableResult
    func enqueue(
        _ operation: @escaping @MainActor (BindingRuntimeRouteExecution) async -> Void,
        completion: @escaping @MainActor (Outcome) -> Void = { _ in }
    ) -> Bool {
        guard pending.count < maximumPendingOperations else { return false }
        pending.append(PendingOperation(operation: operation, completion: completion))
        startWorkerIfNeeded()
        return true
    }

    func cancelAll() {
        let abandoned = pending
        pending.removeAll(keepingCapacity: false)
        abandoned.forEach { $0.completion(.cancelled) }
        runningExecution?.invalidate()
        runningOperation?.cancel()
        runningGate?.resolve(.cancelled)
        worker?.cancel()
    }

    /// True only when a newly accepted route can become the next operation,
    /// which lets URL delivery acquire a short-lived bridge lease just in time.
    var canStartImmediately: Bool {
        pending.isEmpty && runningOperation == nil
    }

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }
        worker = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, !pending.isEmpty {
                let next = pending.removeFirst()
                let outcome = await runWithTimeout(next.operation)
                next.completion(outcome)
            }
            worker = nil
            if !pending.isEmpty {
                startWorkerIfNeeded()
            }
        }
    }

    func waitForIdle() async {
        while let currentWorker = worker {
            await currentWorker.value
        }
    }

    private func runWithTimeout(
        _ operation: @escaping @MainActor (BindingRuntimeRouteExecution) async -> Void
    ) async -> Outcome {
        let gate = CompletionGate()
        let execution = BindingRuntimeRouteExecution()
        let operationID = UUID()
        let operationTask = Task { @MainActor in
            await operation(execution)
            gate.resolve(execution.isActive && !Task.isCancelled ? .completed : .cancelled)
        }
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: operationTimeout)
            guard !Task.isCancelled else { return }
            execution.invalidate()
            gate.resolve(.timedOut)
        }
        runningOperation = operationTask
        runningGate = gate
        runningExecution = execution
        runningOperationID = operationID

        let outcome = await gate.wait()
        if outcome != .completed {
            execution.invalidate()
            operationTask.cancel()
        }
        timeoutTask.cancel()
        if runningOperationID == operationID {
            runningOperation = nil
            runningGate = nil
            runningExecution = nil
            runningOperationID = nil
        }
        return outcome
    }
}

@MainActor
final class BindingSerializedConfigurationLoadCoordinator {
    private var tail: Task<Void, Never>?

    @discardableResult
    func enqueue(
        _ operation: @escaping @MainActor () async -> Void
    ) -> Task<Void, Never> {
        let previous = tail
        previous?.cancel()
        let task = Task { @MainActor in
            if let previous {
                await previous.value
            }
            guard !Task.isCancelled else { return }
            await operation()
        }
        tail = task
        return task
    }

    func cancelAll() {
        tail?.cancel()
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
    nonisolated private static let testProcessStorageID = "\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"

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

        CellBase.documentRootPath = documentRootPath()

        if resolver.tcUtility == nil {
            let utility = TypedCellUtility(storage: FileSystemCellStorage())
            resolver.tcUtility = utility
            CellBase.typedCellUtility = utility
        } else if CellBase.typedCellUtility == nil {
            CellBase.typedCellUtility = resolver.tcUtility
        }

        // The app intentionally transitions from a prompt-free startup vault
        // to the authenticated vault. Keep scaffold-unique resolve ownership
        // aligned with whichever vault is active before any cell is reused.
        await resolver.refreshNamedResolveOwnersFromCurrentVault()

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

    nonisolated static func documentRootPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        launchArguments: [String] = ProcessInfo.processInfo.arguments,
        fileManager: FileManager = .default
    ) -> String {
        let rootURL: URL
        if environment["XCTestConfigurationFilePath"] != nil {
            // Unit-test hosts share NSTemporaryDirectory across invocations.
            // A process-unique root prevents a new ephemeral signing identity
            // from adopting resolver metadata persisted by an earlier run.
            // Tests that prove restart behavior must opt into and pass the same
            // explicit root themselves.
            rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("Binding/TestRuns/\(testProcessStorageID)/CellDocumentRoot", isDirectory: true)
        } else if shouldUseTemporaryDocumentRoot(environment: environment, launchArguments: launchArguments) {
            rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("Binding/CellDocumentRoot", isDirectory: true)
        } else if let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            rootURL = applicationSupportURL
                .appendingPathComponent("Binding/CellDocumentRoot", isDirectory: true)
        } else {
            rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("Binding/CellDocumentRoot", isDirectory: true)
        }

        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL.path
    }

    nonisolated private static func shouldUseTemporaryDocumentRoot(
        environment: [String: String],
        launchArguments: [String]
    ) -> Bool {
        if shouldUseLocalRuntimeOnlyForVerifier(environment: environment, launchArguments: launchArguments) {
            return true
        }
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if boolEnvironmentFlag("CODEX_CI", in: environment)
            || boolEnvironmentFlag("BINDING_FORCE_TEMP_DOCUMENT_ROOT", in: environment) {
            return true
        }
        return false
    }

    nonisolated private static func boolEnvironmentFlag(
        _ key: String,
        in environment: [String: String]
    ) -> Bool {
        guard let rawValue = environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return ["1", "true", "yes"].contains(rawValue)
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
            PendingActionInboxViewModel.shared.reloadPersistedActions()
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            PendingActionInboxViewModel.shared.reloadPersistedActions()
            await NotificationEnrollmentManager.shared.refreshDeviceRegistrationOnActivation()
        }
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
