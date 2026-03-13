import Dispatch
import Foundation
import HavenMacAutomation
import HavenRuntimeBootstrap
import Darwin

public struct FolderEvent: Equatable, Sendable {
    public var watchID: String
    public var path: String
    public var topic: String
    public var eventNames: [FolderWatchEventName]
    public var detectedAt: Date

    public init(
        watchID: String,
        path: String,
        topic: String,
        eventNames: [FolderWatchEventName],
        detectedAt: Date
    ) {
        self.watchID = watchID
        self.path = path
        self.topic = topic
        self.eventNames = eventNames
        self.detectedAt = detectedAt
    }

    public var summary: String {
        "\(watchID):\(eventNames.map(\.rawValue).sorted().joined(separator: ",")) @ \(path)"
    }
}

private final class FolderMonitor {
    private let configuration: WatchFolderConfig
    private let callback: @Sendable (FolderEvent) -> Void
    private let queue: DispatchQueue
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    init(configuration: WatchFolderConfig, callback: @escaping @Sendable (FolderEvent) -> Void) {
        self.configuration = configuration
        self.callback = callback
        self.queue = DispatchQueue(label: "HavenAgentD.FolderMonitor.\(configuration.id)")
    }

    deinit {
        stop()
    }

    func start() throws {
        stop()
        let path = NSString(string: configuration.path).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw AgentRuntimeError.invalidWatchPath(path)
        }

        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            throw AgentRuntimeError.watchOpenFailed(path, errno)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: dispatchMask(for: configuration.events),
            queue: queue
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else {
                return
            }
            let names = self.eventNames(from: source.data)
            guard !names.isEmpty else {
                return
            }
            self.callback(
                FolderEvent(
                    watchID: self.configuration.id,
                    path: path,
                    topic: self.configuration.topic,
                    eventNames: names,
                    detectedAt: Date()
                )
            )
        }
        source.setCancelHandler {
            close(descriptor)
        }
        self.fileDescriptor = descriptor
        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    private func dispatchMask(for events: [FolderWatchEventName]) -> DispatchSource.FileSystemEvent {
        events.reduce(into: DispatchSource.FileSystemEvent()) { partialResult, event in
            switch event {
            case .write: partialResult.formUnion(.write)
            case .delete: partialResult.formUnion(.delete)
            case .extend: partialResult.formUnion(.extend)
            case .attrib: partialResult.formUnion(.attrib)
            case .link: partialResult.formUnion(.link)
            case .rename: partialResult.formUnion(.rename)
            case .revoke: partialResult.formUnion(.revoke)
            }
        }
    }

    private func eventNames(from mask: DispatchSource.FileSystemEvent) -> [FolderWatchEventName] {
        FolderWatchEventName.allCases.filter { event in
            switch event {
            case .write: return mask.contains(.write)
            case .delete: return mask.contains(.delete)
            case .extend: return mask.contains(.extend)
            case .attrib: return mask.contains(.attrib)
            case .link: return mask.contains(.link)
            case .rename: return mask.contains(.rename)
            case .revoke: return mask.contains(.revoke)
            }
        }
    }
}

public enum AgentRuntimeError: Error, Equatable, Sendable, LocalizedError {
    case invalidWatchPath(String)
    case watchOpenFailed(String, Int32)
    case configArgumentMissing
    case unsupportedAction(String)

    public var errorDescription: String? {
        switch self {
        case .invalidWatchPath(let path):
            return "Watch path does not exist: \(path)"
        case .watchOpenFailed(let path, let errno):
            return "Unable to open watch path '\(path)' (errno \(errno))"
        case .configArgumentMissing:
            return "Missing --config argument"
        case .unsupportedAction(let actionID):
            return "Unsupported action kind: \(actionID)"
        }
    }
}

private final class ShutdownSignal {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var sources: [DispatchSourceSignal] = []

