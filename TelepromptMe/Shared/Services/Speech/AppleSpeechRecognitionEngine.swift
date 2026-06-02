import AVFoundation
import Foundation
import Speech

final class AppleSpeechRecognitionEngine: SpeechRecognitionEngine {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private(set) var failureMessage: String?
    private var isStopping = false

    lazy var results: AsyncStream<SpeechRecognitionResult> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    func start(localeIdentifier: String) async throws {
        stop()
        failureMessage = nil
        isStopping = false

        guard await requestMicrophoneAuthorization() else {
            throw SpeechRecognitionError.authorizationDenied
        }

        guard await requestSpeechAuthorization() else {
            throw SpeechRecognitionError.authorizationDenied
        }

        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.channelCount > 0 else {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw SpeechRecognitionError.microphoneUnavailable
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                self?.continuation?.yield(
                    SpeechRecognitionResult(
                        transcript: result.bestTranscription.formattedString,
                        isFinal: result.isFinal
                    )
                )
            }

            if let error {
                if self?.isStopping == false && !Self.isCancellationError(error) {
                    self?.failureMessage = error.localizedDescription
                    NSLog("TelepromptMe speech recognition failed: \(error.localizedDescription)")
                }
                self?.continuation?.finish()
                self?.stopAudioCapture()
            } else if result?.isFinal == true {
                self?.continuation?.finish()
                self?.stopAudioCapture()
            }
        }
    }

    func stop() {
        isStopping = true
        stopAudioCapture()
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func stopAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private static func isCancellationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.localizedDescription.localizedCaseInsensitiveContains("cancel")
            || nsError.code == 216
            || nsError.code == 203
    }
}
