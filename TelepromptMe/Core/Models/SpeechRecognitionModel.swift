import Foundation

enum SpeechRecognitionEngineID: String, CaseIterable, Identifiable {
    case appleBuiltIn = "apple-built-in"
    case whisperSmall = "whisper-small"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleBuiltIn:
            return "Apple Built-In"
        case .whisperSmall:
            return "Whisper Small"
        }
    }

    var subtitle: String {
        switch self {
        case .appleBuiltIn:
            return "Uses the local speech recognition model included with macOS."
        case .whisperSmall:
            return "A downloadable whisper.cpp model for offline recognition."
        }
    }

    var isBuiltIn: Bool {
        self == .appleBuiltIn
    }

    var isWhisperModel: Bool {
        switch self {
        case .appleBuiltIn:
            return false
        case .whisperSmall:
            return true
        }
    }

    var estimatedDownloadSize: String? {
        switch self {
        case .appleBuiltIn:
            return nil
        case .whisperSmall:
            return "465 MB"
        }
    }

    var repositoryID: String? {
        switch self {
        case .appleBuiltIn:
            return nil
        case .whisperSmall:
            return "TelepromptMe/whisper-small-ggml"
        }
    }

    var manifestFileName: String {
        "model.json"
    }

    var primaryModelFileName: String? {
        switch self {
        case .appleBuiltIn:
            return nil
        case .whisperSmall:
            return "ggml-small.bin"
        }
    }
}
