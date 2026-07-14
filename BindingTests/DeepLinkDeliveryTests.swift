// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

@Suite(.serialized)
@MainActor
struct DeepLinkDeliveryTests {
    @Test
    func runtimeCatalogDiscoveryContinuesPastUnavailableConfiguredSource() async throws {
        let goodRoutes: ValueType = .list([
            .object([
                "schema": .string(BindingRuntimeSurfaceLaunchSupport.registrySchema),
                "surfaceID": .string("runtime-only"),
                "enabled": .bool(true),
                "published": .bool(true),
                "configurationLookup": .object([
                    "name": .string("Runtime Surface")
                ])
            ])
        ])

        let result = await BindingRuntimeSurfaceLaunchSupport.discoverCatalogCandidates(
            surfaceID: "runtime-only",
            catalogEndpoints: [
                "cell://unavailable.example/ConfigurationCatalog",
                "cell://healthy.example/ConfigurationCatalog"
            ]
        ) { catalogEndpoint, _ in
            if catalogEndpoint.contains("unavailable") {
                throw URLError(.cannotConnectToHost)
            }
            return goodRoutes
        }

        #expect(result.failedSourceCount == 1)
        #expect(result.candidates.count == 1)
        #expect(result.candidates.first?.catalogEndpoint == "cell://healthy.example/ConfigurationCatalog")
    }

    @Test
    func partialSourceRecoveryKeepsAuthorizedConfigurationWhenSiblingKeypathIsDenied() throws {
        let configuration = CellConfiguration(name: "Recovered Runtime Surface")
        let values: [String: ValueType] = [
            "skeletonConfiguration": .cellConfiguration(configuration)
        ]

        let decision = PortableSurfaceContractSupport.recoveryDecision(
            values: values,
            orderedKeypaths: ["skeletonConfiguration", "purposeGoal", "configuration"],
            authorizationDenied: true
        )

        guard case let .live(recovered) = decision else {
            Issue.record("An authorized live configuration must win over a denied sibling keypath")
            return
        }
        #expect(recovered.name == configuration.name)
    }

    @Test func coldStartURLIsLeasedExactlyOnceAndAcknowledged() throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }

        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=runtime-only&intent=view"))
        let center = NotificationCenter()
#if os(iOS)
        let sceneID: UUID? = UUID()
#else
        let sceneID: UUID? = nil
#endif
        #expect(BindingIncomingURLBridge.post(url: url, targetSceneID: sceneID, notificationCenter: center))

        #expect(BindingIncomingURLBridge.pendingCount() == 1)
        let firstConsumer = UUID()
        let secondConsumer = UUID()
        let leased = BindingIncomingURLBridge.leasePending(
            consumerID: firstConsumer,
            hostingWindowNumber: nil,
            hostingSceneID: sceneID
        )
        #expect(leased.count == 1)
        #expect(leased.first?.event.url == url)
        #expect(BindingIncomingURLBridge.leasePending(
            consumerID: secondConsumer,
            hostingWindowNumber: nil,
            hostingSceneID: sceneID
        ).isEmpty)

        let lease = try #require(leased.first)
        BindingIncomingURLBridge.acknowledge(lease, consumerID: secondConsumer)
        #expect(BindingIncomingURLBridge.pendingCount() == 1)
        BindingIncomingURLBridge.acknowledge(lease, consumerID: firstConsumer)
        #expect(BindingIncomingURLBridge.pendingCount() == 0)
    }

    @Test func targetedURLWaitsForTheMatchingWindow() throws {
#if canImport(AppKit)
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }

        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=window-route&intent=view"))
        #expect(BindingIncomingURLBridge.post(
            url: url,
            targetWindowNumber: 314,
            notificationCenter: NotificationCenter()
        ))

        #expect(BindingIncomingURLBridge.leasePending(
            consumerID: UUID(),
            hostingWindowNumber: 271
        ).isEmpty)
        let matching = BindingIncomingURLBridge.leasePending(
            consumerID: UUID(),
            hostingWindowNumber: 314
        )
        #expect(matching.count == 1)
