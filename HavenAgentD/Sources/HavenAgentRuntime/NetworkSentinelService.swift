// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import HavenMacAutomation

/// Native measurement loop behind the NetworkSentinelCell.
///
/// Reads interface counter deltas (pps / throughput / interface errors) on a
/// fixed cadence, detects sustained floods, collapses a sustained condition into
/// ONE lifecycle event (started -> ongoing -> resolved), optionally triggers a
/// bounded `tcpdump` capture for evidence, and publishes a `NetworkHealthSnapshot`
/// to `AgentRuntimeBridge`. The actual flow emission and user notification are
/// delegated to the injected `sink` so the service owns no protocol/automation
/// semantics itself.
public actor NetworkSentinelService: NetworkSentinelControlling {
    /// Called on every publish. The event is non-nil only on a lifecycle
    /// transition (started / resolved) so the consumer can decide to alert.
    public typealias EventSink = @Sendable (NetworkHealthSnapshot, NetworkFloodEvent?) async -> Void

    private let interface: String
    private let intervalSeconds: Double
    private let captureDirectory: URL
    private let captureEnabled: Bool
    private let processRunner: any ProcessRunning
    private let maxRecentEvents: Int
    private let isoFormatter = ISO8601DateFormatter()

    private var thresholds: NetworkSentinelThresholds
    private var notificationsEnabled: Bool
    private var sink: EventSink?

    private var previous: InterfaceCounterReading?
    private var previousAt: Date?
    private var hotStreak = 0
    private var calmStreak = 0
    private var latest: NetworkHealthSample?
    private var activeEvent: NetworkFloodEvent?
    private var recentEvents: [NetworkFloodEvent] = []
    private var status = "starting"
    private var loopTask: Task<Void, Never>?

    public init(
        interface: String = "en0",
        thresholds: NetworkSentinelThresholds = .init(),
        intervalSeconds: Double = 2.0,
        notificationsEnabled: Bool = true,
        captureDirectory: URL,
        captureEnabled: Bool = true,
        processRunner: any ProcessRunning = FoundationProcessRunner(),
        maxRecentEvents: Int = 20
    ) {
        self.interface = interface
        self.thresholds = thresholds
        self.intervalSeconds = max(0.5, intervalSeconds)
        self.notificationsEnabled = notificationsEnabled
        self.captureDirectory = captureDirectory
        self.captureEnabled = captureEnabled
        self.processRunner = processRunner
        self.maxRecentEvents = max(1, maxRecentEvents)
    }

    // MARK: - Control

    public func setSink(_ sink: EventSink?) {
        self.sink = sink
    }

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    public func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    public func setNotificationsEnabled(_ enabled: Bool) async {
        notificationsEnabled = enabled
        await publish(transition: nil)
    }

    public func setThresholds(_ newThresholds: NetworkSentinelThresholds) async {
        thresholds = newThresholds
        await publish(transition: nil)
    }

    @discardableResult
    public func acknowledgeActiveEvent() async -> Bool {
        guard activeEvent != nil else { return false }
        activeEvent?.acknowledged = true
        if let id = activeEvent?.id, let idx = recentEvents.firstIndex(where: { $0.id == id }) {
            recentEvents[idx].acknowledged = true
        }
        await publish(transition: nil)
        return true
    }

    public func snapshot() -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(
            interface: interface,
            status: status,
            latest: latest,
            activeEvent: activeEvent,
            recentEvents: recentEvents,
            notificationsEnabled: notificationsEnabled,
            thresholds: thresholds,
            updatedAt: isoFormatter.string(from: Date())
        )
    }

    public var isNotificationsEnabled: Bool { notificationsEnabled }

    // MARK: - Loop

    private func runLoop() async {
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }
    }

    private func tick() async {
        guard let reading = InterfaceCounters.read(interface: interface) else {
            status = "unavailable"
            await publish(transition: nil)
            return
        }
        let now = Date()
        defer { previous = reading; previousAt = now }

        guard let previous, let previousAt else {
            status = "calm"
            return
        }

        let dt = max(now.timeIntervalSince(previousAt), 0.001)
        let sample = NetworkHealthSample(
            interface: interface,
            packetsPerSecond: perSecond(reading.ipackets &- previous.ipackets, plus: reading.opackets &- previous.opackets, over: dt),
            bytesPerSecondIn: perSecond(reading.ibytes &- previous.ibytes, over: dt),
            bytesPerSecondOut: perSecond(reading.obytes &- previous.obytes, over: dt),
            inputErrorsPerSecond: perSecond(reading.ierrors &- previous.ierrors, over: dt),
            outputErrorsPerSecond: perSecond(reading.oerrors &- previous.oerrors, over: dt),
            sampledAt: isoFormatter.string(from: now)
        )
        latest = sample

        let isHot = sample.packetsPerSecond >= thresholds.packetsPerSecond
            || sample.megabitsPerSecond >= thresholds.megabitsPerSecond
            || sample.errorsPerSecond >= thresholds.errorsPerSecond

        if isHot {
            hotStreak += 1
            calmStreak = 0
        } else {
            calmStreak += 1
            hotStreak = 0
        }

        if activeEvent == nil {
            status = "calm"
            if hotStreak >= thresholds.sustainedSamples {
                await beginEvent(with: sample, at: now)
            } else {
                await publish(transition: nil)
            }
        } else {
            status = "flooding"
            updateActiveEvent(with: sample, at: now)
            if calmStreak >= thresholds.resolveSamples {
                await resolveActiveEvent(at: now)
            } else {
                await publish(transition: nil)
            }
        }
    }

    // MARK: - Event lifecycle

    private func beginEvent(with sample: NetworkHealthSample, at now: Date) async {
        let timestamp = isoFormatter.string(from: now)
        let classification = classify(sample)
        let eventID = UUID().uuidString
        let capturePath = captureEnabled
            ? captureDirectory.appendingPathComponent("flood-\(eventID).pcap").path
            : nil

        let event = NetworkFloodEvent(
            id: eventID,
            phase: .started,
            classification: classification,
            startedAt: timestamp,
            updatedAt: timestamp,
            peakPacketsPerSecond: sample.packetsPerSecond,
            peakMegabitsPerSecond: sample.megabitsPerSecond,
            capturePath: capturePath,
            summary: summarize(sample, classification: classification),
            acknowledged: false
        )
        activeEvent = event
        status = "flooding"
        appendRecent(event)
        triggerCaptureIfEnabled(eventID: eventID)
        await publish(transition: event)
    }

    private func updateActiveEvent(with sample: NetworkHealthSample, at now: Date) {
        guard var event = activeEvent else { return }
        event.phase = .ongoing
        event.updatedAt = isoFormatter.string(from: now)
        event.peakPacketsPerSecond = max(event.peakPacketsPerSecond, sample.packetsPerSecond)
        event.peakMegabitsPerSecond = max(event.peakMegabitsPerSecond, sample.megabitsPerSecond)
        // Sharpen classification if the picture changed (e.g. errors appeared).
        if event.classification == .unknown || event.classification == .bulkDownload {
            let refined = classify(sample)
            if refined == .interfaceDistress { event.classification = refined }
        }
        event.summary = summarize(sample, classification: event.classification)
        activeEvent = event
        if let idx = recentEvents.firstIndex(where: { $0.id == event.id }) {
            recentEvents[idx] = event
        }
    }

    private func resolveActiveEvent(at now: Date) async {
        guard var event = activeEvent else { return }
        event.phase = .resolved
        event.resolvedAt = isoFormatter.string(from: now)
        event.updatedAt = event.resolvedAt ?? event.updatedAt
        activeEvent = nil
        status = "calm"
        if let idx = recentEvents.firstIndex(where: { $0.id == event.id }) {
            recentEvents[idx] = event
        }
        await publish(transition: event)
    }

    private func appendRecent(_ event: NetworkFloodEvent) {
        recentEvents.append(event)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeFirst(recentEvents.count - maxRecentEvents)
        }
    }

    // MARK: - Classification

    private func classify(_ sample: NetworkHealthSample) -> NetworkFloodClass {
        if sample.errorsPerSecond >= thresholds.errorsPerSecond {
            return .interfaceDistress
        }
        if sample.packetsPerSecond >= thresholds.packetsPerSecond && sample.megabitsPerSecond < 20 {
            return .highPacketRate
        }
        if sample.bytesPerSecondIn > sample.bytesPerSecondOut * 4 {
            return .bulkDownload
        }
        if sample.bytesPerSecondOut > sample.bytesPerSecondIn * 4 {
            return .bulkUpload
        }
        return .unknown
    }

    private func summarize(_ sample: NetworkHealthSample, classification: NetworkFloodClass) -> String {
        let mbps = String(format: "%.1f", sample.megabitsPerSecond)
        return "\(interface): \(sample.packetsPerSecond) pk/s, \(mbps) Mbps, \(sample.errorsPerSecond) err/s (\(classification.rawValue))"
    }

    // MARK: - Capture

    private func triggerCaptureIfEnabled(eventID: String) {
        guard captureEnabled else { return }
        let directory = captureDirectory
        let iface = interface
        let runner = processRunner
        let path = directory.appendingPathComponent("flood-\(eventID).pcap").path
        // Detached so a capture never blocks the measurement loop. Bounded by
        // packet count: we only get here after sustained high pps, so the count
        // fills (and tcpdump exits) within a couple of seconds.
        Task.detached {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            _ = try? await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/sbin/tcpdump"),
                arguments: ["-i", iface, "-n", "-s", "160", "-c", "20000", "-w", path]
            )
        }
    }

    // MARK: - Publish

    private func publish(transition event: NetworkFloodEvent?) async {
        let snapshot = snapshot()
        await AgentRuntimeBridge.shared.update(networkHealth: snapshot)
        if let sink {
            await sink(snapshot, event)
        }
    }

    private func perSecond(_ delta: UInt64, plus other: UInt64 = 0, over seconds: Double) -> Int {
        let total = Double(delta &+ other)
        return max(0, Int(total / seconds))
    }
}
