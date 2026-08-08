// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Network

public struct NetworkReachabilityProbeResult: Codable, Sendable, Equatable {
    public var kind: NetworkProbeKind
    public var host: String
    public var port: UInt16
    public var succeeded: Bool
    public var latencyMs: Double?
    public var errorDescription: String?

    public init(
        kind: NetworkProbeKind = .tcpConnect,
        host: String,
        port: UInt16,
        succeeded: Bool,
        latencyMs: Double? = nil,
        errorDescription: String? = nil
    ) {
        self.kind = kind
        self.host = host
        self.port = port
        self.succeeded = succeeded
        self.latencyMs = latencyMs
        self.errorDescription = errorDescription
    }

    public var displayText: String {
        let noun = kind == .icmpPing ? "ping \(host)" : "\(host):\(Int(port))"
        if succeeded, let latencyMs {
            return String(format: "✓ %@ nådd på %.0f ms", noun, latencyMs)
        }
        let reason = errorDescription.map { " (\($0))" } ?? ""
        return "✗ \(noun) ikke nådd\(reason)"
    }

    private enum CodingKeys: String, CodingKey {
        case kind, host, port, succeeded, latencyMs, errorDescription
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decodeIfPresent(NetworkProbeKind.self, forKey: .kind) ?? .tcpConnect,
            host: try container.decode(String.self, forKey: .host),
            port: try container.decode(UInt16.self, forKey: .port),
            succeeded: try container.decode(Bool.self, forKey: .succeeded),
            latencyMs: try container.decodeIfPresent(Double.self, forKey: .latencyMs),
            errorDescription: try container.decodeIfPresent(String.self, forKey: .errorDescription)
        )
    }
}

/// Strictly bounded ICMP ping probe using macOS' `/sbin/ping`.
///
/// The process is one packet (`-c 1`), quiet (`-q`), numeric (`-n`) and has both
/// ping's own wait bound (`-W`) plus an outer Swift timeout/termination guard. We
/// intentionally discard stderr so sandbox or entitlement failures cannot flood
/// daemon logs or fill a pipe indefinitely.
public struct SystemPingProbe: Sendable {
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

    public var executablePath: String

    public init(executablePath: String = "/sbin/ping") {
        self.executablePath = executablePath
    }

