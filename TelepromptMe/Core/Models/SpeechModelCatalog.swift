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
    static let whisperCppRepositoryID = "ggerganov/whisper.cpp"

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
        whisperCppDescriptors(for: whisperCppModelFiles)
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

    private static var whisperCppModelFiles: [String] {
        [
            "ggml-tiny.bin",
            "ggml-tiny-q5_1.bin",
            "ggml-tiny-q8_0.bin",
            "ggml-tiny.en.bin",
            "ggml-tiny.en-q5_1.bin",
            "ggml-tiny.en-q8_0.bin",
            "ggml-base.bin",
            "ggml-base-q5_1.bin",
            "ggml-base-q8_0.bin",
            "ggml-base.en.bin",
            "ggml-base.en-q5_1.bin",
            "ggml-base.en-q8_0.bin",
            "ggml-small.bin",
            "ggml-small-q5_1.bin",
            "ggml-small-q8_0.bin",
            "ggml-small.en.bin",
            "ggml-small.en-q5_1.bin",
            "ggml-small.en-q8_0.bin",
            "ggml-medium.bin",
            "ggml-medium-q5_0.bin",
            "ggml-medium-q8_0.bin",
            "ggml-medium.en.bin",
            "ggml-medium.en-q5_0.bin",
            "ggml-medium.en-q8_0.bin",
            "ggml-large-v1.bin",
            "ggml-large-v2.bin",
            "ggml-large-v2-q5_0.bin",
            "ggml-large-v2-q8_0.bin",
            "ggml-large-v3.bin",
            "ggml-large-v3-q5_0.bin",
            "ggml-large-v3-turbo.bin",
            "ggml-large-v3-turbo-q5_0.bin",
            "ggml-large-v3-turbo-q8_0.bin",
        ]
    }

    static func whisperCppDescriptors(for fileNames: [String]) -> [SpeechModelDescriptor] {
        fileNames
            .filter(isWhisperCppModelFile)
            .map { whisperCppDescriptor(for: $0) }
    }

    static func isWhisperCppModelFile(_ fileName: String) -> Bool {
        fileName.hasPrefix("ggml-") && fileName.hasSuffix(".bin")
    }

    static func whisperCppDescriptor(for fileName: String) -> SpeechModelDescriptor {
        SpeechModelDescriptor(
            id: whisperCppModelID(for: fileName),
            runtime: .whisperCpp,
            architecture: .whisper,
            title: whisperCppTitle(for: fileName),
            subtitle: whisperCppSubtitle(for: fileName),
            repositoryID: whisperCppRepositoryID,
            primaryModelFileName: fileName,
            checksumSHA256: nil,
            estimatedByteSize: estimatedByteSize(for: fileName),
            supportedLanguageIdentifiers: supportedLanguageIdentifiers(for: fileName),
            isCustom: false,
            isRecommended: ["ggml-base.bin", "ggml-small.bin", "ggml-small.en.bin"].contains(fileName)
        )
    }

    private static func whisperCppModelID(for fileName: String) -> String {
        let baseName = fileName.replacingOccurrences(of: ".bin", with: "")
        let slug = baseName
            .replacingOccurrences(of: "ggml-", with: "")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        return "whisper-\(slug)"
    }

    private static func whisperCppTitle(for fileName: String) -> String {
        let baseName = fileName
            .replacingOccurrences(of: "ggml-", with: "")
            .replacingOccurrences(of: ".bin", with: "")
        let parts = baseName
            .split(separator: "-")
            .map { part in
                part == "en" ? "English" : part.uppercased()
            }

        return "Whisper \(parts.joined(separator: " "))"
    }

    private static func whisperCppSubtitle(for fileName: String) -> String {
        var details = ["Hugging Face whisper.cpp model"]
        if fileName.contains(".en") {
            details.append("English-only")
        } else {
            details.append("multilingual")
        }
        if fileName.contains("-q") {
            details.append("quantized")
        }

        return details.joined(separator: ", ") + "."
    }

    private static func supportedLanguageIdentifiers(for fileName: String) -> [String] {
        fileName.contains(".en") ? ["en_US", "en_GB"] : []
    }

    private static func estimatedByteSize(for fileName: String) -> Int64? {
        switch fileName {
        case "ggml-small.bin":
            return 487_601_967
        default:
            return nil
        }
    }
}
