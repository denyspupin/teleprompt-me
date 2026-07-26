import Foundation
import Observation

@MainActor
@Observable
final class PlaybackController {
    enum State: Equatable {
        case stopped
        case playing
        case paused
    }

    private enum Layout {
        static let timerInterval: TimeInterval = 1.0 / 30.0
        static let pointsPerWord: Double = 18
        static let minimumSpeed: Double = 60
        static let maximumSpeed: Double = 260
        static let speedStep: Double = 10
    }

    var state: State = .stopped
    var speedWordsPerMinute: Double = 140
    var currentOffset: Double = 0
    private var maximumOffset: Double = 0
    private var timer: Timer?
    private var lastTickDate: Date?

    func play() {
        guard maximumOffset > 0 else {
            finishPlayback()
            return
        }

        lastTickDate = .now
        startTimerIfNeeded()
        state = .playing
    }

    func pause() {
        state = .paused
        invalidateTimer()
        lastTickDate = nil
    }

    func stop() {
        state = .stopped
        currentOffset = 0
        invalidateTimer()
        lastTickDate = nil
    }

    func togglePlayback() {
        switch state {
        case .playing:
            pause()
        case .paused, .stopped:
            play()
        }
    }

    func restartFromTop() {
        currentOffset = 0
        pause()
    }

    func increaseSpeed() {
        speedWordsPerMinute = min(Layout.maximumSpeed, speedWordsPerMinute + Layout.speedStep)
    }

    func decreaseSpeed() {
        speedWordsPerMinute = max(Layout.minimumSpeed, speedWordsPerMinute - Layout.speedStep)
    }

    func applySpeed(_ newValue: Double) {
        speedWordsPerMinute = min(Layout.maximumSpeed, max(Layout.minimumSpeed, newValue))
    }

    func updateScrollableMetrics(contentHeight: Double, viewportHeight: Double) {
        maximumOffset = max(0, contentHeight - viewportHeight)
        currentOffset = min(currentOffset, maximumOffset)
        if state == .playing && currentOffset >= maximumOffset {
            finishPlayback()
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: Layout.timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func finishPlayback() {
        state = .stopped
        currentOffset = maximumOffset
        invalidateTimer()
        lastTickDate = nil
    }

    private func tick() {
        guard state == .playing else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastTickDate ?? now)
        lastTickDate = now

        guard elapsed > 0 else { return }

        let wordsPerSecond = speedWordsPerMinute / 60
        currentOffset = min(maximumOffset, currentOffset + (wordsPerSecond * Layout.pointsPerWord * elapsed))

        if state == .playing && currentOffset >= maximumOffset {
            finishPlayback()
        }
    }
}
