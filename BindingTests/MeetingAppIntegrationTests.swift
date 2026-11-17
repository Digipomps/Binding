import XCTest
import CryptoKit
@_spi(Testing) @testable import CellBase
@testable import Binding
@testable import CellApple

final class MeetingAppIntegrationTests: XCTestCase {
    @MainActor func testPipelineWaitsForArchiveFenceThenDeliversReadablePackageAndDeletesAudio() async throws {
        let vault = MeetingTestIdentityVault(), previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault; defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "pipeline-owner", makeNewIfNotFound: true)!
        let guest = await vault.identity(for: "pipeline-guest", makeNewIfNotFound: true)!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingApp-" + UUID().uuidString)
        func store(_ name: String) throws -> MeetingFileStore { try MeetingFileStore(directory: root.appendingPathComponent(name)) }
        let cell = await MeetingSessionCell(owner: owner)
        try cell.installDurability(store: store("journal"), key: Data(repeating: 5, count: 32))
        let plan = MeetingPlan(purpose: "Synthetic pipeline", participants: try [owner, guest].map(MeetingEvidence.principal), recorder: try MeetingEvidence.principal(owner))
        _ = try await cell.set(keypath: "plan.propose", value: .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(plan)]), requester: owner)
        let admission = await cell.addAgreement(cell.agreementTemplate, for: guest, authorizedBy: owner)
        XCTAssertEqual(admission, .signed)
        try cell.installDelivery(store: store("outbox"), recorder: owner, provider: vault)
        try cell.installCaptureDevice(AppFixtureCapture())
        let reference = try cell.durableSnapshot().reference
        for person in [owner, guest] {
            let signed = try await MeetingSignedConsent.approve(cellID: cell.uuid, reference: reference, plan: plan, identity: person)
            _ = try await cell.set(keypath: "consent.submit", value: MeetingSurfaceConfiguration.encode(signed), requester: person)
        }
        _ = try await cell.set(keypath: "recording.start", value: MeetingSurfaceConfiguration.encode(MeetingActionInput(expected: reference)), requester: owner)
        let permit = try XCTUnwrap(cell.durableSnapshot().recording)
        let key = SymmetricKey(size: .bits256)
        let pipeline = MeetingRecordingPipeline(cell: cell, store: try store("audio"), key: key, recognize: { chunks, segment, key in
            _ = try MeetingOnDeviceChunkTranscriber.validatedBuffers(chunks, segment: segment, key: key)
            return MeetingTranscriptPart(permit: chunks[0].header.permit, start: 0, duration: 0.128, text: "Alle godkjenner på nytt.")
        })
        try pipeline.archive.append(MeetingAudioIntegrityTests().chunk(permit, key))
        _ = try await cell.set(keypath: "recording.stop", value: MeetingSurfaceConfiguration.encode(MeetingActionInput(expected: reference)), requester: guest)
        try await pipeline.maintain()
        let premature = try await cell.hasTranscript(for: permit.segmentID)
        XCTAssertFalse(premature, "No finalization while the physical adapter is draining admitted buffers")
        try pipeline.archive.finish(permit.segmentID, complete: true)
        try await pipeline.maintain()
        for _ in 0..<100 {
            if try await cell.hasTranscript(for: permit.segmentID) { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let completed = try await cell.hasTranscript(for: permit.segmentID); XCTAssertTrue(completed)
        let inbox = MeetingDeliveryService(identity: guest, provider: vault, store: try store("inbox"))
        let client = MeetingParticipantClient(cellID: cell.uuid, target: cell, identity: guest, recorder: owner, inbox: inbox)
        let delivered = try await client.synchronizeDelivery(); XCTAssertEqual(delivered, 1)
        let package = try await inbox.readReceived(packetID: permit.segmentID.uuidString + "-v1", sender: owner)
        XCTAssertEqual(package.transcript, "Alle godkjenner på nytt."); XCTAssertFalse(package.incomplete)
        for _ in 0..<100 {
            if try pipeline.archive.keys(permit.segmentID).isEmpty { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(try pipeline.archive.keys(permit.segmentID).isEmpty)
        let reader = await MeetingInboxCell(owner: guest)
        reader.add(cellID: cell.uuid, inbox: MeetingDeliveryService(identity: guest, provider: vault, store: try store("inbox")), sender: owner)
        let state = try await reader.get(keypath: "state", requester: guest)
        XCTAssertTrue(String(data: try JSONEncoder().encode(state), encoding: .utf8)!.contains("Alle godkjenner"))
        try exportAppFixture(name: "received-inbox", configuration: reader.configuration(), root: .object(["inbox": .object(["state": state])]))
        do { _ = try await reader.get(keypath: "state", requester: owner); XCTFail("Other local identity cannot read inbox") } catch { }
        let previousResolver = CellBase.defaultCellResolver
        let resolver = CellResolver.makeIsolatedForTesting(); CellBase.defaultCellResolver = resolver
        defer { CellBase.defaultCellResolver = previousResolver }
        let surface = await MeetingParticipantSurfaceCell(owner: guest)
        surface.bind(target: cell, client: client)
        try await resolver.registerNamedEmitCell(name: surface.uuid, emitCell: surface, scope: .identityUnique, identity: guest)
        let currentReference = try cell.durableSnapshot().reference
        // Binding main has no mounted-action dispatcher (it lived on the 13.10 side
        // branch with an unpublished CellProtocol). Dispatch the same keypath and
        // payload to the participant surface the app renders.
        let mounted = try await surface.set(keypath: "consent.approve",
            value: MeetingSurfaceConfiguration.encode(MeetingActionInput(expected: currentReference)), requester: guest) ?? .null
        XCTAssertEqual(ExploreContract.object(from: mounted)?["status"], .string("ok"))
        XCTAssertEqual(try cell.durableSnapshot().approvals.map(\.participant), [try MeetingEvidence.principal(guest)])

    }

    func testSignedNearbyJoinClearsEveryApprovalAndCannotServeAsRecordingConsent() async throws {
        let oldSink = CellBase.securityEventSink, oldDebug = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        CellBase.securityEventSink = MeetingJoinDiagnosticSink()
        defer { CellBase.securityEventSink = oldSink; CellBase.debugValidateAccessForEverything = oldDebug }

        let vault = MeetingTestIdentityVault(), previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault; defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "join-owner", makeNewIfNotFound: true)!
        let guest = await vault.identity(for: "join-guest", makeNewIfNotFound: true)!
        let late = await vault.identity(for: "join-late", makeNewIfNotFound: true)!
        let cell = await MeetingSessionCell(owner: owner)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingJoin-" + UUID().uuidString)
        try cell.installDurability(store: MeetingFileStore(directory: directory), key: Data(repeating: 6, count: 32))
        let plan = MeetingPlan(purpose: "Nearby join", participants: try [owner, guest].map(MeetingEvidence.principal), recorder: try MeetingEvidence.principal(owner))
        _ = try await cell.set(keypath: "plan.propose", value: .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(plan)]), requester: owner)
        let admission = await cell.addAgreement(cell.agreementTemplate, for: guest, authorizedBy: owner); XCTAssertEqual(admission, .signed)
        let capture = AppFixtureCapture(); try cell.installCaptureDevice(capture)
        let reference = try cell.durableSnapshot().reference
        for person in [owner, guest] {
            let signed = try await MeetingSignedConsent.approve(cellID: cell.uuid, reference: reference, plan: plan, identity: person)
            _ = try await cell.set(keypath: "consent.submit", value: MeetingSurfaceConfiguration.encode(signed), requester: person)
        }
        _ = try await cell.set(keypath: "recording.start", value: MeetingSurfaceConfiguration.encode(MeetingActionInput(expected: reference)), requester: owner)
        XCTAssertNotNil(try cell.durableSnapshot().recording)
        let invite = try await MeetingNearbyInvitation.make(cellID: cell.uuid, endpoint: "cell:///" + cell.uuid, inviter: owner, recipient: MeetingEvidence.principal(late))
        let contract = try await cell.makeAdmission(for: late)
        let join = try await MeetingJoinRequest.make(invitation: invite, admission: contract, identity: late)
        do { _ = try await cell.set(keypath: "meeting.join", value: MeetingSurfaceConfiguration.encode(join), requester: guest); XCTFail("Wrong channel requester") } catch { }
        _ = try await cell.set(keypath: "meeting.join", value: MeetingSurfaceConfiguration.encode(join), requester: late)
        let snapshot = try cell.durableSnapshot()
        XCTAssertEqual(snapshot.plan.participants.count, 3); XCTAssertTrue(snapshot.approvals.isEmpty)
        XCTAssertNil(snapshot.recording); XCTAssertTrue(capture.stopped)
        XCTAssertNotEqual(reference, snapshot.reference)
        let viewState = try await cell.get(keypath: "state", requester: owner)
        try exportAppFixture(name: "joined-meeting", configuration: MeetingSurfaceConfiguration.make(endpoint: "cell:///" + cell.uuid), root: .object(["meeting": .object(["state": viewState])]))
    }
}

