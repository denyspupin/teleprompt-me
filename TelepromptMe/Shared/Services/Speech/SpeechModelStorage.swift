import Foundation

enum SpeechModelStorage {
    static func directoryURL(for model: SpeechRecognitionEngineID) -> URL {
        applicationSupportURL
            .appendingPathComponent("SpeechModels", isDirectory: true)
            .appendingPathComponent(model.rawValue, isDirectory: true)
    }

    static func modelFileURL(for model: SpeechRecognitionEngineID) -> URL? {
        guard let fileName = model.primaryModelFileName else {
            return nil
        }

        return directoryURL(for: model).appendingPathComponent(fileName)
    }

    private static var applicationSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TelepromptMe", isDirectory: true)
    }
}
