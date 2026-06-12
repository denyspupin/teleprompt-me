import XCTest
@testable import TelepromptMe

final class SpeechRecognitionEngineFactoryTests: XCTestCase {
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

    func testAppleModelRoutesToAppleSpeechEngine() {
        let engine = SpeechRecognitionEngineFactory.makeEngine(
            for: SpeechRecognitionEngineID.appleBuiltIn.rawValue,
            fileExists: { _ in true }
        )

        XCTAssertTrue(engine is AppleSpeechRecognitionEngine)
    }

    func testWhisperModelFallsBackWhenModelIsMissing() {
        let engine = SpeechRecognitionEngineFactory.makeEngine(
            for: SpeechRecognitionEngineID.whisperSmall.rawValue,
            fileExists: { _ in false }
        )

        XCTAssertTrue(engine is AppleSpeechRecognitionEngine)
    }

    func testWhisperModelRoutesToWhisperEngineWhenModelExists() throws {
        let descriptor = SpeechRecognitionEngineID.whisperSmall.descriptor
        let modelDirectory = SpeechModelStorage.directoryURL(forModelID: descriptor.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        let modelURL = modelDirectory.appendingPathComponent(descriptor.primaryModelFileName!)
        try Data("model".utf8).write(to: modelURL)

        let engine = SpeechRecognitionEngineFactory.makeEngine(
            for: descriptor.id,
            fileExists: { $0 == modelURL.path }
        )

        XCTAssertTrue(engine is WhisperSpeechRecognitionEngine)
    }

    func testInstalledManifestWhisperModelRoutesToWhisperEngineWhenModelExists() throws {
        let descriptor = SpeechModelDescriptor(
            id: "whisper-runtime-dynamic",
            runtime: .whisperCpp,
            architecture: .whisper,
            title: "Dynamic Whisper",
            subtitle: "Downloaded whisper.cpp model.",
            repositoryID: "example/whisper",
            primaryModelFileName: "ggml-dynamic.bin",
            checksumSHA256: nil,
            estimatedByteSize: nil,
            supportedLanguageIdentifiers: [],
            isCustom: false,
            isRecommended: false
        )
        let modelDirectory = SpeechModelStorage.directoryURL(forModelID: descriptor.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        let modelURL = modelDirectory.appendingPathComponent(descriptor.primaryModelFileName!)
        try Data("model".utf8).write(to: modelURL)
        try JSONEncoder().encode(descriptor).write(
            to: modelDirectory.appendingPathComponent(SpeechModelStorage.manifestFileName)
        )

        let engine = SpeechRecognitionEngineFactory.makeEngine(
            for: descriptor.id,
            fileExists: { $0 == modelURL.path }
        )

        XCTAssertTrue(engine is WhisperSpeechRecognitionEngine)
    }
}
