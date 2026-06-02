import Foundation

enum SpeechRecognitionEngineID: String, CaseIterable, Identifiable {
    case appleBuiltIn = "apple-built-in"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleBuiltIn:
            return "Apple Built-In"
        }
    }

    var subtitle: String {
        switch self {
        case .appleBuiltIn:
            return "Uses the local speech recognition model included with macOS."
        }
    }
}