#endif
    }

    @Test func saturatedBridgeRejectsNewURLWithoutDroppingAcceptedEvents() throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }
        let center = NotificationCenter()
        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=saturated&intent=view"))

        for _ in 0..<32 {
            #expect(BindingIncomingURLBridge.post(url: url, notificationCenter: center))
        }
        #expect(BindingIncomingURLBridge.pendingCount() == 32)
        #expect(!BindingIncomingURLBridge.post(url: url, notificationCenter: center))
        #expect(BindingIncomingURLBridge.pendingCount() == 32)
    }

    @Test func stalePendingURLExpiresBeforeItCanExhaustOrReachAReusedScene() throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=stale&intent=view"))
        #expect(BindingIncomingURLBridge.post(
            url: url,
            targetWindowNumber: 314,
            targetSceneID: UUID(),
            now: startedAt,
            notificationCenter: NotificationCenter()
        ))
        #expect(BindingIncomingURLBridge.pendingCount(now: startedAt) == 1)
        #expect(BindingIncomingURLBridge.pendingCount(now: startedAt.addingTimeInterval(301)) == 0)
    }

    @Test func queueFailureRetainsItsSceneTarget() async throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }
        let center = NotificationCenter()
        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=full&intent=view"))
        for _ in 0..<32 {
            #expect(BindingIncomingURLBridge.post(url: url, notificationCenter: center))
        }
        let targetSceneID = UUID()
        let recorder = IncomingURLDeliveryFailureRecorder()
        let observer = center.addObserver(
            forName: BindingIncomingURLBridge.deliveryFailureNotificationName,
            object: nil,
            queue: nil
        ) { notification in
            recorder.record(BindingIncomingURLBridge.deliveryFailure(from: notification))
        }
        defer { center.removeObserver(observer) }

        BindingIncomingURLBridge.submit(
            url: url,
            targetSceneID: targetSceneID,
            notificationCenter: center,
            retryDelays: []
        )
        await Task.yield()
        await Task.yield()

        let failure = try #require(recorder.failure())
        #expect(failure.reason == "incoming_url_queue_full")
        #expect(failure.targetSceneID == targetSceneID)
    }

    @Test func deliveryFailureTargetsOnlyItsHostingWindow() {
#if canImport(AppKit)
        let failure = BindingIncomingURLDeliveryFailure(
            reason: "incoming_url_queue_full",
            targetWindowNumber: 314,
            targetSceneID: nil
        )
        #expect(RootView.matchesDeliveryFailureTarget(
            failure,
            hostingWindowNumber: 314,
            hostingSceneID: UUID(),
            activeWindowNumber: 314
        ))
        #expect(!RootView.matchesDeliveryFailureTarget(
            failure,
            hostingWindowNumber: 271,
            hostingSceneID: UUID(),
            activeWindowNumber: 314
        ))
#endif
    }

    @Test func expiredLeaseCanBeReclaimedAndStaleTokenCannotAcknowledge() throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }
        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=reclaim&intent=view"))
        let startedAt = Date(timeIntervalSince1970: 10)
#if os(iOS)
        let sceneID: UUID? = UUID()
#else
        let sceneID: UUID? = nil
