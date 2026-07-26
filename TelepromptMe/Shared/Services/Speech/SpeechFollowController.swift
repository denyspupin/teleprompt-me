import Foundation
import Observation

@MainActor
@Observable
final class SpeechFollowController {
    enum State: Equatable {
        case idle
        case listening
        case matching
        case lost
        case failed(String)
    }

    private enum Limits {
        static let lostResultThreshold = 5
    }

    var state: State = .idle
    var lastTranscript = ""
    var confidence: Double = 0

    var isListening: Bool {
        switch state {
        case .idle, .failed:
            return false
        case .listening, .matching, .lost:
            return true
        }
    }

    private let matcher = ScriptProgressMatcher()
    private let makeEngine: () -> SpeechRecognitionEngine
    private var engine: SpeechRecognitionEngine?
    private var listenTask: Task<Void, Never>?
    private weak var playbackController: PlaybackController?
    private var unmatchedResults = 0

    init(makeEngine: @escaping () -> SpeechRecognitionEngine = AppleSpeechRecognitionEngine.init) {
        self.makeEngine = makeEngine
    }

    func start(
        script: String,
        localeIdentifier: String,
        sensitivity: Double,
        playbackController: PlaybackController
    ) {
        stop()
        self.playbackController = playbackController
        matcher.prepare(script: script)
        state = .listening
        lastTranscript = ""
        confidence = 0
        unmatchedResults = 0

        listenTask = Task { [weak self, weak playbackController] in
            guard let self else { return }

            while !Task.isCancelled {
                let engine = self.makeEngine()
                self.engine = engine
                let results = engine.results

                do {
                    try await engine.start(localeIdentifier: localeIdentifier)
                } catch is CancellationError {
                    return
                } catch {
                    self.state = .failed(error.localizedDescription)
                    engine.stop()
                    return
                }

                for await result in results {
                    guard !Task.isCancelled, let playbackController else { return }
                    self.handle(
                        result,
                        sensitivity: sensitivity,
                        playbackController: playbackController
                    )
                }

                engine.stop()
                guard !Task.isCancelled else { return }
                if let message = engine.failureMessage {
                    self.state = .failed(message)
                    return
                }

                self.state = .listening
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
        engine?.stop()
        engine = nil
        matcher.reset()
        playbackController?.stopFollowing()
        playbackController = nil
        state = .idle
        lastTranscript = ""
        confidence = 0
        unmatchedResults = 0
    }

    private func handle(
        _ result: SpeechRecognitionResult,
        sensitivity: Double,
        playbackController: PlaybackController
    ) {
        lastTranscript = result.transcript
        guard let match = matcher.match(transcript: result.transcript, sensitivity: sensitivity) else {
            unmatchedResults += 1
            state = unmatchedResults >= Limits.lostResultThreshold ? .lost : .listening
            return
        }

        unmatchedResults = 0
        confidence = match.confidence
        state = .matching
        playbackController.follow(progress: match.progress)
    }
}
