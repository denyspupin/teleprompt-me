import Foundation

enum SpeechRecognitionEngineID: String, CaseIterable, Identifiable {
    case appleBuiltIn = "apple-built-in"
    case parakeetV3 = "parakeet-v3"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleBuiltIn:
            return "Apple Built-In"
        case .parakeetV3:
            return "Parakeet v3"
        }
    }

    var subtitle: String {
        switch self {
        case .appleBuiltIn:
            return "Uses the local speech recognition model included with macOS."
        case .parakeetV3:
            return "A downloadable local model for offline speech recognition."
        }
    }

    var isBuiltIn: Bool {
        self == .appleBuiltIn
    }

    var estimatedDownloadSize: String? {
        switch self {
        case .appleBuiltIn:
            return nil
        case .parakeetV3:
            return "755 MB"
        }
    }

    var repositoryID: String? {
        switch self {
        case .appleBuiltIn:
            return nil
        case .parakeetV3:
            return "sonic-speech/parakeet-tdt-0.6b-v3-int8"
        }
    }

    var manifestFileName: String {
        "\(rawValue).model"
    }
}
