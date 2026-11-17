// Adapted from CellProtocol ScannerPeerAuthenticationTests controlled-wire fixture.
// No radio, microphones or external participants are used.
import Foundation
import MultipeerConnectivity
import XCTest
@testable import CellApple
@testable import CellBase

final class MeetingScannerPair {
    let a: ScannerService, b: ScannerService
    let aPeer = MCPeerID(displayName: "test-a"), bPeer = MCPeerID(displayName: "test-b")
    let pa: ScannerPeerTransport, pb: ScannerPeerTransport
    let wire = MeetingScannerWire()
    var c: ScannerService?
    var cPeer = MCPeerID(displayName: "test-c")
    var ac: ScannerPeerTransport?, pc: ScannerPeerTransport?
    init(limits: BridgeChannelLimits = BridgeChannelLimits(), ownerA: Identity? = nil, ownerB: Identity? = nil, reverse: Bool = false, admissionA: ScannerAdmission = ScannerAdmission(), sessionSuffix: String = UUID().uuidString) async throws {
        let resolvedOwnerA: Identity
        if let ownerA { resolvedOwnerA = ownerA }
        else { resolvedOwnerA = await Self.owner() }
        let resolvedOwnerB: Identity
        if let ownerB { resolvedOwnerB = ownerB }
        else { resolvedOwnerB = await Self.owner() }
        let suffix = sessionSuffix
        a = ScannerService(admission: admissionA, owner: resolvedOwnerA, sessionUUID: (reverse ? "second-" : "first-") + suffix)
        b = ScannerService(admission: ScannerAdmission(), owner: resolvedOwnerB, sessionUUID: (reverse ? "first-" : "second-") + suffix)
        a.channelLimits = limits; b.channelLimits = limits
        a.foundPeersDict[b.mySessionUUID] = bPeer; a.reversedFoundPeersDict[bPeer] = b.mySessionUUID
        b.foundPeersDict[a.mySessionUUID] = aPeer; b.reversedFoundPeersDict[aPeer] = a.mySessionUUID
        let endpoint = try a.makeInvitation(remoteUUID: b.mySessionUUID)
        b.receiveInvitation(from: aPeer, endpoint: endpoint) { _, _ in }
        _ = b.respondToInvitation(remoteUUID: a.mySessionUUID, invitationID: b.invitationDecisionID(remoteUUID: a.mySessionUUID) ?? UUID(), accept: true)
        pa = try a.prepareBridge(remoteUUID: b.mySessionUUID, peerID: bPeer)
        pb = try b.prepareBridge(remoteUUID: a.mySessionUUID, peerID: aPeer)
        a.peerSend = { [wire, aPeer, weak a] data, peer, session in
            XCTAssertTrue(session === (try a?.sessionForPeer(peer)))
            try wire.append(data, from: aPeer, to: peer)
        }
        b.peerSend = { [wire, bPeer, weak b] data, peer, session in
            XCTAssertTrue(session === (try b?.sessionForPeer(peer)))
            try wire.append(data, from: bPeer, to: peer)
        }
    }
    static func owner() async -> Identity {
        let vault = MeetingTestIdentityVault()
        var identity = Identity(UUID().uuidString, displayName: "test", identityVault: vault)
        await vault.addIdentity(identity: &identity, for: UUID().uuidString)
        return identity
    }
    func addThirdPeer(authenticate: Bool = true) async throws {
        let c = ScannerService(admission: ScannerAdmission(), owner: await Self.owner(), sessionUUID: "third-" + UUID().uuidString)
        self.c = c; c.channelLimits = a.channelLimits
        a.foundPeersDict[c.mySessionUUID] = cPeer; a.reversedFoundPeersDict[cPeer] = c.mySessionUUID
        c.foundPeersDict[a.mySessionUUID] = aPeer; c.reversedFoundPeersDict[aPeer] = a.mySessionUUID
        let endpoint = try a.makeInvitation(remoteUUID: c.mySessionUUID)
        c.receiveInvitation(from: aPeer, endpoint: endpoint) { _, _ in }
        XCTAssertTrue(c.respondToInvitation(remoteUUID: a.mySessionUUID, invitationID: c.invitationDecisionID(remoteUUID: a.mySessionUUID) ?? UUID(), accept: true))
        ac = try a.prepareBridge(remoteUUID: c.mySessionUUID, peerID: cPeer)
        pc = try c.prepareBridge(remoteUUID: a.mySessionUUID, peerID: aPeer)
        c.peerSend = { [wire, cPeer, weak c] data, peer, session in
            XCTAssertTrue(session === (try c?.sessionForPeer(peer)))
            try wire.append(data, from: cPeer, to: peer)
        }
        if authenticate { try await authenticateTransports(ac!, pc!) }
    }
    func prepareReconnect() throws -> (ScannerPeerTransport, ScannerPeerTransport) {
        // The real per-peer MCSession discards its old delivery queue on close.
        // Captured adversarial frames remain available to explicit replay tests.
        wire.discard(between: aPeer, and: bPeer)
        // Rediscovery after a physical disconnect, retaining the same MCPeerIDs.
        a.foundPeersDict[b.mySessionUUID] = bPeer; a.reversedFoundPeersDict[bPeer] = b.mySessionUUID
        b.foundPeersDict[a.mySessionUUID] = aPeer; b.reversedFoundPeersDict[aPeer] = a.mySessionUUID
        let endpoint = try a.makeInvitation(remoteUUID: b.mySessionUUID)
        b.receiveInvitation(from: aPeer, endpoint: endpoint) { _, _ in }
        XCTAssertTrue(b.respondToInvitation(remoteUUID: a.mySessionUUID, invitationID: b.invitationDecisionID(remoteUUID: a.mySessionUUID) ?? UUID(), accept: true))
        return (try a.prepareBridge(remoteUUID: b.mySessionUUID, peerID: bPeer),
                try b.prepareBridge(remoteUUID: a.mySessionUUID, peerID: aPeer))
    }
    func authenticateTransports(_ a: ScannerPeerTransport, _ b: ScannerPeerTransport) async throws {
        let at = Task { try await a.gate.startPeer() }, bt = Task { try await b.gate.startPeer() }
        for _ in 0..<5 { try await deliverNext() }
        try await at.value; try await bt.value
    }
    func receiver(_ frame: MeetingScannerWire.Frame) throws -> ScannerPeerTransport {
        let destination: ScannerService
        if frame.to == aPeer { destination = a }
        else if frame.to == bPeer { destination = b }
        else { destination = try XCTUnwrap(c); XCTAssertEqual(frame.to, cPeer) }
        return try destination.capturePeerTransport(session: destination.sessionForPeer(frame.from), peerID: frame.from)
    }
    func deliver(_ frame: MeetingScannerWire.Frame) async throws {
        let before = wire.history.count
        try await receiver(frame).receiveData(frame.data)
        if frame.sealed, let receipt = wire.history.dropFirst(before).first(where: { $0.from == frame.to && $0.to == frame.from }) {
            // Scanner emits its internal receipt synchronously before dispatch.
            // Consume that exact queued frame, leaving application responses for
            // the test. Assert the real gate classifies it as receipt-only.
            XCTAssertTrue(wire.remove(receipt))
            XCTAssertEqual(try receiver(receipt).gate.openPeerFrame(receipt.data), Data())
        }
    }
    func pump() -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                if let frame = wire.take() {
                    do {
                        let physical = try receiver(frame) // capture before dispatch, as the MC callback does
                        let received = physical.enqueueReceive(frame.data)
                        Task { do { try await received.value } catch { wire.failed(error) } }
                    } catch { wire.failed(error) }
                } else { try? await Task.sleep(nanoseconds: 1_000_000) }
            }
        }
    }
    func start() -> (Task<Void, Error>, Task<Void, Error>) {
        (Task { try await pa.gate.startPeer() }, Task { try await pb.gate.startPeer() })
    }
    func next() async throws -> MeetingScannerWire.Frame {
        for _ in 0..<1000 {
            if let frame = wire.take() { return frame }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw NSError(domain: "Scanner wire timeout", code: 1)
    }
    func deliverNext() async throws {
        let frame = try await next()
        try await deliver(frame)
    }
    private typealias A = BridgeChannelAuthentication
    func finish(_ tasks: (Task<Void, Error>, Task<Void, Error>)) async throws {
        for _ in 0..<5 where pa.channelSession?.state != .authenticated || pb.channelSession?.state != .authenticated {
            try await deliverNext()
        }
        try await tasks.0.value; try await tasks.1.value
    }
    func stop() { a.stop(); b.stop(); c?.stop() }
}
final class MeetingScannerWire: @unchecked Sendable {
    struct Frame {
        let data: Data; let from: MCPeerID; let to: MCPeerID
        var sealed: Bool { data.starts(with: Data("HPC3".utf8)) }
        // M can parse all five envelopes, but only identity-free hello fields.
        // Application records have an explicit sentinel; M holds no keys.
        var command: BridgeCommand { (try? JSONDecoder().decode(BridgeCommand.self, from: data)) ?? BridgeCommand(cmd: "sealed", payload: nil, cid: 0) }
    }
    private let lock = NSLock()
    private var pending: [Frame] = [], recorded: [Frame] = []
    private var failures: [String] = []
    var errors: [String] { lock.withLock { failures } }
    func failed(_ error: Error) { lock.withLock { failures.append(String(describing: error)) } }
    var history: [Frame] { lock.withLock { recorded } }
    func append(_ data: Data, from: MCPeerID, to: MCPeerID) throws {
        let frame = Frame(data: data, from: from, to: to)
        lock.withLock { pending.append(frame); recorded.append(frame) }
    }
    func discard(between a: MCPeerID, and b: MCPeerID) {
        lock.withLock { pending.removeAll { ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a) } }
    }
    func remove(_ frame: Frame) -> Bool {
        lock.withLock {
            guard let index = pending.firstIndex(where: { $0.data == frame.data && $0.from == frame.from && $0.to == frame.to }) else { return false }
            pending.remove(at: index); return true
        }
    }
    func take() -> Frame? { lock.withLock { pending.isEmpty ? nil : pending.removeFirst() } }
}
