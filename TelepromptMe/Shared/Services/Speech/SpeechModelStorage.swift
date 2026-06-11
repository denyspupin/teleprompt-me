import Foundation

enum SpeechModelStorage {
    static let manifestFileName = "model.json"

    static var modelsDirectoryURL: URL {
        applicationSupportURL.appendingPathComponent("SpeechModels", isDirectory: true)
    }

    static func directoryURL(for model: SpeechRecognitionEngineID) -> URL {
        directoryURL(forModelID: model.rawValue)
    }

    static func directoryURL(forModelID modelID: String) -> URL {
        modelsDirectoryURL.appendingPathComponent(modelID, isDirectory: true)
    }

    static func modelFileURL(for model: SpeechRecognitionEngineID) -> URL? {
        modelFileURL(for: model.descriptor)
    }

    static func modelFileURL(for descriptor: SpeechModelDescriptor) -> URL? {
        guard let fileName = descriptor.primaryModelFileName else {
            return nil
        }

        return directoryURL(forModelID: descriptor.id).appendingPathComponent(fileName)
    }

    private static var applicationSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TelepromptMe", isDirectory: true)
    }
}
