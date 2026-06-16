// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation

/// Runs a single, strictly bounded `tcpdump` capture for flood evidence.
///
/// The capture stops at whichever bound is reached first:
///  - the packet limit (`-c`), or
///  - a hard wall-clock duration, enforced by a monotonic `Task.sleep` + SIGTERM.
///
/// This guarantees the capture can never hang waiting for packets that stop
/// arriving (the failure mode of a packet-count-only bound). The duration timer
/// uses Swift's monotonic clock, not wall-clock time, so it is unaffected by
/// NTP/DST adjustments.
public struct BoundedPacketCapture: Sendable {
    private struct UncheckedBox<Value>: @unchecked Sendable { let value: Value }

    public var executablePath: String
    public var snaplen: Int

    public init(executablePath: String = "/usr/sbin/tcpdump", snaplen: Int = 160) {
        self.executablePath = executablePath
        self.snaplen = snaplen
    }

    /// - Returns: true if the capture process was launched (regardless of how it
    ///   terminated), false if it could not be started.
    @discardableResult
    public func capture(
        interface: String,
        outputPath: String,
        durationSeconds: Double,
        packetLimit: Int
    ) async -> Bool {
        let directory = (outputPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [
            "-i", interface,
            "-n",
            "-s", String(snaplen),
            "-c", String(max(1, packetLimit)),
            "-w", outputPath
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return false
        }

        // Hard wall-clock bound. Task.sleep is backed by a monotonic clock, so the
        // bound holds regardless of wall-clock adjustments.
        let processBox = UncheckedBox(value: process)
        let deadline = Task {
            let nanos = UInt64(max(0, durationSeconds) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            let running = processBox.value
            if running.isRunning { running.terminate() }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
            if !process.isRunning {
                // Already exited before the handler was attached.
                process.terminationHandler = nil
                continuation.resume()
            }
        }
        deadline.cancel()
        return true
    }
}
