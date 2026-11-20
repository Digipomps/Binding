import XCTest
@testable import CellBase

final class MeetingDeliveryTests: XCTestCase {
    struct Fixture {
        let vault: MeetingTestIdentityVault
        let identities: [Identity]
        let package: MeetingTranscriptPackage
        let now: Date
    }
    func fixture() async throws -> Fixture {
        let vault = MeetingTestIdentityVault()
        var people: [Identity] = []
        for label in ["recorder", "participant", "third", "late"] {
            let person = await vault.identity(for: label, makeNewIfNotFound: true)
            people.append(try XCTUnwrap(person))
        }
        let participants = try people.prefix(3).map { try MeetingEvidence.principal($0) }
        let plan = MeetingPlan(purpose: "Synthetic delivery acceptance", participants: participants, recorder: participants[0])
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = try MeetingConsentSession(owner: participants[0], plan: plan, now: now)
        let ref = try session.snapshot(now: now).reference
        let cellID = UUID().uuidString
        var proofs: [MeetingSignedConsent] = []
        for person in people.prefix(3) {
            let proof = try await MeetingSignedConsent.approve(cellID: cellID, reference: ref, plan: plan, identity: person, now: now)
            proofs.append(proof)
            try session.approve(by: proof.principal, operationID: proof.operationID, expected: ref, now: now)
        }
        _ = try session.start(by: participants[0], expected: ref, now: now.addingTimeInterval(0.1))
        try session.stop(by: participants[1], now: now.addingTimeInterval(1))
        let segment = try XCTUnwrap(session.snapshot(now: now.addingTimeInterval(1)).segments.first)
        let package = MeetingTranscriptPackage(cellID: cellID, segment: segment, consents: proofs,
            transcript: "Syntetisk møte. Alle må godkjenne på nytt.", incomplete: false, uncertainties: ["Automatisk tekst; ingen taleridentifikasjon."], createdAt: now.addingTimeInterval(2))
        return Fixture(vault: vault, identities: people, package: package, now: now.addingTimeInterval(3))
    }
    func store() throws -> MeetingFileStore {
        try MeetingFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("MeetingDeliveryTests-" + UUID().uuidString))
    }
    func testThreeRecipientsReloadRetryAndOfflineReceipt() async throws {
        let f = try await fixture(); let out = try store()
        let sender = MeetingDeliveryService(identity: f.identities[0], provider: f.vault, store: out)
        let packet = try await sender.enqueue(f.package, now: f.now)
        let retryPacket = try await sender.enqueue(f.package, now: f.now)
        XCTAssertEqual(retryPacket, packet)
        var states = try await sender.states(packetID: packet.id, now: f.now)
        XCTAssertEqual(states.values.filter { $0 == .queued }.count, 3)
        for person in f.identities.prefix(3) {
            let inbox = try store()
            let receiver = MeetingDeliveryService(identity: person, provider: f.vault, store: inbox)
            let receipt = try await receiver.receive(packet, authenticatedSender: f.identities[0], now: f.now)
            let restored = MeetingDeliveryService(identity: person, provider: f.vault, store: inbox)
            let loaded = try await restored.readReceived(packetID: packet.id, sender: f.identities[0], now: f.now)
            XCTAssertEqual(loaded, f.package)
            let retryReceipt = try await restored.receive(packet, authenticatedSender: f.identities[0], now: f.now)
            XCTAssertEqual(retryReceipt, receipt)
            try await sender.acknowledge(receipt, authenticatedRecipient: person, now: f.now)
        }
        let restoredOut = MeetingDeliveryService(identity: f.identities[0], provider: f.vault, store: out)
        states = try await restoredOut.states(packetID: packet.id, now: f.now)
        XCTAssertEqual(states.values.filter { $0 == .stored }.count, 3)
        // Durable files contain ciphertext, not transcript text.
        for key in try out.keys() { XCTAssertFalse(String(decoding: try XCTUnwrap(out.read(key)), as: UTF8.self).contains(f.package.transcript)) }
    }
    func testLateParticipantWrongSenderTamperAndExpiryAreRejected() async throws {
        let f = try await fixture()
        let sender = MeetingDeliveryService(identity: f.identities[0], provider: f.vault, store: try store())
        let packet = try await sender.enqueue(f.package, now: f.now)
        let late = MeetingDeliveryService(identity: f.identities[3], provider: f.vault, store: try store())
        do { _ = try await late.receive(packet, authenticatedSender: f.identities[0], now: f.now); XCTFail("late member got old segment") } catch {}
        let receiver = MeetingDeliveryService(identity: f.identities[1], provider: f.vault, store: try store())
        do { _ = try await receiver.receive(packet, authenticatedSender: f.identities[3], now: f.now); XCTFail("wrong sender") } catch {}
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: MeetingEvidence.bytes(packet)) as? [String: Any])
        json["packageHash"] = String(repeating: "0", count: 64)
        let changed = try JSONDecoder().decode(MeetingDeliveryPacket.self, from: JSONSerialization.data(withJSONObject: json))
        do { _ = try await receiver.receive(changed, authenticatedSender: f.identities[0], now: f.now); XCTFail("tampered hash") } catch {}
        do { _ = try await receiver.receive(packet, authenticatedSender: f.identities[0], now: packet.deliveryExpiresAt); XCTFail("expired delivery") } catch {}
        let receipt = try await receiver.receive(packet, authenticatedSender: f.identities[0], now: f.now)
        do { try await sender.acknowledge(receipt, authenticatedRecipient: f.identities[2], now: f.now); XCTFail("proxy receipt") } catch {}
    }
    func testDiskFailureCannotReturnStoredReceiptAndExpiryDeletes() async throws {
        let f = try await fixture()
        let sender = MeetingDeliveryService(identity: f.identities[0], provider: f.vault, store: try store())
        let packet = try await sender.enqueue(f.package, now: f.now)
        let broken = MeetingDeliveryService(identity: f.identities[1], provider: f.vault, store: FailingMeetingStore())
        do { _ = try await broken.receive(packet, authenticatedSender: f.identities[0], now: f.now); XCTFail("receipt without durable commit") } catch {}
        let inbox = try store()
        let receiver = MeetingDeliveryService(identity: f.identities[1], provider: f.vault, store: inbox)
        _ = try await receiver.receive(packet, authenticatedSender: f.identities[0], now: f.now)
        try await receiver.purgeExpired(now: packet.recipientExpiresAt)
        XCTAssertTrue(try inbox.keys().isEmpty)
        do { _ = try await receiver.readReceived(packetID: packet.id, sender: f.identities[0], now: packet.recipientExpiresAt); XCTFail("expired copy") } catch {}
    }
    func testSignedNearbyInvitationBindsPeerRecipientCellAndExpiry() async throws {
        let f = try await fixture()
        let invite = try await MeetingNearbyInvitation.make(cellID: f.package.cellID, endpoint: "cell:///" + f.package.cellID,
            inviter: f.identities[0], recipient: MeetingEvidence.principal(f.identities[3]), now: f.now)
        try invite.verify(authenticatedPeer: f.identities[0], localRecipient: f.identities[3], now: f.now)
        XCTAssertThrowsError(try invite.verify(authenticatedPeer: f.identities[1], localRecipient: f.identities[3], now: f.now))
        XCTAssertThrowsError(try invite.verify(authenticatedPeer: f.identities[0], localRecipient: f.identities[2], now: f.now))
        XCTAssertThrowsError(try invite.verify(authenticatedPeer: f.identities[0], localRecipient: f.identities[3], now: invite.expiresAt))
    }
    func testAcknowledgedPacketsDoNotStarveLaterPacketsAndRevocationIsPerSegment() async throws {
        let f = try await fixture(), gate = DeliveryReleaseGate()
        let sender = MeetingDeliveryService(identity: f.identities[0], provider: f.vault, store: try store(), authorizeRelease: { try gate.check($0) })
        let receiver = MeetingDeliveryService(identity: f.identities[1], provider: f.vault, store: try store())
        var packets: [MeetingDeliveryPacket] = []
        for index in 0..<17 {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: MeetingEvidence.bytes(f.package)) as? [String: Any])
            var segment = try XCTUnwrap(json["segment"] as? [String: Any]); segment["id"] = UUID().uuidString
            json["segment"] = segment; json["transcript"] = "Synthetic segment \(index)"
            let package = try JSONDecoder().decode(MeetingTranscriptPackage.self, from: JSONSerialization.data(withJSONObject: json))
            packets.append(try await sender.enqueue(package, now: f.now))
        }
        let recipient = try MeetingEvidence.principal(f.identities[1])
        let firstPage = try await sender.pending(for: recipient, now: f.now)
        for packet in firstPage.prefix(16) {
            let receipt = try await receiver.receive(packet, authenticatedSender: f.identities[0], now: f.now)
            try await sender.acknowledge(receipt, authenticatedRecipient: f.identities[1], now: f.now)
        }
        let remainder = try await sender.pending(for: recipient, now: f.now)
        XCTAssertEqual(remainder.count, 1)
        let allForThird = try await sender.pending(for: MeetingEvidence.principal(f.identities[2]), now: f.now)
        XCTAssertEqual(allForThird.count, 17)
        gate.revoke(packets[0].segmentID)
        let afterRevoke = try await sender.pending(for: MeetingEvidence.principal(f.identities[2]), now: f.now)
        XCTAssertEqual(afterRevoke.count, 16)
        XCTAssertFalse(afterRevoke.contains { $0.segmentID == packets[0].segmentID })
    }

    func testUnsignedOrChangedConsentCannotBecomeTrustPackage() async throws {
        let f = try await fixture()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: MeetingEvidence.bytes(f.package)) as? [String: Any])
        var proofs = try XCTUnwrap(json["consents"] as? [[String: Any]])
        proofs[0]["signature"] = Data(repeating: 0, count: 64).base64EncodedString(); json["consents"] = proofs
        let forged = try JSONDecoder().decode(MeetingTranscriptPackage.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try forged.validate())
    }
}
private struct FailingMeetingStore: MeetingDurableStore {
    func read(_ key: String) throws -> Data? { nil }
    func commit(_ bytes: Data, key: String) throws { throw CocoaError(.fileWriteOutOfSpace) }
    func commitReceipt(_ bytes: Data, key: String, requiring package: Data, packageKey: String) throws { throw CocoaError(.fileWriteOutOfSpace) }
    func remove(_ key: String) throws {}
    func keys() throws -> [String] { [] }
}

private final class DeliveryReleaseGate: @unchecked Sendable {
    private let lock = NSLock(); private var revoked: Set<UUID> = []
    func revoke(_ id: UUID) { lock.lock(); defer { lock.unlock() }; revoked.insert(id) }
    func check(_ id: UUID) throws { lock.lock(); defer { lock.unlock() }; if revoked.contains(id) { throw MeetingSessionError.forbidden } }
}
