import AVFoundation
import Foundation

final class WhisperSpeechRecognitionEngine: SpeechRecognitionEngine {
    private let modelURL: URL
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var audioConverter: AVAudioConverter?
    private var temporaryAudioURL: URL?
    private var transcriptionTask: Task<Void, Never>?
    private var continuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private(set) var failureMessage: String?
    private var isRecording = false

    lazy var results: AsyncStream<SpeechRecognitionResult> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    func start(localeIdentifier: String) async throws {
        stop()
        failureMessage = nil

        guard await requestMicrophoneAuthorization() else {
            throw SpeechRecognitionError.authorizationDenied
        }

        guard let transcriber = WhisperCppTranscriber(bundledModelURL: modelURL) else {
            throw SpeechRecognitionError.localModelUnavailable(modelURL.lastPathComponent)
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0 else {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        )
        guard let outputFormat else {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        let audioURL = Self.temporaryAudioURL()
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(
                forWriting: audioURL,
                settings: outputFormat.settings,
                commonFormat: outputFormat.commonFormat,
                interleaved: outputFormat.isInterleaved
            )
        } catch {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        self.audioFile = audioFile
        audioConverter = converter
        temporaryAudioURL = audioURL

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            self?.write(buffer, to: outputFormat)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            clearAudioResources()
            throw SpeechRecognitionError.microphoneUnavailable
        }

        transcriptionTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled && self.isRecording {
                try? await Task.sleep(for: .milliseconds(100))
            }

            guard !Task.isCancelled else { return }

            do {
                let result = try await transcriber.transcribe(
                    audioURL: audioURL,
                    options: WhisperCppTranscriptionOptions(languageIdentifier: localeIdentifier)
                )
                self.continuation?.yield(
                    SpeechRecognitionResult(
                        transcript: result.transcript,
                        isFinal: true
                    )
                )
            } catch {
                self.failureMessage = error.localizedDescription
                NSLog("TelepromptMe Whisper recognition failed: \(error.localizedDescription)")
            }

            self.continuation?.finish()
            self.removeTemporaryAudioFile(at: audioURL)
        }
    }

    func stop() {
        stopAudioCapture()
    }

    private func write(_ buffer: AVAudioPCMBuffer, to outputFormat: AVAudioFormat) {
        guard let audioFile, let audioConverter else { return }

        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate
        ) + 1
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: frameCapacity
        ) else {
            return
        }

        var didProvideBuffer = false
        var conversionError: NSError?
        let status = audioConverter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideBuffer {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideBuffer = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, convertedBuffer.frameLength > 0 else {
            if let conversionError {
                failureMessage = conversionError.localizedDescription
            }
            return
        }

        do {
            try audioFile.write(from: convertedBuffer)
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    private func stopAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        isRecording = false
        clearAudioResources()
    }

    private func clearAudioResources() {
        audioFile = nil
        audioConverter = nil
        temporaryAudioURL = nil
    }

    private func removeTemporaryAudioFile(at audioURL: URL) {
        try? FileManager.default.removeItem(at: audioURL)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: audioURL.path + ".txt"))
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

    private static func temporaryAudioURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("telepromptme-whisper-\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }
}
