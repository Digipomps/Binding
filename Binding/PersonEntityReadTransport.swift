// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import Foundation

/// Header-capable app transport. Core still validates every inbound payload,
/// authorizes origin-proof signing scopes and performs all data operations.
nonisolated final class BindingPersonEntityReadTransport: NSObject, BridgeTransportProtocol, URLSessionWebSocketDelegate, @unchecked Sendable {
    private typealias C = BindingPersonEntityReadRouteContract
    private let request: URLRequest?
    private let identity: Identity?
    private let lock = NSLock()
    private var delegate: (any BridgeDelegateProtocol)?
    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var receiver: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var opening: CheckedContinuation<Void, Error>?
    private var opened = false
    private var closed = false

    init(request: URLRequest? = nil, identity: Identity? = nil) {
        self.request = request; self.identity = identity
        super.init()
    }

    static func new() -> any BridgeTransportProtocol { BindingPersonEntityReadTransport() }
    func setDelegate(_ delegate: any BridgeDelegateProtocol) { locked { if !closed { self.delegate = delegate } } }

    func setup(_ endpointURL: URL, identity: Identity) async throws {
        guard let request, request.url == endpointURL, endpointURL.scheme == "wss",
              let expected = self.identity, expected.uuid == identity.uuid,
              expected.signingPublicKeyFingerprint == identity.signingPublicKeyFingerprint else { throw C.Failure.denied }
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    let socket = try locked { () throws -> URLSessionWebSocketTask in
                        guard !closed, self.socket == nil else { throw C.Failure.unavailable }
                        let config = URLSessionConfiguration.ephemeral
                        config.httpShouldSetCookies = false; config.httpCookieStorage = nil; config.urlCache = nil
                        config.timeoutIntervalForRequest = 10
                        config.timeoutIntervalForResource = C.connectionLifetime + 15
                        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                        let socket = session.webSocketTask(with: request)
                        socket.maximumMessageSize = C.maximumOutboundFrameBytes
                        self.session = session; self.socket = socket; opening = continuation
                        deadline = Task<Void, Never> { [weak self] in
                            do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                            await self?.finish()
                        }
                        return socket
                    }
                    socket.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }, onCancel: { Task { await self.close() } })
        try Task.checkCancellation()
        guard let socket = locked({ opened && !closed ? self.socket : nil }) else { throw C.Failure.unavailable }
        let receiver = Task<Void, Never> { [weak self] in await self?.receive(from: socket) }
        let deadline = Task<Void, Never> { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(C.connectionLifetime * 1_000_000_000)) } catch { return }
            await self?.finish()
        }
        let installed = locked { () -> Bool in
            guard !closed else { return false }
            self.receiver = receiver; self.deadline = deadline
            return true
        }
        if !installed { receiver.cancel(); deadline.cancel(); throw C.Failure.unavailable }
    }

    func sendData(_ data: Data) async throws {
        guard data.count <= C.maximumInboundFrameBytes,
              let socket = locked({ opened && !closed ? self.socket : nil }) else { throw C.Failure.unavailable }
        do {
            if CellBase.sendDataAsText {
                guard let text = String(data: data, encoding: .utf8) else { throw C.Failure.malformed }
                try await socket.send(.string(text))
            } else { try await socket.send(.data(data)) }
        } catch { await finish(); throw C.Failure.unavailable }
    }

    func identityVault(for incoming: Identity?) async -> any IdentityVaultProtocol {
        if let incoming, let identity, incoming.uuid == identity.uuid,
           incoming.signingPublicKeyFingerprint == identity.signingPublicKeyFingerprint,
           let vault = identity.identityVault, let home = identity.homeVaultReference,
           await vault.identityVaultReference() == home, await vault.identityExistInVault(identity) {
            return vault
        }
        if let bridge = locked({ delegate as? any BridgeProtocol }) { return BridgeIdentityVault(cloudBridge: bridge) }
        return DIDIdentityVault()
    }

    func close() async { await finish() }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let continuation = locked { () -> CheckedContinuation<Void, Error>? in
            guard !closed, socket === webSocketTask, !opened else { return nil }
            opened = true
            deadline?.cancel(); deadline = nil
            defer { opening = nil }
            return opening
        }
        continuation?.resume()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if locked({ socket === webSocketTask }) { Task { await finish() } }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if locked({ socket === task }) { Task { await finish() } }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    private func receive(from socket: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                let bytes: Data
                switch message {
                case let .data(value): bytes = value
                case let .string(value): bytes = Data(value.utf8)
                @unknown default: throw C.Failure.malformed
                }
                guard bytes.count <= C.maximumOutboundFrameBytes else { throw C.Failure.malformed }
                try BridgeInboundPayloadValidator().validate(bytes)
                let command = try JSONDecoder().decode(BridgeCommand.self, from: bytes)
                command.identity?.identityVault = await identityVault(for: command.identity)
                guard let delegate = locked({ closed ? nil : self.delegate }) else { throw C.Failure.unavailable }
                switch command.command {
                case .response: try await delegate.consumeResponse(command: command)
                default: try await delegate.consumeCommand(command: command)
                }
            }
        } catch { await finish() }
    }

    private func finish() async {
        let state = locked { () -> (URLSession?, URLSessionWebSocketTask?, (any BridgeDelegateProtocol)?, CheckedContinuation<Void, Error>?)? in
            guard !closed else { return nil }
            closed = true
            let snapshot = (session, socket, delegate, opening)
            receiver?.cancel(); deadline?.cancel()
            receiver = nil; deadline = nil; session = nil; socket = nil; delegate = nil; opening = nil
            return snapshot
        }
        guard let (session, socket, delegate, opening) = state else { return }
        socket?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        opening?.resume(throwing: C.Failure.unavailable)
        if let bridge = delegate as? BridgeBase, let identity { bridge.close(requester: identity) }
        if let delegate {
            await delegate.pushError(errorMessage: "Person data connection closed", error: nil)
            await CellBase.defaultCellResolver?.unregisterEmitCell(uuid: delegate.uuid)
        }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }
}
