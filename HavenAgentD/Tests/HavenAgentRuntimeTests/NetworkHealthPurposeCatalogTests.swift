// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
@testable import HavenAgentRuntime

struct NetworkHealthPurposeCatalogTests {
    private func snapshot(event: NetworkFloodEvent?) -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(
            interface: "en0",
            status: event == nil ? "calm" : "flooding",
            latest: nil,
            activeEvent: event,
            recentEvents: event.map { [$0] } ?? [],
            notificationsEnabled: true,
            thresholds: NetworkSentinelThresholds(),
            updatedAt: "2026-06-13T00:00:00Z"
        )
    }

    private func event(_ classification: NetworkFloodClass, phase: NetworkFloodPhase = .started) -> NetworkFloodEvent {
        NetworkFloodEvent(
            phase: phase,
            classification: classification,
            startedAt: "2026-06-13T00:00:00Z",
            updatedAt: "2026-06-13T00:00:00Z",
            peakPacketsPerSecond: 9_999,
            peakMegabitsPerSecond: 12.0,
            summary: "test"
        )
    }

    @Test
    func harmfulFloodPutsTheGoalAtRiskAndWarrantsNotification() {
        let harmful = event(.interfaceDistress)
        let evaluation = NetworkHealthPurposeCatalog.evaluate(snapshot: snapshot(event: harmful), transition: harmful)
        #expect(evaluation.status == .atRisk)
        #expect(evaluation.purposeRef == NetworkHealthPurposeCatalog.purposeRef)
        #expect(evaluation.goalID == NetworkHealthPurposeCatalog.goalID)
        #expect(NetworkHealthPurposeCatalog.warrantsNotification(evaluation) == true)
    }

    @Test
    func benignBulkDownloadKeepsTheGoalSatisfiedAndQuiet() {
        let benign = event(.bulkDownload)
        let evaluation = NetworkHealthPurposeCatalog.evaluate(snapshot: snapshot(event: benign), transition: benign)
        #expect(evaluation.status == .satisfied)
        #expect(NetworkHealthPurposeCatalog.warrantsNotification(evaluation) == false)
    }

    @Test
    func calmLinkIsSatisfied() {
        let evaluation = NetworkHealthPurposeCatalog.evaluate(snapshot: snapshot(event: nil), transition: nil)
        #expect(evaluation.status == .satisfied)
        #expect(NetworkHealthPurposeCatalog.warrantsNotification(evaluation) == false)
    }

    @Test
    func unavailableInterfaceIsUnknownNotAnAlert() {
        var snap = snapshot(event: nil)
        snap.status = "unavailable"
        let evaluation = NetworkHealthPurposeCatalog.evaluate(snapshot: snap, transition: nil)
        #expect(evaluation.status == .unknown)
        #expect(NetworkHealthPurposeCatalog.warrantsNotification(evaluation) == false)
    }

    @Test
    func classifiesHarmfulVersusBenign() {
        #expect(NetworkHealthPurposeCatalog.isHarmful(.interfaceDistress) == true)
        #expect(NetworkHealthPurposeCatalog.isHarmful(.highPacketRate) == true)
        #expect(NetworkHealthPurposeCatalog.isHarmful(.bulkDownload) == false)
        #expect(NetworkHealthPurposeCatalog.isHarmful(.unknown) == false)
    }
}
