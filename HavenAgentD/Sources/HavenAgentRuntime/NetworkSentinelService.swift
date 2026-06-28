// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation

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
    private let captureDurationSeconds: Double
    private let capturePacketLimit: Int
    private let captureSnaplen: Int
    private let maxRecentEvents: Int
    private let counterProvider: @Sendable (String) -> InterfaceCounterReading?
    /// Monotonic uptime clock (DispatchTime uptime, matching `SystemMonotonicTimeSource`)
    /// used for ALL duration math — immune to wall-clock jumps (NTP step, DST, manual
    /// clock changes). Injectable so tests can drive deterministic elapsed time.
    private let uptimeNanos: @Sendable () -> UInt64
    private let isoFormatter = ISO8601DateFormatter()

    private var thresholds: NetworkSentinelThresholds
    private var notificationsEnabled: Bool
    private var sink: EventSink?

    private var previous: InterfaceCounterReading?
    private var previousMonotonicNanos: UInt64?
    private var hotStreak = 0
    private var calmStreak = 0
    private var latest: NetworkHealthSample?
    private var activeEvent: NetworkFloodEvent?
    private var recentEvents: [NetworkFloodEvent] = []
    private var status = "starting"
    private var recentSamples: [NetworkHealthSample] = []
    private var interfaces: [InterfaceInfo] = []
    private var activeTab = "dashboard"
    private var probeTarget = "192.168.1.1:443"
    private var probeResult: String?
    private var lastCaptureSummary: String?
    private let reachabilityProbe = NetworkReachabilityProbe()
    private let maxRecentSamples = 60
    private var pendingListenDurationNanos: UInt64?
    private var listenStartMonotonic: UInt64?
    private var listenDurationNanos: UInt64 = 0
    private var listenStartWall: String = ""
    private var listenSamples: [NetworkHealthSample] = []
    private var listenSummary: NetworkListenSummary?
    private var loopTask: Task<Void, Never>?

    public init(
        interface: String = "en0",
        thresholds: NetworkSentinelThresholds = .init(),
        intervalSeconds: Double = 2.0,
        notificationsEnabled: Bool = true,
        captureDirectory: URL,
        captureEnabled: Bool = true,
        captureDurationSeconds: Double = 12.0,
        capturePacketLimit: Int = 20_000,
        captureSnaplen: Int = 160,
        maxRecentEvents: Int = 20,
        counterProvider: @escaping @Sendable (String) -> InterfaceCounterReading? = { InterfaceCounters.read(interface: $0) },
        uptimeNanos: @escaping @Sendable () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }
    ) {
        self.interface = interface
        self.thresholds = thresholds
        self.intervalSeconds = max(0.5, intervalSeconds)
        self.notificationsEnabled = notificationsEnabled
        self.captureDirectory = captureDirectory
        self.captureEnabled = captureEnabled
        self.captureDurationSeconds = max(1.0, captureDurationSeconds)
        self.capturePacketLimit = max(1, capturePacketLimit)
        self.captureSnaplen = max(64, captureSnaplen)
        self.maxRecentEvents = max(1, maxRecentEvents)
        self.counterProvider = counterProvider
        self.uptimeNanos = uptimeNanos
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

    public func setActiveTab(_ tabID: String) async {
        let trimmed = tabID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false { activeTab = trimmed }
        await publish(transition: nil)
    }

    public func setProbeTarget(_ target: String) async {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false { probeTarget = trimmed }
        await publish(transition: nil)
    }

    public func runProbe() async -> String {
        let (host, port) = NetworkReachabilityProbe.parseTarget(probeTarget)
        let result = await reachabilityProbe.probe(host: host, port: port)
        probeResult = result
        await publish(transition: nil)
        return result
    }

    public func captureNow() async -> String {
        guard captureEnabled else {
            let message = "Capture er deaktivert i config."
            lastCaptureSummary = message
            await publish(transition: nil)
            return message
        }
        let stamp = String(Int(Date().timeIntervalSince1970))
        let path = captureDirectory.appendingPathComponent("manual-\(stamp).pcap").path
        let capture = BoundedPacketCapture(snaplen: captureSnaplen)
        let duration = captureDurationSeconds
        let limit = capturePacketLimit
        let iface = interface
        // Detached so the button returns immediately; the capture runs bounded.
        Task.detached {
            await capture.capture(interface: iface, outputPath: path, durationSeconds: duration, packetLimit: limit)
        }
        let message = "Capture startet (\(Int(captureDurationSeconds))s, maks \(capturePacketLimit) pk) → \(path)"
        lastCaptureSummary = message
        await publish(transition: nil)
        return message
    }

    // MARK: - Native windowed self-test (runListen)

    public func runListen(minutes: Int) async -> String {
        let mins = max(1, min(minutes, 180))
        pendingListenDurationNanos = UInt64(Double(mins) * 60.0 * 1_000_000_000.0)
        listenStartMonotonic = nil
        listenSamples.removeAll()
        listenStartWall = isoFormatter.string(from: Date())
        listenSummary = NetworkListenSummary(
            interface: interface,
            status: "running",
            startedAt: listenStartWall,
            durationSeconds: mins * 60
        )
        await publish(transition: nil)
        return "Lytt startet — \(mins) min på \(interface). Hent listenSummary når vinduet er ute."
    }

    private func accumulateListen(sample: NetworkHealthSample, monotonicNanos: UInt64, wallClock: Date) {
        if let pending = pendingListenDurationNanos, listenStartMonotonic == nil {
            listenStartMonotonic = monotonicNanos
            listenDurationNanos = pending
            pendingListenDurationNanos = nil
        }
        guard let start = listenStartMonotonic else { return }
        listenSamples.append(sample)
        if (monotonicNanos &- start) >= listenDurationNanos {
            finalizeListen(at: wallClock)
        }
    }

    private func finalizeListen(at wallClock: Date) {
        let samples = listenSamples
        let count = samples.count
        let avgPps = count == 0 ? 0 : samples.reduce(0) { $0 + $1.packetsPerSecond } / count
        let peakSample = samples.max(by: { $0.packetsPerSecond < $1.packetsPerSecond })
        let avgMbps = count == 0 ? 0 : samples.reduce(0.0) { $0 + $1.megabitsPerSecond } / Double(count)
        let peakMbps = samples.map(\.megabitsPerSecond).max() ?? 0

        var bucketPps: [Int: [Int]] = [:]
        var bucketMbps: [Int: [Double]] = [:]
        for (index, sample) in samples.enumerated() {
            let minute = Int(Double(index) * intervalSeconds / 60.0)
            bucketPps[minute, default: []].append(sample.packetsPerSecond)
            bucketMbps[minute, default: []].append(sample.megabitsPerSecond)
        }
        let perMinute = bucketPps.keys.sorted().map { minute -> PerMinuteRate in
            let pps = bucketPps[minute] ?? []
            let mbps = bucketMbps[minute] ?? []
            return PerMinuteRate(
                minute: minute,
                packetsPerSecond: pps.isEmpty ? 0 : pps.reduce(0, +) / pps.count,
                megabitsPerSecond: mbps.isEmpty ? 0 : mbps.reduce(0.0, +) / Double(mbps.count)
            )
        }

        // Flood events that started inside the window (ISO8601 sorts lexicographically).
        let windowEvents = recentEvents.filter { $0.startedAt >= listenStartWall }

        listenSummary = NetworkListenSummary(
            interface: interface,
            status: "complete",
            startedAt: listenStartWall,
            finishedAt: isoFormatter.string(from: wallClock),
            durationSeconds: Int(Double(listenDurationNanos) / 1_000_000_000.0),
            totalSamples: count,
            averagePacketsPerSecond: avgPps,
            peakPacketsPerSecond: peakSample?.packetsPerSecond ?? 0,
            peakAt: peakSample?.sampledAt,
            averageMegabitsPerSecond: avgMbps,
            peakMegabitsPerSecond: peakMbps,
            perMinute: perMinute,
            floodEventCount: windowEvents.count,
            floodSummaries: windowEvents.map(\.summary),
            capturePaths: windowEvents.compactMap(\.capturePath)
        )
        listenStartMonotonic = nil
        listenSamples.removeAll()
    }

    public func snapshot() -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(
            interface: interface,
            status: status,
            latest: latest,
            activeEvent: activeEvent,
            recentEvents: recentEvents,
            recentSamples: recentSamples,
            interfaces: interfaces,
            notificationsEnabled: notificationsEnabled,
            thresholds: thresholds,
            activeTab: activeTab,
            probeTarget: probeTarget,
            probeResult: probeResult,
            lastCaptureSummary: lastCaptureSummary,
            listenSummary: listenSummary,
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
        await ingest(
            reading: counterProvider(interface),
            monotonicNanos: uptimeNanos(),
            wallClock: Date()
        )
    }

    /// Core measurement step. Exposed (internal) so tests can drive deterministic
    /// readings without the timer or live hardware.
    ///
    /// `monotonicNanos` MUST come from an uptime clock (never wall-clock): rate math
    /// divides packet/byte deltas by the elapsed interval, so a wall-clock jump
    /// (NTP step, DST transition, manual clock change) would otherwise yield a bogus
    /// rate — a phantom flood or a missed one. `wallClock` is used ONLY for the
    /// human-readable display timestamps, never for any duration computation.
    func ingest(reading maybeReading: InterfaceCounterReading?, monotonicNanos: UInt64, wallClock: Date) async {
        guard let reading = maybeReading else {
            status = "unavailable"
            await publish(transition: nil)
            return
        }
        defer { previous = reading; previousMonotonicNanos = monotonicNanos }
        interfaces = InterfaceCounters.allInterfaces()

        guard let previous, let previousMonotonicNanos else {
            status = "calm"
            return
        }

        let elapsedNanos = monotonicNanos &- previousMonotonicNanos
        let dt = max(Double(elapsedNanos) / 1_000_000_000.0, 0.001)
        let sample = NetworkHealthSample(
            interface: interface,
            packetsPerSecond: perSecond(counterDelta(reading.ipackets, previous.ipackets), plus: counterDelta(reading.opackets, previous.opackets), over: dt),
            bytesPerSecondIn: perSecond(counterDelta(reading.ibytes, previous.ibytes), over: dt),
            bytesPerSecondOut: perSecond(counterDelta(reading.obytes, previous.obytes), over: dt),
            inputErrorsPerSecond: perSecond(counterDelta(reading.ierrors, previous.ierrors), over: dt),
            outputErrorsPerSecond: perSecond(counterDelta(reading.oerrors, previous.oerrors), over: dt),
            sampledAt: isoFormatter.string(from: wallClock)
        )
        latest = sample
        recentSamples.append(sample)
        if recentSamples.count > maxRecentSamples {
            recentSamples.removeFirst(recentSamples.count - maxRecentSamples)
        }
        accumulateListen(sample: sample, monotonicNanos: monotonicNanos, wallClock: wallClock)

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
                await beginEvent(with: sample, at: wallClock)
            } else {
                await publish(transition: nil)
            }
        } else {
            status = "flooding"
            updateActiveEvent(with: sample, at: wallClock)
            if calmStreak >= thresholds.resolveSamples {
                await resolveActiveEvent(at: wallClock)
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
        let iface = interface
        let path = captureDirectory.appendingPathComponent("flood-\(eventID).pcap").path
        let capture = BoundedPacketCapture(snaplen: captureSnaplen)
        let duration = captureDurationSeconds
        let limit = capturePacketLimit
        // Detached so the capture never blocks the measurement loop. Bounded by BOTH
        // packet count and a hard monotonic wall-clock duration, so it cannot hang.
        Task.detached {
            await capture.capture(
                interface: iface,
                outputPath: path,
                durationSeconds: duration,
                packetLimit: limit
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

    /// Wrap-aware counter delta. `getifaddrs` exposes 32-bit interface counters
    /// (`if_data` uses `u_int32_t`), so byte counters roll over every 4 GB at
    /// sustained throughput. A raw subtraction underflows into an astronomical
    /// value; this folds a single 32-bit wrap back to the true delta. At ≤ a few
    /// seconds per sample the counters can wrap at most once, so one fold suffices.
    private func counterDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? (current - previous) : ((current &+ 0x1_0000_0000) &- previous)
    }
}
