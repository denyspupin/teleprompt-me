import Foundation

enum SpeechRecognitionEngineFactory {
    static func makeEngine(for engineID: String) -> SpeechRecognitionEngine {
        makeEngine(
            for: engineID,
            fileExists: FileManager.default.fileExists(atPath:),
            bundledExecutableURL: WhisperCppTranscriber.bundledExecutableURL
        )
    }

    static func makeEngine(
        for engineID: String,
        fileExists: (String) -> Bool,
        bundledExecutableURL: URL?
    ) -> SpeechRecognitionEngine {
        let resolvedEngineID = SpeechModelCatalog.resolvedModelID(for: engineID)
        guard let descriptor = SpeechModelCatalog.descriptor(for: resolvedEngineID),
              descriptor.isWhisperModel else {
            return AppleSpeechRecognitionEngine()
        }

        guard let modelURL = SpeechModelStorage.modelFileURL(for: descriptor),
              fileExists(modelURL.path),
              bundledExecutableURL != nil else {
            return AppleSpeechRecognitionEngine()
        }

        return WhisperSpeechRecognitionEngine(modelURL: modelURL)
    }
}
