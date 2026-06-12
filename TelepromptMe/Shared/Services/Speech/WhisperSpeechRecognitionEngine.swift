import AVFoundation
import Foundation

final class WhisperSpeechRecognitionEngine: SpeechRecognitionEngine {
    private let modelURL: URL
    private let audioEngine = AVAudioEngine()
    private let sampleBuffer: WhisperAudioSampleBuffer
    private var audioConverter: AVAudioConverter?
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
        sampleBuffer = WhisperAudioSampleBuffer(sampleRate: Self.sampleRate)
    }

    func start(localeIdentifier: String) async throws {
        stop()
        failureMessage = nil
        sampleBuffer.removeAll()

        guard await requestMicrophoneAuthorization() else {
            throw SpeechRecognitionError.authorizationDenied
        }

        let transcriber: WhisperCppTranscriber
        do {
            transcriber = try WhisperCppTranscriber(modelURL: modelURL)
        } catch {
            throw SpeechRecognitionError.localModelUnavailable(modelURL.lastPathComponent)
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0 else {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ),
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        audioConverter = converter

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            self?.appendConvertedSamples(from: buffer, to: outputFormat)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            audioConverter = nil
            throw SpeechRecognitionError.microphoneUnavailable
        }

        transcriptionTask = Task { [weak self] in
            await self?.runTranscriptionLoop(
                transcriber: transcriber,
                localeIdentifier: localeIdentifier
            )
        }
    }

    func stop() {
        stopAudioCapture()
    }

    private func runTranscriptionLoop(
        transcriber: WhisperCppTranscriber,
        localeIdentifier: String
    ) async {
        var lastPartialTranscript = ""
        let options = WhisperCppTranscriptionOptions(languageIdentifier: localeIdentifier)

        while !Task.isCancelled && isRecording {
            try? await Task.sleep(for: .milliseconds(Self.partialTranscriptionIntervalMilliseconds))
            guard !Task.isCancelled, isRecording else {
                break
            }

            let samples = sampleBuffer.recentSamples(duration: Self.partialTranscriptionWindowSeconds)
            guard samples.count >= Self.minimumPartialSampleCount else {
                continue
            }

            do {
                let result = try await transcriber.transcribe(samples: samples, options: options)
                guard result.transcript != lastPartialTranscript else {
                    continue
                }

                lastPartialTranscript = result.transcript
                continuation?.yield(
                    SpeechRecognitionResult(
                        transcript: result.transcript,
                        isFinal: false
                    )
                )
            } catch WhisperCppTranscriberError.emptyTranscript {
                continue
            } catch {
                failureMessage = error.localizedDescription
                NSLog("TelepromptMe Whisper partial recognition failed: \(error.localizedDescription)")
            }
        }

        guard !Task.isCancelled else { return }

        do {
            let samples = sampleBuffer.allSamples()
            guard !samples.isEmpty else {
                continuation?.finish()
                return
            }

            let result = try await transcriber.transcribe(
                samples: samples,
                options: WhisperCppTranscriptionOptions(
                    languageIdentifier: localeIdentifier,
                    runsSingleSegment: false
                )
            )
            continuation?.yield(
                SpeechRecognitionResult(
                    transcript: result.transcript,
                    isFinal: true
                )
            )
        } catch {
            failureMessage = error.localizedDescription
            NSLog("TelepromptMe Whisper recognition failed: \(error.localizedDescription)")
        }

        continuation?.finish()
    }

    private func appendConvertedSamples(from buffer: AVAudioPCMBuffer, to outputFormat: AVAudioFormat) {
        guard let audioConverter else { return }

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

        guard let channelData = convertedBuffer.floatChannelData?[0] else {
            return
        }

        let samples = Array(
            UnsafeBufferPointer(
                start: channelData,
                count: Int(convertedBuffer.frameLength)
            )
        )
        sampleBuffer.append(samples)
    }

    private func stopAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        isRecording = false
        audioConverter = nil
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

    private static let sampleRate: Double = 16_000
    private static let partialTranscriptionIntervalMilliseconds = 1_500
    private static let partialTranscriptionWindowSeconds: TimeInterval = 6
    private static let minimumPartialSampleCount = Int(sampleRate * 1.5)
}

final class WhisperAudioSampleBuffer {
    private let lock = NSLock()
    private let sampleRate: Double
    private var samples: [Float] = []

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func append(_ newSamples: [Float]) {
        lock.withLock {
            samples.append(contentsOf: newSamples)
        }
    }

    func allSamples() -> [Float] {
        lock.withLock {
            samples
        }
    }

    func recentSamples(duration: TimeInterval) -> [Float] {
        lock.withLock {
            let sampleCount = min(samples.count, Int(sampleRate * duration))
            return Array(samples.suffix(sampleCount))
        }
    }

    func removeAll() {
        lock.withLock {
            samples.removeAll(keepingCapacity: true)
        }
    }
}
