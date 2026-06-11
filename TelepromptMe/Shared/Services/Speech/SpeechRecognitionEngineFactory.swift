import Foundation

enum SpeechRecognitionEngineFactory {
    static func makeEngine(for engineID: String) -> SpeechRecognitionEngine {
        makeEngine(
            for: engineID,
            fileExists: FileManager.default.fileExists(atPath:)
        )
    }

    static func makeEngine(
        for engineID: String,
        fileExists: (String) -> Bool
    ) -> SpeechRecognitionEngine {
        guard let descriptor = SpeechModelCatalog.descriptor(for: engineID),
              descriptor.isWhisperModel else {
            return AppleSpeechRecognitionEngine()
        }

        guard let modelURL = SpeechModelStorage.modelFileURL(for: descriptor),
              fileExists(modelURL.path) else {
            return AppleSpeechRecognitionEngine()
        }

        return WhisperSpeechRecognitionEngine(modelURL: modelURL)
    }
}
