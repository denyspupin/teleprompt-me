import Foundation

enum SpeechRecognitionRuntime: String, Codable {
    case appleSpeech
    case whisperCpp
    case whisperKit
    case externalProcess
}

enum SpeechRecognitionArchitecture: String, Codable {
    case appleBuiltIn
    case whisper
}

struct SpeechModelDescriptor: Codable, Identifiable, Equatable {
    var id: String
    var runtime: SpeechRecognitionRuntime
    var architecture: SpeechRecognitionArchitecture
    var title: String
    var subtitle: String
    var repositoryID: String?
    var primaryModelFileName: String?
    var checksumSHA256: String?
    var estimatedByteSize: Int64?
    var supportedLanguageIdentifiers: [String]
    var isCustom: Bool
    var isRecommended: Bool

    var isBuiltIn: Bool {
        runtime == .appleSpeech
    }

    var isWhisperModel: Bool {
        architecture == .whisper && runtime == .whisperCpp
    }

    var estimatedDownloadSize: String? {
        guard let estimatedByteSize else {
            return nil
        }

        return ByteCountFormatter.string(
            fromByteCount: estimatedByteSize,
            countStyle: .file
        )
    }
}

enum SpeechModelCatalog {
    static let builtInAppleSpeechID = SpeechRecognitionEngineID.appleBuiltIn.rawValue

    static var builtInDescriptors: [SpeechModelDescriptor] {
        [
            SpeechModelDescriptor(
                id: SpeechRecognitionEngineID.appleBuiltIn.rawValue,
                runtime: .appleSpeech,
                architecture: .appleBuiltIn,
                title: "Apple Built-In",
                subtitle: "Uses the local speech recognition model included with macOS.",
                repositoryID: nil,
                primaryModelFileName: nil,
                checksumSHA256: nil,
                estimatedByteSize: nil,
                supportedLanguageIdentifiers: [],
                isCustom: false,
                isRecommended: true
            )
        ]
    }

    static var downloadableDescriptors: [SpeechModelDescriptor] {
        [
            SpeechModelDescriptor(
                id: SpeechRecognitionEngineID.whisperSmall.rawValue,
                runtime: .whisperCpp,
                architecture: .whisper,
                title: "Whisper Small",
                subtitle: "A downloadable whisper.cpp model for offline recognition.",
                repositoryID: "TelepromptMe/whisper-small-ggml",
                primaryModelFileName: "ggml-small.bin",
                checksumSHA256: nil,
                estimatedByteSize: 465_000_000,
                supportedLanguageIdentifiers: [],
                isCustom: false,
                isRecommended: true
            )
        ]
    }

    static var descriptors: [SpeechModelDescriptor] {
        builtInDescriptors + downloadableDescriptors + customDescriptors()
    }

    static func descriptor(for id: String) -> SpeechModelDescriptor? {
        descriptors.first { $0.id == id }
    }

    static func descriptor(for model: SpeechRecognitionEngineID) -> SpeechModelDescriptor {
        descriptor(for: model.rawValue) ?? builtInDescriptors[0]
    }

    static func resolvedModelID(for selectedModelID: String) -> String {
        guard let descriptor = descriptor(for: selectedModelID),
              isAvailableForSelection(descriptor) else {
            return builtInAppleSpeechID
        }

        return descriptor.id
    }

    static func customDescriptors() -> [SpeechModelDescriptor] {
        let fileManager = FileManager.default
        guard let modelDirectories = try? fileManager.contentsOfDirectory(
            at: SpeechModelStorage.modelsDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        return modelDirectories.compactMap { directoryURL in
            guard directoryURL.lastPathComponent.hasPrefix("custom-") else {
                return nil
            }

            let manifestURL = directoryURL.appendingPathComponent(SpeechModelStorage.manifestFileName)
            guard let data = try? Data(contentsOf: manifestURL),
                  let descriptor = try? JSONDecoder().decode(SpeechModelDescriptor.self, from: data) else {
                return nil
            }

            return descriptor
        }
    }

    private static func isAvailableForSelection(_ descriptor: SpeechModelDescriptor) -> Bool {
        guard !descriptor.isBuiltIn else {
            return true
        }

        guard let primaryModelFileName = descriptor.primaryModelFileName else {
            return false
        }

        let modelFileURL = SpeechModelStorage.directoryURL(forModelID: descriptor.id)
            .appendingPathComponent(primaryModelFileName)
        return FileManager.default.fileExists(atPath: modelFileURL.path)
    }
}
