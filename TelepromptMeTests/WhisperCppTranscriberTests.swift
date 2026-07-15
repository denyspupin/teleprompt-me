import XCTest
@testable import TelepromptMe

final class WhisperCppTranscriberTests: XCTestCase {
    func testLanguageCodeUsesLocaleLanguage() {
        XCTAssertEqual(WhisperCppTranscriber.whisperLanguageCode(from: "de_DE"), "de")
    }

    func testLanguageCodeUsesBCP47Language() {
        XCTAssertEqual(WhisperCppTranscriber.whisperLanguageCode(from: "en-US"), "en")
    }

    func testSampleBufferReturnsRecentWindow() {
        let buffer = WhisperAudioSampleBuffer(sampleRate: 4)
        buffer.append([1, 2, 3, 4, 5, 6])

        XCTAssertEqual(buffer.recentSamples(duration: 1), [3, 4, 5, 6])
    }

    func testSampleBufferRemoveAllKeepsBufferReusable() {
        let buffer = WhisperAudioSampleBuffer(sampleRate: 4)
        buffer.append([1, 2])
        buffer.removeAll()
        buffer.append([3])

        XCTAssertEqual(buffer.allSamples(), [3])
    }

    func testProgressMatcherAdvancesWithRollingWhisperTranscripts() {
        let matcher = ScriptProgressMatcher()
        matcher.prepare(
            script: """
            Welcome to the product update. Today we will cover design changes, \
            platform improvements, and the launch plan for next week.
            """
        )

        let firstMatch = matcher.match(
            transcript: "Welcome to the product update",
            sensitivity: 0.7
        )
        let secondMatch = matcher.match(
            transcript: "Today we will cover design changes",
            sensitivity: 0.7
        )

        XCTAssertNotNil(firstMatch)
        XCTAssertNotNil(secondMatch)
        XCTAssertGreaterThan(secondMatch?.wordIndex ?? 0, firstMatch?.wordIndex ?? 0)
    }
}