#endif
        #expect(BindingIncomingURLBridge.post(
            url: url,
            targetSceneID: sceneID,
            now: startedAt,
            notificationCenter: NotificationCenter()
        ))

        let firstConsumer = UUID()
        let firstLease = try #require(BindingIncomingURLBridge.leasePending(
            consumerID: firstConsumer,
            hostingWindowNumber: nil,
            hostingSceneID: sceneID,
            now: startedAt
        ).first)
        let secondConsumer = UUID()
        let reclaimed = try #require(BindingIncomingURLBridge.leasePending(
            consumerID: secondConsumer,
            hostingWindowNumber: nil,
            hostingSceneID: sceneID,
            now: startedAt.addingTimeInterval(91)
        ).first)

        BindingIncomingURLBridge.acknowledge(firstLease, consumerID: firstConsumer)
        #expect(BindingIncomingURLBridge.pendingCount() == 1)
        BindingIncomingURLBridge.acknowledge(reclaimed, consumerID: secondConsumer)
        #expect(BindingIncomingURLBridge.pendingCount() == 0)
    }

    @Test func routeQueuePreservesFIFOWhenEarlierWorkIsSlower() async {
        let queue = BindingRuntimeRouteQueue()
        var order: [String] = []

        queue.enqueue { _ in
            try? await Task.sleep(for: .milliseconds(60))
            order.append("slow-first")
        }
        queue.enqueue { _ in
            order.append("fast-second")
        }

        await queue.waitForIdle()
        #expect(order == ["slow-first", "fast-second"])
    }

    @Test func configurationLoadsNeverOverlapAndLatestRequestWins() async {
        let coordinator = BindingSerializedConfigurationLoadCoordinator()
        let gate = CancellationIgnoringRouteGate()
        var activeLoads = 0
        var maximumActiveLoads = 0
        var finalConfiguration = ""

        coordinator.enqueue {
            activeLoads += 1
            maximumActiveLoads = max(maximumActiveLoads, activeLoads)
            await gate.wait()
            finalConfiguration = "first"
            activeLoads -= 1
        }
        await Task.yield()

        let latest = coordinator.enqueue {
            activeLoads += 1
            maximumActiveLoads = max(maximumActiveLoads, activeLoads)
            finalConfiguration = "second"
            activeLoads -= 1
        }
        await Task.yield()
        #expect(maximumActiveLoads == 1)
        #expect(finalConfiguration.isEmpty)

        await gate.open()
        await latest.value
        #expect(maximumActiveLoads == 1)
        #expect(activeLoads == 0)
        #expect(finalConfiguration == "second")
    }

    @Test func timedOutRouteDoesNotBlockFollowingWork() async {
        let queue = BindingRuntimeRouteQueue(operationTimeout: .milliseconds(20))
        let gate = CancellationIgnoringRouteGate()
        var order: [String] = []
        var outcomes: [BindingRuntimeRouteQueue.Outcome] = []

        queue.enqueue { execution in
            await gate.wait()
            execution.commit {
                order.append("late")
            }
        } completion: { outcome in
            outcomes.append(outcome)
        }
        queue.enqueue { _ in
            order.append("second")
        } completion: { outcome in
            outcomes.append(outcome)
        }

        await queue.waitForIdle()
        #expect(order == ["second"])
        #expect(outcomes == [.timedOut, .completed])
        await gate.open()
        await Task.yield()
        #expect(order == ["second"])
    }

    @Test func timedOutRouteCancelsItsUnstructuredConfigurationLoad() async {
        let queue = BindingRuntimeRouteQueue(operationTimeout: .milliseconds(20))
        let coordinator = BindingSerializedConfigurationLoadCoordinator()
        var loadObservedCancellation = false

        queue.enqueue { _ in
            let load = coordinator.enqueue {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    loadObservedCancellation = true
                }
            }
            await withTaskCancellationHandler {
                await load.value
            } onCancel: {
                load.cancel()
            }
        }

        await queue.waitForIdle()
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while !loadObservedCancellation && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(loadObservedCancellation)
    }

    @Test func lifecycleCancellationReleasesLeasesAndRestartsWithOneWorker() async throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }

        let firstURL = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=first&intent=view"))
        let secondURL = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=second&intent=view"))
        let center = NotificationCenter()
#if os(iOS)
        let sceneID: UUID? = UUID()
#else
        let sceneID: UUID? = nil
#endif
        #expect(BindingIncomingURLBridge.post(url: firstURL, targetSceneID: sceneID, notificationCenter: center))
        #expect(BindingIncomingURLBridge.post(url: secondURL, targetSceneID: sceneID, notificationCenter: center))

        let consumer = UUID()
        let leases = BindingIncomingURLBridge.leasePending(
            consumerID: consumer,
            hostingWindowNumber: nil,
            hostingSceneID: sceneID
        )
        #expect(leases.count == 2)

        let queue = BindingRuntimeRouteQueue(operationTimeout: .seconds(5))
        let gate = CancellationIgnoringRouteGate()
        var executed: [String] = []
        for (index, lease) in leases.enumerated() {
            queue.enqueue { execution in
                if index == 0 {
                    await gate.wait()
                }
                execution.commit {
                    executed.append(index == 0 ? "first" : "second")
                }
            } completion: { outcome in
                if outcome == .completed {
                    BindingIncomingURLBridge.acknowledge(lease, consumerID: consumer)
                } else {
                    BindingIncomingURLBridge.release(lease, consumerID: consumer)
                }
            }
        }

        await Task.yield()
        queue.cancelAll()
        #expect(queue.enqueue { _ in
            executed.append("replacement")
        })
        await queue.waitForIdle()

        #expect(executed == ["replacement"])
        #expect(BindingIncomingURLBridge.pendingCount() == 2)
        #expect(BindingIncomingURLBridge.leaseCount() == 0)
        let recovered = BindingIncomingURLBridge.leasePending(
            consumerID: UUID(),
            hostingWindowNumber: nil,
            hostingSceneID: sceneID
        )
        #expect(recovered.count == 2)

        await gate.open()
        await Task.yield()
    }

    @Test func nextRunnableLeaseKeepsThreeEventBacklogDistinctAcrossLeaseWindow() throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }

        let startedAt = Date(timeIntervalSince1970: 1_000)
        let center = NotificationCenter()
