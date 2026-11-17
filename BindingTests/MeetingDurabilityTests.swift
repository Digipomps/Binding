import XCTest
@testable import CellBase

final class MeetingDurabilityTests: XCTestCase {
    func testDurableCellStopsBeforeNewRosterAndRequiresEveryFreshApproval() async throws {
        let vault = MeetingTestIdentityVault(); let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault; defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "owner", makeNewIfNotFound: true)!
        let guest = await vault.identity(for: "guest", makeNewIfNotFound: true)!
        let late = await vault.identity(for: "late", makeNewIfNotFound: true)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingDurableCell-" + UUID().uuidString)
        let store = try MeetingFileStore(directory: directory); let key = Data(repeating: 7, count: 32)
        let cell = await MeetingSessionCell(owner: owner)
        try cell.installDurability(store: store, key: key)
        let principals = try [owner,guest,late].map { try MeetingEvidence.principal($0) }
        let plan = MeetingPlan(purpose: "Durability acceptance", participants: Array(principals.prefix(2)), recorder: principals[0])
        func ok(_ response: ValueType?) { XCTAssertEqual(ExploreContract.object(from: response)?["status"], .string("ok")) }
        ok(try await cell.set(keypath: "plan.propose", value: .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(plan)]), requester: owner))
        let admission = await cell.addAgreement(cell.agreementTemplate, for: guest, authorizedBy: owner)
        XCTAssertEqual(admission, .signed)
        let device = DurableTestCapture()
        try cell.installCaptureDevice(device)
        let ref = try cell.durableSnapshot().reference
        for person in [owner,guest,guest] { // double approval is still one receipt/person
            let proof = try await MeetingSignedConsent.approve(cellID: cell.uuid, reference: ref, plan: plan, identity: person)
            ok(try await cell.set(keypath: "consent.submit", value: MeetingSurfaceConfiguration.encode(proof), requester: person))
        }
        let startID = UUID()
        let start = MeetingSurfaceConfiguration.encode(MeetingActionInput(operationID: startID, expected: ref))
        ok(try await cell.set(keypath: "recording.start", value: start, requester: owner))
        XCTAssertEqual(device.starts, 1)
        let newPlan = MeetingPlan(purpose: plan.purpose, participants: principals, recorder: principals[0])
        ok(try await cell.set(keypath: "plan.propose", value: .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(newPlan), "expected": MeetingSurfaceConfiguration.encode(ref)]), requester: owner))
        XCTAssertTrue(device.stopped)
        let snapshot = try cell.durableSnapshot()
        XCTAssertNil(snapshot.recording); XCTAssertTrue(snapshot.approvals.isEmpty)
        let segment = try XCTUnwrap(snapshot.segments.first)
        XCTAssertEqual(try cell.consentEvidence(for: segment).count, 2)
        let package = MeetingTranscriptPackage(cellID: cell.uuid, segment: segment, consents: try cell.consentEvidence(for: segment), transcript: "Synthetic", incomplete: false, uncertainties: [])
        XCTAssertNoThrow(try package.validate())
        let newRef = snapshot.reference
        for person in [owner,guest] {
            let proof = try await MeetingSignedConsent.approve(cellID: cell.uuid, reference: newRef, plan: newPlan, identity: person)
            ok(try await cell.set(keypath: "consent.submit", value: MeetingSurfaceConfiguration.encode(proof), requester: person))
        }
        let incomplete = try await cell.set(keypath: "recording.start", value: MeetingSurfaceConfiguration.encode(MeetingActionInput(expected: newRef)), requester: owner)
        XCTAssertEqual(ExploreContract.object(from: incomplete)?["code"], .string("consentIncomplete"))
        XCTAssertEqual(device.starts, 1)
        let lateAdmission = await cell.addAgreement(cell.agreementTemplate, for: late, authorizedBy: owner)
        XCTAssertEqual(lateAdmission, .signed)
        let lateProof = try await MeetingSignedConsent.approve(cellID: cell.uuid, reference: newRef, plan: newPlan, identity: late)
        ok(try await cell.set(keypath: "consent.submit", value: MeetingSurfaceConfiguration.encode(lateProof), requester: late))
        XCTAssertEqual(device.starts, 1, "Last yes does not auto-start")
        let restored = try JSONDecoder().decode(MeetingSessionCell.self, from: JSONEncoder().encode(cell))
        try await restored.ensureRuntimeReady()
        try restored.installDurability(store: MeetingFileStore(directory: directory), key: key)
        let afterRestart = try restored.durableSnapshot()
        XCTAssertTrue(afterRestart.approvals.isEmpty); XCTAssertNil(afterRestart.recording)
        XCTAssertNotEqual(afterRestart.reference, newRef)
    }

    func testParticipantClientsDeliverThroughAuthorizedCellAndSurviveInboxReload() async throws {
        let vault = MeetingTestIdentityVault(); let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault; defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "host-client", makeNewIfNotFound: true)!
        let guest = await vault.identity(for: "guest-client", makeNewIfNotFound: true)!
        let people = [owner, guest]
        let cell = await MeetingSessionCell(owner: owner)
        func storage(_ name: String) throws -> MeetingFileStore {
            try MeetingFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(name + UUID().uuidString))
        }
        try cell.installDurability(store: storage("cell-journal-"), key: Data(repeating: 1, count: 32))
        let principals = try people.map { try MeetingEvidence.principal($0) }
        let plan = MeetingPlan(purpose: "Client-cell-delivery", participants: principals, recorder: principals[0])
        let initial = try await cell.set(keypath: "plan.propose", value: .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(plan)]), requester: owner)
        XCTAssertEqual(ExploreContract.object(from: initial)?["status"], .string("ok"))
        let admission = await cell.addAgreement(cell.agreementTemplate, for: guest, authorizedBy: owner)
        XCTAssertEqual(admission, .signed)
        try cell.installCaptureDevice(DurableTestCapture())
        try cell.installDelivery(store: storage("cell-outbox-"), recorder: owner, provider: vault)
        let inboxStores = try people.map { _ in try storage("client-inbox-") }
        let inboxes = zip(people,inboxStores).map { MeetingDeliveryService(identity: $0, provider: vault, store: $1) }
        let clients = zip(people,inboxes).map { MeetingParticipantClient(cellID: cell.uuid, target: cell, identity: $0, recorder: owner, inbox: $1) }
        let ref = try cell.durableSnapshot().reference
        for client in clients {
            let operationID = UUID()
            try await client.approve(expected: ref, operationID: operationID)
            try await client.approve(expected: ref, operationID: operationID) // lost-response retry
            try await client.pulse()
        }
        try await clients[0].start(expected: ref)
        try await clients[1].pulse(); try await clients[0].pulse()
        try await clients[1].stop(expected: ref)
        let segment = try XCTUnwrap(cell.durableSnapshot().segments.last)
        let packet = try await cell.completeSegment(segment.id, transcript: "Syntetisk klientprøve", incomplete: false, uncertainties: [])
        let retried = try await cell.completeSegment(segment.id, transcript: "Syntetisk klientprøve", incomplete: false, uncertainties: [])
        XCTAssertEqual(packet, retried)
        for i in clients.indices {
            let count = try await clients[i].synchronizeDelivery(); XCTAssertEqual(count, 1)
            let restored = MeetingDeliveryService(identity: people[i], provider: vault, store: inboxStores[i])
            let text = try await restored.readReceived(packetID: packet.id, sender: owner)
            XCTAssertEqual(text.transcript, "Syntetisk klientprøve")
        }
    }

    func testCancelledStartAfterDurableCallbackNeverStartsDevice() async throws {
        let a = MeetingPrincipal(id: "a", signingKeyFingerprint: "a"), b = MeetingPrincipal(id: "b", signingKeyFingerprint: "b")
        let policy = try MeetingConsentSession(owner: a, plan: MeetingPlan(purpose: "Cancel start", participants: [a,b], recorder: a))
        let ref = try policy.snapshot(now: Date()).reference
        for member in [a,b] { try policy.approve(by: member, expected: ref, now: Date()) }
        let device = DurableTestCapture(), gate = DurableStartGate()
        let coordinator = MeetingCaptureCoordinator(session: policy, device: device, beforeCapture: { _ in await gate.pause() })
        let attempt = Task { try await coordinator.start(by: a, expected: ref) }
        await gate.waitForEntry()
        attempt.cancel(); await gate.release()
        do { _ = try await attempt.value; XCTFail("Cancelled start succeeded") } catch {}
        XCTAssertEqual(device.starts, 0)
        XCTAssertNil(try policy.snapshot(now: Date()).recording)
    }

    func testSignedApprovalCannotExtendItsAbsoluteExpiry() throws {
        let a = MeetingPrincipal(id: "a", signingKeyFingerprint: "a"), b = MeetingPrincipal(id: "b", signingKeyFingerprint: "b")
        let now = Date()
        let policy = try MeetingConsentSession(owner: a, plan: MeetingPlan(purpose: "Expiry", participants: [a,b], recorder: a), now: now)
        let ref = try policy.snapshot(now: now).reference
        for member in [a,b] { try policy.approve(by: member, expected: ref, now: now, signedExpiry: now.addingTimeInterval(0.1)) }
        XCTAssertThrowsError(try policy.start(by: a, expected: ref, now: now.addingTimeInterval(0.2)))
    }

    func testJournalRejectsWrongKeyAndRepairsUncertainAppendWithoutNewCiphertext() throws {
        let a = MeetingPrincipal(id: "a", signingKeyFingerprint: "a"), b = MeetingPrincipal(id: "b", signingKeyFingerprint: "b")
        let policy = try MeetingConsentSession(owner: a, plan: MeetingPlan(purpose: "Journal", participants: [a,b], recorder: a))
        let base = try MeetingFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("MeetingJournal-" + UUID().uuidString))
        let faulty = UncertainCommitStore(base: base)
        let key = Data(repeating: 8, count: 32), id = UUID().uuidString
        let journal = try MeetingEncryptedJournal(store: faulty, key: key, cellID: id, owner: a)
        XCTAssertThrowsError(try journal.commit(snapshot: policy.snapshot(now: Date()), consents: [], startOperations: []))
        try journal.commit(snapshot: policy.snapshot(now: Date()), consents: [], startOperations: [])
        let restored = try MeetingEncryptedJournal(store: base, key: key, cellID: id, owner: a)
        XCTAssertEqual(restored.latest?.sequence, 2)
        XCTAssertThrowsError(try MeetingEncryptedJournal(store: base, key: Data(repeating: 9, count: 32), cellID: id, owner: a))
    }
}
private final class DurableTestCapture: MeetingCaptureDevice, MeetingPreparedCapture, @unchecked Sendable {
    private let lock = NSLock(); private var startCount = 0; private var didStop = false
    var starts: Int { lock.lock(); defer { lock.unlock() }; return startCount }
    var stopped: Bool { lock.lock(); defer { lock.unlock() }; return didStop }
    func prepare(plan: MeetingPlan) async throws -> any MeetingPreparedCapture { self }
    func start(session: MeetingConsentSession, permit: MeetingRecordingPermit) throws { lock.lock(); defer { lock.unlock() }; startCount += 1; didStop = false }
    func stop() { lock.lock(); defer { lock.unlock() }; didStop = true }
    func cancelProcessing() { stop() }
    var isProcessing: Bool { false }
}
private final class UncertainCommitStore: MeetingDurableStore, @unchecked Sendable {
    let base: MeetingFileStore; private var failed = false
    init(base: MeetingFileStore) { self.base = base }
    func read(_ key: String) throws -> Data? { try base.read(key) }
    func commit(_ bytes: Data, key: String) throws {
        try base.commit(bytes, key: key)
        if !failed { failed = true; throw CocoaError(.fileWriteUnknown) }
    }
    func commitReceipt(_ bytes: Data, key: String, requiring package: Data, packageKey: String) throws { try base.commitReceipt(bytes, key: key, requiring: package, packageKey: packageKey) }
    func remove(_ key: String) throws { try base.remove(key) }
    func keys() throws -> [String] { try base.keys() }
}

private actor DurableStartGate {
    private var entered = false
    private var entry: CheckedContinuation<Void, Never>?
    private var resume: CheckedContinuation<Void, Never>?
    func pause() async {
        entered = true; entry?.resume(); entry = nil
        await withCheckedContinuation { resume = $0 }
    }
    func waitForEntry() async { if !entered { await withCheckedContinuation { entry = $0 } } }
    func release() { resume?.resume(); resume = nil }
}
