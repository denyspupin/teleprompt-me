import XCTest
@testable import TelepromptMe

@MainActor
final class SpeechModelCatalogTests: XCTestCase {
    private var temporaryModelsDirectory: URL!

    override func setUpWithError() throws {
        temporaryModelsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryModelsDirectory,
            withIntermediateDirectories: true
        )
        SpeechModelStorage.modelsDirectoryOverrideURL = temporaryModelsDirectory
    }

    override func tearDownWithError() throws {
        SpeechModelStorage.modelsDirectoryOverrideURL = nil
        if let temporaryModelsDirectory {
            try? FileManager.default.removeItem(at: temporaryModelsDirectory)
        }
        temporaryModelsDirectory = nil
    }

    func testBuiltInDescriptorIsAlwaysSelectableFallback() {
        let descriptor = SpeechModelCatalog.descriptor(for: SpeechRecognitionEngineID.appleBuiltIn)

        XCTAssertEqual(descriptor.id, SpeechModelCatalog.builtInAppleSpeechID)
        XCTAssertEqual(descriptor.runtime, .appleSpeech)
        XCTAssertTrue(descriptor.isBuiltIn)
        XCTAssertTrue(descriptor.isRecommended)
        XCTAssertEqual(
            SpeechModelCatalog.resolvedModelID(for: "missing-model"),
            SpeechModelCatalog.builtInAppleSpeechID
        )
    }

    func testWhisperSmallUsesHuggingFaceWhisperCppSource() throws {
        let descriptor = SpeechRecognitionEngineID.whisperSmall.descriptor

        XCTAssertEqual(descriptor.repositoryID, "ggerganov/whisper.cpp")
        XCTAssertEqual(descriptor.primaryModelFileName, "ggml-small.bin")
        XCTAssertEqual(descriptor.estimatedByteSize, 487_601_967)
        XCTAssertEqual(
            SpeechModelDownloadManager.repositoryAPIURL(for: descriptor.repositoryID!)?.absoluteString,
            "https://huggingface.co/api/models/ggerganov/whisper.cpp"
        )
        XCTAssertEqual(
            try SpeechModelDownloadManager.resolveURL(
                repositoryID: descriptor.repositoryID!,
                filePath: descriptor.primaryModelFileName!
            ).absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
        )
    }

    func testDownloadableDescriptorRequiresExpectedModelFileForSelection() throws {
        let descriptor = SpeechRecognitionEngineID.whisperSmall.descriptor
        let modelDirectory = SpeechModelStorage.directoryURL(forModelID: descriptor.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("manifest".utf8).write(
            to: modelDirectory.appendingPathComponent(SpeechModelStorage.manifestFileName)
        )

        XCTAssertEqual(
            SpeechModelCatalog.resolvedModelID(for: descriptor.id),
            SpeechModelCatalog.builtInAppleSpeechID
        )

        try Data("model".utf8).write(
            to: modelDirectory.appendingPathComponent(descriptor.primaryModelFileName!)
        )

        XCTAssertEqual(SpeechModelCatalog.resolvedModelID(for: descriptor.id), descriptor.id)
    }

    func testCustomDescriptorDiscoveryAndSelection() throws {
        let descriptor = SpeechModelDescriptor(
            id: "custom-meeting-model",
            runtime: .whisperCpp,
            architecture: .whisper,
            title: "Meeting Model",
            subtitle: "Imported whisper.cpp model.",
            repositoryID: nil,
            primaryModelFileName: "meeting.bin",
            checksumSHA256: nil,
            estimatedByteSize: 5,
            supportedLanguageIdentifiers: ["en_US"],
            isCustom: true,
            isRecommended: false
        )
        let modelDirectory = SpeechModelStorage.directoryURL(forModelID: descriptor.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: modelDirectory.appendingPathComponent("meeting.bin"))
        try JSONEncoder().encode(descriptor).write(
            to: modelDirectory.appendingPathComponent(SpeechModelStorage.manifestFileName)
        )

        XCTAssertTrue(SpeechModelCatalog.customDescriptors().contains(descriptor))
        XCTAssertEqual(SpeechModelCatalog.resolvedModelID(for: descriptor.id), descriptor.id)
    }

    func testCustomImportAndDeleteUpdateManagerState() throws {
        let sourceURL = temporaryModelsDirectory
            .appendingPathComponent("source", isDirectory: true)
            .appendingPathComponent("tiny.bin")
        try FileManager.default.createDirectory(
            at: sourceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("tiny model".utf8).write(to: sourceURL)

        let manager = SpeechModelDownloadManager(refreshesHuggingFaceModels: false)
        let descriptor = try manager.importCustomModel(from: sourceURL)

        XCTAssertTrue(descriptor.isCustom)
        XCTAssertEqual(manager.state(for: descriptor), .downloaded)
        XCTAssertTrue(manager.isUsable(descriptor))
        XCTAssertNotNil(descriptor.checksumSHA256)

        manager.delete(descriptor)

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: SpeechModelStorage.directoryURL(forModelID: descriptor.id).path
            )
        )
    }

    func testChecksumMismatchThrowsDownloadError() throws {
        let fileURL = temporaryModelsDirectory.appendingPathComponent("checksum.bin")
        try Data("actual".utf8).write(to: fileURL)

        XCTAssertThrowsError(
            try SpeechModelDownloadManager.verifyChecksum(
                for: fileURL,
                expectedChecksum: String(repeating: "0", count: 64),
                modelName: "Checksum Model"
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("Checksum Model"))
        }
    }

    func testWhisperCppModelFilterExcludesUnsupportedRepositoryFiles() {
        let descriptors = SpeechModelCatalog.whisperCppDescriptors(
            for: [
                ".gitattributes",
                "README.md",
                "ggml-small-encoder.mlmodelc.zip",
                "ggml-small.bin",
                "ggml-small-q5_1.bin",
            ]
        )

        XCTAssertEqual(descriptors.map(\.primaryModelFileName), ["ggml-small.bin", "ggml-small-q5_1.bin"])
    }

    func testWhisperCppDescriptorIncludesMatchingCoreMLArchive() {
        XCTAssertEqual(
            SpeechModelCatalog.whisperCppCoreMLArchiveFileNames(for: "ggml-base.en.bin"),
            ["ggml-base.en-encoder.mlmodelc.zip"]
        )
        XCTAssertEqual(
            SpeechModelCatalog.whisperCppCoreMLArchiveFileNames(for: "ggml-small-q5_1.bin"),
            ["ggml-small-encoder.mlmodelc.zip"]
        )
    }

    func testInstalledDescriptorDiscoveryIncludesDownloadedManifest() throws {
        let descriptor = SpeechModelDescriptor(
            id: "whisper-distil-large",
            runtime: .whisperCpp,
            architecture: .whisper,
            title: "Whisper Distil Large",
            subtitle: "Downloaded whisper.cpp model.",
            repositoryID: "example/whisper",
            primaryModelFileName: "ggml-distil-large.bin",
            auxiliaryModelFileNames: ["ggml-distil-large-encoder.mlmodelc.zip"],
            checksumSHA256: nil,
            estimatedByteSize: 7,
            supportedLanguageIdentifiers: [],
            isCustom: false,
            isRecommended: false
        )
        let modelDirectory = SpeechModelStorage.directoryURL(forModelID: descriptor.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: modelDirectory.appendingPathComponent("ggml-distil-large.bin"))
        try JSONEncoder().encode(descriptor).write(
            to: modelDirectory.appendingPathComponent(SpeechModelStorage.manifestFileName)
        )

        XCTAssertTrue(SpeechModelCatalog.installedDescriptors().contains(descriptor))
        XCTAssertEqual(SpeechModelCatalog.descriptor(for: descriptor.id), descriptor)
        XCTAssertEqual(SpeechModelCatalog.resolvedModelID(for: descriptor.id), descriptor.id)
    }

    func testHuggingFaceLinkedSizeHeaderIsUsedAsByteSize() throws {
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["X-Linked-Size": "487601967", "Content-Length": "123"]
            )
        )

        XCTAssertEqual(SpeechModelDownloadManager.byteSize(from: response), 487_601_967)
    }
}
