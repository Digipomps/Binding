// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
@testable import HavenAgentRuntime

struct NetworkSentinelServiceTests {
    private actor TransitionRecorder {
        private(set) var transitions: [NetworkFloodEvent] = []
        func record(_ event: NetworkFloodEvent?) { if let event { transitions.append(event) } }
        func snapshot() -> [NetworkFloodEvent] { transitions }
    }

    private let oneSecondNanos: UInt64 = 1_000_000_000
    private let wall = Date(timeIntervalSince1970: 1_000_000)

    private func makeService(thresholds: NetworkSentinelThresholds) -> NetworkSentinelService {
        NetworkSentinelService(
            interface: "test0",
            thresholds: thresholds,
            intervalSeconds: 1,
            captureDirectory: FileManager.default.temporaryDirectory,
            captureEnabled: false,
            counterProvider: { _ in nil }
        )
    }

    private func reading(
        ipackets: UInt64 = 0,
        opackets: UInt64 = 0,
        ibytes: UInt64 = 0,
        obytes: UInt64 = 0,
        ierrors: UInt64 = 0,
        oerrors: UInt64 = 0
    ) -> InterfaceCounterReading {
        InterfaceCounterReading(
            ipackets: ipackets,
            opackets: opackets,
            ibytes: ibytes,
            obytes: obytes,
            ierrors: ierrors,
            oerrors: oerrors
        )
    }

    private func probeResult(
        succeeded: Bool,
        latencyMs: Double? = nil,
        host: String = "router.local",
        port: UInt16 = 443
    ) -> NetworkReachabilityProbeResult {
        NetworkReachabilityProbeResult(
            host: host,
            port: port,
            succeeded: succeeded,
            latencyMs: latencyMs,
            errorDescription: succeeded ? nil : "timeout"
        )
    }

    @Test
    func detectsAndResolvesASustainedFloodAsOneEvent() async {
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 1_000,
            megabitsPerSecond: 100_000,
            errorsPerSecond: 100_000,
            sustainedSamples: 2,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        let recorder = TransitionRecorder()
        await service.setSink { _, transition in await recorder.record(transition) }

        var nanos: UInt64 = 0
        func step(packets: UInt64) async {
            await service.ingest(reading: reading(ipackets: packets), monotonicNanos: nanos, wallClock: wall)
            nanos += oneSecondNanos
        }

        await step(packets: 0)       // prime (no sample yet)
        await step(packets: 2_000)   // +2000 pps -> hot 1
        await step(packets: 4_000)   // +2000 pps -> hot 2 => started
        await step(packets: 6_000)   // +2000 pps -> ongoing (no transition)
        await step(packets: 6_000)   // +0 -> calm 1
        await step(packets: 6_000)   // +0 -> calm 2 => resolved

        let transitions = await recorder.snapshot()
        #expect(transitions.count == 2)
        #expect(transitions.first?.phase == .started)
        #expect(transitions.last?.phase == .resolved)
        #expect(transitions.first?.id == transitions.last?.id) // one event, not two
    }

    @Test
    func rateUsesMonotonicTimeAndIgnoresWallClockJumps() async {
        // Monotonic time advances exactly 1 second; the wall clock jumps BACKWARD an
        // hour (as a DST fall-back or NTP step would). A correct implementation keys
        // rate off the monotonic clock, so the rate must stay 2000 pps — not explode.
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 1_000,
            megabitsPerSecond: 100_000,
            errorsPerSecond: 100_000,
            sustainedSamples: 1,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        await service.ingest(reading: reading(), monotonicNanos: 0, wallClock: Date(timeIntervalSince1970: 2_000_000))
        await service.ingest(
            reading: reading(ipackets: 2_000),
            monotonicNanos: oneSecondNanos,
            wallClock: Date(timeIntervalSince1970: 1_996_400) // -3600s wall jump
        )

        let snapshot = await service.snapshot()
        #expect(snapshot.latest?.packetsPerSecond == 2_000)
        #expect(snapshot.activeEvent != nil)
    }

    @Test
    func classifiesHighPacketRate() async {
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 1_000,
            megabitsPerSecond: 100_000,
            errorsPerSecond: 100_000,
            sustainedSamples: 1,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        await service.ingest(reading: reading(), monotonicNanos: 0, wallClock: wall)
        await service.ingest(reading: reading(ipackets: 5_000, ibytes: 1_000), monotonicNanos: oneSecondNanos, wallClock: wall)

        let snapshot = await service.snapshot()
        #expect(snapshot.activeEvent?.classification == .highPacketRate)
        #expect(snapshot.status == "flooding")
    }

