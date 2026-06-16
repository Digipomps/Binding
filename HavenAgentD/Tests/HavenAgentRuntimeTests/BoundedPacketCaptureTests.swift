// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
@testable import HavenAgentRuntime

struct BoundedPacketCaptureTests {
    /// A missing capture binary must fail fast and return false — never hang.
    @Test
    func returnsFalseAndDoesNotHangWhenExecutableMissing() async {
        let capture = BoundedPacketCapture(executablePath: "/nonexistent/tcpdump")
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("bpc-\(UUID().uuidString).pcap").path

        let started = await capture.capture(
            interface: "lo0",
            outputPath: outputPath,
            durationSeconds: 1,
            packetLimit: 10
        )
        #expect(started == false)
    }
}
