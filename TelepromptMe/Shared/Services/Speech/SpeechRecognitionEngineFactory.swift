import Foundation

enum SpeechRecognitionEngineFactory {
    static func makeEngine(for engineID: String) -> SpeechRecognitionEngine {
        guard let descriptor = SpeechModelCatalog.descriptor(for: engineID),
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
