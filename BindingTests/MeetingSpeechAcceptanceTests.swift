import XCTest
import Speech
import AVFoundation
import CryptoKit
@testable import CellBase
@testable import CellApple

/// Opt-in diagnostic only. Never part of routine CI or microphone tests.
final class MeetingSpeechAcceptanceTests: XCTestCase {
    func testExplicitlyAuthorizedSyntheticNorwegianSpeech() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MEETING_RUN_SYNTHETIC_SPEECH"] == "1",
              let path = env["MEETING_SYNTHETIC_AUDIO"] else {
            throw XCTSkip("Requires explicit OS Speech authorization and a synthetic fixture; no microphone is used")
        }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw MeetingAppleCaptureError.permissionRequired }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let fixture = try MeetingAudioIntegrityTests().fixture()
        var segment = fixture.0
        segment.stoppedAt = segment.startedAt.addingTimeInterval(Double(file.length) / file.processingFormat.sampleRate)
        let permit = fixture.1; let key = fixture.2
        var chunks: [MeetingEncryptedAudioChunk] = []
        while file.framePosition < file.length {
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 1024))
            try file.read(into: buffer)
            let planes = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            var data = Data()
            for plane in planes { data.append(plane.mData!.assumingMemoryBound(to: UInt8.self), count: Int(plane.mDataByteSize)) }
            let header = MeetingEncryptedAudioChunk.Header(permit: permit, sequence: UInt64(chunks.count),
                sampleRate: buffer.format.sampleRate, channels: buffer.format.channelCount, frames: buffer.frameLength,
                commonFormat: buffer.format.commonFormat.rawValue, interleaved: buffer.format.isInterleaved,
                planeSizes: planes.map { Int($0.mDataByteSize) })
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let sealed = try AES.GCM.seal(data, using: key, authenticating: encoder.encode(header))
            chunks.append(MeetingEncryptedAudioChunk(header: header, ciphertext: try XCTUnwrap(sealed.combined)))
        }
        let part = try await MeetingOnDeviceChunkTranscriber.transcribe(chunks, from: segment, using: key)
        XCTAssertFalse(part.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let attachment = XCTAttachment(string: part.text); attachment.lifetime = .keepAlways; add(attachment)
        if let output = env["MEETING_TRANSCRIPT_OUTPUT"] {
            try part.text.write(toFile: output, atomically: true, encoding: .utf8)
        }
    }
}