    @Test
    func classifiesBulkDownloadFromThroughputNotPacketRate() async {
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 10_000_000,
            megabitsPerSecond: 100,
            errorsPerSecond: 100_000,
            sustainedSamples: 1,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        await service.ingest(reading: reading(), monotonicNanos: 0, wallClock: wall)
        // ~161 Mbps inbound, no errors, low packet rate.
        await service.ingest(
            reading: reading(ipackets: 100, opackets: 10, ibytes: 20_000_000, obytes: 200_000),
            monotonicNanos: oneSecondNanos,
            wallClock: wall
        )

        let snapshot = await service.snapshot()
        #expect(snapshot.activeEvent?.classification == .bulkDownload)
    }

    @Test
    func classifiesInterfaceDistressOnRisingErrors() async {
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 10_000_000,
            megabitsPerSecond: 100_000,
            errorsPerSecond: 50,
            sustainedSamples: 1,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        await service.ingest(reading: reading(), monotonicNanos: 0, wallClock: wall)
        await service.ingest(
            reading: reading(ipackets: 100, opackets: 100, ibytes: 1_000, obytes: 1_000, ierrors: 200),
            monotonicNanos: oneSecondNanos,
            wallClock: wall
        )

        let snapshot = await service.snapshot()
        #expect(snapshot.activeEvent?.classification == .interfaceDistress)
    }

    @Test
    func detectsSustainedHighProbeLatencyAsOneAlertableEvent() async {
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 10_000_000,
            megabitsPerSecond: 100_000,
            errorsPerSecond: 100_000,
            latencyMs: 100,
            packetLossPercent: 80,
            probeWindowSamples: 3,
            sustainedSamples: 2,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        let recorder = TransitionRecorder()
        await service.setSink { _, transition in await recorder.record(transition) }

        await service.ingestProbe(result: probeResult(succeeded: true, latencyMs: 250), wallClock: wall)
        await service.ingestProbe(result: probeResult(succeeded: true, latencyMs: 260), wallClock: wall)

        let snapshot = await service.snapshot()
        #expect(snapshot.status == "flooding")
        #expect(snapshot.latestProbe?.maxLatencyMs == 260)
        #expect(snapshot.activeEvent?.classification == .highLatency)
        #expect(snapshot.activeEvent?.peakLatencyMs == 260)
        #expect(NetworkHealthPurposeCatalog.isHarmful(snapshot.activeEvent?.classification ?? .unknown))

        let transitions = await recorder.snapshot()
        #expect(transitions.count == 1)
        #expect(transitions.first?.phase == .started)
        #expect(transitions.first?.classification == .highLatency)
    }

    @Test
    func calmTrafficSamplesDoNotResetSustainedProbeLatency() async {
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 10_000_000,
            megabitsPerSecond: 100_000,
            errorsPerSecond: 100_000,
            latencyMs: 100,
            packetLossPercent: 80,
            probeWindowSamples: 3,
            sustainedSamples: 2,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        await service.ingest(reading: reading(), monotonicNanos: 0, wallClock: wall)
        await service.ingest(reading: reading(ipackets: 1), monotonicNanos: oneSecondNanos, wallClock: wall)
        await service.ingestProbe(result: probeResult(succeeded: true, latencyMs: 250), wallClock: wall)
        await service.ingest(reading: reading(ipackets: 2), monotonicNanos: oneSecondNanos * 2, wallClock: wall)
        await service.ingestProbe(result: probeResult(succeeded: true, latencyMs: 260), wallClock: wall)

        let snapshot = await service.snapshot()
        #expect(snapshot.activeEvent?.classification == .highLatency)
        #expect(snapshot.activeEvent?.peakLatencyMs == 260)
    }

