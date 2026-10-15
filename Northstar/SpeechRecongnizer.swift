import Foundation
import Speech
import AVFoundation
import Observation

/// Thrown by startRecording() instead of silently returning, so a caller can
/// actually observe and report the failure.
enum SpeechRecognizerError: LocalizedError {
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is unavailable right now."
        }
    }
}

@MainActor
@Observable
final class SpeechRecognizer {

    private let speechRecognizer =
        SFSpeechRecognizer(
            locale: Locale(identifier: "en-US")
        )

    // A fresh engine for each recording: the microphone's format can change between recordings
    // (AirPods, a call, a video that played), and an old engine keeps the old format → crash.
    private var audioEngine = AVAudioEngine()

    private var recognitionRequest:
        SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask:
        SFSpeechRecognitionTask?

    private var tapInstalled = false

    var transcript = ""
    var isRecording = false

    func requestPermissions() async -> Bool {
        let speechStatus =
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization {
                    status in

                    continuation.resume(
                        returning: status
                    )
                }
            }

        let microphoneGranted =
            await AVAudioApplication
                .requestRecordPermission()

        return speechStatus == .authorized
            && microphoneGranted
    }

    func startRecording() throws {
        stopRecording()
        transcript = ""

        guard speechRecognizer?.isAvailable == true else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        let audioSession =
            AVAudioSession.sharedInstance()

        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker]
        )

        try audioSession.setActive(
            true,
            options: .notifyOthersOnDeactivation
        )

        let request =
            SFSpeechAudioBufferRecognitionRequest()

        request.shouldReportPartialResults = true
        recognitionRequest = request

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        // The microphone's real format right now (after the audio session is set).
        let recordingFormat =
            inputNode.inputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        recognitionTask =
            speechRecognizer?.recognitionTask(
                with: request
            ) { [weak self] result, error in

                guard let self else {
                    return
                }

                if let result {
                    Task { @MainActor in
                        self.transcript =
                            result.bestTranscription
                                .formattedString
                    }
                }

                if error != nil ||
                    result?.isFinal == true {

                    Task { @MainActor in
                        self.stopRecording()
                    }
                }
            }

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { buffer, _ in
            request.append(buffer)
        }

        tapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
    }

    func stopRecording() {
        isRecording = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }

        recognitionRequest?.endAudio()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}
