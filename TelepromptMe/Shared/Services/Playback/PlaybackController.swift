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
        static let followSmoothing: Double = 7
        static let maximumFollowAdvancePerSecond: Double = 180
    }

    var state: State = .stopped
    var mode: Mode = .autoScroll
    var speedWordsPerMinute: Double = 140
    var currentOffset: Double = 0
    var stepUnitPoints: Double = 160
    private(set) var isHoldScrolling = false
    private var maximumOffset: Double = 0
    private var followTargetOffset: Double?
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
        followTargetOffset = nil
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
        currentOffset = min(maximumOffset, currentOffset + stepUnitPoints)
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

    func updateScrollableMetrics(contentHeight: Double, viewportHeight: Double) {
        maximumOffset = max(0, contentHeight - viewportHeight)
        currentOffset = min(currentOffset, maximumOffset)
        if let followTargetOffset {
            self.followTargetOffset = min(followTargetOffset, maximumOffset)
        }

        if state == .playing && currentOffset >= maximumOffset {
            finishPlayback()
        }
    }

    func follow(progress: Double) {
        let clampedProgress = min(1, max(0, progress))
        let targetOffset = maximumOffset * clampedProgress
        followTargetOffset = min(maximumOffset, max(currentOffset, targetOffset))
        lastTickDate = .now
        startTimerIfNeeded()
    }

    func stopFollowing() {
        followTargetOffset = nil

        if state != .playing && !isHoldScrolling {
            invalidateTimer()
            lastTickDate = nil
        }
    }

    func beginHoldScroll() {
        guard !isHoldScrolling else { return }
        isHoldScrolling = true
        lastTickDate = .now
        startTimerIfNeeded()
    }

    func endHoldScroll() {
        guard isHoldScrolling else { return }
        isHoldScrolling = false

        if state != .playing {
            invalidateTimer()
            lastTickDate = nil
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
        guard state == .playing || isHoldScrolling || followTargetOffset != nil else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastTickDate ?? now)
        lastTickDate = now

        guard elapsed > 0 else { return }

        if state == .playing || isHoldScrolling {
            let wordsPerSecond = speedWordsPerMinute / 60
            currentOffset = min(maximumOffset, currentOffset + (wordsPerSecond * Layout.pointsPerWord * elapsed))
        }

        if let target = followTargetOffset {
            let distance = target - currentOffset
            if abs(distance) < 0.5 {
                currentOffset = target
                followTargetOffset = nil
            } else if distance > 0 {
                let easedStep = distance * min(1, Layout.followSmoothing * elapsed)
                let cappedStep = min(easedStep, Layout.maximumFollowAdvancePerSecond * elapsed)
                currentOffset = min(maximumOffset, currentOffset + max(0.5, cappedStep))
            } else {
                followTargetOffset = nil
            }
        }

        if state == .playing && currentOffset >= maximumOffset {
            finishPlayback()
        } else if state != .playing && !isHoldScrolling && followTargetOffset == nil {
            invalidateTimer()
            lastTickDate = nil
        }
    }
}
