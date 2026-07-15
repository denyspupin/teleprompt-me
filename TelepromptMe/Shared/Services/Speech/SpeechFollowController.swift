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

    private enum Layout {
        static let lostResultThreshold = 5
    }

    var state: State = .idle
    var lastTranscript = ""
    var confidence: Double = 0
    var isListening: Bool {
        if case .idle = state { return false }
        if case .failed = state { return false }
        return true
    }

    private let matcher = ScriptProgressMatcher()
    private var engine: SpeechRecognitionEngine?
    private var listenTask: Task<Void, Never>?
    private weak var playbackController: PlaybackController?
    private var unmatchedResults = 0

    func start(script: String, settings: AppSettingsSnapshot, playbackController: PlaybackController) {
        stop()
        self.playbackController = playbackController
        matcher.prepare(script: script)
        state = .listening
        lastTranscript = ""
        confidence = 0
        unmatchedResults = 0

        let engine = SpeechRecognitionEngineFactory.makeEngine(for: settings.selectedSpeechEngineID)
        self.engine = engine

        listenTask = Task { [weak self, weak playbackController] in
            guard let self else { return }
            let results = engine.results

            do {
                try await engine.start(localeIdentifier: settings.selectedSpeechLocaleIdentifier)
            } catch {
                await MainActor.run {
                    self.state = .failed(error.localizedDescription)
                }
                return
            }

            for await result in results {
                await MainActor.run {
                    guard let playbackController else { return }
                    self.handle(
                        result,
                        sensitivity: settings.speechFollowSensitivity,
                        playbackController: playbackController
                    )
                }
            }

            await MainActor.run {
                if let message = engine.failureMessage {
                    self.state = .failed(message)
                } else if self.isListening {
                    self.state = .idle
                }
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
            state = unmatchedResults >= Layout.lostResultThreshold ? .lost : .listening
            return
        }

        unmatchedResults = 0
        confidence = match.confidence
        state = .matching
        playbackController.follow(progress: match.progress)
    }
}