private final class AppFixtureCapture: MeetingCaptureDevice, MeetingPreparedCapture, @unchecked Sendable {
    private let lock = NSLock(); private var stopValue = false
    var stopped: Bool { lock.withLock { stopValue } }
    func prepare(plan: MeetingPlan) async throws -> any MeetingPreparedCapture { self }
    func start(session: MeetingConsentSession, permit: MeetingRecordingPermit) throws { }
    func stop() { lock.withLock { stopValue = true } }
    func cancelProcessing() { stop() }
    var isProcessing: Bool { false }
}

actor MeetingJoinDiagnosticSink: CellSecurityEventSink {
    func record(_ event: CellSecurityEvent) async { print("ADMISSION REASON", event.reasonCode) }
}

private func exportAppFixture(name: String, configuration: CellConfiguration, root: ValueType) throws {
    guard let path = ProcessInfo.processInfo.environment["MEETING_APP_FIXTURES"] else { return }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let directory = URL(fileURLWithPath: path).appendingPathComponent(name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try encoder.encode(configuration.skeleton).write(to: directory.appendingPathComponent("skeleton.json"))
    try encoder.encode(root).write(to: directory.appendingPathComponent("root.json"))
    try encoder.encode(["width":1280,"height":1100]).write(to: directory.appendingPathComponent("viewport.json"))
    try Data(##"{"padding":0,"contentMaxWidth":1280,"backgroundHex":"#F5F2E9"}"##.utf8).write(to: directory.appendingPathComponent("surface.json"))
}
