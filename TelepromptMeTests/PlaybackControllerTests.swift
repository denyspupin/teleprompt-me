import XCTest
@testable import TelepromptMe

@MainActor
final class PlaybackControllerTests: XCTestCase {
    func testSpeedIsClampedToSupportedRange() {
        let controller = PlaybackController()

        controller.applySpeed(10)
        XCTAssertEqual(controller.speedWordsPerMinute, 60)

        controller.applySpeed(500)
        XCTAssertEqual(controller.speedWordsPerMinute, 260)
    }

    func testPlayWithoutScrollableContentStopsAtTop() {
        let controller = PlaybackController()

        controller.play()

        XCTAssertEqual(controller.state, .stopped)
        XCTAssertEqual(controller.currentOffset, 0)
    }

    func testRestartReturnsToTopAndPauses() {
        let controller = PlaybackController()
        controller.updateScrollableMetrics(contentHeight: 1_000, viewportHeight: 200)
        controller.play()

        controller.restartFromTop()

        XCTAssertEqual(controller.state, .paused)
        XCTAssertEqual(controller.currentOffset, 0)
    }

    func testStopResetsPlayback() {
        let controller = PlaybackController()
        controller.updateScrollableMetrics(contentHeight: 1_000, viewportHeight: 200)
        controller.play()

        controller.stop()

        XCTAssertEqual(controller.state, .stopped)
        XCTAssertEqual(controller.currentOffset, 0)
    }
}
