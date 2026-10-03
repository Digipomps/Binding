// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
import Vapor
import NIOCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private enum AdminBridgeTransportEventLoops {
    static let shared = MultiThreadedEventLoopGroup(numberOfThreads: 2)
}

private enum AdminBridgeTransportTimeouts {
    static let hostResolutionMilliseconds = 2_000
    static let connectionMilliseconds = 10_000
}

public enum AdminAuthenticatedVaporBridgeTransportError: Error, LocalizedError, Equatable {
    case missingEndpointHost(endpoint: String)
    case hostResolutionFailed(host: String, detail: String)
    case hostResolutionTimedOut(host: String, timeoutMilliseconds: Int)
    case connectionTimedOut(endpoint: String, timeoutMilliseconds: Int)
    case connectionFailed(endpoint: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case .missingEndpointHost(let endpoint):
            return "Authenticated AdminScaffold bridge endpoint has no host: \(endpoint)"
        case .hostResolutionFailed(let host, let detail):
            return "Authenticated AdminScaffold bridge host '\(host)' could not be resolved: \(detail)"
        case .hostResolutionTimedOut(let host, let timeoutMilliseconds):
            return "Authenticated AdminScaffold bridge host '\(host)' did not resolve within \(timeoutMilliseconds)ms."
        case .connectionTimedOut(let endpoint, let timeoutMilliseconds):
            return "Authenticated AdminScaffold bridge connection to '\(endpoint)' timed out after \(timeoutMilliseconds)ms."
        case .connectionFailed(let endpoint, let detail):
            return "Authenticated AdminScaffold bridge connection to '\(endpoint)' failed: \(detail)"
        }
    }
}

struct AdminBridgeHostLookupResult: Sendable, Equatable {
    let resolved: Bool
    let detail: String
}

struct AdminBridgeHostResolver: Sendable {
    typealias Lookup = @Sendable (_ host: String, _ service: String) -> AdminBridgeHostLookupResult

    private static let lookupQueue = DispatchQueue(
        label: "org.haven.admin-bridge-host-resolution",
        qos: .utility,
        attributes: .concurrent
    )

    let timeoutMilliseconds: Int
    let lookup: Lookup

    init(
        timeoutMilliseconds: Int = AdminBridgeTransportTimeouts.hostResolutionMilliseconds,
        lookup: @escaping Lookup = Self.systemLookup
    ) {
        self.timeoutMilliseconds = max(1, timeoutMilliseconds)
        self.lookup = lookup
    }

    func resolve(host: String, port: Int) async throws {
        let gate = AdminBridgeContinuationGate<Void>()
        let timeoutError = AdminAuthenticatedVaporBridgeTransportError.hostResolutionTimedOut(
            host: host,
            timeoutMilliseconds: timeoutMilliseconds
        )

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                Self.lookupQueue.async {
                    let outcome = lookup(host, String(port))
                    if outcome.resolved {
                        gate.resolve(.success(()))
                    } else {
                        gate.resolve(.failure(
                            AdminAuthenticatedVaporBridgeTransportError.hostResolutionFailed(
                                host: host,
                                detail: outcome.detail
                            )
                        ))
                    }
                }
                Self.lookupQueue.asyncAfter(
                    deadline: .now() + .milliseconds(timeoutMilliseconds)
                ) {
                    gate.resolve(.failure(timeoutError))
                }
            }
        } onCancel: {
            gate.resolve(.failure(CancellationError()))
        }
    }

    private static let systemLookup: Lookup = { host, service in
#if canImport(Darwin) || canImport(Glibc)
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, service, nil, &result)
        if let result {
            freeaddrinfo(result)
        }
        guard status == 0 else {
            let detail = gai_strerror(status).map { String(cString: $0) }
                ?? "getaddrinfo error \(status)"
            return AdminBridgeHostLookupResult(resolved: false, detail: detail)
        }
        return AdminBridgeHostLookupResult(resolved: true, detail: "resolved")
#else
        return AdminBridgeHostLookupResult(
            resolved: false,
            detail: "system host resolution is unavailable on this platform"
        )
#endif
    }
}

private final class AdminBridgeContinuationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?

    func install(_ continuation: CheckedContinuation<Value, Error>) {
        let completedResult: Result<Value, Error>?
        lock.lock()
        if let result {
            completedResult = result
        } else {
            self.continuation = continuation
            completedResult = nil
        }
        lock.unlock()

        if let completedResult {
            continuation.resume(with: completedResult)
        }
    }

    @discardableResult
    func resolve(
        _ result: Result<Value, Error>,
        beforeResume: () -> Void = {}
    ) -> Bool {
        let continuation: CheckedContinuation<Value, Error>?
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return false
        }
        self.result = result
        continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        beforeResume()
        continuation?.resume(with: result)
        return true
    }
}