    public func probeResult(host rawHost: String, timeoutSeconds: Double = 3.0) async -> NetworkReachabilityProbeResult {
        let host = Self.normalizedHost(rawHost)
        guard host.isEmpty == false else {
            return NetworkReachabilityProbeResult(
                kind: .icmpPing,
                host: host,
                port: 0,
                succeeded: false,
                errorDescription: "Ingen vert angitt."
            )
        }
        guard Self.isSafeHostArgument(host) else {
            return NetworkReachabilityProbeResult(
                kind: .icmpPing,
                host: host,
                port: 0,
                succeeded: false,
                errorDescription: "Ugyldig ping-vert."
            )
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let resumed = ResumeOnce()
        let waitMilliseconds = max(100, Int((timeoutSeconds * 1000.0).rounded(.up)))
        let hardTimeoutNanos = UInt64((max(0.1, timeoutSeconds) + 1.0) * 1_000_000_000)

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["-q", "-n", "-c", "1", "-W", "\(waitMilliseconds)", host]
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        return await withCheckedContinuation { (continuation: CheckedContinuation<NetworkReachabilityProbeResult, Never>) in
            process.terminationHandler = { process in
                let output = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let parsed = Self.parsePingOutput(output)
                let received = parsed.received ?? 0
                let succeeded = process.terminationStatus == 0 && received > 0
                let errorDescription: String?
                if succeeded {
                    errorDescription = nil
                } else if let loss = parsed.packetLossPercent {
                    errorDescription = String(format: "%.0f%% pakketap", loss)
                } else {
                    errorDescription = "ping feilet med status \(process.terminationStatus)"
                }
                if resumed.tryResume() {
                    continuation.resume(returning: NetworkReachabilityProbeResult(
                        kind: .icmpPing,
                        host: host,
                        port: 0,
                        succeeded: succeeded,
                        latencyMs: parsed.averageLatencyMs,
                        errorDescription: errorDescription
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                if resumed.tryResume() {
                    continuation.resume(returning: NetworkReachabilityProbeResult(
                        kind: .icmpPing,
                        host: host,
                        port: 0,
                        succeeded: false,
                        errorDescription: "Kunne ikke starte ping: \(error.localizedDescription)"
                    ))
                }
                return
            }

            let processBox = UncheckedBox(value: process)
            Task {
                try? await Task.sleep(nanoseconds: hardTimeoutNanos)
                if processBox.value.isRunning {
                    processBox.value.terminate()
                }
            }
        }
    }

    static func parsePingOutput(_ output: String) -> (
        transmitted: Int?,
        received: Int?,
        packetLossPercent: Double?,
        averageLatencyMs: Double?
    ) {
        let transmitted = firstIntCapture(in: output, pattern: #"(\d+)\s+packets transmitted"#)
        let received = firstIntCapture(in: output, pattern: #"(\d+)\s+packets received"#)
        let loss = firstDoubleCapture(in: output, pattern: #"([0-9]+(?:\.[0-9]+)?)%\s+packet loss"#)
        let average = firstDoubleCapture(
            in: output,
            pattern: #"round-trip\s+min/avg/max/(?:stddev|std-dev)\s+=\s+[0-9.]+/([0-9.]+)/[0-9.]+/[0-9.]+\s+ms"#
        )
        return (transmitted, received, loss, average)
    }

    private static func normalizedHost(_ rawHost: String) -> String {
        let trimmed = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private static func isSafeHostArgument(_ host: String) -> Bool {
        host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
            && host.rangeOfCharacter(from: .controlCharacters) == nil
            && host.count <= 253
    }

    private static func firstIntCapture(in text: String, pattern: String) -> Int? {
        firstStringCapture(in: text, pattern: pattern).flatMap(Int.init)
    }

    private static func firstDoubleCapture(in text: String, pattern: String) -> Double? {
        firstStringCapture(in: text, pattern: pattern).flatMap(Double.init)
    }

    private static func firstStringCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}

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
        await probeResult(host: host, port: port, timeoutSeconds: timeoutSeconds).displayText
    }

    public func probeResult(
        host: String,
        port: UInt16,
        timeoutSeconds: Double = 3.0
    ) async -> NetworkReachabilityProbeResult {
        guard host.isEmpty == false else {
            return NetworkReachabilityProbeResult(
                host: host,
                port: port,
                succeeded: false,
                errorDescription: "Ingen vert angitt."
            )
        }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            return NetworkReachabilityProbeResult(
                host: host,
                port: port,
                succeeded: false,
                errorDescription: "Ugyldig port: \(port)"
            )
        }

        let startNanos = DispatchTime.now().uptimeNanoseconds
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let connectionBox = UncheckedBox(value: connection)
        let resumed = ResumeOnce()

        return await withCheckedContinuation { (continuation: CheckedContinuation<NetworkReachabilityProbeResult, Never>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- startNanos) / 1_000_000.0
                    if resumed.tryResume() {
                        continuation.resume(returning: NetworkReachabilityProbeResult(
                            host: host,
                            port: port,
                            succeeded: true,
                            latencyMs: elapsedMs
                        ))
                    }
                    connectionBox.value.cancel()
                case .failed(let error):
                    if resumed.tryResume() {
                        continuation.resume(returning: NetworkReachabilityProbeResult(
                            host: host,
                            port: port,
                            succeeded: false,
                            errorDescription: error.localizedDescription
                        ))
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
                    continuation.resume(returning: NetworkReachabilityProbeResult(
                        host: host,
                        port: port,
                        succeeded: false,
                        errorDescription: String(format: "tidsavbrudd etter %.0fs", timeoutSeconds)
                    ))
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
