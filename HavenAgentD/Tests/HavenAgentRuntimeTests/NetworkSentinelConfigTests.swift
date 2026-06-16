// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
@testable import HavenAgentRuntime

struct NetworkSentinelConfigTests {
    @Test
    func partialJSONFallsBackToDefaults() throws {
        let json = Data(#"{ "enabled": false, "interface": "en5" }"#.utf8)
        let config = try JSONDecoder().decode(NetworkSentinelConfig.self, from: json)

        #expect(config.enabled == false)
        #expect(config.interface == "en5")
        // Unspecified fields keep the built-in defaults rather than failing to decode.
        #expect(config.intervalSeconds == 2.0)
        #expect(config.notificationsEnabled == true)
        #expect(config.captureEnabled == true)
        #expect(config.thresholds == NetworkSentinelThresholds())
        #expect(config.purpose == NetworkHealthPurposeCatalog.purposeRef)
        #expect(config.goal == NetworkHealthPurposeCatalog.goalID)
    }

    @Test
    func emptyObjectYieldsAllDefaults() throws {
        let config = try JSONDecoder().decode(NetworkSentinelConfig.self, from: Data("{}".utf8))
        #expect(config == NetworkSentinelConfig())
    }

    @Test
    func roundTripsThroughJSON() throws {
        let original = NetworkSentinelConfig(
            enabled: true,
            interface: "en0",
            intervalSeconds: 3,
            notificationsEnabled: false,
            captureEnabled: false,
            captureDurationSeconds: 8,
            capturePacketLimit: 5_000,
            captureSnaplen: 96,
            thresholds: NetworkSentinelThresholds(packetsPerSecond: 9_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NetworkSentinelConfig.self, from: data)
        #expect(decoded == original)
    }
}
