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
    func notificationToggleIsAuthoritativeInSnapshot() async {
        let service = makeService(thresholds: NetworkSentinelThresholds())
        await service.setNotificationsEnabled(false)
        let disabled = await service.snapshot()
        #expect(disabled.notificationsEnabled == false)

        await service.setNotificationsEnabled(true)
        let enabled = await service.snapshot()
        #expect(enabled.notificationsEnabled == true)
    }
}
