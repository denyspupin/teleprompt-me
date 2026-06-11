import XCTest
@testable import TelepromptMe

final class WhisperCppTranscriberTests: XCTestCase {
    func testArgumentsIncludeModelAudioLanguageAndModeFlags() {
        let arguments = WhisperCppTranscriber.arguments(
            executableURL: URL(fileURLWithPath: "/tmp/whisper-cli"),
            modelURL: URL(fileURLWithPath: "/models/ggml-small.bin"),
            audioURL: URL(fileURLWithPath: "/audio/session.wav"),
            options: WhisperCppTranscriptionOptions(
                languageIdentifier: "de_DE",
                translatesToEnglish: true,
                reportsTimestamps: false
            )
        )

        XCTAssertEqual(
            arguments,
            [
                "--model", "/models/ggml-small.bin",
                "--file", "/audio/session.wav",
                "--output-txt",
                "--no-prints",
                "--language", "de",
                "--translate",
                "--no-timestamps",
            ]
        )
    }

    func testArgumentsAllowTimestampOutput() {
        let arguments = WhisperCppTranscriber.arguments(
            executableURL: URL(fileURLWithPath: "/tmp/whisper-cli"),
            modelURL: URL(fileURLWithPath: "/models/model.bin"),
            audioURL: URL(fileURLWithPath: "/audio/file.wav"),
            options: WhisperCppTranscriptionOptions(reportsTimestamps: true)
        )

        XCTAssertFalse(arguments.contains("--no-timestamps"))
    }

    func testTranscriptPrefersNonEmptySidecarOverStdout() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let audioURL = temporaryDirectory.appendingPathComponent("audio.wav")
        let sidecarURL = WhisperCppTranscriber.textOutputURL(for: audioURL)
        try Data(" sidecar transcript \n".utf8).write(to: sidecarURL)

        XCTAssertEqual(
            WhisperCppTranscriber.transcript(
                textOutputURL: sidecarURL,
                stdout: "stdout transcript"
            ),
            "sidecar transcript"
        )
    }

    func testTranscriptFallsBackToTrimmedStdout() {
        let missingSidecarURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        XCTAssertEqual(
            WhisperCppTranscriber.transcript(
                textOutputURL: missingSidecarURL,
                stdout: " stdout transcript \n"
            ),
            "stdout transcript"
        )
    }

    func testBundledExecutableResolutionUsesRequestedBundle() throws {
        let bundleDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        let whisperDirectory = bundleDirectory.appendingPathComponent("whisper", isDirectory: true)
        try FileManager.default.createDirectory(at: whisperDirectory, withIntermediateDirectories: true)
        let executableURL = whisperDirectory.appendingPathComponent("whisper-cli")
        try Data().write(to: executableURL)
        defer {
            try? FileManager.default.removeItem(at: bundleDirectory)
        }

        guard let bundle = Bundle(url: bundleDirectory) else {
            return XCTFail("Expected temporary bundle to load.")
        }

        XCTAssertEqual(WhisperCppTranscriber.bundledExecutableURL(in: bundle), executableURL)
    }
}