    init(signals: [Int32] = [SIGINT, SIGTERM]) {
        for signalNumber in signals {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler { [weak self] in
                self?.resume()
            }
            source.resume()
            sources.append(source)
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }

    private func resume() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

private actor ActionDispatcher {
    private let shortcutRunner: ShortcutRunner
    private let appleScriptRunner: AppleScriptRunner

    init(
        shortcutRunner: ShortcutRunner,
        appleScriptRunner: AppleScriptRunner
    ) {
        self.shortcutRunner = shortcutRunner
        self.appleScriptRunner = appleScriptRunner
    }

    func dispatch(
        _ action: AutomationActionRequest,
        event: FolderEvent,
        policy: AutomationPolicy
    ) async throws -> ExecutedActionRecord {
        let timestamp = Self.iso8601String(Date())
        switch action.kind {
        case .shortcut:
            let inputPath = action.inputPath.map { TemplateRenderer.render($0, event: event) }
            let invocation = ShortcutInvocation(id: action.id, origin: .local, inputPath: inputPath)
            _ = try await shortcutRunner.run(invocation, policy: policy)
            return ExecutedActionRecord(kind: .shortcut, id: action.id, status: "succeeded", recordedAt: timestamp)
        case .appleScript:
            let arguments = action.arguments.mapValues { TemplateRenderer.render($0, event: event) }
            let invocation = AppleScriptInvocation(id: action.id, origin: .local, arguments: arguments)
            _ = try await appleScriptRunner.run(invocation, policy: policy)
            return ExecutedActionRecord(kind: .appleScript, id: action.id, status: "succeeded", recordedAt: timestamp)
        }
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private enum TemplateRenderer {
    static func render(_ template: String, event: FolderEvent) -> String {
        template
            .replacingOccurrences(of: "{{watch.id}}", with: event.watchID)
            .replacingOccurrences(of: "{{watch.topic}}", with: event.topic)
            .replacingOccurrences(of: "{{watch.path}}", with: event.path)
            .replacingOccurrences(of: "{{event.path}}", with: event.path)
            .replacingOccurrences(of: "{{event.topic}}", with: event.topic)
            .replacingOccurrences(of: "{{event.names}}", with: event.eventNames.map(\.rawValue).joined(separator: ","))
            .replacingOccurrences(of: "{{event.detectedAt}}", with: Self.iso8601String(event.detectedAt))
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

public actor AgentRuntime {
    private let paths: RuntimePaths
    private let bootstrap: RuntimeBootstrap
    private let stateStore: AgentStateStore
    private let sessionSupervisor: SessionSupervisor
    private let renewalService: ContractRenewalService
    private let sproutBootstrapClient: SproutBootstrapClient
    private let dispatcher: ActionDispatcher
    private let remoteIntentStateStore: RemoteIntentStateStore
    private let portholeIngressController: any PortholeIngressControlling
    private let now: @Sendable () -> Date
    private let sleep: PortholeLifecycleController.SleepFunction
    private var portholeLifecycleController: PortholeLifecycleController?
    private var monitors: [FolderMonitor] = []
    private var state: AgentRuntimeState?

    public init(
        paths: RuntimePaths,
        processRunner: any ProcessRunning = FoundationProcessRunner(),
        portholeIngressController: (any PortholeIngressControlling)? = nil,
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping PortholeLifecycleController.SleepFunction = PortholeLifecycleController.defaultSleep
    ) {
        self.paths = paths
        self.bootstrap = RuntimeBootstrap()
        self.stateStore = AgentStateStore(fileURL: paths.stateFile)
        self.sessionSupervisor = SessionSupervisor()
        self.renewalService = ContractRenewalService()
        self.sproutBootstrapClient = SproutBootstrapClient(processRunner: processRunner)
        self.dispatcher = ActionDispatcher(
            shortcutRunner: ShortcutRunner(processRunner: processRunner),
            appleScriptRunner: AppleScriptRunner(processRunner: processRunner)
        )
        self.remoteIntentStateStore = RemoteIntentStateStore(fileURL: paths.remoteIntentStateFile)
        self.portholeIngressController = portholeIngressController ?? PortholeIngressSession()
        self.now = now
        self.sleep = sleep
    }

    public func validate(configURL: URL) throws -> AgentConfig {
        try AgentConfig.load(from: configURL)
    }

    public func run(configURL: URL, once: Bool) async throws {
        let config = try AgentConfig.load(from: configURL)
        try await run(config: config, once: once)
    }

    public func run(config: AgentConfig, once: Bool) async throws {
        if once {
            try await validateStartup(config: config, once: true)
            return
        }

        try await start(config: config)
        let shutdownSignal = ShutdownSignal()
        await shutdownSignal.wait()
        try await stop()
    }

    public func start(config: AgentConfig) async throws {
        try await validateStartup(config: config, once: false)
    }

    public func stop() async throws {
        await sessionSupervisor.stop()
        await stopPortholeLifecycle()
        stopMonitors()
        state?.status = "stopped"
        try await persistState()
    }

    private func validateStartup(config: AgentConfig, once: Bool) async throws {
        _ = try bootstrap.bootstrap(paths: paths)
        let bootstrapPlan = config.makeSproutBootstrapPlan()
        await renewalService.update(plan: bootstrapPlan)
        await AgentRuntimeBridge.shared.update(remoteIntentPolicy: config.remoteIntentPolicy)
        await AgentRuntimeBridge.shared.update(remoteIntentExecutor: RemoteIntentExecutionBridge.shared)
        await RemoteIntentExecutionBridge.shared.update(policy: config.automationPolicy)
        await AgentRuntimeBridge.shared.configure(remoteIntentStateStore: remoteIntentStateStore)
        if let persistedRemoteIntentState = try await remoteIntentStateStore.load() {
            await AgentRuntimeBridge.shared.restore(remoteIntentState: persistedRemoteIntentState)
        }

        state = AgentRuntimeState(
            instanceName: config.instanceName,
            status: once ? "validated" : "starting",
            activeWatchIDs: config.watchFolders.map(\.id),
            lastHeartbeatAt: nil,
            lastEventSummary: nil,
            lastError: nil,
            lastExecutedAction: nil,
            lastSproutBootstrap: nil,
            portholeIngress: shouldEnablePortholeIngress(for: config) ? PortholeIngressStatus(phase: .idle) : nil,
            bootstrapPlan: bootstrapPlan
        )
        try await persistState()

        if once {
            let bootstrapRecord = try await sproutBootstrapClient.run(config: config, paths: paths)
            state?.lastSproutBootstrap = bootstrapRecord
            state?.lastError = nil
            try await persistState()
            return
        }

        if shouldEnablePortholeIngress(for: config) {
            try await startPortholeLifecycle(config: config)
        } else {
            let bootstrapRecord = try await sproutBootstrapClient.run(config: config, paths: paths)
            state?.lastSproutBootstrap = bootstrapRecord
            state?.lastError = nil
            try await persistState()
        }

        for watchFolder in config.watchFolders {
            let monitor = FolderMonitor(configuration: watchFolder) { [weak self] event in
                Task {
                    await self?.handle(event: event, configuration: watchFolder, policy: config.automationPolicy)
                }
            }
            try monitor.start()
            monitors.append(monitor)
        }

        await sessionSupervisor.start(intervalSeconds: config.heartbeatIntervalSeconds) { [weak self] date in
            await self?.recordHeartbeat(date)
        }

        state?.status = "running"
        try await persistState()
    }

    private func handle(event: FolderEvent, configuration: WatchFolderConfig, policy: AutomationPolicy) async {
        state?.lastEventSummary = event.summary
        do {
            for action in configuration.actions {
                let record = try await dispatcher.dispatch(action, event: event, policy: policy)
                state?.lastExecutedAction = record
            }
            state?.lastError = nil
        } catch {
            state?.lastError = error.localizedDescription
        }

        do {
            try await persistState()
        } catch {
            state?.lastError = error.localizedDescription
        }
    }

    private func recordHeartbeat(_ date: Date) async {
        state?.lastHeartbeatAt = Self.iso8601String(date)
        do {
            try await persistState()
        } catch {
            state?.lastError = error.localizedDescription
        }
    }

    private func persistState() async throws {
        guard let state else {
            return
        }
        try await stateStore.write(state)
        await AgentRuntimeBridge.shared.update(runtimeState: state)
    }

    private func startPortholeLifecycle(config: AgentConfig) async throws {
        let lifecycle = PortholeLifecycleController(
            paths: paths,
            sproutBootstrapClient: sproutBootstrapClient,
            ingress: portholeIngressController,
            renewalService: renewalService,
            now: now,
            sleep: sleep
        )
        await lifecycle.start(
            config: config,
            onBootstrapRecord: { record in
                await self.recordSproutBootstrap(record)
            },
            onStatus: { status in
                await self.recordPortholeIngress(status)
            }
        )
        portholeLifecycleController = lifecycle
    }

    private func stopPortholeLifecycle() async {
        if let portholeLifecycleController {
            await portholeLifecycleController.stop()
            self.portholeLifecycleController = nil
        }
    }

    private func recordSproutBootstrap(_ bootstrapRecord: SproutBootstrapInvocationRecord?) async {
        state?.lastSproutBootstrap = bootstrapRecord
        let priorPortholeError = state?.portholeIngress?.lastError
        if let priorPortholeError, state?.lastError == priorPortholeError {
            state?.lastError = nil
        }
        try? await persistState()
    }

    private func recordPortholeIngress(_ status: PortholeIngressStatus) async {
        let priorPortholeError = state?.portholeIngress?.lastError
        state?.portholeIngress = status
        if let error = status.lastError, !error.isEmpty {
            state?.lastError = error
        } else if let priorPortholeError, state?.lastError == priorPortholeError {
            state?.lastError = nil
        }
        try? await persistState()
    }

    private func shouldEnablePortholeIngress(for config: AgentConfig) -> Bool {
        config.scaffold.startupMode == .join && config.scaffold.requestedPortholeKind == "native"
    }

    private func stopMonitors() {
        monitors.forEach { $0.stop() }
        monitors.removeAll()
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
