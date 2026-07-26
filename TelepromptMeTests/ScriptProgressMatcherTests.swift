import XCTest
@testable import TelepromptMe

final class ScriptProgressMatcherTests: XCTestCase {
    func testMatchingAdvancesThroughScript() {
        let matcher = ScriptProgressMatcher()
        matcher.prepare(script: "Welcome to the launch. Today we are introducing a focused teleprompter.")

        let first = matcher.match(
            transcript: "Welcome to the launch",
            sensitivity: 0.6
        )
        let second = matcher.match(
            transcript: "Welcome to the launch today we are introducing",
            sensitivity: 0.6
        )

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertGreaterThanOrEqual(second?.progress ?? 0, first?.progress ?? 0)
    }

    func testUnrelatedSpeechDoesNotAdvance() {
        let matcher = ScriptProgressMatcher()
        matcher.prepare(script: "This is the prepared script for the presentation.")

        let match = matcher.match(
            transcript: "Completely unrelated words about something else",
            sensitivity: 0.7
        )

        XCTAssertNil(match)
    }

    func testEmptyScriptNeverMatches() {
        let matcher = ScriptProgressMatcher()
        matcher.prepare(script: "")

        XCTAssertNil(matcher.match(transcript: "Any spoken words", sensitivity: 0.5))
    }
}

@MainActor
final class SpeechFollowControllerTests: XCTestCase {
    func testRecognitionResultMovesControllerToMatchingState() async {
        let engine = TestSpeechRecognitionEngine()
        let controller = SpeechFollowController(makeEngine: { engine })
        let playback = PlaybackController()
        playback.updateScrollableMetrics(contentHeight: 1_000, viewportHeight: 200)

        controller.start(
            script: "Welcome to the launch today we are introducing the product",
            localeIdentifier: "en_US",
            sensitivity: 0.6,
            playbackController: playback
        )
        try? await Task.sleep(for: .milliseconds(25))
        engine.yield("Welcome to the launch today")
        try? await Task.sleep(for: .milliseconds(25))

        XCTAssertEqual(controller.state, .matching)
        XCTAssertGreaterThan(controller.confidence, 0)
    }

    func testStopCancelsEngineAndResetsState() async {
        let engine = TestSpeechRecognitionEngine()
        let controller = SpeechFollowController(makeEngine: { engine })
        let playback = PlaybackController()

        controller.start(
            script: "A prepared script",
            localeIdentifier: "en_US",
            sensitivity: 0.6,
            playbackController: playback
        )
        await Task.yield()
        controller.stop()

        XCTAssertTrue(engine.wasStopped)
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.lastTranscript, "")
    }
}

private final class TestSpeechRecognitionEngine: SpeechRecognitionEngine {
    private var continuation: AsyncStream<SpeechRecognitionResult>.Continuation?
    private(set) var wasStopped = false
    var failureMessage: String?

    lazy var results: AsyncStream<SpeechRecognitionResult> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    func start(localeIdentifier: String) async throws {}

    func stop() {
        wasStopped = true
    }

    func yield(_ transcript: String) {
        continuation?.yield(
            SpeechRecognitionResult(transcript: transcript, isFinal: false)
        )
    }
}