#if os(iOS)
        let sceneID: UUID? = UUID()
#else
        let sceneID: UUID? = nil
#endif
        let urls = try (1...3).map { index in
            try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=sequential-\(index)&intent=view"))
        }
        for url in urls {
            #expect(BindingIncomingURLBridge.post(
                url: url,
                targetSceneID: sceneID,
                now: startedAt,
                notificationCenter: center
            ))
        }

        let consumer = UUID()
        var delivered: [URL] = []
        for (index, now) in [startedAt, startedAt.addingTimeInterval(20), startedAt.addingTimeInterval(40)].enumerated() {
            let lease = try #require(BindingIncomingURLBridge.leaseNextPending(
                consumerID: consumer,
                hostingWindowNumber: nil,
                hostingSceneID: sceneID,
                now: now
            ))
            #expect(BindingIncomingURLBridge.leaseCount() == 1)
            delivered.append(lease.event.url)
            BindingIncomingURLBridge.acknowledge(lease, consumerID: consumer)
            #expect(BindingIncomingURLBridge.pendingCount() == 2 - index)
        }

        #expect(delivered == urls)
        #expect(BindingIncomingURLBridge.leaseCount() == 0)
        #expect(BindingIncomingURLBridge.pendingCount() == 0)
    }

#if os(iOS)
    @Test func sceneTargetedURLCanOnlyBeLeasedByIntendedScene() throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }
        let intendedScene = UUID()
        let otherScene = UUID()
        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=scene&intent=view"))
        #expect(BindingIncomingURLBridge.post(
            url: url,
            targetSceneID: intendedScene,
            notificationCenter: NotificationCenter()
        ))
        #expect(BindingIncomingURLBridge.leasePending(
            consumerID: UUID(),
            hostingWindowNumber: nil,
            hostingSceneID: otherScene
        ).isEmpty)
        #expect(BindingIncomingURLBridge.leasePending(
            consumerID: UUID(),
            hostingWindowNumber: nil,
            hostingSceneID: intendedScene
        ).count == 1)
    }
#endif

    @Test func disabledAutomationDiagnosticNeverIncludesQueryValues() throws {
        let url = try #require(URL(string: "haven://conference-automation?action=open-launcher&token=do-not-log-me"))
        #expect(ContentView.conferenceAutomationHook(from: url) == nil)
        let hook = ContentView.ConferenceAutomationHook.openLauncher
        let diagnostic = ContentView.conferenceAutomationDisabledDiagnostic(for: hook)

        #expect(diagnostic.contains("open-launcher"))
        #expect(!diagnostic.contains("do-not-log-me"))
        #expect(!diagnostic.contains("token"))
    }

    @Test func catalogBootstrapRoutesCanBeReconfiguredWithoutCompilation() {
        let customOnly = BindingRuntimeSurfaceLaunchSupport.configuredRemoteCatalogEndpoints(
            environment: [
                "BINDING_REMOTE_CATALOG_ENDPOINTS": "cell://runtime.example/ConfigurationCatalog",
                "BINDING_INCLUDE_DEFAULT_REMOTE_CATALOG": "false"
            ],
            defaultEndpoint: "cell://compiled.example/ConfigurationCatalog"
        )
        #expect(customOnly == ["cell://runtime.example/ConfigurationCatalog"])

        let replacedDefault = BindingRuntimeSurfaceLaunchSupport.configuredRemoteCatalogEndpoints(
            environment: [
                "BINDING_DEFAULT_REMOTE_CATALOG_ENDPOINT": "cell://owner.example/ConfigurationCatalog"
            ],
            defaultEndpoint: "cell://compiled.example/ConfigurationCatalog"
        )
        #expect(replacedDefault == ["cell://owner.example/ConfigurationCatalog"])
    }
}

private actor CancellationIgnoringRouteGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            if isOpen {
                continuation.resume()
            } else {
                self.continuation = continuation
            }
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private final class IncomingURLDeliveryFailureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedFailure: BindingIncomingURLDeliveryFailure?

    func record(_ failure: BindingIncomingURLDeliveryFailure?) {
        lock.lock()
        storedFailure = failure
        lock.unlock()
    }

    func failure() -> BindingIncomingURLDeliveryFailure? {
        lock.lock()
        defer { lock.unlock() }
        return storedFailure
    }
}
