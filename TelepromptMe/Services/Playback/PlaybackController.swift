import Foundation
import Observation

@MainActor
@Observable
final class PlaybackController {
    enum State {
        case stopped
        case playing
        case paused
    }

    enum Mode: String, CaseIterable, Identifiable {
        case autoScroll
        case manualStep

        var id: String { rawValue }
    }

    private enum Layout {
        static let timerInterval: TimeInterval = 1.0 / 30.0
        static let pointsPerWord: Double = 18
        static let minimumSpeed: Double = 60
        static let maximumSpeed: Double = 260
        static let speedStep: Double = 10
    }

    var state: State = .stopped
    var mode: Mode = .autoScroll
    var speedWordsPerMinute: Double = 140
    var currentOffset: Double = 0
    var stepUnitPoints: Double = 160
    private var timer: Timer?
    private var lastTickDate: Date?

    func play() {
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

    func stepForward() {
        currentOffset += stepUnitPoints
    }

    func stepBackward() {
        currentOffset = max(0, currentOffset - stepUnitPoints)
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

    private func tick() {
        guard state == .playing else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastTickDate ?? now)
        lastTickDate = now

        guard elapsed > 0 else { return }

        let wordsPerSecond = speedWordsPerMinute / 60
        currentOffset += wordsPerSecond * Layout.pointsPerWord * elapsed
    }
}
