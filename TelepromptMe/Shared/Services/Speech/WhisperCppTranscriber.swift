import Foundation
import whisper

struct WhisperCppTranscriptionOptions: Equatable {
    var languageIdentifier: String?
    var translatesToEnglish: Bool
    var reportsTimestamps: Bool
    var usesPreviousContext: Bool
    var runsSingleSegment: Bool

    init(
        languageIdentifier: String? = nil,
        translatesToEnglish: Bool = false,
        reportsTimestamps: Bool = false,
        usesPreviousContext: Bool = true,
        runsSingleSegment: Bool = true
    ) {
        self.languageIdentifier = languageIdentifier
        self.translatesToEnglish = translatesToEnglish
        self.reportsTimestamps = reportsTimestamps
        self.usesPreviousContext = usesPreviousContext
        self.runsSingleSegment = runsSingleSegment
    }
}

struct WhisperCppTranscriptionResult: Equatable {
    var transcript: String
}

enum WhisperCppTranscriberError: LocalizedError {
    case modelMissing(URL)
    case contextInitializationFailed(URL)
    case transcriptionFailed
    case emptySamples
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .modelMissing(let url):
            return "The Whisper model was not found at \(url.path)."
        case .contextInitializationFailed(let url):
            return "Could not load the Whisper model at \(url.path)."
        case .transcriptionFailed:
            return "whisper.cpp could not transcribe the audio samples."
        case .emptySamples:
            return "There were no audio samples to transcribe."
        case .emptyTranscript:
            return "whisper.cpp completed but did not return a transcript."
        }
    }
}

/// Native Swift adapter for the whisper.cpp C API.
///
/// The whisper context is actor-isolated because whisper.cpp contexts should
/// not be used concurrently.
actor WhisperCppTranscriber {
    private let modelURL: URL
    private var context: OpaquePointer?

    init(modelURL: URL) throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw WhisperCppTranscriberError.modelMissing(modelURL)
        }

        self.modelURL = modelURL
        context = try Self.makeContext(modelURL: modelURL)
    }

    deinit {
        if let context {
            whisper_free(context)
        }
    }

    func transcribe(
        samples: [Float],
        options: WhisperCppTranscriptionOptions = WhisperCppTranscriptionOptions()
    ) throws -> WhisperCppTranscriptionResult {
        guard !samples.isEmpty else {
            throw WhisperCppTranscriberError.emptySamples
        }

        guard let context else {
            throw WhisperCppTranscriberError.contextInitializationFailed(modelURL)
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = options.reportsTimestamps
        params.print_special = false
        params.translate = options.translatesToEnglish
        params.no_context = !options.usesPreviousContext
        params.single_segment = options.runsSingleSegment
        params.n_threads = Int32(Self.transcriptionThreadCount)

        let languageCode = options.languageIdentifier.map(Self.whisperLanguageCode(from:))
        let status: Int32
        if let languageCode {
            status = languageCode.withCString { language in
                params.language = language
                return Self.runFullTranscription(context: context, params: params, samples: samples)
            }
        } else {
            status = Self.runFullTranscription(context: context, params: params, samples: samples)
        }

        guard status == 0 else {
            throw WhisperCppTranscriberError.transcriptionFailed
        }

        let transcript = Self.transcript(from: context)
        guard !transcript.isEmpty else {
            throw WhisperCppTranscriberError.emptyTranscript
        }

        return WhisperCppTranscriptionResult(transcript: transcript)
    }

    func resetTimings() {
        if let context {
            whisper_reset_timings(context)
        }
    }

    static func whisperLanguageCode(from localeIdentifier: String) -> String {
        let locale = Locale(identifier: localeIdentifier)
        return locale.language.languageCode?.identifier ?? localeIdentifier
    }

    private static func makeContext(modelURL: URL) throws -> OpaquePointer {
        var params = whisper_context_default_params()
        params.flash_attn = true

        guard let context = whisper_init_from_file_with_params(modelURL.path, params) else {
            throw WhisperCppTranscriberError.contextInitializationFailed(modelURL)
        }

        return context
    }

    private static func runFullTranscription(
        context: OpaquePointer,
        params: whisper_full_params,
        samples: [Float]
    ) -> Int32 {
        samples.withUnsafeBufferPointer { buffer in
            whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
        }
    }

    private static func transcript(from context: OpaquePointer) -> String {
        var transcript = ""
        for index in 0..<whisper_full_n_segments(context) {
            guard let textPointer = whisper_full_get_segment_text(context, index) else {
                continue
            }
            transcript += String(cString: textPointer)
        }

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static var transcriptionThreadCount: Int {
        max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
    }
}