    @Test
    func detectsSustainedProbeLossAndResolvesAfterHealthyResponses() async {
        let thresholds = NetworkSentinelThresholds(
            packetsPerSecond: 10_000_000,
            megabitsPerSecond: 100_000,
            errorsPerSecond: 100_000,
            latencyMs: 1_000,
            packetLossPercent: 75,
            probeWindowSamples: 2,
            sustainedSamples: 2,
            resolveSamples: 2
        )
        let service = makeService(thresholds: thresholds)
        let recorder = TransitionRecorder()
        await service.setSink { _, transition in await recorder.record(transition) }

        await service.ingestProbe(result: probeResult(succeeded: false), wallClock: wall)
        await service.ingestProbe(result: probeResult(succeeded: false), wallClock: wall)

        var snapshot = await service.snapshot()
        #expect(snapshot.activeEvent?.classification == .packetLoss)
        #expect(snapshot.activeEvent?.packetLossPercent == 100)

        await service.ingestProbe(result: probeResult(succeeded: true, latencyMs: 20), wallClock: wall)
        await service.ingestProbe(result: probeResult(succeeded: true, latencyMs: 25), wallClock: wall)
        snapshot = await service.snapshot()
        #expect(snapshot.status == "calm")
        #expect(snapshot.activeEvent == nil)

        let transitions = await recorder.snapshot()
        #expect(transitions.count == 2)
        #expect(transitions.first?.classification == .packetLoss)
        #expect(transitions.first?.phase == .started)
        #expect(transitions.last?.phase == .resolved)
        #expect(transitions.first?.id == transitions.last?.id)
    }

    @Test
    func parsesMacOSPingSummary() {
        let output = """
        PING 1.1.1.1 (1.1.1.1): 56 data bytes

        --- 1.1.1.1 ping statistics ---
        1 packets transmitted, 1 packets received, 0.0% packet loss
        round-trip min/avg/max/stddev = 17.084/17.084/17.084/0.000 ms
        """
        let parsed = SystemPingProbe.parsePingOutput(output)

        #expect(parsed.transmitted == 1)
        #expect(parsed.received == 1)
        #expect(parsed.packetLossPercent == 0.0)
        #expect(parsed.averageLatencyMs == 17.084)
    }

    @Test
    func parsesMacOSPingLossSummary() {
        let output = """
        PING 203.0.113.1 (203.0.113.1): 56 data bytes

        --- 203.0.113.1 ping statistics ---
        1 packets transmitted, 0 packets received, 100.0% packet loss
        """
        let parsed = SystemPingProbe.parsePingOutput(output)

        #expect(parsed.transmitted == 1)
        #expect(parsed.received == 0)
        #expect(parsed.packetLossPercent == 100.0)
        #expect(parsed.averageLatencyMs == nil)
    }

    @Test
    func notificationToggleIsAuthoritativeInSnapshot() async {
        let service = makeService(thresholds: NetworkSentinelThresholds())
        await service.setNotificationsEnabled(false)
        let disabled = await service.snapshot()
        #expect(disabled.notificationsEnabled == false)

        await service.setNotificationsEnabled(true)
        let enabled = await service.snapshot()
        #expect(enabled.notificationsEnabled == true)
    }

    @Test
    func byteRateHandles32BitCounterWrap() async {
        let service = makeService(thresholds: NetworkSentinelThresholds())
        // Prime just below the 32-bit boundary.
        await service.ingest(reading: reading(ibytes: 4_200_000_000), monotonicNanos: 0, wallClock: wall)
        // 1s later the 32-bit byte counter wrapped after +200 MB.
        let wrapped: UInt64 = (4_200_000_000 + 200_000_000) % 0x1_0000_0000
        await service.ingest(reading: reading(ibytes: wrapped), monotonicNanos: 1_000_000_000, wallClock: wall)

        let mbps = await service.snapshot().latest?.megabitsPerSecond ?? 0
        // 200 MB/s ≈ 1600 Mbps — a real rate, not an astronomical underflow.
        #expect(mbps > 1_000 && mbps < 2_000)
    }

    @Test
    func runListenProducesNativeSummaryAfterWindow() async {
        let service = makeService(thresholds: NetworkSentinelThresholds())
        let started = await service.runListen(minutes: 1) // 60s window
        #expect(started.contains("1 min"))

        // Samples 2s apart, +1000 packets/tick => 500 pps, fed past the 60s window.
        var nanos: UInt64 = 0
        for i in 0..<40 {
            await service.ingest(reading: reading(ipackets: UInt64(i) * 1000), monotonicNanos: nanos, wallClock: wall)
            nanos += 2_000_000_000
        }

        let summary = await service.snapshot().listenSummary
        #expect(summary?.status == "complete")
        #expect((summary?.totalSamples ?? 0) > 0)
        #expect((summary?.perMinute.count ?? 0) >= 1)
        #expect(summary?.averagePacketsPerSecond == 500)
        #expect(summary?.peakPacketsPerSecond == 500)
    }
}