private final class AdminBridgeOperationTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var cancellationRequested = false

    func install(_ task: Task<Void, Never>) {
        lock.lock()
        self.task = task
        let shouldCancel = cancellationRequested
        lock.unlock()
        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}

enum AdminBridgeAsyncTimeout {
    static func run(
        timeoutMilliseconds: Int,
        timeoutError: Error,
        onTimeout: @escaping @Sendable () -> Void,
        operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        let boundedTimeout = max(1, timeoutMilliseconds)
        let gate = AdminBridgeContinuationGate<Void>()
        let taskBox = AdminBridgeOperationTaskBox()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                let operationTask = Task {
                    do {
                        try await operation()
                        gate.resolve(.success(()))
                    } catch {
                        gate.resolve(.failure(error))
                    }
                }
                taskBox.install(operationTask)
                Task {
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(boundedTimeout) * 1_000_000
                        )
                    } catch {
                        return
                    }
                    gate.resolve(.failure(timeoutError)) {
                        onTimeout()
                        taskBox.cancel()
                    }
                }
            }
        } onCancel: {
            gate.resolve(.failure(CancellationError())) {
                taskBox.cancel()
            }
        }
    }
}

private final class PendingAdminBridgeWebSocket: @unchecked Sendable {
    private let lock = NSLock()
    private var webSocket: WebSocket?
    private var cancelled = false

    func receive(_ webSocket: WebSocket) {
        lock.lock()
        if cancelled {
            lock.unlock()
            Self.close(webSocket)
            return
        }
        self.webSocket = webSocket
        lock.unlock()
    }

    func take() -> WebSocket? {
        lock.lock()
        defer { lock.unlock() }
        guard cancelled == false else { return nil }
        let webSocket = self.webSocket
        self.webSocket = nil
        return webSocket
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let webSocket = self.webSocket
        self.webSocket = nil
        lock.unlock()
        if let webSocket {
            Self.close(webSocket)
        }
    }

    private static func close(_ webSocket: WebSocket) {
        Task {
            try? await webSocket.close(code: .goingAway)
        }
    }
}

/// Outbound bridge transport used only for the dedicated AdminScaffold host.
///
/// The HMAC handshake authenticates the web workload to the control-plane
/// channel. It deliberately does not grant CellProtocol authority: requester
/// identity, Agreement and role/capability proof are still evaluated by the
/// target cell for every command.
public final class AdminAuthenticatedVaporBridgeTransport: BridgeTransportProtocol, @unchecked Sendable {
    private let stateLock = NSLock()
    private let hostResolver: AdminBridgeHostResolver
    private let connectionTimeoutMilliseconds: Int
    private var delegate: BridgeDelegateProtocol?
    private var webSocket: WebSocket?
    private var closeCleanupCompleted = false

    init(
        hostResolver: AdminBridgeHostResolver = AdminBridgeHostResolver(),
        connectionTimeoutMilliseconds: Int = AdminBridgeTransportTimeouts.connectionMilliseconds
    ) {
        self.hostResolver = hostResolver
        self.connectionTimeoutMilliseconds = max(1, connectionTimeoutMilliseconds)
    }

    public static func new() -> BridgeTransportProtocol {
        AdminAuthenticatedVaporBridgeTransport()
    }

    public func setDelegate(_ delegate: BridgeDelegateProtocol) {
        withStateLock {
            self.delegate = delegate
        }
    }

