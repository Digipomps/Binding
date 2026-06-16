// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Network

/// On-demand reachability check: opens a TCP connection to host:port and reports
/// whether it succeeds and how long the handshake took. Unprivileged, native
/// (Network framework), and strictly bounded by a timeout. Timing uses the
/// monotonic uptime clock, not wall-clock.
public struct NetworkReachabilityProbe: Sendable {
    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func tryResume() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    private struct UncheckedBox<Value>: @unchecked Sendable { let value: Value }

    public init() {}

    public func probe(host: String, port: UInt16, timeoutSeconds: Double = 3.0) async -> String {
        guard host.isEmpty == false else { return "Ingen vert angitt." }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return "Ugyldig port: \(port)" }

        let startNanos = DispatchTime.now().uptimeNanoseconds
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let connectionBox = UncheckedBox(value: connection)
        let resumed = ResumeOnce()

        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- startNanos) / 1_000_000.0
                    if resumed.tryResume() {
                        continuation.resume(returning: String(format: "✓ %@:%d nådd på %.0f ms", host, Int(port), elapsedMs))
                    }
                    connectionBox.value.cancel()
                case .failed(let error):
                    if resumed.tryResume() {
                        continuation.resume(returning: "✗ \(host):\(Int(port)) ikke nådd (\(error.localizedDescription))")
                    }
                    connectionBox.value.cancel()
                default:
                    break
                }
            }
            connection.start(queue: .global())

            Task {
                try? await Task.sleep(nanoseconds: UInt64(max(0.1, timeoutSeconds) * 1_000_000_000))
                if resumed.tryResume() {
                    continuation.resume(returning: String(format: "✗ %@:%d tidsavbrudd etter %.0fs", host, Int(port), timeoutSeconds))
                }
                connectionBox.value.cancel()
            }
        }
    }

    /// Parses a "host:port" string. Defaults to port 443 if no port is given.
    /// IPv6 literals should be wrapped in brackets, e.g. "[fe80::1]:80".
    public static func parseTarget(_ target: String, defaultPort: UInt16 = 443) -> (host: String, port: UInt16) {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["), let close = trimmed.firstIndex(of: "]") {
            let host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
            let rest = trimmed[trimmed.index(after: close)...]
            if rest.hasPrefix(":"), let port = UInt16(rest.dropFirst()) {
                return (host, port)
            }
            return (host, defaultPort)
        }
        if let lastColon = trimmed.lastIndex(of: ":"),
           trimmed[trimmed.index(after: lastColon)...].allSatisfy(\.isNumber),
           let port = UInt16(trimmed[trimmed.index(after: lastColon)...]) {
            return (String(trimmed[trimmed.startIndex..<lastColon]), port)
        }
        return (trimmed, defaultPort)
    }
}
