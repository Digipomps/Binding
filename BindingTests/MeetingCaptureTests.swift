import XCTest
@testable import CellBase

final class MeetingCaptureTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1000)
    let a = MeetingPrincipal(id: "host", signingKeyFingerprint: "host-key")
    let b = MeetingPrincipal(id: "guest", signingKeyFingerprint: "guest-key")
    let c = MeetingPrincipal(id: "nearby", signingKeyFingerprint: "nearby-key")

    final class Capture: MeetingPreparedCapture, @unchecked Sendable {
        private let lock = NSLock()
        private var starts = 0; private var stops = 0; private var cancellations = 0
        var isProcessing: Bool { lock.lock(); defer { lock.unlock() }; return starts > 0 && cancellations == 0 }
        var startCount: Int { lock.lock(); defer { lock.unlock() }; return starts }
        var stopCount: Int { lock.lock(); defer { lock.unlock() }; return stops }
        var cancellationCount: Int { lock.lock(); defer { lock.unlock() }; return cancellations }
        func start(session: MeetingConsentSession, permit: MeetingRecordingPermit) throws {
            lock.lock(); defer { lock.unlock() }; starts += 1
        }
        func stop() { lock.lock(); defer { lock.unlock() }; stops += 1 }
        func cancelProcessing() { lock.lock(); cancellations += 1; lock.unlock(); stop() }
    }
    struct Device: MeetingCaptureDevice {
        let prepareBlock: @Sendable () async throws -> any MeetingPreparedCapture
        func prepare(plan: MeetingPlan) async throws -> any MeetingPreparedCapture { try await prepareBlock() }
    }
    actor Preparation {
        var waiting = false
        var continuation: CheckedContinuation<Void, Never>?
        func pause() async { await withCheckedContinuation { waiting = true; continuation = $0 } }
        func resume() { waiting = false; continuation?.resume(); continuation = nil }
    }
    final class Clock: @unchecked Sendable {
        private let lock = NSLock(); private var value: Date
        init(_ value: Date) { self.value = value }
        func read() -> Date { lock.lock(); defer { lock.unlock() }; return value }
        func advance(_ seconds: Double) { lock.lock(); defer { lock.unlock() }; value.addTimeInterval(seconds) }
    }
    func approved() throws -> (MeetingConsentSession, MeetingPlanReference) {
        let session = try MeetingConsentSession(owner: a, plan: MeetingPlan(purpose: "Fixture", participants: [a,b], recorder: a), now: now)
        let ref = try session.snapshot(now: now).reference
        for person in [a,b] { try session.approve(by: person, expected: ref, now: now) }
        return (session, ref)
    }
    func testNewNearbyParticipantDuringPreparationNeverStartsMicrophone() async throws {
        let (session, ref) = try approved(); let capture = Capture(); let prep = Preparation(); let clock = Clock(now)
        let device = Device { await prep.pause(); return capture }
        let controller = MeetingCaptureCoordinator(session: session, device: device, clock: clock.read)
        let start = Task { try await controller.start(by: a, expected: ref) }
        while !(await prep.waiting) { await Task.yield() }
        try session.replacePlan(MeetingPlan(purpose: "Fixture", participants: [a,b,c], recorder: a), by: a, expected: ref, now: now)
        await prep.resume()
        do { _ = try await start.value; XCTFail("Stale preparation started") } catch { }
        XCTAssertEqual(capture.startCount, 0)
        XCTAssertTrue(try session.snapshot(now: now).approvals.isEmpty)
    }
    func testParticipantStopDuringPreparationCancelsPendingStart() async throws {
        let (session, ref) = try approved(); let capture = Capture(); let prep = Preparation(); let clock = Clock(now)
        let controller = MeetingCaptureCoordinator(session: session, device: Device { await prep.pause(); return capture }, clock: clock.read)
        let start = Task { try await controller.start(by: a, expected: ref) }
        while !(await prep.waiting) { await Task.yield() }
        try await controller.stop(by: b)
        await prep.resume()
        do { _ = try await start.value; XCTFail("Stopped preparation restarted") } catch { }
        XCTAssertEqual(capture.startCount, 0)
        XCTAssertTrue(try session.snapshot(now: now).approvals.isEmpty)
    }
    func testMissingConsentDoesNotEvenPrepareDevice() async throws {
        let (session, ref) = try approved()
        try session.stop(by: b, now: now)
        let current = try session.snapshot(now: now).reference
        let clock = Clock(now)
        let controller = MeetingCaptureCoordinator(session: session, device: Device { XCTFail("Permission preparation without all yes"); return Capture() }, clock: clock.read)
        do { _ = try await controller.start(by: a, expected: current); XCTFail() } catch { }
        XCTAssertNotEqual(current, ref)
    }
    func testCancelledPreparationDoesNotLeaveStartPermanentlyBusy() async throws {
        let (session, ref) = try approved(); let prep = Preparation(); let clock = Clock(now)
        let controller = MeetingCaptureCoordinator(session: session, device: Device { await prep.pause(); return Capture() }, clock: clock.read)
        let first = Task { try await controller.start(by: a, expected: ref) }
        while !(await prep.waiting) { await Task.yield() }
        first.cancel(); await prep.resume()
        do { _ = try await first.value; XCTFail() } catch { }
        let second = Task { try await controller.start(by: a, expected: ref) }
        while !(await prep.waiting) { await Task.yield() }
        await prep.resume()
        _ = try await second.value
        try await controller.stop(by: b)
    }
    func testRevocationCancelsProcessingButNewRosterFinishesOldSegment() async throws {
        for revoked in [true, false] {
            let (session, ref) = try approved(); let capture = Capture(); let clock = Clock(now)
            let controller = MeetingCaptureCoordinator(session: session, device: Device { capture }, clock: clock.read)
            _ = try await controller.start(by: a, expected: ref)
            if revoked { try session.decline(by: b, expected: ref, now: now) }
            else { try session.replacePlan(MeetingPlan(purpose: "Fixture", participants: [a,b,c], recorder: a), by: a, expected: ref, now: now) }
            await controller.checkAdmission()
            XCTAssertEqual(capture.cancellationCount, revoked ? 1 : 0)
            XCTAssertEqual(capture.stopCount, 1)
            XCTAssertTrue(try session.snapshot(now: now).approvals.isEmpty)
        }
    }
    func testLeaseExpiryStopsDeviceWithoutAudioCallbacks() async throws {
        let (session, ref) = try approved(); let capture = Capture(); let clock = Clock(now)
        let controller = MeetingCaptureCoordinator(session: session, device: Device { capture }, clock: clock.read)
        _ = try await controller.start(by: a, expected: ref)
        clock.advance(4)
        await controller.checkAdmission()
        XCTAssertEqual(capture.startCount, 1); XCTAssertEqual(capture.stopCount, 1)
        let active = await controller.isCapturing; XCTAssertFalse(active)
        XCTAssertTrue(try session.snapshot(now: clock.read()).approvals.isEmpty)
    }
    func testLateDeviceFailureCannotStopNewEpoch() throws {
        let (session, ref) = try approved()
        let old = try session.start(by: a, expected: ref, now: now)
        try session.stop(by: b, now: now)
        let current = try session.snapshot(now: now).reference
        for person in [a,b] { try session.approve(by: person, expected: current, now: now) }
        let new = try session.start(by: a, expected: current, now: now)
        session.captureFailed(epoch: old.epoch, now: now, reason: "lateSpeechError")
        XCTAssertEqual(try session.snapshot(now: now).recording?.epoch, new.epoch)
        session.captureFailed(epoch: new.epoch, now: now, reason: "diskFull")
        XCTAssertNil(try session.snapshot(now: now).recording)
        XCTAssertTrue(try session.snapshot(now: now).approvals.isEmpty)
    }
    func testRevocationReachesFinalizingSegmentAndSurvivesNewPlan() async throws {
        for stopFirst in [true, false] {
            let (session, ref) = try approved(); let capture = Capture(); let clock = Clock(now)
            let controller = MeetingCaptureCoordinator(session: session, device: Device { capture }, clock: clock.read)
            let permit = try await controller.start(by: a, expected: ref)
            if stopFirst { try await controller.stop(by: b) }
            let current = try session.snapshot(now: now).reference
            try session.decline(by: b, expected: current, now: now)
            let afterDecline = try session.snapshot(now: now).reference
            try session.replacePlan(MeetingPlan(purpose: "New roster", participants: [a,b,c], recorder: a), by: a, expected: afterDecline, now: now)
            let snapshot = try session.snapshot(now: now)
            XCTAssertTrue(snapshot.declined.isEmpty)
            XCTAssertTrue(snapshot.processingRevokedSegments?.contains(permit.segmentID) == true)
            await controller.checkAdmission()
            XCTAssertEqual(capture.cancellationCount, 1)
            let restored = try MeetingConsentSession(owner: a, restoring: JSONDecoder().decode(MeetingConsentSnapshot.self, from: JSONEncoder().encode(snapshot)), now: now)
            XCTAssertTrue(try restored.snapshot(now: now).processingRevokedSegments?.contains(permit.segmentID) == true)
        }
    }
    func testRemovedParticipantCanRevokeOriginalSegmentWithoutStoppingNewRoster() async throws {
        let (session, ref) = try approved(); let capture = Capture(); let clock = Clock(now)
        let controller = MeetingCaptureCoordinator(session: session, device: Device { capture }, clock: clock.read)
        let old = try await controller.start(by: a, expected: ref)
        try session.replacePlan(MeetingPlan(purpose: "New roster", participants: [a,c], recorder: a), by: a, expected: ref, now: now)
        await controller.checkAdmission()
        let current = try session.snapshot(now: now).reference
        for participant in [a,c] { try session.approve(by: participant, expected: current, now: now) }
        let later = try session.start(by: a, expected: current, now: now)
        XCTAssertThrowsError(try session.revokeProcessing(segmentID: old.segmentID, by: c, expected: ref, now: now))
        XCTAssertThrowsError(try session.revokeProcessing(segmentID: old.segmentID, by: b, expected: current, now: now))
        let operation = UUID()
        try session.revokeProcessing(segmentID: old.segmentID, by: b, operationID: operation, expected: ref, now: now)
        try session.revokeProcessing(segmentID: old.segmentID, by: b, operationID: operation, expected: ref, now: now)
        await controller.checkAdmission()
        XCTAssertEqual(capture.cancellationCount, 1)
        XCTAssertEqual(try session.snapshot(now: now).recording?.epoch, later.epoch)
        XCTAssertThrowsError(try session.revokeProcessing(segmentID: later.segmentID, by: a, operationID: operation, expected: current, now: now))
    }
}
