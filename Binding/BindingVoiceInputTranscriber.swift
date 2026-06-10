// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase

struct BindingVoiceInputPermissionSnapshot {
    var status: String
    var speechStatus: String
    var microphoneStatus: String
    var canTranscribe: Bool
    var requiresUserAction: Bool
    var reason: String

    nonisolated func objectValue() -> Object {
        [
            "permissionStatus": .string(status),
            "speechPermissionStatus": .string(speechStatus),
            "microphonePermissionStatus": .string(microphoneStatus),
            "canTranscribe": .bool(canTranscribe),
            "requiresUserAction": .bool(requiresUserAction),
            "permissionReason": .string(reason)
        ]
    }
}

struct BindingVoiceInputUpdate {
    var status: String
    var partialTranscript: String
    var finalTranscript: String
    var isFinal: Bool
    var isListening: Bool
    var localeIdentifier: String
    var errorCode: String
    var message: String

    nonisolated func objectValue() -> Object {
        [
            "status": .string(status),
            "partialTranscript": .string(partialTranscript),
            "finalTranscript": .string(finalTranscript),
            "isFinal": .bool(isFinal),
            "isListening": .bool(isListening),
            "locale": .string(localeIdentifier),
            "lastError": errorCode.isEmpty ? .null : .string(errorCode),
            "message": .string(message),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }
}

#if (os(iOS) || os(macOS)) && canImport(Speech) && canImport(AVFoundation)
import AVFoundation
import Speech

final class BindingVoiceInputTranscriber {
    typealias UpdateHandler = (BindingVoiceInputUpdate) -> Void

    nonisolated static var engineName: String { "apple-speech-on-device" }
    nonisolated static var isRuntimeAvailable: Bool { true }

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var latestTranscript = ""

    nonisolated static func permissionSnapshot() -> BindingVoiceInputPermissionSnapshot {
        let speech = Self.speechStatusText(SFSpeechRecognizer.authorizationStatus())
        let microphone = Self.microphoneStatusText(AVCaptureDevice.authorizationStatus(for: .audio))
        let granted = speech == "authorized" && microphone == "authorized"
        return BindingVoiceInputPermissionSnapshot(
            status: granted ? "authorized" : "not_authorized",
            speechStatus: speech,
            microphoneStatus: microphone,
            canTranscribe: granted,
            requiresUserAction: speech == "not_determined" || microphone == "not_determined",
            reason: granted ? "Speech and microphone access are available." : "Speech input needs explicit speech and microphone permission."
        )
    }

    nonisolated func permissionSnapshot() -> BindingVoiceInputPermissionSnapshot {
        Self.permissionSnapshot()
    }

    func requestPermissions() async -> BindingVoiceInputPermissionSnapshot {
        let speechStatus = await requestSpeechPermissionIfNeeded()
        let microphoneStatus = await requestMicrophonePermissionIfNeeded()
        let speech = Self.speechStatusText(speechStatus)
        let microphone = Self.microphoneStatusText(microphoneStatus)
        let granted = speech == "authorized" && microphone == "authorized"
        return BindingVoiceInputPermissionSnapshot(
            status: granted ? "authorized" : "not_authorized",
            speechStatus: speech,
            microphoneStatus: microphone,
            canTranscribe: granted,
            requiresUserAction: false,
            reason: granted ? "Speech dictation is ready." : "Speech dictation cannot start without speech and microphone permission."
        )
    }

