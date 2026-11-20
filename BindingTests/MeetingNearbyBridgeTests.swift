import XCTest
@testable import CellApple
@_spi(Testing) @testable import CellBase

final class MeetingNearbyBridgeTests: XCTestCase {
    func testPrivateMeetingJoinAndConsentTraverseAuthenticatedScannerBridgeInBothRoles() async throws {
        let oldSink = CellBase.securityEventSink, oldDebug = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        CellBase.securityEventSink = MeetingJoinDiagnosticSink()
        defer { CellBase.securityEventSink = oldSink; CellBase.debugValidateAccessForEverything = oldDebug }

        for reverse in [false, true] {
            let previous = CellBase.defaultCellResolver, oldVault = CellBase.defaultIdentityVault
            let resolver = CellResolver.makeIsolatedForTesting(); CellBase.defaultCellResolver = resolver
            defer { CellBase.defaultCellResolver = previous; CellBase.defaultIdentityVault = oldVault }
            let pair = try await MeetingScannerPair(reverse: reverse); defer { pair.stop() }
            CellBase.defaultIdentityVault = pair.a.owner.identityVault
            try await pair.finish(pair.start())
            let pump = pair.pump(); defer { pump.cancel() }
            let cell = await MeetingSessionCell(owner: pair.a.owner)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingRelay-" + UUID().uuidString)
            try cell.installDurability(store: MeetingFileStore(directory: directory), key: Data(repeating: 8, count: 32))
            let plan = MeetingPlan(purpose: "Authenticated Nearby", participants: try [pair.a.owner, pair.b.owner].map(MeetingEvidence.principal), recorder: try MeetingEvidence.principal(pair.a.owner))
            _ = try await cell.set(keypath: "plan.propose", value: .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(plan)]), requester: pair.a.owner)
            try await resolver.registerNamedEmitCell(name: cell.uuid, emitCell: cell, scope: .identityUnique, identity: pair.a.owner)
            let invitation = try await MeetingNearbyInvitation.make(cellID: cell.uuid, endpoint: "cell:///" + cell.uuid, inviter: pair.a.owner, recipient: MeetingEvidence.principal(pair.b.owner))
            let a = try pair.a.consumerContext(remoteUUID: pair.b.mySessionUUID)
            let b = try pair.b.consumerContext(remoteUUID: pair.a.mySessionUUID)
            let inbound = try await pair.a.makeMeetingRelay(context: a, cellID: cell.uuid, channelID: invitation.nonce, inbound: true)
            let outbound = try await pair.b.makeMeetingRelay(context: b, cellID: cell.uuid, channelID: invitation.nonce, inbound: false)
            let bridge = try XCTUnwrap(outbound.bridge)
            let admission = try await cell.makeAdmission(for: pair.b.owner)
            let join = try await MeetingJoinRequest.make(invitation: invitation, admission: admission, identity: pair.b.owner)
            let result = try await bridge.set(keypath: "meeting.join", value: MeetingSurfaceConfiguration.encode(join), requester: pair.b.owner)
            XCTAssertEqual(ExploreContract.object(from: result)?["status"], .string("ok"))
            let current = try await bridge.get(keypath: "plan.current", requester: pair.b.owner)
            XCTAssertNotNil(ExploreContract.object(from: current)?["reference"])
            let ref = try cell.durableSnapshot().reference
            let signed = try await MeetingSignedConsent.approve(cellID: cell.uuid, reference: ref, plan: plan, identity: pair.b.owner)
            let accepted = try await bridge.set(keypath: "consent.submit", value: MeetingSurfaceConfiguration.encode(signed), requester: pair.b.owner)
            XCTAssertEqual(ExploreContract.object(from: accepted)?["status"], .string("ok"))
            XCTAssertEqual(try cell.durableSnapshot().approvals.count, 1)
            XCTAssertNil(try cell.durableSnapshot().recording)
            XCTAssertTrue(pair.wire.errors.isEmpty, pair.wire.errors.joined(separator: ", "))
            try cell.installDelivery(store: MeetingFileStore(directory: directory.appendingPathComponent("outbox")), recorder: pair.a.owner, provider: pair.a.owner.identityVault as! MeetingTestIdentityVault)
            try cell.installCaptureDevice(BridgeFixtureCapture())
            let ownerApproval = try await MeetingSignedConsent.approve(cellID: cell.uuid, reference: ref, plan: plan, identity: pair.a.owner)
            _ = try await cell.set(keypath: "consent.submit", value: MeetingSurfaceConfiguration.encode(ownerApproval), requester: pair.a.owner)
            _ = try await bridge.set(keypath: "presence.confirm", value: MeetingSurfaceConfiguration.encode(ref), requester: pair.b.owner)
            _ = try await cell.set(keypath: "recording.start", value: MeetingSurfaceConfiguration.encode(MeetingActionInput(expected: ref)), requester: pair.a.owner)
            let segment = try XCTUnwrap(cell.durableSnapshot().recording).segmentID
            _ = try await bridge.set(keypath: "recording.stop", value: MeetingSurfaceConfiguration.encode(MeetingActionInput(expected: ref)), requester: pair.b.owner)
            let text = String(repeating: "Syntetisk møtetranskript. ", count: 30000)
            let packet = try await cell.completeSegment(segment, transcript: text, incomplete: false, uncertainties: [])
            XCTAssertGreaterThan(try JSONEncoder().encode(packet).count, 512 * 1024)
            let inbox = MeetingDeliveryService(identity: pair.b.owner, provider: pair.b.owner.identityVault as! MeetingTestIdentityVault, store: try MeetingFileStore(directory: directory.appendingPathComponent("inbox")))
            let client = MeetingParticipantClient(cellID: cell.uuid, target: bridge, identity: pair.b.owner, recorder: pair.a.owner, inbox: inbox)
            let delivered = try await client.synchronizeDelivery()
            XCTAssertEqual(delivered, 1)
            let stored = try await inbox.readReceived(packetID: packet.id, sender: pair.a.owner)
            XCTAssertEqual(stored.transcript, text)
            XCTAssertTrue(pair.wire.errors.isEmpty, pair.wire.errors.joined(separator: ", "))
            // A local relay capacity failure must leave the authenticated
            // physical peer (and its ordinary Lobby bridge) alive.
            do { try await outbound.sendData(Data(repeating: 0, count: 512 * 1024 + 1)); XCTFail("Oversize relay accepted") } catch { }
            XCTAssertNoThrow(try a.check()); XCTAssertNoThrow(try b.check())
            XCTAssertNil(outbound.bridge)
            await inbound.close()
            // Closing releases slots; repeated invitations do not exhaust the peer.
            for _ in 0..<10 {
                let route = try await pair.a.makeMeetingRelay(context: a, cellID: cell.uuid, channelID: UUID(), inbound: true)
                let wrong = ScannerMeetingRelay.Frame(channelID: UUID(), cellID: cell.uuid, bytes: try JSONEncoder().encode(BridgeCommand(cmd: "sign", payload: nil, cid: 10)))
                XCTAssertFalse(route.isControl(wrong))
                await route.close()
            }
            let route = try await pair.a.makeMeetingRelay(context: a, cellID: cell.uuid, channelID: UUID(), inbound: true)
            let invalid = ScannerMeetingRelay.Frame(channelID: route.channelID, cellID: UUID().uuidString, bytes: Data())
            var event = FlowElement(title: "Invalid test frame", content: try JSONDecoder().decode(FlowElementValueType.self, from: JSONEncoder().encode(invalid)), properties: .init(type: .event, contentType: .object))
            event.topic = ScannerMeetingRelay.topic
            try await pair.a.handleOutOfBandFlowElement(event, context: a)
            XCTAssertNil(route.bridge)
            XCTAssertNoThrow(try a.check()); XCTAssertNoThrow(try b.check())
            await pair.pa.close()
            XCTAssertFalse(a.isLive)
            do { try await route.receive(invalid, on: a); XCTFail("Retired generation accepted") } catch { }

        }
    }
}

private final class BridgeFixtureCapture: MeetingCaptureDevice, MeetingPreparedCapture, @unchecked Sendable {
    func prepare(plan: MeetingPlan) async throws -> any MeetingPreparedCapture { self }
    func start(session: MeetingConsentSession, permit: MeetingRecordingPermit) throws { }
    func stop() { }
    func cancelProcessing() { }
    var isProcessing: Bool { false }
}
