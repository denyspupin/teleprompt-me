import Foundation
import Observation

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

    var state: State = .stopped
    var mode: Mode = .autoScroll
    var speedWordsPerMinute: Double = 140
    var currentOffset: Double = 0
    var stepUnitPoints: Double = 160

    func play() {
        state = .playing
    }

    func pause() {
        state = .paused
    }

    func stop() {
        state = .stopped
        currentOffset = 0
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
}
