import Foundation
import HavenRuntimeBootstrap

private enum PortholeLifecycleEvent: Error {
    case renewalDue
    case connectionLost(String)
}

public actor PortholeLifecycleController {
    public typealias SleepFunction = @Sendable (TimeInterval) async -> Void
    public typealias StatusSink = @Sendable (PortholeIngressStatus) async -> Void
    public typealias BootstrapRecordSink = @Sendable (SproutBootstrapInvocationRecord?) async -> Void

    private let paths: RuntimePaths
    private let sproutBootstrapClient: SproutBootstrapClient
    private let ingress: any PortholeIngressControlling
    private let renewalService: ContractRenewalService
    private let now: @Sendable () -> Date
    private let sleep: SleepFunction

    private var task: Task<Void, Never>?
    private var currentArtifact: SproutBootstrapSessionArtifact?

    public init(
        paths: RuntimePaths,
        sproutBootstrapClient: SproutBootstrapClient,
        ingress: any PortholeIngressControlling,
        renewalService: ContractRenewalService,
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping SleepFunction = PortholeLifecycleController.defaultSleep
    ) {
        self.paths = paths
        self.sproutBootstrapClient = sproutBootstrapClient
        self.ingress = ingress
        self.renewalService = renewalService
        self.now = now
        self.sleep = sleep
    }

    public func start(
        config: AgentConfig,
        onBootstrapRecord: @escaping BootstrapRecordSink,
        onStatus: @escaping StatusSink
    ) async {
        guard task == nil else {
            return
        }

        await ingress.setStatusHandler { status in
            await onStatus(status)
        }

        task = Task {
            await self.runLoop(
                config: config,
                onBootstrapRecord: onBootstrapRecord
            )
        }
    }

    public func stop() async {
        let task = self.task
        self.task = nil
        task?.cancel()
        await ingress.disconnect()
        await renewalService.markStopped()
        if let task {
            await task.value
        }
    }

    private func runLoop(
        config: AgentConfig,
        onBootstrapRecord: @escaping BootstrapRecordSink
    ) async {
        var retryCount = 0

        while !Task.isCancelled {
            do {
                let artifact = try await bootstrapAndConnect(
                    config: config,
                    onBootstrapRecord: onBootstrapRecord
                )
                retryCount = 0
                await renewalService.markConnected(
                    contractID: artifact.session.contract.contract_id,
                    artifactExpiresAt: artifact.session.contract.expires_at
                )
                try await waitUntilRenewalOrDisconnect(
                    config: config,
                    artifact: artifact
                )
            } catch is CancellationError {
                break
            } catch PortholeLifecycleEvent.renewalDue {
                continue
            } catch {
                let retriable = isRetriable(error)
                retryCount += 1
                await scheduleRetry(
                    error: error,
                    retryCount: retryCount,
                    config: config,
                    retriable: retriable
                )
                if !retriable {
                    break
                }
            }
        }
    }

    private func bootstrapAndConnect(
        config: AgentConfig,
        onBootstrapRecord: @escaping BootstrapRecordSink
    ) async throws -> SproutBootstrapSessionArtifact {
        let bootstrapRecord = try await sproutBootstrapClient.run(config: config, paths: paths)
        await onBootstrapRecord(bootstrapRecord)

        let artifact = try SproutBootstrapArtifactLoader.loadNativeSession(
            from: bootstrapRecord?.artifactPath,
            now: now()
        )
        currentArtifact = artifact

        let renewedAt = Self.iso8601String(now())
        await renewalService.markRenewed(
            contractID: artifact.session.contract.contract_id,
            artifactExpiresAt: artifact.session.contract.expires_at,
            renewedAt: renewedAt
        )

        await ingress.reportLifecycleStatus(
            PortholeIngressStatus(
                phase: .connecting,
                contractID: artifact.session.contract.contract_id,
                bridgeEndpoint: artifact.session.nativeDescriptor?.bridge_endpoint,
                artifactExpiresAt: artifact.session.contract.expires_at,
                lastRenewedAt: renewedAt,
                lastMessageAt: nil,
                lastAcceptedIntentID: nil,
                lastRejectedReason: nil,
                nextRetryAt: nil,
                retryCount: nil,
                lastError: nil
            )
        )
        try await ingress.connect(using: artifact)
        return artifact
    }

    private func waitUntilRenewalOrDisconnect(
        config: AgentConfig,
        artifact: SproutBootstrapSessionArtifact
    ) async throws {
        let pollInterval = max(1, config.scaffold.portholeHealthPollSeconds)
        let leadTime = TimeInterval(max(0, config.scaffold.renewalLeadTimeSeconds))

        while !Task.isCancelled {
            let status = await ingress.statusSnapshot()
            switch status.phase {
            case .failed, .disconnected, .idle:
                throw PortholeLifecycleEvent.connectionLost(
                    status.lastError ?? status.phase.rawValue
                )
            case .connecting, .connected:
                break
            }

            if shouldRenew(artifact: artifact, leadTimeSeconds: leadTime, now: now()) {
                await renewalService.markRenewalDue(
                    contractID: artifact.session.contract.contract_id,
                    artifactExpiresAt: artifact.session.contract.expires_at
                )
                await ingress.disconnect()
                throw PortholeLifecycleEvent.renewalDue
            }

            await sleep(TimeInterval(pollInterval))
        }

        throw CancellationError()
    }

    private func scheduleRetry(
        error: Error,
        retryCount: Int,
        config: AgentConfig,
        retriable: Bool
    ) async {
        let currentStatus = await ingress.statusSnapshot()
        let delay = retriable ? backoffDelaySeconds(for: retryCount, config: config) : 0
        let nextRetryAt = retriable ? Self.iso8601String(now().addingTimeInterval(delay)) : nil
        let contractID = currentStatus.contractID ?? currentArtifact?.session.contract.contract_id
        let bridgeEndpoint = currentStatus.bridgeEndpoint ?? currentArtifact?.session.nativeDescriptor?.bridge_endpoint
        let artifactExpiresAt = currentStatus.artifactExpiresAt ?? currentArtifact?.session.contract.expires_at
        let lastRenewedAt = currentStatus.lastRenewedAt

        if retriable {
            await renewalService.markRetryScheduled(
                contractID: contractID,
                artifactExpiresAt: artifactExpiresAt,
                nextRetryAt: nextRetryAt,
                retryCount: retryCount,
                lastError: error.localizedDescription
            )
        } else {
            await renewalService.markFailed(
                contractID: contractID,
                artifactExpiresAt: artifactExpiresAt,
                lastError: error.localizedDescription
            )
        }

        await ingress.reportLifecycleStatus(
            PortholeIngressStatus(
                phase: .failed,
                contractID: contractID,
                bridgeEndpoint: bridgeEndpoint,
                artifactExpiresAt: artifactExpiresAt,
                lastRenewedAt: lastRenewedAt,
                lastMessageAt: currentStatus.lastMessageAt,
                lastAcceptedIntentID: currentStatus.lastAcceptedIntentID,
                lastRejectedReason: currentStatus.lastRejectedReason,
                nextRetryAt: nextRetryAt,
                retryCount: retriable ? retryCount : nil,
                lastError: error.localizedDescription
            )
        )

        if retriable {
            await sleep(delay)
        }
    }

    private func shouldRenew(
        artifact: SproutBootstrapSessionArtifact,
        leadTimeSeconds: TimeInterval,
        now: Date
    ) -> Bool {
        guard let expiry = ISO8601DateFormatter().date(from: artifact.session.contract.expires_at) else {
            return true
        }
        return now.addingTimeInterval(leadTimeSeconds) >= expiry
    }

    private func backoffDelaySeconds(
        for retryCount: Int,
        config: AgentConfig
    ) -> TimeInterval {
        let baseDelay = max(1, config.scaffold.portholeRetryBaseDelaySeconds)
        let maxDelay = max(baseDelay, config.scaffold.portholeRetryMaxDelaySeconds)
        let exponent = max(0, retryCount - 1)
        let rawDelay = Double(baseDelay) * pow(2.0, Double(exponent))
        return min(Double(maxDelay), rawDelay)
    }

    private func isRetriable(_ error: Error) -> Bool {
        switch error {
        case let error as SproutBootstrapClientError:
            switch error {
            case .missingPurposeGoalInterests, .missingResolverBaseURL, .invalidBinaryPath, .binaryNotExecutable, .conflictingEntityEvidence:
                return false
            }
        default:
            return true
        }
    }

    public static func defaultSleep(_ interval: TimeInterval) async {
        guard interval > 0 else {
            return
        }
        let nanoseconds = UInt64(interval * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
