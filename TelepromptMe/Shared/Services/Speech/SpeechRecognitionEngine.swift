import Foundation

struct SpeechRecognitionResult: Equatable {
    var transcript: String
    var isFinal: Bool
}

protocol SpeechRecognitionEngine: AnyObject {
    var results: AsyncStream<SpeechRecognitionResult> { get }
    var failureMessage: String? { get }

    func start(localeIdentifier: String) async throws
    func stop()
}

enum SpeechRecognitionError: LocalizedError {
    case recognizerUnavailable
    case authorizationDenied
    case microphoneUnavailable
    case localModelUnavailable(String)
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is unavailable for the selected language."
        case .authorizationDenied:
            return "Microphone or speech recognition permission was denied."
        case .microphoneUnavailable:
            return "The microphone could not be started."
        case .localModelUnavailable(let modelName):
            return "\(modelName) is not ready. Download the model and install the local speech runtime first."
        case .recognitionFailed(let message):
            return message
        }
    }
}
