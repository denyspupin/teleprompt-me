import Foundation

enum SpeechRecognitionEngineFactory {
    static func makeEngine(for engineID: String) -> SpeechRecognitionEngine {
        guard let model = SpeechRecognitionEngineID(rawValue: engineID) else {
            return AppleSpeechRecognitionEngine()
        }

        guard model.isWhisperModel else {
            return AppleSpeechRecognitionEngine()
        }

        guard let modelURL = SpeechModelStorage.modelFileURL(for: model),
              FileManager.default.fileExists(atPath: modelURL.path),
              WhisperCppTranscriber.bundledExecutableURL != nil else {
            return AppleSpeechRecognitionEngine()
        }

        return WhisperSpeechRecognitionEngine(modelURL: modelURL)
    }
}
