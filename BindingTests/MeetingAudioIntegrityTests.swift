import XCTest
import AVFoundation
import CryptoKit
@testable import CellBase
@testable import CellApple

final class MeetingAudioIntegrityTests: XCTestCase {
    func fixture() throws -> (MeetingSegment, MeetingRecordingPermit, SymmetricKey) {
        let a = MeetingPrincipal(id: "a", signingKeyFingerprint: "a-key")
        let b = MeetingPrincipal(id: "b", signingKeyFingerprint: "b-key")
        let now = Date()
        let s = try MeetingConsentSession(owner: a, plan: MeetingPlan(purpose: "Synthetic PCM", participants: [a,b], recorder: a), now: now)
        let ref = try s.snapshot(now: now).reference
        for p in [a,b] { try s.approve(by: p, expected: ref, now: now) }
        let permit = try s.start(by: a, expected: ref, now: now)
        try s.stop(by: b, now: now.addingTimeInterval(1))
        return (try s.snapshot(now: now.addingTimeInterval(1)).segments[0], permit, SymmetricKey(size: .bits256))
    }
    func chunk(_ permit: MeetingRecordingPermit, _ key: SymmetricKey, sequence: UInt64 = 0, frames: UInt32 = 1024) throws -> MeetingEncryptedAudioChunk {
        let header = MeetingEncryptedAudioChunk.Header(permit: permit, sequence: sequence, sampleRate: 8000,
            channels: 1, frames: frames, commonFormat: AVAudioCommonFormat.pcmFormatFloat32.rawValue,
            interleaved: false, planeSizes: [Int(frames) * 4])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = Data(repeating: 0, count: Int(frames) * 4)
        let sealed = try AES.GCM.seal(data, using: key, authenticating: encoder.encode(header))
        return MeetingEncryptedAudioChunk(header: header, ciphertext: try XCTUnwrap(sealed.combined))
    }
    func testAuthenticatedPCMRestoresExactFramesAndRejectsWrongKeyOrHeader() throws {
        let (segment, permit, key) = try fixture()
        let first = try chunk(permit, key)
        let buffers = try MeetingOnDeviceChunkTranscriber.validatedBuffers([first], segment: segment, key: key)
        XCTAssertEqual(buffers.count, 1); XCTAssertEqual(buffers[0].frameLength, 1024)
        XCTAssertThrowsError(try first.decryptedPCM(using: SymmetricKey(size: .bits256)))
        let changedHeader = try chunk(permit, key, sequence: 1).header
        XCTAssertThrowsError(try MeetingEncryptedAudioChunk(header: changedHeader, ciphertext: first.ciphertext).decryptedPCM(using: key))
    }
    func testCrossSegmentAndOutOfOrderChunksNeverReachSpeech() throws {
        let (segment, permit, key) = try fixture()
        let (_, other, _) = try fixture()
        XCTAssertThrowsError(try MeetingOnDeviceChunkTranscriber.validatedBuffers([chunk(other,key)], segment: segment, key: key))
        XCTAssertThrowsError(try MeetingOnDeviceChunkTranscriber.validatedBuffers([chunk(permit,key),chunk(permit,key,sequence:2)], segment: segment, key: key))
    }
    func testLegacyRequestCannotExceed45Seconds() throws {
        let (segment, permit, key) = try fixture()
        let chunks = try (0..<46).map { try chunk(permit, key, sequence: UInt64($0), frames: 8000) }
        XCTAssertThrowsError(try MeetingOnDeviceChunkTranscriber.validatedBuffers(chunks, segment: segment, key: key))
        let valid = try MeetingOnDeviceChunkTranscriber.validatedBuffers(Array(chunks.prefix(45)), segment: segment, key: key)
        XCTAssertEqual(valid.reduce(0) { $0 + Int($1.frameLength) }, 360000)
    }
}
