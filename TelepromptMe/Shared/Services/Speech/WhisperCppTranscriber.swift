import Foundation

struct WhisperCppTranscriptionOptions: Equatable {
    var languageIdentifier: String?
    var translatesToEnglish: Bool
    var reportsTimestamps: Bool

    init(
        languageIdentifier: String? = nil,
        translatesToEnglish: Bool = false,
        reportsTimestamps: Bool = false
    ) {
        self.languageIdentifier = languageIdentifier
        self.translatesToEnglish = translatesToEnglish
        self.reportsTimestamps = reportsTimestamps
    }
}

struct WhisperCppTranscriptionResult: Equatable {
    var transcript: String
}

enum WhisperCppTranscriberError: LocalizedError {
    case executableMissing(URL)
    case modelMissing(URL)
    case audioMissing(URL)
    case launchFailed(String)
    case transcriptionFailed(String)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .executableMissing(let url):
            return "The whisper.cpp executable was not found at \(url.path)."
        case .modelMissing(let url):
            return "The Whisper model was not found at \(url.path)."
        case .audioMissing(let url):
            return "The audio file was not found at \(url.path)."
        case .launchFailed(let message):
            return "Could not start whisper.cpp: \(message)"
        case .transcriptionFailed(let message):
            return message
        case .emptyTranscript:
            return "whisper.cpp completed but did not return a transcript."
        }
    }
}

/// Thin Swift adapter for the whisper.cpp command-line runtime.
///
/// This keeps TelepromptMe independent from vendored C/C++ sources while the
/// model catalog and download lifecycle settle. A direct library binding can
/// later conform to the same call shape.
final class WhisperCppTranscriber {
    private let executableURL: URL
    private let modelURL: URL

    static var bundledExecutableURL: URL? {
        Bundle.main.url(
            forResource: "whisper-cli",
            withExtension: nil,
            subdirectory: "whisper"
        )
    }

    convenience init?(bundledModelURL modelURL: URL) {
        guard let executableURL = Self.bundledExecutableURL else {
            return nil
        }

        self.init(executableURL: executableURL, modelURL: modelURL)
    }

    init(executableURL: URL, modelURL: URL) {
        self.executableURL = executableURL
        self.modelURL = modelURL
    }

    func transcribe(
        audioURL: URL,
        options: WhisperCppTranscriptionOptions = WhisperCppTranscriptionOptions()
    ) async throws -> WhisperCppTranscriptionResult {
        try validateInputs(audioURL: audioURL)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments(audioURL: audioURL, options: options)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw WhisperCppTranscriberError.launchFailed(error.localizedDescription)
        }

        return try await withTaskCancellationHandler {
            try await waitForTranscription(
                process: process,
                outputPipe: outputPipe,
                errorPipe: errorPipe
            )
        } onCancel: {
            process.terminate()
        }
    }

    private func validateInputs(audioURL: URL) throws {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw WhisperCppTranscriberError.executableMissing(executableURL)
        }

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw WhisperCppTranscriberError.modelMissing(modelURL)
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperCppTranscriberError.audioMissing(audioURL)
        }
    }

    private func arguments(
        audioURL: URL,
        options: WhisperCppTranscriptionOptions
    ) -> [String] {
        var arguments = [
            "--model", modelURL.path,
            "--file", audioURL.path,
            "--output-txt",
            "--no-prints"
        ]

        if let languageIdentifier = options.languageIdentifier {
            arguments += ["--language", Self.whisperLanguageCode(from: languageIdentifier)]
        }

        if options.translatesToEnglish {
            arguments.append("--translate")
        }

        if !options.reportsTimestamps {
            arguments.append("--no-timestamps")
        }

        return arguments
    }

    private func waitForTranscription(
        process: Process,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) async throws -> WhisperCppTranscriptionResult {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdout = Self.readString(from: outputPipe)
                let stderr = Self.readString(from: errorPipe)

                guard process.terminationStatus == 0 else {
                    let message = stderr.isEmpty ? "whisper.cpp exited with status \(process.terminationStatus)." : stderr
                    continuation.resume(throwing: WhisperCppTranscriberError.transcriptionFailed(message))
                    return
                }

                let transcript = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !transcript.isEmpty else {
                    continuation.resume(throwing: WhisperCppTranscriberError.emptyTranscript)
                    return
                }

                continuation.resume(returning: WhisperCppTranscriptionResult(transcript: transcript))
            }
        }
    }

    private static func readString(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func whisperLanguageCode(from localeIdentifier: String) -> String {
        let locale = Locale(identifier: localeIdentifier)
        return locale.language.languageCode?.identifier ?? localeIdentifier
    }
}