    public func setup(_ endpointURL: URL, identity: Identity) async throws {
        _ = identity
        guard let credential = AdminBridgeClientCredential.current else {
            throw AdminControlPlaneConfigurationError.missingBridgeClientCredential
        }
        guard let host = endpointURL.host else {
            throw AdminAuthenticatedVaporBridgeTransportError.missingEndpointHost(
                endpoint: endpointURL.absoluteString
            )
        }
        let port = endpointURL.port ?? (endpointURL.scheme?.lowercased() == "wss" ? 443 : 80)
        try await hostResolver.resolve(host: host, port: port)

        let headers = try credential.headers(for: endpointURL)
        let pendingWebSocket = PendingAdminBridgeWebSocket()
        do {
            try await AdminBridgeAsyncTimeout.run(
                timeoutMilliseconds: connectionTimeoutMilliseconds,
                timeoutError: AdminAuthenticatedVaporBridgeTransportError.connectionTimedOut(
                    endpoint: endpointURL.absoluteString,
                    timeoutMilliseconds: connectionTimeoutMilliseconds
                ),
                onTimeout: {
                    pendingWebSocket.cancel()
                }
            ) {
                try await WebSocket.connect(
                    to: endpointURL.absoluteString,
                    headers: headers,
                    configuration: WebSocketClient.Configuration(maxFrameSize: 65_536),
                    on: AdminBridgeTransportEventLoops.shared
                ) { webSocket in
                    pendingWebSocket.receive(webSocket)
                }
            }
        } catch let error as AdminAuthenticatedVaporBridgeTransportError {
            pendingWebSocket.cancel()
            throw error
        } catch let error as SocketAddressError.UnknownHost {
            pendingWebSocket.cancel()
            throw AdminAuthenticatedVaporBridgeTransportError.hostResolutionFailed(
                host: error.host,
                detail: error.errorDescription
            )
        } catch is CancellationError {
            pendingWebSocket.cancel()
            throw CancellationError()
        } catch {
            pendingWebSocket.cancel()
            throw AdminAuthenticatedVaporBridgeTransportError.connectionFailed(
                endpoint: endpointURL.absoluteString,
                detail: error.localizedDescription
            )
        }

        guard let webSocket = pendingWebSocket.take() else {
            throw AdminAuthenticatedVaporBridgeTransportError.connectionFailed(
                endpoint: endpointURL.absoluteString,
                detail: "connection completed without an upgraded WebSocket"
            )
        }
        setWebSocket(webSocket)
        // CellResolver waits for the server's `ready` command and then requests
        // the proxy description exactly once. Sending another request here races
        // the inbound bridge's publisher cache and can crash AdminScaffold.
    }

    public func sendData(_ data: Data) async throws {
        guard let webSocket = currentWebSocket() else {
            CellBase.diagnosticLog("Authenticated AdminScaffold bridge is not reachable.", domain: .bridge)
            await cleanupClosedWebSocketRegistration()
            return
        }
        if CellBase.sendDataAsText, let text = String(data: data, encoding: .utf8) {
            try await webSocket.send(text)
        } else {
            try await webSocket.send([UInt8](data))
        }
    }

    public func identityVault(for identity: Identity?) async -> IdentityVaultProtocol {
        _ = identity
        return BridgeIdentityVault(cloudBridge: currentDelegate() as? BridgeProtocol)
    }

    private func setWebSocket(_ webSocket: WebSocket) {
        withStateLock {
            self.webSocket = webSocket
            closeCleanupCompleted = false
        }
        setupCallbacks(on: webSocket)
    }

    private func setupCallbacks(on webSocket: WebSocket) {
        webSocket.onText { [weak self] _, text in
            guard let data = text.data(using: .utf8) else { return }
            try? await self?.extractCommand(data)
        }
        webSocket.onBinary { [weak self] _, buffer in
            guard let data = buffer.getData(at: 0, length: buffer.readableBytes) else { return }
            try? await self?.extractCommand(data)
        }
        webSocket.onClose.whenComplete { [weak self] result in
            if case .failure(let error) = result {
                CellBase.diagnosticLog("Authenticated AdminScaffold bridge closed: \(error)", domain: .bridge)
            }
            Task {
                await self?.cleanupClosedWebSocketRegistration()
            }
        }
    }

    private func extractCommand(_ data: Data) async throws {
        guard let command = try? JSONDecoder().decode(BridgeCommand.self, from: data),
              let delegate = currentDelegate() else {
            return
        }
        command.identity?.identityVault = await identityVault(for: command.identity)
        switch command.command {
        case .response:
            try await delegate.consumeResponse(command: command)
        default:
            try await delegate.consumeCommand(command: command)
        }
    }

    private func cleanupClosedWebSocketRegistration() async {
        guard let delegate = markCloseCleanupStartedAndGetDelegate() else { return }
        await CellBase.defaultCellResolver?.unregisterEmitCell(uuid: delegate.uuid)
    }

    private func currentDelegate() -> BridgeDelegateProtocol? {
        withStateLock { delegate }
    }

    private func currentWebSocket() -> WebSocket? {
        withStateLock { webSocket }
    }

    private func markCloseCleanupStartedAndGetDelegate() -> BridgeDelegateProtocol? {
        withStateLock {
            guard closeCleanupCompleted == false else { return nil }
            closeCleanupCompleted = true
            return delegate
        }
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
}
