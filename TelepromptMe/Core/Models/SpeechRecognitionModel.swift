import Foundation

enum SpeechRecognitionEngineID: String, CaseIterable, Identifiable {
    case appleBuiltIn = "apple-built-in"
    case whisperSmall = "whisper-small"

    var id: String { rawValue }

    var title: String {
        descriptor.title
    }

    var subtitle: String {
        descriptor.subtitle
    }

    var isBuiltIn: Bool {
        descriptor.isBuiltIn
    }

    var isWhisperModel: Bool {
        descriptor.isWhisperModel
    }

    var estimatedDownloadSize: String? {
        descriptor.estimatedDownloadSize
    }

    var repositoryID: String? {
        descriptor.repositoryID
    }

    var manifestFileName: String {
        SpeechModelStorage.manifestFileName
    }

    var primaryModelFileName: String? {
        descriptor.primaryModelFileName
    }

    var descriptor: SpeechModelDescriptor {
        SpeechModelCatalog.descriptor(for: self)
    }
}
