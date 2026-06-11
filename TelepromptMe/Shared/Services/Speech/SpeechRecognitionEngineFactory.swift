import Foundation

enum SpeechRecognitionEngineFactory {
    static func makeEngine(for engineID: String) -> SpeechRecognitionEngine {
        let resolvedEngineID = SpeechModelCatalog.resolvedModelID(for: engineID)
        guard let descriptor = SpeechModelCatalog.descriptor(for: resolvedEngineID),
              descriptor.isWhisperModel else {
            return AppleSpeechRecognitionEngine()
        }

        guard let modelURL = SpeechModelStorage.modelFileURL(for: descriptor),
              FileManager.default.fileExists(atPath: modelURL.path),
              WhisperCppTranscriber.bundledExecutableURL != nil else {
            return AppleSpeechRecognitionEngine()
        }

        return WhisperSpeechRecognitionEngine(modelURL: modelURL)
    }
}
