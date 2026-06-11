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
}