    func start(
        localeIdentifier: String,
        updateHandler: @escaping UpdateHandler
    ) async -> BindingVoiceInputUpdate {
        let permissions = await requestPermissions()
        guard permissions.canTranscribe else {
            return BindingVoiceInputUpdate(
                status: "permission_denied",
                partialTranscript: "",
                finalTranscript: "",
                isFinal: false,
                isListening: false,
                localeIdentifier: localeIdentifier,
                errorCode: "permission_denied",
                message: permissions.reason
            )
        }

        stop()
        latestTranscript = ""

        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return unavailable(localeIdentifier: localeIdentifier, code: "unsupported_locale", message: "Speech recognizer is unavailable for \(localeIdentifier).")
        }
        guard recognizer.isAvailable else {
            return unavailable(localeIdentifier: localeIdentifier, code: "recognizer_unavailable", message: "Speech recognizer is not available right now.")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return unavailable(localeIdentifier: localeIdentifier, code: "on_device_unavailable", message: "On-device speech recognition is not available for \(localeIdentifier).")
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request
        speechRecognizer = recognizer

        do {
            try configureAudioSessionIfNeeded()
            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stop()
            return unavailable(
                localeIdentifier: localeIdentifier,
                code: "audio_start_failed",
                message: "Could not start microphone capture: \(error)"
            )
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.latestTranscript = result.bestTranscription.formattedString
                let update = BindingVoiceInputUpdate(
                    status: result.isFinal ? "transcribed" : "listening",
                    partialTranscript: self.latestTranscript,
                    finalTranscript: result.isFinal ? self.latestTranscript : "",
                    isFinal: result.isFinal,
                    isListening: !result.isFinal,
                    localeIdentifier: localeIdentifier,
                    errorCode: "",
                    message: result.isFinal ? "Speech transcript is ready." : "Listening."
                )
                updateHandler(update)
                if result.isFinal {
                    self.finishAudio()
                }
            } else if let error {
                let update = BindingVoiceInputUpdate(
                    status: "error",
                    partialTranscript: self.latestTranscript,
                    finalTranscript: self.latestTranscript,
                    isFinal: false,
                    isListening: false,
                    localeIdentifier: localeIdentifier,
                    errorCode: "recognition_failed",
                    message: "Speech recognition failed: \(error)"
                )
                updateHandler(update)
                self.stop()
            }
        }

        return BindingVoiceInputUpdate(
            status: "listening",
            partialTranscript: "",
            finalTranscript: "",
            isFinal: false,
            isListening: true,
            localeIdentifier: localeIdentifier,
            errorCode: "",
            message: "Listening."
        )
    }

    func stop() {
        finishAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil
    }

    private func finishAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        deactivateAudioSessionIfNeeded()
    }

    private func requestSpeechPermissionIfNeeded() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermissionIfNeeded() async -> AVAuthorizationStatus {
        let current = AVCaptureDevice.authorizationStatus(for: .audio)
        guard current == .notDetermined else { return current }
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        return granted ? .authorized : AVCaptureDevice.authorizationStatus(for: .audio)
    }

    nonisolated private static func speechStatusText(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not_determined"
        @unknown default: return "unknown"
        }
    }

    nonisolated private static func microphoneStatusText(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not_determined"
        @unknown default: return "unknown"
        }
    }

    private func unavailable(localeIdentifier: String, code: String, message: String) -> BindingVoiceInputUpdate {
        BindingVoiceInputUpdate(
            status: "unavailable",
            partialTranscript: "",
            finalTranscript: "",
            isFinal: false,
            isListening: false,
            localeIdentifier: localeIdentifier,
            errorCode: code,
            message: message
        )
    }

    private func configureAudioSessionIfNeeded() throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
#endif
    }

    private func deactivateAudioSessionIfNeeded() {
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }
}
#else
final class BindingVoiceInputTranscriber {
    typealias UpdateHandler = (BindingVoiceInputUpdate) -> Void

    nonisolated static var engineName: String { "unavailable" }
    nonisolated static var isRuntimeAvailable: Bool { false }

    nonisolated static func permissionSnapshot() -> BindingVoiceInputPermissionSnapshot {
        BindingVoiceInputPermissionSnapshot(
            status: "unavailable",
            speechStatus: "unavailable",
            microphoneStatus: "unavailable",
            canTranscribe: false,
            requiresUserAction: false,
            reason: "Speech and microphone frameworks are unavailable on this platform."
        )
    }

    nonisolated func permissionSnapshot() -> BindingVoiceInputPermissionSnapshot {
        Self.permissionSnapshot()
    }

    func requestPermissions() async -> BindingVoiceInputPermissionSnapshot {
        permissionSnapshot()
    }

    func start(
        localeIdentifier: String,
        updateHandler: @escaping UpdateHandler
    ) async -> BindingVoiceInputUpdate {
        BindingVoiceInputUpdate(
            status: "unavailable",
            partialTranscript: "",
            finalTranscript: "",
            isFinal: false,
            isListening: false,
            localeIdentifier: localeIdentifier,
            errorCode: "unsupported_platform",
            message: "Speech input is unavailable on this platform."
        )
    }

    func stop() {}
}
#endif
